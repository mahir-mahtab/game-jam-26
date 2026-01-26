extends Control

## Main Menu UI controller
## Handles navigation between menu options and scene transitions

# Path to your main game scene (update this when you create it)
const GAME_SCENE_PATH = "res://src/level/level1.tscn"

@onready var menu_options = $MarginContainer/VBoxContainer/MenuOptions
@onready var play_button = $MarginContainer/VBoxContainer/MenuOptions/PlayButton
@onready var options_button = $MarginContainer/VBoxContainer/MenuOptions/OptionsButton
@onready var credits_button = $MarginContainer/VBoxContainer/MenuOptions/CreditsButton
@onready var quit_button = $MarginContainer/VBoxContainer/MenuOptions/QuitButton

func _ready():
	# Initial state for animation
	menu_options.modulate.a = 0
	$MarginContainer/VBoxContainer/TitleLabel.modulate.a = 0
	
	# Simple fade-in animation using Tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($MarginContainer/VBoxContainer/TitleLabel, "modulate:a", 1.0, 1.0)
	tween.tween_property(menu_options, "modulate:a", 1.0, 1.0).set_delay(0.5)
	
	play_button.grab_focus()
	
	# Hide quit button on web builds
	if OS.has_feature("web"):
		quit_button.visible = false


func _on_play_button_pressed():
	# TODO: Update GAME_SCENE_PATH with your actual game scene
	if ResourceLoader.exists(GAME_SCENE_PATH):
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	else:
		print("Game scene not found at: ", GAME_SCENE_PATH)
		print("Create your game scene and update the path in main_menu.gd")


func _on_options_button_pressed():
	# TODO: Implement options menu
	print("Options menu - not implemented yet")
	# Example: get_tree().change_scene_to_file("res://src/ui/options_menu.tscn")


func _on_credits_button_pressed():
	# TODO: Implement credits screen
	print("Credits screen - not implemented yet")
	# Example: get_tree().change_scene_to_file("res://src/ui/credits.tscn")


func _on_quit_button_pressed():
	get_tree().quit()
