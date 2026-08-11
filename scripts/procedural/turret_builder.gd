class_name TurretBuilder
extends Node3D

## Procedural high-detail hard-surface tank turret and main gun generator using SurfaceTool.
## Generates turret ring collar, sloped cheek armor, rear bustle/box, commander cupola,
## gun mantlet block, and barrel with multi-stage muzzle brake using explicit flat and radial normals.

signal turret_rotated(yaw_deg: float, pitch_deg: float)

@export_group("Turret Dimensions")
@export_range(1.5, 4.5, 0.1) var turret_length: float = 3.2 ## Meters
@export_range(1.5, 4.5, 0.1) var turret_width: float = 2.8 ## Meters
@export_range(0.6, 2.0, 0.1) var turret_height: float = 1.1 ## Meters
@export_range(15.0, 75.0, 1.0) var cheek_angle_deg: float = 45.0 ## Wedge cheek slope angle

@export_group("Main Gun & Mantlet")
@export_range(3.0, 9.0, 0.1) var barrel_length: float = 6.2 ## Meters (e.g. 120mm/125mm L/55)
@export_range(0.08, 0.25, 0.01) var barrel_radius: float = 0.125 ## Meters
@export_range(-12.0, 0.0, 0.5) var min_pitch_deg: float = -8.0 ## Gun depression limit
@export_range(10.0, 40.0, 0.5) var max_pitch_deg: float = 20.0 ## Gun elevation limit
@export_range(5.0, 60.0, 1.0) var rotation_speed_deg_s: float = 35.0 ## Turret traverse speed

@export_group("Armor & Material")
@export_range(50.0, 1200.0, 10.0) var front_turret_armor_mm: float = 750.0 ## Cheeks armor RHA
@export var turret_material: Material

# Node references created dynamically
var turret_mesh_instance: MeshInstance3D
var gun_mantlet_node: Node3D
var gun_barrel_mesh_instance: MeshInstance3D

# Internal Aim state
var current_yaw_deg: float = 0.0
var current_pitch_deg: float = 0.0
var target_yaw_deg: float = 0.0
var target_pitch_deg: float = 0.0

var calculated_turret_mass_kg: float = 0.0

func _ready() -> void:
	_setup_nodes()
	generate_turret_and_gun()

func _setup_nodes() -> void:
	if turret_mesh_instance == null:
		turret_mesh_instance = MeshInstance3D.new()
		turret_mesh_instance.name = "TurretMesh"
		add_child(turret_mesh_instance)

	if gun_mantlet_node == null:
		gun_mantlet_node = Node3D.new()
		gun_mantlet_node.name = "GunMantletPivot"
		add_child(gun_mantlet_node)

	if gun_barrel_mesh_instance == null:
		gun_barrel_mesh_instance = MeshInstance3D.new()
		gun_barrel_mesh_instance.name = "GunBarrelMesh"
		gun_mantlet_node.add_child(gun_barrel_mesh_instance)

func _process(delta: float) -> void:
	_smooth_rotate_turret(delta)

## Generates 3D mesh for turret armor shell, ring base, bustle, cupola, mantlet, and gun barrel
func generate_turret_and_gun() -> void:
	_setup_nodes()
	_generate_turret_mesh()
	_generate_gun_mesh()
	_calculate_turret_mass()

