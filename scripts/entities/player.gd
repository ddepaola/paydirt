# Player.gd — Prospector character.
# Axis-locked, cell-aligned movement. Carves into solid cells.
# Fires water blaster. Rooted while pumping a critter.

class_name Player
extends CharacterBody2D

enum Dir { UP, DOWN, LEFT, RIGHT }
enum State { IDLE, MOVING, DIGGING, BLASTING, PUMPING, DEAD }

# ---- node refs ----
@onready var sprite: Sprite2D = $Sprite
@onready var dig_timer: Timer = $DigTimer

# ---- state ----
var facing: Dir = Dir.DOWN
var current_state: State = State.IDLE
var target_cell: Vector2i
var target_world: Vector2
var level_ref: Level

# ---- pump state ----
var pumped_critter = null
var inflate_stage: int = 0
var deflate_timer: float = 0.0
var pump_input: bool = false

# ---- cached balance ----
var _balance: Balance
var _move_speed: float
var _dig_time: float
var _blast_range: int


func _ready() -> void:
	_balance = GameState.get_balance()
	_move_speed = _balance.PLAYER_MOVE_SPEED * _balance.TILE_SIZE  # px/sec
	_dig_time = _balance.PLAYER_DIG_TIME
	_blast_range = _balance.BLAST_RANGE

	dig_timer.one_shot = true
	dig_timer.timeout.connect(_on_dig_complete)


func _process(delta: float) -> void:
	match current_state:
		State.PUMPING:
			_process_pump(delta)


func _physics_process(_delta: float) -> void:
	match current_state:
		State.IDLE, State.MOVING, State.DIGGING:
			_handle_movement()
		State.PUMPING:
			pass  # rooted — no movement


func _handle_movement() -> void:
	if current_state == State.DIGGING:
		return  # waiting for dig to complete

	var input_dir := Vector2i(
		int(Input.get_axis("move_left", "move_right")),
		int(Input.get_axis("move_up", "move_down"))
	)

	if Input.is_action_just_pressed("fire") and current_state != State.DIGGING:
		_try_blast()
		return

	if input_dir == Vector2i.ZERO:
		current_state = State.IDLE
		velocity = Vector2.ZERO
		return

	# Axis-locked: prefer horizontal if both pressed
	if input_dir.x != 0:
		input_dir.y = 0

	# Only turn at cell centers
	var current_cell := level_ref.cell_at(global_position)
	var at_center := global_position.distance_to(level_ref.world_of(current_cell)) < 2.0

	if not at_center and current_state != State.MOVING:
		# Still sliding to a center; keep going
		pass
	elif at_center and input_dir != Vector2i.ZERO:
		var next_cell := current_cell + input_dir
		if not level_ref.is_in_bounds(next_cell):
			current_state = State.IDLE
			velocity = Vector2.Zero
			return

		if level_ref.is_solid(next_cell):
			# Start digging
			current_state = State.DIGGING
			target_cell = next_cell
			target_world = level_ref.world_of(next_cell)
			facing = _dir_from_vec(input_dir)
			_update_sprite()
			dig_timer.start(_dig_time)
			velocity = Vector2.ZERO
		else:
			# Move into tunnel
			current_state = State.MOVING
			target_cell = next_cell
			target_world = level_ref.world_of(next_cell)
			facing = _dir_from_vec(input_dir)
			_update_sprite()
			velocity = global_position.direction_to(target_world) * _move_speed

	if current_state == State.MOVING:
		if global_position.distance_to(target_world) < 2.0:
			global_position = target_world
			current_state = State.IDLE
			velocity = Vector2.ZERO
		else:
			velocity = global_position.direction_to(target_world) * _move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func _on_dig_complete() -> void:
	if current_state == State.DIGGING:
		level_ref.carve(target_cell)
		# Move into the newly carved cell
		current_state = State.MOVING
		velocity = global_position.direction_to(target_world) * _move_speed


func _try_blast() -> void:
	if current_state == State.PUMPING:
		_pump_critter()
		return

	# Fire water blast in facing direction
	current_state = State.BLASTING
	_spawn_blast()
	await get_tree().create_timer(0.15).timeout
	if current_state == State.BLASTING:
		current_state = State.IDLE


