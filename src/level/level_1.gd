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
	# Find the player node
	var player = get_node_or_null("CharacterBody2D")
	if player == null:
		# Try to find by group
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	# Calculate player's screen position as UV (0-1 range)
	var center_uv = Vector2(0.5, 0.5)  # Default to center
	if player:
		var viewport = get_viewport()
		var viewport_size = viewport.get_visible_rect().size
		var camera = viewport.get_camera_2d()
		
		if camera:
			# Get player position relative to camera
			var screen_pos = camera.get_screen_center_position()
			var offset = player.global_position - screen_pos
			# Convert to UV coordinates
			center_uv = Vector2(0.5, 0.5) + offset / viewport_size
			center_uv = center_uv.clamp(Vector2.ZERO, Vector2.ONE)
	
	# Play the reveal animation
	if TransitionManager:
		TransitionManager.circle_open(center_uv, 0.8)