func _generate_turret_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_l = turret_length * 0.5
	var half_w = turret_width * 0.5
	var half_h = turret_height * 0.5

	var cheek_offset = turret_height * tan(deg_to_rad(90.0 - cheek_angle_deg))
	cheek_offset = clamp(cheek_offset, 0.2, half_l * 0.7)

	# ---------------------------------------------------------
	# 1. TURRET RING BASE COLLAR (16-sided cylinder)
	# ---------------------------------------------------------
	var ring_r = half_w * 0.7
	var ring_h = 0.12
	var ring_bot_y = -half_h - ring_h
	var ring_top_y = -half_h
	var ring_sides = 16

	for i in range(ring_sides):
		var a1 = (float(i) / float(ring_sides)) * TAU
		var a2 = (float(i + 1) / float(ring_sides)) * TAU

		var n1 = Vector3(cos(a1), 0, sin(a1))
		var n2 = Vector3(cos(a2), 0, sin(a2))

		var p1_bot = Vector3(cos(a1) * ring_r, ring_bot_y, sin(a1) * ring_r)
		var p2_bot = Vector3(cos(a2) * ring_r, ring_bot_y, sin(a2) * ring_r)
		var p1_top = Vector3(cos(a1) * ring_r, ring_top_y, sin(a1) * ring_r)
		var p2_top = Vector3(cos(a2) * ring_r, ring_top_y, sin(a2) * ring_r)

		_add_quad_smooth_normal(st, p1_bot, p1_top, p2_top, p2_bot, n1, n1, n2, n2)

	# ---------------------------------------------------------
	# 2. MAIN TURRET BODY & SLOPED CHEEKS (Hard-surface flat plates)
	# ---------------------------------------------------------
	var v_front_top = Vector3(half_l * 0.85, half_h * 0.7, 0.0)
	var v_front_bot = Vector3(half_l * 0.85, -half_h * 0.6, 0.0)

	var v_cheek_l = Vector3(half_l - cheek_offset, half_h, -half_w)
	var v_cheek_r = Vector3(half_l - cheek_offset, half_h, half_w)
	var v_bot_cheek_l = Vector3(half_l - cheek_offset, -half_h, -half_w)
	var v_bot_cheek_r = Vector3(half_l - cheek_offset, -half_h, half_w)

	var bustle_start_x = -half_l * 0.25
	var v_top_bl = Vector3(bustle_start_x, half_h, -half_w * 0.95)
	var v_top_br = Vector3(bustle_start_x, half_h, half_w * 0.95)
	var v_bot_bl = Vector3(bustle_start_x, -half_h, -half_w * 0.95)
	var v_bot_br = Vector3(bustle_start_x, -half_h, half_w * 0.95)

	# Main Roof (Normal +Y)
	_add_quad(st, v_top_bl, v_cheek_l, v_cheek_r, v_top_br)
	_add_triangle(st, v_cheek_l, v_front_top, v_cheek_r)

	# Bottom Floor (Normal -Y)
	_add_quad(st, v_bot_cheek_l, v_bot_br, v_bot_bl, v_bot_cheek_r)
	_add_triangle(st, v_front_bot, v_bot_cheek_r, v_bot_cheek_l)

	# Front Cheeks
	_add_triangle(st, v_cheek_l, v_bot_cheek_l, v_front_top)
	_add_triangle(st, v_front_top, v_bot_cheek_l, v_front_bot)

	_add_triangle(st, v_front_top, v_bot_cheek_r, v_cheek_r)
	_add_triangle(st, v_front_top, v_front_bot, v_bot_cheek_r)

	# Main Turret Sides
	_add_quad(st, v_top_bl, v_bot_bl, v_bot_cheek_l, v_cheek_l) # Left side (-Z)
	_add_quad(st, v_cheek_r, v_bot_cheek_r, v_bot_br, v_top_br) # Right side (+Z)

	# ---------------------------------------------------------
	# 3. REAR BUSTLE BOX
	# ---------------------------------------------------------
	var bustle_end_x = -half_l * 1.15
	var bustle_w = half_w * 0.88
	var bustle_bot_y = -half_h * 0.2

	var b_top_fl = v_top_bl
	var b_top_fr = v_top_br
	var b_top_bl = Vector3(bustle_end_x, half_h, -bustle_w)
	var b_top_br = Vector3(bustle_end_x, half_h, bustle_w)

	var b_bot_fl = v_bot_bl
	var b_bot_fr = v_bot_br
	var b_bot_bl = Vector3(bustle_end_x, bustle_bot_y, -bustle_w)
	var b_bot_br = Vector3(bustle_end_x, bustle_bot_y, bustle_w)

	# Bustle roof
	_add_quad(st, b_top_bl, b_top_fl, b_top_fr, b_top_br)
	# Bustle angled floor
	_add_quad(st, b_bot_fl, b_bot_bl, b_bot_br, b_bot_fr)
	# Bustle rear plate
	_add_quad(st, b_top_br, b_top_bl, b_bot_bl, b_bot_br)
	# Bustle sides
	_add_quad(st, b_top_bl, b_bot_bl, b_bot_fl, b_top_fl)
	_add_quad(st, b_top_fr, b_bot_fr, b_bot_br, b_top_br)

	# ---------------------------------------------------------
	# 4. COMMANDER CUPOLA HATCH (Smooth Cylinder)
	# ---------------------------------------------------------
	var cupola_pos = Vector3(-half_l * 0.1, half_h, -half_w * 0.35)
	var cupola_r = 0.35
	var cupola_h = 0.16
	var cupola_sides = 16

	for i in range(cupola_sides):
		var a1 = (float(i) / float(cupola_sides)) * TAU
		var a2 = (float(i + 1) / float(cupola_sides)) * TAU

		var n1 = Vector3(cos(a1), 0, sin(a1))
		var n2 = Vector3(cos(a2), 0, sin(a2))

		var c1_bot = cupola_pos + Vector3(cos(a1) * cupola_r, 0.0, sin(a1) * cupola_r)
		var c2_bot = cupola_pos + Vector3(cos(a2) * cupola_r, 0.0, sin(a2) * cupola_r)
		var c1_top = cupola_pos + Vector3(cos(a1) * cupola_r, cupola_h, sin(a1) * cupola_r)
		var c2_top = cupola_pos + Vector3(cos(a2) * cupola_r, cupola_h, sin(a2) * cupola_r)

		_add_quad_smooth_normal(st, c1_bot, c1_top, c2_top, c2_bot, n1, n1, n2, n2)

		# Cupola roof hatch lid (Normal +Y)
		var cupola_center_top = cupola_pos + Vector3(0.0, cupola_h + 0.03, 0.0)
		_add_triangle(st, cupola_center_top, c2_top, c1_top)

	# Generate Tangents for triplanar mapping (preserves flat normals)
	st.generate_tangents()

	turret_mesh_instance.mesh = st.commit()
	if turret_material:
		turret_mesh_instance.material_override = turret_material

