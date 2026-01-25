extends StaticBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("breakingwall")

func break_wall() -> void:
	if animated_sprite.animation != "break":
		animated_sprite.play("break")
		# Disable collision so player doesn't hit it again
		$CollisionShape2D.set_deferred("disabled", true)
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	if animated_sprite.animation == "break":
		queue_free()
