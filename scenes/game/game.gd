# Game.gd — Main gameplay coordinator for PAY DIRT.
# Uses load().new() for all entity scripts — no class_name deps.
# Player is Node2D (not CharacterBody2D) to avoid llvmpipe hang.

extends Node2D

const SCRIPT_LEVEL = "res://scripts/systems/level.gd"
const SCRIPT_PLAYER = "res://scripts/entities/player.gd"
const SCRIPT_PACKRAT = "res://scripts/entities/pack_rat.gd"
const SCRIPT_TOMMYKNOCKER = "res://scripts/entities/tommyknocker.gd"
const SCRIPT_BOULDER = "res://scripts/entities/boulder.gd"

var current_level
var player
var _balance
var _grid_offset: Vector2i = Vector2i(0, 2)


func _ready() -> void:
	_balance = _load_balance()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.04)
	bg.size = Vector2(480, 360)
	add_child(bg)
	move_child(bg, 0)


func _load_balance():
	if ResourceLoader.exists("res://scripts/balance/balance.tres"):
		var b = load("res://scripts/balance/balance.tres")
		GameState.balance = b
		return b
	var b = load("res://scripts/balance/balance.gd").new()
	GameState.balance = b
	return b


func start_level(lvl_idx: int) -> void:
	if current_level:
		current_level.queue_free()

	var LevelClass = load(SCRIPT_LEVEL)
	var level = LevelClass.new()
	level.name = "Level"

	_create_earth_tilemap(level)

	var entities: Node2D = Node2D.new()
	entities.name = "Entities"
	level.add_child(entities)
	level.entities_node = entities

	var fx: Node2D = Node2D.new()
	fx.name = "FX"
	level.add_child(fx)
	level.fx_node = fx

	add_child(level)
	current_level = level

	if level.has_signal("level_cleared"):
		level.level_cleared.connect(_on_level_cleared)
	if level.has_signal("player_died"):
		level.player_died.connect(_on_player_died)

	var cfg = GameState.get_level_config(lvl_idx)
	level._balance = _balance
	level._config = cfg
	level._setup_grid()
	_spawn_player(level)
	_spawn_critters(level, cfg)
	_spawn_boulders(level, cfg)
	_spawn_pickups(level, cfg)
	_show_level_intro(lvl_idx, cfg)


func _create_earth_tilemap(level) -> void:
	var tm: TileMapLayer = TileMapLayer.new()
	tm.name = "EarthTileMap"
	# No position offset — cell coordinates match grid coordinates directly

	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(_balance.TILE_SIZE, _balance.TILE_SIZE)

	var tw: int = _balance.TILE_SIZE
	var img: Image = Image.create_empty(tw * 5, tw, false, Image.FORMAT_RGBA8)

	var colors: Array[Color] = [
		Color(0.55, 0.35, 0.15), Color(0.65, 0.50, 0.25),
		Color(0.40, 0.42, 0.45), Color(0.12, 0.10, 0.08),
		Color(0.04, 0.04, 0.06),
	]
	for col_i: int in 5:
		var c: Color = colors[col_i]
		for px: int in tw:
			for py: int in tw:
				var noise: float = randf_range(-0.04, 0.04)
				var nc: Color = Color(clamp(c.r + noise, 0, 1), clamp(c.g + noise, 0, 1), clamp(c.b + noise, 0, 1))
				if px == 0 or px == tw - 1 or py == 0 or py == tw - 1:
					nc = Color(nc.r * 0.7, nc.g * 0.7, nc.b * 0.7)
				img.set_pixel(col_i * tw + px, py, nc)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(tw, tw)
	for col_i: int in 5:
		atlas.create_tile(Vector2i(col_i, 0))
	ts.add_source(atlas)
	tm.tile_set = ts
	level.add_child(tm)
	level.earth_tilemap = tm


func _spawn_player(level) -> void:
	var PlayerClass = load(SCRIPT_PLAYER)
	var p = PlayerClass.new()
	p.name = "Player"
	var start_cell: Vector2i = Vector2i(_balance.GRID_COLS / 2, _grid_offset.y + 1)
	p.global_position = Vector2((start_cell.x + 0.5) * _balance.TILE_SIZE,
		(start_cell.y + 0.5) * _balance.TILE_SIZE)
	p.level_ref = level
	p._balance = _balance

	# Load prospector sprite texture from Gemini-gen PNG
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite"
	if ResourceLoader.exists("res://assets/sprites/prospector.png"):
		var tex = load("res://assets/sprites/prospector.png")
		sprite.texture = tex
		# Scale 1024x1024 source down to 24x24 game size
		sprite.scale = Vector2(_balance.TILE_SIZE / 1024.0, _balance.TILE_SIZE / 1024.0)
		# Shader to make white background transparent
		if ResourceLoader.exists("res://assets/sprites/make_transparent.gdshader"):
			var shd = load("res://assets/sprites/make_transparent.gdshader")
			var mat = ShaderMaterial.new()
			mat.shader = shd
			mat.set_shader_parameter("threshold", 0.85)
			sprite.material = mat
	else:
		# Fallback: placeholder colored sprite
		var simg: Image = Image.create(_balance.TILE_SIZE, _balance.TILE_SIZE, false, Image.FORMAT_RGBA8)
		simg.fill(Color(0.15, 0.35, 0.65))
		sprite.texture = ImageTexture.create_from_image(simg)
	p.add_child(sprite)

	var timer: Timer = Timer.new()
	timer.name = "DigTimer"; timer.one_shot = true
	p.add_child(timer); p.dig_timer = timer

	level.entities_node.add_child(p)
	level.register_player(p)
	player = p


