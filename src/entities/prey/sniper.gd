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
	motion_mode = MOTION_MODE_FLOATING 
	
	player_ref = get_tree().get_first_node_in_group("player")
	if not player_ref:
		print("[ERROR] Sniper cannot find any node in group 'player'!")
	
	aim_timer.timeout.connect(_on_shoot)
	if randf() > 0.5: direction = Vector2.LEFT

func _physics_process(_delta: float) -> void:
	if is_zombified:
		_cancel_aim()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if being_pulled:
		_cancel_aim()
		move_and_slide()
		return

	match current_state:
		PATROL:
			_process_patrol()
			_check_for_player()
		AIM:
			_process_aim()

	move_and_slide()

func _process_patrol() -> void:
	wall_check.target_position = direction * 35.0
	if wall_check.is_colliding() or is_on_wall():
		direction *= -1
		wall_check.force_raycast_update()
	
	velocity = direction * patrol_speed
	animated_sprite.flip_h = (direction.x < 0)
	laser_line.visible = false

func _check_for_player() -> void:
	if not player_ref: return
	
	# DEBUG 1: Distance
	var dist = global_position.distance_to(player_ref.global_position)
	if dist > sight_range: 
		# Uncomment if you suspect range issues
		# print("[DEBUG] Player too far: ", dist)
		return
	
	# DEBUG 2: Direction
	var to_player = (player_ref.global_position - global_position).normalized()
	if direction.dot(to_player) < 0: 
		# print("[DEBUG] Player is behind me")
		return 
	
	# DEBUG 3: Raycast Vision
	var space = get_world_2d().direct_space_state
	
	# Start ray 30px forward to clear own hitbox
	var start_pos = global_position + (direction * 30.0)
	
	var query = PhysicsRayQueryParameters2D.create(start_pos, player_ref.global_position)
	
	# EXCLUDE SELF AND CHILDREN (Important!)
	var exceptions = [get_rid()]
	for child in get_children():
		if child is CollisionObject2D: # Exclude any child Areas/Bodies
			exceptions.append(child.get_rid())
	query.exclude = exceptions
	
	var result = space.intersect_ray(query)
	
	if result:
		if result.collider == player_ref:
			_start_aiming()
		else:
			# CRITICAL DEBUG: This tells us what is blocking the view
			print("[DEBUG] Vision Blocked by: ", result.collider.name)

func _start_aiming() -> void:
	if current_state == AIM: return
	print("Sniper spotted player! Starting Aim.")
	current_state = AIM
	velocity = Vector2.ZERO 
	laser_line.visible = true
	aim_timer.start()

func _process_aim() -> void:
	if not player_ref:
		_cancel_aim()
		return
	laser_line.clear_points()
	laser_line.add_point(Vector2.ZERO)
	laser_line.add_point(to_local(player_ref.global_position))

func _on_shoot() -> void:
	if current_state != AIM: return
	
	var space = get_world_2d().direct_space_state
	var start_pos = global_position + (direction * 30.0)
	var query = PhysicsRayQueryParameters2D.create(start_pos, player_ref.global_position)
	query.exclude = [get_rid()]
	
	var result = space.intersect_ray(query)
	
	if result and result.collider == player_ref:
		print("BANG! Sniper hit player.")
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(40.0)
			laser_line.default_color = Color.WHITE
	else:
		if result:
			print("Sniper shot blocked by: ", result.collider.name)
		else:
			print("Sniper shot missed (No collision?)")
	
	_cancel_aim()

func _cancel_aim() -> void:
	current_state = PATROL
	laser_line.visible = false
	laser_line.default_color = Color(1, 0, 0)
	aim_timer.stop()

# Helper functions
func set_pulled_state(pulled: bool) -> void: being_pulled = pulled
func set_zombified(state: bool) -> void: 
	is_zombified = state
	if is_zombified: modulate = Color(0.5, 1.0, 0.5)
