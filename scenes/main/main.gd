# Main.gd — Top-level scene router.
# Manages Title → Game → GameOver flow.
# Holds references to all major sub-scenes.

extends Node

var title_screen: Control
var game_screen: Node2D
var game_over_screen: Control
var hud: CanvasLayer


func _ready() -> void:
	# Cache node references
	title_screen = $TitleScreen
	game_screen = $Game
	game_over_screen = $GameOverScreen
	hud = $HUD

	# Connect signals
	GameState.game_over.connect(_on_game_over)

	# Start at title
	_show_title()


func _show_title() -> void:
	title_screen.visible = true
	game_screen.visible = false
	game_over_screen.visible = false
	hud.visible = false
	title_screen.start()


func _start_game() -> void:
	GameState.reset()
	title_screen.visible = false
	game_over_screen.visible = false
	game_screen.visible = true
	hud.visible = true
	game_screen.start_level(GameState.level_index)


func _on_game_over() -> void:
	game_screen.visible = false
	hud.visible = true
	game_over_screen.visible = true
	game_over_screen.show_results(GameState.score, GameState.depth)


func _on_game_over_restart() -> void:
	_start_game()
