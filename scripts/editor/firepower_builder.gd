class_name FirepowerBuilder
extends Node3D

## Procedural Gun Barrel, Mantlet, and Firepower Manager for Sprocket-style editor.
## Synchronizes gun caliber and length with TurretBuilder to prevent duplicate barrel meshes.

@export_group("Gun Parameters")
@export_range(20.0, 155.0, 5.0) var caliber_mm: float = 120.0 ## Gun Caliber in mm
@export_range(2.0, 8.0, 0.1) var barrel_length_m: float = 6.2 ## Length of barrel in meters
@export_range(-10.0, 30.0, 1.0) var max_elevation_deg: float = 20.0 ## Max Pitch Up
@export_range(-15.0, 5.0, 1.0) var max_depression_deg: float = -8.0 ## Max Pitch Down

@export var turret_builder: TurretBuilder

func _ready() -> void:
	# Locate turret builder if not assigned explicitly
	if turret_builder == null and get_parent():
		turret_builder = get_parent().get_node_or_null("ProceduralTurret")
	sync_with_turret()

func sync_with_turret() -> void:
	if turret_builder:
		turret_builder.barrel_length = barrel_length_m
		turret_builder.barrel_radius = (caliber_mm / 1000.0) * 0.5
		turret_builder.generate_turret_and_gun()

func set_caliber_and_length(p_caliber: float, p_length: float) -> void:
	caliber_mm = p_caliber
	barrel_length_m = p_length
	sync_with_turret()
