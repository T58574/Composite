shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform float armor_thickness_mm : hint_range(5.0, 1000.0) = 100.0;
uniform bool is_composite = false;

void fragment() {
	vec3 color = vec3(0.1, 0.5, 0.9); // Default Thin (Blue)
	
	if (is_composite) {
		color = vec3(0.65, 0.3, 0.95); // Purple Composite NERA
	} else {
		if (armor_thickness_mm < 40.0) {
			color = mix(vec3(0.0, 0.8, 1.0), vec3(0.1, 0.9, 0.4), armor_thickness_mm / 40.0);
		} else if (armor_thickness_mm < 150.0) {
			color = mix(vec3(0.1, 0.9, 0.4), vec3(1.0, 0.8, 0.1), (armor_thickness_mm - 40.0) / 110.0);
		} else if (armor_thickness_mm < 350.0) {
			color = mix(vec3(1.0, 0.8, 0.1), vec3(0.95, 0.2, 0.1), (armor_thickness_mm - 150.0) / 200.0);
		} else {
			color = vec3(0.95, 0.15, 0.1); // Deep Red Heavy Armor
		}
	}
	
	ALBEDO = color;
}
