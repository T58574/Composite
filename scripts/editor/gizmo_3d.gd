class_name Gizmo3D
extends Node3D

## Interactive 3D Transform Gizmo for Sprocket-style editor.
## Renders solid 3D RGB translation arrows, rotation rings, and scale cubes.
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
@export var rotation_snap_deg: float = 5.0 ## Degrees (5, 15, 45)

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
	red_mat.albedo_color = Color(1.0, 0.2, 0.2)
	red_mat.no_depth_test = true

	green_mat = StandardMaterial3D.new()
	green_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green_mat.albedo_color = Color(0.2, 0.9, 0.2)
	green_mat.no_depth_test = true

	blue_mat = StandardMaterial3D.new()
	blue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue_mat.albedo_color = Color(0.2, 0.5, 1.0)
	blue_mat.no_depth_test = true

	highlight_mat = StandardMaterial3D.new()
	highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_mat.albedo_color = Color(1.0, 0.9, 0.2)
	highlight_mat.no_depth_test = true

func _build_gizmo_visuals() -> void:
	if x_axis_mesh: x_axis_mesh.queue_free()
	if y_axis_mesh: y_axis_mesh.queue_free()
	if z_axis_mesh: z_axis_mesh.queue_free()

	x_axis_mesh = _create_axis_mesh(Vector3.RIGHT, red_mat)
	x_axis_mesh.name = "AxisX"
	add_child(x_axis_mesh)

	y_axis_mesh = _create_axis_mesh(Vector3.UP, green_mat)
	y_axis_mesh.name = "AxisY"
	add_child(y_axis_mesh)

	z_axis_mesh = _create_axis_mesh(Vector3.BACK, blue_mat)
	z_axis_mesh.name = "AxisZ"
	add_child(z_axis_mesh)

