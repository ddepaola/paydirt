# Main.gd — Top-level scene router.
# Manages Title → Game → GameOver flow.

extends Node

var title_screen: Control
var game_screen: Node2D
var game_over_screen: Control
var hud: CanvasLayer


func _ready() -> void:
	title_screen = $TitleScreen
	game_screen = $Game
	game_over_screen = $GameOverScreen
	hud = $HUD

	GameState.game_over.connect(_on_game_over)
	title_screen.play_pressed.connect(_start_game)
	game_over_screen.restart_pressed.connect(_start_game)

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
