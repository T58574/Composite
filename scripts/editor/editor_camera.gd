class_name EditorCamera
extends Node3D

## Advanced 3D Orbit & WASD Flight Camera for Tank Editor.
## Controls:
## - RMB / MMB Drag: Rotate camera (captures mouse cursor)
## - WASD / QE: Move camera target in 3D space
## - Mouse Wheel: Zoom spring length
## - 'F' Key: Focus camera on vehicle center

@export var spring_arm: SpringArm3D
@export var camera_3d: Camera3D
@export var mesh_editor: MeshEditor

@export var sensitivity: float = 0.003
@export var move_speed: float = 8.0
@export var zoom_speed: float = 1.0
@export var min_distance: float = 2.0
@export var max_distance: float = 30.0

var pitch_deg: float = -20.0
var yaw_deg: float = 45.0
var is_dragging: bool = false

var is_rmb_down: bool = false
var rmb_press_pos: Vector2 = Vector2.ZERO
var rmb_drag_distance: float = 0.0

func _ready() -> void:
	if mesh_editor == null and get_parent():
		mesh_editor = get_parent().get_node_or_null("MeshEditorController") as MeshEditor
	_setup_nodes()
	_update_camera_transform()

func _setup_nodes() -> void:
	if spring_arm == null:
		spring_arm = get_node_or_null("SpringArm3D") as SpringArm3D
		if spring_arm == null:
			spring_arm = SpringArm3D.new()
			spring_arm.name = "SpringArm3D"
			add_child(spring_arm)
			
	if spring_arm:
		spring_arm.spring_length = 8.0
	
	if camera_3d == null and spring_arm:
		camera_3d = spring_arm.get_node_or_null("Camera3D") as Camera3D
		if camera_3d == null:
			camera_3d = Camera3D.new()
			camera_3d.name = "Camera3D"
			spring_arm.add_child(camera_3d)

func _process(delta: float) -> void:
	_handle_keyboard_movement(delta)

func _handle_keyboard_movement(delta: float) -> void:
	var move_dir = Vector3.ZERO
	var rot_basis = global_transform.basis
	
	if Input.is_key_pressed(KEY_W):
		move_dir -= rot_basis.z
	if Input.is_key_pressed(KEY_S):
		move_dir += rot_basis.z
	if Input.is_key_pressed(KEY_A):
		move_dir -= rot_basis.x
	if Input.is_key_pressed(KEY_D):
		move_dir += rot_basis.x
	if Input.is_key_pressed(KEY_E):
		move_dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		move_dir -= Vector3.UP
		
	if move_dir.length_squared() > 0.01:
		global_position += move_dir.normalized() * (move_speed * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_rmb_down = true
				rmb_press_pos = event.position
				rmb_drag_distance = 0.0
				is_dragging = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				if is_rmb_down:
					is_rmb_down = false
					is_dragging = false
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					if rmb_drag_distance < 5.0:
						if mesh_editor == null and get_parent():
							mesh_editor = get_parent().get_node_or_null("MeshEditorController") as MeshEditor
						if mesh_editor and mesh_editor.has_method("handle_rmb_click"):
							mesh_editor.handle_rmb_click(rmb_press_pos)

		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				is_dragging = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if spring_arm:
				spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if spring_arm:
				spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_distance, max_distance)

	elif event is InputEventMouseMotion and is_dragging:
		if is_rmb_down:
			rmb_drag_distance += event.relative.length()
		yaw_deg -= rad_to_deg(event.relative.x * sensitivity)
		pitch_deg -= rad_to_deg(event.relative.y * sensitivity)
		pitch_deg = clamp(pitch_deg, -85.0, 85.0)
		_update_camera_transform()

	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		focus_target(Vector3(0.0, 1.2, 0.0))

func _update_camera_transform() -> void:
	self.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)

## Smoothly refocuses camera onto specific target point
func focus_target(new_target: Vector3) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", new_target, 0.4)
