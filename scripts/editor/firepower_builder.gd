class_name FirepowerBuilder
extends Node3D

## Procedural Gun Barrel, Mantlet, and Firepower Manager for Sprocket-style editor.

@export_group("Gun Parameters")
@export_range(20.0, 155.0, 5.0) var caliber_mm: float = 120.0 ## Gun Caliber in mm
@export_range(2.0, 8.0, 0.1) var barrel_length_m: float = 6.2 ## Length of barrel in meters
@export_range(-10.0, 30.0, 1.0) var max_elevation_deg: float = 20.0 ## Max Pitch Up
@export_range(-15.0, 5.0, 1.0) var max_depression_deg: float = -8.0 ## Max Pitch Down

@export var gun_mesh_instance: MeshInstance3D

func _ready() -> void:
	generate_gun_mesh()

func generate_gun_mesh() -> void:
	if gun_mesh_instance == null:
		gun_mesh_instance = MeshInstance3D.new()
		gun_mesh_instance.name = "GunBarrelMesh"
		add_child(gun_mesh_instance)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var radius = (caliber_mm / 1000.0) * 0.5
	var segments = 16
	var steps = [
		Vector3(0, 0, 0), # Breach / Mantlet base
		Vector3(0, 0, -barrel_length_m * 0.3), # Bore evacuator start
		Vector3(0, 0, -barrel_length_m * 0.35), # Bore evacuator end
		Vector3(0, 0, -barrel_length_m) # Muzzle
	]
	var radii = [radius * 1.8, radius * 1.5, radius * 1.3, radius]

	# Build cylinder segments
	for step_idx in range(steps.size() - 1):
		var p1 = steps[step_idx]
		var p2 = steps[step_idx + 1]
		var r1 = radii[step_idx]
		var r2 = radii[step_idx + 1]

		for i in range(segments):
			var a1 = (float(i) / segments) * TAU
			var a2 = (float(i + 1) / segments) * TAU

			var v1_b = p1 + Vector3(cos(a1) * r1, sin(a1) * r1, 0)
			var v2_b = p1 + Vector3(cos(a2) * r1, sin(a2) * r1, 0)
			var v1_t = p2 + Vector3(cos(a1) * r2, sin(a1) * r2, 0)
			var v2_t = p2 + Vector3(cos(a2) * r2, sin(a2) * r2, 0)

			_add_quad(st, v1_b, v2_b, v2_t, v1_t)

	st.generate_normals()
	st.generate_tangents()
	gun_mesh_instance.mesh = st.commit()

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)

	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)

func set_caliber_and_length(p_caliber: float, p_length: float) -> void:
	caliber_mm = p_caliber
	barrel_length_m = p_length
	generate_gun_mesh()
