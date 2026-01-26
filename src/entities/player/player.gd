extends CharacterBody2D

# --- PHYSICS CONFIGURATION ---
const PROJECTILE_SPEED = 1000.0
const PROJECTILE_DECELERATION = 400.0
const BOUNCE_DAMPING = 0.5

# --- TONGUE CONFIGURATION ---
const TONGUE_SPEED = 1500.0
const TONGUE_MAX_LENGTH = 800.0
const TONGUE_RETRACT_SPEED = 2000.0
const PREY_PULL_SPEED = 900.0
const TONGUE_WIDTH = 4.0

# --- TRAJECTORY DOT CONFIGURATION ---
const DOT_SPACING = 21.0
const MAX_LENGTH = 1000.0
const DOT_SCALE = 0.02

# --- STATE VARIABLES ---
var current_host: Node2D = null # The prey we are currently stuck to
var tongue_line: Line2D = null
var tongue_active := false
var tongue_state := "IDLE" 
var tongue_direction := Vector2.ZERO
var tongue_current_length := 0.0

var caught_prey: CharacterBody2D = null
var projectile_active := false 

# Trajectory variables
var dots: Array[Sprite2D] = []

# --- REFERENCES ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dots_container: Node2D = $TrajectoryDots
@onready var dot_template: Sprite2D = $TrajectoryDots/DotTemplate

func _ready() -> void:
	# 1. Setup Tongue Visuals
	setup_tongue_visual()
	
	# 2. Setup Trajectory Dots (From your original script)
	if dot_template:
		dot_template.visible = false
		var max_dots := int(MAX_LENGTH / DOT_SPACING)
		for i in range(max_dots):
			var dot := dot_template.duplicate() as Sprite2D
			dot.visible = true
			dot.scale = Vector2.ONE * DOT_SCALE / (1 + i/10.0)
			dots_container.add_child(dot)
			dots.append(dot)
	
	# Hide dots initially
	dots_container.visible = false

func _physics_process(delta: float) -> void:
	# 1. ZOMBIE MODE (Attached to Host)
	if current_host != null:
		# Snap our position to the host
		global_position = current_host.global_position
		velocity = Vector2.ZERO
		
		# Show aiming dots because we are ready to launch
		dots_container.visible = true
		update_trajectory_dots()
		return

	# 2. HANDLE TONGUE
	if tongue_active:
		process_tongue_physics(delta)
		if caught_prey:
			pull_prey(delta)
		return 

	# 3. HANDLE PROJECTILE MOVEMENT
	if projectile_active:
		var collision = move_and_collide(velocity * delta)
		
		var speed = velocity.length()
		speed = move_toward(speed, 0, PROJECTILE_DECELERATION * delta)
		velocity = velocity.normalized() * speed

		if speed < 10.0:
			stop_movement()

		if collision:
			velocity = velocity.bounce(collision.get_normal()) * BOUNCE_DAMPING
	
	# Hide dots if we are flying or empty
	if current_host == null:
		dots_container.visible = false

func _input(event: InputEvent) -> void:
	# LEFT CLICK: Launch (Only if we have a Host)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_host != null:
			launch_from_host()
		elif not projectile_active and not tongue_active:
			print("Need a host to launch!")

	# RIGHT CLICK: Tongue (Only if NOT attached to host)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if current_host == null and not tongue_active and not projectile_active:
			start_tongue()

# --- ACTIONS ---

func launch_from_host() -> void:
	# THE EXCHANGE: Destroy the host to gain speed
	if current_host:
		current_host.queue_free()
		current_host = null
	
	var dir = (get_global_mouse_position() - global_position).normalized()
	velocity = dir * PROJECTILE_SPEED
	projectile_active = true
	
	animated_sprite.play("run")

func stop_movement() -> void:
	projectile_active = false
	velocity = Vector2.ZERO
	animated_sprite.play("idle")

func attach_to_host(prey: Node2D) -> void:
	print("Attached to prey!")
	
	reset_tongue()
	current_host = prey
	
	# Note: We keeps the collision exception active so we don't 
	# "explode" away from the host due to physics overlap.
	
	if current_host.has_method("set_zombified"):
		current_host.set_zombified(true)
		
	global_position = current_host.global_position
# --- TONGUE MECHANICS ---

func start_tongue() -> void:
	tongue_active = true
	tongue_state = "EXTENDING"
	tongue_direction = (get_global_mouse_position() - global_position).normalized()
	tongue_current_length = 0.0
	tongue_line.visible = true

