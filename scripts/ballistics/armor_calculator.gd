class_name ArmorCalculator
extends Node

## Armor penetration and ballistics physics calculator for modern MBTs.
## Computes LOS effective thickness T_eff = T / cos(theta), composite RHA equivalency,
## multi-layer sandwich armor layers, and Add-on protection systems (ERA, Slat Cages, Stealth).

enum AmmoType {
	APFSDS, ## Armor-Piercing Fin-Stabilized Discarding Sabot (Kinetic Energy)
	HEAT,   ## High-Explosive Anti-Tank (Shaped Charge Chemical Energy)
	ATGM    ## Anti-Tank Guided Missile (Tandem HEAT Charge)
}

enum ArmorType {
	RHA_STEEL,    ## Rolled Homogeneous Armor Steel (Multiplier 1.0)
	CAST_STEEL,   ## Cast Armor (Multiplier 0.9)
	COMPOSITE,    ## Ceramic / NERA Composite Sandwich (KE ~1.3-1.6, HEAT ~2.0-2.5)
	ERA_KONTAKT1, ## Kontakt-1 Reactive Armor (vs HEAT -350mm, vs KE 0)
	ERA_KONTAKT5, ## Kontakt-5 Heavy Reactive Armor (vs HEAT -600mm, vs KE -250mm)
	ERA_RELIKT    ## Relikt 3rd Gen Reactive Armor (vs HEAT -800mm, vs KE -400mm)
}

enum MaterialType {
	RHA_STEEL,
	CAST_STEEL,
	HHRA_STEEL,
	FACE_HARDENED,
	GLASS_TEXTOLITE_STK,
	CERAMIC_SIC_AL2O3,
	NERA_AIR_RUBBER,
	DEPLETED_URANIUM,
	SPALL_LINER_KEVLAR
}

enum AddonProtectionType {
	NONE,
	ERA_KONTAKT1,
	ERA_KONTAKT5,
	ERA_RELIKT,
	SLAT_CAGE_GRID,
	SIDE_SKIRTS_SOFT,
	COPE_CAGE_MANGAL,
	STEALTH_NAKIDKA
}

class ArmorLayer extends RefCounted:
	var material: MaterialType = MaterialType.RHA_STEEL
	var thickness_mm: float = 0.0

	func _init(p_material: MaterialType = MaterialType.RHA_STEEL, p_thickness_mm: float = 0.0) -> void:
		material = p_material
		thickness_mm = p_thickness_mm

	func get_density_kg_m3() -> float:
		match material:
			MaterialType.RHA_STEEL: return 7850.0
			MaterialType.CAST_STEEL: return 7850.0
			MaterialType.HHRA_STEEL: return 7850.0
			MaterialType.FACE_HARDENED: return 7850.0
			MaterialType.GLASS_TEXTOLITE_STK: return 1850.0
			MaterialType.CERAMIC_SIC_AL2O3: return 3600.0
			MaterialType.NERA_AIR_RUBBER: return 1200.0
			MaterialType.DEPLETED_URANIUM: return 19100.0
			MaterialType.SPALL_LINER_KEVLAR: return 1440.0
		return 7850.0

	func get_ke_multiplier() -> float:
		match material:
			MaterialType.RHA_STEEL: return 1.0
			MaterialType.CAST_STEEL: return 0.9
			MaterialType.HHRA_STEEL: return 1.15
			MaterialType.FACE_HARDENED: return 1.05
			MaterialType.GLASS_TEXTOLITE_STK: return 0.45
			MaterialType.CERAMIC_SIC_AL2O3: return 1.35
			MaterialType.NERA_AIR_RUBBER: return 0.55
			MaterialType.DEPLETED_URANIUM: return 1.75
			MaterialType.SPALL_LINER_KEVLAR: return 0.30
		return 1.0

	func get_heat_multiplier() -> float:
		match material:
			MaterialType.RHA_STEEL: return 1.0
			MaterialType.CAST_STEEL: return 0.9
			MaterialType.HHRA_STEEL: return 1.10
			MaterialType.FACE_HARDENED: return 1.05
			MaterialType.GLASS_TEXTOLITE_STK: return 0.90
			MaterialType.CERAMIC_SIC_AL2O3: return 2.20
			MaterialType.NERA_AIR_RUBBER: return 1.60
			MaterialType.DEPLETED_URANIUM: return 1.50
			MaterialType.SPALL_LINER_KEVLAR: return 0.30
		return 1.0

	func get_area_mass_kg_m2() -> float:
		return (thickness_mm / 1000.0) * get_density_kg_m3()


