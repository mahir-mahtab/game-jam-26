extends CanvasLayer

## Transition screen between Level 2 and Level 3

const CURRENT_LEVEL_PATH = "res://src/level/level2.tscn"
const NEXT_LEVEL_PATH = "res://src/level/level3.tscn"

func _ready() -> void:
	add_to_group("transition_screen")
	visible = false

func show_transition() -> void:
	visible = true
	get_tree().paused = true
	_grab_focus()

func _grab_focus() -> void:
	var continue_button = $CenterContainer/VBoxContainer/ContinueButton
	if continue_button:
		continue_button.grab_focus()

func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(NEXT_LEVEL_PATH)

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(CURRENT_LEVEL_PATH)
