class_name MeshEditor
extends Node3D

## Freeform Mesh Editing controller (Sprocket-style).
## Handles Vertex (1), Edge (2), Face (3), Corner (4) selection, X-Symmetry, Extrude, and Armor inspection.
## Hotkeys: 1-4 (Modes), G/R/S (Gizmo), E (Extrude), F1-F3 (View), Delete.

enum EditMode { VERTEX = 1, EDGE = 2, FACE = 3, CORNER = 4 }
enum VisualizationMode { SOLID, ARMOR_HEATMAP, XRAY }

signal edit_mode_changed(mode: EditMode)
signal visualization_mode_changed(mode: VisualizationMode)
signal face_hovered(thickness_mm: float, angle_deg: float, effective_rha_mm: float)
signal selection_changed()

@export var hull_builder: HullBuilder
@export var turret_builder: TurretBuilder
@export var camera_3d: Camera3D
@export var gizmo_3d: Gizmo3D

@export var symmetry_x_enabled: bool = true
@export var grid_snap_step: float = 0.1 ## Meters (0.05, 0.1, 0.5)

var current_edit_mode: EditMode = EditMode.VERTEX
var current_vis_mode: VisualizationMode = VisualizationMode.SOLID

# Selection state
var selected_target: MeshInstance3D = null
var selected_face_index: int = -1
var selected_vertex_indices: Array[int] = []
var selected_positions: Array[Vector3] = []
var hovered_face_index: int = -1

# Materials for visualization modes
@export var pbr_material: Material
@export var heatmap_material: ShaderMaterial
@export var xray_material: ShaderMaterial

# Visual Selection Overlays
var selection_overlay_mesh: MeshInstance3D
var selection_material: StandardMaterial3D

func _ready() -> void:
	_setup_selection_overlay()
	set_edit_mode(EditMode.VERTEX)
	set_visualization_mode(VisualizationMode.SOLID)

	if gizmo_3d:
		gizmo_3d.transform_changed.connect(_on_gizmo_transform_changed)

func _setup_selection_overlay() -> void:
	if selection_overlay_mesh == null:
		selection_overlay_mesh = MeshInstance3D.new()
		selection_overlay_mesh.name = "SelectionOverlay"
		add_child(selection_overlay_mesh)

	selection_material = StandardMaterial3D.new()
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_material.albedo_color = Color(1.0, 0.6, 0.1, 1.0) # Orange primary selection
	selection_material.no_depth_test = true

func _unhandled_input(event: InputEvent) -> void:
	if gizmo_3d and gizmo_3d.process_input_event(camera_3d, event):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pick_element_at_screen_pos(event.position)

	elif event is InputEventMouseMotion:
		inspect_hover_point(event.position)

	elif event is InputEventKey and event.pressed:
		# Ignore hotkeys if user is typing in a text field
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			return

		match event.keycode:
			KEY_1: set_edit_mode(EditMode.VERTEX)
			KEY_2: set_edit_mode(EditMode.EDGE)
			KEY_3: set_edit_mode(EditMode.FACE)
			KEY_4: set_edit_mode(EditMode.CORNER)
			KEY_G:
				if gizmo_3d: gizmo_3d.set_gizmo_mode(Gizmo3D.GizmoMode.TRANSLATE)
			KEY_R:
				if gizmo_3d: gizmo_3d.set_gizmo_mode(Gizmo3D.GizmoMode.ROTATE)
			KEY_S:
				if gizmo_3d: gizmo_3d.set_gizmo_mode(Gizmo3D.GizmoMode.SCALE)
			KEY_E:
				if current_edit_mode == EditMode.FACE and selected_face_index != -1:
					extrude_selected_face()
			KEY_F1: set_visualization_mode(VisualizationMode.SOLID)
			KEY_F2: set_visualization_mode(VisualizationMode.ARMOR_HEATMAP)
			KEY_F3: set_visualization_mode(VisualizationMode.XRAY)
			KEY_DELETE, KEY_BACKSPACE:
				_delete_selected_element()

func set_edit_mode(mode: EditMode) -> void:
	current_edit_mode = mode
	edit_mode_changed.emit(mode)
	_update_selection_visuals()