## Generates SOLID 3D meshes (Cylinders, Cones, Cubes) for gizmo handles
func _create_axis_mesh(dir: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	match gizmo_mode:
		GizmoMode.TRANSLATE:
			# 3D Solid Cylinder Shaft
			_add_solid_cylinder(st, Vector3.ZERO, dir * 0.8, 0.025)
			# 3D Solid Cone Arrow Tip
			_add_solid_cone(st, dir * 0.8, dir * 1.15, 0.09)

		GizmoMode.ROTATE:
			# 3D Solid Circular Torus Ring perpendicular to dir
			_add_solid_torus_ring(st, dir, 0.9, 0.025)

		GizmoMode.SCALE:
			# 3D Solid Cylinder Shaft
			_add_solid_cylinder(st, Vector3.ZERO, dir * 0.85, 0.025)
			# 3D Solid Box Handle at tip
			_add_solid_box(st, dir * 0.95, Vector3(0.12, 0.12, 0.12))

	st.generate_tangents()
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
				var axis_vec = _get_axis_vector(active_axis)

				if gizmo_mode == GizmoMode.ROTATE:
					drag_start_plane_pos = _get_ray_plane_intersection_perp(camera, event.position, global_position, axis_vec)
				else:
					drag_start_plane_pos = _get_ray_plane_intersection(camera, event.position, global_position, axis_vec)

				_update_axis_materials()
				transform_started.emit()
				return true
		else:
			if is_dragging:
				is_dragging = false
				active_axis = -1
				_update_axis_materials()
				transform_ended.emit()
				return true

	elif event is InputEventMouseMotion:
		if is_dragging and active_axis != -1:
			var axis_vec = _get_axis_vector(active_axis)

			match gizmo_mode:
				GizmoMode.TRANSLATE:
					var current_plane_pos = _get_ray_plane_intersection(camera, event.position, global_position, axis_vec)
					var delta_pos = current_plane_pos - drag_start_plane_pos
					var proj_dist = delta_pos.dot(axis_vec)

					if grid_snap_enabled and grid_snap_step > 0.001:
						proj_dist = snapped(proj_dist, grid_snap_step)

					if abs(proj_dist) > 0.0001:
						var trans_delta = axis_vec * proj_dist
						global_position += trans_delta
						drag_start_plane_pos = current_plane_pos
						transform_changed.emit(trans_delta, Vector3.ZERO, Vector3.ONE)

				GizmoMode.ROTATE:
					var current_plane_pos = _get_ray_plane_intersection_perp(camera, event.position, global_position, axis_vec)
					var v_start = (drag_start_plane_pos - global_position).normalized()
					var v_curr = (current_plane_pos - global_position).normalized()

					if v_start.length() > 0.1 and v_curr.length() > 0.1:
						var raw_angle = v_start.signed_angle_to(v_curr, axis_vec)
						if grid_snap_enabled:
							raw_angle = snapped(raw_angle, deg_to_rad(rotation_snap_deg))

						if abs(raw_angle) > 0.001:
							var rot_delta = axis_vec * raw_angle
							drag_start_plane_pos = current_plane_pos
							transform_changed.emit(Vector3.ZERO, rot_delta, Vector3.ONE)

				GizmoMode.SCALE:
					var current_plane_pos = _get_ray_plane_intersection(camera, event.position, global_position, axis_vec)
					var delta_pos = current_plane_pos - drag_start_plane_pos
					var proj_dist = delta_pos.dot(axis_vec)

					if grid_snap_enabled and grid_snap_step > 0.001:
						proj_dist = snapped(proj_dist, grid_snap_step)

					if abs(proj_dist) > 0.0001:
						var scale_factor = 1.0 + proj_dist * 0.5
						scale_factor = max(scale_factor, 0.1)
						var scale_delta = Vector3.ONE
						match active_axis:
							0: scale_delta.x = scale_factor
							1: scale_delta.y = scale_factor
							2: scale_delta.z = scale_factor
						drag_start_plane_pos = current_plane_pos
						transform_changed.emit(Vector3.ZERO, Vector3.ZERO, scale_delta)

			return true

	return false

func _pick_axis(camera: Camera3D, screen_pos: Vector2) -> int:
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var min_dist = 0.45
	var best_axis = -1

	for i in range(3):
		var axis_start = global_position
		var axis_end = global_position + axes[i] * 1.15
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

func _update_axis_materials() -> void:
	if x_axis_mesh: x_axis_mesh.material_override = highlight_mat if active_axis == 0 else red_mat
	if y_axis_mesh: y_axis_mesh.material_override = highlight_mat if active_axis == 1 else green_mat
	if z_axis_mesh: z_axis_mesh.material_override = highlight_mat if active_axis == 2 else blue_mat

func _get_ray_plane_intersection(camera: Camera3D, screen_pos: Vector2, plane_point: Vector3, axis_vec: Vector3) -> Vector3:
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	var plane_normal = camera.global_transform.basis.z.cross(axis_vec).cross(axis_vec).normalized()
	if plane_normal.length() < 0.01:
		plane_normal = camera.global_transform.basis.z

	var plane = Plane(plane_normal, plane_point.dot(plane_normal))
	var intersect = plane.intersects_ray(ray_origin, ray_dir)
	return intersect if intersect != null else plane_point

func _get_ray_plane_intersection_perp(camera: Camera3D, screen_pos: Vector2, plane_point: Vector3, normal: Vector3) -> Vector3:
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	var plane = Plane(normal, plane_point.dot(normal))
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

# ---------------------------------------------------------
# Solid 3D Procedural Geometry Mesh Generators for Gizmo
# ---------------------------------------------------------
func _add_solid_cylinder(st: SurfaceTool, start: Vector3, end: Vector3, radius: float) -> void:
	var dir = (end - start).normalized()
	var side1 = Vector3(-dir.z, dir.x, dir.y).normalized() * radius
	if side1.length_squared() < 0.0001:
		side1 = Vector3(dir.y, -dir.z, dir.x).normalized() * radius
	var side2 = dir.cross(side1).normalized() * radius

	var segs = 8
	for i in range(segs):
		var a1 = (float(i) / segs) * TAU
		var a2 = (float(i + 1) / segs) * TAU

		var r1 = side1 * cos(a1) + side2 * sin(a1)
		var r2 = side1 * cos(a2) + side2 * sin(a2)

		var p1 = start + r1
		var p2 = start + r2
		var p3 = end + r2
		var p4 = end + r1

		_add_quad_simple(st, p1, p2, p3, p4)

func _add_solid_cone(st: SurfaceTool, base: Vector3, tip: Vector3, radius: float) -> void:
	var dir = (tip - base).normalized()
	var side1 = Vector3(-dir.z, dir.x, dir.y).normalized() * radius
	if side1.length_squared() < 0.0001:
		side1 = Vector3(dir.y, -dir.z, dir.x).normalized() * radius
	var side2 = dir.cross(side1).normalized() * radius

	var segs = 8
	for i in range(segs):
		var a1 = (float(i) / segs) * TAU
		var a2 = (float(i + 1) / segs) * TAU

		var r1 = side1 * cos(a1) + side2 * sin(a1)
		var r2 = side1 * cos(a2) + side2 * sin(a2)

		var p1 = base + r1
		var p2 = base + r2

		var n = (p2 - p1).cross(tip - p1).normalized()
		st.set_normal(n)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p1)
		st.set_normal(n)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p2)
		st.set_normal(n)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(tip)