class ArmorSandwich extends RefCounted:
	var outer_layer: ArmorLayer = null
	var filler_layer: ArmorLayer = null
	var rear_layer: ArmorLayer = null
	var has_spall_liner: bool = false
	var addon_protection: AddonProtectionType = AddonProtectionType.NONE
	var era_detonated: bool = false
	var sector_era_states: Dictionary = {}

	func _init() -> void:
		outer_layer = ArmorLayer.new(MaterialType.RHA_STEEL, 60.0)
		filler_layer = ArmorLayer.new(MaterialType.GLASS_TEXTOLITE_STK, 105.0)
		rear_layer = ArmorLayer.new(MaterialType.RHA_STEEL, 50.0)
		has_spall_liner = false
		addon_protection = AddonProtectionType.NONE
		era_detonated = false
		sector_era_states = {}

	func duplicate_sandwich() -> ArmorSandwich:
		var copy = ArmorSandwich.new()
		if outer_layer:
			copy.outer_layer = ArmorLayer.new(outer_layer.material, outer_layer.thickness_mm)
		if filler_layer:
			copy.filler_layer = ArmorLayer.new(filler_layer.material, filler_layer.thickness_mm)
		if rear_layer:
			copy.rear_layer = ArmorLayer.new(rear_layer.material, rear_layer.thickness_mm)
		copy.has_spall_liner = has_spall_liner
		copy.addon_protection = addon_protection
		copy.era_detonated = era_detonated
		copy.sector_era_states = sector_era_states.duplicate()
		return copy

	func is_era_detonated_at_sector(sector_id: String = "") -> bool:
		if era_detonated:
			return true
		if not sector_id.is_empty():
			return sector_era_states.get(sector_id, false)
		return false

	func detonate_era_at_sector(sector_id: String = "") -> void:
		if not sector_id.is_empty():
			sector_era_states[sector_id] = true
		era_detonated = true

	func get_total_physical_thickness_mm() -> float:
		var total: float = 0.0
		if outer_layer: total += outer_layer.thickness_mm
		if filler_layer: total += filler_layer.thickness_mm
		if rear_layer: total += rear_layer.thickness_mm
		if has_spall_liner: total += 15.0
		return total

	func get_area_mass_kg_m2() -> float:
		var mass: float = 0.0
		if outer_layer: mass += outer_layer.get_area_mass_kg_m2()
		if filler_layer: mass += filler_layer.get_area_mass_kg_m2()
		if rear_layer: mass += rear_layer.get_area_mass_kg_m2()
		if has_spall_liner:
			mass += (15.0 / 1000.0) * 1440.0
		mass += ArmorCalculator.get_addon_area_mass_kg_m2(addon_protection)
		return mass

	func get_effective_rha_mm(projectile_type: AmmoType, los_factor: float = 1.0, impact_angle_deg: float = 0.0, sector_id: String = "") -> float:
		var total_rha: float = 0.0
		var layers = [outer_layer, filler_layer, rear_layer]
		for layer in layers:
			if layer != null:
				var mult = layer.get_ke_multiplier() if projectile_type == AmmoType.APFSDS else layer.get_heat_multiplier()
				total_rha += layer.thickness_mm * los_factor * mult
		if has_spall_liner:
			total_rha += 15.0 * los_factor * 0.3
		var is_spent = is_era_detonated_at_sector(sector_id)
		var addon_bonus := 0.0
		if not is_spent:
			addon_bonus = ArmorCalculator.get_addon_rha_bonus_mm(addon_protection, projectile_type, impact_angle_deg)
		total_rha += addon_bonus
		return total_rha

	static func create_default_glacis() -> ArmorSandwich:
		var sandwich = ArmorSandwich.new()
		sandwich.outer_layer = ArmorLayer.new(MaterialType.RHA_STEEL, 60.0)
		sandwich.filler_layer = ArmorLayer.new(MaterialType.GLASS_TEXTOLITE_STK, 105.0)
		sandwich.rear_layer = ArmorLayer.new(MaterialType.RHA_STEEL, 50.0)
		sandwich.has_spall_liner = true
		sandwich.addon_protection = AddonProtectionType.ERA_KONTAKT5
		return sandwich

	static func create_default_turret() -> ArmorSandwich:
		var sandwich = ArmorSandwich.new()
		sandwich.outer_layer = ArmorLayer.new(MaterialType.RHA_STEEL, 100.0)
		sandwich.filler_layer = ArmorLayer.new(MaterialType.CERAMIC_SIC_AL2O3, 220.0)
		sandwich.rear_layer = ArmorLayer.new(MaterialType.RHA_STEEL, 80.0)
		sandwich.has_spall_liner = true
		sandwich.addon_protection = AddonProtectionType.NONE
		return sandwich


