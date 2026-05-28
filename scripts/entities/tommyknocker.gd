# Tommyknocker.gd — Mine gremlin critter.
# Extends Critter with a flame-breath sub-behavior.
# Windup (glow telegraph) → breathe (lethal flame column) → cooldown.
# Double points if popped mid-breathe or from the flank.

class_name Tommyknocker
extends Critter

enum FlameState { IDLE, WINDUP, ACTIVE, COOLDOWN }

var flame_state: FlameState = FlameState.IDLE
var flame_timer: float = 0.0
var flame_dir: Vector2i     # direction flame will fire


func _ready() -> void:
	super()
	critter_name = "Tommyknocker"
	is_tommyknocker = true
	flame_timer = randf() * _balance.FLAME_COOLDOWN  # stagger initial cooldown


func _physics_process(delta: float) -> void:
	super(delta)
	if current_state == State.PUMPED or current_state == State.DEAD:
		return
	_update_flame(delta)


func _update_flame(delta: float) -> void:
	match flame_state:
		FlameState.IDLE:
			flame_timer -= delta
			if flame_timer <= 0.0 and _aligned_with_player():
				_start_flame()
			# Also check if we're in CHASE/PATROL and aligned
			if _aligned_with_player() and (current_state == State.CHASE or current_state == State.PATROL):
				flame_timer -= delta * 2.0  # faster trigger when aligned

		FlameState.WINDUP:
			flame_timer -= delta
			modulate = Color(1.0, 0.7, 0.3, 0.8 + 0.2 * sin(flame_timer * 20.0))  # glow pulse
			if flame_timer <= 0.0:
				flame_state = FlameState.ACTIVE
				flame_timer = _balance.FLAME_ACTIVE
				_spawn_flame()

		FlameState.ACTIVE:
			flame_timer -= delta
			modulate = Color(1.0, 0.3, 0.1)
			if flame_timer <= 0.0:
				flame_state = FlameState.COOLDOWN
				flame_timer = _balance.FLAME_COOLDOWN
				modulate = Color(1.0, 1.0, 1.0)

		FlameState.COOLDOWN:
			flame_timer -= delta
			if flame_timer <= 0.0:
				flame_state = FlameState.IDLE


func _aligned_with_player() -> bool:
	var pc := level_ref.cell_at(player_ref.global_position)
	# Same row or same column
	if pc.x != current_cell.x and pc.y != current_cell.y:
		return false
	# Check range
	if abs(pc.x - current_cell.x) + abs(pc.y - current_cell.y) > _balance.FLAME_RANGE:
		return false
	# Check line of sight (tunnels only)
	if pc.x == current_cell.x:
		var step := 1 if pc.y > current_cell.y else -1
		for y in range(current_cell.y + step, pc.y, step):
			if level_ref.is_solid(Vector2i(current_cell.x, y)):
				return false
	else:
		var step := 1 if pc.x > current_cell.x else -1
		for x in range(current_cell.x + step, pc.x, step):
			if level_ref.is_solid(Vector2i(x, current_cell.y)):
				return false
	# Store flame direction
	if pc.x == current_cell.x:
		flame_dir = Vector2i(0, 1 if pc.y > current_cell.y else -1)
	else:
		flame_dir = Vector2i(1 if pc.x > current_cell.x else -1, 0)
	return true


func _start_flame() -> void:
	flame_state = FlameState.WINDUP
	flame_timer = _balance.FLAME_WINDUP


func _spawn_flame() -> void:
	# Check if player is in the flame column
	var pc := level_ref.cell_at(player_ref.global_position)
	var step := current_cell + flame_dir
	for _i in range(_balance.FLAME_RANGE):
		if not level_ref.is_in_bounds(step):
			break
		if level_ref.is_solid(step):
			break
		if step == pc:
			player_ref.die()
			return
		step += flame_dir

	# Visual FX: flame column
	var fx_start := level_ref.world_of(current_cell + flame_dir)
	var fx_end := level_ref.world_of(step - flame_dir)
	_draw_flame_fx(fx_start, fx_end)
	Audio.play_sfx("flame")


func _draw_flame_fx(from: Vector2, to: Vector2) -> void:
	var fx := ColorRect.new()
	fx.color = Color(1.0, 0.4, 0.1, 0.8)
	var ext := to - from
	if abs(ext.x) > abs(ext.y):
		fx.size = Vector2(abs(ext.x) + _balance.TILE_SIZE, _balance.TILE_SIZE * 0.5)
		fx.position = Vector2(min(from.x, to.x) - _balance.TILE_SIZE * 0.5, from.y - _balance.TILE_SIZE * 0.25)
	else:
		fx.size = Vector2(_balance.TILE_SIZE * 0.5, abs(ext.y) + _balance.TILE_SIZE)
		fx.position = Vector2(from.x - _balance.TILE_SIZE * 0.25, min(from.y, to.y) - _balance.TILE_SIZE * 0.5)
	level_ref.fx_node.add_child(fx)
	var tween := create_tween()
	tween.tween_property(fx, "modulate:a", 0.0, 0.3)
	tween.tween_callback(fx.queue_free)


func set_inflate_stage(stage: int) -> void:
	super(stage)
	# Cancel any active flame
	if flame_state == FlameState.ACTIVE or flame_state == FlameState.WINDUP:
		flame_state = FlameState.COOLDOWN
		flame_timer = _balance.FLAME_COOLDOWN * 0.5
		modulate = Color(1.0, 1.0, 1.0)


## Returns true if popped during a vulnerable state (mid-breathe or flank)
func is_crit_pop() -> bool:
	return flame_state == FlameState.ACTIVE or flame_state == FlameState.WINDUP


func _draw() -> void:
	var size := Vector2(_balance.TILE_SIZE * 0.6, _balance.TILE_SIZE * 0.7)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(0.3, 0.5, 0.3), true)  # greenish body
	# Glowing eyes
	if flame_state == FlameState.WINDUP or flame_state == FlameState.ACTIVE:
		draw_circle(Vector2.ZERO, 3, Color(1.0, 0.3, 0.0))
	else:
		draw_rect(Rect2(Vector2(-3, -6), Vector2(3, 3)), Color(1.0, 0.9, 0.0), true)
		draw_rect(Rect2(Vector2(1, -6), Vector2(3, 3)), Color(1.0, 0.9, 0.0), true)
