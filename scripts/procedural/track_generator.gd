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
	_ensure_default_material()
	_create_road_wheels_and_belts()

func _ensure_default_material() -> void:
	if track_material == null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.24, 0.26)
		mat.metallic = 0.45
		mat.roughness = 0.55
		track_material = mat

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
		sprocket.material_override = track_material
		add_child(sprocket)

		# 2. Idler Wheel (Rear, -X) with dished spokes
		var idler_pos = Vector3(rear_x - (wheel_radius * 1.3), 0.1, z_pos)
		var idler = _create_idler_mesh(wheel_radius * 0.85, track_width * 0.85, side)
		idler.position = idler_pos
		idler.material_override = track_material
		add_child(idler)

		# 3. Dual Rim Road Wheels & Axle Hub Caps along X axis
		var wheel_y = -suspension_height * 0.5
		for i in range(road_wheels_count):
			var x_pos = rear_x + (float(i) * wheel_diameter * 1.15)
			var wheel_pos = Vector3(x_pos, wheel_y, z_pos)
			var wheel = _create_dual_road_wheel_mesh(wheel_radius, track_width * 0.85, side)
			wheel.position = wheel_pos
			wheel.material_override = track_material
			add_child(wheel)
			_wheel_nodes.append(wheel)

		# 4. Return Rollers (Upper Track Support along X)
		var roller_count = max(2, int(road_wheels_count * 0.5))
		var roller_r = wheel_radius * 0.45
		var roller_y = suspension_height * 0.4
		var roller_positions: Array[Vector3] = []

		for i in range(roller_count):
			var t = (float(i) + 0.5) / float(roller_count)
			var rx = lerp(rear_x, front_x, t)
			var r_pos = Vector3(rx, roller_y, z_pos)
			roller_positions.append(r_pos)

			var roller = _create_dual_road_wheel_mesh(roller_r, track_width * 0.7, side)
			roller.position = r_pos
			roller.material_override = track_material
			add_child(roller)

		# 5. Continuous Track Belt Loop with Sag Curve along X axis
		_build_track_loop_mesh(z_pos, sprocket_pos, idler_pos, roller_positions, wheel_radius, track_width)

## Creates a detailed Dual Rim Road Wheel (Inner Rim + Outer Rim + Rubber Tire + Central Axle Hub Cap)
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

			var n1 = Vector3(cos(a1), sin(a1), 0.0)
			var n2 = Vector3(cos(a2), sin(a2), 0.0)

			var o1_in = Vector3(cos(a1) * inner_r, sin(a1) * inner_r, offset - rim_width * 0.5)
			var o2_in = Vector3(cos(a2) * inner_r, sin(a2) * inner_r, offset - rim_width * 0.5)
			var o1_out = Vector3(cos(a1) * radius, sin(a1) * radius, offset - rim_width * 0.5)
			var o2_out = Vector3(cos(a2) * radius, sin(a2) * radius, offset - rim_width * 0.5)

			var i1_in = Vector3(cos(a1) * inner_r, sin(a1) * inner_r, offset + rim_width * 0.5)
			var i2_in = Vector3(cos(a2) * inner_r, sin(a2) * inner_r, offset + rim_width * 0.5)
			var i1_out = Vector3(cos(a1) * radius, sin(a1) * radius, offset + rim_width * 0.5)
			var i2_out = Vector3(cos(a2) * radius, sin(a2) * radius, offset + rim_width * 0.5)

			# Rubber tread outer face
			_add_quad_smooth_normal(st, o1_out, o2_out, i2_out, i1_out, n1, n2, n2, n1)

			# Wheel dish rim face
			var cap_n = Vector3(0, 0, side)
			_add_quad_flat_normal(st, o1_in, o2_in, o2_out, o1_out, cap_n)

	# Axle hub cap
	var hub_r = radius * 0.35
	var hub_h = width * 0.15
	for i in range(sides):
		var a1 = (float(i) / float(sides)) * TAU
		var a2 = (float(i + 1) / float(sides)) * TAU
		var h1 = Vector3(cos(a1) * hub_r, sin(a1) * hub_r, side * (width * 0.5))
		var h2 = Vector3(cos(a2) * hub_r, sin(a2) * hub_r, side * (width * 0.5))
		var hc = Vector3(0, 0, side * (width * 0.5 + hub_h))
		_add_triangle_flat_normal(st, h1, h2, hc, Vector3(0, 0, side))

	st.generate_tangents()
	mi.mesh = st.commit()
	mi.material_override = track_material
	return mi

