class_name MeshEditor
extends Node3D

## Freeform Mesh Editing controller (Sprocket-style).
## Handles Vertex (1), Edge (2), Face (3), Corner (4) selection, X-Symmetry, Extrude, and Armor inspection.
## Hotkeys: 1-4 (Modes), G/R/S (Gizmo), E (Extrude), F1-F3 (View), Delete.

enum EditMode { VERTEX = 1, EDGE = 2, FACE = 3, CORNER = 4 }
enum VisualizationMode { SOLID, ARMOR_HEATMAP, XRAY }

signal edit_mode_changed(mode: EditMode)
signal visualization_mode_changed(mode: VisualizationMode)
signal gizmo_mode_changed(mode: Gizmo3D.GizmoMode)
signal face_hovered(thickness_mm: float, angle_deg: float, effective_rha_mm: float)
signal selection_changed()

@export var hull_builder: HullBuilder
@export var turret_builder: TurretBuilder
@export var track_generator: TrackGenerator
@export var camera_3d: Camera3D
@export var gizmo_3d: Gizmo3D

@export var symmetry_x_enabled: bool = true
@export_range(0.01, 2.0, 0.05) var grid_snap_step: float = 0.1 ## Meters (0.05, 0.1, 0.5)

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
var selection_fill_material: StandardMaterial3D
var selection_line_material: StandardMaterial3D

func _ready() -> void:
	if track_generator == null and get_parent():
		track_generator = get_parent().get_node_or_null("ProceduralVehicle/TrackGenerator")
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

	selection_fill_material = StandardMaterial3D.new()
	selection_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_fill_material.albedo_color = Color(1.0, 0.75, 0.1, 0.35) # Golden fill
	selection_fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	selection_fill_material.no_depth_test = true

	selection_line_material = StandardMaterial3D.new()
	selection_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_line_material.vertex_color_use_as_albedo = true
	selection_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_line_material.no_depth_test = true

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
				set_gizmo_mode(Gizmo3D.GizmoMode.TRANSLATE)
			KEY_R:
				set_gizmo_mode(Gizmo3D.GizmoMode.ROTATE)
			KEY_S:
				set_gizmo_mode(Gizmo3D.GizmoMode.SCALE)
			KEY_E:
				if current_edit_mode == EditMode.FACE and selected_face_index != -1:
					extrude_selected_face()
			KEY_F1: set_visualization_mode(VisualizationMode.SOLID)
			KEY_F2: set_visualization_mode(VisualizationMode.ARMOR_HEATMAP)
			KEY_F3: set_visualization_mode(VisualizationMode.XRAY)
			KEY_DELETE, KEY_BACKSPACE:
				_delete_selected_element()

func set_gizmo_mode(mode: Gizmo3D.GizmoMode) -> void:
	if gizmo_3d:
		gizmo_3d.set_gizmo_mode(mode)
	gizmo_mode_changed.emit(mode)

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
	if turret_builder:
		if turret_builder.turret_mesh_instance:
			turret_builder.turret_mesh_instance.material_override = active_mat
		if turret_builder.gun_barrel_mesh_instance:
			turret_builder.gun_barrel_mesh_instance.material_override = active_mat
	if track_generator:
		track_generator.track_material = active_mat
		for child in track_generator.get_children():
			if child is MeshInstance3D:
				child.material_override = active_mat

	visualization_mode_changed.emit(mode)

## Handles RMB click selection and deselection via 3D Raycasting against hull_builder and turret_builder.
func handle_rmb_click(screen_pos: Vector2) -> void:
	_pick_element_at_screen_pos(screen_pos)

func _raycast_targets(ray_origin: Vector3, ray_dir: Vector3) -> Dictionary:
	var targets: Array[MeshInstance3D] = []
	if hull_builder and hull_builder.mesh:
		targets.append(hull_builder)
	if turret_builder:
		if turret_builder.turret_mesh_instance and turret_builder.turret_mesh_instance.mesh:
			targets.append(turret_builder.turret_mesh_instance)
		if turret_builder.gun_barrel_mesh_instance and turret_builder.gun_barrel_mesh_instance.mesh:
			targets.append(turret_builder.gun_barrel_mesh_instance)

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

