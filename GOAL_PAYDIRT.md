/goal — PAY DIRT (Miners Warehouse arcade game)
> **One-line objective:** Autonomously build a Dig-Dug-style 2D arcade game ("PAY DIRT") in Godot 4.6.2, mining/gold-prospecting themed, playable locally and exported to HTML5, served and embedded from the existing **Node.js** minerswarehouse app (same application, routes `/game/paydirt/` for the build and `/api/paydirt/*` for the leaderboard). Run end-to-end with no check-ins. Telegram on completion or hard blocker only.
---
0. Execution constraints (read first)
Orchestrator: Hermes (top-level). Reasoning/planning: DeepSeek-V4-Pro via Nous Portal. Implementation: Claude Code subprocess (`--dangerously-skip-permissions`). Bulk content (level configs, copy, leaderboard strings): local Qwen. Art/sprites/tilesets: ComfyUI (Flux2).
Autonomy: Run end-to-end. Do not request intermediate approval. Telegram-notify only on (a) all acceptance criteria in §7 met, or (b) a blocker unresolved after 3 attempts.
Engine: Godot 4.6.2 stable, GDScript only. No C# (web export for C# is still unreliable).
Repo: git, conventional commits, one logical commit per phase (§11). Project folder `paydirt/`. Node integration lives in the existing app (§6), not a separate service.
Build placeholder art FIRST (programmatic ColorRect/Polygon2D/AtlasTexture stand-ins) so the game is fully playable before any ComfyUI asset lands. Art is a swap-in pass, never a blocker.
"Done" = §7, verified — not "it runs once in the editor."
---
1. What we're building
A single-screen, grid-based tunnel-digging arcade game. A gold prospector digs through layered earth, collects gold, and clears mine critters with a hydraulic water blaster; falling cave-in boulders are the secondary kill. Clear all critters on a level to descend deeper. Classic Dig-Dug loop, fully re-skinned to gold mining.
Base presentation: internal resolution 480×360 (4:3), integer-scaled. Project stretch mode `canvas_items`, aspect `keep`. Pixel-art, nearest-neighbor filtering, no mipmaps. Top HUD band reserved; playfield below it.
Platform targets, priority order:
Local desktop playable (run-in-editor + Windows export) for fast iteration.
HTML5 / Web export, served by the Node app at `/game/paydirt/`, embeddable via iframe on any store page. This is the real deliverable.
---
2. Theme & naming
Working title: `PAY DIRT`. Backups if branding prefers clarity: `GOLD RUSH DIGGER`, `MOTHER LODE`.
Setting: a worked-out gold claim / mine shaft; depth increases each level.
Earth layers (palette shifts with depth): topsoil (warm brown) → clay (tan/ochre) → gravel (cool grey) → bedrock with glittering gold veins (near-black + gold flecks).
Aesthetic: chunky 8/16-bit arcade pixel art, warm earth tones, old-west prospector vibe. Optional looping banjo/harmonica chiptune.
---
3. Mechanics (port of Dig Dug, re-themed)
Dig Dug original	PAY DIRT version	Notes
Dig tunnels through dirt	Carve tunnels through earth tiles	Grid/TileMapLayer based, 4-directional
Pump/harpoon inflate-to-pop	Hydraulic water monitor — blast, then pump full of water in 4 stages until it bursts	Hold fire to inflate; release/timeout deflates; stage 4 = pop
Pooka (round critter)	Pack Rat — basic critter, scurries tunnels	Ghosts through dirt toward player when it can't path via tunnels
Fygar (fire-breather)	Tommyknocker — folklore mine gremlin, breathes flame in a straight line	More dangerous; telegraphed windup; flame kills player
Drop rocks to crush	Cave-in boulders — dig out support, boulder wobbles then falls, crushing critters/player in its column	Chain-crush = escalating bonus
Vegetable bonus at center	Mining gear bonus (gold pan, sluice box, metal detector, gem cluster)	Spawns after 2 boulders dropped, or on a timer
— (new)	Gold nuggets scattered in earth, collected when dug through	Adds a collect-objective + score, richer with depth
3.1 Detailed rules
Player: 3 lives. Dies on critter contact or Tommyknocker flame. Moves only through tunnel cells; initiating movement into an adjacent solid cell carves it (turns it to tunnel) over a short dig time. Facing direction = blast direction. Carrying no inventory; score-only.
Water blast (the monitor):
Fire spawns a short projectile traveling up to `BLAST_RANGE` cells in the facing direction along tunnel cells.
On hitting a critter: the critter enters PUMPED state and is tethered. Holding/repeatedly tapping fire advances inflate stage `0→1→2→3→4`. Each stage has a visible swell.
Releasing fire (or `DEFLATE_TIME` with no input) drops the critter one stage per `DEFLATE_STEP` until stage 0, then it resumes normal AI.
Stage 4 = burst → score (see §10), critter removed.
While a critter is pumped, the player is rooted (cannot move) — same risk/reward as Dig Dug.
Critters — shared: patrol tunnels; switch to CHASE when the player is in line-of-sight down a shared tunnel; enter GHOST when unable to path to the player via tunnels for `GHOST_TRIGGER` seconds (turn translucent, move in a straight line through solid earth toward the player at `GHOST_SPEED`, revert to tunnel-walk on re-entering a tunnel cell). Cannot be blasted while fully inside solid earth (ghosting); can be blasted in tunnels.
Tommyknocker (adds flame): when aligned with the player on the same row/column within `FLAME_RANGE` cells and in a tunnel, it performs `windup (FLAME_WINDUP, glowing telegraph) → breathe (FLAME_ACTIVE) → cooldown (FLAME_COOLDOWN)`. Flame fills the cells ahead; lethal to the player. Popping a Tommyknocker mid-breathe or from its flank scores double (see §10).
Boulders (cave-in): a boulder rests while the cell directly below is solid or another boulder. When its support becomes a tunnel and nothing holds it, it `wobbles (BOULDER_WOBBLE) → falls` at `BOULDER_FALL_SPEED`, crushing any critter or the player in its column, then shatters on landing. Multiple critters crushed by one fall = escalating chain bonus.
Nuggets / gems: embedded in earth cells; collected when the player carves that cell. Density and value rise with depth (nugget → gem → one Mother Lode jackpot per deep level).
Gear bonus: after 2 boulders have fallen (or `BONUS_TIMER` elapses), a gear item (pan/sluice/detector/gem cluster) spawns near playfield center for a limited time; collecting it awards depth-scaled points.
Level clear: all critters cleared → short "shaft cleared" interstitial → descend to next level (depth increases, palette shifts, difficulty scales per §10).
3.2 Tunable constants (export vars on a `Balance` resource — DO NOT hardcode)
```
TILE_SIZE            = 24      # px; playfield grid 20 cols x 13 rows under a 2-row HUD
PLAYER_MOVE_SPEED    = 4.0     # cells/sec through tunnels
PLAYER_DIG_TIME      = 0.18    # sec to carve one cell
BLAST_RANGE          = 3       # cells
INFLATE_STAGES       = 4
INFLATE_PER_PUMP     = 1       # stage gained per fire input
DEFLATE_TIME         = 1.2     # sec of no input before deflate starts
DEFLATE_STEP         = 0.5     # sec per stage lost
CRITTER_SPEED        = 3.0     # cells/sec in tunnels
GHOST_SPEED          = 1.6     # cells/sec through solid
GHOST_TRIGGER        = 4.0     # sec stuck before ghosting
FLAME_RANGE          = 3
FLAME_WINDUP         = 0.8
FLAME_ACTIVE         = 0.5
FLAME_COOLDOWN       = 2.5
BOULDER_WOBBLE       = 0.7
BOULDER_FALL_SPEED   = 10.0    # cells/sec
BONUS_TIMER          = 25.0
```
---
4. Brand / conversion hooks (game first — keep tasteful)
Title screen: "Miners Warehouse presents — PAY DIRT".
Win & game-over screens: CTA button → "Outfit your real claim: gold pans, sluices & detectors →", linking to a configurable `STORE_URL` constant (so the affiliate/landing target changes without a rebuild).
Gear bonus items mirror real store categories (pan / sluice / detector / classifier) — visual nod only, no mid-game popups.
Global leaderboard (see §6) drives repeat plays and dwell time — a marketing asset, not just a feature.
---
5. Technical architecture (for the implementation agent)
5.1 Scene tree
```
Main (Node)                      # router: Title -> Game -> GameOver; holds GameState ref
├── TitleScreen (Control)        # logo, Play, leaderboard preview, branding
├── Game (Node2D)
│   ├── Level (Node2D)           # owns grid + spawns; tracks clear condition
│   │   ├── EarthTileMap (TileMapLayer)   # solid/tunnel earth
│   │   ├── DecoTileMap (TileMapLayer)    # gold-vein deco, layer tinting
│   │   ├── Entities (Node2D)
│   │   │   ├── Player (CharacterBody2D)
│   │   │   ├── Critters (Node2D)         # PackRat / Tommyknocker instances
│   │   │   ├── Boulders (Node2D)
│   │   │   └── Pickups (Node2D)          # nuggets, gems, gear bonus
│   │   └── FX (Node2D)                   # bursts, dust, flame, popups
│   └── HUD (CanvasLayer)         # score, lives, depth(ft), gold
└── GameOverScreen (Control)      # score, initials entry, leaderboard, CTA
```
5.2 Autoloads (singletons)
GameState — `score`, `lives`, `depth`, `gold`, `level_index`, `STORE_URL`, `API_BASE`. Signals: `score_changed(v)`, `lives_changed(v)`, `depth_changed(v)`, `gold_changed(v)`, `game_over()`. Holds the active `Balance` resource and `LevelConfig` table.
Leaderboard — wraps the API client + offline fallback (§5.6).
Audio — SFX/music bus, play helpers.
5.3 Grid & digging model
Earth is a `TileMapLayer`. Each cell is logically SOLID or TUNNEL (track in a backing `PackedInt32Array`/2D dict keyed by `Vector2i`, kept in sync with the tilemap for fast queries).
Pickups, boulders, and vein-deco are tracked in their own cell-keyed dictionaries, not the earth array.
Carving: when the player commits to entering an adjacent SOLID cell, run `PLAYER_DIG_TIME`, then set that cell TUNNEL, update the tilemap (autotile edges for a clean tunnel look), collect any nugget/gem present, and re-evaluate boulder supports in the affected column.
Helper API on `Level`: `is_tunnel(cell)`, `carve(cell)`, `cell_at(world_pos)`, `world_of(cell)`, `neighbors4(cell)`.
5.4 Movement model
`Player` and critters use axis-locked, cell-aligned movement: they move continuously toward the next cell center; turns only allowed at cell centers. This reproduces the Dig Dug feel and keeps tunnel-following deterministic.
Player input: 4-direction; moving into a SOLID cell triggers carve-then-enter; moving into a TUNNEL cell just enters. Fire = blast/pump.
5.5 AI (state machines)
`Critter` base class with `state`: `PATROL | CHASE | PUMPED | GHOST | DEAD`.
PATROL: follow tunnels, bias toward the player at junctions (weighted random so they don't all clump).
CHASE: A* over tunnel cells toward the player; recompute on junction or every `0.5s`.
GHOST: if no tunnel path to player for `GHOST_TRIGGER`, lerp in a straight line through solids toward the player at `GHOST_SPEED`; on entering a tunnel cell, revert to CHASE.
PUMPED: tethered + inflating per §3.1; stage 4 → DEAD (score), else deflate → PATROL/CHASE.
`PackRat` = base only. `Tommyknocker` = base + flame sub-behavior (§3.1) usable from PATROL/CHASE when aligned.
Pathfinding: `AStarGrid2D` constrained to tunnel cells, rebuilt incrementally as cells are carved.
5.6 Leaderboard client (game side) — GDScript sketch
```gdscript
# Leaderboard.gd (autoload). API_BASE comes from GameState (e.g. "/api/paydirt").
extends Node
signal scores_loaded(list)         # Array of {initials, score, depth}
signal submit_done(ok)

func fetch_top() -> void:
    var http := HTTPRequest.new(); add_child(http)
    http.request_completed.connect(func(_r, code, _h, body):
        if code == 200:
            var data = JSON.parse_string(body.get_string_from_utf8())
            scores_loaded.emit(data if data is Array else [])
        else:
            scores_loaded.emit(_local_top())          # offline fallback
        http.queue_free())
    var err := http.request(GameState.API_BASE + "/scores")
    if err != OK: scores_loaded.emit(_local_top())

func submit(initials: String, score: int, depth: int) -> void:
    _local_save(initials, score, depth)               # always cache locally
    var http := HTTPRequest.new(); add_child(http)
    var payload := JSON.stringify({"initials": initials, "score": score, "depth": depth})
    http.request_completed.connect(func(_r, code, _h, _b):
        submit_done.emit(code == 201 or code == 200); http.queue_free())
    http.request(GameState.API_BASE + "/scores", ["Content-Type: application/json"],
        HTTPClient.METHOD_POST, payload)

# Offline fallback: web -> localStorage via JavaScriptBridge; desktop -> user:// ConfigFile.
func _local_save(i, s, d): ...
func _local_top() -> Array: ...
```
---
6. Web export & deployment — Node.js, same app
The game's static build is served by the existing minerswarehouse Node/Express app at `/game/paydirt/`, and the leaderboard API at `/api/paydirt/*`, reusing the app's existing PostgreSQL pool. Because we own the server, we set headers directly — no `coi-serviceworker` hack required.
6.1 Export
Install Godot 4.6.2 Web export templates in the headless/CI build environment.
Preset: Web (HTML5), output `paydirt/build/index.html`, renderer Compatibility (WebGL2) for max browser reach.
Threading: default to single-threaded (disable "Thread Support" in the Web preset). A 2D tilemap game needs no worker threads, and single-threaded requires no cross-origin-isolation headers — it embeds anywhere with zero server gymnastics. (Threaded path documented in §6.5 for completeness; do not enable unless profiling proves a need.)
Copy `paydirt/build/` into the app's served assets, e.g. `app/public/game/paydirt/`.
6.2 Same-app integration module
A single mountable module wires both static serving and the API. Reuse the app's existing `pg` pool — do not open a new one.
```js
// paydirt.js  —  registerPaydirt(app, pool)
const path = require('path');
const express = require('express');
const rateLimit = require('express-rate-limit');

const INITIALS_RE = /^[A-Z0-9]{1,3}$/;
const MAX_SCORE = 9_999_999;

function clampInt(v, lo, hi) {
  v = Number.parseInt(v, 10);
  if (!Number.isFinite(v)) return null;
  return Math.min(hi, Math.max(lo, v));
}

module.exports = function registerPaydirt(app, pool) {
  // --- static game build ---
  const buildDir = path.join(__dirname, 'public', 'game', 'paydirt');
  app.use('/game/paydirt', express.static(buildDir, {
    setHeaders(res, filePath) {
      if (filePath.endsWith('.wasm')) res.setHeader('Content-Type', 'application/wasm');
      if (filePath.endsWith('index.html')) res.setHeader('Cache-Control', 'no-cache');
      else res.setHeader('Cache-Control', 'public, max-age=31536000, immutable'); // hashed assets
    },
  }));

  // --- leaderboard API ---
  const api = express.Router();
  api.use(express.json({ limit: '4kb' }));

  const postLimiter = rateLimit({ windowMs: 60_000, max: 10, standardHeaders: true, legacyHeaders: false });

  api.get('/scores', async (_req, res) => {
    try {
      const { rows } = await pool.query(
        'SELECT initials, score, depth FROM paydirt_scores ORDER BY score DESC, created_at ASC LIMIT 10'
      );
      res.json(rows);
    } catch (e) { console.error('[paydirt] scores GET', e); res.status(500).json({ error: 'server_error' }); }
  });

  api.post('/scores', postLimiter, async (req, res) => {
    const initials = String(req.body?.initials ?? '').toUpperCase().slice(0, 3);
    const score = clampInt(req.body?.score, 0, MAX_SCORE);
    const depth = clampInt(req.body?.depth, 0, 100000);
    if (!INITIALS_RE.test(initials) || score === null || depth === null)
      return res.status(400).json({ error: 'bad_input' });
    // light plausibility check: score must be reachable for the claimed depth
    if (score > (depth + 1) * 250_000) return res.status(422).json({ error: 'implausible' });
    try {
      await pool.query(
        'INSERT INTO paydirt_scores (initials, score, depth) VALUES ($1, $2, $3)',
        [initials, score, depth]
      );
      res.status(201).json({ ok: true });
    } catch (e) { console.error('[paydirt] scores POST', e); res.status(500).json({ error: 'server_error' }); }
  });

  app.use('/api/paydirt', api);
};
```
Mount in the main app once: `require('./paydirt')(app, pool);` (after the pool and any global `compression()` middleware are set up).
6.3 PostgreSQL schema (idempotent migration)
```sql
CREATE TABLE IF NOT EXISTS paydirt_scores (
  id          BIGSERIAL PRIMARY KEY,
  initials    CHAR(3)     NOT NULL,
  score       INTEGER     NOT NULL CHECK (score >= 0 AND score <= 9999999),
  depth       INTEGER     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_paydirt_scores_score ON paydirt_scores (score DESC, created_at ASC);
```
6.4 Anti-cheat note
Client scores are inherently untrusted. For a marketing-site arcade board, the layering is good enough: input validation + server-side clamp + per-IP rate limit + a depth-vs-score plausibility ceiling. Full server-authoritative simulation is explicitly out of scope.
6.5 Optional threaded path (only if needed)
If a threaded export is ever required, set isolation headers on the game route and keep that route free of cross-origin scripts:
```js
app.use('/game/paydirt', (_req, res, next) => {
  res.set('Cross-Origin-Opener-Policy', 'same-origin');
  res.set('Cross-Origin-Embedder-Policy', 'require-corp');
  next();
});
```
COEP `require-corp` will block any cross-origin resource on that route lacking CORP/`crossorigin` — keep the game standalone and embed via iframe.
6.6 Compression
Enable `compression()` middleware (gzip) app-wide or on `/game/paydirt`; Godot `.wasm`/`.pck` compress well. Brotli precompression + serving `.br` with `Content-Encoding: br` is a nice optimization but not required for "done."
6.7 Embed snippet (responsive iframe)
```html
<div class="paydirt-embed" style="position:relative;width:100%;max-width:720px;margin:0 auto;aspect-ratio:4/3;">
  <iframe src="/game/paydirt/" title="PAY DIRT — Miners Warehouse"
          loading="lazy" allow="autoplay; fullscreen"
          style="position:absolute;inset:0;width:100%;height:100%;border:0;border-radius:8px;"></iframe>
</div>
```
6.8 Smoke test (headless, required)
Load `/game/paydirt/` headlessly (e.g. Puppeteer/Playwright): assert HTTP 200, `.wasm` served as `application/wasm`, the Godot canvas initializes, and zero console errors. Hit `GET /api/paydirt/scores` (expect 200 + JSON array) and a valid + an invalid `POST` (expect 201 / 4xx). Do not declare done on the editor build alone.
---
7. Acceptance criteria (Definition of Done)
Complete only when ALL hold:
[ ] Playable in the Godot editor and as a Windows export.
[ ] All core mechanics work: digging/carving, water-blast inflate-to-pop (4 stages), Pack Rats, Tommyknocker flame (telegraphed), critter ghost-through-dirt, boulder wobble→fall→crush (+chain bonus), nugget/gem/gear pickups, level clear → descend.
[ ] ≥5 hand-tuned levels + procedural fallback beyond level 5, with a rising difficulty curve per §10.
[ ] HUD complete (score, 3 lives, depth ft, gold). Title, level-intro, and game-over screens present; all balance values come from the `Balance` resource (no magic numbers in logic).
[ ] Backend leaderboard works in the live web build: `GET`/`POST /api/paydirt/scores` against the app's PostgreSQL, server-side validation/clamp + rate limit, top-10 display on title + game-over, initials entry, and `localStorage`/`user://` fallback when the API is unreachable.
[ ] Branding present: title attribution + configurable `STORE_URL` CTA on win/lose screens.
[ ] HTML5 build loads via the Node `/game/paydirt/` route with zero console errors, verified headlessly per §6.8; `.wasm` served as `application/wasm`; default single-threaded (no isolation headers).
[ ] Copy-paste iframe embed snippet (§6.7) produced and confirmed working on a test store page.
[ ] Art: final ComfyUI sprites/tilesets OR clean programmatic placeholders — visually coherent either way (placeholder acceptable for "done"; final art is stretch).
[ ] Repo committed; `README.md` documents run, export, the `registerPaydirt(app, pool)` mount, the SQL migration, and deploy.
---
8. Asset list (ComfyUI / Flux2 — stretch, after gameplay works)
Pixel-art, consistent palette, small dimensions (use a pixel-art LoRA if base Flux is inconsistent; otherwise keep placeholders). Author sprites at `TILE_SIZE`-compatible dimensions.
Prospector: idle, walk ×4 dir, blasting pose.
Pack Rat: walk, ghost, inflate ×4, pop.
Tommyknocker: walk, ghost, windup, flame-breath, inflate ×4, pop.
Water blast: projectile + spray.
Boulder (rest, wobble, shatter); optional ore-cart.
Pickups: gold nugget, gem cluster, gold pan, sluice box, metal detector, Mother Lode nugget.
Tilesets (autotile): topsoil, clay, gravel, bedrock-with-vein, incl. tunnel-edge tiles.
UI: PAY DIRT logo, HUD icons (gold, life, depth), button frames.
---
9. Audio (optional / placeholder OK for v1)
Chiptune SFX: dig, blast, pump, pop, boulder-fall, pickup, flame, death, level-clear. Looping prospector banjo/harmonica track. CC0 sources acceptable — document licensing in README.
---
10. Scoring & balancing (concrete)
10.1 Scoring
Action	Points
Pop Pack Rat	200 / 300 / 400 / 500 by layer (topsoil→bedrock)
Pop Tommyknocker	400 / 600 / 800 / 1000 by layer; ×2 if popped mid-breathe or from the flank
Boulder crush (chain)	1000, 2500, 4000, 6000, 8000, 10000, 12000, 15000 for 1–8 critters in one fall
Gold nugget	100
Gem cluster	500
Gear bonus	1000 / 2000 / 3000 / 5000 by layer
Mother Lode (deep-level jackpot)	5000
Level clear bonus	250 × level_index
10.2 Level curve (LevelConfig 1–10; ≥11 procedural)
Lvl	Layer	Critters	Tommyknocker ratio	Boulders	Nugget density	Mother Lode
1	topsoil	3	0%	2	low	no
2	topsoil	4	0%	2	low	no
3	clay	4	25%	3	med	no
4	clay	5	25%	3	med	no
5	gravel	5	40%	3	med	yes
6	gravel	6	40%	4	high	yes
7	gravel	6	50%	4	high	yes
8	bedrock	7	50%	4	high	yes
9	bedrock	7	60%	5	rich	yes
10	bedrock	8	60%	5	rich	yes
Critter base speed scales `CRITTER_SPEED × (1 + 0.05 × level_index)`. Qwen mass-generates layouts to this schema; the implementation agent defines the JSON/resource schema first.
---
11. Suggested phase plan (Hermes may re-plan)
Plan (DeepSeek): finalize scene tree, `Balance`/`LevelConfig` schemas, grid model — commit `docs:`.
Core loop (Claude Code): grid + carve + player movement, placeholder art → playable digging. Commit `feat: core loop`.
Combat & hazards: water blaster/pump, both critters + AI (incl. ghost + flame), boulders. Commit `feat: combat`.
Economy & flow: nuggets/gems/gear, HUD, title/level-intro/gameover, branding/CTA. Commit `feat: economy+ui`.
Content: Qwen generates levels 1–10 + procedural fallback; tune to §10. Commit `feat: levels`.
Node integration: export, `registerPaydirt`, SQL migration, leaderboard client, iframe snippet, headless smoke test (§6.8). Commit `feat: web+api`.
Art pass (ComfyUI): generate + integrate sprites/tilesets/audio if quality/time allow. Commit `feat: art`.
Verify §7, write README, Telegram: done with build path, route URLs, and embed snippet. Commit `chore: release`.
---
Run silent. Telegram only on completion (all §7 met) or an unrecoverable blocker after 3 attempts.
