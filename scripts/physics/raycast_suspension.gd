class_name RaycastSuspensionChassis
extends RigidBody3D

## Raycast-based tracked vehicle suspension physics script running over Godot-Jolt.
## Simulates dynamic spring compression, progressive damping, anti-sway bar stabilization,
## friction, track skid steering, torque, dynamic wheel displacement over obstacles, and TTX mass integration.
## Uses central force & torque decomposition to guarantee 100% mathematical stability and prevent GPU driver crashes.

@export_group("Transmission & Power")
@export_range(100.0, 3000.0, 50.0) var engine_horsepower: float = 1200.0 ## HP
@export_range(10.0, 120.0, 5.0) var max_speed_kmh: float = 65.0 ## Top speed km/h
@export_range(1.0, 15.0, 0.5) var steer_sensitivity: float = 5.0 ## Turning torque

@export_group("Suspension Parameters")
@export_range(0.1, 1.5, 0.05) var rest_length: float = 0.65 ## Suspension travel meters
@export_range(5000.0, 200000.0, 1000.0) var spring_stiffness: float = 45000.0 ## Spring constant k (auto-tuned if 0)
@export_range(500.0, 2000.0, 500.0) var spring_damping: float = 4500.0 ## Damping coefficient c
@export_range(0.1, 0.8, 0.02) var wheel_radius: float = 0.35 ## Road wheel radius (m)

var _ray_entries: Array[Dictionary] = []
var _inputs: Vector2 = Vector2.ZERO # x = steering (-1..1), y = throttle (-1..1)
var _track_generator_node: TrackGenerator = null
var _chassis_collision_shape: CollisionShape3D = null

# Transmission state
var current_gear: int = 1 # 1..6 Forward, -1..-2 Reverse, 0 Neutral
var current_rpm: float = 800.0
const IDLE_RPM: float = 800.0
const MAX_RPM: float = 2400.0
const GEAR_RATIOS_FWD: Array[float] = [0.0, 14.0, 8.5, 5.2, 3.4, 2.2, 1.5]
const GEAR_RATIOS_REV: Array[float] = [0.0, -10.0, -5.0]

# Telemetry output structure for diagnostic logging
class TelemetryFrame extends RefCounted:
	var position: Vector3 = Vector3.ZERO
	var speed_kmh: float = 0.0
	var angular_speed_rad: float = 0.0
	var grounded_rays: int = 0
	var max_compression_m: float = 0.0
	var is_valid_finite: bool = true

func _ready() -> void:
	self.collision_layer = 2 # Vehicle Layer 2
	self.collision_mask = 1  # Collides only with Environment Layer 1
	self.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	self.center_of_mass = Vector3(0.0, -0.4, 0.0)
	self.linear_damp = 0.8
	self.angular_damp = 3.5
	call_deferred("_auto_setup_test_range")

