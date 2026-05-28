# Level.gd — Owns the playfield grid, TileMapLayers, and all entity spawning.
# This is the central coordinator for a single level instance.

extends Node2D

# ---- enums ----
enum LayerIdx { TOPSOIL = 0, CLAY = 1, GRAVEL = 2, BEDROCK = 3 }

# ---- signals ----
signal level_cleared()
signal player_died()
signal nugget_collected(cell: Vector2i, value: int)
signal gear_spawned(item: String, world_pos: Vector2)

# ---- const ----
const GRID_OFFSET := Vector2i(0, 2)   # playfield starts after 2-row HUD

# ---- node refs (set by scene, or created in _ready) ----
var earth_tilemap: TileMapLayer
var deco_tilemap: TileMapLayer
var entities_node: Node2D
var fx_node: Node2D

# ---- grid state ----
var _tunnel: Dictionary = {}          # Vector2i → bool (true = TUNNEL)
var _pickups: Dictionary = {}         # Vector2i → String ("nugget"|"gem"|"mother_lode")
var _boulder_cells: Dictionary = {}   # Vector2i → Boulder ref
var _critter_cells: Dictionary = {}   # Vector2i → Critter ref
var _config: LevelConfig
var _balance: Balance
var _cur_layer: LayerIdx = LayerIdx.TOPSOIL

# ---- A* data ----
var _astar: AStarGrid2D
var _astar_needs_rebuild: bool = true

# ---- entity lists ----
var critters_alive: int = 0
var boulders_count: int = 0
var player_ref = null  # (Player — untyped to avoid circular dep with Player class)
var center_cell: Vector2i          # playfield geometric center, for bonuses


func _ready() -> void:
	_balance = GameState.get_balance()
	_config = GameState.get_level_config(GameState.level_index)
	_cur_layer = _config.layer as LayerIdx

	# Use programmatically-set refs if available, otherwise try $NodeName
	if not earth_tilemap:
		earth_tilemap = get_node_or_null("EarthTileMap")
	if not entities_node:
		entities_node = get_node_or_null("Entities")
	if not fx_node:
		fx_node = get_node_or_null("FX")

	center_cell = Vector2i(_balance.GRID_COLS / 2, GRID_OFFSET.y + _balance.GRID_ROWS / 2)
	_setup_grid()
	_spawn_from_config()


# ---- grid API ----

func is_tunnel(cell: Vector2i) -> bool:
	return _tunnel.get(cell, false)


func is_solid(cell: Vector2i) -> bool:
	return not is_tunnel(cell)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _balance.GRID_COLS and \
		   cell.y >= GRID_OFFSET.y and cell.y < GRID_OFFSET.y + _balance.GRID_ROWS


func carve(cell: Vector2i) -> void:
	if not is_in_bounds(cell) or is_tunnel(cell):
		return
	_tunnel[cell] = true
	_update_tilemap_cell(cell)
	_astar_needs_rebuild = true
	if _pickups.has(cell):
		_pickups.erase(cell)
		nugget_collected.emit(cell, _get_pickup_value(cell))
	_check_boulder_column(cell.x)


func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / _balance.TILE_SIZE),
		int(world_pos.y / _balance.TILE_SIZE)
	)


func world_of(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x + 0.5) * _balance.TILE_SIZE,
		(cell.y + 0.5) * _balance.TILE_SIZE
	)


func neighbors4(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i.UP,
		cell + Vector2i.DOWN,
		cell + Vector2i.LEFT,
		cell + Vector2i.RIGHT,
	]


# ---- pathfinding ----

func get_astar() -> AStarGrid2D:
	if _astar_needs_rebuild:
		_rebuild_astar()
	return _astar


func _rebuild_astar() -> void:
	if not _astar:
		_astar = AStarGrid2D.new()
		_astar.region = Rect2i(0, GRID_OFFSET.y, _balance.GRID_COLS, _balance.GRID_ROWS)
		_astar.cell_size = Vector2i(_balance.TILE_SIZE, _balance.TILE_SIZE)
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for x in range(_balance.GRID_COLS):
		for y in range(GRID_OFFSET.y, GRID_OFFSET.y + _balance.GRID_ROWS):
			var cell := Vector2i(x, y)
			_astar.set_point_solid(cell, is_solid(cell))
	_astar_needs_rebuild = false


