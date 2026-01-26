extends Node2D

# --- Configuration ---
# How long to wait on the final still frame before fading starts
const FADE_DELAY: float = 1.0 
# How long the fading process takes
const FADE_DURATION: float = 2.5 

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Ensure physics and processing are off so these don't lag the game
	set_process(false)
	set_physics_process(false)
	
	# Ensure Loop OFF in code just in case
	if sprite.sprite_frames.has_animation("die"):
		sprite.sprite_frames.set_animation_loop("die", false)
	
	# Play animation and listen for the finish
	sprite.play("die")
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	# Ensure it only triggers for the correct animation
	if sprite.animation == "die":
		# 1. Freeze on the last frame
		sprite.stop()
		var frame_count = sprite.sprite_frames.get_frame_count("die")
		# Indices are 0-based, so the last frame is count - 1
		sprite.frame = frame_count - 1 
		
		# 2. Begin the fade out sequence
		_start_fade_sequence()

func _start_fade_sequence() -> void:
	# Create a tween for smooth transitions
	var tween = create_tween()
	
	# Step A: Wait a moment while staying fully visible on the last frame
	if FADE_DELAY > 0:
		tween.tween_interval(FADE_DELAY)
	
	# Step B: Tween the alpha (transparency) of the root node down to 0.
	# Modifying 'self.modulate' affects all children (the sprite).
	# set_trans(Tween.TRANS_SINE) makes it look a bit smoother than linear.
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	
	# Step C: Important! Delete the object from memory once it's invisible.
	tween.finished.connect(queue_free)
