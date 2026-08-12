class_name HullBuilder
extends MeshInstance3D

## Procedural hard-surface tank hull generator using SurfaceTool & MeshDataTool.
## Generates a clean sloped base tank hull: upper & lower glacis, side sponson overhangs,
## roof deck, and rear plate with explicit flat normals and solid CCW face winding.

@export_group("Hull Dimensions")
@export_range(2.0, 10.0, 0.1) var length: float = 6.8 ## Meters
@export_range(1.5, 5.0, 0.1) var width: float = 3.4 ## Meters
@export_range(0.5, 2.5, 0.1) var height: float = 1.4 ## Meters
@export_range(10.0, 80.0, 1.0) var front_glacis_angle_deg: float = 60.0 ## Front slope angle (deg)
@export_range(0.1, 0.5, 0.02) var sponson_width_ratio: float = 0.25 ## Sponson overhang fraction of width

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
var armor_sandwich: ArmorCalculator.ArmorSandwich = null
var era_sectors: Dictionary = {}
var static_collision_body: StaticBody3D = null
var collision_shape_node: CollisionShape3D = null

func _ready() -> void:
	generate_hull_mesh()

## Generate clean hard-surface 3D Base Hull Mesh via SurfaceTool with explicit flat normals
func generate_hull_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_l = length * 0.5
	var half_w = width * 0.5
	var half_h = height * 0.5

	# Sponson overhang parameters
	var belly_w = half_w * (1.0 - sponson_width_ratio)
	var sponson_y = -half_h * 0.15

	# Front glacis offset based on angle
	var glacis_x_offset = height * tan(deg_to_rad(90.0 - front_glacis_angle_deg))
	glacis_x_offset = clamp(glacis_x_offset, 0.3, half_l * 0.85)

	var top_front_x = half_l - glacis_x_offset
	var nose_x = half_l + 0.15
	var nose_y = sponson_y
	var nose_w = belly_w * 0.85

	# ---------------------------------------------------------
	# 1. LOWER BELLY & LOWER GLACIS
	# ---------------------------------------------------------
	var v_belly_bl = Vector3(-half_l + 0.3, -half_h, -belly_w)
	var v_belly_br = Vector3(-half_l + 0.3, -half_h, belly_w)
	var v_belly_fl = Vector3(half_l * 0.6, -half_h, -belly_w)
	var v_belly_fr = Vector3(half_l * 0.6, -half_h, belly_w)

	var v_nose_l = Vector3(nose_x, nose_y, -nose_w)
	var v_nose_r = Vector3(nose_x, nose_y, nose_w)

	# Belly bottom face (Normal -Y)
	_add_quad(st, v_belly_fl, v_belly_fr, v_belly_br, v_belly_bl)

	# Lower Glacis (Normal +X, -Y)
	_add_quad(st, v_nose_l, v_nose_r, v_belly_fr, v_belly_fl)

	# ---------------------------------------------------------
	# 2. SIDE SPONSON OVERHANGS
	# ---------------------------------------------------------
	var v_spons_fl = Vector3(half_l * 0.6, sponson_y, -half_w)
	var v_spons_fr = Vector3(half_l * 0.6, sponson_y, half_w)
	var v_spons_bl = Vector3(-half_l + 0.3, sponson_y, -half_w)
	var v_spons_br = Vector3(-half_l + 0.3, sponson_y, half_w)

	# Under-sponson sloped plates (Left & Right)
	_add_quad(st, v_belly_fl, v_belly_bl, v_spons_bl, v_spons_fl)
	_add_quad(st, v_spons_fr, v_spons_br, v_belly_br, v_belly_fr)

	# Top deck outer edges
	var v_top_fl = Vector3(top_front_x, half_h, -half_w)
	var v_top_fr = Vector3(top_front_x, half_h, half_w)
	var v_top_bl = Vector3(-half_l, half_h, -half_w)
	var v_top_br = Vector3(-half_l, half_h, half_w)

	# Sponson side outer walls (Solid CCW order)
	_add_quad(st, v_top_bl, v_spons_bl, v_spons_fl, v_top_fl) # Left side (-Z)
	_add_quad(st, v_top_fr, v_spons_fr, v_spons_br, v_top_br) # Right side (+Z)

	# ---------------------------------------------------------
	# 3. UPPER GLACIS & FRONT NOSE
	# ---------------------------------------------------------
	var upper_glacis_w = half_w * 0.75
	var v_glacis_top_l = Vector3(top_front_x, half_h, -upper_glacis_w)
	var v_glacis_top_r = Vector3(top_front_x, half_h, upper_glacis_w)

	# Central Upper Glacis plate (Normal +X, +Y)
	_add_quad(st, v_glacis_top_l, v_nose_l, v_nose_r, v_glacis_top_r)

	# Front cheek transitions to sponsons
	_add_quad(st, v_top_fl, v_spons_fl, v_nose_l, v_glacis_top_l)
	_add_quad(st, v_glacis_top_r, v_nose_r, v_spons_fr, v_top_fr)

	# Front nose cap
	_add_quad(st, v_spons_fl, v_spons_fr, v_nose_r, v_nose_l)

	# ---------------------------------------------------------
	# 4. UPPER CREW DECK & ENGINE DECK
	# ---------------------------------------------------------
	# Roof deck
	_add_quad(st, v_top_fl, v_top_bl, v_top_br, v_top_fr)

	# ---------------------------------------------------------
	# 5. REAR HULL PLATE
	# ---------------------------------------------------------
	var v_rear_top_l = Vector3(-half_l, half_h, -half_w)
	var v_rear_top_r = Vector3(-half_l, half_h, half_w)
	var v_rear_bot_l = Vector3(-half_l + 0.3, -half_h, -belly_w)
	var v_rear_bot_r = Vector3(-half_l + 0.3, -half_h, belly_w)

	# Main sloped rear plate (Normal -X)
	_add_quad(st, v_rear_top_r, v_rear_bot_r, v_rear_bot_l, v_rear_top_l)

	# Rear corner fills
	_add_triangle(st, v_rear_top_l, v_spons_bl, v_rear_bot_l)
	_add_triangle(st, v_rear_top_r, v_rear_bot_r, v_spons_br)

	# ---------------------------------------------------------
	# GENERATE TANGENTS & COMMIT
	# ---------------------------------------------------------
	st.generate_tangents()

	var generated_mesh = st.commit()
	self.mesh = generated_mesh

	if hull_material:
		self.material_override = hull_material

	_calculate_physical_properties()
	_update_collision_shape()