class ImpactResult extends RefCounted:
	var penetrated: bool = false
	var effective_thickness_mm: float = 0.0
	var residual_penetration_mm: float = 0.0
	var impact_angle_deg: float = 0.0
	var hit_position: Vector3 = Vector3.ZERO
	var description: String = ""
	var spall_cone_angle_deg: float = 0.0
	var spall_fragment_count: int = 0
	var damaged_modules: Array[String] = []
	var crew_knocked_out: Array[String] = []


static func is_era_addon(addon: AddonProtectionType) -> bool:
	match addon:
		AddonProtectionType.ERA_KONTAKT1, AddonProtectionType.ERA_KONTAKT5, AddonProtectionType.ERA_RELIKT:
			return true
	return false


static func get_addon_area_mass_kg_m2(addon: AddonProtectionType) -> float:
	match addon:
		AddonProtectionType.NONE: return 0.0
		AddonProtectionType.ERA_KONTAKT1: return 120.0
		AddonProtectionType.ERA_KONTAKT5: return 300.0
		AddonProtectionType.ERA_RELIKT: return 350.0
		AddonProtectionType.SLAT_CAGE_GRID: return 45.0
		AddonProtectionType.SIDE_SKIRTS_SOFT: return 30.0
		AddonProtectionType.COPE_CAGE_MANGAL: return 60.0
		AddonProtectionType.STEALTH_NAKIDKA: return 15.0
	return 0.0


