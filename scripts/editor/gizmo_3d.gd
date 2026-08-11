class_name Gizmo3D
extends Node3D

## Interactive 3D Transform Gizmo for Sprocket-style editor.
## Renders RGB translation arrows, rotation rings, and scale cubes.
## Supports hotkeys G (Move), R (Rotate), S (Scale).

enum GizmoMode { TRANSLATE, ROTATE, SCALE }
enum TransformSpace { LOCAL, GLOBAL }

signal transform_started()
signal transform_changed(translation_delta: Vector3, rotation_delta: Vector3, scale_delta: Vector3)
signal transform_ended()

@export var gizmo_mode: GizmoMode = GizmoMode.TRANSLATE
@export var transform_space: TransformSpace = TransformSpace.LOCAL
@export var grid_snap_enabled: bool = true
@export var grid_snap_step: float = 0.1 ## Grid size in meters (0.05, 0.1, 0.5)

var active_axis: int = -1 # -1: None, 0: X (Red), 1: Y (Green), 2: Z (Blue)
var is_dragging: bool = false
var drag_start_plane_pos: Vector3 = Vector3.ZERO
var initial_gizmo_pos: Vector3 = Vector3.ZERO

# Mesh instances for gizmo visual handles
var x_axis_mesh: MeshInstance3D
var y_axis_mesh: MeshInstance3D
var z_axis_mesh: MeshInstance3D

var red_mat: StandardMaterial3D
var green_mat: StandardMaterial3D
var blue_mat: StandardMaterial3D
var highlight_mat: StandardMaterial3D

func _ready() -> void:
	_setup_materials()
	_build_gizmo_visuals()
	hide()

func set_gizmo_mode(mode: GizmoMode) -> void:
	gizmo_mode = mode
	_build_gizmo_visuals()

func _setup_materials() -> void:
	red_mat = StandardMaterial3D.new()
	red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red_mat.albedo_color = Color(1.0, 0.25, 0.25)
	red_mat.no_depth_test = true

	green_mat = StandardMaterial3D.new()
	green_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green_mat.albedo_color = Color(0.25, 0.9, 0.25)
	green_mat.no_depth_test = true

	blue_mat = StandardMaterial3D.new()
	blue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue_mat.albedo_color = Color(0.25, 0.45, 1.0)
	blue_mat.no_depth_test = true

	highlight_mat = StandardMaterial3D.new()
	highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_mat.albedo_color = Color(1.0, 0.9, 0.2)
	highlight_mat.no_depth_test = true

func _build_gizmo_visuals() -> void:
	if x_axis_mesh: x_axis_mesh.queue_free()
	if y_axis_mesh: y_axis_mesh.queue_free()
	if z_axis_mesh: z_axis_mesh.queue_free()

	# X Axis (Red)
	x_axis_mesh = _create_axis_mesh(Vector3(1, 0, 0), red_mat)
	x_axis_mesh.name = "AxisX"
	add_child(x_axis_mesh)

	# Y Axis (Green)
	y_axis_mesh = _create_axis_mesh(Vector3(0, 1, 0), green_mat)
	y_axis_mesh.name = "AxisY"
	add_child(y_axis_mesh)

	# Z Axis (Blue)
	z_axis_mesh = _create_axis_mesh(Vector3(0, 0, 1), blue_mat)
	z_axis_mesh.name = "AxisZ"
	add_child(z_axis_mesh)

