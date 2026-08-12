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
signal face_hovered(thickness_mm: float, angle_deg: float, eff_ke_mm: float, eff_heat_mm: float)
signal selection_changed()

@export var hull_builder: HullBuilder
@export var turret_builder: TurretBuilder
@export var track_generator: TrackGenerator
@export var camera_3d: Camera3D
@export var gizmo_3d: Gizmo3D
@export var bounding_box_overlay: BoundingBoxOverlay

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

# UndoRedo & Optimization Caching
var undo_redo: UndoRedo = UndoRedo.new()
var cached_colocated_vertex_indices: Array[int] = []
var cached_symmetric_vertex_indices: Array[int] = []

var _drag_start_target: MeshInstance3D = null
var _drag_start_mesh_arrays: Array = []
var _drag_start_selected_positions: Array[Vector3] = []

# Materials for visualization modes
@export var pbr_material: Material
@export var heatmap_material: ShaderMaterial
@export var xray_material: ShaderMaterial

# Visual Selection Overlays
var selection_overlay_mesh: MeshInstance3D
var selection_material: StandardMaterial3D

func _ready() -> void:
	if track_generator == null and get_parent():
		track_generator = get_parent().get_node_or_null("ProceduralVehicle/TrackGenerator")
	_setup_selection_overlay()
	set_edit_mode(EditMode.VERTEX)
	set_visualization_mode(VisualizationMode.SOLID)

	if gizmo_3d:
		if not gizmo_3d.transform_changed.is_connected(_on_gizmo_transform_changed):
			gizmo_3d.transform_changed.connect(_on_gizmo_transform_changed)
		if not gizmo_3d.transform_started.is_connected(_on_gizmo_transform_started):
			gizmo_3d.transform_started.connect(_on_gizmo_transform_started)
		if not gizmo_3d.transform_ended.is_connected(_on_gizmo_transform_ended):
			gizmo_3d.transform_ended.connect(_on_gizmo_transform_ended)

func _setup_selection_overlay() -> void:
	if selection_overlay_mesh == null:
		selection_overlay_mesh = MeshInstance3D.new()
		selection_overlay_mesh.name = "SelectionOverlay"
		add_child(selection_overlay_mesh)

	selection_material = StandardMaterial3D.new()
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_material.vertex_color_use_as_albedo = true
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	selection_material.no_depth_test = true
	selection_overlay_mesh.material_override = selection_material

