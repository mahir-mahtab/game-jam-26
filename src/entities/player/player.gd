extends CharacterBody2D

## ==============================================================================
##  PLAYER CONTROLLER - IMPROVED & JUICED
## ==============================================================================

signal damage_taken  # Emitted when player takes damage

# --- PHYSICS CONSTANTS ---
const SPEED = 300.0
const PROJECTILE_SPEED = 1000.0
const PROJECTILE_DECELERATION = 400.0
const BOUNCE_DAMPING = 0.7 
const MAX_BOUNCE_FOR_PLAYER = 3

# --- HEALTH CONSTANTS ---
const MAX_HEALTH = 100.0
const HEALTH_DECAY_PER_SEC = 15.0

# --- TONGUE CONSTANTS ---
# Reduced speed slightly so the eye can track the movement
const TONGUE_SPEED = 1200.0 
const TONGUE_MAX_LENGTH = 800.0
const TONGUE_RETRACT_SPEED = 2000.0
const PREY_PULL_SPEED = 1000.0
const TONGUE_WIDTH = 4.0
const IMPACT_FREEZE_TIME = 0.1 # Pause for 0.1s when hitting prey to sell the impact

# --- VISUAL CONSTANTS ---
const DOT_SPACING = 21.0
const MAX_LENGTH = 1000.0
const DOT_SCALE = 0.02
const HEAD_OFFSET = Vector2(1, -14.5)

# ===== State Enum =====
enum State {
	IDLE,
	PROJECTILE,
	STUCK,
	TONGUE_EXTEND,
	TONGUE_LATCHED, # NEW STATE: Freezes the tongue momentarily on impact
	TONGUE_RETRACT
}

@export var dead_body_scene: PackedScene

# ===== Node References =====
@onready var sfx_bite: AudioStreamPlayer2D = $BiteSound
@onready var sfx_bounce: AudioStreamPlayer2D = $BounceSound
@onready var sfx_throw: AudioStreamPlayer2D = $ThrowSound
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
var stuck_to: Node2D = null
var stuck_offset := Vector2.ZERO
var tongue_direction := Vector2.ZERO
var tongue_current_length := 0.0
var caught_prey: CharacterBody2D = null
var latch_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	motion_mode = MOTION_MODE_FLOATING
	_setup_trajectory_dots()
	_setup_tongue_visual()

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:           _process_idle(delta)
		State.PROJECTILE:     _process_projectile(delta)
		State.STUCK:          _process_stuck(delta)
		State.TONGUE_EXTEND:  _process_tongue_extend(delta)
		State.TONGUE_LATCHED: _process_tongue_latched(delta) # Handle the pause
		State.TONGUE_RETRACT: _process_tongue_retract(delta)

func _process(delta: float) -> void:
	_update_health(delta)
	_update_trajectory_dots()

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed: return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click()

# --- INPUT & STATE LOGIC ---
func _handle_left_click() -> void:
	if current_state == State.STUCK:
		_launch_projectile()
	elif current_state in [State.IDLE, State.PROJECTILE]:
		_launch_tongue()

