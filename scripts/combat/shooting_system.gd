class_name ShootingSystem
extends Node3D

signal shot_fired(ammo_remaining: int)
signal impact_result(result: ArmorCalculator.ImpactResult)
signal reload_progress(progress: float)

@export var turret_builder: TurretBuilder
@export var hull_builder: HullBuilder
@export_range(80.0, 152.0, 1.0) var caliber_mm: float = 125.0
@export_range(500.0, 2000.0, 50.0) var muzzle_velocity_ms: float = 1750.0
@export_range(300.0, 1000.0, 10.0) var penetration_mm: float = 600.0
@export var ammo_type: ArmorCalculator.AmmoType = ArmorCalculator.AmmoType.APFSDS

var ammo_count: int = 40
var reload_time_sec: float = 6.5
var _reload_timer: float = 0.0
var _is_reloading: bool = false
var _fire_raycast: RayCast3D

func _ready() -> void:
	_fire_raycast = RayCast3D.new()
	_fire_raycast.name = "FireRayCast"
	_fire_raycast.target_position = Vector3(0, 0, -3000)  # 3km range
	_fire_raycast.enabled = true
	add_child(_fire_raycast)
	_update_raycast_exceptions()

func _update_raycast_exceptions() -> void:
	if _fire_raycast == null:
		return
	_fire_raycast.clear_exceptions()

	if turret_builder == null and get_parent():
		for child in get_parent().get_children():
			if child is TurretBuilder:
				turret_builder = child
				break

	if hull_builder == null and get_parent():
		for child in get_parent().get_children():
			if child is HullBuilder:
				hull_builder = child
				break

	var root_vehicle := get_parent()

	_add_exception_target(turret_builder)
	_add_exception_target(hull_builder)
	_add_exception_target(root_vehicle)

func _add_exception_target(target: Node) -> void:
	if target == null:
		return
	if target is CollisionObject3D:
		_fire_raycast.add_exception(target as CollisionObject3D)
	if "static_collision_body" in target and target.static_collision_body is CollisionObject3D:
		_fire_raycast.add_exception(target.static_collision_body as CollisionObject3D)
	for child in target.find_children("", "CollisionObject3D", true, false):
		if child is CollisionObject3D:
			_fire_raycast.add_exception(child as CollisionObject3D)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		fire()

func _process(delta: float) -> void:
	# Position raycast at gun barrel tip
	if turret_builder and turret_builder.gun_barrel_mesh_instance:
		var barrel := turret_builder.gun_barrel_mesh_instance
		_fire_raycast.global_position = barrel.global_position + barrel.global_transform.basis.z * -(turret_builder.barrel_length * 0.5)
		_fire_raycast.global_transform.basis = barrel.global_transform.basis
	
	if _is_reloading:
		_reload_timer -= delta
		var progress := 1.0 - (_reload_timer / reload_time_sec)
		reload_progress.emit(clampf(progress, 0.0, 1.0))
		if _reload_timer <= 0.0:
			_is_reloading = false
			_reload_timer = 0.0

func fire() -> void:
	if _is_reloading or ammo_count <= 0:
		return
	
	_update_raycast_exceptions()

	ammo_count -= 1
	_is_reloading = true
	_reload_timer = reload_time_sec
	shot_fired.emit(ammo_count)
	
	# Raycast check
	_fire_raycast.force_raycast_update()
	if _fire_raycast.is_colliding():
		var hit_pos := _fire_raycast.get_collision_point()
		var hit_normal := _fire_raycast.get_collision_normal()
		var collider := _fire_raycast.get_collider()
		
		# Determine armor properties of hit target
		var armor_sandwich: ArmorCalculator.ArmorSandwich = null
		var armor_thickness := 100.0  # Default
		var armor_type := ArmorCalculator.ArmorType.RHA_STEEL
		
		# Check if we hit something with an ArmorCalculator or known armor
		if collider:
			if collider.has_meta("armor_sandwich"):
				var meta_sandwich = collider.get_meta("armor_sandwich")
				if meta_sandwich is ArmorCalculator.ArmorSandwich:
					armor_sandwich = meta_sandwich
			if collider.has_meta("armor_thickness_mm"):
				armor_thickness = float(collider.get_meta("armor_thickness_mm"))
			if collider.has_meta("armor_type"):
				armor_type = collider.get_meta("armor_type") as ArmorCalculator.ArmorType
		
		var ray_dir := (_fire_raycast.global_transform.basis * Vector3(0, 0, -1)).normalized()
		var result := ArmorCalculator.evaluate_impact(
			ammo_type,
			penetration_mm,
			armor_thickness,
			armor_type,
			hit_normal,
			ray_dir,
			armor_sandwich
		)
		result.hit_position = hit_pos
		impact_result.emit(result)
