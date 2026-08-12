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

class Projectile extends RefCounted:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var distance_traveled: float = 0.0
	var initial_velocity_ms: float = 1750.0
	var penetration_mm: float = 600.0
	var ammo_type: ArmorCalculator.AmmoType = ArmorCalculator.AmmoType.APFSDS
	var visual_node: Node3D = null
	var lifetime: float = 0.0
	var max_lifetime: float = 10.0

var _active_projectiles: Array[Projectile] = []

func _ready() -> void:
	_update_raycast_exceptions()

func _exit_tree() -> void:
	for proj in _active_projectiles:
		if proj.visual_node and is_instance_valid(proj.visual_node):
			proj.visual_node.queue_free()
	_active_projectiles.clear()

func _update_raycast_exceptions() -> void:
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		fire()

func _physics_process(delta: float) -> void:
	_update_reload(delta)
	_update_projectiles(delta)

func _update_reload(delta: float) -> void:
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

	# Determine barrel tip position and firing direction vector
	var spawn_pos := global_position
	var fire_dir := -global_transform.basis.z.normalized()

	if turret_builder and turret_builder.gun_barrel_mesh_instance:
		var barrel := turret_builder.gun_barrel_mesh_instance
		spawn_pos = barrel.global_position + barrel.global_transform.basis.z * -(turret_builder.barrel_length * 0.5)
		fire_dir = -barrel.global_transform.basis.z.normalized()

	# Instantiate physical projectile entity
	var proj := Projectile.new()
	proj.position = spawn_pos
	proj.velocity = fire_dir * muzzle_velocity_ms
	proj.initial_velocity_ms = muzzle_velocity_ms
	proj.penetration_mm = penetration_mm
	proj.ammo_type = ammo_type
	proj.distance_traveled = 0.0
	proj.lifetime = 0.0

	# Create glowing 3D visual tracer effect
	var tracer := _create_tracer_visual(caliber_mm)
	tracer.global_position = spawn_pos
	if fire_dir.length_squared() > 0.01:
		var up := Vector3.UP
		if absf(fire_dir.dot(up)) > 0.99:
			up = Vector3.RIGHT
		tracer.look_at(spawn_pos + fire_dir, up)

	var world_root := get_tree().current_scene if get_tree() and get_tree().current_scene else (get_tree().root if get_tree() else get_parent())
	if world_root:
		world_root.add_child(tracer)
	proj.visual_node = tracer

	_active_projectiles.append(proj)

func _update_projectiles(delta: float) -> void:
	if _active_projectiles.is_empty():
		return

	var vehicle_rids := _get_vehicle_collision_rids()
	var space_state := get_world_3d().direct_space_state if get_world_3d() else null
	var projectiles_to_remove: Array[Projectile] = []

	for proj in _active_projectiles:
		proj.lifetime += delta
		if proj.lifetime > proj.max_lifetime:
			projectiles_to_remove.append(proj)
			continue

		var old_pos := proj.position

		# 1. Update cumulative distance traveled (meters)
		var step_dist := proj.velocity.length() * delta
		proj.distance_traveled += step_dist

		# 2. Velocity drag degradation: v(d) = v0 * max(0.7, 1.0 - 0.00015 * d)
		var drag_factor := maxf(0.7, 1.0 - 0.00015 * proj.distance_traveled)
		var current_speed := proj.initial_velocity_ms * drag_factor
		var vel_dir := proj.velocity.normalized() if proj.velocity.length_squared() > 0.001 else Vector3.FORWARD
		proj.velocity = vel_dir * current_speed

		# 3. Parabolic gravity arc drop: g = 9.81 m/s^2
		proj.velocity.y -= 9.81 * delta

		# 4. Advance position for current step
		var new_pos := old_pos + proj.velocity * delta
		proj.position = new_pos

		# 5. Continuous segment raycast to detect collision without high-speed tunneling
		if space_state:
			var query := PhysicsRayQueryParameters3D.create(old_pos, new_pos)
			query.exclude = vehicle_rids
			query.collide_with_bodies = true
			query.collide_with_areas = true

			var hit := space_state.intersect_ray(query)
			if not hit.is_empty():
				var hit_pos: Vector3 = hit.position
				var hit_normal: Vector3 = hit.normal
				var collider: Object = hit.collider

				# Compute exact distance to hit point
				var exact_dist := proj.distance_traveled - old_pos.distance_to(new_pos) + old_pos.distance_to(hit_pos)
				var hit_drag_factor := maxf(0.7, 1.0 - 0.00015 * exact_dist)
				var hit_speed := proj.initial_velocity_ms * hit_drag_factor

				# Scale penetration capacity dynamically with velocity for APFSDS: Pen(d) = Pen0 * v(d) / v0
				var current_pen := proj.penetration_mm
				if proj.ammo_type == ArmorCalculator.AmmoType.APFSDS:
					var v0_safe := maxf(1.0, proj.initial_velocity_ms)
					current_pen = proj.penetration_mm * (hit_speed / v0_safe)

				# Retrieve armor metadata from target
				var armor_sandwich: ArmorCalculator.ArmorSandwich = null
				var armor_thickness := 100.0
				var armor_type := ArmorCalculator.ArmorType.RHA_STEEL

				if collider:
					var target_node: Node = collider as Node
					while target_node != null and not target_node.has_method("get_armor_sandwich_at"):
						target_node = target_node.get_parent()
					if target_node != null and target_node.has_method("get_armor_sandwich_at"):
						armor_sandwich = target_node.get_armor_sandwich_at(hit_pos)
					elif collider.has_meta("armor_sandwich"):
						var meta_sandwich = collider.get_meta("armor_sandwich")
						if meta_sandwich is ArmorCalculator.ArmorSandwich:
							armor_sandwich = meta_sandwich
					if collider.has_meta("armor_thickness_mm"):
						armor_thickness = float(collider.get_meta("armor_thickness_mm"))
					if collider.has_meta("armor_type"):
						armor_type = collider.get_meta("armor_type") as ArmorCalculator.ArmorType

				var ray_dir := (new_pos - old_pos).normalized()
				var result := ArmorCalculator.evaluate_impact(
					proj.ammo_type,
					current_pen,
					armor_thickness,
					armor_type,
					hit_normal,
					ray_dir,
					armor_sandwich
				)
				result.hit_position = hit_pos
				impact_result.emit(result)

				proj.position = hit_pos
				projectiles_to_remove.append(proj)
				continue

		# Update visual tracer mesh transform
		if proj.visual_node and is_instance_valid(proj.visual_node):
			proj.visual_node.global_position = proj.position
			if proj.velocity.length_squared() > 0.01:
				var up := Vector3.UP
				if absf(proj.velocity.normalized().dot(up)) > 0.99:
					up = Vector3.RIGHT
				proj.visual_node.look_at(proj.position + proj.velocity, up)

	# Clean up despawned or impacted projectiles
	for proj in projectiles_to_remove:
		if proj.visual_node and is_instance_valid(proj.visual_node):
			proj.visual_node.queue_free()
		_active_projectiles.erase(proj)

