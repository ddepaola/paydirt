# TitleScreen.gd — Title / start screen.
# Shows PAY DIRT logo, Miners Warehouse brand, Play button, leaderboard preview.

class_name TitleScreen
extends Control

signal play_pressed

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var leaderboard_list: VBoxContainer = $CenterContainer/VBoxContainer/LeaderboardPreview
@onready var brand_label: Label = $CenterContainer/VBoxContainer/BrandLabel
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	Leaderboard.scores_loaded.connect(_on_scores_loaded)


func start() -> void:
	title_label.text = "PAY DIRT"
	brand_label.text = "Miners Warehouse presents"
	Leaderboard.fetch_top()


func _on_play() -> void:
	play_pressed.emit()


func _on_scores_loaded(scores: Array) -> void:
	# Clear existing preview entries
	for child in leaderboard_list.get_children():
		child.queue_free()

	# Show top 5
	var shown := min(scores.size(), 5)
	for i in range(shown):
		var entry: Dictionary = scores[i]
		var label := Label.new()
		label.text = "%d. %s — %d" % [i + 1, entry.get("initials", "???"), entry.get("score", 0)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		leaderboard_list.add_child(label)

	if scores.size() == 0:
		var label := Label.new()
		label.text = "No scores yet — be the first!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		leaderboard_list.add_child(label)
