# PackRat.gd — Basic critter. Patrols tunnels, chases player, ghosts through earth.
# Extends Critter base script.

extends "res://scripts/entities/critter.gd"


func _ready() -> void:
	super()
	critter_name = "PackRat"


func _draw_placeholder() -> void:
	# Brown/grey body, pointy nose
	queue_redraw()


func _draw() -> void:
	# Simple placeholder drawing
	var size := Vector2(_balance.TILE_SIZE * 0.7, _balance.TILE_SIZE * 0.5)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(0.5, 0.35, 0.2), true)  # brown body
	draw_rect(Rect2(size * 0.3, Vector2(4, 4)), Color(0.2, 0.2, 0.2), true)  # eye
