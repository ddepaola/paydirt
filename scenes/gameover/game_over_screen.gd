# GameOverScreen.gd — Game over screen.
# Shows final score, depth reached, initials entry, leaderboard, CTA.

class_name GameOverScreen
extends Control

signal restart_pressed

@onready var score_label: Label = $CenterContainer/VBoxContainer/FinalScore
@onready var depth_label: Label = $CenterContainer/VBoxContainer/FinalDepth
@onready var initials_input: LineEdit = $CenterContainer/VBoxContainer/InitialsRow/InitialsInput
@onready var submit_button: Button = $CenterContainer/VBoxContainer/InitialsRow/SubmitButton
@onready var leaderboard_list: VBoxContainer = $CenterContainer/VBoxContainer/LeaderboardList
@onready var cta_button: Button = $CenterContainer/VBoxContainer/CTAButton
@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton

var _final_score: int
var _final_depth: int
var _submitted: bool = false


func _ready() -> void:
	restart_button.pressed.connect(func(): restart_pressed.emit())
	submit_button.pressed.connect(_on_submit)
	cta_button.pressed.connect(_on_cta)
	initials_input.max_length = 3


func show_results(score: int, depth: int) -> void:
	_final_score = score
	_final_depth = depth
	score_label.text = "SCORE: %d" % score
	depth_label.text = "DEPTH: %d FT" % depth
	cta_button.text = "Outfit your real claim: gold pans, sluices & detectors \u2192"
	initials_input.grab_focus()
	Leaderboard.scores_loaded.connect(_on_scores_loaded)
	Leaderboard.fetch_top()


func _on_submit() -> void:
	if _submitted:
		return
	var initials := initials_input.text.to_upper().strip_edges()
	if initials.length() == 0:
		initials = "AAA"
	# Pad to 3
	initials = initials.substr(0, 3)
	while initials.length() < 3:
		initials += "A"
	_submitted = true
	submit_button.disabled = true
	Leaderboard.submit_done.connect(_on_submit_done, CONNECT_ONE_SHOT)
	Leaderboard.submit(initials, _final_score, _final_depth)


func _on_submit_done(ok: bool) -> void:
	submit_button.text = "Saved!" if ok else "Saved locally"
	Leaderboard.fetch_top()


func _on_scores_loaded(scores: Array) -> void:
	for child in leaderboard_list.get_children():
		child.queue_free()

	for i in range(min(scores.size(), 10)):
		var entry: Dictionary = scores[i]
		var label := Label.new()
		label.text = "%2d. %s  %d" % [i + 1, entry.get("initials", "???"), entry.get("score", 0)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		leaderboard_list.add_child(label)


func _on_cta() -> void:
	OS.shell_open(GameState.STORE_URL)