static func get_addon_rha_bonus_mm(addon: AddonProtectionType, projectile_type: AmmoType, impact_angle_deg: float = 0.0) -> float:
	var base_bonus := 0.0
	match addon:
		AddonProtectionType.NONE:
			return 0.0
		AddonProtectionType.ERA_KONTAKT1:
			if projectile_type == AmmoType.HEAT:
				base_bonus = 350.0
			elif projectile_type == AmmoType.ATGM:
				base_bonus = 0.0 # Tandem precursor charge neutralizes Kontakt-1 flyer plates
			else:
				base_bonus = 0.0
		AddonProtectionType.ERA_KONTAKT5:
			if projectile_type == AmmoType.HEAT:
				base_bonus = 600.0
			elif projectile_type == AmmoType.ATGM:
				base_bonus = 250.0 # Tandem precursor charge reduces protection
			else:
				base_bonus = 250.0
		AddonProtectionType.ERA_RELIKT:
			if projectile_type == AmmoType.HEAT:
				base_bonus = 800.0
			elif projectile_type == AmmoType.ATGM:
				base_bonus = 600.0 # 3rd gen ERA tandem mitigation
			else:
				base_bonus = 400.0
		AddonProtectionType.SLAT_CAGE_GRID:
			return 150.0 if projectile_type == AmmoType.HEAT else (80.0 if projectile_type == AmmoType.ATGM else 10.0)
		AddonProtectionType.SIDE_SKIRTS_SOFT:
			return 80.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 5.0
		AddonProtectionType.COPE_CAGE_MANGAL:
			return 200.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 15.0
		AddonProtectionType.STEALTH_NAKIDKA:
			return 20.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 0.0

	# Obliquity angle scaling for ERA: flyer plate interaction path increases with impact angle theta
	if is_era_addon(addon) and base_bonus > 0.0:
		var cos_theta = maxf(cos(deg_to_rad(impact_angle_deg)), 0.1736) # min cos for 80 deg limit
		var era_angle_factor = clampf(1.0 / pow(cos_theta, 0.7), 1.0, 2.2)
		return base_bonus * era_angle_factor

	return base_bonus


static func get_material_name(mat: MaterialType) -> String:
	match mat:
		MaterialType.RHA_STEEL: return "Rolled Homogeneous Armor (RHA)"
		MaterialType.CAST_STEEL: return "Cast Armor Steel"
		MaterialType.HHRA_STEEL: return "High-Hardness Armor (HHRA)"
		MaterialType.FACE_HARDENED: return "Face-Hardened Steel"
		MaterialType.GLASS_TEXTOLITE_STK: return "Glass Textolite (STK)"
		MaterialType.CERAMIC_SIC_AL2O3: return "Ceramic (SiC / Al2O3)"
		MaterialType.NERA_AIR_RUBBER: return "NERA (Rubber / Air)"
		MaterialType.DEPLETED_URANIUM: return "Depleted Uranium (DU Mesh)"
		MaterialType.SPALL_LINER_KEVLAR: return "Kevlar Spall Liner"
	return "Unknown Material"


static func get_addon_name(addon: AddonProtectionType) -> String:
	match addon:
		AddonProtectionType.NONE: return "None"
		AddonProtectionType.ERA_KONTAKT1: return "Kontakt-1 ERA"
		AddonProtectionType.ERA_KONTAKT5: return "Kontakt-5 Heavy ERA"
		AddonProtectionType.ERA_RELIKT: return "Relikt 3rd Gen ERA"
		AddonProtectionType.SLAT_CAGE_GRID: return "Slat / Cage Anti-RPG Grid"
		AddonProtectionType.SIDE_SKIRTS_SOFT: return "Soft Side Skirts"
		AddonProtectionType.COPE_CAGE_MANGAL: return "Roof Cope Cage (Mangal)"
		AddonProtectionType.STEALTH_NAKIDKA: return "Nakidka Stealth Blanket"
	return "Unknown Addon"


## Calculate APFSDS obliquity slope factor accounting for rod bending/shatter/denormalization at >60 deg
static func calculate_apfsds_slope_factor(impact_angle_deg: float) -> float:
	var angle = clampf(impact_angle_deg, 0.0, 85.0)
	var cos_theta = maxf(cos(deg_to_rad(angle)), 0.087) # 0.087 = cos(85 deg)
	var base_los = 1.0 / cos_theta
	if angle > 60.0:
		# Hydrodynamic denormalization & rod shatter penalty for long rods at extreme obliquity
		var over_angle = (angle - 60.0) / 25.0
		var denorm_penalty = 1.0 + 1.8 * pow(over_angle, 1.4)
		return base_los * denorm_penalty
	return base_los