func process_tongue_physics(delta: float) -> void:
	var start_pos = global_position
	
	# CASE 1: We have a target. Let pull_prey() handle everything.
	if caught_prey != null:
		if is_instance_valid(caught_prey):
			tongue_current_length = start_pos.distance_to(caught_prey.global_position)
			update_tongue_line()
		else:
			reset_tongue()
		return 

	# CASE 2: No target yet (Extending or Retracting empty)
	if tongue_state == "EXTENDING":
		tongue_current_length += TONGUE_SPEED * delta
		var tip_pos = start_pos + (tongue_direction * tongue_current_length)
		
		var query = PhysicsRayQueryParameters2D.create(start_pos, tip_pos)
		query.exclude = [get_rid()] 
		
		# --- CHANGE 1: Enable hitting Area2D (The Shield) ---
		query.collide_with_areas = true 
		# ---------------------------------------------------

		var result = get_world_2d().direct_space_state.intersect_ray(query)
		
		if result:
			tongue_current_length = start_pos.distance_to(result.position)
			var collider = result.collider
			
			# --- CHANGE 2: Check for Shield BEFORE checking for Prey ---
			if collider.is_in_group("shield"):
				print("Clang! Tongue hit a shield.")
				tongue_state = "RETRACTING"
				# Optional: Add a spark particle effect here
			
			elif collider.is_in_group("prey"):
				start_pulling_prey(collider)
			else:
				# Hit a wall
				tongue_state = "RETRACTING"
			# -----------------------------------------------------------
		
		elif tongue_current_length >= TONGUE_MAX_LENGTH:
			tongue_state = "RETRACTING"

	elif tongue_state == "RETRACTING":
		tongue_current_length -= TONGUE_RETRACT_SPEED * delta
		if tongue_current_length <= 0:
			reset_tongue()

	update_tongue_line()

	update_tongue_line()
func start_pulling_prey(prey: Node2D) -> void:
	caught_prey = prey
	tongue_state = "RETRACTING"
	
	# NEW: Allow the prey to overlap with the player so we can catch it
	add_collision_exception_with(prey)
	
	if prey.has_method("set_pulled_state"):
		prey.set_pulled_state(true)

func pull_prey(delta: float) -> void:
	if not is_instance_valid(caught_prey): 
		reset_tongue()
		return
		
	# PHYSICS PULL
	var direction = (global_position - caught_prey.global_position).normalized()
	var dist = global_position.distance_to(caught_prey.global_position)

	# If closer than 50px, ATTACH!
	if dist < 50.0:
		attach_to_host(caught_prey)
		return

	var speed = PREY_PULL_SPEED
	# Smooth down speed as they get close
	if dist < 50.0:
		speed = 400.0
	
	# Apply velocity to prey
	caught_prey.velocity = direction * speed
	
	# Update visual line
	var local_prey_pos = to_local(caught_prey.global_position)
	tongue_line.set_point_position(1, local_prey_pos)
func reset_tongue() -> void:
	tongue_active = false
	tongue_state = "IDLE"
	tongue_line.visible = false
	
	# SAFETY: If we drop a prey, tell it to stop being pulled
	if caught_prey != null and is_instance_valid(caught_prey):
		if caught_prey.has_method("set_pulled_state"):
			caught_prey.set_pulled_state(false)
			# Also stop its sliding velocity so it doesn't drift away
			caught_prey.velocity = Vector2.ZERO
			
	caught_prey = null

func setup_tongue_visual() -> void:
	tongue_line = get_node_or_null("Tongue")
	if not tongue_line:
		tongue_line = Line2D.new()
		tongue_line.name = "Tongue"
		tongue_line.width = TONGUE_WIDTH
		tongue_line.default_color = Color(1.0, 0.4, 0.5)
		add_child(tongue_line)

func update_tongue_line() -> void:
	if tongue_line.visible:
		tongue_line.clear_points()
		tongue_line.add_point(Vector2.ZERO)
		tongue_line.add_point(tongue_direction * tongue_current_length)

# --- TRAJECTORY VISUALIZATION (Restored) ---
func update_trajectory_dots() -> void:
	var start_pos = global_position
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - start_pos).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var space_state = get_world_2d().direct_space_state
	var remaining_length = MAX_LENGTH
	var current_pos = start_pos
	var current_dir = direction

	var dot_index = 0
	var max_bounces = 3 

	while remaining_length > 0 and dot_index < dots.size() and max_bounces >= 0:
		var ray_end = current_pos + current_dir * remaining_length
		var query = PhysicsRayQueryParameters2D.create(current_pos, ray_end)
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)

		var segment_length = remaining_length

		if result:
			segment_length = current_pos.distance_to(result.position)
		
		# Place dots along this segment
		var segment_dot_count = int(segment_length / DOT_SPACING)
		for i in range(segment_dot_count):
			if dot_index >= dots.size():
				break
			var dot = dots[dot_index]
			var t = float(i + 1) * DOT_SPACING
			dot.global_position = current_pos + current_dir * t
			var alpha = clamp(1.0 - (MAX_LENGTH - remaining_length + t) / MAX_LENGTH, 0.0, 1.0)
			dot.modulate = Color(1, 1, 1, alpha)
			dot.visible = true
			dot_index += 1

		if result:
			# Reflect the direction
			current_dir = current_dir.bounce(result.normal)
			current_pos = result.position + current_dir * 0.1 
			remaining_length -= segment_length
			max_bounces -= 1
		else:
			break

	# Hide any remaining dots
	for i in range(dot_index, dots.size()):
		dots[i].visible = false
