# Critter.gd — Base class for all mine critters (PackRat, Tommyknocker).
# State machine: PATROL → CHASE → GHOST → PUMPED → DEAD
# Axis-locked, cell-aligned movement like the player.

class_name Critter
extends CharacterBody2D

enum State { PATROL, CHASE, PUMPED, GHOST, DEAD }

# ---- exported ----
@export var critter_name: String = "Critter"
@export var is_tommyknocker: bool = false

# ---- state ----
var current_state: State = State.PATROL
var target_cell: Vector2i
var target_world: Vector2
var current_cell: Vector2i
var level_ref: Level
var player_ref: Player

# ---- ghost ----
var ghost_timer: float = 0.0
var ghost_target: Vector2

# ---- pump ----
var inflate_stage: int = 0
var pumping_player = null

# ---- cached ----
var _balance: Balance
var _speed: float


func _ready() -> void:
	_balance = GameState.get_balance()
	_speed = _balance.CRITTER_SPEED * _balance.TILE_SIZE
	_speed *= (1.0 + _balance.CRITTER_SPEED_SCALE * GameState.level_index)
	current_cell = level_ref.cell_at(global_position)
	target_cell = current_cell


func _physics_process(delta: float) -> void:
	match current_state:
		State.PATROL:
			_update_patrol(delta)
		State.CHASE:
			_update_chase(delta)
		State.GHOST:
			_update_ghost(delta)
		State.PUMPED:
			pass  # tethered, no movement
		State.DEAD:
			pass

	if current_state != State.PUMPED and current_state != State.DEAD:
		_move_toward_target()
		move_and_slide()

	# Update current cell
	var new_cell := level_ref.cell_at(global_position)
	if new_cell != current_cell:
		level_ref.unregister_critter_at(current_cell)
		current_cell = new_cell
		level_ref.register_critter_at(current_cell, self)

		# If ghost entered a tunnel, revert to CHASE
		if current_state == State.GHOST and level_ref.is_tunnel(current_cell):
			current_state = State.CHASE
			ghost_timer = 0.0


func _update_patrol(delta: float) -> void:
	# Wander tunnels with a bias toward player
	if _can_see_player():
		current_state = State.CHASE
		return

	# Check if stuck → ghost
	ghost_timer += delta
	if ghost_timer >= _balance.GHOST_TRIGGER:
		current_state = State.GHOST
		ghost_timer = 0.0
		return

	# Move along tunnels — pick random neighbor at junctions
	if _at_cell_center():
		var neighbors: Array[Vector2i] = []
		for n in level_ref.neighbors4(current_cell):
			if level_ref.is_tunnel(n) and level_ref.is_in_bounds(n):
				# Bias toward player direction
				neighbors.append(n)

		if neighbors.size() > 0:
			# Weighted: prefer cells closer to player
			var player_cell := level_ref.cell_at(player_ref.global_position)
			neighbors.sort_custom(func(a, b):
				return a.distance_squared_to(player_cell) < b.distance_squared_to(player_cell))
			# 70% chance pick best, 30% random
			if randf() < 0.7:
				target_cell = neighbors[0]
			else:
				target_cell = neighbors[randi() % neighbors.size()]
			target_world = level_ref.world_of(target_cell)

	if ghost_timer < _balance.GHOST_TRIGGER:
		ghost_timer += delta


func _update_chase(delta: float) -> void:
	var player_cell := level_ref.cell_at(player_ref.global_position)

	# Check if ghost should trigger
	if not _has_tunnel_path(current_cell, player_cell):
		ghost_timer += delta
		if ghost_timer >= _balance.GHOST_TRIGGER:
			current_state = State.GHOST
			ghost_target = player_ref.global_position
			ghost_timer = 0.0
			return
	else:
		ghost_timer = max(0.0, ghost_timer - delta * 2.0)

	# Recompute path at cell centers or periodically
	if _at_cell_center():
		_follow_astar_to(player_cell)


func _update_ghost(delta: float) -> void:
	# Move in a straight line through solid earth toward the player
	ghost_target = player_ref.global_position
	var dir := global_position.direction_to(ghost_target)
	velocity = dir * _balance.GHOST_SPEED * _balance.TILE_SIZE
	# Snap to cell center when entering a tunnel
	# (handled in physics_process by cell-change check)


func _move_toward_target() -> void:
	if current_state == State.GHOST:
		return  # ghost uses direct velocity
	if global_position.distance_to(target_world) < 2.0:
		global_position = target_world
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(target_world) * _speed


# ---- pump interface (called by Player) ----

func on_pumped(player) -> void:
	current_state = State.PUMPED
	pumping_player = player
	inflate_stage = 1
	velocity = Vector2.ZERO


func set_inflate_stage(stage: int) -> void:
	inflate_stage = stage
	_update_inflate_visual()


func on_released() -> void:
	pumping_player = null
	inflate_stage = 0
	current_state = State.CHASE


func on_popped() -> void:
	current_state = State.DEAD
	# Score is handled by the level/player based on layer and critter type
	_spawn_pop_fx()
	level_ref.on_critter_killed(self, current_cell)
	queue_free()


func _spawn_pop_fx() -> void:
	var fx := ColorRect.new()
	fx.color = Color(1.0, 0.8, 0.2, 0.8)
	fx.size = Vector2(_balance.TILE_SIZE * 0.8, _balance.TILE_SIZE * 0.8)
	fx.position = global_position - fx.size * 0.5
	level_ref.fx_node.add_child(fx)
	var tween := create_tween()
	tween.tween_property(fx, "scale", Vector2(2, 2), 0.3)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, 0.3)
	tween.tween_callback(fx.queue_free)


# ---- helpers ----

func _at_cell_center() -> bool:
	return global_position.distance_to(level_ref.world_of(current_cell)) < 2.0


func _can_see_player() -> bool:
	# Line-of-sight through tunnels only
	var player_cell := level_ref.cell_at(player_ref.global_position)
	if player_cell.x == current_cell.x:
		var step := 1 if player_cell.y > current_cell.y else -1
		for y in range(current_cell.y + step, player_cell.y, step):
			if level_ref.is_solid(Vector2i(current_cell.x, y)):
				return false
		return true
	elif player_cell.y == current_cell.y:
		var step := 1 if player_cell.x > current_cell.x else -1
		for x in range(current_cell.x + step, player_cell.x, step):
			if level_ref.is_solid(Vector2i(x, current_cell.y)):
				return false
		return true
	return false


func _has_tunnel_path(from: Vector2i, to: Vector2i) -> bool:
	return level_ref.tunnel_distance(from, to) < INF


func _follow_astar_to(target: Vector2i) -> void:
	var astar := level_ref.get_astar()
	var path := astar.get_id_path(current_cell, target)
	if path.size() >= 2:
		target_cell = path[1]  # next step
		target_world = level_ref.world_of(target_cell)


func _update_inflate_visual() -> void:
	# Placeholder: scale the sprite based on inflate_stage
	var scale_factor := 1.0 + inflate_stage * 0.15
	scale = Vector2(scale_factor, scale_factor)
	# Flash redder as stage increases
	modulate = Color(1.0, 1.0 - inflate_stage * 0.2, 1.0 - inflate_stage * 0.2)
