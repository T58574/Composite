class_name ArmorCalculator
extends Node

## Armor penetration and ballistics physics calculator for modern MBTs.
## Computes LOS effective thickness T_eff = T / cos(theta), composite RHA equivalency,
## and ERA (Explosive Reactive Armor) degradation effects.

enum AmmoType {
	APFSDS, ## Armor-Piercing Fin-Stabilized Discarding Sabot (Kinetic Energy)
	HEAT,   ## High-Explosive Anti-Tank (Shaped Charge Chemical Energy)
	ATGM    ## Anti-Tank Guided Missile (Tandem HEAT Charge)
}

enum ArmorType {
	RHA_STEEL,  ## Rolled Homogeneous Armor Steel (Multiplier 1.0)
	CAST_STEEL, ## Cast Armor (Multiplier 0.9)
	COMPOSITE,  ## Ceramic / NERA Composite Sandwich (KE ~1.3-1.6, HEAT ~2.0-2.5)
	ERA_KONTAKT1, ## Kontakt-1 Reactive Armor (vs HEAT -300mm, vs KE 0)
	ERA_KONTAKT5, ## Kontakt-5 Heavy Reactive Armor (vs HEAT -500mm, vs KE -250mm)
	ERA_RELIKT    ## Relikt 3rd Gen Reactive Armor (vs HEAT -800mm, vs KE -400mm)
}

class ImpactResult extends RefCounted:
	var penetrated: bool = false
	var effective_thickness_mm: float = 0.0
	var residual_penetration_mm: float = 0.0
	var impact_angle_deg: float = 0.0
	var hit_position: Vector3 = Vector3.ZERO
	var description: String = ""

## Calculate Effective Armor Thickness considering Line-Of-Sight (LOS) angle:
## T_eff = T / cos(theta)
static func calculate_effective_thickness(nominal_thickness_mm: float, normal: Vector3, ray_dir: Vector3) -> float:
	var cos_theta = abs(normal.dot(-ray_dir))
	# Clamp angle to prevent infinite thickness on extreme glancing hits (>85 deg)
	cos_theta = max(cos_theta, cos(deg_to_rad(85.0)))
	return nominal_thickness_mm / cos_theta

## Perform full impact penetration test
static func evaluate_impact(
	projectile_type: AmmoType,
	penetration_capacity_mm: float,
	nominal_armor_mm: float,
	armor_material: ArmorType,
	impact_normal: Vector3,
	projectile_direction: Vector3
) -> ImpactResult:
	var result = ImpactResult.new()
	
	var cos_theta = abs(impact_normal.dot(-projectile_direction))
	var angle_rad = acos(clamp(cos_theta, 0.0, 1.0))
	result.impact_angle_deg = rad_to_deg(angle_rad)
	
	# LOS angle math: T_eff = T / cos(theta)
	var los_thickness = nominal_armor_mm / max(cos_theta, 0.087) # 0.087 = cos(85 deg)
	
	# RHA equivalency coefficient based on armor material and threat type
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
	
	# Check for ricochet on extreme angles (> 78 deg for APFSDS, > 80 deg for HEAT)
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
