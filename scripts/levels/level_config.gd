# LevelConfig.gd — Resource describing one level's parameters.
class_name LevelConfig
extends Resource

enum Layer { TOPSOIL, CLAY, GRAVEL, BEDROCK }

@export var level_number: int = 1
@export var layer: Layer = Layer.TOPSOIL
@export var critter_count: int = 3
@export var tommyknocker_pct: float = 0.0      # 0.0 - 1.0
@export var boulder_count: int = 2
@export var nugget_density: float = 0.0         # 0.0 - 1.0 (lo = sparse, hi = rich)
@export var has_mother_lode: bool = false

## How many Tommyknockers to spawn (rounds down).
func tommyknocker_count() -> int:
	return int(critter_count * tommyknocker_pct)

## How many Pack Rats to spawn (remainder).
func packrat_count() -> int:
	return critter_count - tommyknocker_count()

## Layer index for scoring tables (0=topsoil, 1=clay, 2=gravel, 3=bedrock).
func layer_index() -> int:
	return layer as int
