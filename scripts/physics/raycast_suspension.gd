class_name RaycastSuspensionChassis
extends RigidBody3D

## Raycast-based tracked vehicle suspension physics script running over Godot-Jolt.
## Simulates spring compression, damping, friction, track skid steering, and torque.

@export_group("Engine & Propulsion")
@export_range(100.0, 2000.0, 50.0) var engine_horsepower: float = 1200.0 ## HP
@export_range(10.0, 100.0, 5.0) var max_speed_kmh: float = 65.0 ## Top speed km/h
@export_range(1.0, 10.0, 0.5) var steer_sensitivity: float = 4.0 ## Turning torque

@export_group("Suspension Parameters")
@export_range(0.1, 1.5, 0.05) var rest_length: float = 0.6 ## Suspension travel meters
@export_range(1000.0, 80000.0, 1000.0) var spring_stiffness: float = 35000.0 ## Spring constant k
@export_range(100.0, 8000.0, 1000.0) var spring_damping: float = 3200.0 ## Damping coefficient c
@export_range(0.1, 0.8, 0.02) var wheel_radius: float = 0.35 ## Road wheel radius (m)

@export_group("Wheel Anchor Setup")
@export var wheel_mount_nodes: Array[NodePath] = []

var _raycasts: Array[RayCast3D] = []
var _wheel_mesh_nodes: Array[Node3D] = []
var _inputs: Vector2 = Vector2.ZERO # x = steering (-1..1), y = throttle (-1..1)
var _track_generator_node: Node = null

func _ready() -> void:
	# Set rigid body physics defaults for Godot-Jolt
	self.mass = 42000.0 # 42 Tons MBT standard
	self.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	self.center_of_mass = Vector3(0.0, -0.3, 0.0) # Low center of gravity for stability
	
	_initialize_suspension_rays()

func _initialize_suspension_rays() -> void:
	# If no explicit wheel mounts provided, auto-generate standard 2x6 tank roadwheel layout
	if wheel_mount_nodes.is_empty():
		_generate_default_wheel_layout()
	else:
		for path in wheel_mount_nodes:
			var node = get_node_or_null(path)
			if node is RayCast3D:
				_raycasts.append(node)

func _generate_default_wheel_layout() -> void:
	var wheel_container = Node3D.new()
	wheel_container.name = "SuspensionRays"
	add_child(wheel_container)
	
	var roadwheel_count_per_side = 6
	var length_span = 4.8 # meters
	var track_width = 1.4 # meters from center
	
	for side in [-1.0, 1.0]: # Left (-1) and Right (1)
		for i in range(roadwheel_count_per_side):
			var z_pos = lerp(-length_span * 0.5, length_span * 0.5, float(i) / float(roadwheel_count_per_side - 1))
			var ray = RayCast3D.new()
			ray.name = "Ray_%s_%d" % ["L" if side < 0 else "R", i]
			ray.position = Vector3(side * track_width, 0.0, z_pos)
			ray.target_position = Vector3(0.0, -(rest_length + wheel_radius), 0.0)
			ray.enabled = true
			ray.add_exception(self)
			wheel_container.add_child(ray)
			_raycasts.append(ray)

func _physics_process(delta: float) -> void:
	_read_player_input()
	_apply_suspension_forces(delta)
	_apply_propulsion_and_steering(delta)
	_animate_tracks_and_wheels(delta)

func _animate_tracks_and_wheels(delta: float) -> void:
	var forward_dir = -global_transform.basis.z
	var current_speed_ms = linear_velocity.dot(forward_dir)
	var track_gen = _find_track_generator()
	if track_gen and track_gen.has_method("animate_tracks_and_wheels"):
		track_gen.animate_tracks_and_wheels(current_speed_ms, delta)

func _find_track_generator() -> Node:
	if _track_generator_node and is_instance_valid(_track_generator_node):
		return _track_generator_node

	if has_node("TrackGenerator"):
		_track_generator_node = get_node("TrackGenerator")
		return _track_generator_node

	for child in get_children():
		if child is TrackGenerator or child.has_method("animate_tracks_and_wheels"):
			_track_generator_node = child
			return _track_generator_node

	if get_parent() != null:
		for sibling in get_parent().get_children():
			if sibling != self and (sibling is TrackGenerator or sibling.has_method("animate_tracks_and_wheels")):
				_track_generator_node = sibling
				return _track_generator_node

	return null

func _read_player_input() -> void:
	var forward = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var turn = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	_inputs = Vector2(turn, forward)

func _apply_suspension_forces(delta: float) -> void:
	var up_dir = global_transform.basis.y
	
	for ray in _raycasts:
		if not ray.is_colliding():
			continue
			
		var hit_point = ray.get_collision_point()
		var ray_origin = ray.global_position
		var current_distance = ray_origin.distance_to(hit_point) - wheel_radius
		var compression = rest_length - current_distance
		
		if compression > 0.0:
			# Spring force: F_spring = k * x
			var spring_force = compression * spring_stiffness
			
			# Damping force: F_damp = c * v_rel
			var wheel_velocity = _get_point_velocity(ray_origin)
			var damp_force = wheel_velocity.dot(up_dir) * spring_damping
			
			var total_force_magnitude = max(0.0, spring_force - damp_force)
			var force_vector = up_dir * total_force_magnitude
			
			# Apply force at wheel contact point
			apply_force(force_vector, ray_origin - global_position)
			
			# Track lateral friction (anti-slide)
			_apply_lateral_friction(ray_origin, wheel_velocity, delta)

func _apply_lateral_friction(point: Vector3, velocity: Vector3, delta: float) -> void:
	var right_dir = global_transform.basis.x
	var lateral_vel = velocity.dot(right_dir)
	
	# Counteract sideways sliding with track tread grip
	var counter_force = -right_dir * (lateral_vel * mass * 0.15 / max(1, _raycasts.size()))
	apply_force(counter_force, point - global_position)

func _apply_propulsion_and_steering(delta: float) -> void:
	var total_rays = _raycasts.size()
	if total_rays == 0:
		return

	var grounded_rays: int = 0
	for ray in _raycasts:
		if ray.is_colliding():
			grounded_rays += 1

	var ground_contact_ratio: float = float(grounded_rays) / float(total_rays)

	var forward_dir = -global_transform.basis.z
	var current_speed_ms = linear_velocity.dot(forward_dir)
	var current_speed_kmh = current_speed_ms * 3.6
	
	# Throttle force
	if abs(_inputs.y) > 0.05 and abs(current_speed_kmh) < max_speed_kmh:
		# Convert engine HP to force N: P = F * v => F = P / max(v, 1)
		var max_torque_force = (engine_horsepower * 745.7) / max(5.0, abs(current_speed_ms))
		var drive_force = forward_dir * (_inputs.y * max_torque_force * ground_contact_ratio)
		apply_central_force(drive_force)
		
	# Tank Skid Steering (Differential torque)
	if abs(_inputs.x) > 0.05:
		var torque_vector = -global_transform.basis.y * (_inputs.x * steer_sensitivity * mass * 1.5 * ground_contact_ratio)
		apply_torque(torque_vector)

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)