func _add_solid_torus_ring(st: SurfaceTool, dir: Vector3, radius: float, thickness: float) -> void:
	var u_axis = Vector3(-dir.z, dir.x, dir.y).normalized()
	if u_axis.length_squared() < 0.0001:
		u_axis = Vector3(dir.y, -dir.z, dir.x).normalized()
	var v_axis = dir.cross(u_axis).normalized()

	var segs = 24
	for i in range(segs):
		var a1 = (float(i) / segs) * TAU
		var a2 = (float(i + 1) / segs) * TAU

		var c1 = (u_axis * cos(a1) + v_axis * sin(a1)) * radius
		var c2 = (u_axis * cos(a2) + v_axis * sin(a2)) * radius

		var out1 = c1.normalized() * thickness
		var out2 = c2.normalized() * thickness

		var p1 = c1 - dir * (thickness * 0.5)
		var p2 = c2 - dir * (thickness * 0.5)
		var p3 = c2 + dir * (thickness * 0.5)
		var p4 = c1 + dir * (thickness * 0.5)

		_add_quad_simple(st, p1, p2, p3, p4)

func _add_solid_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h = size * 0.5
	var c0 = center + Vector3(-h.x, -h.y, -h.z)
	var c1 = center + Vector3(h.x, -h.y, -h.z)
	var c2 = center + Vector3(h.x, -h.y, h.z)
	var c3 = center + Vector3(-h.x, -h.y, h.z)
	var c4 = center + Vector3(-h.x, h.y, -h.z)
	var c5 = center + Vector3(h.x, h.y, -h.z)
	var c6 = center + Vector3(h.x, h.y, h.z)
	var c7 = center + Vector3(-h.x, h.y, h.z)

	_add_quad_simple(st, c0, c1, c5, c4)
	_add_quad_simple(st, c3, c7, c6, c2)
	_add_quad_simple(st, c0, c4, c7, c3)
	_add_quad_simple(st, c1, c2, c6, c5)
	_add_quad_simple(st, c4, c5, c6, c7)
	_add_quad_simple(st, c0, c3, c2, c1)

func _add_quad_simple(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n = (b - a).cross(d - a).normalized()
	st.set_normal(n)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)

	st.set_normal(n)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)

	st.set_normal(n)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)

	st.set_normal(n)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)

	st.set_normal(n)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)

	st.set_normal(n)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)
