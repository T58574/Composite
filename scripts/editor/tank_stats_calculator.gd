class_name TankStatsCalculator
extends RefCounted

## Computes real-time tactical & technical characteristics (TTX) for tank editor.
## Calculates total mass, center of mass, engine power-to-weight ratio, and top speed,
## taking into account multi-layer sandwich armor area densities (kg/m2) and add-on module weights.

class TankTTX:
	var total_mass_tons: float = 0.0
	var hull_mass_tons: float = 0.0
	var turret_mass_tons: float = 0.0
	var tracks_mass_tons: float = 0.0
	var engine_horsepower: float = 1200.0
	var power_to_weight_hp_ton: float = 0.0
	var max_speed_kmh: float = 0.0
	var center_of_mass: Vector3 = Vector3.ZERO

## Calculates exact enclosed mesh volume using signed volume of tetrahedrons 1/6 * (v0 . (v1 x v2)) across faces.
static func calculate_mesh_volume(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	var faces: PackedVector3Array = mesh.get_faces()
	var total_volume: float = 0.0
	var count = faces.size()
	for i in range(0, count - 2, 3):
		var v0 = faces[i]
		var v1 = faces[i + 1]
		var v2 = faces[i + 2]
		total_volume += v0.dot(v1.cross(v2)) / 6.0
	return abs(total_volume)

## Calculates exact mesh surface area using sum of triangle areas 1/2 * ||(v1 - v0) x (v2 - v0)|| across faces.
static func calculate_mesh_surface_area(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	var faces: PackedVector3Array = mesh.get_faces()
	var total_area: float = 0.0
	var count = faces.size()
	for i in range(0, count - 2, 3):
		var v0 = faces[i]
		var v1 = faces[i + 1]
		var v2 = faces[i + 2]
		total_area += 0.5 * (v1 - v0).cross(v2 - v0).length()
	return total_area

static func calculate_stats(
	hull_builder: HullBuilder,
	turret_builder: TurretBuilder,
	track_generator: TrackGenerator,
	engine_hp: float = 1200.0
) -> TankTTX:
	var ttx = TankTTX.new()
	ttx.engine_horsepower = engine_hp
	
	if hull_builder:
		var hull_sandwich: ArmorCalculator.ArmorSandwich = null
		if "armor_sandwich" in hull_builder and hull_builder.armor_sandwich != null:
			hull_sandwich = hull_builder.armor_sandwich
		else:
			hull_sandwich = ArmorCalculator.ArmorSandwich.create_default_glacis()
			
		var surface_area_m2: float = 0.0
		var hull_volume_m3: float = 0.0
		if hull_builder.mesh != null:
			surface_area_m2 = calculate_mesh_surface_area(hull_builder.mesh)
			hull_volume_m3 = calculate_mesh_volume(hull_builder.mesh)
		else:
			surface_area_m2 = 2.0 * (hull_builder.length * hull_builder.width + hull_builder.length * hull_builder.height + hull_builder.width * hull_builder.height)
			hull_volume_m3 = hull_builder.length * hull_builder.width * hull_builder.height
			
		var front_area = surface_area_m2 * 0.4
		var side_area = surface_area_m2 * 0.4
		var rear_area = surface_area_m2 * 0.2
		
		var front_mass_kg = front_area * hull_sandwich.get_area_mass_kg_m2()
		var side_mass_kg = side_area * (hull_builder.side_armor_mm / 1000.0) * 7850.0
		var rear_mass_kg = rear_area * (hull_builder.rear_armor_mm / 1000.0) * 7850.0
		
		ttx.hull_mass_tons = (front_mass_kg + side_mass_kg + rear_mass_kg) / 1000.0
	else:
		ttx.hull_mass_tons = 25.0
		
	if turret_builder:
		var turret_sandwich: ArmorCalculator.ArmorSandwich = null
		if "armor_sandwich" in turret_builder and turret_builder.armor_sandwich != null:
			turret_sandwich = turret_builder.armor_sandwich
		else:
			turret_sandwich = ArmorCalculator.ArmorSandwich.create_default_turret()
			
		var turret_surf_m2: float = 0.0
		var turret_volume_m3: float = 0.0
		if turret_builder.turret_mesh_instance != null and turret_builder.turret_mesh_instance.mesh != null:
			turret_surf_m2 = calculate_mesh_surface_area(turret_builder.turret_mesh_instance.mesh)
			turret_volume_m3 = calculate_mesh_volume(turret_builder.turret_mesh_instance.mesh)
		else:
			turret_surf_m2 = 2.0 * (turret_builder.turret_length * turret_builder.turret_width + turret_builder.turret_length * turret_builder.turret_height + turret_builder.turret_width * turret_builder.turret_height) * 0.6
			turret_volume_m3 = turret_builder.turret_length * turret_builder.turret_width * turret_builder.turret_height * 0.5
			
		var cheek_area = turret_surf_m2 * 0.45
		var side_rear_area = turret_surf_m2 * 0.55
		
		var cheek_mass_kg = cheek_area * turret_sandwich.get_area_mass_kg_m2()
		var side_rear_mass_kg = side_rear_area * (turret_builder.front_turret_armor_mm * 0.3 / 1000.0) * 7850.0
		var gun_mass_kg = turret_builder.barrel_length * 450.0
		
		ttx.turret_mass_tons = (cheek_mass_kg + side_rear_mass_kg + gun_mass_kg) / 1000.0
	else:
		ttx.turret_mass_tons = 12.0
		
	if track_generator:
		ttx.tracks_mass_tons = track_generator.road_wheels_count * 0.85
	else:
		ttx.tracks_mass_tons = 5.0
		
	ttx.total_mass_tons = ttx.hull_mass_tons + ttx.turret_mass_tons + ttx.tracks_mass_tons
	
	# Power-to-weight ratio: HP / Tons
	if ttx.total_mass_tons > 0.0:
		ttx.power_to_weight_hp_ton = ttx.engine_horsepower / ttx.total_mass_tons
	else:
		ttx.power_to_weight_hp_ton = 0.0
		
	# Estimated top speed: V_max = (Power / Weight) * 2.6
	ttx.max_speed_kmh = clamp(ttx.power_to_weight_hp_ton * 2.6, 20.0, 95.0)
	
	# Center of Mass approximation
	var hull_pos = hull_builder.global_position if hull_builder else Vector3.ZERO
	var turret_pos = turret_builder.global_position if turret_builder else Vector3(0, 1.2, 0)
	
	if ttx.total_mass_tons > 0.0:
		ttx.center_of_mass = (hull_pos * ttx.hull_mass_tons + turret_pos * ttx.turret_mass_tons) / ttx.total_mass_tons
		
	return ttx