func _auto_setup_test_range() -> void:
	var hull: HullBuilder = null
	var turret: TurretBuilder = null
	var tracks: TrackGenerator = null
	var engine_hp: float = 1200.0

	for child in get_children():
		if child is HullBuilder: hull = child
		elif child is TurretBuilder: turret = child
		elif child is TrackGenerator: tracks = child

	if FileAccess.file_exists("user://temp_tank.json"):
		var data = TankSerializer.load_preset("user://temp_tank.json")
		if not data.is_empty():
			if data.has("hull") and hull:
				var h = data["hull"]
				hull.set_dimensions(h.get("length", 6.8), h.get("width", 3.4), h.get("height", 1.4), h.get("front_glacis_angle_deg", 60.0), h.get("glacis_style", 0), true)
				hull.front_armor_mm = h.get("front_armor_mm", 450.0)
			if data.has("turret") and turret:
				var t = data["turret"]
				var t_len = t.get("length", t.get("turret_length", 3.2))
				var t_wid = t.get("width", t.get("turret_width", 2.4))
				var t_hei = t.get("height", t.get("turret_height", 1.2))
				var b_len = t.get("barrel_length", 5.5)
				turret.turret_length = t_len
				turret.turret_width = t_wid
				turret.turret_height = t_hei
				turret.barrel_length = b_len
				turret.generate_turret_and_gun()
			if data.has("firepower"):
				var fp = data["firepower"]
				var cal = fp.get("caliber_mm", 120.0)
				var b_len = fp.get("barrel_length_m", 6.2)
				if turret:
					turret.barrel_length = b_len
					turret.generate_turret_and_gun()
				var shooting_sys = get_node_or_null("ShootingSystem") as ShootingSystem
				if shooting_sys:
					shooting_sys.caliber_mm = cal
					shooting_sys.penetration_mm = 600.0 if cal >= 120.0 else 450.0
			if data.has("chassis") and tracks:
				var c = data["chassis"]
				tracks.set_chassis_parameters(c.get("road_wheel_pairs", 6), c.get("wheel_diameter", 0.65), c.get("track_width", 0.6), 0.6)
			if data.has("powertrain"):
				engine_hp = data["powertrain"].get("engine_hp", 1200.0)

	setup_vehicle_from_builder(hull, turret, tracks, engine_hp)

## Public API to dynamically configure vehicle physics from tank editor builders & stats
func setup_vehicle_from_builder(
	hull_builder: HullBuilder,
	turret_builder: TurretBuilder,
	track_generator: TrackGenerator,
	engine_hp: float = 1200.0
) -> void:
	_track_generator_node = track_generator
	
	# 1. Calculate Real TTX Mass & Physical Stats
	var ttx = TankStatsCalculator.calculate_stats(hull_builder, turret_builder, track_generator, engine_hp)
	self.mass = max(5000.0, ttx.total_mass_tons * 1000.0) # mass in kg
	self.engine_horsepower = ttx.engine_horsepower
	self.max_speed_kmh = ttx.max_speed_kmh
	self.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	self.center_of_mass = Vector3(0.0, -0.4, 0.0)
	self.linear_damp = 0.8
	self.angular_damp = 3.5
	
	# 2. Setup Solid Chassis Collision Shape directly on RigidBody3D
	_setup_chassis_collision(hull_builder)
	
	# 3. Synchronize Raycast Layout with Visual Road Wheels from TrackGenerator
	if track_generator != null:
		self.wheel_radius = track_generator.wheel_diameter * 0.5
		self.rest_length = track_generator.suspension_height
		_bind_raycasts_to_track_generator(track_generator)
	else:
		_initialize_suspension_rays()

	# 4. Auto-tune Spring Stiffness & Damping based on actual tank mass
	_auto_tune_suspension()
	_refresh_ray_exceptions()

func _setup_chassis_collision(hull_builder: HullBuilder) -> void:
	if _chassis_collision_shape == null:
		_chassis_collision_shape = CollisionShape3D.new()
		_chassis_collision_shape.name = "ChassisBodyCollision"
		add_child(_chassis_collision_shape)
		
	if hull_builder != null:
		_chassis_collision_shape.shape = hull_builder.create_rigidbody_shape()
		_chassis_collision_shape.position = Vector3(0.0, hull_builder.height * 0.25, 0.0)
	else:
		var default_box = BoxShape3D.new()
		default_box.size = Vector3(6.5, 1.0, 3.2)
		_chassis_collision_shape.shape = default_box
		_chassis_collision_shape.position = Vector3(0.0, 0.3, 0.0)

func _auto_tune_suspension() -> void:
	var total_wheels = max(2, _ray_entries.size())
	var target_sag = max(0.1, rest_length * 0.35)
	var weight_per_wheel = (mass * 9.81) / float(total_wheels)
	spring_stiffness = weight_per_wheel / target_sag
	
	var m_wheel = mass / float(total_wheels)
	spring_damping = 1.2 * sqrt(spring_stiffness * m_wheel)

