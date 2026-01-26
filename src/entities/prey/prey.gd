extends CharacterBody2D

# --- CONFIGURATION ---
const SPEED = 40.0
const GRAVITY = 980.0

# --- STATE VARIABLES ---
var direction = 1 # 1 = Right, -1 = Left
var being_pulled := false
var is_zombified := false

# --- REFERENCES ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var wall_check = $WallCheck
@onready var floor_check = $FloorCheck

func _ready() -> void:
	# [cite_start]CRITICAL: Must be in this group for the Player to detect and eat it [cite: 1]
	add_to_group("prey")
	
	# Optional: Randomize start direction so they don't all move in sync
	if randf() > 0.5:
		direction = -1

func _physics_process(delta: float) -> void:
	# 1. ZOMBIFIED STATE (Player is attached/riding)
	# We freeze completely so the player can aim without us walking away.
	if is_zombified:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 2. BEING PULLED (Tongue physics)
	# CRITICAL FIX: We must call move_and_slide() here!
	# If we just 'return', the velocity applied by the player is ignored.
	if being_pulled:
		move_and_slide()
		return
	
	# 3. GRAVITY
	# Apply gravity so they walk on the floor, not float in air
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# 4. NORMAL AI MOVEMENT
	# Update raycasts to look ahead
	wall_check.target_position.x = 20 * direction
	floor_check.position.x = 20 * direction
	
	# Turn around at walls OR if the floor check finds a gap (ledge)
	# NEW: Added 'or is_on_wall()' as a backup failsafe
	if wall_check.is_colliding() or is_on_wall() or (is_on_floor() and not floor_check.is_colliding()):
		direction *= -1
	
	velocity.x = direction * SPEED
	
	# Visuals
	animated_sprite.flip_h = (direction < 0)

	move_and_slide()

# --- HELPER FUNCTIONS (Called by Player) ---

func set_pulled_state(pulled: bool) -> void:
	being_pulled = pulled

func set_zombified(state: bool) -> void:
	is_zombified = state
	
	# Visual Feedback: Change color to show infection/capture
	if is_zombified:
		modulate = Color(0.5, 1.0, 0.5) # Green tint
	else:
		modulate = Color(1, 1, 1) # Normal
