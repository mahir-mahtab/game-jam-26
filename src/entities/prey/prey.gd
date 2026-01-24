extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

var being_pulled := false

func _ready() -> void:
	add_to_group("prey")

func _physics_process(_delta: float) -> void:
	# Skip normal movement if being pulled by player's tongue
	if being_pulled:
		return
	
	move_and_slide()

func set_pulled_state(pulled: bool) -> void:
	"""Called by player when prey is being pulled by tongue"""
	being_pulled = pulled
