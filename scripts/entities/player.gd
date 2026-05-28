# Player.gd — MINIMAL: cell-aligned movement, no physics, no state machine.
extends Node2D

enum State { IDLE, MOVING, DIGGING }
var current_state: int = State.IDLE
var target_pos: Vector2 = Vector2.ZERO
var _speed: float = 96.0  # px/sec (4 cells/sec * 24px)
var _dig_time: float = 0.18
var dig_timer: Timer

# References set by Game
var level_ref  # set before add_child
var _balance  # set before add_child


func _ready() -> void:
	_speed = _balance.PLAYER_MOVE_SPEED * _balance.TILE_SIZE
	_dig_time = _balance.PLAYER_DIG_TIME
	dig_timer = $DigTimer
	dig_timer.one_shot = true
	dig_timer.timeout.connect(_on_dig_done)


func _physics_process(delta: float) -> void:
	if current_state == State.IDLE:
		var dx: int = int(Input.get_axis("move_left", "move_right"))
		var dy: int = int(Input.get_axis("move_up", "move_down"))
		if dx == 0 and dy == 0:
			return

		# Axis lock
		if dx != 0: dy = 0

		var cur: Vector2i = level_ref.cell_at(global_position)
		var nxt: Vector2i = cur + Vector2i(dx, dy)
		if not level_ref.is_in_bounds(nxt):
			return

		if level_ref.is_tunnel(nxt):
			current_state = State.MOVING
			target_pos = level_ref.world_of(nxt)
		else:
			current_state = State.DIGGING
			target_pos = level_ref.world_of(nxt)
			dig_timer.start(_dig_time)

	elif current_state == State.MOVING:
		if global_position.distance_squared_to(target_pos) < 4.0:
			global_position = target_pos
			current_state = State.IDLE
		else:
			var dir: Vector2 = global_position.direction_to(target_pos)
			global_position += dir * _speed * delta


func _on_dig_done() -> void:
	if current_state == State.DIGGING:
		level_ref.carve(level_ref.cell_at(target_pos))
		current_state = State.MOVING
