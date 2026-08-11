class_name TrackGenerator
extends Node3D

## Procedural Continuous Track Belt and Road Wheel Generator for Sprocket-style Editor.
## Builds dual-rim road wheels with hub caps, drive sprockets with radial teeth,
## skeletonized idler wheels, return rollers, and continuous track belt loops with realistic sag curves.

enum SuspensionType { TORSION_BAR, HYDROPNEUMATIC, LEAF_SPRING }

@export_group("Chassis Configuration")
@export_range(4, 8, 1) var road_wheels_count: int = 6 ## Pairs of road wheels per side
@export_range(0.3, 1.2, 0.05) var wheel_diameter: float = 0.65 ## Meters
@export_range(0.3, 0.9, 0.05) var track_width: float = 0.6 ## Meters
@export_range(0.3, 1.2, 0.05) var suspension_height: float = 0.6 ## Ground clearance
@export_range(1.2, 2.5, 0.1) var track_span_width: float = 1.6 ## Distance from vehicle center
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
	var start_z = -chassis_length * 0.5
	var end_z = chassis_length * 0.5

	for side in [-1.0, 1.0]: # Left (-1) and Right (1)
		var x_pos = side * track_span_width

		# 1. Drive Sprocket (Front) with teeth
		var sprocket_pos = Vector3(x_pos, 0.1, start_z - (wheel_radius * 1.3))
		var sprocket = _create_sprocket_mesh(wheel_radius * 0.9, track_width * 0.85, side)
		sprocket.position = sprocket_pos
		add_child(sprocket)

		# 2. Idler Wheel (Rear) with dished spokes
		var idler_pos = Vector3(x_pos, 0.1, end_z + (wheel_radius * 1.3))
		var idler = _create_idler_mesh(wheel_radius * 0.85, track_width * 0.85, side)
		idler.position = idler_pos
		add_child(idler)

		# 3. Dual Rim Road Wheels & Axle Hub Caps
		var wheel_y = -suspension_height * 0.5
		for i in range(road_wheels_count):
			var z_pos = start_z + (float(i) * wheel_diameter * 1.15)
			var wheel_pos = Vector3(x_pos, wheel_y, z_pos)
			var wheel = _create_dual_road_wheel_mesh(wheel_radius, track_width * 0.85, side)
			wheel.position = wheel_pos
			add_child(wheel)
			_wheel_nodes.append(wheel)

		# 4. Return Rollers (Upper Track Support)
		var return_roller_count = clamp(road_wheels_count - 2, 2, 4)
		var roller_positions: Array[Vector3] = []
		var roller_y = 0.35
		var roller_r = wheel_radius * 0.45

		for r in range(return_roller_count):
			var t_r = float(r + 1) / float(return_roller_count + 1)
			var r_z = lerp(sprocket_pos.z, idler_pos.z, t_r)
			var r_pos = Vector3(x_pos, roller_y, r_z)
			roller_positions.append(r_pos)

			var roller = _create_dual_road_wheel_mesh(roller_r, track_width * 0.7, side)
			roller.position = r_pos
			add_child(roller)

		# 5. Continuous Track Belt Loop with Realistic Sag Curve
		_build_track_loop_mesh(x_pos, sprocket_pos, idler_pos, roller_positions, wheel_radius, track_width, start_z, end_z)

