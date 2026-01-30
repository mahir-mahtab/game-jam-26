extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Play circle open transition from player position
	_play_entry_transition()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Assuming you have an input action named "reset" in your Project Settings
	if Input.is_action_just_pressed("reset"):
		reset_scene()

func reset_scene():
	get_tree().reload_current_scene()


func _play_entry_transition() -> void:
	# Simply use screen center for the reveal animation
	# This is called when the level loads after the video transition
	if TransitionManager:
		TransitionManager.circle_open(Vector2(0.5, 0.5), 0.8)
