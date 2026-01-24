extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animated_sprite = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("prey")

func _physics_process(_delta: float) -> void:
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
