# GameState.gd — Autoload singleton
# Holds all persistent game state: score, lives, depth, gold, level index.
# Also holds references to Balance and LevelConfig resources.

extends Node

# ---- constants ----
const STORE_URL := "https://minerswarehouse.com/collections/prospecting"
const API_BASE := "/api/paydirt"
const MAX_LIVES := 3
const INITIALS_LENGTH := 3

# ---- signals ----
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal depth_changed(new_depth: int)
signal gold_changed(new_gold: int)
signal game_over()
signal gear_bonus_spawned(item: String, points: int)

# ---- state ----
var score: int = 0
var lives: int = MAX_LIVES
var depth: int = 0          # current depth in feet
var gold: int = 0            # nuggets/gems collected
var level_index: int = 0     # 0-based; incremented on clear
var boulders_dropped_this_level: int = 0
var bonus_timer_active: bool = false

# ---- resources (set at startup) ----
var balance: Resource   # Balance resource
var level_configs: Array = []  # Array[LevelConfig]


func reset() -> void:
	score = 0
	lives = MAX_LIVES
	depth = 0
	gold = 0
	level_index = 0
	boulders_dropped_this_level = 0
	bonus_timer_active = false


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		game_over.emit()


func on_boulder_dropped() -> void:
	boulders_dropped_this_level += 1
	if boulders_dropped_this_level >= 2:
		bonus_timer_active = false


func next_level() -> void:
	level_index += 1
	depth += _depth_for_level(level_index)
	depth_changed.emit(depth)
	boulders_dropped_this_level = 0
	bonus_timer_active = false


func _depth_for_level(lvl: int) -> int:
	return 15 + lvl * 30


func get_balance() -> Resource:
	return balance


func get_level_config(lvl: int) -> Resource:
	if lvl < level_configs.size():
		return level_configs[lvl]
	return _procedural_config(lvl)


func _procedural_config(lvl: int) -> Resource:
	# Create a LevelConfig inline with dictionary-style init
	var cfg: Resource = load("res://scripts/levels/level_config.gd").new()
	cfg.level_number = lvl + 1
	cfg.layer = 3 if lvl >= 7 else 2 if lvl >= 5 else 1 if lvl >= 3 else 0
	cfg.critter_count = 4 + int(lvl * 0.6)
	cfg.tommyknocker_pct = 0.5 + lvl * 0.02
	cfg.boulder_count = 3 + int(lvl * 0.3)
	cfg.nugget_density = 0.5 + lvl * 0.05
	cfg.has_mother_lode = lvl >= 5
	return cfg
