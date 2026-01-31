extends CanvasLayer

## Victory Screen controller
## Shows congratulations when the player completes level 4

const LEVEL_4_PATH = "res://src/level/level4.tscn"
const MAIN_MENU_PATH = "res://src/ui/main_menu.tscn"

func _ready() -> void:
	# Add to group for easy lookup
	add_to_group("victory_screen")
	
	# Check if loaded as standalone scene (direct navigation)
	if get_tree().current_scene == self or get_parent() == get_tree().root:
		# Show immediately when loaded directly
		visible = true
		_grab_focus()
	else:
		visible = false  # Hide it when instanced in a level

func show_victory() -> void:
	visible = true
	get_tree().paused = true  # Pause the game
	_grab_focus()

func _grab_focus() -> void:
	# Grab focus on the first button for gamepad/keyboard support
	var play_again_button = $CenterContainer/VBoxContainer/PlayAgainButton
	if play_again_button:
		play_again_button.grab_focus()

func _on_play_again_button_pressed() -> void:
	get_tree().paused = false  # Unpause before changing scene
	get_tree().change_scene_to_file(LEVEL_4_PATH)

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false  # Unpause before changing scene
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