func set_visualization_mode(mode: VisualizationMode) -> void:
	current_vis_mode = mode

	var active_mat: Material = pbr_material
	match mode:
		VisualizationMode.SOLID:
			active_mat = pbr_material
		VisualizationMode.ARMOR_HEATMAP:
			active_mat = heatmap_material
		VisualizationMode.XRAY:
			active_mat = xray_material

	if hull_builder:
		hull_builder.material_override = active_mat
	if turret_builder and turret_builder.turret_mesh_instance:
		turret_builder.turret_mesh_instance.material_override = active_mat

	visualization_mode_changed.emit(mode)

func _raycast_targets(ray_origin: Vector3, ray_dir: Vector3) -> Dictionary:
	var targets: Array[MeshInstance3D] = []
	if hull_builder and hull_builder.mesh:
		targets.append(hull_builder)
	if turret_builder and turret_builder.turret_mesh_instance and turret_builder.turret_mesh_instance.mesh:
		targets.append(turret_builder.turret_mesh_instance)

	var closest_dist = 1e9
	var best_hit = {}

	for target in targets:
		var mesh = target.mesh
		if mesh == null:
			continue

		var faces = mesh.get_faces()
		var gt = target.global_transform
		var tri_count = faces.size() / 3

		for i in range(tri_count):
			var v0 = gt * faces[i * 3]
			var v1 = gt * faces[i * 3 + 1]
			var v2 = gt * faces[i * 3 + 2]

			var hit = Geometry3D.ray_intersects_triangle(ray_origin, ray_dir, v0, v1, v2)
			if hit != null:
				var dist = ray_origin.distance_to(hit)
				if dist < closest_dist:
					closest_dist = dist
					best_hit = {
						"target": target,
						"face_index": i,
						"face_verts": [faces[i * 3], faces[i * 3 + 1], faces[i * 3 + 2]],
						"hit_pos": hit,
						"dist": dist
					}

	return best_hit

func _pick_element_at_screen_pos(screen_pos: Vector2) -> void:
	if camera_3d == null:
		return

	var ray_origin = camera_3d.project_ray_origin(screen_pos)
	var ray_dir = camera_3d.project_ray_normal(screen_pos)

	var best_hit = _raycast_targets(ray_origin, ray_dir)

	if best_hit.is_empty():
		_clear_selection()
		return

	selected_target = best_hit["target"]
	selected_face_index = best_hit["face_index"]
	var face_verts: Array[Vector3] = best_hit["face_verts"]
	var hit_pos_global: Vector3 = best_hit["hit_pos"]
	var target_gt = selected_target.global_transform

	selected_vertex_indices.clear()
	selected_positions.clear()

	var gizmo_pos = hit_pos_global

	match current_edit_mode:
		EditMode.FACE:
			var tri_offset = selected_face_index * 3
			selected_vertex_indices = [tri_offset, tri_offset + 1, tri_offset + 2]
			selected_positions = [target_gt * face_verts[0], target_gt * face_verts[1], target_gt * face_verts[2]]
			gizmo_pos = (selected_positions[0] + selected_positions[1] + selected_positions[2]) / 3.0

		EditMode.VERTEX, EditMode.CORNER:
			var best_idx = 0
			var best_dist = 1e9
			for i in range(3):
				var g_v = target_gt * face_verts[i]
				var d = g_v.distance_to(hit_pos_global)
				if d < best_dist:
					best_dist = d
					best_idx = i
			var vert_idx = selected_face_index * 3 + best_idx
			selected_vertex_indices = [vert_idx]
			selected_positions = [target_gt * face_verts[best_idx]]
			gizmo_pos = selected_positions[0]

		EditMode.EDGE:
			var edges = [[0, 1], [1, 2], [2, 0]]
			var best_edge = edges[0]
			var best_dist = 1e9
			for e in edges:
				var g_a = target_gt * face_verts[e[0]]
				var g_b = target_gt * face_verts[e[1]]
				var mid = (g_a + g_b) * 0.5
				var d = mid.distance_to(hit_pos_global)
				if d < best_dist:
					best_dist = d
					best_edge = e
			var tri_offset = selected_face_index * 3
			selected_vertex_indices = [tri_offset + best_edge[0], tri_offset + best_edge[1]]
			selected_positions = [target_gt * face_verts[best_edge[0]], target_gt * face_verts[best_edge[1]]]
			gizmo_pos = (selected_positions[0] + selected_positions[1]) * 0.5

	selection_changed.emit()

	if gizmo_3d:
		gizmo_3d.attach_to_position(gizmo_pos)

	_update_selection_visuals()

