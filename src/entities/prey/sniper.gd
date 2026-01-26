extends CharacterBody2D

# --- CONFIGURATION ---
@export var patrol_speed: float = 40.0
@export var sight_range: float = 450.0

# --- STATE ---
enum { PATROL, AIM }
var current_state = PATROL
var direction = Vector2.RIGHT

# Shared Variables
var being_pulled := false
var is_zombified := false

# --- REFERENCES ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var wall_check = $WallCheck
@onready var laser_line = $LaserSight
@onready var aim_timer = $AimTimer

var player_ref: Node2D = null

func _ready() -> void:
	add_to_group("prey")
	
	# CRITICAL: This prevents falling!
	motion_mode = MOTION_MODE_FLOATING 
	
	player_ref = get_tree().get_first_node_in_group("player")
	aim_timer.timeout.connect(_on_shoot)
	
	if randf() > 0.5: direction = Vector2.LEFT

func _physics_process(_delta: float) -> void:
	# 1. STOP if captured
	if is_zombified:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if being_pulled:
		move_and_slide()
		return

	# 2. STATE LOGIC
	match current_state:
		PATROL:
			_process_patrol()
			_check_for_player()
		AIM:
			_process_aim()

	# 3. APPLY MOVEMENT
	move_and_slide()

func _process_patrol() -> void:
	# Wall Bounce Logic
	wall_check.target_position = direction * 35.0
	if wall_check.is_colliding() or is_on_wall():
		direction *= -1
		wall_check.force_raycast_update()
	
	velocity = direction * patrol_speed
	
	# Visuals
	animated_sprite.flip_h = (direction.x < 0)
	laser_line.visible = false

func _check_for_player() -> void:
	if not player_ref: return
	
	# A. Distance
	var dist = global_position.distance_to(player_ref.global_position)
	if dist > sight_range: return
	
	# B. Facing Direction (90 degree cone)
	var to_player = (player_ref.global_position - global_position).normalized()
	if direction.dot(to_player) < 0: return 
	
	# C. Raycast (Vision)
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player_ref.global_position)
	query.exclude = [get_rid()] 
	
	var result = space.intersect_ray(query)
	if result and result.collider == player_ref:
		_start_aiming()

func _start_aiming() -> void:
	current_state = AIM
	velocity = Vector2.ZERO # Stop moving to shoot
	laser_line.visible = true
	aim_timer.start()

func _process_aim() -> void:
	if not player_ref:
		_cancel_aim()
		return
	# Update laser visual
	laser_line.clear_points()
	laser_line.add_point(Vector2.ZERO)
	laser_line.add_point(to_local(player_ref.global_position))

func _on_shoot() -> void:
	if current_state != AIM: return
	
	# Final line of sight check
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player_ref.global_position)
	query.exclude = [get_rid()]
	var result = space.intersect_ray(query)
	
	if result and result.collider == player_ref:
		print("BANG! Player hit.")
		get_tree().reload_current_scene()
	
	_cancel_aim()

func _cancel_aim() -> void:
	current_state = PATROL
	laser_line.visible = false
	aim_timer.stop()

# Helper functions
func set_pulled_state(pulled: bool) -> void: being_pulled = pulled
func set_zombified(state: bool) -> void: 
	is_zombified = state
	if is_zombified: modulate = Color(0.5, 1.0, 0.5)
