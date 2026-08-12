class_name ChaseCamera
extends Node3D

## Third-person chase camera for Test Range. Follows the tank with smooth interpolation.
## Toggle between 3rd person (chase) and 1st person (gunner scope) with 'V' key.

enum CameraMode { THIRD_PERSON, GUNNER_SCOPE }

@export var target: Node3D
@export var camera_3d: Camera3D
@export_range(2.0, 20.0, 0.5) var chase_distance: float = 12.0
@export_range(2.0, 15.0, 0.5) var chase_height: float = 5.0
@export_range(0.5, 10.0, 0.1) var follow_speed: float = 3.0
@export_range(0.001, 0.02, 0.001) var look_sensitivity: float = 0.004

var current_mode: CameraMode = CameraMode.THIRD_PERSON
var _yaw: float = 0.0
var _pitch: float = -0.25
var _rmb_held: bool = false

func _ready() -> void:
	if camera_3d == null:
		camera_3d = Camera3D.new()
		camera_3d.name = "Camera3D"
		add_child(camera_3d)
		camera_3d.current = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		toggle_camera_mode()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_held = event.pressed
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			chase_distance = clampf(chase_distance - 1.0, 4.0, 20.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			chase_distance = clampf(chase_distance + 1.0, 4.0, 20.0)
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, -1.2, 0.4)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	match current_mode:
		CameraMode.THIRD_PERSON:
			_update_chase(delta)
		CameraMode.GUNNER_SCOPE:
			_update_gunner(delta)

	_update_turret_aiming()

func _update_chase(delta: float) -> void:
	if target == null:
		return
	var pivot_pos := target.global_position + Vector3(0.0, 1.2, 0.0)
	# Camera offset relative to target pivot
	var offset := Vector3(
		-cos(_yaw) * cos(_pitch) * chase_distance,
		sin(-_pitch) * chase_distance + 1.2,
		sin(_yaw) * cos(_pitch) * chase_distance
	)
	var desired_pos := pivot_pos + offset
	# Tight War Thunder style follow tracking
	global_position = global_position.lerp(desired_pos, clampf(25.0 * delta, 0.0, 1.0))
	if camera_3d:
		camera_3d.look_at(pivot_pos)

func _update_gunner(delta: float) -> void:
	## Position camera at turret/gun position looking forward along +X
	var turret := target.get_node_or_null("ProceduralTurret") as Node3D
	if turret:
		var gun_tip := turret.global_position + turret.global_transform.basis.x * 3.0 + Vector3.UP * 0.4
		global_position = global_position.lerp(gun_tip, clampf(30.0 * delta, 0.0, 1.0))
		if camera_3d:
			camera_3d.look_at(global_position + turret.global_transform.basis.x * 100.0)
	else:
		var forward := target.global_transform.basis.x
		var scope_pos := target.global_position + Vector3.UP * 2.2 + forward * 2.0
		global_position = global_position.lerp(scope_pos, clampf(30.0 * delta, 0.0, 1.0))
		if camera_3d:
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
	query.collision_mask = 1 # Environment Layer
	var hit = space_state.intersect_ray(query)
	if not hit.is_empty():
		aim_target = hit.position

	var local_aim = turret.global_transform.affine_inverse() * aim_target
	var aim_yaw_deg = rad_to_deg(atan2(-local_aim.z, local_aim.x))
	var horiz_dist = Vector2(local_aim.x, local_aim.z).length()
	var aim_pitch_deg = rad_to_deg(atan2(local_aim.y, horiz_dist))
	turret.set_aim_target(aim_yaw_deg, aim_pitch_deg)

func toggle_camera_mode() -> void:
	if current_mode == CameraMode.THIRD_PERSON:
		current_mode = CameraMode.GUNNER_SCOPE
	else:
		current_mode = CameraMode.THIRD_PERSON
