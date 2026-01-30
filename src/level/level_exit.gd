extends Area2D

# This creates a file picker in the Inspector!
# If left empty, the script will auto-detect the next level based on current scene
@export_file("*.tscn") var next_level_scene: String

# Define the level progression order
const LEVEL_ORDER = [
	"res://src/level/level1.tscn",
	"res://src/level/level2.tscn",
	"res://src/level/level3.tscn",
	"res://src/level/level4.tscn",
	"res://src/level/level34.tscn"
]

# The scene to load after all levels are completed
const FINISH_SCENE = "res://src/ui/victory_screen.tscn"

func _ready() -> void:
	# Signal is already connected in the .tscn file via Editor
	pass

func _on_body_entered(body: Node2D) -> void:
	# 1. Check if the object entering is the Player
	if body.is_in_group("player"):
		_load_next_level()

func _load_next_level() -> void:
	var target_scene = _get_next_scene()
	
	if target_scene == "":
		print("Error: Could not determine next level!")
		return
	
	print("Loading next level: " + target_scene)
	
	# "call_deferred" is safer when changing scenes during a physics collision
	call_deferred("_switch_scene", target_scene)

func _get_next_scene() -> String:
	# Auto-detect based on the current scene (prioritize this for correct progression)
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	# Find the current level in the progression order
	for i in range(LEVEL_ORDER.size()):
		if current_scene_path == LEVEL_ORDER[i]:
			# If this is the last level, go to finish
			if i >= LEVEL_ORDER.size() - 1:
				return FINISH_SCENE
			# Otherwise, return the next level
			return LEVEL_ORDER[i + 1]
	
	# If current scene is not in the level order, try to parse the level number
	# This handles edge cases where the path might be slightly different
	var scene_name = current_scene_path.get_file().get_basename()
	
	# Handle numbered levels (level1, level2, etc.)
	if scene_name.begins_with("level"):
		var level_num_str = scene_name.substr(5)  # Get everything after "level"
		if level_num_str.is_valid_int():
			var level_num = int(level_num_str)
			# Find the corresponding next level
			if level_num == 1:
				return "res://src/level/level2.tscn"
			elif level_num == 2:
				return "res://src/level/level3.tscn"
			elif level_num == 3:
				return "res://src/level/level4.tscn"
			elif level_num == 4:
				return "res://src/level/level34.tscn"
			elif level_num == 34 or level_num >= 5:
				return FINISH_SCENE
	
	# Fallback: if a specific next level is set in the Inspector, use that
	if next_level_scene != "":
		return next_level_scene
	
	return ""

func _switch_scene(target_scene: String) -> void:
	get_tree().change_scene_to_file(target_scene)
