# PAY DIRT — Miners Warehouse Arcade Game

Dig-Dug-style 2D mining arcade game built in Godot 4.6.2.
Dig tunnels, blast critters with a water monitor, collect gold, and descend deeper into the mine.

## Quick Start

```bash
# Run in Godot editor
godot --editor .

# Or headless export
godot --headless --export-release "Web" build/index.html
```

## Project Structure

```
paydirt/
├── project.godot              # Godot project config (480×360, canvas_items stretch)
├── autoload/                  # Singleton scripts
│   ├── game_state.gd          # Score, lives, depth, gold, level state
│   ├── leaderboard.gd         # HTTP client for /api/paydirt/scores
│   └── audio.gd               # SFX/music manager
├── scenes/
│   ├── main/                  # Scene router (Title → Game → GameOver)
│   ├── title/                 # Title screen
│   ├── game/                  # Gameplay coordinator
│   └── gameover/              # Game over screen
├── scripts/
│   ├── balance/               # Tunable constants (Balance resource)
│   ├── entities/              # Player, critters, boulders
│   ├── levels/                # Level configuration
│   ├── systems/               # Grid model, tilemap, A*
│   └── ui/                    # HUD
├── export_presets.cfg         # Web (HTML5) export preset
├── paydirt.js                 # Node.js Express integration module
├── migrations/                # PostgreSQL schema
└── embed-snippet.html         # Copy-paste iframe snippet for store pages
```

## Node.js Integration

Mount the game and leaderboard API into any Express app:

```js
const registerPaydirt = require('./paydirt');
registerPaydirt(app, pool);  // app = Express app, pool = pg Pool
```

This registers:
- `GET/POST /api/paydirt/scores` — leaderboard API
- `GET /game/paydirt/*` — static game build (place `build/` contents at `public/game/paydirt/`)

### Database Migration

Run `migrations/001_paydirt_scores.sql` against your PostgreSQL database:

```sql
psql $DATABASE_URL < migrations/001_paydirt_scores.sql
```

## Embedding

Copy the iframe snippet from `embed-snippet.html` into any store page:

```html
<div class="paydirt-embed" style="position:relative;width:100%;max-width:720px;margin:0 auto;aspect-ratio:4/3;">
  <iframe src="/game/paydirt/" title="PAY DIRT — Miners Warehouse"
          loading="lazy" allow="autoplay; fullscreen"
          style="position:absolute;inset:0;width:100%;height:100%;border:0;border-radius:8px;"></iframe>
</div>
```

## Controls

- **WASD / Arrow Keys** — Move and dig through earth
- **Space / J** — Fire water blaster (hold to pump critters until they burst)

## Mechanics

| Action | Points |
|--------|--------|
| Pop Pack Rat | 200–500 (by layer) |
| Pop Tommyknocker | 400–1000 (×2 if flank/mid-breathe) |
| Boulder crush (chain) | 1000–15000 |
| Gold nugget | 100 |
| Gem cluster | 500 |
| Mother Lode | 5000 |
| Gear bonus | 1000–5000 |
| Level clear | 250 × level |

## Art

Placeholder art (colored rectangles) is used for all entities. Final pixel-art sprites and tilesets are generated via ComfyUI/Flux as a stretch goal.

## Audio

Audio is optional — the game runs silently without audio assets. CC0 chiptune SFX and a looping banjo track are planned.

## Web Export

- Renderer: Compatibility (WebGL2)
- Single-threaded (no SharedArrayBuffer required)
- Embeds anywhere via iframe — no COOP/COEP headers needed
- Build output: `build/index.html` + `.js` + `.wasm` + `.pck`