## Calculate Effective Armor Thickness considering Line-Of-Sight (LOS) angle and ammo type:
static func calculate_effective_thickness(nominal_thickness_mm: float, normal: Vector3, ray_dir: Vector3, ammo_type: AmmoType = AmmoType.APFSDS) -> float:
	var cos_theta = abs(normal.dot(-ray_dir))
	var angle_deg = rad_to_deg(acos(clampf(cos_theta, 0.0, 1.0)))
	if ammo_type == AmmoType.APFSDS:
		return nominal_thickness_mm * calculate_apfsds_slope_factor(angle_deg)
	var los_factor = 1.0 / maxf(cos_theta, cos(deg_to_rad(85.0)))
	return nominal_thickness_mm * los_factor


static func get_sector_from_impact(impact_normal: Vector3, hit_position: Vector3 = Vector3.ZERO) -> String:
	var norm = impact_normal.normalized()
	if norm.y > 0.7:
		return "roof"
	elif norm.y < -0.7:
		return "belly"
	elif norm.z > 0.4:
		return "glacis_front" if norm.y > 0.2 else "hull_front"
	elif norm.z < -0.4:
		return "hull_rear"
	elif norm.x < -0.4:
		return "side_left"
	elif norm.x > 0.4:
		return "side_right"
	return "glacis_front"


