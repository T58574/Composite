class_name BoundingBoxOverlay
extends Node3D

## Renders a 3D translucent wireframe bounding box with real-time metric dimension labels
## (Length, Width, Height) around the vehicle assembly in TankEditor.

signal dimensions_changed(length: float, width: float, height: float)

@export var hull_builder: HullBuilder
@export var turret_builder: TurretBuilder
@export var track_generator: TrackGenerator
@export var target_vehicle: Node3D

@export var auto_update: bool = true
@export var show_overlay: bool = true:
	set(value):
		show_overlay = value
		visible = show_overlay

@export_group("Visual Styling")
@export var wireframe_color: Color = Color(0.15, 0.75, 1.0, 0.9) ## Bright cyan wireframe
@export var fill_color: Color = Color(0.1, 0.5, 0.9, 0.12) ## Translucent inner fill
@export var label_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var label_outline_color: Color = Color(0.0, 0.0, 0.0, 0.95)
@export var label_font_size: int = 28
@export var corner_bracket_size: float = 0.4 ## Length of corner bracket accents in meters

# Sub-nodes created dynamically
var lines_mesh_instance: MeshInstance3D
var fill_mesh_instance: MeshInstance3D
var length_label: Label3D
var width_label: Label3D
var height_label: Label3D

# Materials
var wire_material: StandardMaterial3D
var fill_material: StandardMaterial3D

# Internal dimension tracking
var current_length: float = 0.0
var current_width: float = 0.0
var current_height: float = 0.0
var _current_aabb: AABB = AABB()

func _ready() -> void:
	_setup_nodes()
	_setup_materials()
	if hull_builder == null or turret_builder == null or track_generator == null:
		_auto_find_targets()
	update_overlay()

func _process(_delta: float) -> void:
	if auto_update and visible:
		update_overlay()

func _setup_nodes() -> void:
	if lines_mesh_instance == null:
		lines_mesh_instance = MeshInstance3D.new()
		lines_mesh_instance.name = "WireframeLines"
		add_child(lines_mesh_instance)

	if fill_mesh_instance == null:
		fill_mesh_instance = MeshInstance3D.new()
		fill_mesh_instance.name = "TranslucentFill"
		add_child(fill_mesh_instance)

	if length_label == null:
		length_label = Label3D.new()
		length_label.name = "LengthLabel"
		_configure_label(length_label)
		add_child(length_label)

	if width_label == null:
		width_label = Label3D.new()
		width_label.name = "WidthLabel"
		_configure_label(width_label)
		add_child(width_label)

	if height_label == null:
		height_label = Label3D.new()
		height_label.name = "HeightLabel"
		_configure_label(height_label)
		add_child(height_label)

func _configure_label(label: Label3D) -> void:
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.font_size = label_font_size
	label.outline_size = 8
	label.modulate = label_text_color
	label.outline_modulate = label_outline_color

func _setup_materials() -> void:
	wire_material = StandardMaterial3D.new()
	wire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wire_material.albedo_color = wireframe_color
	wire_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wire_material.no_depth_test = false
	wire_material.render_priority = 10

	fill_material = StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.albedo_color = fill_color
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_material.no_depth_test = false
	fill_material.render_priority = 5

	if lines_mesh_instance:
		lines_mesh_instance.material_override = wire_material
	if fill_mesh_instance:
		fill_mesh_instance.material_override = fill_material

func _auto_find_targets() -> void:
	var tree = get_tree()
	if tree == null:
		return

	if target_vehicle != null:
		if hull_builder == null:
			hull_builder = target_vehicle.find_child("*Hull*", true, false) as HullBuilder
		if turret_builder == null:
			turret_builder = target_vehicle.find_child("*Turret*", true, false) as TurretBuilder
		if track_generator == null:
			track_generator = target_vehicle.find_child("*Track*", true, false) as TrackGenerator

	var search_root = get_parent() if get_parent() != null else tree.current_scene
	if search_root:
		if hull_builder == null:
			var hulls = search_root.find_children("", "HullBuilder", true, false)
			if not hulls.is_empty():
				hull_builder = hulls[0] as HullBuilder

		if turret_builder == null:
			var turrets = search_root.find_children("", "TurretBuilder", true, false)
			if not turrets.is_empty():
				turret_builder = turrets[0] as TurretBuilder

		if track_generator == null:
			var tracks = search_root.find_children("", "TrackGenerator", true, false)
			if not tracks.is_empty():
				track_generator = tracks[0] as TrackGenerator

