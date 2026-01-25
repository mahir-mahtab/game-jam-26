extends CharacterBody2D

const SPEED = 300.0
const DOT_SPACING = 21.0
const MAX_LENGTH = 1000.0
const DOT_SCALE = 0.02
const PROJECTILE_SPEED = 1000.0
const PROJECTILE_DECELERATION = 600.0
const BOUNCE_DAMPING = 0.6

# Tongue projectile constants
const TONGUE_SPEED = 1500.0
const TONGUE_MAX_LENGTH = 1000.0
const TONGUE_RETRACT_SPEED = 2000.0
const PREY_PULL_SPEED = 800.0
const TONGUE_WIDTH = 3.0

# Reference to your AnimatedSprite2D node
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dots_container: Node2D = $TrajectoryDots
@onready var dot_template: Sprite2D = $TrajectoryDots/DotTemplate

var tongue_line: Line2D = null
var dots: Array[Sprite2D] = []
var projectile_active := false
var stuck_to: Node2D = null
var stuck_offset := Vector2.ZERO

# Tongue system state variables
var tongue_active := false
var tongue_extending := false
var tongue_retracting := false
var tongue_direction := Vector2.ZERO
var tongue_current_length := 0.0
var caught_prey: CharacterBody2D = null
var prey_pull_start_pos := Vector2.ZERO

func _ready() -> void:
	# Build dot pool from template
	dot_template.visible = false
	var max_dots := int(MAX_LENGTH / DOT_SPACING)
	for i in range(max_dots):
		var dot := dot_template.duplicate() as Sprite2D
		dot.visible = true
		
		dot.scale = Vector2.ONE * DOT_SCALE /(1+i/10)
		dots_container.add_child(dot)
		dots.append(dot)
	
	# Create tongue Line2D if it doesn't exist
	setup_tongue_visual()

func setup_tongue_visual() -> void:
	"""Create or get reference to tongue Line2D node"""
	# Check if Tongue node already exists
	tongue_line = get_node_or_null("Tongue")
	
	if tongue_line == null:
		# Create tongue Line2D programmatically
		tongue_line = Line2D.new()
		tongue_line.name = "Tongue"
		tongue_line.width = TONGUE_WIDTH
		tongue_line.default_color = Color(1.0, 0.4, 0.5, 1.0)  # Pinkish-red color
		tongue_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		tongue_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		tongue_line.visible = false
		tongue_line.z_index = -1  # Draw behind player
		add_child(tongue_line)
		print("Tongue Line2D created programmatically")
	else:
		print("Tongue Line2D found in scene")

func _physics_process(_delta: float) -> void:
	# Handle tongue projectile system (locks player movement)
	if tongue_active:
		update_tongue_physics(_delta)
		if caught_prey:
			update_prey_pull(_delta)
		return  # Don't process normal movement while tongue is active
	
	if stuck_to != null:
		velocity = Vector2.ZERO
		global_position = stuck_to.global_position + stuck_offset
		return

	if projectile_active:
		# Apply deceleration to projectile
		var current_speed = velocity.length()
		if current_speed < 10.0:
			projectile_active = false
			velocity = Vector2.ZERO
			return
			
		var new_speed = max(current_speed - PROJECTILE_DECELERATION * _delta, 0.0)
		velocity = velocity.normalized() * new_speed
		
		# Use move_and_collide for better bounce handling
		var collision = move_and_collide(velocity * _delta)
		if collision:
			var collider = collision.get_collider()
			if collider != null and collider.is_in_group("prey"):
				stick_to_prey(collider)
			else:
				# Bounce off other objects
				velocity = velocity.bounce(collision.get_normal()) * BOUNCE_DAMPING
		return

	# Get direction vector based on 8-direction input
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		# Flip sprite based on horizontal direction
		if direction.x != 0:
			animated_sprite.flip_h = (direction.x < 0)
		animated_sprite.play("run")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		animated_sprite.play("idle")

	move_and_slide()
	update_trajectory_dots()

func _process(_delta: float) -> void:
	# Always update trajectory dots regardless of state
	update_trajectory_dots()

func _input(event: InputEvent) -> void:
	# Left-click: Launch player as projectile
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not projectile_active and stuck_to:
			launch_projectile()
	
	# Right-click: Launch tongue to grab prey
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not tongue_active and not projectile_active:
			launch_tongue()
		

