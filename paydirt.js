// paydirt.js — Mountable module for the minerswarehouse Node/Express app.
// Usage: require('./paydirt')(app, pool);
//
// Registers:
//   GET  /game/paydirt/*   → static game build (HTML5 export)
//   GET  /api/paydirt/scores → top 10 leaderboard
//   POST /api/paydirt/scores → submit score

const path = require('path');
const express = require('express');
const rateLimit = require('express-rate-limit');

// ---- validation ----
const INITIALS_RE = /^[A-Z0-9]{1,3}$/;
const MAX_SCORE = 9_999_999;

function clampInt(v, lo, hi) {
  v = Number.parseInt(v, 10);
  if (!Number.isFinite(v)) return null;
  return Math.min(hi, Math.max(lo, v));
}

// ---- registerPaydirt(app, pool) ----
module.exports = function registerPaydirt(app, pool) {
  // --- static game build ---
  const buildDir = path.join(__dirname, 'public', 'game', 'paydirt');
  app.use('/game/paydirt', express.static(buildDir, {
    setHeaders(res, filePath) {
      if (filePath.endsWith('.wasm')) {
        res.setHeader('Content-Type', 'application/wasm');
      }
      if (filePath.endsWith('index.html')) {
        res.setHeader('Cache-Control', 'no-cache');
      } else {
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
      }
    },
  }));

  // --- leaderboard API ---
  const api = express.Router();
  api.use(express.json({ limit: '4kb' }));

  const postLimiter = rateLimit({
    windowMs: 60_000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
  });

  // GET /api/paydirt/scores — top 10
  api.get('/scores', async (_req, res) => {
    try {
      const { rows } = await pool.query(
        'SELECT initials, score, depth FROM paydirt_scores ORDER BY score DESC, created_at ASC LIMIT 10'
      );
      res.json(rows);
    } catch (e) {
      console.error('[paydirt] scores GET', e.message);
      res.status(500).json({ error: 'server_error' });
    }
  });

  // POST /api/paydirt/scores — submit score
  api.post('/scores', postLimiter, async (req, res) => {
    const initials = String(req.body?.initials ?? '').toUpperCase().slice(0, 3);
    const score = clampInt(req.body?.score, 0, MAX_SCORE);
    const depth = clampInt(req.body?.depth, 0, 100000);

    if (!INITIALS_RE.test(initials) || score === null || depth === null) {
      return res.status(400).json({ error: 'bad_input' });
    }

    // Light plausibility check: score must be reachable for claimed depth
    if (score > (depth + 1) * 250_000) {
      return res.status(422).json({ error: 'implausible' });
    }

    try {
      await pool.query(
        'INSERT INTO paydirt_scores (initials, score, depth) VALUES ($1, $2, $3)',
        [initials, score, depth]
      );
      res.status(201).json({ ok: true });
    } catch (e) {
      console.error('[paydirt] scores POST', e.message);
      res.status(500).json({ error: 'server_error' });
    }
  });

  app.use('/api/paydirt', api);
};
