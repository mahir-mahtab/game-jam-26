extends CharacterBody2D

# --- CONFIGURATION ---
const SPEED = 40.0

# --- STATE VARIABLES ---
var direction = 1 # 1 = Right, -1 = Left
var being_pulled := false
var is_zombified := false

# --- REFERENCES ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var wall_check = $WallCheck
# Note: Removed FloorCheck

func _ready() -> void:
	add_to_group("prey")
	
	# CRITICAL: Top-Down Physics Mode
	motion_mode = MOTION_MODE_FLOATING
	
	# Random start
	if randf() > 0.5: direction = -1

func _physics_process(_delta: float) -> void:
	# 1. ZOMBIE MODE
	if is_zombified:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 2. BEING PULLED
	if being_pulled:
		move_and_slide()
		return
	
	# 3. PATROL LOGIC (Top-Down)
	
	# Update Raycast (Increased to 40px for safety)
	wall_check.target_position.x = 40 * direction
	
	# Turn around if Ray hits OR Physics Body hits
	if wall_check.is_colliding() or is_on_wall():
		direction *= -1
		wall_check.force_raycast_update()
		
	velocity.x = direction * SPEED
	
	# 4. VISUALS & SHIELD HANDLING
	animated_sprite.flip_h = (direction < 0)
	
	# Move the Shield Area to match facing direction
	# Ensure you have a child node named "Shield" (Area2D or StaticBody2D)
	if has_node("Shield"):
		var shield = $Shield
		# If facing Right (1), shield is at +20. If Left (-1), at -20.
		shield.position.x = 20 * direction
		
		# Optional: If your shield sprite needs flipping too:
		# shield.scale.x = direction 

	move_and_slide()

# --- HELPER FUNCTIONS ---

func set_pulled_state(pulled: bool) -> void:
	being_pulled = pulled

func set_zombified(state: bool) -> void:
	is_zombified = state
	if is_zombified:
		modulate = Color(0.5, 1.0, 0.5)
	else:
		modulate = Color(1, 1, 1)
