extends CanvasLayer

## Global scene transition manager with circle/iris wipe effect
## Add this as an autoload singleton named "TransitionManager"

var transition_rect: ColorRect
var is_transitioning: bool = false

# Transition settings
const TRANSITION_DURATION: float = 0.8

func _ready() -> void:
	layer = 128  # Above everything
	_setup_transition_rect()

func _setup_transition_rect() -> void:
	transition_rect = ColorRect.new()
	transition_rect.name = "TransitionRect"
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create iris/circle wipe shader
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform bool invert = false;

void fragment() {
	float dist = distance(UV, center);
	float max_dist = max(
		max(distance(vec2(0.0, 0.0), center), distance(vec2(1.0, 0.0), center)),
		max(distance(vec2(0.0, 1.0), center), distance(vec2(1.0, 1.0), center))
	);
	float normalized_dist = dist / max_dist;
	
	float threshold = progress;
	float alpha;
	
	if (invert) {
		// Circle closing (outside to inside)
		alpha = normalized_dist < (1.0 - threshold) ? 0.0 : 1.0;
	} else {
		// Circle opening (inside to outside)  
		alpha = normalized_dist < threshold ? 0.0 : 1.0;
	}
	
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("progress", 0.0)
	shader_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	shader_material.set_shader_parameter("invert", false)
	
	transition_rect.material = shader_material
	transition_rect.visible = false
	add_child(transition_rect)


func circle_close(center_uv: Vector2 = Vector2(0.5, 0.5), duration: float = TRANSITION_DURATION) -> void:
	"""Circle closes from outside to inside, ending fully black"""
	if is_transitioning:
		return
	is_transitioning = true
	
	var mat = transition_rect.material as ShaderMaterial
	mat.set_shader_parameter("center", center_uv)
	mat.set_shader_parameter("invert", true)
	mat.set_shader_parameter("progress", 0.0)
	transition_rect.visible = true
	
	var tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	await tween.finished
	is_transitioning = false


func circle_open(center_uv: Vector2 = Vector2(0.5, 0.5), duration: float = TRANSITION_DURATION) -> void:
	"""Circle opens from inside to outside, revealing the scene"""
	if is_transitioning:
		return
	is_transitioning = true
	
	var mat = transition_rect.material as ShaderMaterial
	mat.set_shader_parameter("center", center_uv)
	mat.set_shader_parameter("invert", false)
	mat.set_shader_parameter("progress", 0.0)
	transition_rect.visible = true
	
	var tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	await tween.finished
	
	transition_rect.visible = false
	is_transitioning = false


func _set_progress(value: float) -> void:
	var mat = transition_rect.material as ShaderMaterial
	mat.set_shader_parameter("progress", value)


func set_fully_black() -> void:
	"""Set screen to fully black (for scene transitions)"""
	var mat = transition_rect.material as ShaderMaterial
	mat.set_shader_parameter("progress", 1.0)
	mat.set_shader_parameter("invert", true)
	transition_rect.visible = true