func launch_projectile() -> void:
	if stuck_to != null:
		unstick_from_prey()
	var dir = (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	velocity = dir * PROJECTILE_SPEED
	projectile_active = true

func stick_to_prey(prey_node: Node2D) -> void:
	projectile_active = false
	stuck_to = prey_node
	stuck_offset = global_position - prey_node.global_position
	velocity = Vector2.ZERO
	# 2. Access the PREY'S shape (if you actually want the prey to stop colliding)
	var prey_shape = prey_node.get_node_or_null("CollisionShape2D") 
	if prey_shape:
		prey_shape.set_deferred("disabled", true)
	else:
		print("Warning: No CollisionShape2D found on prey!")
	

func unstick_from_prey() -> void:
	stuck_to = null
	stuck_offset = Vector2.ZERO

func update_trajectory_dots() -> void:
	# Hide trajectory dots when tongue is active
	if tongue_active:
		for dot in dots:
			dot.visible = false
		return

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
	var max_bounces = 3  # Limit reflections to avoid infinite loop

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
			current_pos = result.position + current_dir * 0.1  # Small offset to prevent sticking
			remaining_length -= segment_length
			max_bounces -= 1
		else:
			# No collision, finish
			break

	# Hide any remaining dots
	for i in range(dot_index, dots.size()):
		dots[i].visible = false

# ===== Tongue Projectile System =====

func launch_tongue() -> void:
	"""Launch tongue projectile towards mouse cursor"""
	if tongue_active or projectile_active or stuck_to != null:
		return
	
	# Calculate direction from player to mouse
	var dir = (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	
	# Initialize tongue state
	tongue_active = true
	tongue_extending = true
	tongue_retracting = false
	tongue_direction = dir
	tongue_current_length = 0.0
	caught_prey = null
	
	# Make tongue visible and initialize it
	if tongue_line:
		tongue_line.position = Vector2.ZERO
		
		tongue_line.visible = true
		tongue_line.clear_points()
		tongue_line.add_point(Vector2.ZERO)
		tongue_line.add_point(Vector2.ZERO)

func update_tongue_physics(delta: float) -> void:
	"""Update tongue extending/retracting and collision detection"""
	if not tongue_active or not tongue_line:
		return
	
	var start_global_pos = global_position
	
	if tongue_extending:
		# Extend tongue outward
		tongue_current_length += TONGUE_SPEED * delta
		
		# Calculate tongue tip position
		var tongue_tip_pos = tongue_direction * tongue_current_length
		
		# Check for collision with prey using raycast
		var space_state = get_world_2d().direct_space_state
		var ray_end = start_global_pos + tongue_tip_pos
		var query = PhysicsRayQueryParameters2D.create(start_global_pos, ray_end)
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)
		
		if result:
			var collider = result.collider
			
			# Adjust current length to hit point to avoid clipping through walls
			tongue_current_length = start_global_pos.distance_to(result.position)
			var hit_tip_pos = tongue_direction * tongue_current_length
			update_tongue_visual(hit_tip_pos)
			
			# Check if we hit prey
			if collider != null and collider.is_in_group("prey") and collider is CharacterBody2D:
				catch_prey(collider as CharacterBody2D)
			else:
				# Hit something else (like TileSet, wall, etc.)
				tongue_extending = false
				tongue_retracting = true
			return
		
		# Check if reached max length
		if tongue_current_length >= TONGUE_MAX_LENGTH:
			tongue_extending = false
			tongue_retracting = true
		
		# Update tongue Line2D visual
		update_tongue_visual(tongue_tip_pos)
	
	elif tongue_retracting:
		# Retract tongue back to player
		tongue_current_length -= TONGUE_RETRACT_SPEED * delta
		
		# Update tongue visual
		var tongue_tip_pos = tongue_direction * max(tongue_current_length, 0.0)
		update_tongue_visual(tongue_tip_pos)
		
		# Check if fully retracted
		if tongue_current_length <= 0.0:
			finish_tongue_action()

func catch_prey(prey_node: CharacterBody2D) -> void:
	"""Called when tongue collides with prey"""
	caught_prey = prey_node
	tongue_extending = false
	tongue_retracting = true
	prey_pull_start_pos = prey_node.global_position
	
	# Disable prey collision
	var prey_shape = prey_node.get_node_or_null("CollisionShape2D")
	if prey_shape:
		prey_shape.set_deferred("disabled", true)
	
	# Set prey to being pulled state if it has the method
	if prey_node.has_method("set_pulled_state"):
		prey_node.set_pulled_state(true)

func update_prey_pull(delta: float) -> void:
	"""Update prey position to follow tongue tip as it retracts"""
	if caught_prey == null or not tongue_retracting:
		return
	
	var start_global_pos = global_position
	
	# Calculate target position (tongue tip in global coordinates)
	var tongue_tip_global = start_global_pos + (tongue_direction * tongue_current_length)
	
	# Smoothly move prey towards tongue tip
	var prey_current_pos = caught_prey.global_position
	var move_distance = PREY_PULL_SPEED * delta
	caught_prey.global_position = prey_current_pos.move_toward(tongue_tip_global, move_distance)

func finish_tongue_action() -> void:
	"""Clean up tongue action when finished and stick to prey if caught"""
	tongue_active = false
	tongue_extending = false
	tongue_retracting = false
	tongue_current_length = 0.0
	
	# Hide tongue visual
	if tongue_line:
		tongue_line.visible = false
		tongue_line.clear_points()
	
	# Handle caught prey
	if caught_prey != null:
		var prey = caught_prey
		caught_prey = null # Clear reference before sticking to avoid logic loops
		
		# Clear pulled state on prey
		if prey.has_method("set_pulled_state"):
			prey.set_pulled_state(false)
		
		# Place prey at tongue start position (player center) for immediate sticking
		prey.global_position = global_position
		
		# Use existing sticking logic to attach player to prey
		stick_to_prey(prey)
		# Note: projectile_active is set to false in stick_to_prey()
		# Player can now left-click to launch from the prey

func update_tongue_visual(tongue_tip_local: Vector2) -> void:
	"""Update Line2D points to visualize tongue"""
	if not tongue_line:
		return
	
	tongue_line.clear_points()
	tongue_line.add_point(Vector2.ZERO)  # Start at player center
	tongue_line.add_point(tongue_tip_local)  # End at tongue tip
