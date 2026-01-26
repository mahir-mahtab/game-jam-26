extends CharacterBody2D

# --- CONFIGURATION ---
const SPEED = 40.0
const GRAVITY = 980.0

# --- STATE VARIABLES ---
var direction = 1 # 1 = Right, -1 = Left
var being_pulled := false
var is_zombified := false # <--- NEW: Added this variable

# --- REFERENCES ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var wall_check = $WallCheck
@onready var floor_check = $FloorCheck

func _ready() -> void:
	add_to_group("prey")

func _physics_process(delta: float) -> void:
	# 1. ZOMBIE MODE (Player is attached)
	if is_zombified:
		velocity = Vector2.ZERO
		move_and_slide()
		return # Stop here so we don't wander around

	# 2. BEING PULLED (Tongue physics)
	if being_pulled:
		move_and_slide() # <--- CRITICAL: Allow the pull velocity to work
		return # Stop here so we don't apply gravity/AI
	
	# 3. GRAVITY (Uncomment if you want gravity later)
	# if not is_on_floor():
	# 	velocity.y += GRAVITY * delta
	
	# 4. NORMAL AI MOVEMENT
	# Update raycasts
	wall_check.target_position.x = 20 * direction
	floor_check.position.x = 20 * direction
	
	# Turn around at walls or ledges
	if wall_check.is_colliding() or (is_on_floor() and not floor_check.is_colliding()):
		direction *= -1
		
	velocity.x = direction * SPEED
	
	# Visuals
	animated_sprite.flip_h = (direction < 0)
	# FLIP SHIELD with Body
	# Assuming the Shield is a child of the root node
	if direction > 0:
		$Shield.position.x = 20 # Front Right
	else:
		$Shield.position.x = -20 # Front Left

	move_and_slide()

# --- HELPER FUNCTIONS ---

func set_pulled_state(pulled: bool) -> void:
	being_pulled = pulled

# <--- NEW: Added this function so Player script can call it
func set_zombified(state: bool) -> void:
	is_zombified = state
	# Optional: Change color to show infection
	if is_zombified:
		modulate = Color(0.5, 1.0, 0.5) # Green tint
	else:
		modulate = Color(1, 1, 1)
