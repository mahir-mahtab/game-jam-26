extends Area2D

# This creates a file picker in the Inspector!
@export_file("*.tscn") var next_level_scene: String

func _ready() -> void:
	# Signal is already connected in the .tscn file via Editor
	pass

func _on_body_entered(body: Node2D) -> void:
	# 1. Check if the object entering is the Player
	if body.is_in_group("player"):
		_load_next_level()

func _load_next_level() -> void:
	if next_level_scene == "":
		print("Error: Next level scene is not set in the Inspector!")
		return
	
	print("Loading next level...")
	
	# "call_deferred" is safer when changing scenes during a physics collision
	call_deferred("_switch_scene")

func _switch_scene() -> void:
	get_tree().change_scene_to_file(next_level_scene)
