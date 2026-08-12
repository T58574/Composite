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

	func _init() -> void:
		outer_layer = ArmorLayer.new(MaterialType.RHA_STEEL, 60.0)
		filler_layer = ArmorLayer.new(MaterialType.GLASS_TEXTOLITE_STK, 105.0)
		rear_layer = ArmorLayer.new(MaterialType.RHA_STEEL, 50.0)
		has_spall_liner = false
		addon_protection = AddonProtectionType.NONE

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

	func get_effective_rha_mm(projectile_type: AmmoType, los_factor: float = 1.0) -> float:
		var total_rha: float = 0.0
		var layers = [outer_layer, filler_layer, rear_layer]
		for layer in layers:
			if layer != null:
				var mult = layer.get_ke_multiplier() if projectile_type == AmmoType.APFSDS else layer.get_heat_multiplier()
				total_rha += layer.thickness_mm * los_factor * mult
		if has_spall_liner:
			total_rha += 15.0 * los_factor * 0.3
		total_rha += ArmorCalculator.get_addon_rha_bonus_mm(addon_protection, projectile_type)
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


static func get_addon_rha_bonus_mm(addon: AddonProtectionType, projectile_type: AmmoType) -> float:
	match addon:
		AddonProtectionType.NONE:
			return 0.0
		AddonProtectionType.ERA_KONTAKT1:
			return 350.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 0.0
		AddonProtectionType.ERA_KONTAKT5:
			return 600.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 250.0
		AddonProtectionType.ERA_RELIKT:
			return 800.0 if projectile_type == AmmoType.HEAT else (400.0 if projectile_type == AmmoType.ATGM else 400.0)
		AddonProtectionType.SLAT_CAGE_GRID:
			return 150.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 10.0
		AddonProtectionType.SIDE_SKIRTS_SOFT:
			return 80.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 5.0
		AddonProtectionType.COPE_CAGE_MANGAL:
			return 200.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 15.0
		AddonProtectionType.STEALTH_NAKIDKA:
			return 20.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 0.0
	return 0.0


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


## Calculate Effective Armor Thickness considering Line-Of-Sight (LOS) angle:
## T_eff = T / cos(theta)
static func calculate_effective_thickness(nominal_thickness_mm: float, normal: Vector3, ray_dir: Vector3) -> float:
	var cos_theta = abs(normal.dot(-ray_dir))
	# Clamp angle to prevent infinite thickness on extreme glancing hits (>85 deg)
	cos_theta = max(cos_theta, cos(deg_to_rad(85.0)))
	return nominal_thickness_mm / cos_theta


## Perform full impact penetration test supporting ArmorSandwich or nominal values
static func evaluate_impact(
	projectile_type: AmmoType,
	penetration_capacity_mm: float,
	nominal_armor_mm: float,
	armor_material: ArmorType,
	impact_normal: Vector3,
	projectile_direction: Vector3,
	sandwich: ArmorSandwich = null
) -> ImpactResult:
	var result = ImpactResult.new()
	
	var cos_theta = abs(impact_normal.dot(-projectile_direction))
	var angle_rad = acos(clamp(cos_theta, 0.0, 1.0))
	result.impact_angle_deg = rad_to_deg(angle_rad)
	
	var los_factor = 1.0 / max(cos_theta, 0.087) # 0.087 = cos(85 deg)
	
	if sandwich != null:
		result.effective_thickness_mm = sandwich.get_effective_rha_mm(projectile_type, los_factor)
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
				era_reduction_mm = 350.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 0.0
			ArmorType.ERA_KONTAKT5:
				era_reduction_mm = 600.0 if (projectile_type == AmmoType.HEAT or projectile_type == AmmoType.ATGM) else 250.0
			ArmorType.ERA_RELIKT:
				era_reduction_mm = 800.0 if (projectile_type == AmmoType.HEAT) else (400.0 if projectile_type == AmmoType.ATGM else 350.0)
		
		result.effective_thickness_mm = (los_thickness * rha_multiplier) + era_reduction_mm

	# Check for ricochet on extreme angles (> 78 deg for APFSDS, > 82 deg for HEAT)
	var ricochet_angle = 78.0 if projectile_type == AmmoType.APFSDS else 82.0
	if result.impact_angle_deg > ricochet_angle:
		result.penetrated = false
		result.residual_penetration_mm = 0.0
		result.description = "RICOCHET (Glancing hit at %.1f°)" % result.impact_angle_deg
		return result
		
	if penetration_capacity_mm >= result.effective_thickness_mm:
		result.penetrated = true
		result.residual_penetration_mm = penetration_capacity_mm - result.effective_thickness_mm
		result.description = "PENETRATION (Pen: %.0fmm vs Eff: %.0fmm)" % [penetration_capacity_mm, result.effective_thickness_mm]
	else:
		result.penetrated = false
		result.residual_penetration_mm = 0.0
		result.description = "NON-PENETRATION / SHOCKED (Pen: %.0fmm vs Eff: %.0fmm)" % [penetration_capacity_mm, result.effective_thickness_mm]
		
	return result

