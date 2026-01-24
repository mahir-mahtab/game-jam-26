extends CharacterBody2D

const SPEED = 300.0
const DOT_SPACING = 18.0
const MAX_LENGTH = 1000.0
const DOT_SCALE = 0.12
const PROJECTILE_SPEED = 800.0
const PROJECTILE_DECELERATION = 300.0
const BOUNCE_DAMPING = 0.6

# Reference to your AnimatedSprite2D node
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dots_container: Node2D = $TrajectoryDots
@onready var dot_template: Sprite2D = $TrajectoryDots/DotTemplate

var dots: Array[Sprite2D] = []
var projectile_active := false
var stuck_to: Node2D = null
var stuck_offset := Vector2.ZERO

func _ready() -> void:
	# Build dot pool from template
	dot_template.visible = false
	var max_dots := int(MAX_LENGTH / DOT_SPACING)
	for i in range(max_dots):
		var dot := dot_template.duplicate() as Sprite2D
		dot.visible = true
		dot.scale = Vector2.ONE * DOT_SCALE
		dots_container.add_child(dot)
		dots.append(dot)

func _physics_process(_delta: float) -> void:
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not projectile_active:
			launch_projectile()

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

func unstick_from_prey() -> void:
	stuck_to = null
	stuck_offset = Vector2.ZERO

func update_trajectory_dots() -> void:
	# Start from player's center (relative to the player node)
	var start_local_pos = Vector2(0, -35)
	var start_global_pos = global_position + start_local_pos

	var mouse_pos = get_global_mouse_position()
	var ray_direction = (mouse_pos - start_global_pos).normalized()
	if ray_direction == Vector2.ZERO:
		ray_direction = Vector2.RIGHT

	var space_state = get_world_2d().direct_space_state
	var end_global = start_global_pos + ray_direction * MAX_LENGTH
	var query = PhysicsRayQueryParameters2D.create(start_global_pos, end_global)
	query.exclude = [get_rid()] # Exclude the player
	var result = space_state.intersect_ray(query)

	var hit_length := MAX_LENGTH
	if result:
		hit_length = start_global_pos.distance_to(result.position)

	for i in range(dots.size()):
		var dist := (i + 1) * DOT_SPACING
		var dot := dots[i]
		if dist > hit_length:
			dot.visible = false
			continue
		var dot_global = start_global_pos + ray_direction * dist
		dot.global_position = dot_global
		var alpha = clamp(1.0 - (dist / MAX_LENGTH), 0.0, 1.0)
		dot.modulate = Color(1, 1, 1, alpha)
		dot.visible = true
