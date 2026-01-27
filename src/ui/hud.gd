extends CanvasLayer

@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var charge_indicator: ProgressBar = $MarginContainer/VBoxContainer/ChargeIndicator
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel

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
	# Try to find player by common names
	var possible_names = ["player", "CharacterBody2D", "Player"]
	for node_name in possible_names:
		var node = scene.get_node_or_null(node_name)
		if node != null and node is CharacterBody2D:
			return node
	# Fallback: search for player in "player" group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is CharacterBody2D:
		return players[0]
	return null

func _update_display() -> void:
	if feedback_label == null or charge_indicator == null or health_bar == null or health_label == null:
		return
	if player == null or not is_instance_valid(player):
		feedback_label.text = "Projectile: ?"
		charge_indicator.value = 0.0
		health_bar.value = 0.0
		health_label.text = "Health: ?"
		return

	_update_health_display()
	
	# Use public API methods
	if player.has_method("is_projectile_active") and player.is_projectile_active():
		feedback_label.text = "Projectile: IN FLIGHT"
		charge_indicator.value = 0.0
	elif player.has_method("is_tongue_active") and player.is_tongue_active():
		feedback_label.text = "Tongue: ACTIVE"
		charge_indicator.value = 1.0
	elif player.has_method("is_stuck") and player.is_stuck():
		feedback_label.text = "Projectile: READY (stuck)"
		charge_indicator.value = 2.0
	else:
		feedback_label.text = "Tongue: READY (find prey)"
		charge_indicator.value = 0.0

func _update_health_display() -> void:
	if not player.has_method("get_health") or not player.has_method("get_max_health"):
		return
	var current = float(player.get_health())
	var maximum = float(player.get_max_health())
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "Health: %d / %d" % [int(round(current)), int(round(maximum))]