## Calculates the vehicle 3D AABB dynamically from all component mesh instances
func calculate_vehicle_aabb() -> AABB:
	var mesh_instances: Array[MeshInstance3D] = []

	if hull_builder:
		_collect_mesh_instances(hull_builder, mesh_instances)
	if turret_builder:
		_collect_mesh_instances(turret_builder, mesh_instances)
	if track_generator:
		_collect_mesh_instances(track_generator, mesh_instances)
	if target_vehicle:
		_collect_mesh_instances(target_vehicle, mesh_instances)

	var unique_mesh_instances: Array[MeshInstance3D] = []
	for mi in mesh_instances:
		if mi not in unique_mesh_instances and mi != lines_mesh_instance and mi != fill_mesh_instance and mi.get_parent() != self:
			unique_mesh_instances.append(mi)

	if unique_mesh_instances.is_empty():
		return _calculate_fallback_aabb()

	var first: bool = true
	var min_bound := Vector3.ZERO
	var max_bound := Vector3.ZERO

	for mi in unique_mesh_instances:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue

		var local_aabb := mi.mesh.get_aabb()
		var mi_transform := mi.global_transform

		var corners: Array[Vector3] = [
			local_aabb.position,
			local_aabb.position + Vector3(local_aabb.size.x, 0, 0),
			local_aabb.position + Vector3(0, local_aabb.size.y, 0),
			local_aabb.position + Vector3(0, 0, local_aabb.size.z),
			local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0),
			local_aabb.position + Vector3(local_aabb.size.x, 0, local_aabb.size.z),
			local_aabb.position + Vector3(0, local_aabb.size.y, local_aabb.size.z),
			local_aabb.position + local_aabb.size
		]

		for corner in corners:
			var world_p := mi_transform * corner
			var local_p := to_local(world_p)

			if first:
				min_bound = local_p
				max_bound = local_p
				first = false
			else:
				min_bound.x = min(min_bound.x, local_p.x)
				min_bound.y = min(min_bound.y, local_p.y)
				min_bound.z = min(min_bound.z, local_p.z)
				max_bound.x = max(max_bound.x, local_p.x)
				max_bound.y = max(max_bound.y, local_p.y)
				max_bound.z = max(max_bound.z, local_p.z)

	if first:
		return _calculate_fallback_aabb()

	var size := max_bound - min_bound
	size.x = max(size.x, 0.1)
	size.y = max(size.y, 0.1)
	size.z = max(size.z, 0.1)

	return AABB(min_bound, size)

func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			result.append(mi)
	for child in node.get_children():
		_collect_mesh_instances(child, result)

func _calculate_fallback_aabb() -> AABB:
	var l = 6.8
	var w = 3.4
	var h = 2.0

	if hull_builder:
		l = hull_builder.length
		w = hull_builder.width
		h = hull_builder.height

	if turret_builder:
		l = max(l, turret_builder.turret_length + turret_builder.barrel_length * 0.5)
		w = max(w, turret_builder.turret_width)
		h += turret_builder.turret_height * 0.8

	if track_generator:
		w = max(w, track_generator.track_span_width * 2.0 + track_generator.track_width)

	var half_l = l * 0.5
	var half_w = w * 0.5
	var min_p = Vector3(-half_l, 0.0, -half_w)
	var size = Vector3(l, h, w)
	return AABB(min_p, size)

## Rebuilds 3D wireframe mesh lines & corner brackets via SurfaceTool
func _build_wireframe_mesh(aabb: AABB) -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var min_p = aabb.position
	var max_p = aabb.position + aabb.size

	var c000 = Vector3(min_p.x, min_p.y, min_p.z)
	var c100 = Vector3(max_p.x, min_p.y, min_p.z)
	var c010 = Vector3(min_p.x, max_p.y, min_p.z)
	var c110 = Vector3(max_p.x, max_p.y, min_p.z)
	var c001 = Vector3(min_p.x, min_p.y, max_p.z)
	var c101 = Vector3(max_p.x, min_p.y, max_p.z)
	var c011 = Vector3(min_p.x, max_p.y, max_p.z)
	var c111 = Vector3(max_p.x, max_p.y, max_p.z)

	var main_edges: Array[Vector3] = [
		# Bottom frame
		c000, c100,
		c100, c101,
		c101, c001,
		c001, c000,
		# Top frame
		c010, c110,
		c110, c111,
		c111, c011,
		c011, c010,
		# Vertical pillars
		c000, c010,
		c100, c110,
		c101, c111,
		c001, c011
	]

	for i in range(0, main_edges.size(), 2):
		st.add_vertex(main_edges[i])
		st.add_vertex(main_edges[i + 1])

	# Add corner bracket accents for Sprocket/CAD editor look
	if corner_bracket_size > 0.01:
		var brack_len = min(corner_bracket_size, min(aabb.size.x, min(aabb.size.y, aabb.size.z)) * 0.3)
		var corners = [c000, c100, c010, c110, c001, c101, c011, c111]

		for corner in corners:
			var dir_x = 1.0 if corner.x == min_p.x else -1.0
			var dir_y = 1.0 if corner.y == min_p.y else -1.0
			var dir_z = 1.0 if corner.z == min_p.z else -1.0

			st.add_vertex(corner)
			st.add_vertex(corner + Vector3(dir_x * brack_len, 0, 0))

			st.add_vertex(corner)
			st.add_vertex(corner + Vector3(0, dir_y * brack_len, 0))

			st.add_vertex(corner)
			st.add_vertex(corner + Vector3(0, 0, dir_z * brack_len))

	return st.commit()

