# PAY DIRT — Deliverable Plan

## Current State (v0.5)

Core gameplay works: dig, move, boulders, tilemap rendering, HUD, screens.

## Remaining for v1.0 Deliverable

### 1. Art (ComfyUI / Flux2 Pixel-Art) — Highest Impact

Every asset is currently a colored rectangle. The game needs proper 24×24 pixel-art sprites.

**Tilesets (TILE_SIZE=24, atlas 5 columns × 1 row):**
- Topsoil tile (warm brown with texture/grain)
- Clay tile (tan/ochre with variation)
- Gravel tile (cool grey with speckles)
- Bedrock tile (near-black with gold vein flecks)
- Tunnel tile (dark with subtle edge highlights)
- *Each tile needs 4 directional edge variants for autotile (optional but nice)*

**Player (prospector, 24×24, 4 directions × 2 frames idle/walk):**
- Idle: standing, holding water monitor nozzle
- Walk: 2-frame stride animation for each direction
- Blast: firing pose (can reuse idle + nozzle flash)

**Pack Rat (24×24, 4 states):**
- Walk/patrol (2 frames)
- Ghost (translucent, no animation needed — just tint)
- Inflate stages 1-4 (visibly swelling)
- Pop (explosion frame)

**Tommyknocker (24×24, 5 states):**
- Walk/patrol (2 frames)
- Ghost (translucent)
- Windup (glowing telegraph — orange pulse)
- Flame breath (flame projectile sprite, 3 cells long)
- Inflate stages 1-4 + pop

**Boulder (24×24, 3 states):**
- Rest (round grey stone)
- Wobble (offset, no new sprite needed)
- Shatter (4-6 debris fragments)

**Pickups (16×16 or 24×24):**
- Gold nugget (gold lump)
- Gem cluster (multi-colored gems)
- Mother Lode (large golden nugget with sparkle)
- Gold pan (bonus item)
- Sluice box (bonus item)
- Metal detector (bonus item)

**UI:**
- PAY DIRT logo (for title screen)
- HUD icons: life (pickaxe or heart), gold (nugget), depth (drill/arrow)
- Button frames (Play, Submit, Play Again, CTA)

**Environment:**
- Optional: ore cart, mine support beams, lantern decoration tiles

**Workflow:**
1. Generate each sprite in ComfyUI with pixel-art LoRA if base Flux is inconsistent
2. Export as PNG at 2x or 4x source size, scale down to TILE_SIZE
3. Import into Godot, set nearest-neighbor filtering
4. Replace placeholder ColorRect/Sprite2D textures with new atlas/sprite sheets
5. Create animation frames where needed (AnimationPlayer or AnimatedSprite2D)

### 2. Audio (Chiptune SFX + Music)

Currently silent. Needs CC0-licensed or custom chiptune assets.

**SFX (8-bit style, ~0.1-0.5s each):**
- Dig: short scrape/rumble
- Blast fire: water hiss/spray
- Pump: inflation squeak (per stage)
- Pop: burst/explosion
- Boulder wobble: creak
- Boulder fall: rumble
- Boulder crush: smash
- Pickup: coin ding (pitch up for gems)
- Flame: whoosh
- Player death: descending tone
- Level clear: ascending fanfare

**Music:**
- Title screen: looping banjo/harmonica melody (old-west prospector)
- Gameplay: up-tempo chiptune mining track, optional depth layers

**Sources:**
- https://opengameart.org (CC0 chiptune packs)
- https://freesound.org (CC0)
- Or generate with tools like BFXR, sfxr, or Suno AI for music

**Integration:**
- Place .ogg files in `assets/audio/`
- Audio autoload will pick them up automatically
- Wire SFX to game events (already partially wired with `Audio.play_sfx()` calls)

### 3. Gameplay Polish

**Critter AI:**
- PackRats currently don't pathfind or chase effectively
- Need A* pathfinding working (AStarGrid2D setup exists but may need tuning)
- Ghost-through-dirt behavior triggers but may not look right
- Tommyknocker flame telegraph and activation needs visual tuning

**Level Design:**
- Current levels 1-10 use random tunnel placement from the starter pocket
- Need hand-designed layouts with interesting chambers and corridors
- Each level should have: spawn points, boulder positions, gold placement
- Progressive difficulty: more critters, faster, deeper layers

