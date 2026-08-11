shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

uniform vec4 xray_color : source_color = vec4(0.0, 0.75, 1.0, 0.25);
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	vec3 final_color = mix(xray_color.rgb * 0.4, vec3(0.1, 0.95, 1.0), fresnel);
	
	ALBEDO = final_color;
	ALPHA = clamp(xray_color.a + fresnel * 0.5, 0.15, 0.8);
}
