extends CanvasLayer

## Level Transition Screen controller
## Shows between levels with options to restart or continue

signal restart_requested
signal continue_requested

var current_level_path: String = ""
var next_level_path: String = ""

func _ready() -> void:
	# Add to group for easy lookup
	add_to_group("transition_screen")
	visible = false  # Hide by default

func show_transition(current_level: String, next_level: String) -> void:
	current_level_path = current_level
	next_level_path = next_level
	
	visible = true
	get_tree().paused = true  # Pause the game
	
	# Update the level complete text based on current level
	var level_name = _get_level_name(current_level)
	$CenterContainer/VBoxContainer/TitleLabel.text = level_name + " Complete!"
	
	# Grab focus on continue button
	var continue_button = $CenterContainer/VBoxContainer/ContinueButton
	if continue_button:
		continue_button.grab_focus()

func _get_level_name(level_path: String) -> String:
	if "level1" in level_path:
		return "Level 1"
	elif "level2" in level_path:
		return "Level 2"
	elif "level3" in level_path:
		return "Level 3"
	elif "level4" in level_path:
		return "Level 4"
	else:
		return "Level"

func _on_continue_button_pressed() -> void:
	get_tree().paused = false  # Unpause before changing scene
	emit_signal("continue_requested")
	
	if next_level_path != "":
		get_tree().change_scene_to_file(next_level_path)

func _on_restart_button_pressed() -> void:
	get_tree().paused = false  # Unpause before changing scene
	emit_signal("restart_requested")
	
	if current_level_path != "":
		get_tree().change_scene_to_file(current_level_path)
	else:
		get_tree().reload_current_scene()