func _unhandled_input(event: InputEvent) -> void:
	if gizmo_3d and gizmo_3d.process_input_event(camera_3d, event):
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_element_at_screen_pos(event.position)

	if event is InputEventMouseMotion:
		inspect_hover_point(event.position)

	elif event is InputEventKey and event.pressed:
		# Ignore hotkeys if user is typing in a text field
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			return

		if event.is_command_or_control_pressed():
			if event.keycode == KEY_Z:
				if event.shift_pressed:
					undo_redo.redo()
				else:
					undo_redo.undo()
				return
			elif event.keycode == KEY_Y:
				undo_redo.redo()
				return

		match event.keycode:
			KEY_1: set_edit_mode(EditMode.VERTEX)
			KEY_2: set_edit_mode(EditMode.EDGE)
			KEY_3: set_edit_mode(EditMode.FACE)
			KEY_4: set_edit_mode(EditMode.CORNER)
			KEY_G: set_gizmo_mode(Gizmo3D.GizmoMode.TRANSLATE)
			KEY_R: set_gizmo_mode(Gizmo3D.GizmoMode.ROTATE)
			KEY_S: set_gizmo_mode(Gizmo3D.GizmoMode.SCALE)
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
	if turret_builder and turret_builder.turret_mesh_instance and turret_builder.turret_mesh_instance.mesh:
		targets.append(turret_builder.turret_mesh_instance)

	var closest_dist = 1e9
	var best_hit = {}

	for target in targets:
		var mesh = target.mesh
		if mesh == null:
			continue

		# Fast AABB bounding box check to prevent frame drops on hover
		var inv_gt = target.global_transform.affine_inverse()
		var local_origin = inv_gt * ray_origin
		var local_dir = (inv_gt.basis * ray_dir).normalized()
		var aabb = mesh.get_aabb().grow(0.05)
		if aabb.intersects_ray(local_origin, local_dir) == null:
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
					var tri_verts: Array = [faces[i * 3], faces[i * 3 + 1], faces[i * 3 + 2]]
					best_hit = {
						"target": target,
						"face_index": i,
						"face_verts": tri_verts,
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
	var face_verts: Array = best_hit["face_verts"]
	var hit_pos_global: Vector3 = best_hit["hit_pos"]
	var target_gt = selected_target.global_transform

	selected_vertex_indices.clear()
	selected_positions.clear()

	var gizmo_pos = hit_pos_global

	match current_edit_mode:
		EditMode.FACE:
			selected_positions = _get_coplanar_quad_face_vertices(selected_target, selected_face_index)
			if selected_positions.is_empty():
				var tri_offset = selected_face_index * 3
				selected_positions = [target_gt * face_verts[0], target_gt * face_verts[1], target_gt * face_verts[2]]
			var avg_pos = Vector3.ZERO
			for p in selected_positions:
				avg_pos += p
			gizmo_pos = avg_pos / max(selected_positions.size(), 1)

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

	_update_cached_colocated_vertices()
	selection_changed.emit()

	if gizmo_3d:
		gizmo_3d.attach_to_position(gizmo_pos)

	_update_selection_visuals()

func _clear_selection() -> void:
	selected_target = null
	selected_face_index = -1
	selected_vertex_indices.clear()
	selected_positions.clear()
	cached_colocated_vertex_indices.clear()
	cached_symmetric_vertex_indices.clear()
	if gizmo_3d:
		gizmo_3d.detach()
	_update_selection_visuals()

func _get_coplanar_quad_face_vertices(target: MeshInstance3D, hit_face_idx: int) -> Array[Vector3]:
	var quad_verts: Array[Vector3] = []
	if target == null or target.mesh == null:
		return quad_verts

	var mesh = target.mesh
	var faces = mesh.get_faces()
	var total_tris = faces.size() / 3
	if hit_face_idx < 0 or hit_face_idx >= total_tris:
		return quad_verts

	var target_gt = target.global_transform if target.is_inside_tree() else target.transform
	var hit_v0 = target_gt * faces[hit_face_idx * 3 + 0]
	var hit_v1 = target_gt * faces[hit_face_idx * 3 + 1]
	var hit_v2 = target_gt * faces[hit_face_idx * 3 + 2]

	var e1 = hit_v1 - hit_v0
	var e2 = hit_v2 - hit_v0
	var hit_norm = e1.cross(e2).normalized()

	quad_verts.append(hit_v0)
	quad_verts.append(hit_v1)
	quad_verts.append(hit_v2)

	# Find adjacent co-planar triangles sharing an edge and coplanar normal
	for i in range(total_tris):
		if i == hit_face_idx:
			continue
		var v0 = target_gt * faces[i * 3 + 0]
		var v1 = target_gt * faces[i * 3 + 1]
		var v2 = target_gt * faces[i * 3 + 2]
		var norm = (v1 - v0).cross(v2 - v0).normalized()

		if abs(norm.dot(hit_norm)) > 0.95:
			var shared_count = 0
			for tri_v in [v0, v1, v2]:
				for q_v in [hit_v0, hit_v1, hit_v2]:
					if tri_v.distance_to(q_v) < 0.05:
						shared_count += 1
						break

			if shared_count >= 2:
				for tri_v in [v0, v1, v2]:
					var is_dup = false
					for existing in quad_verts:
						if tri_v.distance_to(existing) < 0.05:
							is_dup = true
							break
					if not is_dup:
						quad_verts.append(tri_v)

	return quad_verts

func _update_cached_colocated_vertices() -> void:
	cached_colocated_vertex_indices.clear()
	cached_symmetric_vertex_indices.clear()

	if selected_target == null or selected_target.mesh == null or selected_positions.is_empty():
		return

	var array_mesh = selected_target.mesh as ArrayMesh
	if array_mesh == null or array_mesh.get_surface_count() == 0:
		return

	var mdt = MeshDataTool.new()
	var err = mdt.create_from_surface(array_mesh, 0)
	if err != OK:
		return

	var target_local_positions: Array[Vector3] = []
	for pos in selected_positions:
		if selected_target.is_inside_tree():
			target_local_positions.append(selected_target.to_local(pos))
		else:
			target_local_positions.append(selected_target.transform.affine_inverse() * pos)

	var vertex_count = mdt.get_vertex_count()
	var dist_threshold = 0.05 # 5 cm tolerance for co-located corner & edge vertices

	for i in range(vertex_count):
		var v_pos = mdt.get_vertex(i)
		var matched = false

		for t_pos in target_local_positions:
			if v_pos.distance_to(t_pos) < dist_threshold:
				cached_colocated_vertex_indices.append(i)
				matched = true
				break

		if not matched and symmetry_x_enabled:
			for t_pos in target_local_positions:
				var sym_pos = Vector3(-t_pos.x, t_pos.y, t_pos.z)
				if v_pos.distance_to(sym_pos) < dist_threshold:
					cached_symmetric_vertex_indices.append(i)
					break

func _on_gizmo_transform_started() -> void:
	_update_cached_colocated_vertices()
	if selected_target and selected_target.mesh is ArrayMesh and (selected_target.mesh as ArrayMesh).get_surface_count() > 0:
		_drag_start_target = selected_target
		_drag_start_mesh_arrays = _duplicate_surface_arrays((selected_target.mesh as ArrayMesh).surface_get_arrays(0))
		_drag_start_selected_positions = selected_positions.duplicate()
	else:
		_drag_start_target = null
		_drag_start_mesh_arrays.clear()
		_drag_start_selected_positions.clear()

## Moves ALL co-located vertices sharing target 3D positions together and updates selection state for continuous drag
func _on_gizmo_transform_changed(trans_delta: Vector3, _rot_delta: Vector3, _scale_delta: Vector3) -> void:
	if selected_target == null or selected_target.mesh == null or selected_positions.is_empty():
		return

	var array_mesh = selected_target.mesh as ArrayMesh
	if array_mesh == null or array_mesh.get_surface_count() == 0:
		return

	var target_gt = selected_target.global_transform if selected_target.is_inside_tree() else selected_target.transform
	var inv_gt = target_gt.basis.inverse()
	var local_trans_delta = inv_gt * trans_delta
	var sym_trans_delta = Vector3(-local_trans_delta.x, local_trans_delta.y, local_trans_delta.z)

	if cached_colocated_vertex_indices.is_empty() and not selected_positions.is_empty():
		_update_cached_colocated_vertices()

	var arrays = array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vert_count = vertices.size()

	for v_idx in cached_colocated_vertex_indices:
		if v_idx < vert_count:
			vertices[v_idx] += local_trans_delta

	if symmetry_x_enabled:
		for v_idx in cached_symmetric_vertex_indices:
			if v_idx < vert_count:
				vertices[v_idx] += sym_trans_delta

	arrays[Mesh.ARRAY_VERTEX] = vertices
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	selected_target.mesh = array_mesh

	# Crucial: update selected_positions by trans_delta so subsequent drag frames continue smoothly!
	for k in range(selected_positions.size()):
		selected_positions[k] += trans_delta

	_update_selection_visuals()
	selection_changed.emit()

func _on_gizmo_transform_ended() -> void:
	if _drag_start_target != null and is_instance_valid(_drag_start_target) and _drag_start_target.mesh is ArrayMesh:
		var drag_end_mesh_arrays = _duplicate_surface_arrays((_drag_start_target.mesh as ArrayMesh).surface_get_arrays(0))
		var drag_end_selected_positions = selected_positions.duplicate()
		var target = _drag_start_target
		var start_arrays = _drag_start_mesh_arrays
		var start_positions = _drag_start_selected_positions.duplicate()

		undo_redo.create_action("Transform Mesh")
		undo_redo.add_do_method(_restore_mesh_state.bind(target, drag_end_mesh_arrays, drag_end_selected_positions))
		undo_redo.add_undo_method(_restore_mesh_state.bind(target, start_arrays, start_positions))
		undo_redo.commit_action(false)

		if target == hull_builder and hull_builder.has_method("_update_collision_shape"):
			hull_builder.call("_update_collision_shape")
		elif turret_builder and (target == turret_builder or target == turret_builder.turret_mesh_instance) and turret_builder.has_method("_update_collision_shape"):
			turret_builder.call("_update_collision_shape")

		if bounding_box_overlay and bounding_box_overlay.has_method("update_overlay"):
			bounding_box_overlay.update_overlay()

	_drag_start_target = null
	_drag_start_mesh_arrays = []
	_drag_start_selected_positions = []

func extrude_selected_face() -> void:
	if selected_target == null or selected_target.mesh == null or selected_face_index < 0:
		return

	var target = selected_target
	var array_mesh = target.mesh as ArrayMesh
	if array_mesh == null or array_mesh.get_surface_count() == 0:
		return

	var old_arrays = _duplicate_surface_arrays(array_mesh.surface_get_arrays(0))
	var old_positions = selected_positions.duplicate()

	# Real 3D geometry extrusion creating side quad faces and offsetting top face vertices
	var extrude_dist: float = 0.4
	var sym_idx = -1
	if symmetry_x_enabled:
		sym_idx = MeshTopologyOps.find_symmetric_face_index(array_mesh, selected_face_index)

	array_mesh = MeshTopologyOps.extrude_face(array_mesh, selected_face_index, extrude_dist)
	if sym_idx >= 0 and sym_idx != selected_face_index:
		array_mesh = MeshTopologyOps.extrude_face(array_mesh, sym_idx, extrude_dist)

	target.mesh = array_mesh

	if target == hull_builder and hull_builder.has_method("_update_collision_shape"):
		hull_builder.call("_update_collision_shape")

	var faces = array_mesh.get_faces()
	var target_gt = target.global_transform
	if selected_face_index * 3 + 2 < faces.size():
		var p0 = target_gt * faces[selected_face_index * 3 + 0]
		var p1 = target_gt * faces[selected_face_index * 3 + 1]
		var p2 = target_gt * faces[selected_face_index * 3 + 2]
		selected_positions = [p0, p1, p2]
		if gizmo_3d:
			gizmo_3d.attach_to_position((p0 + p1 + p2) / 3.0)

	_update_cached_colocated_vertices()
	_update_selection_visuals()
	selection_changed.emit()

	var new_arrays = _duplicate_surface_arrays(array_mesh.surface_get_arrays(0))
	var new_positions = selected_positions.duplicate()

	undo_redo.create_action("Extrude Face")
	undo_redo.add_do_method(_restore_mesh_state.bind(target, new_arrays, new_positions))
	undo_redo.add_undo_method(_restore_mesh_state.bind(target, old_arrays, old_positions))
	undo_redo.commit_action(false)

func _apply_extrude_state(target: MeshInstance3D, hull_len: float, turret_len: float, surface_arrays: Array, sel_positions: Array[Vector3]) -> void:
	if target == hull_builder and hull_builder:
		hull_builder.length = hull_len
		hull_builder.generate_hull_mesh()
	elif turret_builder and target == turret_builder.turret_mesh_instance:
		turret_builder.turret_length = turret_len
		turret_builder.generate_turret_and_gun()
	elif target and target.mesh and not surface_arrays.is_empty():
		_restore_mesh_state(target, surface_arrays, sel_positions)
		return

	if selected_target == target:
		selected_positions = sel_positions.duplicate()
		_update_cached_colocated_vertices()
		_update_selection_visuals()
		selection_changed.emit()

func _duplicate_surface_arrays(arrays: Array) -> Array:
	var copy: Array = []
	copy.resize(arrays.size())
	for i in range(arrays.size()):
		var val = arrays[i]
		if val is PackedVector3Array or val is PackedVector2Array or val is PackedColorArray or val is PackedInt32Array or val is PackedFloat32Array or val is PackedByteArray:
			copy[i] = val.duplicate()
		elif val != null and val is Array:
			copy[i] = (val as Array).duplicate(true)
		else:
			copy[i] = val
	return copy

func _restore_mesh_state(target: MeshInstance3D, surface_arrays: Array, sel_positions: Array[Vector3]) -> void:
	if target == null or not is_instance_valid(target):
		return
	var array_mesh = target.mesh as ArrayMesh
	if array_mesh and not surface_arrays.is_empty():
		array_mesh.clear_surfaces()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _duplicate_surface_arrays(surface_arrays))
		target.mesh = array_mesh

	if target == hull_builder and hull_builder.has_method("_update_collision_shape"):
		hull_builder.call("_update_collision_shape")
	elif turret_builder and (target == turret_builder or target == turret_builder.turret_mesh_instance) and turret_builder.has_method("_update_collision_shape"):
		turret_builder.call("_update_collision_shape")

	if selected_target == target:
		selected_positions = sel_positions.duplicate()
		_update_cached_colocated_vertices()
		if selected_positions.size() > 0 and gizmo_3d:
			var avg = Vector3.ZERO
			for p in selected_positions:
				avg += p
			avg /= float(selected_positions.size())
			gizmo_3d.attach_to_position(avg)
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
	if selected_target == null or selected_target.mesh == null:
		_clear_selection()
		return

	var array_mesh = selected_target.mesh as ArrayMesh
	if array_mesh == null:
		return

	match current_edit_mode:
		EditMode.FACE:
			if selected_face_index >= 0:
				var faces_to_delete: Array[int] = [selected_face_index]
				if symmetry_x_enabled:
					var sym_idx = MeshTopologyOps.find_symmetric_face_index(array_mesh, selected_face_index)
					if sym_idx >= 0 and sym_idx != selected_face_index:
						faces_to_delete.append(sym_idx)

				faces_to_delete.sort()
				faces_to_delete.reverse()

				for f_idx in faces_to_delete:
					array_mesh = MeshTopologyOps.delete_face(array_mesh, f_idx)

		EditMode.VERTEX, EditMode.CORNER:
			if selected_face_index >= 0:
				array_mesh = MeshTopologyOps.delete_face(array_mesh, selected_face_index)

		EditMode.EDGE:
			if selected_face_index >= 0:
				array_mesh = MeshTopologyOps.delete_face(array_mesh, selected_face_index)

	selected_target.mesh = array_mesh
	if selected_target == hull_builder and hull_builder.has_method("_update_collision_shape"):
		hull_builder.call("_update_collision_shape")

	_clear_selection()