## Creates Drive Sprocket with radial teeth (Front, +X)
func _create_sprocket_mesh(radius: float, width: float, side: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var teeth_count = 14
	var tooth_h = radius * 0.22
	var hub_r = radius * 0.78

	for i in range(teeth_count):
		var a_center = (float(i) / float(teeth_count)) * TAU
		var a_step = (PI / float(teeth_count)) * 0.45

		var a1 = a_center - a_step
		var a2 = a_center + a_step

		var b1 = Vector3(cos(a1) * hub_r, sin(a1) * hub_r, -width * 0.5)
		var b2 = Vector3(cos(a2) * hub_r, sin(a2) * hub_r, -width * 0.5)
		var t1 = Vector3(cos(a_center) * (hub_r + tooth_h), sin(a_center) * (hub_r + tooth_h), -width * 0.5)

		var b1_back = Vector3(cos(a1) * hub_r, sin(a1) * hub_r, width * 0.5)
		var b2_back = Vector3(cos(a2) * hub_r, sin(a2) * hub_r, width * 0.5)
		var t1_back = Vector3(cos(a_center) * (hub_r + tooth_h), sin(a_center) * (hub_r + tooth_h), width * 0.5)

		var n_tooth = Vector3(cos(a_center), sin(a_center), 0.0)
		_add_triangle_flat_normal(st, b1, b2, t1, Vector3(0, 0, -1))
		_add_triangle_flat_normal(st, b2_back, b1_back, t1_back, Vector3(0, 0, 1))
		_add_quad_flat_normal(st, b1, t1, t1_back, b1_back, n_tooth)
		_add_quad_flat_normal(st, t1, b2, b2_back, t1_back, n_tooth)

	st.generate_tangents()
	mi.mesh = st.commit()
	mi.material_override = track_material
	return mi

## Creates Skeletonized Idler Wheel (Rear, -X)
func _create_idler_mesh(radius: float, width: float, side: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 20
	var rim_width = width * 0.35
	var rim_r_in = radius * 0.78

	for i in range(sides):
		var a1 = (float(i) / float(sides)) * TAU
		var a2 = (float(i + 1) / float(sides)) * TAU

		var n1 = Vector3(cos(a1), sin(a1), 0.0)
		var n2 = Vector3(cos(a2), sin(a2), 0.0)

		var o1 = Vector3(cos(a1) * radius, sin(a1) * radius, -rim_width * 0.5)
		var o2 = Vector3(cos(a2) * radius, sin(a2) * radius, -rim_width * 0.5)
		var o1_b = Vector3(cos(a1) * radius, sin(a1) * radius, rim_width * 0.5)
		var o2_b = Vector3(cos(a2) * radius, sin(a2) * radius, rim_width * 0.5)

		_add_quad_smooth_normal(st, o1, o2, o2_b, o1_b, n1, n2, n2, n1)

	# 6 Skeletonized Spokes
	var spoke_count = 6
	for i in range(spoke_count):
		var a = (float(i) / float(spoke_count)) * TAU
		var s_dir = Vector3(cos(a), sin(a), 0.0)
		var s_side = Vector3(-sin(a), cos(a), 0.0) * (radius * 0.1)

		var p1 = s_side - Vector3(0, 0, rim_width * 0.4)
		var p2 = -s_side - Vector3(0, 0, rim_width * 0.4)
		var p3 = s_dir * radius - s_side - Vector3(0, 0, rim_width * 0.4)
		var p4 = s_dir * radius + s_side - Vector3(0, 0, rim_width * 0.4)
		_add_quad_flat_normal(st, p1, p2, p3, p4, Vector3(0, 0, -1))

	st.generate_tangents()
	mi.mesh = st.commit()
	mi.material_override = track_material
	return mi

## Builds continuous Track Belt Loop around sprockets, idler, and road wheels with sag curve
func _build_track_loop_mesh(
	z_center: float,
	sprocket_pos: Vector3,
	idler_pos: Vector3,
	roller_positions: Array[Vector3],
	wheel_r: float,
	w_width: float
) -> void:
	var mi = MeshInstance3D.new()
	mi.name = "TrackLoop_Z%.1f" % z_center
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_w = w_width * 0.52
	var link_thick = 0.045
	var path_points: Array[Vector3] = []

	# Bottom run (Road Wheels ground run along X, from Front +X to Rear -X)
	var bot_y = -suspension_height * 0.5 - wheel_r
	var front_bottom_x = sprocket_pos.x - wheel_r * 0.5
	var rear_bottom_x = idler_pos.x + wheel_r * 0.5

	var ground_segs = 12
	for i in range(ground_segs + 1):
		var t = float(i) / float(ground_segs)
		var x = lerp(front_bottom_x, rear_bottom_x, t)
		path_points.append(Vector3(x, bot_y, z_center))

	# Rear Idler Curve (-X)
	var idler_segs = 8
	for i in range(1, idler_segs + 1):
		var angle = (float(i) / float(idler_segs)) * PI + (PI * 0.5)
		var x = idler_pos.x + cos(angle) * (wheel_r * 0.95)
		var y = idler_pos.y + sin(angle) * (wheel_r * 0.95)
		path_points.append(Vector3(x, y, z_center))

	# Top Run with Sag Curves over return rollers
	var top_segs = 14
	for i in range(1, top_segs):
		var t = float(i) / float(top_segs)
		var x = lerp(idler_pos.x, sprocket_pos.x, t)
		var base_y = lerp(idler_pos.y + wheel_r, sprocket_pos.y + wheel_r, t)

		# Add realistic catenary sag between rollers
		var sag = sin(t * PI) * track_sag_m
		var y = base_y - sag
		path_points.append(Vector3(x, y, z_center))

	# Front Sprocket Curve (+X)
	var sprocket_segs = 8
	for i in range(sprocket_segs):
		var angle = (float(i) / float(sprocket_segs)) * PI - (PI * 0.5)
		var x = sprocket_pos.x + cos(angle) * (wheel_r * 0.95)
		var y = sprocket_pos.y + sin(angle) * (wheel_r * 0.95)
		path_points.append(Vector3(x, y, z_center))

	# Build 3D Track Link Segments along path_points
	var pt_count = path_points.size()
	for i in range(pt_count):
		var p_curr = path_points[i]
		var p_next = path_points[(i + 1) % pt_count]

		var tangent = (p_next - p_curr).normalized()
		var norm = Vector3.UP.cross(tangent).normalized()
		if norm.length_squared() < 0.0001:
			norm = Vector3.BACK

		var p1_in = p_curr + Vector3(0, 0, -half_w)
		var p1_out = p_curr + Vector3(0, 0, half_w)
		var p2_in = p_next + Vector3(0, 0, -half_w)
		var p2_out = p_next + Vector3(0, 0, half_w)

		var p1_in_t = p1_in + norm * link_thick
		var p1_out_t = p1_out + norm * link_thick
		var p2_in_t = p2_in + norm * link_thick
		var p2_out_t = p2_out + norm * link_thick

		# Track shoe outer face
		_add_quad_flat_normal(st, p1_in_t, p1_out_t, p2_out_t, p2_in_t, norm)
		# Track guide horn pin in center
		var horn_c = (p_curr + p_next) * 0.5
		var horn_h = norm * (link_thick * 2.2)
		var h1 = horn_c + Vector3(0, 0, -0.04)
		var h2 = horn_c + Vector3(0, 0, 0.04)
		var h3 = horn_c + horn_h
		_add_triangle_flat_normal(st, h1, h2, h3, norm)

	st.generate_tangents()
	mi.mesh = st.commit()
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