func _generate_gun_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	gun_mantlet_node.position = Vector3(turret_length * 0.42, 0.0, 0.0)

	# ---------------------------------------------------------
	# 1. GUN MANTLET BLOCK (Armored Housing Box)
	# ---------------------------------------------------------
	var m_l = 0.45
	var m_w = 0.4
	var m_h = 0.35

	var m_fl = Vector3(m_l, m_h, -m_w)
	var m_fr = Vector3(m_l, m_h, m_w)
	var m_bl = Vector3(-0.05, m_h * 1.05, -m_w * 1.05)
	var m_br = Vector3(-0.05, m_h * 1.05, m_w * 1.05)

	var mb_fl = Vector3(m_l, -m_h, -m_w)
	var mb_fr = Vector3(m_l, -m_h, m_w)
	var mb_bl = Vector3(-0.05, -m_h * 1.05, -m_w * 1.05)
	var mb_br = Vector3(-0.05, -m_h * 1.05, m_w * 1.05)

	_add_quad(st, m_fl, m_fr, mb_fr, mb_fl) # Front shield
	_add_quad(st, m_bl, mb_bl, mb_fl, m_fl) # Left side
	_add_quad(st, m_fr, mb_fr, mb_br, m_br) # Right side
	_add_quad(st, m_bl, m_fl, m_fr, m_br) # Top
	_add_quad(st, mb_bl, mb_br, mb_fr, mb_fl) # Bottom

	# ---------------------------------------------------------
	# 2. MAIN GUN BARREL & MUZZLE BRAKE (Cylindrical Smooth Radial Normals)
	# ---------------------------------------------------------
	var sides = 16
	var sleeve_start_x = barrel_length * 0.35
	var sleeve_end_x = barrel_length * 0.52
	var brake_start_x = barrel_length * 0.9
	var brake_end_x = barrel_length

	for i in range(sides):
		var a1 = (float(i) / float(sides)) * TAU
		var a2 = (float(i + 1) / float(sides)) * TAU

		var n1 = Vector3(0.0, cos(a1), sin(a1))
		var n2 = Vector3(0.0, cos(a2), sin(a2))

		# Base barrel cylinder
		var r1 = Vector3(0.0, cos(a1) * barrel_radius, sin(a1) * barrel_radius)
		var r2 = Vector3(0.0, cos(a2) * barrel_radius, sin(a2) * barrel_radius)

		var p1_base = r1 + Vector3(0.3, 0, 0)
		var p2_base = r2 + Vector3(0.3, 0, 0)
		var p1_tip = r1 + Vector3(brake_start_x, 0, 0)
		var p2_tip = r2 + Vector3(brake_start_x, 0, 0)

		_add_quad_smooth_normal(st, p1_base, p1_tip, p2_tip, p2_base, n1, n1, n2, n2)

		# Mid-barrel Thermal Sleeve / Evacuator bump
		var s_r1 = r1 * 1.3
		var s_r2 = r2 * 1.3
		var s1_start = s_r1 + Vector3(sleeve_start_x, 0, 0)
		var s2_start = s_r2 + Vector3(sleeve_start_x, 0, 0)
		var s1_end = s_r1 + Vector3(sleeve_end_x, 0, 0)
		var s2_end = s_r2 + Vector3(sleeve_end_x, 0, 0)

		_add_quad_smooth_normal(st, s1_start, s1_end, s2_end, s2_start, n1, n1, n2, n2)

		# Muzzle Brake collar at tip
		var b_r1 = r1 * 1.5
		var b_r2 = r2 * 1.5
		var b1_start = b_r1 + Vector3(brake_start_x, 0, 0)
		var b2_start = b_r2 + Vector3(brake_start_x, 0, 0)
		var b1_end = b_r1 + Vector3(brake_end_x, 0, 0)
		var b2_end = b_r2 + Vector3(brake_end_x, 0, 0)

		_add_quad_smooth_normal(st, b1_start, b1_end, b2_end, b2_start, n1, n1, n2, n2)

		# Front muzzle cap ring (Normal +X)
		_add_quad(st, b1_end, r1 + Vector3(brake_end_x, 0, 0), r2 + Vector3(brake_end_x, 0, 0), b2_end)

	st.generate_tangents()
	gun_barrel_mesh_instance.mesh = st.commit()
	if turret_material:
		gun_barrel_mesh_instance.material_override = turret_material