func _update_selection_visuals() -> void:
	if selection_overlay_mesh == null:
		return

	if selected_target == null or selected_positions.is_empty():
		selection_overlay_mesh.mesh = null
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Translucent Face Fill Overlay (Sprocket-style Golden Fill)
	if current_edit_mode == EditMode.FACE and selected_positions.size() >= 3:
		if selected_positions.size() == 4:
			var p0 = selected_positions[0]
			var p1 = selected_positions[1]
			var p2 = selected_positions[2]
			var p3 = selected_positions[3]
			st.set_color(Color(1.0, 0.75, 0.1, 0.40))
			_add_quad_simple(st, p0, p1, p2, p3)

			if symmetry_x_enabled:
				st.set_color(Color(0.2, 0.8, 1.0, 0.40))
				_add_quad_simple(st, _symmetry_x(p0), _symmetry_x(p1), _symmetry_x(p2), _symmetry_x(p3))
		elif selected_positions.size() == 3:
			var p0 = selected_positions[0]
			var p1 = selected_positions[1]
			var p2 = selected_positions[2]
			var normal = (p1 - p0).cross(p2 - p0).normalized()

			st.set_color(Color(1.0, 0.75, 0.1, 0.40))
			st.set_normal(normal)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(p0)
			st.set_normal(normal)
			st.set_uv(Vector2(1, 0))
			st.add_vertex(p1)
			st.set_normal(normal)
			st.set_uv(Vector2(0.5, 1))
			st.add_vertex(p2)

			if symmetry_x_enabled:
				var s0 = _symmetry_x(p0)
				var s1 = _symmetry_x(p1)
				var s2 = _symmetry_x(p2)
				var s_norm = (s1 - s0).cross(s2 - s0).normalized()

				st.set_color(Color(0.2, 0.8, 1.0, 0.40))
				st.set_normal(s_norm)
				st.set_uv(Vector2(0, 0))
				st.add_vertex(s0)
				st.set_normal(s_norm)
				st.set_uv(Vector2(1, 0))
				st.add_vertex(s1)
				st.set_normal(s_norm)
				st.set_uv(Vector2(0.5, 1))
				st.add_vertex(s2)

	# 2. Contour Line Outlines
	if selected_positions.size() >= 3:
		for k in range(selected_positions.size()):
			var a = selected_positions[k]
			var b = selected_positions[(k + 1) % selected_positions.size()]
			_add_thick_line(st, a, b, Color(1.0, 0.85, 0.1), 0.018)
	elif selected_positions.size() == 2:
		_add_thick_line(st, selected_positions[0], selected_positions[1], Color(1.0, 0.85, 0.1), 0.018)

	# 3. Unique Corner Vertex Handle Nodes (Red Cubes) - Deduplicated by 3D position using spatial grid hashing
	if selected_target and selected_target.mesh:
		var faces = selected_target.mesh.get_faces()
		var gt = selected_target.global_transform
		var cell_size: float = 0.02
		var seen_grid = {}

		for i in range(faces.size()):
			var v_g = gt * faces[i]
			var key = Vector3i(
				int(round(v_g.x / cell_size)),
				int(round(v_g.y / cell_size)),
				int(round(v_g.z / cell_size))
			)
			if not seen_grid.has(key):
				seen_grid[key] = true
				_add_box(st, v_g, 0.07, Color(1.0, 0.2, 0.2))

	# 4. Center Cyan Wireframe Diamond Anchor
	if selected_positions.size() > 0:
		var center_pos = Vector3.ZERO
		for pos in selected_positions:
			center_pos += pos
		center_pos /= float(selected_positions.size())
		_add_diamond_anchor(st, center_pos, 0.12, Color(0.2, 0.8, 1.0))

	st.generate_tangents()
	selection_overlay_mesh.mesh = st.commit()

