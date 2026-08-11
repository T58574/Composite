class_name HullBuilder
extends MeshInstance3D

## Procedural high-detail tank hull generator using SurfaceTool & MeshDataTool.
## Generates sloped upper & lower glacis, side sponson overhangs, engine deck grills,
## driver hatch bump, side skirts, rear plate, and chamfered edges.
## Calculates volume, mass, and Jolt convex collision shape.

@export_group("Hull Dimensions")
@export_range(2.0, 10.0, 0.1) var length: float = 6.8 ## Meters
@export_range(1.5, 5.0, 0.1) var width: float = 3.4 ## Meters
@export_range(0.5, 2.5, 0.1) var height: float = 1.4 ## Meters
@export_range(10.0, 80.0, 1.0) var front_glacis_angle_deg: float = 60.0 ## Front slope angle (deg)
@export_range(0.1, 0.5, 0.02) var sponson_width_ratio: float = 0.25 ## Sponson overhang fraction of width
@export_range(0.1, 0.8, 0.05) var skirt_depth: float = 0.35 ## Side skirt drop below sponson

@export_group("Armor Parameters")
@export_range(10.0, 1000.0, 5.0) var front_armor_mm: float = 450.0 ## Front armor thickness in mm RHA
@export_range(10.0, 500.0, 5.0) var side_armor_mm: float = 80.0 ## Side armor thickness in mm RHA
@export_range(10.0, 300.0, 5.0) var rear_armor_mm: float = 50.0 ## Rear armor thickness in mm RHA
@export_range(500.0, 8000.0, 50.0) var armor_density_kg_m3: float = 7850.0 ## Steel density (kg/m3)

@export_group("Material")
@export var hull_material: Material

# Calculated output stats
var calculated_volume_m3: float = 0.0
var calculated_mass_kg: float = 0.0
var static_collision_body: StaticBody3D = null
var collision_shape_node: CollisionShape3D = null

func _ready() -> void:
	generate_hull_mesh()

