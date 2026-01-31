extends CanvasLayer

@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var charge_indicator: ProgressBar = $MarginContainer/VBoxContainer/ChargeIndicator
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel
@onready var exit_arrow: Polygon2D = $ExitArrowContainer/Arrow
@onready var exit_arrow_container: Control = $ExitArrowContainer
@onready var pain_vignette: ColorRect = $PainVignette
@onready var restart_button: Button = $MarginContainer/RestartButton

var player: CharacterBody2D = null
var level_exit: Node2D = null
var _original_health_bar_color: Color
var _pain_pulse_time: float = 0.0

func _ready() -> void:
	player = _find_player()
	level_exit = _find_level_exit()
	_update_display()
	_connect_player_signals()
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	
	# Store original health bar color
	if health_bar:
		_original_health_bar_color = health_bar.modulate

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()
		_connect_player_signals()
	if level_exit == null or not is_instance_valid(level_exit):
		level_exit = _find_level_exit()
	_update_display()
	_update_exit_arrow()
	_update_pain_vignette(delta)

func _connect_player_signals() -> void:
	if player and player.has_signal("damage_taken"):
		if not player.is_connected("damage_taken", _on_player_damaged):
			player.connect("damage_taken", _on_player_damaged)

func _on_player_damaged() -> void:
	# Flash health bar red
	if health_bar:
		health_bar.modulate = Color(2.0, 0.2, 0.2, 1.0)  # Bright red
		var tween = create_tween()
		tween.tween_property(health_bar, "modulate", _original_health_bar_color, 0.4)
	
	# Flash pain vignette on damage
	if pain_vignette and pain_vignette.material:
		pain_vignette.material.set_shader_parameter("intensity", 1.0)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _update_pain_vignette(delta: float) -> void:
	if pain_vignette == null or pain_vignette.material == null:
		return
	if player == null or not is_instance_valid(player):
		pain_vignette.material.set_shader_parameter("intensity", 0.0)
		return
	
	if not player.has_method("get_health") or not player.has_method("get_max_health"):
		return
	
	var health_percent = float(player.get_health()) / float(player.get_max_health())
	
	# Calculate base intensity (higher when health is lower)
	var base_intensity = clamp(1.0 - health_percent, 0.0, 1.0)
	
	# Add pulsing effect when critically low (below 30%)
	var pulse_intensity = 0.0
	if health_percent < 0.3:
		_pain_pulse_time += delta * 4.0  # Pulse speed
		pulse_intensity = sin(_pain_pulse_time) * 0.15
	
	# Get current intensity and smoothly transition
	var current = pain_vignette.material.get_shader_parameter("intensity")
	var target = clamp(base_intensity * 0.7 + pulse_intensity, 0.0, 1.0)
	
	# Smooth transition (faster fade in, slower fade out)
	var speed = 8.0 if target > current else 3.0
	var new_intensity = move_toward(current, target, delta * speed)
	
	pain_vignette.material.set_shader_parameter("intensity", new_intensity)

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

func _find_level_exit() -> Node2D:
	# Find the level exit node (levelExit is the name used in level scenes)
	var scene = get_tree().get_current_scene()
	if scene == null:
		return null
	var exit = scene.get_node_or_null("levelExit")
	if exit != null:
		return exit
	# Search recursively as fallback
	return _find_node_by_name(scene, "levelExit")

func _find_node_by_name(node: Node, target_name: String) -> Node2D:
	if node.name == target_name and node is Node2D:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null

func _update_exit_arrow() -> void:
	if exit_arrow == null or exit_arrow_container == null:
		return
	
	# Hide arrow if player or exit not found
	if player == null or not is_instance_valid(player) or level_exit == null or not is_instance_valid(level_exit):
		exit_arrow_container.visible = false
		return
	
	exit_arrow_container.visible = true
	
	# Calculate direction from player to exit
	var direction = (level_exit.global_position - player.global_position).normalized()
	
	# Convert direction to angle (pointing up is 0 degrees)
	var angle = direction.angle() + PI / 2  # Add 90 degrees since arrow points up by default
	exit_arrow.rotation = angle

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