func _spawn_blast() -> void:
	var dir_vec := _vec_from_dir(facing)
	var start_cell := level_ref.cell_at(global_position)

	for i in range(1, _blast_range + 1):
		var check_cell := start_cell + dir_vec * i
		if not level_ref.is_in_bounds(check_cell):
			break
		if level_ref.is_solid(check_cell):
			break  # blast stops at solid earth

		# Check for critter in this tunnel cell
		var hit := level_ref.get_critter_at(check_cell)
		if hit:
			_attach_pump(hit, check_cell)
			return

	# Blast visual FX (transient)
	_show_blast_fx(start_cell + dir_vec, start_cell + dir_vec * min(_blast_range, 3))


func _attach_pump(critter, cell: Vector2i) -> void:
	pumped_critter = critter
	inflate_stage = 0
	deflate_timer = 0.0
	current_state = State.PUMPING
	critter.on_pumped(self)
	Audio.play_sfx("blast_hit")


func _process_pump(delta: float) -> void:
	if Input.is_action_just_pressed("fire"):
		pump_input = true
		_pump_critter()

	if not Input.is_action_pressed("fire") and pump_input:
		pump_input = false

	# Deflate over time
	if not pump_input:
		deflate_timer += delta
		while deflate_timer >= _balance.DEFLATE_STEP and inflate_stage > 0:
			inflate_stage -= 1
			deflate_timer -= _balance.DEFLATE_STEP
			if pumped_critter:
				pumped_critter.set_inflate_stage(inflate_stage)

		if inflate_stage == 0:
			_detach_pump()


func _pump_critter() -> void:
	deflate_timer = 0.0
	inflate_stage += _balance.INFLATE_PER_PUMP
	if pumped_critter:
		pumped_critter.set_inflate_stage(min(inflate_stage, _balance.INFLATE_STAGES))

	if inflate_stage >= _balance.INFLATE_STAGES:
		_pop_critter()


func _pop_critter() -> void:
	if pumped_critter:
		var critter = pumped_critter
		_detach_pump()
		critter.on_popped()
		Audio.play_sfx("pop")


func _detach_pump() -> void:
	if pumped_critter:
		pumped_critter.on_released()
		pumped_critter = null
	inflate_stage = 0
	deflate_timer = 0.0
	current_state = State.IDLE


func _show_blast_fx(from: Vector2i, to: Vector2i) -> void:
	# Placeholder: spawn a colored line or particles along the blast path
	var fx := ColorRect.new()
	fx.color = Color(0.3, 0.6, 1.0, 0.7)
	fx.size = Vector2(_balance.TILE_SIZE * (to.x - from.x + 1), _balance.TILE_SIZE * 0.25)
	fx.position = level_ref.world_of(from) - Vector2(_balance.TILE_SIZE * 0.5, _balance.TILE_SIZE * 0.125)
	level_ref.fx_node.add_child(fx)
	var tween := create_tween()
	tween.tween_property(fx, "modulate:a", 0.0, 0.2)
	tween.tween_callback(fx.queue_free)


func die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	Audio.play_sfx("player_death")
	# Death animation
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		GameState.lose_life()
		level_ref.player_died.emit()
	)


# ---- helpers ----

func _vec_from_dir(d: Dir) -> Vector2i:
	match d:
		Dir.UP:    return Vector2i.UP
		Dir.DOWN:  return Vector2i.DOWN
		Dir.LEFT:  return Vector2i.LEFT
		Dir.RIGHT: return Vector2i.RIGHT
	return Vector2i.DOWN


func _dir_from_vec(v: Vector2i) -> Dir:
	if v.y < 0: return Dir.UP
	if v.y > 0: return Dir.DOWN
	if v.x < 0: return Dir.LEFT
	return Dir.RIGHT


func _update_sprite() -> void:
	if not sprite:
		return
	# Placeholder: rotate/change frame based on facing
	match facing:
		Dir.UP:    sprite.rotation_degrees = 0
		Dir.DOWN:  sprite.rotation_degrees = 180
		Dir.LEFT:  sprite.rotation_degrees = 90
		Dir.RIGHT: sprite.rotation_degrees = 270
