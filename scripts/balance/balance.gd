# Balance.gd — Resource holding all tunable game constants.
# DO NOT hardcode these values in game logic scripts.
# Always read from Balance resource via GameState.get_balance().

class_name Balance
extends Resource

# ---- grid ----
@export var TILE_SIZE: int = 24
@export var GRID_COLS: int = 20
@export var GRID_ROWS: int = 13          # playfield (below 2-row HUD)
@export var HUD_ROWS: int = 2

# ---- player ----
@export var PLAYER_MOVE_SPEED: float = 4.0      # cells/sec through tunnels
@export var PLAYER_DIG_TIME: float = 0.18        # sec to carve one cell

# ---- water blaster ----
@export var BLAST_RANGE: int = 3                  # cells
@export var INFLATE_STAGES: int = 4
@export var INFLATE_PER_PUMP: int = 1             # stages gained per fire press
@export var DEFLATE_TIME: float = 1.2             # sec of no input before deflate
@export var DEFLATE_STEP: float = 0.5             # sec per stage lost

# ---- critters ----
@export var CRITTER_SPEED: float = 3.0            # cells/sec in tunnels
@export var GHOST_SPEED: float = 1.6              # cells/sec through solid
@export var GHOST_TRIGGER: float = 4.0            # sec stuck before ghosting
@export var CRITTER_SPEED_SCALE: float = 0.05     # +5% per level

# ---- tommyknocker flame ----
@export var FLAME_RANGE: int = 3
@export var FLAME_WINDUP: float = 0.8
@export var FLAME_ACTIVE: float = 0.5
@export var FLAME_COOLDOWN: float = 2.5

# ---- boulders ----
@export var BOULDER_WOBBLE: float = 0.7
@export var BOULDER_FALL_SPEED: float = 10.0      # cells/sec

# ---- bonuses ----
@export var BONUS_TIMER: float = 25.0
@export var GEAR_BONUS_VALUES: Array[int] = [1000, 2000, 3000, 5000]  # by layer

# ---- scoring ----
@export var PACKRAT_POP_BASE: Array[int] = [200, 300, 400, 500]       # by layer
@export var TOMMYKNOCKER_POP_BASE: Array[int] = [400, 600, 800, 1000]  # by layer
@export var TOMMYKNOCKER_CRIT_MULT: int = 2                            # flank/mid-breathe
@export var BOULDER_CHAIN: Array[int] = [1000, 2500, 4000, 6000, 8000, 10000, 12000, 15000]
@export var NUGGET_VALUE: int = 100
@export var GEM_VALUE: int = 500
@export var MOTHER_LODE_VALUE: int = 5000
@export var LEVEL_CLEAR_BONUS: int = 250                               # × level_index