func _clear_selection() -> void:
	selected_target = null
	selected_face_index = -1
	selected_vertex_indices.clear()
	selected_positions.clear()
	if gizmo_3d:
		gizmo_3d.detach()
	_update_selection_visuals()
	selection_changed.emit()

func _on_gizmo_transform_changed(trans_delta: Vector3, _rot_delta: Vector3, _scale_delta: Vector3) -> void:
	if selected_target == null:
		return

	var scale_factor = 2.0 if symmetry_x_enabled else 1.0

	if selected_target == hull_builder:
		hull_builder.length = clamp(hull_builder.length + trans_delta.z * 1.5, 2.0, 10.0)
		hull_builder.width = clamp(hull_builder.width + trans_delta.x * scale_factor, 1.5, 5.0)
		hull_builder.height = clamp(hull_builder.height + trans_delta.y * 1.5, 0.5, 2.5)
		hull_builder.generate_hull_mesh()

	elif turret_builder and selected_target == turret_builder.turret_mesh_instance:
		turret_builder.turret_length = clamp(turret_builder.turret_length + trans_delta.z * 1.5, 1.5, 4.5)
		turret_builder.turret_width = clamp(turret_builder.turret_width + trans_delta.x * scale_factor, 1.5, 4.5)
		turret_builder.turret_height = clamp(turret_builder.turret_height + trans_delta.y * 1.5, 0.6, 2.0)
		turret_builder.generate_turret_and_gun()

	_reposition_gizmo_and_selection()
	_update_selection_visuals()
	selection_changed.emit()

func _reposition_gizmo_and_selection() -> void:
	if selected_target == null or selected_face_index == -1:
		return

	var mesh = selected_target.mesh
	if mesh == null:
		return

	var faces = mesh.get_faces()
	if faces.is_empty():
		return

	var tri_count = faces.size() / 3
	var face_idx = clamp(selected_face_index, 0, tri_count - 1)
	var gt = selected_target.global_transform
	var tri_offset = face_idx * 3
	var f0 = gt * faces[tri_offset]
	var f1 = gt * faces[tri_offset + 1]
	var f2 = gt * faces[tri_offset + 2]

	match current_edit_mode:
		EditMode.FACE:
			selected_positions = [f0, f1, f2]
			if gizmo_3d:
				gizmo_3d.global_position = (f0 + f1 + f2) / 3.0
		EditMode.VERTEX, EditMode.CORNER:
			selected_positions = [f0]
			if gizmo_3d:
				gizmo_3d.global_position = f0
		EditMode.EDGE:
			selected_positions = [f0, f1]
			if gizmo_3d:
				gizmo_3d.global_position = (f0 + f1) * 0.5

func extrude_selected_face() -> void:
	if selected_target == hull_builder:
		hull_builder.length = clamp(hull_builder.length + 0.4, 2.0, 10.0)
		hull_builder.generate_hull_mesh()
	elif turret_builder and selected_target == turret_builder.turret_mesh_instance:
		turret_builder.turret_length = clamp(turret_builder.turret_length + 0.4, 1.5, 4.5)
		turret_builder.generate_turret_and_gun()
	_reposition_gizmo_and_selection()
	_update_selection_visuals()
	selection_changed.emit()

func _delete_selected_element() -> void:
	_clear_selection()