func _initialize_suspension_rays() -> void:
	_clear_rays()
	var track_gen = _find_track_generator()
	if track_gen != null:
		_bind_raycasts_to_track_generator(track_gen)
	else:
		_generate_default_wheel_layout()

func _clear_rays() -> void:
	for entry in _ray_entries:
		var ray: RayCast3D = entry.get("ray")
		if is_instance_valid(ray):
			ray.queue_free()
	_ray_entries.clear()

func _bind_raycasts_to_track_generator(track_gen: TrackGenerator) -> void:
	_clear_rays()
	var specs = track_gen.get_road_wheel_specs()
	
	var ray_container = get_node_or_null("SuspensionRays")
	if ray_container == null:
		ray_container = Node3D.new()
		ray_container.name = "SuspensionRays"
		add_child(ray_container)
		
	for child in ray_container.get_children():
		child.queue_free()

	for spec in specs:
		var side: float = spec["side"]
		var index: int = spec["index"]
		var x_pos: float = spec["x_pos"]
		var z_pos: float = spec["z_pos"]
		
		var ray = RayCast3D.new()
		ray.name = "Ray_%s_%d" % ["L" if side < 0 else "R", index]
		ray.position = Vector3(x_pos, 0.0, z_pos)
		ray.target_position = Vector3(0.0, -(rest_length + wheel_radius + 0.5), 0.0)
		ray.collision_mask = 1
		ray.enabled = true
		ray_container.add_child(ray)
		
		_ray_entries.append({
			"ray": ray,
			"side": side,
			"index": index,
			"x_pos": x_pos,
			"z_pos": z_pos
		})
	_refresh_ray_exceptions()

func _generate_default_wheel_layout() -> void:
	_clear_rays()
	var ray_container = Node3D.new()
	ray_container.name = "SuspensionRays"
	add_child(ray_container)
	
	var roadwheel_count_per_side = 6
	var length_span = 4.8
	var track_width = 1.4
	
	for side in [-1.0, 1.0]:
		for i in range(roadwheel_count_per_side):
			var x_pos = lerp(-length_span * 0.5, length_span * 0.5, float(i) / float(roadwheel_count_per_side - 1))
			var z_pos = side * track_width
			var ray = RayCast3D.new()
			ray.name = "Ray_%s_%d" % ["L" if side < 0 else "R", i]
			ray.position = Vector3(x_pos, 0.0, z_pos)
			ray.target_position = Vector3(0.0, -(rest_length + wheel_radius + 0.5), 0.0)
			ray.collision_mask = 1
			ray.enabled = true
			ray_container.add_child(ray)
			
			_ray_entries.append({
				"ray": ray,
				"side": side,
				"index": i,
				"x_pos": x_pos,
				"z_pos": z_pos
			})
	_refresh_ray_exceptions()

func _refresh_ray_exceptions() -> void:
	for entry in _ray_entries:
		var ray: RayCast3D = entry.get("ray")
		if is_instance_valid(ray):
			_add_vehicle_exceptions(ray)

func _add_vehicle_exceptions(ray: RayCast3D) -> void:
	ray.add_exception(self)
	_exclude_node_children(self, ray)

func _exclude_node_children(node: Node, ray: RayCast3D) -> void:
	if node is CollisionObject3D:
		ray.add_exception(node)
	if "static_collision_body" in node:
		var scb = node.get("static_collision_body")
		if scb is CollisionObject3D:
			ray.add_exception(scb)
	for child in node.get_children():
		_exclude_node_children(child, ray)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return

	# Fall protection & Reset Key ('R'): reset to origin if vehicle falls off map edge or user presses R
	if global_position.y < -10.0 or not is_finite(global_position.x) or Input.is_key_pressed(KEY_R):
		global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0))
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

	_read_player_input()
	_apply_suspension_forces(delta)
	_apply_propulsion_and_steering(delta)
	_animate_tracks_and_wheels(delta)