func _on_gizmo_transform_changed(trans_delta: Vector3, rot_delta: Vector3, scale_delta: Vector3) -> void:
	if selected_target == null:
		return

	var scale_factor = 2.0 if symmetry_x_enabled else 1.0

	if gizmo_3d and gizmo_3d.gizmo_mode == Gizmo3D.GizmoMode.SCALE:
		var sx = (scale_delta.x - 1.0) * scale_factor
		var sy = (scale_delta.y - 1.0) * 1.5
		var sz = (scale_delta.z - 1.0) * 1.5
		if selected_target == hull_builder:
			hull_builder.length = clamp(hull_builder.length + sz, 2.0, 10.0)
			hull_builder.width = clamp(hull_builder.width + sx, 1.5, 5.0)
			hull_builder.height = clamp(hull_builder.height + sy, 0.5, 2.5)
			hull_builder.generate_hull_mesh()
		elif turret_builder and selected_target == turret_builder.turret_mesh_instance:
			turret_builder.turret_length = clamp(turret_builder.turret_length + sz, 1.5, 4.5)
			turret_builder.turret_width = clamp(turret_builder.turret_width + sx, 1.5, 4.5)
			turret_builder.turret_height = clamp(turret_builder.turret_height + sy, 0.6, 2.0)
			turret_builder.generate_turret_and_gun()

	elif gizmo_3d and gizmo_3d.gizmo_mode == Gizmo3D.GizmoMode.ROTATE:
		var rot_amount_deg = rad_to_deg(rot_delta.x + rot_delta.y + rot_delta.z)
		if selected_target == hull_builder:
			hull_builder.front_glacis_angle_deg = clamp(hull_builder.front_glacis_angle_deg + rot_amount_deg * 0.5, 10.0, 80.0)
			hull_builder.generate_hull_mesh()
		elif turret_builder and selected_target == turret_builder.turret_mesh_instance:
			turret_builder.cheek_angle_deg = clamp(turret_builder.cheek_angle_deg + rot_amount_deg * 0.5, 15.0, 75.0)
			turret_builder.generate_turret_and_gun()

	else:
		# GizmoMode.TRANSLATE or default
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

func flip_selected_normals() -> void:
	if selected_target == null or selected_face_index < 0:
		return
	var mesh = selected_target.mesh as ArrayMesh
	if mesh and mesh.get_surface_count() > 0:
		var mdt = MeshDataTool.new()
		var err = mdt.create_from_surface(mesh, 0)
		if err == OK and selected_face_index < mdt.get_face_count():
			var v0 = mdt.get_face_vertex(selected_face_index, 0)
			var v1 = mdt.get_face_vertex(selected_face_index, 1)
			var v2 = mdt.get_face_vertex(selected_face_index, 2)
			mdt.set_face_vertex(selected_face_index, 1, v2)
			mdt.set_face_vertex(selected_face_index, 2, v1)

			var n0 = mdt.get_vertex_normal(v0)
			var n1 = mdt.get_vertex_normal(v1)
			var n2 = mdt.get_vertex_normal(v2)
			mdt.set_vertex_normal(v0, -n0)
			mdt.set_vertex_normal(v1, -n1)
			mdt.set_vertex_normal(v2, -n2)

			mesh.clear_surfaces()
			mdt.commit_to_surface(mesh)
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

	var arr_mesh = ArrayMesh.new()

	# 1. Semi-transparent golden fill overlay quad (Color(1.0, 0.75, 0.1, 0.35)) when in EditMode.FACE
	if current_edit_mode == EditMode.FACE and selected_positions.size() >= 3:
		var st_fill = SurfaceTool.new()
		st_fill.begin(Mesh.PRIMITIVE_TRIANGLES)
		st_fill.set_color(Color(1.0, 0.75, 0.1, 0.35))

		var p0 = selected_positions[0]
		var p1 = selected_positions[1]
		var p2 = selected_positions[2]

		# Front face triangle
		st_fill.set_uv(Vector2(0, 0))
		st_fill.add_vertex(p0)
		st_fill.set_uv(Vector2(1, 0))
		st_fill.add_vertex(p1)
		st_fill.set_uv(Vector2(0.5, 1))
		st_fill.add_vertex(p2)

		# Back face triangle
		st_fill.set_uv(Vector2(0, 0))
		st_fill.add_vertex(p0)
		st_fill.set_uv(Vector2(0.5, 1))
		st_fill.add_vertex(p2)
		st_fill.set_uv(Vector2(1, 0))
		st_fill.add_vertex(p1)

		if selected_positions.size() >= 4:
			var p3 = selected_positions[3]
			st_fill.set_uv(Vector2(0, 0))
			st_fill.add_vertex(p0)
			st_fill.set_uv(Vector2(1, 0))
			st_fill.add_vertex(p2)
			st_fill.set_uv(Vector2(0.5, 1))
			st_fill.add_vertex(p3)

			st_fill.set_uv(Vector2(0, 0))
			st_fill.add_vertex(p0)
			st_fill.set_uv(Vector2(0.5, 1))
			st_fill.add_vertex(p3)
			st_fill.set_uv(Vector2(1, 0))
			st_fill.add_vertex(p2)

		if symmetry_x_enabled:
			var s0 = _symmetry_x(p0)
			var s1 = _symmetry_x(p1)
			var s2 = _symmetry_x(p2)
			st_fill.set_uv(Vector2(0, 0))
			st_fill.add_vertex(s0)
			st_fill.set_uv(Vector2(1, 0))
			st_fill.add_vertex(s1)
			st_fill.set_uv(Vector2(0.5, 1))
			st_fill.add_vertex(s2)

			st_fill.set_uv(Vector2(0, 0))
			st_fill.add_vertex(s0)
			st_fill.set_uv(Vector2(0.5, 1))
			st_fill.add_vertex(s2)
			st_fill.set_uv(Vector2(1, 0))
			st_fill.add_vertex(s1)

		st_fill.generate_normals()
		st_fill.generate_tangents()
		arr_mesh = st_fill.commit(arr_mesh)
		arr_mesh.surface_set_material(arr_mesh.get_surface_count() - 1, selection_fill_material)

	# 2. Line Overlay Surface: Contours (Bright Orange/Yellow), Red Vertex Cubes, Cyan Diamond Anchor
	var st_lines = SurfaceTool.new()
	st_lines.begin(Mesh.PRIMITIVE_LINES)

	# Bright orange/yellow outline contours (Color(1.0, 0.85, 0.1))
	var contour_color = Color(1.0, 0.85, 0.1)
	st_lines.set_color(contour_color)

	match current_edit_mode:
		EditMode.FACE:
			if selected_positions.size() >= 3:
				var p0 = selected_positions[0]
				var p1 = selected_positions[1]
				var p2 = selected_positions[2]
				_add_line(st_lines, p0, p1)
				_add_line(st_lines, p1, p2)
				_add_line(st_lines, p2, p0)
				if selected_positions.size() >= 4:
					_add_line(st_lines, p2, selected_positions[3])
					_add_line(st_lines, selected_positions[3], p0)
		EditMode.EDGE:
			if selected_positions.size() >= 2:
				_add_line(st_lines, selected_positions[0], selected_positions[1])
		EditMode.VERTEX, EditMode.CORNER:
			pass

	if symmetry_x_enabled:
		st_lines.set_color(contour_color)
		match current_edit_mode:
			EditMode.FACE:
				if selected_positions.size() >= 3:
					var s0 = _symmetry_x(selected_positions[0])
					var s1 = _symmetry_x(selected_positions[1])
					var s2 = _symmetry_x(selected_positions[2])
					_add_line(st_lines, s0, s1)
					_add_line(st_lines, s1, s2)
					_add_line(st_lines, s2, s0)
					if selected_positions.size() >= 4:
						var s3 = _symmetry_x(selected_positions[3])
						_add_line(st_lines, s2, s3)
						_add_line(st_lines, s3, s0)
			EditMode.EDGE:
				if selected_positions.size() >= 2:
					_add_line(st_lines, _symmetry_x(selected_positions[0]), _symmetry_x(selected_positions[1]))
			EditMode.VERTEX, EditMode.CORNER:
				pass

	# Red 3D vertex handle cubes (Color(1.0, 0.2, 0.2)) at corner vertices
	var vertex_color = Color(1.0, 0.2, 0.2)
	for pos in selected_positions:
		_add_box(st_lines, pos, 0.08, vertex_color)
		if symmetry_x_enabled:
			_add_box(st_lines, _symmetry_x(pos), 0.08, vertex_color)

	# Cyan wireframe diamond anchor (Color(0.2, 0.8, 1.0)) at selected face/node center
	var center = Vector3.ZERO
	for pos in selected_positions:
		center += pos
	center /= float(selected_positions.size())

	var diamond_color = Color(0.2, 0.8, 1.0)
	_add_diamond(st_lines, center, 0.16, diamond_color)
	if symmetry_x_enabled:
		_add_diamond(st_lines, _symmetry_x(center), 0.16, diamond_color)

	arr_mesh = st_lines.commit(arr_mesh)
	arr_mesh.surface_set_material(arr_mesh.get_surface_count() - 1, selection_line_material)

	selection_overlay_mesh.mesh = arr_mesh

