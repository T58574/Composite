class_name TankStatsCalculator
extends RefCounted

## Computes real-time tactical & technical characteristics (TTX) for tank editor.
## Calculates total mass, center of mass, engine power-to-weight ratio, and top speed.

class TankTTX:
	var total_mass_tons: float = 0.0
	var hull_mass_tons: float = 0.0
	var turret_mass_tons: float = 0.0
	var tracks_mass_tons: float = 0.0
	var engine_horsepower: float = 1200.0
	var power_to_weight_hp_ton: float = 0.0
	var max_speed_kmh: float = 0.0
	var center_of_mass: Vector3 = Vector3.ZERO

static func calculate_stats(
	hull_builder: HullBuilder,
	turret_builder: TurretBuilder,
	track_generator: TrackGenerator,
	engine_hp: float = 1200.0
) -> TankTTX:
	var ttx = TankTTX.new()
	ttx.engine_horsepower = engine_hp
	
	if hull_builder:
		ttx.hull_mass_tons = hull_builder.calculated_mass_kg / 1000.0
	else:
		ttx.hull_mass_tons = 25.0
		
	if turret_builder:
		ttx.turret_mass_tons = turret_builder.calculated_turret_mass_kg / 1000.0
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