## Creates a detailed Dual Rim Road Wheel (Inner Rim + Outer Rim + Rubber Tire + Central Axle Hub Cap)
func _create_dual_road_wheel_mesh(radius: float, width: float, side: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 24
	var rim_width = width * 0.38
	var gap = width * 0.24 # Gap down middle for track guide horn

	var rim_offsets = [-gap * 0.5 - rim_width * 0.5, gap * 0.5 + rim_width * 0.5]

	for offset in rim_offsets:
		var inner_r = radius * 0.72
		for i in range(sides):
			var a1 = (float(i) / float(sides)) * TAU
			var a2 = (float(i + 1) / float(sides)) * TAU
			var u1 = float(i) / float(sides)
			var u2 = float(i + 1) / float(sides)

			var x_in = offset - rim_width * 0.5
			var x_out = offset + rim_width * 0.5

			# Rubber Tire Outer Tread Ring
			var p1_l = Vector3(x_in, cos(a1) * radius, sin(a1) * radius)
			var p2_l = Vector3(x_in, cos(a2) * radius, sin(a2) * radius)
			var p1_r = Vector3(x_out, cos(a1) * radius, sin(a1) * radius)
			var p2_r = Vector3(x_out, cos(a2) * radius, sin(a2) * radius)

			_add_quad(st, p1_l, p2_l, p2_r, p1_r, Vector2(u1, 0), Vector2(u2, 0), Vector2(u2, 1), Vector2(u1, 1))

			# Metal Wheel Rim Dish Face
			var pr1_l = Vector3(x_in, cos(a1) * inner_r, sin(a1) * inner_r)
			var pr2_l = Vector3(x_in, cos(a2) * inner_r, sin(a2) * inner_r)
			var pr1_r = Vector3(x_out, cos(a1) * inner_r, sin(a1) * inner_r)
			var pr2_r = Vector3(x_out, cos(a2) * inner_r, sin(a2) * inner_r)

			_add_quad(st, pr1_l, pr2_l, p2_l, p1_l)
			_add_quad(st, p1_r, p2_r, pr2_r, pr1_r)

	# Central Axle Hub Cap
	var hub_r = radius * 0.32
	var hub_out_x = side * (width * 0.52)
	var hub_in_x = side * (width * 0.3)

	for i in range(16):
		var a1 = (float(i) / 16.0) * TAU
		var a2 = (float(i + 1) / 16.0) * TAU
		var hp1_in = Vector3(hub_in_x, cos(a1) * hub_r, sin(a1) * hub_r)
		var hp2_in = Vector3(hub_in_x, cos(a2) * hub_r, sin(a2) * hub_r)
		var hp1_out = Vector3(hub_out_x, cos(a1) * hub_r, sin(a1) * hub_r)
		var hp2_out = Vector3(hub_out_x, cos(a2) * hub_r, sin(a2) * hub_r)

		if side > 0:
			_add_quad(st, hp1_in, hp2_in, hp2_out, hp1_out)
		else:
			_add_quad(st, hp1_out, hp2_out, hp2_in, hp1_in)

		# Hub end cap disc
		var uv0 = Vector2(0.5, 0.5)
		var uv1 = Vector2(cos(a1)*0.5+0.5, sin(a1)*0.5+0.5)
		var uv2 = Vector2(cos(a2)*0.5+0.5, sin(a2)*0.5+0.5)
		var hub_center = Vector3(hub_out_x + side * 0.02, 0, 0)

		if side > 0:
			_add_triangle(st, hub_center, hp1_out, hp2_out, uv0, uv1, uv2)
		else:
			_add_triangle(st, hub_center, hp2_out, hp1_out, uv0, uv2, uv1)

	st.generate_normals()
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

	for ring_x in [-half_w, half_w]:
		for i in range(teeth_count):
			var a1 = (float(i) / float(teeth_count)) * TAU
			var a2 = (float(i + 0.5) / float(teeth_count)) * TAU
			var a3 = (float(i + 1.0) / float(teeth_count)) * TAU

			var p_base1 = Vector3(ring_x, cos(a1) * radius, sin(a1) * radius)
			var p_tip   = Vector3(ring_x, cos(a2) * (radius + 0.09), sin(a2) * (radius + 0.09))
			var p_base2 = Vector3(ring_x, cos(a3) * radius, sin(a3) * radius)

			# Tooth triangle
			if ring_x > 0:
				_add_triangle(st, p_base1, p_tip, p_base2)
			else:
				_add_triangle(st, p_base1, p_base2, p_tip)

			# Tooth thickness quad
			var p_tip_other = Vector3(ring_x - sign(ring_x) * 0.04, p_tip.y, p_tip.z)
			var p_b1_other  = Vector3(ring_x - sign(ring_x) * 0.04, p_base1.y, p_base1.z)
			_add_triangle(st, p_base1, p_tip, p_tip_other)
			_add_triangle(st, p_base1, p_tip_other, p_b1_other)

	st.generate_normals()
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
		var u1 = float(i) / float(sides)
		var u2 = float(i + 1) / float(sides)

		var p1_l = Vector3(-half_w, cos(a1) * radius, sin(a1) * radius)
		var p2_l = Vector3(-half_w, cos(a2) * radius, sin(a2) * radius)
		var p1_r = Vector3(half_w, cos(a1) * radius, sin(a1) * radius)
		var p2_r = Vector3(half_w, cos(a2) * radius, sin(a2) * radius)

		_add_quad(st, p1_l, p2_l, p2_r, p1_r, Vector2(u1, 0), Vector2(u2, 0), Vector2(u2, 1), Vector2(u1, 1))

		# Dished center cap
		var center_l = Vector3(-half_w * 0.7, 0, 0)
		var center_r = Vector3(half_w * 0.7, 0, 0)
		_add_triangle(st, center_l, p2_l, p1_l)
		_add_triangle(st, center_r, p1_r, p2_r)

	st.generate_normals()
	st.generate_tangents()
	mi.mesh = st.commit()
	if track_material:
		mi.material_override = track_material
	return mi

## Builds continuous track belt loop around sprockets, rollers, idler, and ground wheels with sag curve
func _build_track_loop_mesh(
	x_pos: float,
	sprocket_pos: Vector3,
	idler_pos: Vector3,
	rollers: Array[Vector3],
	radius: float,
	width: float,
	start_z: float,
	end_z: float
) -> void:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_w = width * 0.5
	var bot_y = -suspension_height * 0.5 - radius
	var track_thickness = 0.04
	var guide_horn_h = 0.07

	# Build path points around continuous track loop
	var path_points: Array[Vector3] = []
	var path_normals: Array[Vector3] = []

	# 1. Bottom Ground Contact Run (Front to Rear)
	var segs_bot = 16
	for i in range(segs_bot + 1):
		var t = float(i) / float(segs_bot)
		var z = lerp(sprocket_pos.z, idler_pos.z, t)
		path_points.append(Vector3(x_pos, bot_y, z))
		path_normals.append(Vector3.UP)

	# 2. Rear Idler Wrap Arc
	var segs_arc = 8
	var idler_r = radius * 0.85
	for i in range(1, segs_arc):
		var a = lerp(-PI * 0.5, PI * 0.5, float(i) / float(segs_arc))
		var pt = idler_pos + Vector3(0.0, sin(a) * idler_r, cos(a) * idler_r)
		path_points.append(pt)
		path_normals.append(Vector3(0, sin(a), cos(a)).normalized())

	# 3. Top Return Run with Sag Curve between rollers
	var top_supports: Array[Vector3] = []
	top_supports.append(idler_pos + Vector3(0, idler_r, 0))
	for r_pos in rollers:
		top_supports.append(r_pos + Vector3(0, radius * 0.45, 0))
	var sprocket_r = radius * 0.9
	top_supports.append(sprocket_pos + Vector3(0, sprocket_r, 0))

	# Reverse order for top run (Rear to Front)
	top_supports.reverse()

	for s in range(top_supports.size() - 1):
		var p1 = top_supports[s]
		var p2 = top_supports[s + 1]
		var segs_span = 8

		for i in range(1, segs_span + 1):
			var t = float(i) / float(segs_span)
			var pos = p1.lerp(p2, t)
			# Catenary / parabolic sag curve
			var sag = sin(t * PI) * track_sag_m
			pos.y -= sag

			path_points.append(pos)
			path_normals.append(Vector3.DOWN)

	# 4. Front Sprocket Wrap Arc
	for i in range(1, segs_arc):
		var a = lerp(PI * 0.5, PI * 1.5, float(i) / float(segs_arc))
		var pt = sprocket_pos + Vector3(0.0, sin(a) * sprocket_r, cos(a) * sprocket_r)
		path_points.append(pt)
		path_normals.append(Vector3(0, sin(a), cos(a)).normalized())

	# Extrude 3D Track Link geometry along path points
	var total_pts = path_points.size()
	for i in range(total_pts):
		var i_next = (i + 1) % total_pts
		var p1 = path_points[i]
		var p2 = path_points[i_next]
		var norm1 = path_normals[i]
		var norm2 = path_normals[i_next]

		var u1 = float(i) * 0.5
		var u2 = float(i + 1) * 0.5

		# Outer track tread quad
		var a_out = p1 + Vector3(-half_w, 0, 0)
		var b_out = p2 + Vector3(-half_w, 0, 0)
		var c_out = p2 + Vector3(half_w, 0, 0)
		var d_out = p1 + Vector3(half_w, 0, 0)

		_add_quad(st, a_out, b_out, c_out, d_out, Vector2(0, u1), Vector2(1, u1), Vector2(1, u2), Vector2(0, u2))

		# Inner track face quad
		var a_in = a_out + norm1 * track_thickness
		var b_in = b_out + norm2 * track_thickness
		var c_in = c_out + norm2 * track_thickness
		var d_in = d_out + norm1 * track_thickness

		_add_quad(st, d_in, c_in, b_in, a_in, Vector2(0, u1), Vector2(1, u1), Vector2(1, u2), Vector2(0, u2))

		# Central Guide Horn Ridge (runs down center of inner track face)
		var horn_w = 0.04
		var gh_a = p1 + norm1 * (track_thickness + guide_horn_h) + Vector3(-horn_w, 0, 0)
		var gh_b = p2 + norm2 * (track_thickness + guide_horn_h) + Vector3(-horn_w, 0, 0)
		var gh_c = p2 + norm2 * (track_thickness + guide_horn_h) + Vector3(horn_w, 0, 0)
		var gh_d = p1 + norm1 * (track_thickness + guide_horn_h) + Vector3(horn_w, 0, 0)

		_add_quad(st, gh_a, gh_b, gh_c, gh_d)

	st.generate_normals()
	st.generate_tangents()
	mi.mesh = st.commit()
	if track_material:
		mi.material_override = track_material
	add_child(mi)

func _add_triangle(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3,
	uv_a: Vector2 = Vector2(0, 0),
	uv_b: Vector2 = Vector2(1, 0),
	uv_c: Vector2 = Vector2(0.5, 1)
) -> void:
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_uv(uv_c)
	st.add_vertex(c)

func _add_quad(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	uv_a: Vector2 = Vector2(0, 0),
	uv_b: Vector2 = Vector2(1, 0),
	uv_c: Vector2 = Vector2(1, 1),
	uv_d: Vector2 = Vector2(0, 1)
) -> void:
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_uv(uv_c)
	st.add_vertex(c)

	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_uv(uv_c)
	st.add_vertex(c)
	st.set_uv(uv_d)
	st.add_vertex(d)

func set_chassis_parameters(count: int, diameter: float, width: float, clearance: float) -> void:
	self.road_wheels_count = count
	self.wheel_diameter = diameter
	self.track_width = width
	self.suspension_height = clearance
	generate_tracks_and_wheels()
