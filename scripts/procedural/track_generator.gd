class_name TrackGenerator
extends Node3D

## Procedural Continuous Track Belt and Road Wheel Generator for Sprocket-style Editor.
## Aligned along X axis (vehicle length) and Z axis (vehicle track span width).
## Builds dual-rim road wheels with hub caps, drive sprockets with radial teeth,
## skeletonized idler wheels, return rollers, and continuous track belt loops with realistic sag curves.

enum SuspensionType { TORSION_BAR, HYDROPNEUMATIC, LEAF_SPRING }

@export_group("Chassis Configuration")
@export_range(4, 8, 1) var road_wheels_count: int = 6 ## Pairs of road wheels per side
@export_range(0.3, 1.2, 0.05) var wheel_diameter: float = 0.65 ## Meters
@export_range(0.3, 0.9, 0.05) var track_width: float = 0.6 ## Meters
@export_range(0.3, 1.2, 0.05) var suspension_height: float = 0.6 ## Ground clearance
@export_range(1.2, 2.5, 0.1) var track_span_width: float = 1.6 ## Distance from vehicle center (Z axis)
@export_range(0.01, 0.15, 0.01) var track_sag_m: float = 0.06 ## Track sag depth on top run

@export_group("Suspension Tuning")
@export var suspension_type: SuspensionType = SuspensionType.TORSION_BAR
@export_range(10.0, 100.0, 5.0) var suspension_stiffness_k: float = 45.0 ## kN/m

@export_group("Material")
@export var track_material: Material

# Property alias for compatibility with tank_serializer
var road_wheel_pairs: int:
	get:
		return road_wheels_count
	set(value):
		road_wheels_count = value

var _wheel_nodes: Array[MeshInstance3D] = []

func _ready() -> void:
	generate_tracks_and_wheels()

func generate_tracks_and_wheels() -> void:
	_clear_existing()
	_create_road_wheels_and_belts()

func _clear_existing() -> void:
	for child in get_children():
		child.queue_free()
	_wheel_nodes.clear()

func _create_road_wheels_and_belts() -> void:
	var wheel_radius = wheel_diameter * 0.5
	var chassis_length = (road_wheels_count - 1) * (wheel_diameter * 1.15)
	
	# Chassis runs along X axis: Rear (-X) to Front (+X)
	var rear_x = -chassis_length * 0.5
	var front_x = chassis_length * 0.5

	for side in [-1.0, 1.0]: # Left (-1, -Z) and Right (1, +Z)
		var z_pos = side * track_span_width

		# 1. Drive Sprocket (Front, +X) with radial teeth
		var sprocket_pos = Vector3(front_x + (wheel_radius * 1.3), 0.1, z_pos)
		var sprocket = _create_sprocket_mesh(wheel_radius * 0.9, track_width * 0.85, side)
		sprocket.position = sprocket_pos
		add_child(sprocket)

		# 2. Idler Wheel (Rear, -X) with dished spokes
		var idler_pos = Vector3(rear_x - (wheel_radius * 1.3), 0.1, z_pos)
		var idler = _create_idler_mesh(wheel_radius * 0.85, track_width * 0.85, side)
		idler.position = idler_pos
		add_child(idler)

		# 3. Dual Rim Road Wheels & Axle Hub Caps along X axis
		var wheel_y = -suspension_height * 0.5
		for i in range(road_wheels_count):
			var x_pos = rear_x + (float(i) * wheel_diameter * 1.15)
			var wheel_pos = Vector3(x_pos, wheel_y, z_pos)
			var wheel = _create_dual_road_wheel_mesh(wheel_radius, track_width * 0.85, side)
			wheel.position = wheel_pos
			add_child(wheel)
			_wheel_nodes.append(wheel)

		# 4. Return Rollers (Upper Track Support along X)
		var return_roller_count = clamp(road_wheels_count - 2, 2, 4)
		var roller_positions: Array[Vector3] = []
		var roller_y = 0.35
		var roller_r = wheel_radius * 0.45

		for r in range(return_roller_count):
			var t_r = float(r + 1) / float(return_roller_count + 1)
			var r_x = lerp(rear_x, front_x, t_r)
			var r_pos = Vector3(r_x, roller_y, z_pos)
			roller_positions.append(r_pos)

			var roller = _create_dual_road_wheel_mesh(roller_r, track_width * 0.7, side)
			roller.position = r_pos
			add_child(roller)

		# 5. Continuous Track Belt Loop with Sag Curve along X axis
		_build_track_loop_mesh(z_pos, sprocket_pos, idler_pos, roller_positions, wheel_radius, track_width)

