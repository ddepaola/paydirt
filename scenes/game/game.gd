# Game.gd — Main gameplay coordinator for PAY DIRT.
# All entity creation uses load().new() — no class_name dependencies.

extends Node2D

# Script paths
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
	# Add a dark background so the game doesn't look broken
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

	# Build children BEFORE adding to tree
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
	# Boulders disabled — tweens may cause freeze on llvmpipe/WSL
	# _spawn_boulders(level, cfg)
	_spawn_pickups(level, cfg)
	_show_level_intro(lvl_idx, cfg)


func _create_earth_tilemap(level) -> void:
	var tm: TileMapLayer = TileMapLayer.new()
	tm.name = "EarthTileMap"
	# Offset the tilemap to match grid offset
	tm.position = Vector2(0, _grid_offset.y * _balance.TILE_SIZE)

	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(_balance.TILE_SIZE, _balance.TILE_SIZE)

	# Create a single atlas image with 5 colored tiles in a row
	var tw: int = _balance.TILE_SIZE
	var img: Image = Image.create_empty(tw * 5, tw, false, Image.FORMAT_RGBA8)

	# Tile colors: topsoil, clay, gravel, bedrock, tunnel
	var colors: Array[Color] = [
		Color(0.55, 0.35, 0.15),  # warm brown
		Color(0.65, 0.50, 0.25),  # tan/ochre
		Color(0.40, 0.42, 0.45),  # cool grey
		Color(0.15, 0.12, 0.10),  # near-black
		Color(0.04, 0.04, 0.06),  # dark tunnel
	]

	for col_i: int in 5:
		var c: Color = colors[col_i]
		for px: int in tw:
			for py: int in tw:
				# Add subtle noise to each tile for visual interest
				var nc: Color = c
				var noise: float = randf_range(-0.04, 0.04)
				nc.r = clamp(nc.r + noise, 0.0, 1.0)
				nc.g = clamp(nc.g + noise, 0.0, 1.0)
				nc.b = clamp(nc.b + noise, 0.0, 1.0)
				# Draw a 1px border on the tile edges for grid visibility
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

	# Simple but visible player sprite
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite"
	var simg: Image = Image.create(_balance.TILE_SIZE, _balance.TILE_SIZE, false, Image.FORMAT_RGBA8)
	# Body (blue overalls)
	for yy: int in range(8, 22):
		for xx: int in range(4, 20):
			simg.set_pixel(xx, yy, Color(0.15, 0.35, 0.65))
	# Head (skin)
	var head_c: Color = Color(1.0, 0.82, 0.62)
	for yy: int in range(3, 10):
		for xx: int in range(6, 18):
			var px: Color = simg.get_pixel(xx, yy)
			if px.a == 0 or px == Color(0.15, 0.35, 0.65):
				simg.set_pixel(xx, yy, head_c)
	# Hat (brown)
	for yy: int in range(1, 5):
		for xx: int in range(2, 21):
			if simg.get_pixel(xx, yy) == head_c or simg.get_pixel(xx, yy).a == 0:
				simg.set_pixel(xx, yy, Color(0.4, 0.25, 0.12))
	# Eyes
	simg.set_pixel(8, 6, Color.BLACK)
	simg.set_pixel(14, 6, Color.BLACK)
	sprite.texture = ImageTexture.create_from_image(simg)
	p.add_child(sprite)

	# Collision
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(_balance.TILE_SIZE * 0.75, _balance.TILE_SIZE * 0.75)
	shape.shape = rect
	p.add_child(shape)

	# Dig timer
	var timer: Timer = Timer.new()
	timer.name = "DigTimer"
	timer.one_shot = true
	p.add_child(timer)
	p.dig_timer = timer

	level.entities_node.add_child(p)
	level.register_player(p)
	player = p


func _spawn_critters(level, cfg) -> void:
	var cc: int = cfg.critter_count
	var tk: int = cfg.tommyknocker_count()
	var tunnel_cells: Array = level._get_all_tunnel_cells()
	if tunnel_cells.size() < 2:
		return
	tunnel_cells.shuffle()

	var player_cell: Vector2i = level.cell_at(player.global_position)
	var spawned: int = 0
	var idx: int = 0
	var PRClass = load(SCRIPT_PACKRAT)
	var TKClass = load(SCRIPT_TOMMYKNOCKER)

	while spawned < cc and idx < tunnel_cells.size():
		var cell: Vector2i = tunnel_cells[idx]; idx += 1
		if cell.distance_squared_to(player_cell) < 4:
			continue

		var critter
		if spawned < tk:
			critter = TKClass.new()
			critter.name = "TK_%d" % spawned
		else:
			critter = PRClass.new()
			critter.name = "PR_%d" % spawned

		critter.global_position = Vector2((cell.x + 0.5) * _balance.TILE_SIZE,
			(cell.y + 0.5) * _balance.TILE_SIZE)
		critter.level_ref = level
		critter.player_ref = player
		level.entities_node.add_child(critter)
		level.register_critter(critter, cell)
		spawned += 1


func _spawn_boulders(level, cfg) -> void:
	var count: int = cfg.boulder_count
	var cols: Array = range(2, _balance.GRID_COLS - 2)
	cols.shuffle()
	var BClass = load(SCRIPT_BOULDER)
	var placed: int = 0
	for col in cols:
		if placed >= count:
			break
		var row: int = _grid_offset.y + randi_range(2, _balance.GRID_ROWS / 2)
		var cell: Vector2i = Vector2i(col, row)
		var below: Vector2i = cell + Vector2i.DOWN
		if not level.is_in_bounds(below) or level.is_tunnel(below):
			continue
		var b = BClass.new()
		b.name = "B_%d" % placed
		b.level_ref = level
		b.my_cell = cell
		b.global_position = Vector2((cell.x + 0.5) * _balance.TILE_SIZE,
			(cell.y + 0.5) * _balance.TILE_SIZE)
		level.entities_node.add_child(b)
		level.register_boulder(b, cell)
		placed += 1


func _spawn_pickups(level, cfg) -> void:
	var density: float = cfg.nugget_density
	var layer_val: int = cfg.layer as int
	var placed: int = 0
	for x: int in _balance.GRID_COLS:
		for y: int in range(_grid_offset.y, _grid_offset.y + _balance.GRID_ROWS):
			var cell: Vector2i = Vector2i(x, y)
			if level.is_solid(cell) and randf() < density:
				var is_gem: bool = (layer_val >= 2) and randf() < 0.3
				level._pickups[cell] = "gem" if is_gem else "nugget"
				placed += 1
	if cfg.has_mother_lode:
		var lc: Vector2i = Vector2i(_balance.GRID_COLS / 2, _grid_offset.y + _balance.GRID_ROWS - 3)
		level._pickups[lc] = "mother_lode"


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
		if mn and mn.has_method("_start_game"):
			mn._start_game()
	)


func _on_player_died() -> void:
	if GameState.lives <= 0:
		return
	if player:
		player.queue_free()
	player = null
	await get_tree().create_timer(0.5).timeout
	if current_level:
		_spawn_player(current_level)
