# PAY DIRT — Implementation Plan

> **For Hermes:** Execute via delegate_task subagents (Claude Code) for each phase.

**Goal:** Build Dig-Dug-style 2D arcade mining game in Godot 4.6.2, playable locally +
exported to HTML5, served from Node.js minerswarehouse app at /game/paydirt/.

**Architecture:** Single-screen grid-based tunnel-digging game. TileMapLayer earth,
CharacterBody2D player, state-machine critters, Godot autoloads for GameState/Leaderboard/Audio.
Internal 480×360, integer-scaled, nearest-neighbor, pixel-art.

**Tech Stack:** Godot 4.6.2, GDScript, Node.js/Express integration module, PostgreSQL leaderboard.

---

## Phase 1: Foundation — project scaffold + Balance + grid model

**Commit:** `feat: foundation — project scaffold, Balance, grid model`

### Task 1.1: Create project.godot with correct settings
- Stretch mode: canvas_items, aspect: keep
- Resolution: 480×360
- Filtering: nearest, no mipmaps
- Autoloads: GameState, Leaderboard, Audio

### Task 1.2: Balance resource (balance.gd)
- All tunable constants as @export vars
- TILE_SIZE, speeds, inflate stages, boulder params, bonus timer etc.

### Task 1.3: LevelConfig resource (level_config.gd)
- Per-level: layer enum, critter count, tommyknocker ratio, boulder count, nugget density, mother_lode flag
- Levels 1-10 hand-tuned; procedural generator for 11+

### Task 1.4: GameState autoload (game_state.gd)
- score, lives, depth_ft, gold, level_index
- Balance ref, LevelConfig table
- Store URL constant
- Signals: score_changed, lives_changed, depth_changed, gold_changed, game_over

### Task 1.5: Level grid model (level.gd)
- EarthTileMap + DecoTileMap
- SOLID/TUNNEL cell tracking dict
- carve(cell), is_tunnel(cell), cell_at(world_pos), world_of(cell), neighbors4(cell)
- Boulder support tracking per column

### Task 1.6: Placeholder art system
- ColorRect-based sprites for all entities (player, critters, boulders, pickups)
- Polygon2D placeholders for directional sprites
- Colored earth layers per palette

---

## Phase 2: Core Loop — dig + move + placeholder playable

**Commit:** `feat: core loop — player movement, digging, placeholders`

### Task 2.1: Player scene (CharacterBody2D)
- Axis-locked, cell-aligned movement
- 4-directional input
- Move into SOLID triggers carve-then-enter
- Placeholder sprite (colored rect + hat shape)

### Task 2.2: EarthTileMap + carve system
- Autotile for tunnel edges
- Carve animation (brief dig delay)
- Nugget/gem collection on carve

### Task 2.3: Camera + scaling
- Integer-scaled viewport
- Follow player within playfield bounds

### Task 2.4: HUD stubs (CanvasLayer)
- Score, lives, depth, gold labels
- Wired to GameState signals

### Task 2.5: Title screen stub
- "PAY DIRT" text
- Play button → Game scene
- Miners Warehouse branding

---

## Phase 3: Combat — water blaster, critters, AI, boulders

**Commit:** `feat: combat — blaster, PackRat, Tommyknocker, boulders`

### Task 3.1: Water blaster system
- Fire in facing direction, BLAST_RANGE cells
- Projectile visual (stretched rect/particles)
- Tether critter on hit

### Task 3.2: Inflate/pump mechanic
- Stages 0→1→2→3→4 with visual swell
- Hold fire to advance, release to deflate
- Player rooted while pumping
- Stage 4 = pop → score

### Task 3.3: Critter base class + PackRat
- State machine: PATROL, CHASE, PUMPED, GHOST, DEAD
- AStarGrid2D pathfinding on tunnel cells
- Ghost-through-solid behavior
- PackRat = base only

### Task 3.4: Tommyknocker
- Extends base critter with FLAME sub-behavior
- Windup → breathe → cooldown
- Lethal flame in straight line
- Double score for flank/mid-breathe pop

