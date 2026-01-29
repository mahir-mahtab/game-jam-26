extends Camera2D

@export var max_shake = 10.0
@export var shake_fade = 20.0

# Zoom effect settings
@export var kill_zoom_amount: float = 0.3  # How much to zoom in
@export var kill_zoom_duration: float = 0.25  # How long to zoom in
@export var kill_zoom_hold: float = 0.15      # How long to hold the zoom
@export var kill_zoom_out_duration: float = 0.3  # How long to zoom back out

var _shake_strength: float = 0.0
var _base_zoom: Vector2 = Vector2.ONE
var _is_zooming: bool = false

# Spotlight/vignette overlay
var _spotlight_layer: CanvasLayer = null
var _spotlight_rect: ColorRect = null

func _ready() -> void:
	_base_zoom = zoom
	_setup_spotlight()

func _setup_spotlight() -> void:
	# Create a CanvasLayer for the overlay effect
	_spotlight_layer = CanvasLayer.new()
	_spotlight_layer.layer = 100  # On top of everything
	add_child(_spotlight_layer)
	
	# Create the vignette/spotlight effect using a ColorRect with a shader
	_spotlight_rect = ColorRect.new()
	_spotlight_rect.anchors_preset = Control.PRESET_FULL_RECT
	_spotlight_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spotlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spotlight_rect.visible = false
	
	# Create spotlight shader
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float radius : hint_range(0.0, 1.0) = 0.3;
uniform float softness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float vignette = smoothstep(radius, radius + softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity * 0.85);
}
"""
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("intensity", 0.0)
	shader_material.set_shader_parameter("radius", 0.25)
	shader_material.set_shader_parameter("softness", 0.35)
	
	_spotlight_rect.material = shader_material
	_spotlight_layer.add_child(_spotlight_rect)

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

func trigger_kill_zoom() -> void:
	if _is_zooming: return
	_is_zooming = true
	
	var target_zoom = _base_zoom + Vector2(kill_zoom_amount, kill_zoom_amount)
	
	# Show spotlight effect
	_spotlight_rect.visible = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	
	# Zoom in and fade in spotlight
	tween.tween_property(self, "zoom", target_zoom, kill_zoom_duration)
	tween.tween_method(_set_spotlight_intensity, 0.0, 1.0, kill_zoom_duration)
	
	# Hold phase
	tween.chain().tween_interval(kill_zoom_hold)
	
	# Zoom out and fade out spotlight
	tween.chain().set_parallel(true)
	tween.tween_property(self, "zoom", _base_zoom, kill_zoom_out_duration).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_spotlight_intensity, 1.0, 0.0, kill_zoom_out_duration)
	
	tween.finished.connect(_on_kill_zoom_finished)

func _set_spotlight_intensity(value: float) -> void:
	if _spotlight_rect and _spotlight_rect.material:
		(_spotlight_rect.material as ShaderMaterial).set_shader_parameter("intensity", value)

func _on_kill_zoom_finished() -> void:
	_is_zooming = false
	_spotlight_rect.visible = false
