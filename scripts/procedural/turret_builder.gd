class_name TurretBuilder
extends Node3D

## Procedural high-detail hard-surface tank turret and main gun generator using SurfaceTool.
## Generates turret ring collar, sloped cheek armor, rear bustle/box, commander cupola,
## gun mantlet block, and barrel with multi-stage muzzle brake using explicit flat and radial normals.

signal turret_rotated(yaw_deg: float, pitch_deg: float)

enum TurretStyle { WEDGE_CHEEK, CAST_DOME, BOX_WELDED }

@export_group("Turret Dimensions")
@export var turret_style: TurretStyle = TurretStyle.WEDGE_CHEEK
@export_range(1.5, 4.5, 0.1) var turret_length: float = 3.2 ## Meters
@export_range(1.5, 4.5, 0.1) var turret_width: float = 2.8 ## Meters
@export_range(0.6, 2.0, 0.1) var turret_height: float = 1.1 ## Meters
@export_range(15.0, 75.0, 1.0) var cheek_angle_deg: float = 45.0 ## Wedge cheek slope angle
@export var turret_offset_x: float = 0.0
@export var turret_offset_z: float = 0.0

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
var static_collision_body: StaticBody3D = null
var collision_shape_node: CollisionShape3D = null

# Internal Aim state
var current_yaw_deg: float = 0.0
var current_pitch_deg: float = 0.0
var target_yaw_deg: float = 0.0
var target_pitch_deg: float = 0.0

var calculated_turret_mass_kg: float = 0.0
var armor_sandwich: ArmorCalculator.ArmorSandwich = null
var era_sectors: Dictionary = {}

var _mesh_update_pending: bool = false

func _ready() -> void:
	_setup_nodes()
	generate_turret_and_gun()

## Queue a deferred turret and gun mesh update (debounced for UI slider drags)
func queue_generate_turret_and_gun() -> void:
	if not is_inside_tree():
		generate_turret_and_gun()
		return
	if _mesh_update_pending:
		return
	_mesh_update_pending = true
	call_deferred("_do_generate_turret_and_gun")

func _do_generate_turret_and_gun() -> void:
	if not _mesh_update_pending:
		return
	_mesh_update_pending = false
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
	_mesh_update_pending = false
	_setup_nodes()
	_generate_turret_mesh()
	_generate_gun_mesh()
	_calculate_turret_mass()
	_update_collision_shape()