## Creates a detailed Dual Rim Road Wheel (Inner Rim + Outer Rim + Rubber Tire + Central Axle Hub Cap)
## Wheels roll in XY plane, axle extends along Z axis.
func _create_dual_road_wheel_mesh(radius: float, width: float, side: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 24
	var rim_width = width * 0.38
	var gap = width * 0.24

	var rim_offsets = [-gap * 0.5 - rim_width * 0.5, gap * 0.5 + rim_width * 0.5]

	for offset in rim_offsets:
		var inner_r = radius * 0.72
		for i in range(sides):
			var a1 = (float(i) / float(sides)) * TAU
			var a2 = (float(i + 1) / float(sides)) * TAU

			# Radial normal in XY plane
			var n1 = Vector3(cos(a1), sin(a1), 0.0)
			var n2 = Vector3(cos(a2), sin(a2), 0.0)

			var z_in = offset - rim_width * 0.5
			var z_out = offset + rim_width * 0.5

			# Rubber Tire Outer Tread Ring (XY circle, extruded in Z)
			var p1_in = Vector3(cos(a1) * radius, sin(a1) * radius, z_in)
			var p2_in = Vector3(cos(a2) * radius, sin(a2) * radius, z_in)
			var p1_out = Vector3(cos(a1) * radius, sin(a1) * radius, z_out)
			var p2_out = Vector3(cos(a2) * radius, sin(a2) * radius, z_out)

			_add_quad_smooth_normal(st, p1_in, p1_out, p2_out, p2_in, n1, n1, n2, n2)

			# Metal Wheel Rim Dish Face (Flat Z normals)
			var pr1_in = Vector3(cos(a1) * inner_r, sin(a1) * inner_r, z_in)
			var pr2_in = Vector3(cos(a2) * inner_r, sin(a2) * inner_r, z_in)
			var pr1_out = Vector3(cos(a1) * inner_r, sin(a1) * inner_r, z_out)
			var pr2_out = Vector3(cos(a2) * inner_r, sin(a2) * inner_r, z_out)

			_add_quad_flat_normal(st, pr1_in, p1_in, p2_in, pr2_in, Vector3(0, 0, -1))
			_add_quad_flat_normal(st, pr1_out, pr2_out, p2_out, p1_out, Vector3(0, 0, 1))

	# Central Axle Hub Cap
	var hub_r = radius * 0.32
	var hub_out_z = side * (width * 0.52)
	var hub_in_z = side * (width * 0.3)

	for i in range(16):
		var a1 = (float(i) / 16.0) * TAU
		var a2 = (float(i + 1) / 16.0) * TAU
		var n1 = Vector3(cos(a1), sin(a1), 0.0)
		var n2 = Vector3(cos(a2), sin(a2), 0.0)

		var hp1_in = Vector3(cos(a1) * hub_r, sin(a1) * hub_r, hub_in_z)
		var hp2_in = Vector3(cos(a2) * hub_r, sin(a2) * hub_r, hub_in_z)
		var hp1_out = Vector3(cos(a1) * hub_r, sin(a1) * hub_r, hub_out_z)
		var hp2_out = Vector3(cos(a2) * hub_r, sin(a2) * hub_r, hub_out_z)

		if side > 0:
			_add_quad_smooth_normal(st, hp1_in, hp1_out, hp2_out, hp2_in, n1, n1, n2, n2)
		else:
			_add_quad_smooth_normal(st, hp1_out, hp1_in, hp2_in, hp2_out, n1, n1, n2, n2)

		# Hub end cap disc (Flat Z normal)
		var hub_center = Vector3(0, 0, hub_out_z + side * 0.02)
		var side_norm = Vector3(0, 0, side)

		if side > 0:
			_add_triangle_flat_normal(st, hub_center, hp1_out, hp2_out, side_norm)
		else:
			_add_triangle_flat_normal(st, hub_center, hp2_out, hp1_out, side_norm)

	st.generate_tangents()
	mi.mesh = st.commit()
	if track_material:
		mi.material_override = track_material
	return mi

## Creates Drive Sprocket Wheel with perimeter drive teeth
func _create_sprocket_mesh(radius: float, width: float, side: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var teeth_count = 14
	var half_w = width * 0.4

	for ring_z in [-half_w, half_w]:
		for i in range(teeth_count):
			var a1 = (float(i) / float(teeth_count)) * TAU
			var a2 = (float(i + 0.5) / float(teeth_count)) * TAU
			var a3 = (float(i + 1.0) / float(teeth_count)) * TAU

			var p_base1 = Vector3(cos(a1) * radius, sin(a1) * radius, ring_z)
			var p_tip   = Vector3(cos(a2) * (radius + 0.09), sin(a2) * (radius + 0.09), ring_z)
			var p_base2 = Vector3(cos(a3) * radius, sin(a3) * radius, ring_z)

			var side_n = Vector3(0, 0, 1.0 if ring_z > 0 else -1.0)

			if ring_z > 0:
				_add_triangle_flat_normal(st, p_base1, p_tip, p_base2, side_n)
			else:
				_add_triangle_flat_normal(st, p_base1, p_base2, p_tip, side_n)

			var p_tip_other = Vector3(p_tip.x, p_tip.y, ring_z - sign(ring_z) * 0.04)
			var p_b1_other  = Vector3(p_base1.x, p_base1.y, ring_z - sign(ring_z) * 0.04)
			_add_triangle_flat_normal(st, p_base1, p_tip, p_tip_other, Vector3(cos(a2), sin(a2), 0))
			_add_triangle_flat_normal(st, p_base1, p_tip_other, p_b1_other, Vector3(cos(a1), sin(a1), 0))

	st.generate_tangents()
	mi.mesh = st.commit()
	if track_material:
		mi.material_override = track_material
	return mi

## Creates Rear Idler Wheel mesh with dished spoke cutouts
func _create_idler_mesh(radius: float, width: float, side: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 20
	var half_w = width * 0.45

	for i in range(sides):
		var a1 = (float(i) / float(sides)) * TAU
		var a2 = (float(i + 1) / float(sides)) * TAU

		var n1 = Vector3(cos(a1), sin(a1), 0.0)
		var n2 = Vector3(cos(a2), sin(a2), 0.0)

		var p1_l = Vector3(cos(a1) * radius, sin(a1) * radius, -half_w)
		var p2_l = Vector3(cos(a2) * radius, sin(a2) * radius, -half_w)
		var p1_r = Vector3(cos(a1) * radius, sin(a1) * radius, half_w)
		var p2_r = Vector3(cos(a2) * radius, sin(a2) * radius, half_w)

		_add_quad_smooth_normal(st, p1_l, p1_r, p2_r, p2_l, n1, n1, n2, n2)

		var center_l = Vector3(0, 0, -half_w * 0.7)
		var center_r = Vector3(0, 0, half_w * 0.7)
		_add_triangle_flat_normal(st, center_l, p1_l, p2_l, Vector3(0, 0, -1))
		_add_triangle_flat_normal(st, center_r, p2_r, p1_r, Vector3(0, 0, 1))

	st.generate_tangents()
	mi.mesh = st.commit()
	if track_material:
		mi.material_override = track_material
	return mi

## Builds continuous track belt loop around sprockets, rollers, idler, and ground wheels along X axis
func _build_track_loop_mesh(
	z_pos: float,
	sprocket_pos: Vector3,
	idler_pos: Vector3,
	rollers: Array[Vector3],
	radius: float,
	width: float
) -> void:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_w = width * 0.5
	var bot_y = -suspension_height * 0.5 - radius
	var track_thickness = 0.04
	var guide_horn_h = 0.07

	var path_points: Array[Vector3] = []
	var path_normals: Array[Vector3] = []

	# 1. Bottom Ground Contact Run (Rear -X to Front +X)
	var segs_bot = 16
	for i in range(segs_bot + 1):
		var t = float(i) / float(segs_bot)
		var x = lerp(idler_pos.x, sprocket_pos.x, t)
		path_points.append(Vector3(x, bot_y, z_pos))
		path_normals.append(Vector3.UP)

	# 2. Front Sprocket Wrap Arc (+X, XY plane)
	var segs_arc = 8
	var sprocket_r = radius * 0.9
	for i in range(1, segs_arc):
		var a = lerp(-PI * 0.5, PI * 0.5, float(i) / float(segs_arc))
		var pt = sprocket_pos + Vector3(cos(a) * sprocket_r, sin(a) * sprocket_r, 0.0)
		path_points.append(pt)
		path_normals.append(Vector3(cos(a), sin(a), 0.0).normalized())

	# 3. Top Return Run with Sag Curve between rollers (Front +X to Rear -X)
	var top_supports: Array[Vector3] = []
	top_supports.append(sprocket_pos + Vector3(0, sprocket_r, 0))
	for r_pos in rollers:
		top_supports.append(r_pos + Vector3(0, radius * 0.45, 0))
	var idler_r = radius * 0.85
	top_supports.append(idler_pos + Vector3(0, idler_r, 0))

	for s in range(top_supports.size() - 1):
		var p1 = top_supports[s]
		var p2 = top_supports[s + 1]
		var segs_span = 8

		for i in range(1, segs_span + 1):
			var t = float(i) / float(segs_span)
			var pos = p1.lerp(p2, t)
			var sag = sin(t * PI) * track_sag_m
			pos.y -= sag

			path_points.append(pos)
			path_normals.append(Vector3.DOWN)

	# 4. Rear Idler Wrap Arc (-X, XY plane)
	for i in range(1, segs_arc):
		var a = lerp(PI * 0.5, PI * 1.5, float(i) / float(segs_arc))
		var pt = idler_pos + Vector3(cos(a) * idler_r, sin(a) * idler_r, 0.0)
		path_points.append(pt)
		path_normals.append(Vector3(cos(a), sin(a), 0.0).normalized())

	# Extrude 3D Track Link geometry along Z width
	var total_pts = path_points.size()
	for i in range(total_pts):
		var i_next = (i + 1) % total_pts
		var p1 = path_points[i]
		var p2 = path_points[i_next]
		var norm1 = path_normals[i]
		var norm2 = path_normals[i_next]

		var u1 = float(i) * 0.5
		var u2 = float(i + 1) * 0.5

		# Outer track tread quad (extruding Z width)
		var a_out = p1 + Vector3(0, 0, -half_w)
		var b_out = p2 + Vector3(0, 0, -half_w)
		var c_out = p2 + Vector3(0, 0, half_w)
		var d_out = p1 + Vector3(0, 0, half_w)

		_add_quad_smooth_normal(st, a_out, b_out, c_out, d_out, -norm1, -norm2, -norm2, -norm1)

		# Inner track face quad
		var a_in = a_out + norm1 * track_thickness
		var b_in = b_out + norm2 * track_thickness
		var c_in = c_out + norm2 * track_thickness
		var d_in = d_out + norm1 * track_thickness

		_add_quad_smooth_normal(st, a_in, d_in, c_in, b_in, norm1, norm1, norm2, norm2)

		# Central Guide Horn Ridge
		var horn_w = 0.04
		var gh_a = p1 + norm1 * (track_thickness + guide_horn_h) + Vector3(0, 0, -horn_w)
		var gh_b = p2 + norm2 * (track_thickness + guide_horn_h) + Vector3(0, 0, -horn_w)
		var gh_c = p2 + norm2 * (track_thickness + guide_horn_h) + Vector3(0, 0, horn_w)
		var gh_d = p1 + norm1 * (track_thickness + guide_horn_h) + Vector3(0, 0, horn_w)

		_add_quad_smooth_normal(st, gh_a, gh_b, gh_c, gh_d, norm1, norm2, norm2, norm1)

	st.generate_tangents()
	mi.mesh = st.commit()
	if track_material:
		mi.material_override = track_material
	add_child(mi)

func _add_quad_flat_normal(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
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

func _add_quad_smooth_normal(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	st.set_normal(na)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)

	st.set_normal(nb)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)

	st.set_normal(nc)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)

	st.set_normal(na)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)

	st.set_normal(nc)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)

	st.set_normal(nd)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)

func _add_triangle_flat_normal(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)

	st.set_normal(n)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)

	st.set_normal(n)
	st.set_uv(Vector2(0.5, 1))
	st.add_vertex(c)

func set_chassis_parameters(count: int, diameter: float, width: float, clearance: float) -> void:
	self.road_wheels_count = count
	self.wheel_diameter = diameter
	self.track_width = width
	self.suspension_height = clearance
	generate_tracks_and_wheels()