func _spawn_critters(level, cfg) -> void:
	var cc: int = cfg.critter_count
	var tk: int = cfg.tommyknocker_count()
	var tunnel_cells: Array = level._get_all_tunnel_cells()
	if tunnel_cells.size() < 2: return
	tunnel_cells.shuffle()

	var player_cell: Vector2i = level.cell_at(player.global_position)
	var spawned: int = 0; var idx: int = 0
	var PRClass = load(SCRIPT_PACKRAT); var TKClass = load(SCRIPT_TOMMYKNOCKER)

	while spawned < cc and idx < tunnel_cells.size():
		var cell: Vector2i = tunnel_cells[idx]; idx += 1
		if cell.distance_squared_to(player_cell) < 4: continue
		var critter = (TKClass.new() if spawned < tk else PRClass.new())
		critter.name = "C_%d" % spawned
		critter.global_position = Vector2((cell.x + 0.5) * _balance.TILE_SIZE,
			(cell.y + 0.5) * _balance.TILE_SIZE)
		critter.level_ref = level; critter.player_ref = player
		level.entities_node.add_child(critter)
		level.register_critter(critter, cell)
		spawned += 1


func _spawn_boulders(level, cfg) -> void:
	var count: int = cfg.boulder_count
	var cols: Array = range(2, _balance.GRID_COLS - 2); cols.shuffle()
	var BClass = load(SCRIPT_BOULDER); var placed: int = 0
	for col in cols:
		if placed >= count: break
		var row: int = _grid_offset.y + randi_range(2, _balance.GRID_ROWS / 2)
		var cell: Vector2i = Vector2i(col, row)
		var below: Vector2i = cell + Vector2i.DOWN
		if not level.is_in_bounds(below) or level.is_tunnel(below): continue
		var b = BClass.new()
		b.name = "B_%d" % placed; b.level_ref = level; b.my_cell = cell
		b.global_position = Vector2((cell.x + 0.5) * _balance.TILE_SIZE,
			(cell.y + 0.5) * _balance.TILE_SIZE)
		level.entities_node.add_child(b)
		level.register_boulder(b, cell); placed += 1


func _spawn_pickups(level, cfg) -> void:
	var density: float = cfg.nugget_density
	var layer_val: int = cfg.layer as int
	for x: int in _balance.GRID_COLS:
		for y: int in range(_grid_offset.y, _grid_offset.y + _balance.GRID_ROWS):
			var cell: Vector2i = Vector2i(x, y)
			if level.is_solid(cell) and randf() < density:
				level._pickups[cell] = ("gem" if (layer_val >= 2 and randf() < 0.3) else "nugget")
	if cfg.has_mother_lode:
		level._pickups[Vector2i(_balance.GRID_COLS / 2, _grid_offset.y + _balance.GRID_ROWS - 3)] = "mother_lode"


func _show_level_intro(lvl_idx: int, cfg) -> void:
	var names: Array[String] = ["TOPSOIL", "CLAY", "GRAVEL", "BEDROCK"]
	var label: Label = Label.new()
	label.text = "LEVEL %d\n%s\n%d FT" % [lvl_idx + 1, names[cfg.layer], GameState.depth]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	add_child(label)
	label.anchors_preset = Control.PRESET_FULL_RECT
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


func _on_level_cleared() -> void:
	var bonus: int = _balance.LEVEL_CLEAR_BONUS * (GameState.level_index + 1)
	GameState.add_score(bonus)
	var label: Label = Label.new()
	label.text = "SHAFT CLEARED!\n+%d" % bonus
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	add_child(label)
	label.anchors_preset = Control.PRESET_FULL_RECT
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		label.queue_free()
		GameState.next_level()
		var mn = get_parent()
		if mn and mn.has_method("_start_game"): mn._start_game()
	)


func _on_player_died() -> void:
	if GameState.lives <= 0: return
	if player: player.queue_free()
	player = null
	await get_tree().create_timer(0.5).timeout
	if current_level: _spawn_player(current_level)
