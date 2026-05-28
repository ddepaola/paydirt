# HUD.gd — Heads-up display (CanvasLayer).
# Shows score, lives, depth (ft), and gold count.
# Wired to GameState signals for live updates.

class_name HUD
extends CanvasLayer

@onready var score_label: Label = $MarginContainer/VBoxContainer/TopRow/ScoreLabel
@onready var lives_label: Label = $MarginContainer/VBoxContainer/TopRow/LivesLabel
@onready var depth_label: Label = $MarginContainer/VBoxContainer/TopRow/DepthLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopRow/GoldLabel


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.depth_changed.connect(_on_depth_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	_refresh_all()


func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = "SCORE %d" % new_score


func _on_lives_changed(new_lives: int) -> void:
	if lives_label:
		lives_label.text = "LIVES %d" % new_lives


func _on_depth_changed(new_depth: int) -> void:
	if depth_label:
		depth_label.text = "%d FT" % new_depth


func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "AU %d" % new_gold


func _refresh_all() -> void:
	_on_score_changed(GameState.score)
	_on_lives_changed(GameState.lives)
	_on_depth_changed(GameState.depth)
	_on_gold_changed(GameState.gold)
