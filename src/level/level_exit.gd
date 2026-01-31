extends Area2D

# This creates a file picker in the Inspector!
@export_file("*.tscn") var next_level_scene: String

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_triggered: bool = false

func _ready() -> void:
	# Ensure animation is stopped at first frame
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.frame = 0
		# Connect animation finished signal
		if not animated_sprite.is_connected("animation_finished", _on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

func _on_body_entered(body: Node2D) -> void:
	# 1. Check if the object entering is the Player
	if body.is_in_group("player") and not is_triggered:
		is_triggered = true
		# Stop the player
		if body is CharacterBody2D:
			body.velocity = Vector2.ZERO
			# Also try to reset player state if method exists
			if body.has_method("freeze_for_exit"):
				body.freeze_for_exit()
		_play_exit_animation()

func _play_exit_animation() -> void:
	print("Exit triggered - playing animation...")
	
	# Play the door animation
	if animated_sprite:
		animated_sprite.play("default")
	else:
		# No animation, go straight to transition
		_start_transition()

func _on_animation_finished() -> void:
	# Animation finished, now do the transition
	_start_transition()

func _start_transition() -> void:
	if next_level_scene == "":
		print("Error: Next level scene is not set in the Inspector!")
		return
	
	print("Loading next level with transition...")
	
	# Use TransitionManager for smooth transition
	if TransitionManager:
		await TransitionManager.circle_close(Vector2(0.5, 0.5), 0.6)
		TransitionManager.set_fully_black()
	
	# Change scene
	get_tree().change_scene_to_file(next_level_scene)
