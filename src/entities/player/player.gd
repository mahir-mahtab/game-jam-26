extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Reference to your AnimatedSprite2D node
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# 1. Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Get direction
	var direction := Input.get_axis("ui_left", "ui_right")
	
	# 4. Handle Flipping and Movement
	if direction != 0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = (direction < 0) # Flip sprite based on direction
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	update_animations(direction)
	move_and_slide()

# 5. Animation Logic Helper
func update_animations(direction):
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	