func _create_tracer_visual(p_caliber_mm: float) -> Node3D:
	var tracer_root := Node3D.new()
	tracer_root.name = "ProjectileTracer"

	# Shell body mesh
	var shell_mesh := MeshInstance3D.new()
	shell_mesh.name = "ShellMesh"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = clampf(p_caliber_mm / 2000.0, 0.04, 0.1)
	cylinder.bottom_radius = clampf(p_caliber_mm / 2000.0, 0.04, 0.1)
	cylinder.height = 0.5
	shell_mesh.mesh = cylinder
	shell_mesh.rotation_degrees.x = 90.0

	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.25, 0.25, 0.3)
	shell_mat.metallic = 0.8
	shell_mat.roughness = 0.3
	shell_mesh.material_override = shell_mat
	tracer_root.add_child(shell_mesh)

	# Tracer streak mesh
	var streak_mesh := MeshInstance3D.new()
	streak_mesh.name = "TracerStreak"
	var box := BoxMesh.new()
	var streak_width: float = clampf(p_caliber_mm / 1200.0, 0.06, 0.15)
	var streak_length: float = 4.0
	box.size = Vector3(streak_width, streak_width, streak_length)
	streak_mesh.mesh = box
	streak_mesh.position = Vector3(0, 0, streak_length * 0.5 + 0.25)

	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.albedo_color = Color(1.0, 0.85, 0.3)
	tracer_mat.emission_enabled = true
	tracer_mat.emission = Color(1.0, 0.7, 0.1)
	tracer_mat.emission_energy_multiplier = 8.0
	streak_mesh.material_override = tracer_mat
	tracer_root.add_child(streak_mesh)

	# OmniLight3D for bright illumination
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.3)
	light.light_energy = 2.5
	light.omni_range = 6.0
	tracer_root.add_child(light)

	return tracer_root

func _get_vehicle_collision_rids() -> Array[RID]:
	var rids: Array[RID] = []
	var root := get_parent()
	if root:
		_collect_rids(root, rids)
	if turret_builder and turret_builder != root:
		_collect_rids(turret_builder, rids)
	if hull_builder and hull_builder != root:
		_collect_rids(hull_builder, rids)
	return rids

func _collect_rids(node: Node, rids: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid := (node as CollisionObject3D).get_rid()
		if not rids.has(rid):
			rids.append(rid)
	if "static_collision_body" in node and node.static_collision_body is CollisionObject3D:
		var rid := (node.static_collision_body as CollisionObject3D).get_rid()
		if not rids.has(rid):
			rids.append(rid)
	for child in node.get_children():
		_collect_rids(child, rids)

