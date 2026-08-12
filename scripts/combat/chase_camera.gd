class_name ChaseCamera
extends Node3D

## War Thunder style third-person camera. Always positioned behind and above the tank.
## Mouse orbits around the tank. Camera follows tank heading.
## RMB = freelook (no turret rotation). V = toggle gunner scope.

enum CameraMode { THIRD_PERSON, GUNNER_SCOPE }

@export var target: Node3D
@export var camera_3d: Camera3D
@export_range(4.0, 22.0, 0.5) var chase_distance: float = 10.0
@export_range(2.0, 10.0, 0.5) var chase_height: float = 4.0
@export_range(0.001, 0.02, 0.001) var look_sensitivity: float = 0.003

var current_mode: CameraMode = CameraMode.THIRD_PERSON
## Mouse-relative yaw offset from tank heading (radians)
var _yaw_offset: float = 0.0
## Pitch angle (radians, negative = look down)
var _pitch: float = -0.2
var _rmb_held: bool = false

func _ready() -> void:
	if camera_3d == null:
		camera_3d = Camera3D.new()
		camera_3d.name = "Camera3D"
		add_child(camera_3d)
	camera_3d.current = true
	camera_3d.fov = 70.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_V:
			toggle_camera_mode()
		elif event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseButton:
		# Click to recapture mouse
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		if event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_held = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			chase_distance = clampf(chase_distance - 1.0, 4.0, 22.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			chase_distance = clampf(chase_distance + 1.0, 4.0, 22.0)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw_offset -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, -1.2, 0.3)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	match current_mode:
		CameraMode.THIRD_PERSON:
			_update_chase(delta)
		CameraMode.GUNNER_SCOPE:
			_update_gunner(delta)

	_update_turret_aiming()

func _update_chase(_delta: float) -> void:
	if target == null or camera_3d == null:
		return

	# Tank center pivot (slightly above hull top)
	var pivot: Vector3 = target.global_position + Vector3.UP * 1.5

	# Tank's forward direction is +X in Composite coordinate space
	var tank_fwd: Vector3 = target.global_transform.basis.x.normalized()
	# Tank heading yaw angle in world XZ plane
	var tank_yaw: float = atan2(-tank_fwd.z, tank_fwd.x)

	# Combined yaw = tank heading + mouse offset
	# At _yaw_offset = 0, camera is directly behind the tank
	var cam_yaw: float = tank_yaw + PI + _yaw_offset

	# Spherical offset from pivot: behind and above tank
	var horiz_dist: float = chase_distance * cos(_pitch)
	var vert_dist: float = chase_distance * sin(-_pitch) + chase_height

	var cam_offset := Vector3(
		cos(cam_yaw) * horiz_dist,
		vert_dist,
		-sin(cam_yaw) * horiz_dist
	)

	# Set camera position rigidly
	global_position = pivot + cam_offset

	# Look at pivot
	camera_3d.global_position = global_position
	camera_3d.look_at(pivot, Vector3.UP)

func _update_gunner(_delta: float) -> void:
	if target == null or camera_3d == null:
		return
	var turret := target.get_node_or_null("ProceduralTurret") as Node3D
	if turret:
		var gun_tip := turret.global_position + turret.global_transform.basis.x * 3.0 + Vector3.UP * 0.4
		global_position = global_position.lerp(gun_tip, clampf(30.0 * _delta, 0.0, 1.0))
		camera_3d.global_position = global_position
		camera_3d.look_at(global_position + turret.global_transform.basis.x * 100.0)
	else:
		var forward := target.global_transform.basis.x
		var scope_pos := target.global_position + Vector3.UP * 2.2 + forward * 2.0
		global_position = global_position.lerp(scope_pos, clampf(30.0 * _delta, 0.0, 1.0))
		camera_3d.global_position = global_position
		camera_3d.look_at(global_position + forward * 100.0)

func _update_turret_aiming() -> void:
	if target == null or camera_3d == null or _rmb_held:
		return
	var turret = target.get_node_or_null("ProceduralTurret") as TurretBuilder
	if turret == null:
		return
	var viewport = get_viewport()
	if viewport == null:
		return

	# Raycast from camera center into world to find exact aim point
	var screen_center = viewport.get_visible_rect().size * 0.5
	var ray_origin = camera_3d.project_ray_origin(screen_center)
	var ray_dir = camera_3d.project_ray_normal(screen_center)
	var aim_target = ray_origin + ray_dir * 1000.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 2000.0)
	query.exclude = [target.get_rid()]
	query.collision_mask = 1
	var hit = space_state.intersect_ray(query)
	if not hit.is_empty():
		aim_target = hit.position

	# Transform aim point into HULL (turret parent) local space, NOT turret local space,
	# because set_aim_target sets rotation_degrees.y which is relative to the parent node.
	var hull_transform: Transform3D = target.global_transform
	var local_aim = hull_transform.affine_inverse() * aim_target
	# Turret is offset from hull origin — subtract turret's local position
	var turret_local_pos = turret.position
	local_aim -= turret_local_pos
	var aim_yaw_deg = rad_to_deg(atan2(-local_aim.z, local_aim.x))
	var horiz_dist = Vector2(local_aim.x, local_aim.z).length()
	var aim_pitch_deg = rad_to_deg(atan2(local_aim.y, horiz_dist))
	turret.set_aim_target(aim_yaw_deg, aim_pitch_deg)

func toggle_camera_mode() -> void:
	if current_mode == CameraMode.THIRD_PERSON:
		current_mode = CameraMode.GUNNER_SCOPE
	else:
		current_mode = CameraMode.THIRD_PERSON
