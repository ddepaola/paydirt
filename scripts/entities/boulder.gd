# Boulder.gd — Cave-in hazard.
# Rests while supported by solid earth or another boulder below.
# Wobbles then falls when support is removed. Crushes anything in its column.

class_name Boulder
extends CharacterBody2D

enum State { REST, WOBBLE, FALLING, SHATTERED }

var current_state: State = State.REST
var level_ref  # (Level — untyped)
var my_cell: Vector2i
var _balance  # (Balance — untyped)
var _fall_speed: float
var _wobble_time: float


func _ready() -> void:
	_balance = GameState.get_balance()
	_fall_speed = _balance.BOULDER_FALL_SPEED * _balance.TILE_SIZE
	_wobble_time = _balance.BOULDER_WOBBLE
	global_position = level_ref.world_of(my_cell)


func trigger_fall() -> void:
	if current_state != State.REST:
		return
	current_state = State.WOBBLE
	_do_wobble()


func _do_wobble() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + 2, 0.1)
	tween.tween_property(self, "position:x", position.x - 2, 0.1)
	tween.tween_property(self, "position:x", position.x, 0.1)
	tween.tween_callback(_start_fall)
	Audio.play_sfx("boulder_wobble")


func _start_fall() -> void:
	current_state = State.FALLING
	Audio.play_sfx("boulder_fall")
	# Fall straight down, checking each cell we pass through
	_continue_fall()


func _continue_fall() -> void:
	var cell_below := my_cell + Vector2i.DOWN

	# Stop if out of bounds or hitting solid earth
	if not level_ref.is_in_bounds(cell_below) or level_ref.is_solid(cell_below):
		_shatter()
		return

	# Crush anything in this cell (critter or player)
	var critter = level_ref.get_critter_at(cell_below)
	if critter:
		critter.on_crushed()
		_bump_chain_bonus()

	# Check player
	if level_ref.player_ref:
		var player_cell: Vector2i = level_ref.cell_at(level_ref.player_ref.global_position)
		if player_cell == cell_below:
			level_ref.player_ref.die()
			_shatter()
			return

	# Stop if hitting another boulder
	if level_ref.has_boulder_at(cell_below):
		# Land on the boulder below
		my_cell = cell_below
		level_ref.unregister_boulder_at(my_cell)
		level_ref.register_boulder(self, my_cell)
		global_position = level_ref.world_of(my_cell)
		current_state = State.REST
		return

	# Move down one cell
	level_ref.unregister_boulder_at(my_cell)
	my_cell = cell_below
	level_ref.register_boulder(self, my_cell)

	var tween := create_tween()
	tween.tween_property(self, "global_position", level_ref.world_of(my_cell), _balance.TILE_SIZE / _fall_speed)
	tween.tween_callback(_continue_fall)


func _shatter() -> void:
	current_state = State.SHATTERED
	# Check if player is in the cell we land on
	if level_ref.player_ref:
		var player_cell: Vector2i = level_ref.cell_at(level_ref.player_ref.global_position)
		if player_cell == my_cell:
			level_ref.player_ref.die()

	_spawn_shatter_fx()
	level_ref.unregister_boulder_at(my_cell)
	queue_free()


func _spawn_shatter_fx() -> void:
	for i in range(4):
		var fx := ColorRect.new()
		fx.color = Color(0.4, 0.35, 0.3)
		fx.size = Vector2(6, 6)
		fx.position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 0))
		level_ref.fx_node.add_child(fx)
		var tween := create_tween()
		tween.tween_property(fx, "position", fx.position + Vector2(randf_range(-20, 20), randf_range(-20, 5)), 0.4)
		tween.parallel().tween_property(fx, "modulate:a", 0.0, 0.4)
		tween.tween_callback(fx.queue_free)


var _chain_count: int = 0


func _bump_chain_bonus() -> void:
	_chain_count += 1
	var pts_idx: int = min(_chain_count - 1, _balance.BOULDER_CHAIN.size() - 1)
	var pts: int = _balance.BOULDER_CHAIN[pts_idx]
	GameState.add_score(pts)


func on_crushed() -> void:
	current_state = State.SHATTERED
	level_ref.on_critter_killed(self, my_cell)
	queue_free()


# Placeholder drawing
func _draw() -> void:
	var size: float = _balance.TILE_SIZE * 0.7
	draw_circle(Vector2.ZERO, size * 0.5, Color(0.35, 0.3, 0.28))
	draw_arc(Vector2.ZERO, size * 0.5, 0, PI, 8, Color(0.45, 0.4, 0.38), 2.0)