func _symmetry_x(pos: Vector3) -> Vector3:
	return Vector3(-pos.x, pos.y, pos.z)

func _add_thick_line(st: SurfaceTool, a: Vector3, b: Vector3, color: Color, width: float) -> void:
	var dir = (b - a).normalized()
	var side = Vector3.UP.cross(dir).normalized() * width
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT * width

	var n = Vector3.UP
	st.set_color(color)

	st.set_normal(n)
	st.set_uv(Vector2(0,0))
	st.add_vertex(a - side)
	st.set_normal(n)
	st.set_uv(Vector2(1,0))
	st.add_vertex(a + side)
	st.set_normal(n)
	st.set_uv(Vector2(1,1))
	st.add_vertex(b + side)

	st.set_normal(n)
	st.set_uv(Vector2(0,0))
	st.add_vertex(a - side)
	st.set_normal(n)
	st.set_uv(Vector2(1,1))
	st.add_vertex(b + side)
	st.set_normal(n)
	st.set_uv(Vector2(0,1))
	st.add_vertex(b - side)

func _add_box(st: SurfaceTool, center: Vector3, size: float, color: Color) -> void:
	var h = size * 0.5
	var c0 = center + Vector3(-h, -h, -h)
	var c1 = center + Vector3(h, -h, -h)
	var c2 = center + Vector3(h, -h, h)
	var c3 = center + Vector3(-h, -h, h)
	var c4 = center + Vector3(-h, h, -h)
	var c5 = center + Vector3(h, h, -h)
	var c6 = center + Vector3(h, h, h)
	var c7 = center + Vector3(-h, h, h)

	st.set_color(color)

	# 6 Box faces
	_add_quad_simple(st, c0, c1, c5, c4) # Front
	_add_quad_simple(st, c3, c7, c6, c2) # Rear
	_add_quad_simple(st, c0, c4, c7, c3) # Left
	_add_quad_simple(st, c1, c2, c6, c5) # Right
	_add_quad_simple(st, c4, c5, c6, c7) # Top
	_add_quad_simple(st, c0, c3, c2, c1) # Bottom

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

