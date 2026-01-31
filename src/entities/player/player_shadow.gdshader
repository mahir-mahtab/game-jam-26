shader_type canvas_item;

// Drop shadow effect for the player character
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec2 shadow_offset = vec2(4.0, 6.0);
uniform float shadow_blur : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    
    // Calculate shadow position
    vec2 shadow_uv = UV - shadow_offset * TEXTURE_PIXEL_SIZE;
    
    // Sample for shadow with slight blur
    float shadow_alpha = 0.0;
    float samples = 0.0;
    
    if (shadow_blur > 0.0) {
        // Blur the shadow for softer look
        for (float x = -1.0; x <= 1.0; x += 1.0) {
            for (float y = -1.0; y <= 1.0; y += 1.0) {
                vec2 blur_offset = vec2(x, y) * TEXTURE_PIXEL_SIZE * shadow_blur;
                shadow_alpha += texture(TEXTURE, shadow_uv + blur_offset).a;
                samples += 1.0;
            }
        }
        shadow_alpha /= samples;
    } else {
        shadow_alpha = texture(TEXTURE, shadow_uv).a;
    }
    
    // Create shadow
    vec4 shadow = shadow_color * shadow_alpha * (1.0 - original.a);
    
    // Combine shadow with original sprite (shadow behind)
    COLOR = mix(shadow, original, original.a);
    COLOR.a = max(shadow.a, original.a);
}