func _update_selection_visuals() -> void:
	if selection_overlay_mesh == null:
		return

	if selected_target == null or selected_positions.is_empty():
		selection_overlay_mesh.mesh = null
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(Color(1.0, 0.6, 0.1)) # Primary selection (Orange)

	match current_edit_mode:
		EditMode.FACE:
			if selected_positions.size() >= 3:
				var p0 = selected_positions[0]
				var p1 = selected_positions[1]
				var p2 = selected_positions[2]
				_add_line(st, p0, p1)
				_add_line(st, p1, p2)
				_add_line(st, p2, p0)
		EditMode.EDGE:
			if selected_positions.size() >= 2:
				_add_line(st, selected_positions[0], selected_positions[1])
		EditMode.VERTEX, EditMode.CORNER:
			if selected_positions.size() >= 1:
				_add_box(st, selected_positions[0], 0.08)

	if symmetry_x_enabled:
		st.set_color(Color(0.2, 0.8, 1.0)) # X-Symmetry selection (Cyan)
		match current_edit_mode:
			EditMode.FACE:
				if selected_positions.size() >= 3:
					var s0 = _symmetry_x(selected_positions[0])
					var s1 = _symmetry_x(selected_positions[1])
					var s2 = _symmetry_x(selected_positions[2])
					_add_line(st, s0, s1)
					_add_line(st, s1, s2)
					_add_line(st, s2, s0)
			EditMode.EDGE:
				if selected_positions.size() >= 2:
					_add_line(st, _symmetry_x(selected_positions[0]), _symmetry_x(selected_positions[1]))
			EditMode.VERTEX, EditMode.CORNER:
				if selected_positions.size() >= 1:
					_add_box(st, _symmetry_x(selected_positions[0]), 0.08)

	selection_overlay_mesh.mesh = st.commit()
	selection_overlay_mesh.material_override = selection_material

func _symmetry_x(pos: Vector3) -> Vector3:
	return Vector3(-pos.x, pos.y, pos.z)

func _add_line(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)

func _add_box(st: SurfaceTool, center: Vector3, size: float) -> void:
	var h = size * 0.5
	var c = [
		center + Vector3(-h, -h, -h), center + Vector3(h, -h, -h),
		center + Vector3(h, -h, h), center + Vector3(-h, -h, h),
		center + Vector3(-h, h, -h), center + Vector3(h, h, -h),
		center + Vector3(h, h, h), center + Vector3(-h, h, h)
	]
	for i in range(4):
		_add_line(st, c[i], c[(i + 1) % 4])
		_add_line(st, c[4 + i], c[4 + (i + 1) % 4])
		_add_line(st, c[i], c[4 + i])

func inspect_hover_point(screen_pos: Vector2) -> void:
	if camera_3d == null:
		return

	var ray_origin = camera_3d.project_ray_origin(screen_pos)
	var ray_dir = camera_3d.project_ray_normal(screen_pos)

	var hit_data = _raycast_targets(ray_origin, ray_dir)
	if hit_data.is_empty():
		return

	var target = hit_data["target"]
	var face_verts: Array[Vector3] = hit_data["face_verts"]
	var gt = target.global_transform

	var v0 = gt * face_verts[0]
	var v1 = gt * face_verts[1]
	var v2 = gt * face_verts[2]

	var normal = (v1 - v0).cross(v2 - v0).normalized()
	if normal.dot(-ray_dir) < 0:
		normal = -normal

	var cos_theta = clamp(abs(normal.dot(-ray_dir)), 0.0, 1.0)
	var angle_deg = rad_to_deg(acos(cos_theta))

	var thickness = 450.0
	if target == hull_builder:
		var local_norm = target.global_transform.basis.inverse() * normal
		if local_norm.z > 0.4:
			thickness = hull_builder.front_armor_mm
		elif abs(local_norm.x) > 0.4:
			thickness = hull_builder.side_armor_mm
		elif local_norm.z < -0.4:
			thickness = hull_builder.rear_armor_mm
		else:
			thickness = hull_builder.front_armor_mm
	elif turret_builder and target == turret_builder.turret_mesh_instance:
		thickness = turret_builder.front_turret_armor_mm

	var eff_rha = ArmorCalculator.calculate_effective_thickness(thickness, normal, ray_dir)
	face_hovered.emit(thickness, angle_deg, eff_rha)