func _add_diamond_anchor(st: SurfaceTool, center: Vector3, size: float, color: Color) -> void:
	var h = size * 0.5
	var top = center + Vector3(0, h * 1.4, 0)
	var bot = center + Vector3(0, -h * 1.4, 0)
	var e0 = center + Vector3(h, 0, 0)
	var e1 = center + Vector3(0, 0, h)
	var e2 = center + Vector3(-h, 0, 0)
	var e3 = center + Vector3(0, 0, -h)

	st.set_color(color)

	_add_quad_simple(st, top, e0, bot, e1)
	_add_quad_simple(st, top, e1, bot, e2)
	_add_quad_simple(st, top, e2, bot, e3)
	_add_quad_simple(st, top, e3, bot, e0)

func inspect_hover_point(screen_pos: Vector2) -> void:
	if camera_3d == null:
		return

	var ray_origin = camera_3d.project_ray_origin(screen_pos)
	var ray_dir = camera_3d.project_ray_normal(screen_pos)

	var hit_data = _raycast_targets(ray_origin, ray_dir)
	if hit_data.is_empty():
		return

	var target = hit_data["target"]
	var face_verts: Array = hit_data["face_verts"]
	var gt = target.global_transform

	var v0: Vector3 = gt * face_verts[0]
	var v1: Vector3 = gt * face_verts[1]
	var v2: Vector3 = gt * face_verts[2]

	var normal = (v1 - v0).cross(v2 - v0).normalized()
	if normal.dot(-ray_dir) < 0:
		normal = -normal

	var cos_theta = clamp(abs(normal.dot(-ray_dir)), 0.0, 1.0)
	var angle_deg = rad_to_deg(acos(cos_theta))
	var los_factor = 1.0 / max(cos_theta, 0.087)

	var sandwich: ArmorCalculator.ArmorSandwich = null
	if target == hull_builder:
		if hull_builder.armor_sandwich == null:
			hull_builder.armor_sandwich = ArmorCalculator.ArmorSandwich.create_default_glacis()
		sandwich = hull_builder.armor_sandwich
	elif turret_builder and (target == turret_builder or target == turret_builder.turret_mesh_instance):
		if turret_builder.armor_sandwich == null:
			turret_builder.armor_sandwich = ArmorCalculator.ArmorSandwich.create_default_turret()
		sandwich = turret_builder.armor_sandwich

	var thickness = 450.0
	var eff_ke_mm = 0.0
	var eff_heat_mm = 0.0

	if sandwich != null:
		thickness = sandwich.get_total_physical_thickness_mm()
		eff_ke_mm = sandwich.get_effective_rha_mm(ArmorCalculator.AmmoType.APFSDS, los_factor)
		eff_heat_mm = sandwich.get_effective_rha_mm(ArmorCalculator.AmmoType.HEAT, los_factor)
	else:
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

		eff_ke_mm = ArmorCalculator.calculate_effective_thickness(thickness, normal, ray_dir)
		eff_heat_mm = eff_ke_mm

	face_hovered.emit(thickness, angle_deg, eff_ke_mm, eff_heat_mm)