func _create_axis_mesh(dir: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(Color.WHITE)

	st.add_vertex(Vector3.ZERO)
	st.add_vertex(dir * 1.0)

	var tip = dir * 1.0
	var side1 = Vector3(-dir.z, dir.x, dir.y) * 0.15
	var side2 = Vector3(dir.y, -dir.z, dir.x) * 0.15

	if gizmo_mode == GizmoMode.ROTATE:
		# Draw arc ring segment
		var radius = 0.8
		var segs = 16
		for i in range(segs):
			var a1 = (float(i) / segs) * (PI * 0.5)
			var a2 = (float(i + 1) / segs) * (PI * 0.5)
			var v1 = (side1 * cos(a1) + side2 * sin(a1)).normalized() * radius
			var v2 = (side1 * cos(a2) + side2 * sin(a2)).normalized() * radius
			st.add_vertex(v1)
			st.add_vertex(v2)
	else:
		# Arrow tip or Cube tip
		st.add_vertex(tip)
		st.add_vertex(tip - dir * 0.2 + side1)
		st.add_vertex(tip)
		st.add_vertex(tip - dir * 0.2 - side1)

	mi.mesh = st.commit()
	mi.material_override = mat
	return mi

func attach_to_position(pos: Vector3) -> void:
	global_position = pos
	show()

func detach() -> void:
	hide()
	is_dragging = false
	active_axis = -1

func process_input_event(camera: Camera3D, event: InputEvent) -> bool:
	if not visible or camera == null:
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit_axis = _pick_axis(camera, event.position)
			if hit_axis != -1:
				active_axis = hit_axis
				is_dragging = true
				initial_gizmo_pos = global_position
				drag_start_plane_pos = _get_ray_plane_intersection(camera, event.position, global_position, _get_axis_vector(active_axis))
				transform_started.emit()
				return true
		else:
			if is_dragging:
				is_dragging = false
				active_axis = -1
				transform_ended.emit()
				return true

	elif event is InputEventMouseMotion and is_dragging:
		var current_plane_pos = _get_ray_plane_intersection(camera, event.position, global_position, _get_axis_vector(active_axis))
		var delta_pos = current_plane_pos - drag_start_plane_pos

		var axis_vec = _get_axis_vector(active_axis)
		var proj_dist = delta_pos.dot(axis_vec)

		if grid_snap_enabled and grid_snap_step > 0.001:
			proj_dist = snapped(proj_dist, grid_snap_step)

		var constrained_delta = axis_vec * proj_dist

		if constrained_delta.length() > 0.0001:
			global_position = initial_gizmo_pos + constrained_delta
			transform_changed.emit(constrained_delta, Vector3.ZERO, Vector3.ONE)

		return true

	return false

func _pick_axis(camera: Camera3D, screen_pos: Vector2) -> int:
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	var axes = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	var min_dist = 0.35
	var best_axis = -1

	for i in range(3):
		var axis_start = global_position
		var axis_end = global_position + axes[i] * 1.0
		var dist = _ray_to_segment_distance(ray_origin, ray_dir, axis_start, axis_end)
		if dist < min_dist:
			min_dist = dist
			best_axis = i

	return best_axis

func _get_axis_vector(axis_idx: int) -> Vector3:
	match axis_idx:
		0: return Vector3.RIGHT
		1: return Vector3.UP
		2: return Vector3.BACK
		_: return Vector3.ZERO

func _get_ray_plane_intersection(camera: Camera3D, screen_pos: Vector2, plane_point: Vector3, axis_vec: Vector3) -> Vector3:
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	var plane_normal = camera.global_transform.basis.z.cross(axis_vec).cross(axis_vec).normalized()
	if plane_normal.length() < 0.01:
		plane_normal = camera.global_transform.basis.z

	var plane = Plane(plane_normal, plane_point.dot(plane_normal))
	var intersect = plane.intersects_ray(ray_origin, ray_dir)
	return intersect if intersect != null else plane_point

func _ray_to_segment_distance(ray_o: Vector3, ray_d: Vector3, seg_a: Vector3, seg_b: Vector3) -> float:
	var u = ray_d
	var v = seg_b - seg_a
	var w = ray_o - seg_a
	var a = u.dot(u)
	var b = u.dot(v)
	var c = v.dot(v)
	var d = u.dot(w)
	var e = v.dot(w)
	var denom = a * c - b * b
	if abs(denom) < 1e-5:
		return 100.0
	var sc = (b * e - c * d) / denom
	var tc = (a * e - b * d) / denom
	var closest_ray = ray_o + u * max(sc, 0.0)
	var closest_seg = seg_a + v * clamp(tc, 0.0, 1.0)
	return closest_ray.distance_to(closest_seg)
