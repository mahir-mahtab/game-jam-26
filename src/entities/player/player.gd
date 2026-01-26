extends CharacterBody2D

## Player State Machine
## Features: FSM Architecture + Equivalent Exchange + Shield Support

# ===== Constants =====
const SPEED = 300.0
const PROJECTILE_SPEED = 1000.0
const PROJECTILE_DECELERATION = 400.0
const BOUNCE_DAMPING = 0.5
const MAX_BOUNCE_FOR_PLAYER = 2

const MAX_HEALTH = 100.0
const HEALTH_DECAY_PER_SEC = 10.0

const TONGUE_SPEED = 1500.0
const TONGUE_MAX_LENGTH = 800.0
const TONGUE_RETRACT_SPEED = 2000.0
const PREY_PULL_SPEED = 900.0
const TONGUE_WIDTH = 4.0

# ===== Visuals =====
const DOT_SPACING = 21.0
const MAX_LENGTH = 1000.0
const DOT_SCALE = 0.02

# ===== State Enum =====
enum State {
	IDLE,
	MOVING,
	PROJECTILE,
	STUCK,
	TONGUE_EXTEND,
	TONGUE_RETRACT
}

# ===== Node References =====
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dots_container: Node2D = $TrajectoryDots
@onready var dot_template: Sprite2D = $TrajectoryDots/DotTemplate
@onready var camera: Camera2D = $Camera2D
# ===== State Variables =====
var current_state: State = State.IDLE
var tongue_line: Line2D = null
var dots: Array[Sprite2D] = []

var health := MAX_HEALTH
var bounce_count := 0

# Stuck state data
var stuck_to: Node2D = null
var stuck_offset := Vector2.ZERO

# Tongue state data
var tongue_direction := Vector2.ZERO
var tongue_current_length := 0.0
var caught_prey: CharacterBody2D = null

# ===== Lifecycle =====

func _ready() -> void:
	_setup_trajectory_dots()
	_setup_tongue_visual()
	add_to_group("player")

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.PROJECTILE:
			_process_projectile(delta)
		State.STUCK:
			_process_stuck(delta)
		State.TONGUE_EXTEND:
			_process_tongue_extend(delta)
		State.TONGUE_RETRACT:
			_process_tongue_retract(delta)

func _process(delta: float) -> void:
	_update_health(delta)
	_update_trajectory_dots()

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_left_click()
		MOUSE_BUTTON_RIGHT:
			_handle_right_click()

# ===== Input Handlers =====

func _handle_left_click() -> void:
	# Projectile launch only when STUCK (The "Exchange")
	if current_state == State.STUCK:
		_launch_projectile()

func _handle_right_click() -> void:
	# Tongue allowed when not STUCK and not already using tongue
	if current_state in [State.IDLE, State.MOVING, State.PROJECTILE]:
		_launch_tongue()

# ===== State Processors =====

