extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Assuming you have an input action named "reset" in your Project Settings
	if Input.is_action_just_pressed("reset"):
		reset_scene()

func reset_scene():
	get_tree().reload_current_scene()