func _process_idle(_delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	animated_sprite.play("idle")
	move_and_slide()

func _process_projectile(delta: float) -> void:
	var current_speed = velocity.length()
	if current_speed < 50.0:
		velocity = Vector2.ZERO
		bounce_count = 0
		_change_state(State.IDLE)
		return

	var new_speed = max(current_speed - PROJECTILE_DECELERATION * delta, 0.0)
	velocity = velocity.normalized() * new_speed
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		sfx_bounce.play(.04)
		if collider.is_in_group("shield"):
			velocity = velocity.bounce(collision.get_normal()) * 0.3
			bounce_count += 1
			global_position += collision.get_normal() * 2.0
		elif collider.is_in_group("prey"):
			_stick_to_prey(collider)
		elif collider.is_in_group("breakingwall"):
			if collider.has_method("break_wall"): collider.break_wall()
			velocity = velocity * 0.8
		else:
			sfx_bounce.play(.4)
			velocity = velocity.bounce(collision.get_normal()) * BOUNCE_DAMPING
			bounce_count += 1
			global_position += collision.get_normal() * 1.0
			if bounce_count >= MAX_BOUNCE_FOR_PLAYER:
				velocity = velocity * 0.4

func _process_stuck(_delta: float) -> void:
	velocity = Vector2.ZERO
	if stuck_to != null and is_instance_valid(stuck_to):
		global_position = stuck_to.global_position + stuck_offset
	else:
		_unstick()
		_change_state(State.IDLE)

func _process_tongue_extend(delta: float) -> void:
	if tongue_line == null:
		_change_state(State.IDLE)
		return
	
	# 1. Increment Length
	tongue_current_length += TONGUE_SPEED * delta
	
	# 2. Setup Raycast
	var head_pos = global_position + HEAD_OFFSET
	var tongue_tip_vector = tongue_direction * tongue_current_length
	var ray_end = head_pos + tongue_tip_vector
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(head_pos, ray_end)
	query.exclude = [get_rid()]
	# IMPORTANT: Disabled area collision to prevent tongue hitting invisible zones
	# Enable only if enemies are purely Area2Ds
	query.collide_with_areas = false 
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	# 3. Update Visuals BEFORE state change ensures the frame is drawn
	if result:
		# Snap length to hit position
		tongue_current_length = head_pos.distance_to(result.position)
		tongue_tip_vector = tongue_direction * tongue_current_length
		_update_tongue_visual(tongue_tip_vector)
		
		var collider = result.collider
		if collider.is_in_group("prey") and collider is CharacterBody2D:
			_catch_prey(collider as CharacterBody2D)
		else:
			# Hit wall/shield - Bounce back
			if collider.is_in_group("shield"): print("Tongue blocked.")
			_change_state(State.TONGUE_RETRACT)
		return
	
	# If no hit, check max length
	if tongue_current_length >= TONGUE_MAX_LENGTH:
		_change_state(State.TONGUE_RETRACT)
		
	_update_tongue_visual(tongue_tip_vector)

func _process_tongue_latched(delta: float) -> void:
	# Just wait here for a few frames to let the player see the connection
	latch_timer -= delta
	
	# Keep the line drawn to the prey while frozen
	if caught_prey != null and is_instance_valid(caught_prey):
		var head_pos = global_position + HEAD_OFFSET
		var target_pos = caught_prey.global_position - head_pos
		_update_tongue_visual(target_pos)
		
	if latch_timer <= 0:
		_change_state(State.TONGUE_RETRACT)

func _process_tongue_retract(delta: float) -> void:
	var head_pos = global_position + HEAD_OFFSET
	
	if caught_prey != null and is_instance_valid(caught_prey):
		# Pull prey toward head
		var move_distance = PREY_PULL_SPEED * delta
		caught_prey.global_position = caught_prey.global_position.move_toward(head_pos, move_distance)
		
		# Tongue tip follows the prey
		var tongue_tip_pos = caught_prey.global_position - head_pos
		_update_tongue_visual(tongue_tip_pos)
		
		# Finish when prey reaches the head
		if caught_prey.global_position.distance_to(head_pos) < 15.0: # Increased threshold slightly
			_finish_tongue()
	else:
		# Retract empty tongue
		tongue_current_length -= TONGUE_RETRACT_SPEED * delta
		var tongue_tip_pos = tongue_direction * max(tongue_current_length, 0.0)
		_update_tongue_visual(tongue_tip_pos)
		if tongue_current_length <= 0.0: _finish_tongue()

# --- ACTIONS ---
func _change_state(new_state: State) -> void:
	var old_state = current_state
	current_state = new_state
	
	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.PROJECTILE:
			animated_sprite.play("bite")
			animated_sprite.flip_h = false 
		State.STUCK:
			velocity = Vector2.ZERO
		State.TONGUE_LATCHED:
			latch_timer = IMPACT_FREEZE_TIME

func _launch_projectile() -> void:
	sfx_throw.play(.4)
	if dead_body_scene:
		var body = dead_body_scene.instantiate()
		body.global_position = global_position
		var body_sprite = body.get_node_or_null("AnimatedSprite2D")
		if body_sprite:
			body_sprite.flip_h = animated_sprite.flip_h
		get_parent().add_child(body)
	_unstick()
	var dir = (get_global_mouse_position() - global_position).normalized()
	velocity = dir * PROJECTILE_SPEED
	bounce_count = 0
	_change_state(State.PROJECTILE)
	
func _launch_tongue() -> void:
	if current_state == State.PROJECTILE: velocity = Vector2.ZERO
	
	# 1. FIX: Calculate direction from HEAD, not FEET
	# This matches the math used in _update_trajectory_dots
	var head_global_pos = global_position + HEAD_OFFSET
	var dir = (get_global_mouse_position() - head_global_pos).normalized()
	
	if dir == Vector2.ZERO: dir = Vector2.RIGHT
	tongue_direction = dir
	tongue_current_length = 0.0
	caught_prey = null
	
	if tongue_line:
		tongue_line.visible = true
		tongue_line.clear_points()
		# Ensure the line visually starts at the head
		tongue_line.add_point(HEAD_OFFSET) 
		tongue_line.add_point(HEAD_OFFSET)
		
	_change_state(State.TONGUE_EXTEND)
func _stick_to_prey(prey_node: Node2D) -> void:
	stuck_to = prey_node
	stuck_offset = global_position - prey_node.global_position
	velocity = Vector2.ZERO
	var prey_shape = prey_node.get_node_or_null("CollisionShape2D")
	if prey_shape: prey_shape.set_deferred("disabled", true)
	if prey_node.has_method("set_zombified"): prey_node.set_zombified(true)
	_change_state(State.STUCK)

func _unstick() -> void:
	if stuck_to != null and is_instance_valid(stuck_to):
		stuck_to.queue_free()
	stuck_to = null
	stuck_offset = Vector2.ZERO

func _catch_prey(prey_node: CharacterBody2D) -> void:
	sfx_bite.play()
	caught_prey = prey_node
	
	if camera:
		if camera.has_method("trigger_shake"): camera.trigger_shake()
		if camera.has_method("trigger_kill_zoom"): camera.trigger_kill_zoom()
		
	add_collision_exception_with(prey_node)
	if prey_node.has_method("set_pulled_state"): prey_node.set_pulled_state(true)
	
	# Go to LATCHED state first instead of RETRACT immediately
	_change_state(State.TONGUE_LATCHED)

func _finish_tongue() -> void:
	if tongue_line:
		tongue_line.visible = false
		tongue_line.clear_points()
		
	if caught_prey != null and is_instance_valid(caught_prey):
		var prey = caught_prey
		caught_prey = null
		if prey.has_method("set_pulled_state"): prey.set_pulled_state(false)
		prey.global_position = global_position
		_stick_to_prey(prey)
	else:
		caught_prey = null
		_change_state(State.IDLE)

# --- HELPERS ---
func _update_health(delta: float) -> void:
	if current_state == State.STUCK or current_state == State.PROJECTILE: return
	health = max(health - HEALTH_DECAY_PER_SEC * delta, 0.0)
	if health <= 0:
		die()

func die() -> void:
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	if ui_nodes.size() > 0:
		ui_nodes[0].game_over()
	else:
		get_tree().reload_current_scene()

func take_damage(amount: float) -> void:
	health -= amount
	if camera and camera.has_method("trigger_shake"): camera.trigger_shake()
	_flash_damage()
	damage_taken.emit()
	if health <= 0: die()

func _flash_damage() -> void:
	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", original_modulate, 0.3)

func _update_tongue_visual(tongue_tip_local: Vector2) -> void:
	if not tongue_line: return
	tongue_line.clear_points()
	tongue_line.add_point(HEAD_OFFSET)
	tongue_line.add_point(HEAD_OFFSET + tongue_tip_local)

func _update_trajectory_dots() -> void:
	if current_state != State.STUCK:
		for dot in dots: dot.visible = false
		return
		
	var start_pos = global_position + HEAD_OFFSET
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - start_pos).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	
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
		if result: segment_length = current_pos.distance_to(result.position)
		
		var segment_dot_count = int(segment_length / DOT_SPACING)
		for i in range(segment_dot_count):
			if dot_index >= dots.size(): break
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
		else: break
	
	for i in range(dot_index, dots.size()): dots[i].visible = false

# --- SETUP ---
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
		tongue_line.z_index = 1
		add_child(tongue_line)

# --- PUBLIC API FOR HUD ---
func get_health() -> float: return health
func get_max_health() -> float: return MAX_HEALTH
func is_projectile_active() -> bool: return current_state == State.PROJECTILE
func is_tongue_active() -> bool:
	return current_state in [State.TONGUE_EXTEND, State.TONGUE_LATCHED, State.TONGUE_RETRACT]
func is_stuck() -> bool: return current_state == State.STUCK