func _process_idle(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		_change_state(State.MOVING)
		_process_moving(delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		animated_sprite.play("idle")
		move_and_slide()

func _process_moving(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction == Vector2.ZERO:
		_change_state(State.IDLE)
		return
	
	velocity = direction * SPEED
	if direction.x != 0:
		animated_sprite.flip_h = (direction.x < 0)
	animated_sprite.play("run")
	move_and_slide()

func _process_projectile(delta: float) -> void:
	var current_speed = velocity.length()
	# Stop if too slow
	if current_speed < 10.0:
		velocity = Vector2.ZERO
		bounce_count = 0
		_change_state(State.IDLE)
		return
	
	# Apply deceleration
	var new_speed = max(current_speed - PROJECTILE_DECELERATION * delta, 0.0)
	velocity = velocity.normalized() * new_speed
	
	# Check collisions
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider != null:
			if collider.is_in_group("prey"):
				# Direct impact catch
				_stick_to_prey(collider)
			elif collider.is_in_group("breakingwall"):
				if collider.has_method("break_wall"):
					collider.break_wall()
				velocity = velocity * .6
			else:
				# Wall bounce
				velocity = velocity.bounce(collision.get_normal()) * BOUNCE_DAMPING
				bounce_count += 1
				if bounce_count >= MAX_BOUNCE_FOR_PLAYER:
					velocity *= 0.1

func _process_stuck(_delta: float) -> void:
	velocity = Vector2.ZERO
	if stuck_to != null and is_instance_valid(stuck_to):
		global_position = stuck_to.global_position + stuck_offset
	else:
		# Prey was destroyed or lost, return to idle
		_unstick()
		_change_state(State.IDLE)

func _process_tongue_extend(delta: float) -> void:
	if tongue_line == null:
		_change_state(State.IDLE)
		return
	
	tongue_current_length += TONGUE_SPEED * delta
	var tongue_tip_pos = tongue_direction * tongue_current_length
	
	# Raycast for collision
	var space_state = get_world_2d().direct_space_state
	var ray_end = global_position + tongue_tip_pos
	var query = PhysicsRayQueryParameters2D.create(global_position, ray_end)
	query.exclude = [get_rid()]
	
	# Enable Area collisions for Shields
	query.collide_with_areas = true 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		tongue_current_length = global_position.distance_to(result.position)
		var hit_tip_pos = tongue_direction * tongue_current_length
		_update_tongue_visual(hit_tip_pos)
		
		var collider = result.collider
		
		# Check Shield Group First
		if collider.is_in_group("shield"):
			print("Clang! Hit a shield.")
			_change_state(State.TONGUE_RETRACT)
			return
			
		elif collider != null and collider.is_in_group("prey") and collider is CharacterBody2D:
			_catch_prey(collider as CharacterBody2D)
		else:
			# Hit wall
			_change_state(State.TONGUE_RETRACT)
		return
	
	# Max length reached
	if tongue_current_length >= TONGUE_MAX_LENGTH:
		_change_state(State.TONGUE_RETRACT)
	
	_update_tongue_visual(tongue_tip_pos)

func _process_tongue_retract(delta: float) -> void:
	tongue_current_length -= TONGUE_RETRACT_SPEED * delta
	
	# Pull caught prey along
	if caught_prey != null and is_instance_valid(caught_prey):
		var tongue_tip_global = global_position + (tongue_direction * tongue_current_length)
		
		# Move prey towards tongue tip
		var move_distance = PREY_PULL_SPEED * delta
		caught_prey.global_position = caught_prey.global_position.move_toward(tongue_tip_global, move_distance)
	
	var tongue_tip_pos = tongue_direction * max(tongue_current_length, 0.0)
	_update_tongue_visual(tongue_tip_pos)
	
	# Fully retracted
	if tongue_current_length <= 0.0:
		_finish_tongue()

# ===== State Transitions =====

func _change_state(new_state: State) -> void:
	var old_state = current_state
	current_state = new_state
	
	# EXIT logic
	if old_state == State.PROJECTILE:
		# Reset rotation and re-enable standard flipping when leaving projectile state
		animated_sprite.rotation = 0
		bounce_count = 0

	# ENTER logic
	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.MOVING:
			animated_sprite.play("run")
		State.PROJECTILE:
			# Play the bite animation and ensure flip_h is off 
			# so the "right side" (mouth) faces the direction of travel
			animated_sprite.play("bite") 
			animated_sprite.flip_h = false 
		State.STUCK:
			velocity = Vector2.ZERO
			# Keep the rotation if you want them to look "latched on" 
			# or reset it here if they should stand upright on the prey.
	current_state = new_state
	
	# Enter new state
	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.MOVING:
			animated_sprite.play("run")
		State.PROJECTILE:
			animated_sprite.play("run")
		State.STUCK:
			velocity = Vector2.ZERO
		State.TONGUE_EXTEND:
			pass
		State.TONGUE_RETRACT:
			pass

# ===== Actions =====
@export var dead_body_scene: PackedScene

func _launch_projectile() -> void:
	# 1. Spawn the dead body before moving
	if dead_body_scene:
		var body = dead_body_scene.instantiate()
		body.global_position = global_position
		# Match the player's current flip direction so the body faces the right way
		var body_sprite = body.get_node("AnimatedSprite2D")
		if body_sprite:
			body_sprite.flip_h = animated_sprite.flip_h
			
		get_parent().add_child(body)

	# 2. Proceed with the launch logic
	_unstick()
	var dir = (get_global_mouse_position() - global_position).normalized()
	velocity = dir * PROJECTILE_SPEED
	bounce_count = 0
	_change_state(State.PROJECTILE)
	
func _launch_tongue() -> void:
	# Cancel projectile if active
	if current_state == State.PROJECTILE:
		velocity = Vector2.ZERO
	
	var dir = (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	
	tongue_direction = dir
	tongue_current_length = 0.0
	caught_prey = null
	
	if tongue_line:
		tongue_line.position = Vector2.ZERO
		tongue_line.visible = true
		tongue_line.clear_points()
		tongue_line.add_point(Vector2.ZERO)
		tongue_line.add_point(Vector2.ZERO)
	
	_change_state(State.TONGUE_EXTEND)

func _stick_to_prey(prey_node: Node2D) -> void:
	stuck_to = prey_node
	stuck_offset = global_position - prey_node.global_position
	velocity = Vector2.ZERO
	
	var prey_shape = prey_node.get_node_or_null("CollisionShape2D")
	if prey_shape:
		prey_shape.set_deferred("disabled", true)
	else:
		print("Warning: No CollisionShape2D found on prey!")
		
	# CRITICAL FIX 2: FREEZE THE PREY
	if prey_node.has_method("set_zombified"):
		prey_node.set_zombified(true)
	
	_change_state(State.STUCK)

func _unstick() -> void:
	stuck_to = null
	stuck_offset = Vector2.ZERO

func _catch_prey(prey_node: CharacterBody2D) -> void:
	caught_prey = prey_node
	if camera: camera.trigger_shake()
	
	# Add collision exception so prey can be pulled to center
	add_collision_exception_with(prey_node)
	
	if prey_node.has_method("set_pulled_state"):
		prey_node.set_pulled_state(true)
	
	_change_state(State.TONGUE_RETRACT)

func _finish_tongue() -> void:
	# Hide tongue
	if tongue_line:
		tongue_line.visible = false
		tongue_line.clear_points()
	
	# Handle caught prey
	if caught_prey != null and is_instance_valid(caught_prey):
		var prey = caught_prey
		caught_prey = null
		
		# Reset pulled state
		if prey.has_method("set_pulled_state"):
			prey.set_pulled_state(false)
		
		# Snap to position
		prey.global_position = global_position
		
		# Stick to it
		_stick_to_prey(prey)
	else:
		caught_prey = null
		_change_state(State.IDLE)

# ===== Visual Updates =====

func _update_trajectory_dots() -> void:
	# Only show when STUCK
	if current_state != State.STUCK:
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
	var max_bounces = 3 # Kept Enemy branch setting

	while remaining_length > 0 and dot_index < dots.size() and max_bounces >= 0:
		var ray_end = current_pos + current_dir * remaining_length
		var query = PhysicsRayQueryParameters2D.create(current_pos, ray_end)
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)

		var segment_length = remaining_length
		if result:
			segment_length = current_pos.distance_to(result.position)
		
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
			current_dir = current_dir.bounce(result.normal)
			current_pos = result.position + current_dir * 0.1
			remaining_length -= segment_length
			max_bounces -= 1
		else:
			break

	for i in range(dot_index, dots.size()):
		dots[i].visible = false

func _update_tongue_visual(tongue_tip_local: Vector2) -> void:
	if not tongue_line:
		return
	tongue_line.clear_points()
	tongue_line.add_point(Vector2.ZERO)
	tongue_line.add_point(tongue_tip_local)

func _update_health(delta: float) -> void:
	if current_state == State.STUCK || current_state==State.PROJECTILE:
		return
	health = max(health - HEALTH_DECAY_PER_SEC * delta, 0.0)

# ===== Damage Interface =====

func take_damage(amount: float) -> void:
	health -= amount
	print("Player took damage! Health: ", health)
	
	if camera and camera.has_method("trigger_shake"):
		camera.trigger_shake()
		
	if health <= 0:
		print("Player died!")
		get_tree().reload_current_scene()

# ===== Setup =====

func _setup_trajectory_dots() -> void:
	if dot_template:
		dot_template.visible = false
		var max_dots := int(MAX_LENGTH / DOT_SPACING)
		for i in range(max_dots):
			var dot := dot_template.duplicate() as Sprite2D
			dot.visible = true
			dot.scale = Vector2.ONE * DOT_SCALE * 1.0 / (1 + (i * 1.0) / 10)
			dots_container.add_child(dot)
			dots.append(dot)

func _setup_tongue_visual() -> void:
	tongue_line = get_node_or_null("Tongue")
	if tongue_line == null:
		tongue_line = Line2D.new()
		tongue_line.name = "Tongue"
		tongue_line.width = TONGUE_WIDTH
		tongue_line.default_color = Color(1.0, 0.4, 0.5, 1.0)
		tongue_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		tongue_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		tongue_line.visible = false
		tongue_line.z_index = -1
		add_child(tongue_line)

# ===== Public API (for HUD/external access) =====

func get_state() -> State:
	return current_state

func is_stuck() -> bool:
	return current_state == State.STUCK

func is_projectile_active() -> bool:
	return current_state == State.PROJECTILE

func is_tongue_active() -> bool:
	return current_state in [State.TONGUE_EXTEND, State.TONGUE_RETRACT]

func get_health() -> float:
	return health

func get_max_health() -> float:
	return MAX_HEALTH
