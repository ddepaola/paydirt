# Game.gd — Main gameplay coordinator for PAY DIRT.
# All entity creation uses load().new() — no class_name dependencies.

extends Node2D

# Script paths (loaded at runtime, no parse-order issues)
const SCRIPT_LEVEL = "res://scripts/systems/level.gd"
const SCRIPT_PLAYER = "res://scripts/entities/player.gd"
const SCRIPT_PACKRAT = "res://scripts/entities/pack_rat.gd"
const SCRIPT_TOMMYKNOCKER = "res://scripts/entities/tommyknocker.gd"
const SCRIPT_BOULDER = "res://scripts/entities/boulder.gd"

var current_level                        # Level ref (untyped)
var player                               # Player ref (untyped)
var _balance                             # Balance ref (untyped)
var _grid_offset: Vector2i = Vector2i(0, 2)


func _ready() -> void:
	_balance = _load_balance()


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
	add_child(level)
	current_level = level

	if level.has_signal("level_cleared"):
		level.level_cleared.connect(_on_level_cleared)
	if level.has_signal("player_died"):
		level.player_died.connect(_on_player_died)

	var cfg = GameState.get_level_config(lvl_idx)
	level._balance = _balance
	level._config = cfg

	var entities: Node2D = Node2D.new()
	entities.name = "Entities"
	level.add_child(entities)
	level.entities_node = entities

	var fx: Node2D = Node2D.new()
	fx.name = "FX"
	level.add_child(fx)
	level.fx_node = fx

	_create_earth_tilemap(level)
	level._setup_grid()
	_spawn_player(level)
	_spawn_critters(level, cfg)
	_spawn_boulders(level, cfg)
	_spawn_pickups(level, cfg)
	_show_level_intro(lvl_idx, cfg)


func _create_earth_tilemap(level) -> void:
	var tm: TileMapLayer = TileMapLayer.new()
	tm.name = "EarthTileMap"

	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(_balance.TILE_SIZE, _balance.TILE_SIZE)

	var img: Image = Image.create_empty(_balance.TILE_SIZE * 5, _balance.TILE_SIZE, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [
		Color(0.55, 0.35, 0.15), Color(0.65, 0.50, 0.25),
		Color(0.40, 0.40, 0.45), Color(0.12, 0.10, 0.08),
		Color(0.05, 0.05, 0.08),
	]
	for col_i: int in 5:
		var c: Color = colors[col_i]
		for px: int in _balance.TILE_SIZE:
			for py: int in _balance.TILE_SIZE:
				img.set_pixel(col_i * _balance.TILE_SIZE + px, py, c)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(_balance.TILE_SIZE, _balance.TILE_SIZE)
	atlas.tile_size = Vector2i(_balance.TILE_SIZE, _balance.TILE_SIZE)
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
	p.global_position = Vector2((start_cell.x + 0.5) * _balance.TILE_SIZE, (start_cell.y + 0.5) * _balance.TILE_SIZE)
	p.level_ref = level

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite"
	var simg: Image = Image.create(_balance.TILE_SIZE, _balance.TILE_SIZE, false, Image.FORMAT_RGBA8)
	simg.fill(Color(0.2, 0.4, 0.7))
	for xx: int in range(4, 20): simg.set_pixel(xx, 4, Color(0.4, 0.25, 0.1))
	for yy: int in range(6, 12):
		for xx: int in range(7, 17): simg.set_pixel(xx, yy, Color(1.0, 0.85, 0.7))
	simg.set_pixel(9, 8, Color.BLACK); simg.set_pixel(13, 8, Color.BLACK)
	sprite.texture = ImageTexture.create_from_image(simg)
	p.add_child(sprite)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(_balance.TILE_SIZE * 0.8, _balance.TILE_SIZE * 0.8)
	shape.shape = rect
	p.add_child(shape)

	var timer: Timer = Timer.new()
	timer.name = "DigTimer"; timer.one_shot = true
	p.add_child(timer)
	p.dig_timer = timer

	level.entities_node.add_child(p)
	level.register_player(p)
	player = p


func _spawn_critters(level, cfg) -> void:
	var critter_count: int = cfg.critter_count
	var tk_count: int = cfg.tommyknocker_count()
	var tunnel_cells: Array = level._get_all_tunnel_cells()
	tunnel_cells.shuffle()

	var player_cell: Vector2i = level.cell_at(player.global_position)
	var spawned: int = 0; var idx: int = 0

	var PRClass = load(SCRIPT_PACKRAT)
	var TKClass = load(SCRIPT_TOMMYKNOCKER)

	while spawned < critter_count and idx < tunnel_cells.size():
		var cell: Vector2i = tunnel_cells[idx]; idx += 1
		if cell.distance_squared_to(player_cell) < 9: continue

		var critter
		if spawned < tk_count:
			critter = TKClass.new()
			critter.name = "Tommyknocker_%d" % spawned
		else:
			critter = PRClass.new()
			critter.name = "PackRat_%d" % spawned

		critter.global_position = Vector2((cell.x + 0.5) * _balance.TILE_SIZE, (cell.y + 0.5) * _balance.TILE_SIZE)
		critter.level_ref = level
		critter.player_ref = player
		level.entities_node.add_child(critter)
		level.register_critter(critter, cell)
		spawned += 1


func _spawn_boulders(level, cfg) -> void:
	var count: int = cfg.boulder_count
	var cols: Array = range(1, _balance.GRID_COLS - 1); cols.shuffle()

	var BClass = load(SCRIPT_BOULDER)
	var i: int = 0
	for col in cols:
		if i >= count: break
		var row: int = _grid_offset.y + randi_range(1, _balance.GRID_ROWS / 2)
		var cell: Vector2i = Vector2i(col, row)
		var below: Vector2i = cell + Vector2i.DOWN
		if not level.is_in_bounds(below) or level.is_tunnel(below): continue

		var b = BClass.new()
		b.name = "Boulder_%d" % i
		b.level_ref = level; b.my_cell = cell
		b.global_position = Vector2((cell.x + 0.5) * _balance.TILE_SIZE, (cell.y + 0.5) * _balance.TILE_SIZE)
		level.entities_node.add_child(b)
		level.register_boulder(b, cell)
		i += 1


func _spawn_pickups(level, cfg) -> void:
	var density: float = cfg.nugget_density
	var layer_val: int = cfg.layer as int
	for x: int in _balance.GRID_COLS:
		for y: int in range(_grid_offset.y, _grid_offset.y + _balance.GRID_ROWS):
			var cell: Vector2i = Vector2i(x, y)
			if level.is_solid(cell) and randf() < density:
				var is_gem: bool = (layer_val >= 2) and randf() < 0.3
				level._pickups[cell] = "gem" if is_gem else "nugget"
	if cfg.has_mother_lode:
		var lode_cell: Vector2i = Vector2i(_balance.GRID_COLS / 2, _grid_offset.y + _balance.GRID_ROWS - 2)
		level._pickups[lode_cell] = "mother_lode"


func _show_level_intro(lvl_idx: int, cfg) -> void:
	var layer_names: Array[String] = ["TOPSOIL", "CLAY", "GRAVEL", "BEDROCK"]
	var label: Label = Label.new()
	label.text = "LEVEL %d\n%s\n%d FT" % [lvl_idx + 1, layer_names[cfg.layer], GameState.depth]
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
		if mn.has_method("_start_game"): mn._start_game()
	)


func _on_player_died() -> void:
	if GameState.lives <= 0: return
	player.queue_free(); player = null
	await get_tree().create_timer(0.5).timeout
	if current_level: _spawn_player(current_level)
