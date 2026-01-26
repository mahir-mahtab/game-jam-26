extends Camera2D

@export var max_shake = 10.0
@export var shake_fade = 20.0

var _shake_strength: float = 0.0

func _process(delta: float) -> void:
	if _shake_strength > 0:
		# Gradually reduce the strength
		_shake_strength = move_toward(_shake_strength, 0, shake_fade * delta)
		
		# Apply to 'offset' so it doesn't interfere with camera movement/position
		offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
	else:
		offset = Vector2.ZERO # Ensure it resets to perfectly still

func trigger_shake() -> void:
	_shake_strength = max_shake
