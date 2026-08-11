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
	if event is InputEventMouseMotion and _rmb_held:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, -1.2, 0.2)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	match current_mode:
		CameraMode.THIRD_PERSON:
			_update_chase(delta)
		CameraMode.GUNNER_SCOPE:
			_update_gunner(delta)

func _update_chase(delta: float) -> void:
	var target_pos := target.global_position
	var offset := Vector3(
		sin(_yaw) * cos(_pitch) * chase_distance,
		sin(-_pitch) * chase_distance + chase_height,
		cos(_yaw) * cos(_pitch) * chase_distance
	)
	var desired_pos := target_pos + offset
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	if camera_3d:
		camera_3d.look_at(target_pos + Vector3.UP * 1.5)

func _update_gunner(delta: float) -> void:
	## Position camera at turret/gun position looking forward
	var turret := target.get_node_or_null("ProceduralTurret") as Node3D
	if turret:
		var gun_tip := turret.global_position + turret.global_transform.basis.z * -3.0 + Vector3.UP * 0.5
		global_position = global_position.lerp(gun_tip, follow_speed * 2.0 * delta)
		if camera_3d:
			camera_3d.look_at(global_position - turret.global_transform.basis.z * 100.0)
	else:
		var forward := -target.global_transform.basis.z
		var scope_pos := target.global_position + Vector3.UP * 2.5 + forward * 2.0
		global_position = global_position.lerp(scope_pos, follow_speed * 2.0 * delta)
		if camera_3d:
			camera_3d.look_at(global_position + forward * 100.0)

func toggle_camera_mode() -> void:
	if current_mode == CameraMode.THIRD_PERSON:
		current_mode = CameraMode.GUNNER_SCOPE
	else:
		current_mode = CameraMode.THIRD_PERSON
