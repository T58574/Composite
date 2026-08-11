shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float thermal_intensity : hint_range(0.0, 2.0) = 1.0;
uniform bool white_hot = true; // true = White Hot FLIR, false = Black Hot FLIR

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    float luminance = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Thermal gradient mapping (Cold = dark/blue, Hot = bright white/red)
    float heat = clamp(luminance * thermal_intensity, 0.0, 1.0);
    
    vec3 cold_color = vec3(0.05, 0.08, 0.12);
    vec3 mid_color = vec3(0.4, 0.45, 0.5);
    vec3 hot_color = vec3(1.0, 1.0, 0.95);
    
    vec3 thermal_result;
    if (heat < 0.5) {
        thermal_result = mix(cold_color, mid_color, heat * 2.0);
    } else {
        thermal_result = mix(mid_color, hot_color, (heat - 0.5) * 2.0);
    }
    
    if (!white_hot) {
        thermal_result = vec3(1.0) - thermal_result;
    }
    
    COLOR = vec4(thermal_result, 1.0);
}
