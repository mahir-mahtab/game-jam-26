extends Control

## Ending Screen - Plays the ending video and returns to main menu
## Player cannot skip this video

const ENDING_VIDEO_PATH = "res://src/ui/end.ogv"
const MAIN_MENU_PATH = "res://src/ui/main_menu.tscn"

var video_player: VideoStreamPlayer

func _ready() -> void:
	print("Ending screen _ready called")
	
	# Make sure the control fills the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Create the video player directly (it will show black when no frame is visible anyway)
	video_player = VideoStreamPlayer.new()
	video_player.name = "EndingVideoPlayer"
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.anchor_right = 1.0
	video_player.anchor_bottom = 1.0
	video_player.offset_right = 0
	video_player.offset_bottom = 0
	video_player.expand = true
	video_player.finished.connect(_on_video_finished)
	add_child(video_player)
	
	# Load the video stream
	var video_stream = load(ENDING_VIDEO_PATH)
	if video_stream:
		print("Ending video loaded successfully: ", ENDING_VIDEO_PATH)
		video_player.stream = video_stream
		# Start playing
		video_player.play()
		print("Video playback started, is_playing: ", video_player.is_playing())
	else:
		push_error("Failed to load ending video: " + ENDING_VIDEO_PATH)
		# If video doesn't exist, go to main menu after a brief delay
		await get_tree().create_timer(1.0).timeout
		_go_to_main_menu()


func _on_video_finished() -> void:
	print("Ending video finished!")
	# Go directly to main menu (no transition)
	_go_to_main_menu()


func _go_to_main_menu() -> void:
	print("Going to main menu...")
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


# Block all input - player cannot skip
func _input(event: InputEvent) -> void:
	# Consume all input events to prevent skipping
	get_viewport().set_input_as_handled()
