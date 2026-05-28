# FakeLevel.gd — Minimal level stub for no-tilemap test.
# Provides just the methods player.gd needs.

extends Node2D

var _caller: Node2D  # Reference back to the Game scene for grid state

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 20 and cell.y >= 2 and cell.y < 15

func is_solid(cell: Vector2i) -> bool:
	return not _caller._tunnel.get(cell, false)

func is_tunnel(cell: Vector2i) -> bool:
	return _caller._tunnel.get(cell, false)

func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / 24), int(pos.y / 24))

func world_of(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * 24, (cell.y + 0.5) * 24)

func carve(cell: Vector2i) -> void:
	_caller._carve(cell)

func register_player(p) -> void:
	pass

func neighbors4(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]

func get_critter_at(cell: Vector2i):
	return null

func register_critter(c, cell: Vector2i) -> void:
	pass

func unregister_critter_at(cell: Vector2i) -> void:
	pass

func register_critter_at(cell: Vector2i, c) -> void:
	pass

func on_critter_killed(c, cell: Vector2i) -> void:
	pass

func has_boulder_at(cell: Vector2i) -> bool:
	return false

func register_boulder(b, cell: Vector2i) -> void:
	pass

func unregister_boulder_at(cell: Vector2i) -> void:
	pass

func _get_all_tunnel_cells() -> Array[Vector2i]:
	return []
