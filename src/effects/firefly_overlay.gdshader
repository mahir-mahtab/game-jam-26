shader_type canvas_item;

// Firefly particle glow shader - Radial transparency effect
// Bright center fading to transparent edges

uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 0.85, 1.0);
uniform float glow_intensity : hint_range(0.5, 5.0) = 2.5;
uniform float flicker_speed : hint_range(0.0, 10.0) = 3.0;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.25;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    // Radial falloff - 0 at center, 1 at edge (0.5 distance)
    float radial = dist * 2.0; // Normalize to 0-1 range
    
    // Create smooth radial transparency (1 at center, 0 at edge)
    float alpha = 1.0 - smoothstep(0.0, 1.0, radial);
    
    // Add extra glow boost to center
    float core_boost = 1.0 - smoothstep(0.0, 0.3, radial);
    
    // Flickering animation
    float flicker = sin(TIME * flicker_speed + UV.x * 12.0 + UV.y * 12.0) * 0.5 + 0.5;
    float intensity = (1.0 - flicker_intensity) + flicker_intensity * flicker;
    
    // Mix core color (bright) with glow color based on distance from center
    vec3 final_rgb = mix(glow_color.rgb, core_color.rgb, core_boost);
    
    // Apply intensity and radial alpha
    float final_alpha = alpha * glow_intensity * intensity;
    final_alpha = clamp(final_alpha, 0.0, 1.0);
    
    COLOR = vec4(final_rgb, final_alpha);
}