## Rebuilds 3D translucent box fill faces via SurfaceTool
func _build_fill_mesh(aabb: AABB) -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var min_p = aabb.position
	var max_p = aabb.position + aabb.size

	var c000 = Vector3(min_p.x, min_p.y, min_p.z)
	var c100 = Vector3(max_p.x, min_p.y, min_p.z)
	var c010 = Vector3(min_p.x, max_p.y, min_p.z)
	var c110 = Vector3(max_p.x, max_p.y, min_p.z)
	var c001 = Vector3(min_p.x, min_p.y, max_p.z)
	var c101 = Vector3(max_p.x, min_p.y, max_p.z)
	var c011 = Vector3(min_p.x, max_p.y, max_p.z)
	var c111 = Vector3(max_p.x, max_p.y, max_p.z)

	_add_quad(st, c000, c100, c101, c001) # Bottom
	_add_quad(st, c010, c011, c111, c110) # Top
	_add_quad(st, c100, c110, c111, c101) # Front (+X)
	_add_quad(st, c000, c001, c011, c010) # Rear (-X)
	_add_quad(st, c000, c010, c110, c100) # Left (-Z)
	_add_quad(st, c001, c101, c111, c011) # Right (+Z)

	return st.commit()

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n = (b - a).cross(d - a).normalized()
	if n.length_squared() < 0.0001:
		n = Vector3.UP

	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)

	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(c)
	st.set_normal(n)
	st.add_vertex(d)

## Public API to manually recalculate AABB, update wireframe visuals and dimension labels
func update_overlay() -> void:
	if not is_inside_tree():
		return

	if hull_builder == null or turret_builder == null or track_generator == null:
		_auto_find_targets()

	var aabb = calculate_vehicle_aabb()
	_current_aabb = aabb

	var new_l = aabb.size.x
	var new_h = aabb.size.y
	var new_w = aabb.size.z

	if lines_mesh_instance:
		lines_mesh_instance.mesh = _build_wireframe_mesh(aabb)

	if fill_mesh_instance:
		fill_mesh_instance.mesh = _build_fill_mesh(aabb)

	var min_p = aabb.position
	var max_p = aabb.position + aabb.size

	if length_label:
		length_label.text = "L: %.2f m" % new_l
		length_label.position = Vector3((min_p.x + max_p.x) * 0.5, min_p.y - 0.2, max_p.z + 0.25)

	if width_label:
		width_label.text = "W: %.2f m" % new_w
		width_label.position = Vector3(max_p.x + 0.25, min_p.y - 0.2, (min_p.z + max_p.z) * 0.5)

	if height_label:
		height_label.text = "H: %.2f m" % new_h
		height_label.position = Vector3(max_p.x + 0.25, (min_p.y + max_p.y) * 0.5, max_p.z + 0.25)

	if abs(new_l - current_length) > 0.001 or abs(new_w - current_width) > 0.001 or abs(new_h - current_height) > 0.001:
		current_length = new_l
		current_width = new_w
		current_height = new_h
		dimensions_changed.emit(current_length, current_width, current_height)

## Assign target builders and immediately refresh
func set_targets(p_hull: HullBuilder, p_turret: TurretBuilder, p_track: TrackGenerator) -> void:
	hull_builder = p_hull
	turret_builder = p_turret
	track_generator = p_track
	update_overlay()

## Returns current dimensions as Vector3(Length, Height, Width) in meters
func get_dimensions() -> Vector3:
	return Vector3(current_length, current_height, current_width)

## Returns current vehicle bounding box
func get_aabb() -> AABB:
	return _current_aabb