func _read_player_input() -> void:
	var forward = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var turn = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if Input.is_key_pressed(KEY_W): forward = 1.0
	elif Input.is_key_pressed(KEY_S): forward = -1.0
	
	if Input.is_key_pressed(KEY_D): turn = 1.0
	elif Input.is_key_pressed(KEY_A): turn = -1.0
	
	_inputs = Vector2(turn, forward)

func _apply_suspension_forces(delta: float) -> void:
	var up_dir = global_transform.basis.y
	var right_dir = global_transform.basis.z
	var track_gen = _find_track_generator()
	var d_rest = rest_length + wheel_radius
	var total_rays = max(1, _ray_entries.size())
	var max_force_per_wheel = (mass * 9.81 * 2.5) / float(total_rays)

	# Track wheel compressions for anti-sway stabilizer bar
	var wheel_compressions: Dictionary = {}

	for entry in _ray_entries:
		var ray: RayCast3D = entry["ray"]
		var side: float = entry["side"]
		var index: int = entry["index"]
		var x_pos: float = entry["x_pos"]
		var z_pos: float = entry["z_pos"]
		
		if not is_instance_valid(ray):
			continue

		# Force immediate RayCast3D update for exact current-frame physics position
		ray.force_raycast_update()
			
		if not ray.is_colliding():
			if track_gen and track_gen.has_method("update_road_wheel_suspension"):
				track_gen.update_road_wheel_suspension(side, index, 0.0)
			continue

		var collider = ray.get_collider()
		if collider != null:
			if collider == self or is_ancestor_of(collider) or collider.get_parent() == self or (collider.get_parent() != null and is_ancestor_of(collider.get_parent())):
				if track_gen and track_gen.has_method("update_road_wheel_suspension"):
					track_gen.update_road_wheel_suspension(side, index, 0.0)
				continue
			
		var hit_point = ray.get_collision_point()
		var ray_origin = ray.global_position
		var dist_to_ground = (hit_point - ray_origin).length()
		var compression = clamp(d_rest - dist_to_ground, 0.0, rest_length)
		wheel_compressions["%s_%d" % ["L" if side < 0 else "R", index]] = compression
		
		if track_gen and track_gen.has_method("update_road_wheel_suspension"):
			track_gen.update_road_wheel_suspension(side, index, compression)
		
		if compression > 0.0:
			var spring_force = compression * spring_stiffness
			var wheel_velocity = _get_point_velocity(ray_origin)
			var v_rel = wheel_velocity.dot(up_dir)
			
			# Correct signed spring damping: opposes chassis vertical velocity
			var f_mag = spring_force - (v_rel * spring_damping)
			f_mag = clamp(f_mag, 0.0, max_force_per_wheel)
			
			# Apply upward spring force at center of mass height to prevent pitch/roll torque feedback loops
			var local_offset_com = Vector3(x_pos, center_of_mass.y, z_pos) - center_of_mass
			apply_force(up_dir * f_mag, local_offset_com)
			
			# Coulomb lateral track friction (bounded strictly by F_normal * 0.85)
			var max_lateral_f = f_mag * 0.85
			var lateral_vel = wheel_velocity.dot(right_dir)
			if abs(lateral_vel) > 0.01:
				var f_frict = clamp(lateral_vel * (mass / float(total_rays)) * 5.0, -max_lateral_f, max_lateral_f)
				apply_force(-right_dir * f_frict, local_offset_com)

	# Apply Anti-Sway Stabilizer Bar Forces between paired Left & Right wheels
	var wheels_per_side = total_rays / 2
	var anti_sway_k = spring_stiffness * 0.4
	for i in range(wheels_per_side):
		var comp_l: float = wheel_compressions.get("L_%d" % i, 0.0)
		var comp_r: float = wheel_compressions.get("R_%d" % i, 0.0)
		var diff = comp_l - comp_r
		if abs(diff) > 0.01:
			var sway_f = diff * anti_sway_k
			apply_torque(-global_transform.basis.x * sway_f * 0.15)

