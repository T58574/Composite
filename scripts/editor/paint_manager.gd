class_name PaintManager
extends Node

## Manages tank PBR materials, paint color, camouflage schemes, metallic finish, and wear.

enum PaintScheme { SOLID_OLIVE, TRICOLOR_CAMO, DESERT_TAN, WINTER_WHITE, DARK_GRAPHITE }

signal paint_changed(scheme: PaintScheme, primary_color: Color)

@export var primary_color: Color = Color(0.25, 0.28, 0.22, 1.0) # Olive Drab
@export_range(0.0, 1.0, 0.05) var metallic: float = 0.85
@export_range(0.0, 1.0, 0.05) var roughness: float = 0.45
@export_range(0.0, 1.0, 0.05) var edge_wear: float = 0.35
@export_range(0, 4) var camo_type: int = 0
@export_range(0.0, 1.0, 0.05) var dirt_amount: float = 0.4

var current_scheme: PaintScheme = PaintScheme.SOLID_OLIVE

func apply_paint_to_material(material: ShaderMaterial) -> void:
	if material == null:
		return
	material.set_shader_parameter("base_color", primary_color)
	material.set_shader_parameter("metallic", metallic)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("edge_wear", edge_wear)
	material.set_shader_parameter("camo_type", camo_type)
	material.set_shader_parameter("dirt_amount", dirt_amount)

func set_scheme(scheme: PaintScheme) -> void:
	current_scheme = scheme
	match scheme:
		PaintScheme.SOLID_OLIVE:
			camo_type = 1
			primary_color = Color(0.25, 0.28, 0.22, 1.0)
		PaintScheme.TRICOLOR_CAMO:
			camo_type = 3
			primary_color = Color(0.35, 0.38, 0.28, 1.0)
		PaintScheme.DESERT_TAN:
			camo_type = 2
			primary_color = Color(0.76, 0.68, 0.52, 1.0)
		PaintScheme.WINTER_WHITE:
			camo_type = 0
			primary_color = Color(0.85, 0.88, 0.90, 1.0)
		PaintScheme.DARK_GRAPHITE:
			camo_type = 4
			primary_color = Color(0.18, 0.20, 0.22, 1.0)
	
	paint_changed.emit(current_scheme, primary_color)

