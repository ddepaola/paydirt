You are implementing a complete Godot 4.6.2 2D arcade game called "PAY DIRT" at /home/dominick/projects/paydirt.

Godot binary: ~/.local/bin/godot (v4.6.2.stable)
Export templates installed: ~/.local/share/godot/export_templates/4.6.2.stable/templates/

=== CRITICAL: Read the implementation plan and spec ===
Read these two files for full requirements:
1. /home/dominick/projects/paydirt/.hermes/plans/2026-05-28-paydirt-implementation.md (phase plan)
2. The user's original specification is embedded in the existing code — read all .gd files to understand the architecture.

=== WHAT EXISTS ALREADY ===
The project has a foundation with parse errors. Your job is to FIX ALL PARSE ERRORS and COMPLETE THE GAME.

Existing files:
- project.godot — Godot project config (autoloads: GameState, Leaderboard, Audio)
- autoload/game_state.gd — game state singleton (score, lives, depth, gold, level)
- autoload/leaderboard.gd — HTTP leaderboard client with offline fallback
- autoload/audio.gd — audio manager stub
- scripts/balance/balance.gd + balance.tres — all tunable constants (TILE_SIZE=24, speeds, etc.)
- scripts/levels/level_config.gd — per-level config resource
- scripts/systems/level.gd — grid model, tilemap, A*, boulder tracking
- scripts/entities/player.gd — axis-locked, cell-aligned player with dig+blast+pump
- scripts/entities/critter.gd — base critter: PATROL/CHASE/GHOST/PUMPED/DEAD state machine
- scripts/entities/pack_rat.gd — basic critter
- scripts/entities/tommyknocker.gd — flame-breathing critter
- scripts/entities/boulder.gd — cave-in boulder (wobble→fall→crush)
- scenes/main/main.tscn + main.gd — scene router (Title→Game→GameOver)
- scenes/title/title_screen.gd — title screen
- scenes/game/game.gd — gameplay coordinator (spawning, level transitions)
- scenes/gameover/game_over_screen.gd — game over, initials, CTA
- scripts/ui/hud.gd — HUD (score, lives, depth, gold)

=== YOUR TASK ===

Complete the game end-to-end. Priorities:

1. FIX ALL PARSE ERRORS first (run `~/.local/bin/godot --headless --quit` to see them). The main issues:
   - class_name scripts not being recognized (use `const MyClass = preload("res://path/to/script.gd")` at the top of files that need them, and remove class_name)
   - Type inference warnings treated as errors (add explicit types everywhere, or add `# warning-ignore:untyped_declaration` annotations)
   - TileMapLayer.tile_set needs a proper TileSet resource, not created in code

2. COMPLETE ALL MECHANICS:
   - Grid-based earth with TileMapLayer (colored rects for placeholder earth layers)
   - Player: axis-locked cell-aligned movement, dig into solid cells, water blaster
   - Water blaster: fire in facing direction, hit critter → PUMPED state, 4 inflate stages → pop
   - PackRat: PATROL tunnels, CHASE via A*, GHOST through solids
   - Tommyknocker: same as PackRat + flame breath (windup→breathe→cooldown)
   - Boulders: wobble→fall→crush chain bonus
   - Nuggets/gems: embedded in earth, collected on carve
   - Gear bonus: spawns after 2 boulders or timer

3. COMPLETE ALL SCREENS:
   - Title: logo, play button, leaderboard preview
   - Level intro: "LEVEL N — LAYER — DEPTH FT"
   - HUD: score, lives, depth, gold (wired to GameState signals)
   - Game over: final score, initials entry, leaderboard, CTA button (STORE_URL)

4. LEVELS:
   - Create 10 LevelConfig resources for levels 1-10
   - Procedural generator for level 11+
   - Placeholder earth layer colors: topsoil (warm brown), clay (tan), gravel (grey), bedrock (near-black)

5. WEB EXPORT:
   - Create export_presets.cfg with Web (HTML5) preset
   - Renderer: Compatibility (WebGL2), single-threaded
   - Export to build/index.html
   - Test: `~/.local/bin/godot --headless --export-release "Web" build/index.html`

6. SCORING (from Balance resource):
   - PackRat pop: 200/300/400/500 by layer
   - Tommyknocker pop: 400/600/800/1000 ×2 if flank/mid-breathe
   - Boulder chain: 1000-15000
   - Nugget: 100, Gem: 500, Mother Lode: 5000
   - Level clear: 250 × level_index

=== APPROACH ===

Work iteratively:
1. Run `~/.local/bin/godot --headless --quit` to check for errors
2. Fix errors one by one
3. When the project loads clean (no parse errors), test gameplay
4. Continue until all mechanics work

Use realistic but simple placeholder art: ColorRect + Polygon2D for sprites, colored TileMapLayer cells for earth. The game must be PLAYABLE with placeholders.

=== COMPLETION ===

When the game loads clean and mechanics work, export to Web and verify:
- `~/.local/bin/godot --headless --export-release "Web" build/index.html` succeeds
- The build directory contains index.html, .js, .wasm, .pck files

Then write a summary of what you did, any remaining issues, and the build path.

WORK SILENTLY. Do not ask questions — make decisions and move forward. If stuck on something for >3 attempts, document the issue and move on.
