shader_type canvas_item;

// Glow effect for prey/enemy to make them stand out
uniform vec4 glow_color : source_color = vec4(1.0, 0.3, 0.3, 0.8);
uniform float glow_size : hint_range(0.0, 10.0) = 3.0;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    
    // Sample surrounding pixels for glow outline
    float outline = 0.0;
    vec2 pixel_size = TEXTURE_PIXEL_SIZE * glow_size;
    
    // Sample 8 directions for smooth glow
    for (float x = -1.0; x <= 1.0; x += 1.0) {
        for (float y = -1.0; y <= 1.0; y += 1.0) {
            if (x == 0.0 && y == 0.0) continue;
            vec2 offset = vec2(x, y) * pixel_size;
            outline += texture(TEXTURE, UV + offset).a;
        }
    }
    
    // Add pulsing animation effect
    float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
    float animated_intensity = glow_intensity * (0.7 + 0.3 * pulse);
    
    // Create glow color with intensity
    vec4 glow = glow_color * animated_intensity * outline * (1.0 - original.a);
    
    // Combine original sprite with glow
    COLOR = mix(glow, original, original.a);
    COLOR.a = max(glow.a, original.a);
}