## Helper function to add a quad with explicit flat normal calculation
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

## Helper function to add a triangle with explicit flat normal calculation
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

func _calculate_physical_properties() -> void:
	var surface_area_m2: float = 0.0
	if mesh != null:
		calculated_volume_m3 = TankStatsCalculator.calculate_mesh_volume(mesh)
		surface_area_m2 = TankStatsCalculator.calculate_mesh_surface_area(mesh)
	else:
		calculated_volume_m3 = length * width * height
		surface_area_m2 = 2.0 * (length * width + length * height + width * height)
	var sandwich = armor_sandwich if armor_sandwich != null else ArmorCalculator.ArmorSandwich.create_default_glacis()
	var front_mass = (surface_area_m2 * 0.4) * sandwich.get_area_mass_kg_m2()
	var side_mass = (surface_area_m2 * 0.4) * (side_armor_mm / 1000.0) * 7850.0
	var rear_mass = (surface_area_m2 * 0.2) * (rear_armor_mm / 1000.0) * 7850.0
	calculated_mass_kg = front_mass + side_mass + rear_mass

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

	if armor_sandwich == null:
		armor_sandwich = ArmorCalculator.ArmorSandwich.create_default_glacis()

	static_collision_body.set_meta("armor_sandwich", armor_sandwich)
	static_collision_body.set_meta("armor_thickness_mm", front_armor_mm)
	static_collision_body.set_meta("armor_type", ArmorCalculator.ArmorType.COMPOSITE)

## Public API to update hull dimensions dynamically from UI
func set_dimensions(p_length: float, p_width: float, p_height: float, p_glacis_angle: float) -> void:
	self.length = p_length
	self.width = p_width
	self.height = p_height
	self.front_glacis_angle_deg = p_glacis_angle
	generate_hull_mesh()

## Determine local armor sector name from world hit position
func get_sector_at(world_hit_pos: Vector3) -> String:
	var local_pos = to_local(world_hit_pos)
	var half_l = length * 0.5
	var half_w = width * 0.5
	var half_h = height * 0.5

	if local_pos.y > half_h * 0.35:
		return "roof"
	elif local_pos.x > 0.0:
		if local_pos.y < -half_h * 0.2:
			return "lower_glacis"
		elif local_pos.z < -half_w * 0.25:
			return "upper_glacis_left"
		elif local_pos.z > half_w * 0.25:
			return "upper_glacis_right"
		else:
			return "upper_glacis_center"
	elif local_pos.x < -half_l * 0.65:
		return "rear"
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

	var base_sandwich = armor_sandwich if armor_sandwich != null else ArmorCalculator.ArmorSandwich.create_default_glacis()
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
