shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D metalness_texture : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform vec4 base_color : source_color = vec4(0.22, 0.26, 0.18, 1.0); // Authentic Matte Olive Drab
uniform float metallic : hint_range(0.0, 1.0) = 0.20; // Low reflectivity for CARC matte armor
uniform float roughness : hint_range(0.0, 1.0) = 0.78; // High roughness for non-reflective military paint
uniform float uv_scale : hint_range(0.1, 10.0) = 0.6;
uniform float edge_wear : hint_range(0.0, 1.0) = 0.12;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

// Procedural Camouflage Scheme: 0=Solid, 1=Olive Drab, 2=Desert Sand, 3=NATO 3-Color, 4=Panzer Grey
uniform int camo_type : hint_range(0, 4) = 1;
uniform float camo_scale : hint_range(0.1, 10.0) = 0.8;

// Dirt / Dust Weathering Gradient near ground Y
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.25;
uniform float dirt_height : hint_range(0.1, 5.0) = 1.0;
uniform vec4 dirt_color : source_color = vec4(0.25, 0.20, 0.14, 1.0);

// Procedural 3D Noise for Fallback & Camouflage
float hash3D(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3D(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float n000 = hash3D(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash3D(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3D(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3D(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3D(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3D(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3D(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3D(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);

	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);

	return mix(nxy0, nxy1, f.z);
}

float fbm3D(vec3 p) {
	float val = 0.0;
	float amp = 0.5;
	vec3 q = p;
	for (int i = 0; i < 4; i++) {
		val += amp * noise3D(q);
		q *= 2.03;
		amp *= 0.5;
	}
	return val;
}

vec3 get_procedural_camo(vec3 p, int scheme) {
	p *= camo_scale;
	float n1 = fbm3D(p);
	float n2 = fbm3D(p * 1.6 + vec3(4.3, 1.7, 2.9));

	if (scheme == 1) { // Olive Drab
		vec3 olive_base = vec3(0.22, 0.26, 0.18);
		vec3 olive_dark = vec3(0.14, 0.18, 0.11);
		return mix(olive_dark, olive_base, smoothstep(0.3, 0.7, n1));
	} else if (scheme == 2) { // Desert Sand
		vec3 tan_base = vec3(0.68, 0.60, 0.45);
		vec3 brown_patch = vec3(0.42, 0.33, 0.22);
		vec3 light_sand = vec3(0.76, 0.69, 0.53);
		float pattern = smoothstep(0.42, 0.58, n1 + n2 * 0.25);
		vec3 c = mix(tan_base, brown_patch, pattern);
		return mix(c, light_sand, smoothstep(0.65, 0.8, n2) * 0.4);
	} else if (scheme == 3) { // NATO 3-Color
		vec3 nato_green = vec3(0.17, 0.23, 0.13);
		vec3 nato_brown = vec3(0.31, 0.20, 0.12);
		vec3 nato_black = vec3(0.08, 0.09, 0.08);
		float mask1 = smoothstep(0.38, 0.46, n1);
		float mask2 = smoothstep(0.58, 0.66, n2);
		vec3 c = mix(nato_green, nato_brown, mask1);
		return mix(c, nato_black, mask2);
	} else if (scheme == 4) { // Panzer Grey
		vec3 grey_base = vec3(0.24, 0.26, 0.28);
		vec3 grey_dark = vec3(0.15, 0.16, 0.18);
		return mix(grey_dark, grey_base, smoothstep(0.35, 0.65, n1));
	}
	// Default Solid
	return base_color.rgb;
}

// Triplanar sample helper: samples a texture using triplanar projection
vec4 triplanar_sample(sampler2D tex, vec3 proj_pos, vec3 weights) {
	vec4 s_x = texture(tex, proj_pos.yz);
	vec4 s_y = texture(tex, proj_pos.xz);
	vec4 s_z = texture(tex, proj_pos.xy);
	return s_x * weights.x + s_y * weights.y + s_z * weights.z;
}

// Check if a texture is actually assigned (not just a default 1x1 or 4x4 placeholder)
bool is_texture_valid(sampler2D tex) {
	ivec2 dim = textureSize(tex, 0);
	return (dim.x > 8 && dim.y > 8);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_norm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Triplanar normal weights
	vec3 normal_weights = abs(world_norm);
	normal_weights = pow(normal_weights, vec3(4.0));
	normal_weights /= max(normal_weights.x + normal_weights.y + normal_weights.z, 0.0001);

	vec3 proj_pos = world_pos * uv_scale;

	// --- Albedo ---
	vec3 tex_color;
	if (is_texture_valid(albedo_texture)) {
		tex_color = triplanar_sample(albedo_texture, proj_pos, normal_weights).rgb;
	} else {
		// Subtle steel texture noise fallback
		float noise_pattern = fbm3D(world_pos * 8.0) * 0.12 + 0.94;
		tex_color = vec3(noise_pattern);
	}

	// --- Roughness map ---
	float sampled_roughness = roughness;
	if (is_texture_valid(roughness_texture)) {
		sampled_roughness = triplanar_sample(roughness_texture, proj_pos, normal_weights).r;
	}

	// --- Metalness map ---
	float sampled_metallic = metallic;
	if (is_texture_valid(metalness_texture)) {
		sampled_metallic = triplanar_sample(metalness_texture, proj_pos, normal_weights).r;
	}

	// --- Normal map ---
	if (is_texture_valid(normal_texture)) {
		// Triplanar normal mapping: sample each plane, reconstruct, and blend
		vec3 tn_x = texture(normal_texture, proj_pos.yz).rgb * 2.0 - 1.0;
		vec3 tn_y = texture(normal_texture, proj_pos.xz).rgb * 2.0 - 1.0;
		vec3 tn_z = texture(normal_texture, proj_pos.xy).rgb * 2.0 - 1.0;

		// Swizzle tangent-space normals to world-aligned axes for each projection plane
		vec3 wn_x = vec3(0.0, tn_x.y, -tn_x.x);
		vec3 wn_y = vec3(tn_y.x, 0.0, -tn_y.y);
		vec3 wn_z = vec3(tn_z.x, tn_z.y, 0.0);

		vec3 blended_normal = wn_x * normal_weights.x + wn_y * normal_weights.y + wn_z * normal_weights.z;
		blended_normal = normalize(world_norm + blended_normal * normal_strength);

		// Convert back to view-space for Godot's NORMAL output
		NORMAL = normalize((VIEW_MATRIX * vec4(blended_normal, 0.0)).xyz);
	}

	// Base color / Camouflage color calculation (Authentic CARC Military Armor Paint)
	vec3 pattern_color = (camo_type > 0) ? get_procedural_camo(world_pos, camo_type) : base_color.rgb;
	
	// Blend subtle steel grain texture onto painted albedo without darkening to black
	vec3 painted_albedo = is_texture_valid(albedo_texture) ? mix(pattern_color, tex_color * pattern_color * 1.8, 0.30) : pattern_color * tex_color;

	// Subtle Edge Wear scraping along sharp contours
	float edge_factor = 1.0 - abs(dot(NORMAL, VIEW));
	float wear_noise = fbm3D(world_pos * 14.0);
	float wear = pow(edge_factor, 3.8) * edge_wear * (0.3 + 0.7 * wear_noise);
	wear = clamp(wear, 0.0, 1.0);

	vec3 bare_steel = vec3(0.48, 0.50, 0.52);
	vec3 albedo_after_wear = mix(painted_albedo, bare_steel, wear);
	float metallic_after_wear = mix(sampled_metallic, 0.70, wear * 0.4);
	float roughness_after_wear = mix(sampled_roughness, 0.40, wear * 0.3);

	// Dirt / Dust accumulation gradient near ground (Y = 0.0)
	float height_fade = clamp(1.0 - (world_pos.y / max(dirt_height, 0.001)), 0.0, 1.0);
	float dirt_noise = fbm3D(world_pos * 3.5);
	float dirt_factor = clamp(pow(height_fade, 2.0) * dirt_amount * (0.4 + 0.8 * dirt_noise), 0.0, 1.0);

	vec3 final_albedo = mix(albedo_after_wear, dirt_color.rgb, dirt_factor);
	float final_metallic = mix(metallic_after_wear, 0.05, dirt_factor);
	float final_roughness = mix(roughness_after_wear, 0.88, dirt_factor);

	ALBEDO = final_albedo;
	METALLIC = final_metallic;
	ROUGHNESS = final_roughness;
}
