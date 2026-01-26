extends CharacterBody2D

# --- CONFIGURATION ---
@export var patrol_speed: float = 30.0
@export var hover_strength: float = 5.0 # Speed of the bobbing
@export var hover_distance: float = 40.0 # Height of the bobbing

# --- STATE ---
var direction = 1
var start_y: float = 0.0
var time_counter: float = 0.0
var being_pulled := false
var is_zombified := false

# --- REFERENCES ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var wall_check = $WallCheck

func _ready() -> void:
	add_to_group("prey")
	start_y = global_position.y
	
	# Randomize timing so they don't all bob in sync
	time_counter = randf() * 10.0 
	if randf() > 0.5: direction = -1

func _physics_process(delta: float) -> void:
	# 1. STOP if captured
	if is_zombified:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if being_pulled:
		move_and_slide()
		return 

	# 2. JETPACK MOVEMENT (No Gravity!)
	
	# Horizontal Patrol
	wall_check.target_position.x = 30 * direction
	if wall_check.is_colliding():
		direction *= -1
	
	velocity.x = direction * patrol_speed
	
	# Vertical Hover (Sine Wave Logic)
	time_counter += delta * 2.0
	var target_y = start_y + sin(time_counter) * hover_distance
	
	# Smoothly move to target height
	var diff_y = target_y - global_position.y
	velocity.y = diff_y * hover_strength
	
	# 3. VISUALS
	animated_sprite.flip_h = (direction < 0)
	
	# Optional: Slight tilt when flying
	rotation_degrees = velocity.x * 0.1
	
	move_and_slide()

# --- INTERFACE ---
func set_pulled_state(pulled: bool) -> void: 
	being_pulled = pulled

func set_zombified(state: bool) -> void: 
	is_zombified = state
	rotation_degrees = 0 # Reset tilt when caught
	if is_zombified:
		modulate = Color(0.5, 1.0, 0.5)
