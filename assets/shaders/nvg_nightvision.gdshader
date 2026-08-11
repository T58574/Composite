shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec4 phosphor_color : source_color = vec4(0.1, 0.95, 0.2, 1.0); // Classic Green Phosphor
uniform float amplification : hint_range(1.0, 5.0) = 2.2;
uniform float noise_amount : hint_range(0.0, 0.5) = 0.08;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 scene_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    float luminance = dot(scene_color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Light amplification
    float amplified = clamp(luminance * amplification, 0.0, 1.0);
    
    // Vignette
    vec2 uv = SCREEN_UV - vec2(0.5);
    float dist = length(uv);
    float vignette = smoothstep(0.65, 0.35, dist);
    
    // Noise grain
    float n = (rand(SCREEN_UV + vec2(TIME * 0.1, TIME * 0.2)) - 0.5) * noise_amount;
    
    vec3 nvg_color = phosphor_color.rgb * (amplified + n) * vignette;
    
    COLOR = vec4(nvg_color, 1.0);
}
