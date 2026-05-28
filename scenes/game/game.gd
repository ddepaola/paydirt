# Game.gd — Main gameplay coordinator.
# Owns the current Level instance. Handles level transitions, spawning,
# and the overall game flow from within the Game scene.

class_name GamePlay
extends Node2D

var current_level: Level
var player: Player
var _balance: Balance


func _ready() -> void:
	_balance = GameState.get_balance()
	# Load Balance resource if it exists
	if ResourceLoader.exists("res://scripts/balance/balance.tres"):
		GameState.balance = load("res://scripts/balance/balance.tres")
	else:
		GameState.balance = Balance.new()


func start_level(lvl_idx: int) -> void:
	# Clear previous level if any
	if current_level:
		current_level.queue_free()

	# Create Level
	current_level = Level.new()
	current_level.name = "Level"
	add_child(current_level)
	current_level.level_cleared.connect(_on_level_cleared)
	current_level.player_died.connect(_on_player_died)

	# Set up references
	current_level._balance = _balance
	current_level._config = GameState.get_level_config(lvl_idx)

	# Create EarthTileMap
	_create_earth_tilemap()
	# Create Entities container
	current_level.entities_node = Node2D.new()
	current_level.entities_node.name = "Entities"
	current_level.add_child(current_level.entities_node)
	# Create FX container
	current_level.fx_node = Node2D.new()
	current_level.fx_node.name = "FX"
	current_level.add_child(current_level.fx_node)

	# Initialize grid
	current_level._setup_grid()

	# Spawn player
	_spawn_player()

	# Spawn critters
	_spawn_critters()

	# Spawn boulders
	_spawn_boulders()

	# Spawn pickups
	_spawn_pickups()

	# Level intro interstitial
	_show_level_intro(lvl_idx)


func _create_earth_tilemap() -> void:
	var tm := TileMapLayer.new()
	tm.name = "EarthTileMap"
	tm.tile_set = _create_placeholder_tileset()
	tm.centered_textures = false
	current_level.add_child(tm)
	current_level.earth_tilemap = tm


func _create_placeholder_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(_balance.TILE_SIZE, _balance.TILE_SIZE)

	# Create a simple colored rect source for each earth layer + tunnel
	var layers := [
		{"color": Color(0.55, 0.35, 0.15), "name": "topsoil"},       # warm brown
		{"color": Color(0.65, 0.5, 0.25), "name": "clay"},            # tan/ochre
		{"color": Color(0.4, 0.4, 0.45), "name": "gravel"},           # cool grey
		{"color": Color(0.12, 0.1, 0.08), "name": "bedrock"},         # near-black
		{"color": Color(0.05, 0.05, 0.08), "name": "tunnel"},         # dark tunnel
	]

	var source_id := ts.add_source(TileSet.SOURCE_IMAGE, Image.create(_balance.TILE_SIZE, _balance.TILE_SIZE * len(layers), false, Image.FORMAT_RGBA8))

	for i in range(len(layers)):
		# Create atlas tile at column i, row 0
		var atlas_coords := Vector2i(i, 0)
		ts.set_tile_data(atlas_coords, {
			"name": layers[i]["name"],
			"texture_origin": Vector2i(0, i * _balance.TILE_SIZE),
		})

	return ts


func _spawn_player() -> void:
	var player_scene := _create_player_placeholder()
	player = player_scene
	player.level_ref = current_level
	var start_cell := Vector2i(_balance.GRID_COLS / 2, Level.GRID_OFFSET.y + 1)
	player.global_position = current_level.world_of(start_cell)
	current_level.entities_node.add_child(player)
	current_level.register_player(player)