**Visual Polish:**
- Tunnel edge autotiling (so tunnels have smooth borders, not hard grid edges)
- Particle effects: dirt spray when digging, gold sparkles on pickup
- Screen shake on boulder fall
- Score popup animations (floating +NUMBER text)
- Smooth camera follow (optional, current is fixed)
- Life loss animation (flash/knockback)

**HUD Polish:**
- Animated score counter (ticks up)
- Gold count with nugget icon
- Lives as heart/pickaxe icons
- Depth display with animated drill arrow

### 4. Leaderboard & API

**Backend:**
- Deploy `paydirt.js` to the minerswarehouse Node/Express app
- Run SQL migration (`migrations/001_paydirt_scores.sql`) on the PostgreSQL database
- Test GET/POST endpoints with curl
- Add CORS headers to the API responses for cross-origin iframe embeds

**Game Client:**
- Wire leaderboard display on title screen (currently disabled on WSL)
- Wire score submission on game over screen
- Test fallback to localStorage when API is unreachable

### 5. Web Export & Deploy

**Build pipeline:**
- `godot --headless --export-release "Web" build/index.html`
- Copy `build/` contents to the app's `public/game/paydirt/` directory
- Ensure Content-Type headers for .wasm (application/wasm)

**Embed:**
- Add the iframe snippet to the minerswarehouse store page
- Test responsive layout at 720px max-width, 4:3 aspect ratio

**Smoke test (headless):**
- Assert HTTP 200 for /game/paydirt/index.html
- Assert application/wasm for .wasm files
- Assert GET /api/paydirt/scores returns 200 + JSON array
- Assert POST valid score returns 201
- Assert POST invalid score returns 400

### 6. Prioritization

| Priority | Item | Effort | Impact |
|----------|------|--------|--------|
| P0 | Player + critter sprites | 4h | Transformative |
| P0 | Earth tileset | 2h | Transformative |
| P0 | Tunnels look right (autotile or edge tiles) | 2h | High |
| P1 | Chiptune SFX pack | 1h | High |
| P1 | Boulder/bonus pickup sprites | 1h | High |
| P1 | HUD icons | 1h | Medium |
| P2 | Gameplay loop: level layout pass | 3h | High |
| P2 | Particle effects + screen shake | 2h | Medium |
| P2 | Animated score/lives/gold | 1h | Medium |
| P3 | Background music track | 2h | Low |
| P3 | Level-intro / game-over polish | 1h | Low |
| P3 | Leaderboard deploy + test | 2h | Medium |

### 7. Estimated Timeline (sequential)

- **Days 1-2:** Art generation (ComfyUI pixel-art pass) — sprites + tileset
- **Day 3:** Audio — SFX pack, wire into game events
- **Day 4:** Gameplay polish — AI tuning, level layouts, particles
- **Day 5:** Leaderboard deploy, web export, smoke test, store page embed
- **Day 6:** Final polish, bug bash, README, release

### 8. File Inventory (what needs changing)

| File | What |
|------|------|
| `assets/sprites/prospector.png` | Player sprite sheet (NEW) |
| `assets/sprites/packrat.png` | PackRat sprite sheet (NEW) |
| `assets/sprites/tommyknocker.png` | Tommyknocker sprite sheet (NEW) |
| `assets/sprites/boulder.png` | Boulder sprites (NEW) |
| `assets/sprites/pickups.png` | Nugget/gem/bonus sprites (NEW) |
| `assets/tilesets/earth.png` | Earth tileset (NEW) |
| `assets/audio/*.ogg` | SFX and music files (NEW) |
| `scripts/entities/player.gd` | Add AnimatedSprite2D, animation frames |
| `scripts/entities/critter.gd` | Add AnimatedSprite2D, state-driven animation |
| `scripts/systems/level.gd` | Autotile setup or edge-tile logic |
| `scenes/game/game.gd` | Particles, screen shake |
| `scenes/gameover/game_over_screen.gd` | Score submission feedback |
| `paydirt.js` | Add CORS headers |
| `README.md` | Update with deploy instructions |
