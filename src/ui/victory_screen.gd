extends CanvasLayer

@onready var title_label = $Control/VBoxContainer/TitleLabel
@onready var message_label = $Control/VBoxContainer/MessageLabel
@onready var menu_button = $Control/VBoxContainer/MenuButton

func _ready() -> void:
	# Setup the victory screen
	title_label.text = "CONGRATULATIONS!"
	message_label.text = "You have escaped!\nAll levels completed!"
	menu_button.grab_focus()

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_menu_button_pressed()
