extends Control

## Main Menu UI controller
## Handles navigation between menu options and scene transitions

# Path to your main game scene (update this when you create it)
const GAME_SCENE_PATH = "res://src/level/level1.tscn"
const INTRO_VIDEO_PATH = "res://src/ui/intro.ogv"
const TUTORIAL_IMAGE_PATH = "res://src/ui/tutorial.png"

@onready var menu_options = $MarginContainer/VBoxContainer/MenuOptions
@onready var play_button = $MarginContainer/VBoxContainer/MenuOptions/PlayButton
@onready var tutorial_button = $MarginContainer/VBoxContainer/MenuOptions/PlayButton2
@onready var quit_button = $MarginContainer/VBoxContainer/MenuOptions/QuitButton

# Video player components
var video_container: ColorRect
var video_player: VideoStreamPlayer
var saved_bus_volumes: Dictionary = {}

# Tutorial overlay components
var tutorial_container: ColorRect
var tutorial_image: TextureRect
var tutorial_back_button: Button

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
	
	# Setup video player (hidden by default)
	_setup_video_player()
	
	# Setup tutorial overlay (hidden by default)
	_setup_tutorial_overlay()
	
	# Connect tutorial button
	if tutorial_button:
		tutorial_button.pressed.connect(_on_tutorial_button_pressed)


func _setup_video_player() -> void:
	# Create a full-screen black background
	video_container = ColorRect.new()
	video_container.name = "VideoContainer"
	video_container.color = Color.BLACK
	video_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_container.visible = false
	video_container.z_index = 100  # On top of everything
	add_child(video_container)
	
	# Create the video player
	video_player = VideoStreamPlayer.new()
	video_player.name = "IntroVideoPlayer"
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.finished.connect(_on_video_finished)
	video_container.add_child(video_player)
	
	# Load the video stream
	var video_stream = load(INTRO_VIDEO_PATH)
	if video_stream:
		video_player.stream = video_stream
	else:
		push_warning("Failed to load intro video: " + INTRO_VIDEO_PATH)


func _setup_tutorial_overlay() -> void:
	# Create a full-screen dark background
	tutorial_container = ColorRect.new()
	tutorial_container.name = "TutorialContainer"
	tutorial_container.color = Color(0, 0, 0, 0.95)
	tutorial_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_container.visible = false
	tutorial_container.z_index = 101  # On top of everything including video
	add_child(tutorial_container)
	
	# Create the tutorial image
	tutorial_image = TextureRect.new()
	tutorial_image.name = "TutorialImage"
	tutorial_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tutorial_container.add_child(tutorial_image)
	
	# Load the tutorial image
	var tutorial_texture = load(TUTORIAL_IMAGE_PATH)
	if tutorial_texture:
		tutorial_image.texture = tutorial_texture
	else:
		push_warning("Failed to load tutorial image: " + TUTORIAL_IMAGE_PATH)
	
	# Create the back button
	tutorial_back_button = Button.new()
	tutorial_back_button.name = "BackButton"
	tutorial_back_button.text = "BACK"
	tutorial_back_button.custom_minimum_size = Vector2(150, 50)
	tutorial_back_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tutorial_back_button.position = Vector2(-75, -80)  # Center horizontally, 80px from bottom
	tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
	tutorial_container.add_child(tutorial_back_button)


func _on_tutorial_button_pressed() -> void:
	# Show tutorial overlay and hide menu
	$MarginContainer.visible = false
	tutorial_container.visible = true
	tutorial_back_button.grab_focus()


func _on_tutorial_back_pressed() -> void:
	# Hide tutorial overlay and show menu
	tutorial_container.visible = false
	$MarginContainer.visible = true
	play_button.grab_focus()


func _on_play_button_pressed():
	# Check if video exists
	if video_player.stream:
		_play_intro_video()
	else:
		_start_game()


func _play_intro_video() -> void:
	# Mute all audio buses except the video
	_mute_all_buses()
	
	# Hide menu and show video
	$MarginContainer.visible = false
	video_container.visible = true
	
	# Play the video
	video_player.play()


func _mute_all_buses() -> void:
	# Save and mute all audio bus volumes EXCEPT Master (so video audio can play)
	var bus_count = AudioServer.bus_count
	for i in range(1, bus_count):  # Start from 1 to skip Master bus
		var bus_name = AudioServer.get_bus_name(i)
		saved_bus_volumes[bus_name] = AudioServer.get_bus_volume_db(i)
		AudioServer.set_bus_volume_db(i, -80.0)  # Effectively mute


func _restore_all_buses() -> void:
	# Restore all audio bus volumes
	for bus_name in saved_bus_volumes:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			AudioServer.set_bus_volume_db(bus_idx, saved_bus_volumes[bus_name])
	saved_bus_volumes.clear()


func _on_video_finished() -> void:
	print("Video finished!")
	# Video finished - freeze on last frame (video player keeps showing last frame)
	video_player.paused = true
	
	# Restore audio
	_restore_all_buses()
	
	# Play circle close animation (outside to inside, screen goes black)
	if TransitionManager:
		print("Playing circle close transition...")
		await TransitionManager.circle_close(Vector2(0.5, 0.5), 0.8)
		print("Circle close done, keeping screen black...")
		TransitionManager.set_fully_black()
	
	# Hide video
	video_container.visible = false
	
	# Start the game
	print("Starting game...")
	_start_game()


func _start_game() -> void:
	if ResourceLoader.exists(GAME_SCENE_PATH):
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	else:
		print("Game scene not found at: ", GAME_SCENE_PATH)
		print("Create your game scene and update the path in main_menu.gd")
		# Show menu again if game scene doesn't exist
		$MarginContainer.visible = true
		video_container.visible = false


func _on_quit_button_pressed():
	get_tree().quit()
