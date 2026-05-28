'use strict';

const path = require('path');
const express = require('express');
const rateLimit = require('express-rate-limit'); // npm i express-rate-limit

const INITIALS_RE = /^[A-Z0-9]{1,3}$/;
const MAX_SCORE = 9_999_999;
const MAX_DEPTH = 100_000;

function clampInt(value, lo, hi) {
  const n = Number.parseInt(value, 10);
  if (!Number.isFinite(n)) return null;
  return Math.min(hi, Math.max(lo, n));
}

/**
 * Mount PAY DIRT into an EXISTING Express app (the minerswarehouse server).
 * Reuses the app's existing PostgreSQL pool — does NOT open a new one.
 *
 *   const registerPaydirt = require('./server/paydirt');
 *   registerPaydirt(app, pool, {
 *     buildDir: path.join(__dirname, 'public', 'game', 'paydirt'), // <- match YOUR app
 *   });
 *
 * @param {import('express').Express} app   the existing app
 * @param {import('pg').Pool}         pool  the existing PostgreSQL pool
 * @param {object}  [opts]
 * @param {string}  [opts.buildDir]            absolute path to the Godot HTML5 export folder
 * @param {string}  [opts.staticPath]          URL mount for the game (default '/game/paydirt')
 * @param {string}  [opts.apiPath]             URL mount for the API  (default '/api/paydirt')
 * @param {boolean} [opts.crossOriginIsolated] set COOP/COEP — ONLY for a THREADED export
 */
module.exports = function registerPaydirt(app, pool, opts = {}) {
  const staticPath = opts.staticPath || '/game/paydirt';
  const apiPath = opts.apiPath || '/api/paydirt';
  // Default assumes this file lives one level below the app root (e.g. /server/paydirt.js)
  // with the export at <root>/public/game/paydirt. Pass opts.buildDir to override.
  const buildDir = opts.buildDir || path.join(__dirname, '..', 'public', 'game', 'paydirt');

  // ---- static game build --------------------------------------------------
  if (opts.crossOriginIsolated) {
    // Needed ONLY if you ship a THREADED Godot web export. Keep this route free
    // of cross-origin scripts (analytics/affiliate) or COEP require-corp blocks them.
    app.use(staticPath, (_req, res, next) => {
      res.set('Cross-Origin-Opener-Policy', 'same-origin');
      res.set('Cross-Origin-Embedder-Policy', 'require-corp');
      next();
    });
  }

  app.use(staticPath, express.static(buildDir, {
    setHeaders(res, filePath) {
      if (filePath.endsWith('.wasm')) res.setHeader('Content-Type', 'application/wasm');
      if (filePath.endsWith('index.html')) {
        res.setHeader('Cache-Control', 'no-cache');         // always revalidate the shell
      } else {
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable'); // hashed assets
      }
    },
  }));

  // ---- leaderboard API ----------------------------------------------------
  const api = express.Router();
  api.use(express.json({ limit: '4kb' }));

  const postLimiter = rateLimit({
    windowMs: 60_000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
  });

  // GET top 10
  api.get('/scores', async (_req, res) => {
    try {
      const { rows } = await pool.query(
        `SELECT initials, score, depth
           FROM paydirt_scores
          ORDER BY score DESC, created_at ASC
          LIMIT 10`
      );
      res.json(rows);
    } catch (err) {
      console.error('[paydirt] GET /scores', err);
      res.status(500).json({ error: 'server_error' });
    }
  });

  // POST a score
  api.post('/scores', postLimiter, async (req, res) => {
    const initials = String(req.body?.initials ?? '').toUpperCase().slice(0, 3);
    const score = clampInt(req.body?.score, 0, MAX_SCORE);
    const depth = clampInt(req.body?.depth, 0, MAX_DEPTH);

    if (!INITIALS_RE.test(initials) || score === null || depth === null) {
      return res.status(400).json({ error: 'bad_input' });
    }
    // light plausibility ceiling: a run can't realistically beat this for its depth
    if (score > (depth + 1) * 250_000) {
      return res.status(422).json({ error: 'implausible' });
    }

    try {
      await pool.query(
        `INSERT INTO paydirt_scores (initials, score, depth) VALUES ($1, $2, $3)`,
        [initials, score, depth]
      );
      res.status(201).json({ ok: true });
    } catch (err) {
      console.error('[paydirt] POST /scores', err);
      res.status(500).json({ error: 'server_error' });
    }
  });

  app.use(apiPath, api);

  console.log(`[paydirt] mounted: game ${staticPath}  api ${apiPath}  build ${buildDir}`);
};
