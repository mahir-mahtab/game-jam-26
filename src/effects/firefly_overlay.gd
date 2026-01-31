extends CanvasLayer
class_name FireflyOverlay

## Firefly overlay effect that creates ambient floating particles
## Add this scene to any level for a magical atmosphere

@export_group("Particle Settings")
@export var firefly_count: int = 40  ## Number of fireflies
@export var spawn_area: Vector2 = Vector2(1920, 1080)  ## Area to spawn fireflies
@export var spawn_offset: Vector2 = Vector2(-480, -270)  ## Offset from center

@export_group("Movement Settings")
@export var base_speed: float = 20.0  ## Base movement speed
@export var speed_variation: float = 15.0  ## Random speed variation
@export var drift_frequency: float = 0.5  ## How often direction changes
@export var wobble_amount: float = 30.0  ## Sine wave wobble amplitude

@export_group("Visual Settings")
@export var min_size: float = 8.0  ## Minimum firefly size
@export var max_size: float = 18.0  ## Maximum firefly size
@export var glow_color: Color = Color(1.0, 0.92, 0.4, 1.0)  ## Main glow color
@export var glow_intensity: float = 2.5  ## How bright the glow is
@export var color_variation: float = 0.08  ## How much color can vary
@export var follow_camera: bool = true  ## Whether fireflies follow the camera

var fireflies: Array[Node2D] = []
var firefly_data: Array[Dictionary] = []
var shader_material: ShaderMaterial
var camera: Camera2D

func _ready() -> void:
	# Make sure this layer renders above game elements
	layer = 100
	
	# Create shader material
	shader_material = ShaderMaterial.new()
	var shader = load("res://src/effects/firefly_overlay.gdshader")
	if shader:
		shader_material.shader = shader
	
	# Find camera in scene
	await get_tree().process_frame
	camera = get_viewport().get_camera_2d()
	
	# Spawn fireflies
	_spawn_fireflies()

func _spawn_fireflies() -> void:
	for i in range(firefly_count):
		var firefly = _create_firefly()
		add_child(firefly)
		fireflies.append(firefly)
		
		# Store movement data for each firefly
		var data = {
			"velocity": Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized(),
			"speed": base_speed + randf_range(-speed_variation, speed_variation),
			"wobble_offset": randf() * TAU,
			"wobble_speed": randf_range(1.0, 3.0),
			"lifetime": 0.0,
			"direction_change_timer": randf() * drift_frequency,
			"fade_in": randf() * 2.0,  # Staggered fade in
		}
		firefly_data.append(data)

func _create_firefly() -> Node2D:
	var firefly = Node2D.new()
	
	# Create visual representation using ColorRect with shader
	var visual = ColorRect.new()
	var size = randf_range(min_size, max_size)
	visual.size = Vector2(size, size)
	visual.position = Vector2(-size/2, -size/2)  # Center the rect
	
	# Apply shader material with slight color variation
	var mat = shader_material.duplicate() as ShaderMaterial
	var varied_color = glow_color
	varied_color.r += randf_range(-color_variation, color_variation)
	varied_color.g += randf_range(-color_variation, color_variation)
	varied_color.b += randf_range(-color_variation, color_variation)
	mat.set_shader_parameter("glow_color", varied_color)
	mat.set_shader_parameter("glow_intensity", glow_intensity + randf_range(-0.5, 0.5))
	mat.set_shader_parameter("flicker_speed", randf_range(2.0, 4.0))
	mat.set_shader_parameter("flicker_intensity", randf_range(0.15, 0.35))
	visual.material = mat
	
	firefly.add_child(visual)
	
	# Set random starting position
	var start_pos = Vector2(
		randf_range(spawn_offset.x, spawn_offset.x + spawn_area.x),
		randf_range(spawn_offset.y, spawn_offset.y + spawn_area.y)
	)
	firefly.position = start_pos
	firefly.modulate.a = 0.0  # Start invisible for fade in
	
	return firefly

func _process(delta: float) -> void:
	# Update camera reference if following
	if follow_camera and camera:
		var cam_pos = camera.global_position
		offset = cam_pos + spawn_offset
	
	# Update each firefly
	for i in range(fireflies.size()):
		_update_firefly(i, delta)

func _update_firefly(index: int, delta: float) -> void:
	var firefly = fireflies[index]
	var data = firefly_data[index]
	
	# Update lifetime
	data.lifetime += delta
	
	# Fade in effect
	if data.fade_in > 0:
		data.fade_in -= delta
		firefly.modulate.a = clamp(1.0 - data.fade_in / 2.0, 0.0, 1.0)
	else:
		firefly.modulate.a = 1.0
	
	# Update direction change timer
	data.direction_change_timer -= delta
	if data.direction_change_timer <= 0:
		data.direction_change_timer = drift_frequency + randf() * drift_frequency
		# Slightly adjust direction
		var angle_change = randf_range(-PI/4, PI/4)
		data.velocity = data.velocity.rotated(angle_change)
	
	# Calculate wobble
	var wobble = sin(data.lifetime * data.wobble_speed + data.wobble_offset) * wobble_amount
	var perpendicular = data.velocity.rotated(PI/2).normalized()
	
	# Move firefly
	var movement = data.velocity * data.speed + perpendicular * wobble * 0.5
	firefly.position += movement * delta
	
	# Wrap around spawn area (relative to camera if following)
	var bounds_min = spawn_offset
	var bounds_max = spawn_offset + spawn_area
	
	if firefly.position.x < bounds_min.x:
		firefly.position.x = bounds_max.x
	elif firefly.position.x > bounds_max.x:
		firefly.position.x = bounds_min.x
	
	if firefly.position.y < bounds_min.y:
		firefly.position.y = bounds_max.y
	elif firefly.position.y > bounds_max.y:
		firefly.position.y = bounds_min.y