func _generate_turret_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_l = turret_length * 0.5
	var half_w = turret_width * 0.5
	var half_h = turret_height * 0.5

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
	# 2. MAIN TURRET BODY GEOMETRY BY TURRET STYLE
	# ---------------------------------------------------------
	match turret_style:
		TurretStyle.WEDGE_CHEEK:
			var cheek_offset = turret_height * tan(deg_to_rad(90.0 - cheek_angle_deg))
			cheek_offset = clamp(cheek_offset, 0.2, half_l * 0.7)

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
			_add_quad(st, v_top_bl, v_bot_bl, v_bot_cheek_l, v_cheek_l)
			_add_quad(st, v_cheek_r, v_bot_cheek_r, v_bot_br, v_top_br)

			# Bustle Box
			_add_bustle_box(st, half_l, half_w, half_h, v_top_bl, v_top_br, v_bot_bl, v_bot_br)

		TurretStyle.CAST_DOME:
			var slices = 16
			var stacks = 6
			var rx = half_l * 0.75
			var rz = half_w * 0.8
			var ry = turret_height * 0.95

			for j in range(stacks):
				var phi1 = (float(j) / float(stacks)) * (PI * 0.48)
				var phi2 = (float(j + 1) / float(stacks)) * (PI * 0.48)

				for i in range(slices):
					var theta1 = (float(i) / float(slices)) * TAU
					var theta2 = (float(i + 1) / float(slices)) * TAU

					var n11 = Vector3(cos(theta1) * cos(phi1), sin(phi1), sin(theta1) * cos(phi1)).normalized()
					var n21 = Vector3(cos(theta2) * cos(phi1), sin(phi1), sin(theta2) * cos(phi1)).normalized()
					var n12 = Vector3(cos(theta1) * cos(phi2), sin(phi2), sin(theta1) * cos(phi2)).normalized()
					var n22 = Vector3(cos(theta2) * cos(phi2), sin(phi2), sin(theta2) * cos(phi2)).normalized()

					var p11 = Vector3(cos(theta1) * cos(phi1) * rx, sin(phi1) * ry - half_h, sin(theta1) * cos(phi1) * rz)
					var p21 = Vector3(cos(theta2) * cos(phi1) * rx, sin(phi1) * ry - half_h, sin(theta2) * cos(phi1) * rz)
					var p12 = Vector3(cos(theta1) * cos(phi2) * rx, sin(phi2) * ry - half_h, sin(theta1) * cos(phi2) * rz)
					var p22 = Vector3(cos(theta2) * cos(phi2) * rx, sin(phi2) * ry - half_h, sin(theta2) * cos(phi2) * rz)

					_add_quad_smooth_normal(st, p11, p12, p22, p21, n11, n12, n22, n21)

			# Cap top center roof of cast dome
			var top_phi = (float(stacks) / float(stacks)) * (PI * 0.48)
			var top_y = sin(top_phi) * ry - half_h
			var center_top = Vector3(0.0, top_y + 0.02, 0.0)
			for i in range(slices):
				var theta1 = (float(i) / float(slices)) * TAU
				var theta2 = (float(i + 1) / float(slices)) * TAU
				var p1 = Vector3(cos(theta1) * cos(top_phi) * rx, top_y, sin(theta1) * cos(top_phi) * rz)
				var p2 = Vector3(cos(theta2) * cos(top_phi) * rx, top_y, sin(theta2) * cos(top_phi) * rz)
				_add_triangle(st, center_top, p2, p1)

			# Small rear bustle shelf for dome
			var b_top_fl = Vector3(-rx * 0.6, 0.0, -rz * 0.7)
			var b_top_fr = Vector3(-rx * 0.6, 0.0, rz * 0.7)
			var b_bot_fl = Vector3(-rx * 0.6, -half_h, -rz * 0.7)
			var b_bot_fr = Vector3(-rx * 0.6, -half_h, rz * 0.7)
			_add_bustle_box(st, half_l, half_w, half_h, b_top_fl, b_top_fr, b_bot_fl, b_bot_fr)

		TurretStyle.BOX_WELDED:
			var front_x = half_l * 0.75
			var bustle_start_x = -half_l * 0.25
			var box_w = half_w * 0.9

			var v_top_fl = Vector3(front_x, half_h, -box_w)
			var v_top_fr = Vector3(front_x, half_h, box_w)
			var v_top_bl = Vector3(bustle_start_x, half_h, -box_w)
			var v_top_br = Vector3(bustle_start_x, half_h, box_w)

			var v_bot_fl = Vector3(front_x, -half_h, -box_w)
			var v_bot_fr = Vector3(front_x, -half_h, box_w)
			var v_bot_bl = Vector3(bustle_start_x, -half_h, -box_w)
			var v_bot_br = Vector3(bustle_start_x, -half_h, box_w)

			# Flat Front Face (Normal +X)
			_add_quad(st, v_top_fr, v_bot_fr, v_bot_fl, v_top_fl)

			# Main Roof (Normal +Y)
			_add_quad(st, v_top_bl, v_top_fl, v_top_fr, v_top_br)

			# Main Floor (Normal -Y)
			_add_quad(st, v_bot_fl, v_bot_bl, v_bot_br, v_bot_fr)

			# Main Sides
			_add_quad(st, v_top_bl, v_bot_bl, v_bot_fl, v_top_fl)
			_add_quad(st, v_top_fr, v_bot_fr, v_bot_br, v_top_br)

			# Bustle Box
			_add_bustle_box(st, half_l, half_w, half_h, v_top_bl, v_top_br, v_bot_bl, v_bot_br)

	# Commander Cupola (common across styles)
	var cupola_pos = Vector3(-half_l * 0.1, half_h, -half_w * 0.35)
	if turret_style == TurretStyle.CAST_DOME:
		cupola_pos.y = half_h * 0.75
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
	turret_mesh_instance.position = Vector3(turret_offset_x, 0.0, turret_offset_z)
	if turret_material:
		turret_mesh_instance.material_override = turret_material

func _add_bustle_box(st: SurfaceTool, half_l: float, half_w: float, half_h: float, b_top_fl: Vector3, b_top_fr: Vector3, b_bot_fl: Vector3, b_bot_fr: Vector3) -> void:
	var bustle_end_x = -half_l * 1.15
	var bustle_w = half_w * 0.88
	var bustle_bot_y = -half_h * 0.2

	var b_top_bl = Vector3(bustle_end_x, half_h, -bustle_w)
	var b_top_br = Vector3(bustle_end_x, half_h, bustle_w)
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

