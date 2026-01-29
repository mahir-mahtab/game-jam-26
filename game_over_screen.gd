extends CanvasLayer

func _ready() -> void:
	visible = false # Hide it when the game starts

func game_over() -> void:
	visible = true
	get_tree().paused = true # Freezes the game/enemies

func _on_restart_button_pressed() -> void:
	get_tree().paused = false # Unpause before reloading!
	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	get_tree().paused = false # Unpause before quitting!
	get_tree().quit()