func tunnel_distance(from: Vector2i, to: Vector2i) -> float:
	var astar := get_astar()
	var path := astar.get_id_path(from, to)
	if path.size() < 2:
		return INF
	return (path.size() - 1) * _balance.TILE_SIZE


# ---- boulder support ----

func _check_boulder_column(col: int) -> void:
	for y in range(GRID_OFFSET.y + _balance.GRID_ROWS - 1, GRID_OFFSET.y - 1, -1):
		var cell := Vector2i(col, y)
		if _boulder_cells.has(cell):
			var below := cell + Vector2i.DOWN
			# Boulder is supported if cell below is solid or has another boulder
			var supported := is_solid(below) or _boulder_cells.has(below)
			if not supported:
				_boulder_cells[cell].trigger_fall()


# ---- internal ----

func _setup_grid() -> void:
	# Initialize all cells as SOLID (except a few starter tunnels for the player)
	for x in range(_balance.GRID_COLS):
		for y in range(GRID_OFFSET.y, GRID_OFFSET.y + _balance.GRID_ROWS):
			_tunnel[Vector2i(x, y)] = false

	# Carve a small starter pocket for the player (center-ish near top)
	var start := Vector2i(_balance.GRID_COLS / 2, GRID_OFFSET.y + 1)
	carve(start)
	for n in neighbors4(start):
		if is_in_bounds(n):
			carve(n)

	# Populate earth tilemap
	_populate_earth_tilemap()


func _populate_earth_tilemap() -> void:
	if not earth_tilemap:
		return
	var solid_id := _tile_for_layer(0)
	var tunnel_id := _tile_for_layer(-1)
	for x in range(_balance.GRID_COLS):
		for y in range(GRID_OFFSET.y, GRID_OFFSET.y + _balance.GRID_ROWS):
			var cell := Vector2i(x, y)
			var atlas_coords := solid_id if is_solid(cell) else tunnel_id
			earth_tilemap.set_cell(cell, 0, atlas_coords)


func _update_tilemap_cell(cell: Vector2i) -> void:
	if not earth_tilemap:
		return
	var tunnel_id := _tile_for_layer(-1)
	earth_tilemap.set_cell(cell, 0, tunnel_id)
	earth_tilemap.queue_redraw()


func _tile_for_layer(variant: int) -> Vector2i:
	# Placeholder: return atlas coords based on layer and variant
	# variant -1 = tunnel, 0- = solid earth variants
	# In placeholder mode, we use simple colored rects via TileMapLayer
	if variant == -1:
		return Vector2i(4, 0)  # tunnel tile (column 4)
	match _cur_layer:
		LayerIdx.TOPSOIL:
			return Vector2i(0, 0)  # warm brown
		LayerIdx.CLAY:
			return Vector2i(1, 0)  # tan/ochre
		LayerIdx.GRAVEL:
			return Vector2i(2, 0)  # cool grey
		LayerIdx.BEDROCK:
			return Vector2i(3, 0)  # near-black with gold flecks
	return Vector2i(0, 0)


func _spawn_from_config() -> void:
	# Called after grid is set up; spawns critters, boulders, pickups
	# The actual spawning logic is delegated to the entity managers
	pass


func _get_pickup_value(cell: Vector2i) -> int:
	# Stub — overridden when pickup system is implemented
	return 0


func register_player(p) -> void:     # Player ref — untyped to break circular dep
	player_ref = p


func register_critter(critter, cell: Vector2i) -> void:
	_critter_cells[cell] = critter
	critters_alive += 1


func register_critter_at(cell: Vector2i, critter) -> void:
	_critter_cells[cell] = critter


func unregister_critter_at(cell: Vector2i) -> void:
	_critter_cells.erase(cell)


func get_critter_at(cell: Vector2i):
	return _critter_cells.get(cell, null)


func register_boulder(boulder, cell: Vector2i) -> void:
	_boulder_cells[cell] = boulder


func unregister_boulder_at(cell: Vector2i) -> void:
	_boulder_cells.erase(cell)


func has_boulder_at(cell: Vector2i) -> bool:
	return _boulder_cells.has(cell)


func on_critter_killed(critter, cell: Vector2i) -> void:
	_critter_cells.erase(cell)
	critters_alive -= 1
	if critters_alive <= 0:
		level_cleared.emit()


func _get_all_tunnel_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _tunnel.keys():
		if _tunnel[cell]:
			cells.append(cell)
	return cells