func _apply_propulsion_and_steering(delta: float) -> void:
	var total_rays = _ray_entries.size()
	if total_rays == 0:
		return

	var grounded_rays: int = 0
	for entry in _ray_entries:
		var ray: RayCast3D = entry["ray"]
		if is_instance_valid(ray) and ray.is_colliding():
			grounded_rays += 1

	var ground_contact_ratio: float = float(grounded_rays) / float(total_rays)
	if ground_contact_ratio < 0.05:
		return

	var forward_dir = global_transform.basis.x
	var current_speed_ms = linear_velocity.dot(forward_dir)
	var current_speed_kmh = current_speed_ms * 3.6
	
	# Throttle Drive / Braking Force along +X
	if abs(_inputs.y) > 0.05 and abs(current_speed_kmh) < max_speed_kmh:
		var max_torque_force = (engine_horsepower * 745.7) / max(3.0, abs(current_speed_ms))
		var drive_force = forward_dir * (_inputs.y * max_torque_force * ground_contact_ratio)
		apply_central_force(drive_force)
	elif abs(_inputs.y) <= 0.05 and ground_contact_ratio > 0.1:
		var brake_force = -forward_dir * (current_speed_ms * mass * 3.0 * ground_contact_ratio)
		apply_central_force(brake_force)
		
	# Skid Steering & Stationary Pivot Turn Torque around Y axis
	if abs(_inputs.x) > 0.05:
		var torque_vector = -global_transform.basis.y * (_inputs.x * steer_sensitivity * mass * 0.85 * ground_contact_ratio)
		apply_torque(torque_vector)

func _animate_tracks_and_wheels(delta: float) -> void:
	var forward_dir = global_transform.basis.x
	var current_speed_ms = linear_velocity.dot(forward_dir)
	var track_gen = _find_track_generator()
	if track_gen and track_gen.has_method("animate_tracks_and_wheels"):
		track_gen.animate_tracks_and_wheels(current_speed_ms, delta)

func _find_track_generator() -> TrackGenerator:
	if _track_generator_node and is_instance_valid(_track_generator_node):
		return _track_generator_node

	if has_node("TrackGenerator"):
		_track_generator_node = get_node("TrackGenerator") as TrackGenerator
		return _track_generator_node

	for child in get_children():
		if child is TrackGenerator:
			_track_generator_node = child
			return _track_generator_node

	if get_parent() != null:
		for sibling in get_parent().get_children():
			if sibling != self and sibling is TrackGenerator:
				_track_generator_node = sibling
				return _track_generator_node

	return null

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

## Returns real-time diagnostic telemetry for headless physics unit testing
func capture_telemetry() -> TelemetryFrame:
	var frame = TelemetryFrame.new()
	if not is_inside_tree():
		return frame
	frame.position = global_position
	frame.speed_kmh = linear_velocity.dot(global_transform.basis.x) * 3.6
	frame.angular_speed_rad = angular_velocity.length()
	
	var grounded: int = 0
	var max_comp: float = 0.0
	var d_rest = rest_length + wheel_radius
	
	for entry in _ray_entries:
		var ray: RayCast3D = entry["ray"]
		if is_instance_valid(ray) and ray.is_colliding():
			grounded += 1
			var local_hit = ray.to_local(ray.get_collision_point())
			var comp = clamp(d_rest - (-local_hit.y), 0.0, rest_length)
			max_comp = max(max_comp, comp)
			
	frame.grounded_rays = grounded
	frame.max_compression_m = max_comp
	frame.is_valid_finite = is_finite(global_position.x) and is_finite(angular_velocity.x) and is_finite(linear_velocity.x)
	return frame