func _create_player_placeholder() -> Player:
	var p := Player.new()
	p.name = "Player"

	# Placeholder sprite
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	# Draw a simple prospector shape
	var img := Image.create(_balance.TILE_SIZE, _balance.TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.7))  # blue shirt
	# Hat (brown line at top)
	for x in range(4, 20):
		img.set_pixel(x, 4, Color(0.4, 0.25, 0.1))
	# Head (peach)
	for y in range(6, 12):
		for x in range(7, 17):
			img.set_pixel(x, y, Color(1.0, 0.85, 0.7))
	# Eyes
	img.set_pixel(9, 8, Color(0, 0, 0))
	img.set_pixel(13, 8, Color(0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
	p.add_child(sprite)

	# Collision
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_balance.TILE_SIZE * 0.8, _balance.TILE_SIZE * 0.8)
	shape.shape = rect
	p.add_child(shape)

	# Dig timer
	var timer := Timer.new()
	timer.name = "DigTimer"
	p.add_child(timer)
	p.dig_timer = timer

	return p


func _spawn_critters() -> void:
	var cfg := current_level._config
	var packrat_count := cfg.packrat_count()
	var tk_count := cfg.tommyknocker_count()
	var tunnel_cells := current_level._get_all_tunnel_cells()

	# Shuffle tunnel cells for random placement
	tunnel_cells.shuffle()

	var spawned := 0
	var i := 0

	while spawned < cfg.critter_count and i < tunnel_cells.size():
		var cell := tunnel_cells[i]
		i += 1

		# Don't spawn too close to player
		if cell.distance_squared_to(current_level.cell_at(player.global_position)) < 9:
			continue

		var critter: Critter
		if spawned < tk_count:
			critter = Tommyknocker.new()
		else:
			critter = PackRat.new()

		critter.name = "%s_%d" % [critter.critter_name, spawned]
		critter.level_ref = current_level
		critter.player_ref = player
		critter.global_position = current_level.world_of(cell)
		current_level.entities_node.add_child(critter)
		current_level.register_critter(critter, cell)
		spawned += 1


func _spawn_boulders() -> void:
	var cfg := current_level._config
	var cols_available: Array[int] = []
	for x in range(1, _balance.GRID_COLS - 1):
		cols_available.append(x)
	cols_available.shuffle()

	for i in range(min(cfg.boulder_count, cols_available.size())):
		var col := cols_available[i]
		# Place boulder at a random row in the upper half of the playfield
		var row := Level.GRID_OFFSET.y + randi_range(1, _balance.GRID_ROWS / 2)
		var cell := Vector2i(col, row)
		# Ensure cell below is solid (so it rests)
		var below := cell + Vector2i.DOWN
		if current_level.is_in_bounds(below) and current_level.is_solid(below):
			var boulder := Boulder.new()
			boulder.name = "Boulder_%d" % i
			boulder.level_ref = current_level
			boulder.my_cell = cell
			boulder.global_position = current_level.world_of(cell)
			current_level.entities_node.add_child(boulder)
			current_level.register_boulder(boulder, cell)


func _spawn_pickups() -> void:
	var cfg := current_level._config
	# Scatter nuggets/gems throughout solid earth
	for x in range(_balance.GRID_COLS):
		for y in range(Level.GRID_OFFSET.y, Level.GRID_OFFSET.y + _balance.GRID_ROWS):
			var cell := Vector2i(x, y)
			if current_level.is_solid(cell):
				if randf() < cfg.nugget_density:
					# Deeper = more likely gem
					var is_gem := (cfg.layer >= LevelConfig.Layer.GRAVEL) and randf() < 0.3
					current_level._pickups[cell] = "gem" if is_gem else "nugget"

	# Mother Lode if flagged
	if cfg.has_mother_lode:
		# Place one mother lode in a hard-to-reach spot (bottom center-ish)
		var lode_cell := Vector2i(_balance.GRID_COLS / 2, Level.GRID_OFFSET.y + _balance.GRID_ROWS - 2)
		current_level._pickups[lode_cell] = "mother_lode"


func _show_level_intro(lvl_idx: int) -> void:
	var cfg := current_level._config
	var layer_names := ["TOPSOIL", "CLAY", "GRAVEL", "BEDROCK"]
	var label := Label.new()
	label.text = "LEVEL %d\n%s\n%d FT" % [lvl_idx + 1, layer_names[cfg.layer], GameState.depth]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	add_child(label)
	label.anchors_preset = Control.PRESET_FULL_RECT

	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


func _on_level_cleared() -> void:
	# Score bonus
	var bonus = _balance.LEVEL_CLEAR_BONUS * (GameState.level_index + 1)
	GameState.add_score(bonus)

	# Brief celebration
	var label := Label.new()
	label.text = "SHAFT CLEARED!\n+%d" % bonus
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	add_child(label)
	label.anchors_preset = Control.PRESET_FULL_RECT

	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		label.queue_free()
		GameState.next_level()
		start_level(GameState.level_index)
	)


func _on_player_died() -> void:
	if GameState.lives <= 0:
		return  # game_over signal handles it

	# Respawn player
	player.queue_free()
	player = null
	await get_tree().create_timer(0.5).timeout
	_spawn_player()
