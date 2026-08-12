class_name RaycastSuspensionChassis
extends RigidBody3D

## Raycast-based tracked vehicle suspension physics script running over Godot-Jolt.
## Simulates dynamic spring compression, progressive damping, friction, track skid steering,
## torque, dynamic wheel displacement over obstacles, and TTX mass integration.

@export_group("Engine & Propulsion")
@export_range(100.0, 3000.0, 50.0) var engine_horsepower: float = 1200.0 ## HP
@export_range(10.0, 120.0, 5.0) var max_speed_kmh: float = 65.0 ## Top speed km/h
@export_range(1.0, 15.0, 0.5) var steer_sensitivity: float = 5.0 ## Turning torque

@export_group("Suspension Parameters")
@export_range(0.1, 1.5, 0.05) var rest_length: float = 0.65 ## Suspension travel meters
@export_range(5000.0, 200000.0, 1000.0) var spring_stiffness: float = 45000.0 ## Spring constant k (auto-tuned if 0)
@export_range(500.0, 20000.0, 500.0) var spring_damping: float = 4500.0 ## Damping coefficient c
@export_range(0.1, 0.8, 0.02) var wheel_radius: float = 0.35 ## Road wheel radius (m)

var _ray_entries: Array[Dictionary] = []
var _inputs: Vector2 = Vector2.ZERO # x = steering (-1..1), y = throttle (-1..1)
var _track_generator_node: TrackGenerator = null
var _chassis_collision_shape: CollisionShape3D = null

func _ready() -> void:
	self.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	self.center_of_mass = Vector3(0.0, -0.4, 0.0)
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
				turret.turret_length = t.get("turret_length", 3.2)
				turret.turret_width = t.get("turret_width", 2.4)
				turret.turret_height = t.get("turret_height", 1.2)
				turret.barrel_length = t.get("barrel_length", 5.5)
				turret.barrel_caliber_mm = t.get("gun_caliber_mm", 120.0)
				turret.generate_turret_mesh()
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

func _setup_chassis_collision(hull_builder: HullBuilder) -> void:
	if _chassis_collision_shape == null:
		_chassis_collision_shape = CollisionShape3D.new()
		_chassis_collision_shape.name = "ChassisBodyCollision"
		add_child(_chassis_collision_shape)
		
	if hull_builder != null:
		_chassis_collision_shape.shape = hull_builder.create_rigidbody_shape()
	else:
		var default_box = BoxShape3D.new()
		default_box.size = Vector3(3.2, 1.4, 6.5)
		_chassis_collision_shape.shape = default_box

func _auto_tune_suspension() -> void:
	var total_wheels = max(2, _ray_entries.size())
	var target_sag = max(0.1, rest_length * 0.3)
	var weight_per_wheel = (mass * 9.81) / float(total_wheels)
	spring_stiffness = weight_per_wheel / target_sag
	
	var m_wheel = mass / float(total_wheels)
	spring_damping = 1.4 * sqrt(spring_stiffness * m_wheel)

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
		ray.target_position = Vector3(0.0, -(rest_length + wheel_radius + 0.15), 0.0)
		ray.enabled = true
		ray.add_exception(self)
		ray_container.add_child(ray)
		
		_ray_entries.append({
			"ray": ray,
			"side": side,
			"index": index,
			"initial_pos": Vector3(x_pos, 0.0, z_pos)
		})

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
			var ray = RayCast3D.new()
			ray.name = "Ray_%s_%d" % ["L" if side < 0 else "R", i]
			ray.position = Vector3(x_pos, 0.0, side * track_width)
			ray.target_position = Vector3(0.0, -(rest_length + wheel_radius + 0.15), 0.0)
			ray.enabled = true
			ray.add_exception(self)
			ray_container.add_child(ray)
			
			_ray_entries.append({
				"ray": ray,
				"side": side,
				"index": i,
				"initial_pos": ray.position
			})

func _physics_process(delta: float) -> void:
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
	var track_gen = _find_track_generator()
	
	for entry in _ray_entries:
		var ray: RayCast3D = entry["ray"]
		var side: float = entry["side"]
		var index: int = entry["index"]
		
		if not is_instance_valid(ray):
			continue
			
		if not ray.is_colliding():
			if track_gen and track_gen.has_method("update_road_wheel_suspension"):
				track_gen.update_road_wheel_suspension(side, index, 0.0)
			continue
			
		var hit_point = ray.get_collision_point()
		var ray_origin = ray.global_position
		var current_distance = ray_origin.distance_to(hit_point) - wheel_radius
		var compression = rest_length - current_distance
		
		if track_gen and track_gen.has_method("update_road_wheel_suspension"):
			track_gen.update_road_wheel_suspension(side, index, max(0.0, compression))
		
		if compression > 0.0:
			var effective_stiffness = spring_stiffness
			var bump_stop_threshold = rest_length * 0.75
			if compression > bump_stop_threshold:
				var excess_ratio = (compression - bump_stop_threshold) / max(0.001, rest_length * 0.25)
				effective_stiffness *= (1.0 + 3.0 * excess_ratio * excess_ratio)
			
			var spring_force = compression * effective_stiffness
			var wheel_velocity = _get_point_velocity(ray_origin)
			var damp_force = wheel_velocity.dot(up_dir) * spring_damping
			
			var total_force_magnitude = max(0.0, spring_force - damp_force)
			var force_vector = up_dir * total_force_magnitude
			
			apply_force(force_vector, ray_origin - global_position)
			_apply_lateral_friction(ray_origin, wheel_velocity, delta, total_force_magnitude)

func _apply_lateral_friction(point: Vector3, velocity: Vector3, delta: float, normal_force: float = 0.0) -> void:
	var right_dir = global_transform.basis.z # Lateral direction across vehicle width
	var lateral_vel = velocity.dot(right_dir)
	if abs(lateral_vel) < 0.001:
		return
		
	var active_wheels = max(1, _ray_entries.size())
	var wheel_mass = mass / float(active_wheels)
	
	var track_grip_coeff: float = 0.95
	var desired_force = -right_dir * (lateral_vel * wheel_mass * track_grip_coeff / max(0.001, delta))
	
	if normal_force > 0.0:
		var max_friction = normal_force * 1.3
		if desired_force.length() > max_friction:
			desired_force = desired_force.normalized() * max_friction
			
	apply_force(desired_force, point - global_position)

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

	var forward_dir = global_transform.basis.x
	var current_speed_ms = linear_velocity.dot(forward_dir)
	var current_speed_kmh = current_speed_ms * 3.6
	
	if abs(_inputs.y) > 0.05 and abs(current_speed_kmh) < max_speed_kmh:
		var max_torque_force = (engine_horsepower * 745.7) / max(4.0, abs(current_speed_ms))
		var drive_force = forward_dir * (_inputs.y * max_torque_force * ground_contact_ratio)
		apply_central_force(drive_force)
		
	if abs(_inputs.x) > 0.05:
		var torque_vector = -global_transform.basis.y * (_inputs.x * steer_sensitivity * mass * 1.6 * ground_contact_ratio)
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