func _generate_gun_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	gun_mantlet_node.position = Vector3(turret_length * 0.42 + turret_offset_x, 0.0, turret_offset_z)

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
	var surface_area_m2: float = 0.0
	if turret_mesh_instance != null and turret_mesh_instance.mesh != null:
		surface_area_m2 = TankStatsCalculator.calculate_mesh_surface_area(turret_mesh_instance.mesh)
	else:
		surface_area_m2 = 2.0 * (turret_length * turret_width + turret_length * turret_height + turret_width * turret_height) * 0.6
	var sandwich = armor_sandwich if armor_sandwich != null else ArmorCalculator.ArmorSandwich.create_default_turret()
	var cheek_mass = (surface_area_m2 * 0.45) * sandwich.get_area_mass_kg_m2()
	var side_rear_mass = (surface_area_m2 * 0.55) * (front_turret_armor_mm * 0.3 / 1000.0) * 7850.0
	var gun_mass = barrel_length * 450.0
	calculated_turret_mass_kg = cheek_mass + side_rear_mass + gun_mass

func _update_collision_shape() -> void:
	if turret_mesh_instance == null or turret_mesh_instance.mesh == null:
		return

	if static_collision_body == null:
		static_collision_body = StaticBody3D.new()
		static_collision_body.name = "TurretCollisionBody"
		turret_mesh_instance.add_child(static_collision_body)

	for child in static_collision_body.get_children():
		child.queue_free()

	collision_shape_node = CollisionShape3D.new()
	collision_shape_node.name = "CollisionShape3D"
	collision_shape_node.shape = turret_mesh_instance.mesh.create_trimesh_shape()
	static_collision_body.add_child(collision_shape_node)

	static_collision_body.set_meta("armor_sandwich", armor_sandwich)
	static_collision_body.set_meta("armor_thickness_mm", front_turret_armor_mm)
	static_collision_body.set_meta("armor_type", ArmorCalculator.ArmorType.COMPOSITE)

	# If attached to a RigidBody3D tank chassis, disable static_collision_body to prevent Jolt depenetration explosions
	var p = get_parent()
	if p is RigidBody3D or (p != null and p.get_parent() is RigidBody3D):
		static_collision_body.process_mode = Node.PROCESS_MODE_DISABLED
		collision_shape_node.disabled = true

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

func set_turret_dimensions(l: float, w: float, h: float, cheek_deg: float, b_length: float, front_armor: float, p_turret_style: TurretStyle = turret_style, immediate: bool = false) -> void:
	self.turret_length = l
	self.turret_width = w
	self.turret_height = h
	self.cheek_angle_deg = cheek_deg
	self.barrel_length = b_length
	self.front_turret_armor_mm = front_armor
	self.turret_style = p_turret_style
	if immediate:
		generate_turret_and_gun()
	else:
		queue_generate_turret_and_gun()

func set_turret_offset(x_off: float, z_off: float) -> void:
	self.turret_offset_x = x_off
	self.turret_offset_z = z_off
	position.x = x_off
	position.z = z_off

## Determine local armor sector name from world hit position
func get_sector_at(world_hit_pos: Vector3) -> String:
	var local_pos = to_local(world_hit_pos)
	var half_w = turret_width * 0.5
	var half_h = turret_height * 0.5

	if local_pos.y > half_h * 0.35:
		return "roof"
	elif local_pos.x > 0.0:
		if local_pos.z < -half_w * 0.2:
			return "cheek_left"
		elif local_pos.z > half_w * 0.2:
			return "cheek_right"
		else:
			return "mantlet_center"
	elif local_pos.x < -turret_length * 0.3:
		return "rear_bustle"
	else:
		if local_pos.z < 0.0:
			return "side_left"
		else:
			return "side_right"

## Get or initialize sector-specific ArmorSandwich for target tracking
func get_armor_sandwich_at(world_hit_pos: Vector3) -> ArmorCalculator.ArmorSandwich:
	var sector = get_sector_at(world_hit_pos)
	if era_sectors.has(sector):
		return era_sectors[sector] as ArmorCalculator.ArmorSandwich

	var base_sandwich = armor_sandwich if armor_sandwich != null else ArmorCalculator.ArmorSandwich.create_default_turret()
	var sector_sandwich = base_sandwich.duplicate_sandwich()
	era_sectors[sector] = sector_sandwich
	return sector_sandwich

func is_era_sector_spent(sector_name: String) -> bool:
	if era_sectors.has(sector_name):
		var s: ArmorCalculator.ArmorSandwich = era_sectors[sector_name]
		return s != null and s.era_detonated
	return false

func get_spent_era_sectors() -> Array[String]:
	var spent: Array[String] = []
	for sector_name in era_sectors:
		var s: ArmorCalculator.ArmorSandwich = era_sectors[sector_name]
		if s != null and s.era_detonated:
			spent.append(sector_name)
	return spent

func reset_era_sectors() -> void:
	era_sectors.clear()