func _symmetry_x(pos: Vector3) -> Vector3:
	return Vector3(-pos.x, pos.y, pos.z)

func _add_line(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(b)

func _add_box(st: SurfaceTool, center: Vector3, size: float, color: Color) -> void:
	st.set_color(color)
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

func _add_diamond(st: SurfaceTool, center: Vector3, size: float, color: Color) -> void:
	st.set_color(color)
	var h = size * 0.5
	var top = center + Vector3(0, h, 0)
	var bot = center + Vector3(0, -h, 0)
	var e0 = center + Vector3(h, 0, 0)
	var e1 = center + Vector3(0, 0, h)
	var e2 = center + Vector3(-h, 0, 0)
	var e3 = center + Vector3(0, 0, -h)

	# Top pyramid
	_add_line(st, top, e0)
	_add_line(st, top, e1)
	_add_line(st, top, e2)
	_add_line(st, top, e3)

	# Bottom pyramid
	_add_line(st, bot, e0)
	_add_line(st, bot, e1)
	_add_line(st, bot, e2)
	_add_line(st, bot, e3)

	# Equator ring
	_add_line(st, e0, e1)
	_add_line(st, e1, e2)
	_add_line(st, e2, e3)
	_add_line(st, e3, e0)

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
		if local_norm.x > 0.4:
			thickness = hull_builder.front_armor_mm
		elif abs(local_norm.z) > 0.4:
			thickness = hull_builder.side_armor_mm
		elif local_norm.x < -0.4:
			thickness = hull_builder.rear_armor_mm
		else:
			thickness = hull_builder.front_armor_mm
	elif turret_builder and target == turret_builder.turret_mesh_instance:
		thickness = turret_builder.front_turret_armor_mm

	var eff_rha = ArmorCalculator.calculate_effective_thickness(thickness, normal, ray_dir)
	face_hovered.emit(thickness, angle_deg, eff_rha)