## Perform full impact penetration test supporting ArmorSandwich or nominal values
static func evaluate_impact(
	projectile_type: AmmoType,
	penetration_capacity_mm: float,
	nominal_armor_mm: float,
	armor_material: ArmorType,
	impact_normal: Vector3,
	projectile_direction: Vector3,
	sandwich: ArmorSandwich = null,
	hit_position: Vector3 = Vector3.ZERO,
	sector_id: String = ""
) -> ImpactResult:
	var result = ImpactResult.new()
	result.hit_position = hit_position
	
	var cos_theta = abs(impact_normal.dot(-projectile_direction))
	var angle_rad = acos(clampf(cos_theta, 0.0, 1.0))
	result.impact_angle_deg = rad_to_deg(angle_rad)

	# Determine sector ID if not provided explicitly
	var active_sector_id = sector_id
	if active_sector_id.is_empty():
		active_sector_id = get_sector_from_impact(impact_normal, hit_position)
	
	# Calculate LOS factor (accounting for APFSDS de-normalization at >60 deg)
	var los_factor := 1.0
	if projectile_type == AmmoType.APFSDS:
		los_factor = calculate_apfsds_slope_factor(result.impact_angle_deg)
	else:
		los_factor = 1.0 / maxf(cos_theta, 0.087) # 0.087 = cos(85 deg)
	
	var era_bonus_applied := false

	if sandwich != null:
		var is_spent = sandwich.is_era_detonated_at_sector(active_sector_id)
		var era_bonus = get_addon_rha_bonus_mm(sandwich.addon_protection, projectile_type, result.impact_angle_deg) if (is_era_addon(sandwich.addon_protection) and not is_spent) else 0.0
		if era_bonus > 0.0:
			era_bonus_applied = true
		result.effective_thickness_mm = sandwich.get_effective_rha_mm(projectile_type, los_factor, result.impact_angle_deg, active_sector_id)
	else:
		var los_thickness = nominal_armor_mm * los_factor
		var rha_multiplier = 1.0
		var era_reduction_mm = 0.0
		
		match armor_material:
			ArmorType.CAST_STEEL:
				rha_multiplier = 0.9
			ArmorType.COMPOSITE:
				rha_multiplier = 1.45 if projectile_type == AmmoType.APFSDS else 2.2
			ArmorType.ERA_KONTAKT1:
				era_reduction_mm = get_addon_rha_bonus_mm(AddonProtectionType.ERA_KONTAKT1, projectile_type, result.impact_angle_deg)
			ArmorType.ERA_KONTAKT5:
				era_reduction_mm = get_addon_rha_bonus_mm(AddonProtectionType.ERA_KONTAKT5, projectile_type, result.impact_angle_deg)
			ArmorType.ERA_RELIKT:
				era_reduction_mm = get_addon_rha_bonus_mm(AddonProtectionType.ERA_RELIKT, projectile_type, result.impact_angle_deg)
		
		if era_reduction_mm > 0.0:
			era_bonus_applied = true
		result.effective_thickness_mm = (los_thickness * rha_multiplier) + era_reduction_mm

	# Check for ricochet on extreme angles (> 78 deg for APFSDS, > 82 deg for HEAT)
	var ricochet_angle = 78.0 if projectile_type == AmmoType.APFSDS else 82.0
	if result.impact_angle_deg > ricochet_angle:
		result.penetrated = false
		result.residual_penetration_mm = 0.0
		result.spall_cone_angle_deg = 0.0
		result.spall_fragment_count = 0
		result.damaged_modules.clear()
		result.crew_knocked_out.clear()
		result.description = "RICOCHET (Glancing hit at %.1f°)" % result.impact_angle_deg
		return result
		
	if penetration_capacity_mm >= result.effective_thickness_mm:
		result.penetrated = true
		result.residual_penetration_mm = penetration_capacity_mm - result.effective_thickness_mm
		
		# Spall Cone Angle: 60° for APFSDS, 90° for HEAT
		var base_cone_angle: float = 60.0 if projectile_type == AmmoType.APFSDS else 90.0
		var base_frags: float = 35.0 if projectile_type == AmmoType.APFSDS else 65.0
		base_frags += clampf(result.residual_penetration_mm * 0.1, 0.0, 45.0)
		
		var has_spall_liner: bool = (sandwich != null and sandwich.has_spall_liner)
		if has_spall_liner:
			result.spall_cone_angle_deg = base_cone_angle * 0.4 # Reduced by 60% (to ~24° or ~36°)
			result.spall_fragment_count = int(round(base_frags * 0.4)) # Fragment count reduced by 60%
		else:
			result.spall_cone_angle_deg = base_cone_angle
			result.spall_fragment_count = int(round(base_frags))

		# Secondary damage evaluation to modules and crew using 3D spatial spall cone
		_evaluate_internal_damage(result, projectile_type, has_spall_liner, projectile_direction)

		# Detailed impact result description
		var desc: String = "PENETRATION (Pen: %.0fmm vs Eff: %.0fmm)" % [penetration_capacity_mm, result.effective_thickness_mm]
		desc += " [Cone: %.0f°, Frags: %d%s]" % [
			result.spall_cone_angle_deg,
			result.spall_fragment_count,
			" (Spall Liner -60%)" if has_spall_liner else ""
		]
		if not result.damaged_modules.is_empty():
			desc += " | Modules: " + ", ".join(result.damaged_modules)
		if not result.crew_knocked_out.is_empty():
			desc += " | Crew KO: " + ", ".join(result.crew_knocked_out)
		result.description = desc
	else:
		result.penetrated = false
		result.residual_penetration_mm = 0.0
		result.spall_cone_angle_deg = 0.0
		result.spall_fragment_count = 0
		result.damaged_modules.clear()
		result.crew_knocked_out.clear()
		result.description = "NON-PENETRATION / SHOCKED (Pen: %.0fmm vs Eff: %.0fmm)" % [penetration_capacity_mm, result.effective_thickness_mm]
		
	if era_bonus_applied:
		if sandwich != null:
			sandwich.detonate_era_at_sector(active_sector_id)
		result.description += " [ERA DETONATED sector: %s]" % active_sector_id

	return result


