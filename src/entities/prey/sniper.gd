extends CharacterBody2D

# --- CONFIGURATION ---
@export var patrol_speed: float = 40.0
@export var sight_range: float = 450.0
@export var laser_damage: float = 10.0  # Reduced damage for more frequent hits
@export var aim_time: float = 0.8  # Time before shooting (faster)

# Offset from center to the "eye" or "gun" position for raycasting
const LASER_ORIGIN_OFFSET := Vector2(0, -20)  # Sprite is offset upward

# --- STATE ---
enum { PATROL, AIM }
var current_state = PATROL
var direction_change_cooldown: float = 0.0  # Prevents rapid direction flipping
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
	
	# Find player after scene tree is fully set up
	call_deferred("_find_player")
	
	aim_timer.timeout.connect(_on_shoot)
	if randf() > 0.5: direction = Vector2.LEFT


func _find_player() -> void:
	player_ref = get_tree().get_first_node_in_group("player")
	if not player_ref:
		# Try again next frame if player not found yet
		await get_tree().process_frame
		player_ref = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if is_zombified or being_pulled:
		_cancel_aim()
		velocity = Vector2.ZERO
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
	# Update cooldown timer
	if direction_change_cooldown > 0:
		direction_change_cooldown -= get_physics_process_delta_time()
	
	# Set wall check direction
	wall_check.target_position = direction * 35.0
	
	# Only flip direction if cooldown has expired
	if direction_change_cooldown <= 0:
		if wall_check.is_colliding() or is_on_wall():
			direction *= -1
			direction_change_cooldown = 0.3  # Prevent flipping again for 0.3 seconds
			wall_check.force_raycast_update()
	
	velocity = direction * patrol_speed
	animated_sprite.flip_h = (direction.x < 0)
	laser_line.visible = false

func _check_for_player() -> void:
	if not player_ref: return
	
	# Wall Check (Raycast) - no distance or FOV limit, can shoot from anywhere
	var space = get_world_2d().direct_space_state
	var query = _create_smart_query(player_ref.global_position)
	var result = space.intersect_ray(query)
	
	# Only aim if we hit the player (not a wall)
	if result and result.collider == player_ref:
		# Update facing direction toward player
		var to_player = (player_ref.global_position - global_position)
		if abs(to_player.x) > abs(to_player.y):
			direction = Vector2.RIGHT if to_player.x > 0 else Vector2.LEFT
		animated_sprite.flip_h = (to_player.x < 0)
		_start_aiming()

func _start_aiming() -> void:
	if current_state == AIM: return
	current_state = AIM
	velocity = Vector2.ZERO 
	laser_line.visible = true
	aim_timer.wait_time = aim_time
	aim_timer.start()

func _process_aim() -> void:
	if not player_ref:
		_cancel_aim()
		return
	
	var to_player = (player_ref.global_position - global_position).normalized()
	
	# Update facing direction to always track player (360 degree vision)
	if abs(to_player.x) > abs(to_player.y):
		direction = Vector2.RIGHT if to_player.x > 0 else Vector2.LEFT
	animated_sprite.flip_h = (to_player.x < 0)

	# Check if a wall is now in the way
	var space = get_world_2d().direct_space_state
	var query = _create_smart_query(player_ref.global_position)
	var result = space.intersect_ray(query)
	
	# If we hit anything that is NOT the player, vision is blocked
	if result and result.collider != player_ref:
		_cancel_aim()
		return
	
	# If clear, update Visuals - draw from laser origin offset to player
	laser_line.clear_points()
	laser_line.add_point(LASER_ORIGIN_OFFSET)
	laser_line.add_point(to_local(player_ref.global_position))

func _on_shoot() -> void:
	if current_state != AIM: return
	if not is_inside_tree(): return
	
	# Double check line of sight one last time before firing
	var space = get_world_2d().direct_space_state
	var query = _create_smart_query(player_ref.global_position)
	var result = space.intersect_ray(query)
	
	if result and result.collider == player_ref:
		print("BANG! Sniper hit player.")
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(laser_damage)
			
		laser_line.default_color = Color.WHITE
		if is_inside_tree():
			await get_tree().create_timer(0.1).timeout
	
	_cancel_aim()

func _cancel_aim() -> void:
	current_state = PATROL
	laser_line.visible = false
	laser_line.default_color = Color(1, 0, 0)
	aim_timer.stop()

# Helper: Consolidates raycast logic so aimed shots and vision are identical
func _create_smart_query(target_pos: Vector2) -> PhysicsRayQueryParameters2D:
	# Use a fixed offset from sprite origin, NOT based on patrol direction
	# This ensures consistent detection regardless of which way sniper is facing
	var start_pos = global_position + LASER_ORIGIN_OFFSET
	var query = PhysicsRayQueryParameters2D.create(start_pos, target_pos)
	
	# Exclude self and all children from raycast
	var exceptions = [get_rid()]
	for child in get_children():
		if child is CollisionObject2D:
			exceptions.append(child.get_rid())
	query.exclude = exceptions
	
	# Prevent false detections from Area2D triggers
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return query

func set_pulled_state(pulled: bool) -> void: being_pulled = pulled
func set_zombified(state: bool) -> void: 
	is_zombified = state
	if is_zombified: modulate = Color(0.5, 1.0, 0.5)