### Task 3.5: Boulders (cave-in)
- Rest while cell below is solid
- Wobble → fall when support becomes tunnel
- Crush critters/player in column
- Chain-crush bonus scoring

---

## Phase 4: Economy & UI flow

**Commit:** `feat: economy+ui — pickups, HUD, screens, branding`

### Task 4.1: Nuggets, gems, Mother Lode
- Embedded in earth cells, collected on carve
- Value scales with depth
- Visual: gold dots / sparkles

### Task 4.2: Gear bonus system
- Spawns after 2 boulder drops or BONUS_TIMER
- Pan, sluice, detector, gem cluster variants
- Depth-scaled points

### Task 4.3: Full HUD implementation
- Animated score counter, lives as hearts/icons
- Depth display (ft), gold count
- Smooth transitions

### Task 4.4: Title screen polish
- Animated logo
- Leaderboard preview (top 5)
- Play button, branding

### Task 4.5: Level-intro interstitial
- "Level N — [layer name] — [depth] ft"
- Brief animation before gameplay

### Task 4.6: Game over screen
- Final score, depth reached
- Initials entry (3 chars, A-Z 0-9)
- Leaderboard display
- CTA: "Outfit your real claim →" linking to STORE_URL
- Play again button

---

## Phase 5: Level content

**Commit:** `feat: levels — 10 hand-tuned + procedural fallback`

### Task 5.1: Level layout system
- Define level layouts as resource files
- Grid-based: critter spawn points, boulder positions, earth fill pattern
- Nugget density map

### Task 5.2: Levels 1-10
- Follow LevelConfig table from spec
- Layout variety (open chambers, tight corridors, pillar arrangements)
- Progressive difficulty

### Task 5.3: Procedural generator (level 11+)
- Random critter placement
- Scaled difficulty
- Ensures playability (connected tunnels, reachable areas)

---

## Phase 6: Web export + Node integration

**Commit:** `feat: web+api — HTML5 export, paydirt.js, leaderboard`

### Task 6.1: Godot web export preset
- Web (HTML5), renderer Compatibility (WebGL2)
- Single-threaded (no SharedArrayBuffer)
- Output: paydirt/build/index.html

### Task 6.2: paydirt.js integration module
- registerPaydirt(app, pool) function
- Static serving of /game/paydirt/ with correct headers
- Leaderboard API: GET/POST /api/paydirt/scores
- Rate limiting, input validation, plausibility check

### Task 6.3: SQL migration
- paydirt_scores table with index
- Idempotent CREATE IF NOT EXISTS

### Task 6.4: Godot Leaderboard autoload
- HTTPRequest-based client
- fetch_top() and submit(initials, score, depth)
- Offline fallback: web→localStorage, desktop→ConfigFile

### Task 6.5: Headless smoke test
- Serve via Node, load with Puppeteer/Playwright
- Assert: 200, .wasm as application/wasm, canvas initializes, zero console errors
- Test leaderboard API endpoints

### Task 6.6: Embed snippet
- Responsive iframe with 4:3 aspect ratio

---

## Phase 7: Art pass (ComfyUI, stretch)

**Commit:** `feat: art — sprite and tileset pass`

### Task 7.1: Sprite generation
- All entities at TILE_SIZE-compatible dimensions
- Pixel-art style, consistent palette

### Task 7.2: Tileset generation
- Earth layers with autotile edges
- Tunnel variants

### Task 7.3: UI assets
- Logo, icons, button frames

---

## Phase 8: Verification + release

**Commit:** `chore: release — README, deploy docs, final verification`

### Task 8.1: Full acceptance criteria check
- All §7 items verified
- Editor, Windows export, HTML5 export all working

### Task 8.2: README.md
- How to run/edit/export
- registerPaydirt mount instructions
- SQL migration
- Deploy steps

### Task 8.3: git tag + Telegram notification
- Deliverable summary