## Evaluates secondary internal damage to vehicle modules (Engine, Ammo Storage) and crew (Driver, Gunner, Commander)
## using spatial proximity and 3D vector cone direction.
static func _evaluate_internal_damage(
	result: ImpactResult,
	projectile_type: AmmoType,
	has_spall_liner: bool,
	impact_direction: Vector3 = Vector3.ZERO
) -> void:
	result.damaged_modules.clear()
	result.crew_knocked_out.clear()

	var residual_pen := result.residual_penetration_mm
	if residual_pen <= 0.0:
		return

	var spall_mitigation := 0.4 if has_spall_liner else 1.0
	var spall_cone_angle := result.spall_cone_angle_deg
	var cone_half_angle_rad := deg_to_rad(spall_cone_angle * 0.5)

	# Max spall travel distance in meters based on residual penetration
	var max_spall_dist := clampf(residual_pen * 0.015, 0.8, 4.5)

	# Normalized penetration direction vector (pointing into interior)
	var pen_dir := impact_direction.normalized()
	if pen_dir.length_squared() < 0.01:
		pen_dir = Vector3(0.0, 0.0, -1.0) # Default forward-to-back fallback

	# Estimated internal vehicle module coordinates in local space
	# X: right(+)/left(-), Y: up(+)/down(-), Z: rear(+)/front(-)
	var modules := {
		"Driver": Vector3(0.0, 0.6, -1.8),
		"Gunner": Vector3(-0.6, 1.4, -0.2),
		"Commander": Vector3(0.6, 1.5, -0.2),
		"Engine": Vector3(0.0, 0.7, 1.8),
		"Ammunition Storage": Vector3(0.0, 0.3, 0.0)
	}

	var hit_pos := result.hit_position

	# If hit_pos is non-zero and within reasonable local coordinate range (< 50m)
	var is_local_pos := hit_pos != Vector3.ZERO and hit_pos.length() < 50.0

	for mod_name in modules:
		var mod_pos: Vector3 = modules[mod_name]
		var spatial_factor := 0.0

		if is_local_pos:
			# Direct 3D spatial spall cone check in local coordinates
			var to_mod := mod_pos - hit_pos
			var dist_along := to_mod.dot(pen_dir)
			if dist_along > 0.0 and dist_along <= max_spall_dist:
				var perp_vec := to_mod - (dist_along * pen_dir)
				var perp_dist := perp_vec.length()
				var angle_rad := atan2(perp_dist, dist_along)
				if angle_rad <= cone_half_angle_rad:
					var angle_weight := 1.0 - (angle_rad / cone_half_angle_rad)
					var dist_weight := 1.0 - (dist_along / max_spall_dist)
					spatial_factor = angle_weight * dist_weight
		else:
			# Spatial direction alignment check based on impact vector pen_dir
			var target_dir := mod_pos.normalized()
			var alignment := pen_dir.dot(target_dir)
			if alignment > 0.1:
				spatial_factor = alignment * 0.7

		if spatial_factor > 0.05:
			# Probability scaled by spatial factor, residual pen energy, and spall liner mitigation
			var pen_energy_factor := clampf(residual_pen / 150.0, 0.2, 1.5)
			var damage_prob := clampf(spatial_factor * pen_energy_factor * spall_mitigation, 0.05, 0.90)

			if randf() < damage_prob:
				if mod_name in ["Driver", "Gunner", "Commander"]:
					result.crew_knocked_out.append(mod_name)
				else:
					if mod_name == "Ammunition Storage":
						var det_threshold := 70.0 if projectile_type == AmmoType.APFSDS else 45.0
						if residual_pen > det_threshold and randf() < 0.65:
							result.damaged_modules.append("Ammunition Storage (Ammo Detonation!)")
						else:
							result.damaged_modules.append("Ammunition Storage")
					else:
						result.damaged_modules.append(mod_name)

	# Fallback if penetration occurred with high residual energy but no module was hit due to geometry edge cases
	if residual_pen > 60.0 and result.damaged_modules.is_empty() and result.crew_knocked_out.is_empty():
		if randf() < 0.5:
			result.crew_knocked_out.append("Gunner" if randf() < 0.5 else "Driver")
		else:
			result.damaged_modules.append("Engine" if randf() < 0.5 else "Ammunition Storage")