## Generate high-detail 3D Hull Mesh programmatically via SurfaceTool
func generate_hull_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_l = length * 0.5
	var half_w = width * 0.5
	var half_h = height * 0.5

	# Sponson overhang parameters
	var belly_w = half_w * (1.0 - sponson_width_ratio)
	var sponson_y = -half_h * 0.1

	# Front glacis offsets based on angle
	var glacis_x_offset = height * tan(deg_to_rad(90.0 - front_glacis_angle_deg))
	glacis_x_offset = clamp(glacis_x_offset, 0.3, half_l * 0.85)

	var top_front_x = half_l - glacis_x_offset
	var nose_x = half_l + 0.15
	var nose_y = sponson_y
	var nose_w = belly_w * 0.85

	var engine_x = -half_l * 0.1

	# ---------------------------------------------------------
	# 1. LOWER BELLY & LOWER GLACIS
	# ---------------------------------------------------------
	var v_belly_bl = Vector3(-half_l + 0.3, -half_h, -belly_w)
	var v_belly_br = Vector3(-half_l + 0.3, -half_h, belly_w)
	var v_belly_fl = Vector3(half_l * 0.6, -half_h, -belly_w)
	var v_belly_fr = Vector3(half_l * 0.6, -half_h, belly_w)

	var v_nose_l = Vector3(nose_x, nose_y, -nose_w)
	var v_nose_r = Vector3(nose_x, nose_y, nose_w)

	# Belly bottom face
	_add_quad(st, v_belly_fl, v_belly_fr, v_belly_br, v_belly_bl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# Lower Glacis (front bottom slope)
	_add_quad(st, v_nose_l, v_nose_r, v_belly_fr, v_belly_fl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# ---------------------------------------------------------
	# 2. SIDE SPONSON OVERHANGS (UNDER-SPONSON SLOPES & OUTER WALLS)
	# ---------------------------------------------------------
	# Sponson floor outer edges
	var v_spons_fl = Vector3(half_l * 0.6, sponson_y, -half_w)
	var v_spons_fr = Vector3(half_l * 0.6, sponson_y, half_w)
	var v_spons_bl = Vector3(-half_l + 0.3, sponson_y, -half_w)
	var v_spons_br = Vector3(-half_l + 0.3, sponson_y, half_w)

	# Under-sponson sloped plates (Left & Right)
	_add_quad(st, v_belly_fl, v_spons_fl, v_spons_bl, v_belly_bl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_add_quad(st, v_spons_fr, v_belly_fr, v_belly_br, v_spons_br, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# Top deck outer edges
	var v_top_fl = Vector3(top_front_x, half_h, -half_w)
	var v_top_fr = Vector3(top_front_x, half_h, half_w)
	var v_top_bl = Vector3(-half_l, half_h, -half_w)
	var v_top_br = Vector3(-half_l, half_h, half_w)

	# Sponson side outer walls
	_add_quad(st, v_top_bl, v_top_fl, v_spons_fl, v_spons_bl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_add_quad(st, v_top_fr, v_top_br, v_spons_br, v_spons_fr, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# ---------------------------------------------------------
	# 3. UPPER GLACIS & CHAMFERED CORNERS
	# ---------------------------------------------------------
	var upper_glacis_w = half_w * 0.75
	var v_glacis_top_l = Vector3(top_front_x, half_h, -upper_glacis_w)
	var v_glacis_top_r = Vector3(top_front_x, half_h, upper_glacis_w)

	# Central Upper Glacis plate
	_add_quad(st, v_glacis_top_l, v_glacis_top_r, v_nose_r, v_nose_l, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# Front chamfered glacis cheek triangles (transition to sponson front)
	_add_quad(st, v_top_fl, v_glacis_top_l, v_nose_l, v_spons_fl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_add_quad(st, v_glacis_top_r, v_top_fr, v_spons_fr, v_nose_r, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# Front nose cap between sponsons
	_add_quad(st, v_spons_fl, v_nose_l, v_nose_r, v_spons_fr, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# ---------------------------------------------------------
	# 4. UPPER CREW DECK & ENGINE DECK GRILLS
	# ---------------------------------------------------------
	var v_eng_l = Vector3(engine_x, half_h, -half_w)
	var v_eng_r = Vector3(engine_x, half_h, half_w)

	# Front crew roof deck
	_add_quad(st, v_eng_l, v_eng_r, v_top_fr, v_top_fl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# Engine deck base panel
	_add_quad(st, v_top_bl, v_top_br, v_eng_r, v_eng_l, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# Engine deck ventilation grill louvres (raised details)
	var grill_w = half_w * 0.55
	var grill_start_x = engine_x - 0.15
	var grill_end_x = -half_l + 0.35
	var grill_h = 0.04

	var g_tl = Vector3(grill_start_x, half_h + grill_h, -grill_w)
	var g_tr = Vector3(grill_start_x, half_h + grill_h, grill_w)
	var g_bl = Vector3(grill_end_x, half_h + grill_h, -grill_w)
	var g_br = Vector3(grill_end_x, half_h + grill_h, grill_w)

	_add_quad(st, g_bl, g_br, g_tr, g_tl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	# Grill sides
	_add_quad(st, Vector3(grill_start_x, half_h, -grill_w), g_tl, g_bl, Vector3(grill_end_x, half_h, -grill_w))
	_add_quad(st, g_tr, Vector3(grill_start_x, half_h, grill_w), Vector3(grill_end_x, half_h, grill_w), g_br)
	_add_quad(st, g_tl, g_tr, Vector3(grill_start_x, half_h, grill_w), Vector3(grill_start_x, half_h, -grill_w))
	_add_quad(st, Vector3(grill_end_x, half_h, -grill_w), Vector3(grill_end_x, half_h, grill_w), g_br, g_bl)

	# ---------------------------------------------------------
	# 5. DRIVER HATCH BUMP
	# ---------------------------------------------------------
	var hatch_x = top_front_x * 0.7
	var hatch_z = -half_w * 0.35
	var hatch_l = 0.45
	var hatch_w = 0.4
	var hatch_h = 0.12

	var h_fl = Vector3(hatch_x + hatch_l * 0.5, half_h + hatch_h, hatch_z - hatch_w * 0.5)
	var h_fr = Vector3(hatch_x + hatch_l * 0.5, half_h + hatch_h, hatch_z + hatch_w * 0.5)
	var h_bl = Vector3(hatch_x - hatch_l * 0.5, half_h + hatch_h, hatch_z - hatch_w * 0.5)
	var h_br = Vector3(hatch_x - hatch_l * 0.5, half_h + hatch_h, hatch_z + hatch_w * 0.5)

	var hb_fl = Vector3(hatch_x + hatch_l * 0.6, half_h, hatch_z - hatch_w * 0.55)
	var hb_fr = Vector3(hatch_x + hatch_l * 0.6, half_h, hatch_z + hatch_w * 0.55)
	var hb_bl = Vector3(hatch_x - hatch_l * 0.55, half_h, hatch_z - hatch_w * 0.55)
	var hb_br = Vector3(hatch_x - hatch_l * 0.55, half_h, hatch_z + hatch_w * 0.55)

	_add_quad(st, h_bl, h_br, h_fr, h_fl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_add_quad(st, hb_fl, hb_fr, h_fr, h_fl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)) # Front sloped visor
	_add_quad(st, hb_bl, hb_fl, h_fl, h_bl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_add_quad(st, hb_fr, hb_br, h_br, h_fr, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_add_quad(st, hb_br, hb_bl, h_bl, h_br, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# ---------------------------------------------------------
	# 6. REAR HULL PLATE & EXHAUST BOX
	# ---------------------------------------------------------
	var v_rear_top_l = Vector3(-half_l, half_h, -half_w)
	var v_rear_top_r = Vector3(-half_l, half_h, half_w)
	var v_rear_bot_l = Vector3(-half_l + 0.3, -half_h, -belly_w)
	var v_rear_bot_r = Vector3(-half_l + 0.3, -half_h, belly_w)

	# Main sloped rear plate
	_add_quad(st, v_rear_top_r, v_rear_top_l, v_rear_bot_l, v_rear_bot_r, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# Rear chamfered corner fills
	_add_triangle(st, v_rear_top_l, v_spons_bl, v_rear_bot_l)
	_add_triangle(st, v_rear_top_r, v_rear_bot_r, v_spons_br)

	# Exhaust box protruding on rear plate
	var ex_w = half_w * 0.4
	var ex_h = 0.25
	var ex_depth = 0.18
	var ex_y = 0.0

	var ex_tl = Vector3(-half_l - ex_depth, ex_y + ex_h, -ex_w)
	var ex_tr = Vector3(-half_l - ex_depth, ex_y + ex_h, ex_w)
	var ex_bl = Vector3(-half_l - ex_depth, ex_y - ex_h, -ex_w)
	var ex_br = Vector3(-half_l - ex_depth, ex_y - ex_h, ex_w)

	var ex_stl = Vector3(-half_l + 0.1, ex_y + ex_h, -ex_w)
	var ex_str = Vector3(-half_l + 0.1, ex_y + ex_h, ex_w)
	var ex_sbl = Vector3(-half_l + 0.15, ex_y - ex_h, -ex_w)
	var ex_sbr = Vector3(-half_l + 0.15, ex_y - ex_h, ex_w)

	_add_quad(st, ex_tr, ex_tl, ex_bl, ex_br, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	_add_quad(st, ex_stl, ex_str, ex_tr, ex_tl)
	_add_quad(st, ex_bl, ex_br, ex_sbr, ex_sbl)
	_add_quad(st, ex_tl, ex_stl, ex_sbl, ex_bl)
	_add_quad(st, ex_str, ex_tr, ex_br, ex_sbr)

	# ---------------------------------------------------------
	# 7. SIDE SKIRTS & MUDGUARDS
	# ---------------------------------------------------------
	var skirt_y_bot = sponson_y - skirt_depth
	for side in [-1.0, 1.0]:
		var z_out = side * (half_w + 0.02)
		var z_in = side * half_w

		# Front mudguard curve
		var mg_front_x = half_l + 0.2
		var mg_top = Vector3(top_front_x, half_h - 0.05, z_out)
		var mg_front = Vector3(mg_front_x, sponson_y - 0.05, z_out)
		var mg_bot = Vector3(mg_front_x - 0.2, skirt_y_bot, z_out)

		_add_triangle(st, mg_top, mg_front, mg_bot)

		# Main hanging skirt panel
		var sk_fl = Vector3(mg_front_x - 0.2, sponson_y, z_out)
		var sk_fr = Vector3(-half_l + 0.1, sponson_y, z_out)
		var sk_bl = Vector3(mg_front_x - 0.2, skirt_y_bot, z_out)
		var sk_br = Vector3(-half_l + 0.1, skirt_y_bot, z_out)

		if side > 0:
			_add_quad(st, sk_fl, sk_fr, sk_br, sk_bl, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		else:
			_add_quad(st, sk_fr, sk_fl, sk_bl, sk_br, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))

	# ---------------------------------------------------------
	# NORMALS, TANGENTS & MESH COMMIT
	# ---------------------------------------------------------
	st.generate_normals()
	st.generate_tangents()

	var generated_mesh = st.commit()
	self.mesh = generated_mesh

	if hull_material:
		self.material_override = hull_material

	_calculate_physical_properties()
	_update_collision_shape()

## Helper function to add a quad with explicit UVs for each vertex
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

## Helper function to add a triangle with explicit UVs for each vertex
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

func _calculate_physical_properties() -> void:
	# Refined volume calculation considering sloped glacis and sponson volume
	calculated_volume_m3 = length * width * height * 0.82

	# Hull surface area calculation for mass estimation
	var surface_area_m2 = 2.3 * (length * width + length * height + width * height)
	var avg_armor_thickness_m = ((front_armor_mm * 0.4) + (side_armor_mm * 0.4) + (rear_armor_mm * 0.2)) / 1000.0

	# Mass of steel armor hull (kg)
	calculated_mass_kg = surface_area_m2 * avg_armor_thickness_m * armor_density_kg_m3

func _update_collision_shape() -> void:
	if mesh == null:
		return

	if static_collision_body == null:
		static_collision_body = StaticBody3D.new()
		static_collision_body.name = "HullCollisionBody"
		add_child(static_collision_body)

	if collision_shape_node == null:
		collision_shape_node = CollisionShape3D.new()
		collision_shape_node.name = "CollisionShape3D"
		static_collision_body.add_child(collision_shape_node)

	collision_shape_node.shape = mesh.create_convex_shape()

## Public API to update hull dimensions dynamically from UI
func set_dimensions(p_length: float, p_width: float, p_height: float, p_glacis_angle: float) -> void:
	self.length = p_length
	self.width = p_width
	self.height = p_height
	self.front_glacis_angle_deg = p_glacis_angle
	generate_hull_mesh()
