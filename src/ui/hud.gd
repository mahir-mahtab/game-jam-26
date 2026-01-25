extends CanvasLayer

@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var charge_indicator: ProgressBar = $MarginContainer/VBoxContainer/ChargeIndicator

var player: CharacterBody2D = null

func _ready() -> void:
	player = _find_player()
	_update_display()

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()
	_update_display()

func _find_player() -> CharacterBody2D:
	var scene = get_tree().get_current_scene()
	if scene == null:
		return null
	var node = scene.get_node_or_null("player")
	if node != null and node is CharacterBody2D:
		return node
	return null

func _update_display() -> void:
	if feedback_label == null or charge_indicator == null:
		return
	if player == null or not is_instance_valid(player):
		feedback_label.text = "Projectile: ?"
		charge_indicator.value = 0.0
		return
	var stuck_to = player.get("stuck_to")
	var projectile_active = player.get("projectile_active")
	if projectile_active:
		feedback_label.text = "Projectile: IN FLIGHT"
		charge_indicator.value = 0.0
	elif stuck_to != null:
		feedback_label.text = "Projectile: READY (stuck)"
		charge_indicator.value = 2.0
	else:
		feedback_label.text = "Projectile: LOCKED (find prey)"
		charge_indicator.value = 0.0