func _add_quad(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	uv_a: Vector2 = Vector2(0, 0),
	uv_b: Vector2 = Vector2(1, 0),
	uv_c: Vector2 = Vector2(1, 1),
	uv_d: Vector2 = Vector2(0, 1)
) -> void:
	var n = (b - a).cross(d - a).normalized()
	if n.length_squared() < 0.0001:
		n = Vector3.UP

	st.set_normal(n)
	st.set_uv(uv_a)
	st.add_vertex(a)

	st.set_normal(n)
	st.set_uv(uv_b)
	st.add_vertex(b)

	st.set_normal(n)
	st.set_uv(uv_c)
	st.add_vertex(c)

	st.set_normal(n)
	st.set_uv(uv_a)
	st.add_vertex(a)

	st.set_normal(n)
	st.set_uv(uv_c)
	st.add_vertex(c)

	st.set_normal(n)
	st.set_uv(uv_d)
	st.add_vertex(d)

func _add_quad_smooth_normal(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3
) -> void:
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

func _add_triangle(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3,
	uv_a: Vector2 = Vector2(0, 0),
	uv_b: Vector2 = Vector2(1, 0),
	uv_c: Vector2 = Vector2(0.5, 1)
) -> void:
	var n = (b - a).cross(c - a).normalized()
	if n.length_squared() < 0.0001:
		n = Vector3.UP

	st.set_normal(n)
	st.set_uv(uv_a)
	st.add_vertex(a)

	st.set_normal(n)
	st.set_uv(uv_b)
	st.add_vertex(b)

	st.set_normal(n)
	st.set_uv(uv_c)
	st.add_vertex(c)

func _calculate_turret_mass() -> void:
	var turret_vol = turret_length * turret_width * turret_height * 0.75
	var armor_m = front_turret_armor_mm / 1000.0
	calculated_turret_mass_kg = turret_vol * armor_m * 7850.0 + (barrel_length * 450.0)

func _smooth_rotate_turret(delta: float) -> void:
	var step = rotation_speed_deg_s * delta
	current_yaw_deg = move_toward(current_yaw_deg, target_yaw_deg, step)
	current_pitch_deg = move_toward(current_pitch_deg, target_pitch_deg, step)

	self.rotation_degrees.y = current_yaw_deg
	if gun_mantlet_node:
		gun_mantlet_node.rotation_degrees.z = current_pitch_deg

	turret_rotated.emit(current_yaw_deg, current_pitch_deg)

func set_aim_target(yaw_deg: float, pitch_deg: float) -> void:
	target_yaw_deg = yaw_deg
	target_pitch_deg = clamp(pitch_deg, min_pitch_deg, max_pitch_deg)

func set_turret_dimensions(l: float, w: float, h: float, cheek_deg: float, b_length: float, front_armor: float) -> void:
	self.turret_length = l
	self.turret_width = w
	self.turret_height = h
	self.cheek_angle_deg = cheek_deg
	self.barrel_length = b_length
	self.front_turret_armor_mm = front_armor
	generate_turret_and_gun()
