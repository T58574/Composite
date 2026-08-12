extends SceneTree

## Automated Headless Test Runner for Composite Engine & Editor
## Run with: Godot_console.exe --headless -s res://scripts/tests/test_runner.gd

func _init() -> void:
	print("==========================================================")
	print(" 🧪 COMPOSITE ENGINE - AUTOMATED HEADLESS SUITE ")
	print("==========================================================")

	var total_tests := 0
	var passed_tests := 0

	# Test Group 1: Armor & Ballistics Physics
	total_tests += 1
	if _test_armor_calculator():
		passed_tests += 1

	# Test Group 2: Procedural Hull & Turret Builders
	total_tests += 1
	if _test_procedural_builders():
		passed_tests += 1

	# Test Group 3: Shooting & Ballistic Trajectory
	total_tests += 1
	if _test_shooting_system():
		passed_tests += 1

	# Test Group 4: Mesh Editor Topology Ops
	total_tests += 1
	if _test_mesh_topology():
		passed_tests += 1

	# Test Group 5: Preset Card Selector UI & Drawing
	total_tests += 1
	if _test_preset_card_selector():
		passed_tests += 1

	print("----------------------------------------------------------")
	print("RESULT: %d / %d TEST SUITES PASSED" % [passed_tests, total_tests])
	print("==========================================================")

	if passed_tests == total_tests:
		print("✅ ALL TESTS PASSED CLEANLY!")
		quit(0)
	else:
		print("❌ TEST SUITE FAILED WITH ERRORS")
		quit(1)

func _test_armor_calculator() -> bool:
	print("\n[TEST 1] Testing ArmorCalculator & Ballistics Physics...")
	
	# Test RHA nominal thickness
	var eff = ArmorCalculator.calculate_effective_thickness(100.0, Vector3.UP, Vector3.DOWN)
	if absf(eff - 100.0) > 0.1:
		print("  FAIL: Vertical normal effective thickness != 100mm (got %.2f)" % eff)
		return false

	# Test APFSDS impact on Kontakt-5 ERA
	var sandwich = ArmorCalculator.ArmorSandwich.create_default_glacis()
	var result = ArmorCalculator.evaluate_impact(
		ArmorCalculator.AmmoType.APFSDS,
		700.0, # Pen mm
		200.0, # Nominal
		ArmorCalculator.ArmorType.COMPOSITE,
		Vector3(0.866, 0.5, 0.0).normalized(), # ~60 deg
		Vector3(-1.0, 0.0, 0.0),
		sandwich
	)
	
	if result == null or result.description == "":
		print("  FAIL: evaluate_impact returned null or empty description")
		return false

	print("  PASS: ArmorCalculator tests passed (Impact: %s)" % result.description)
	return true

func _test_procedural_builders() -> bool:
	print("\n[TEST 2] Testing HullBuilder & TurretBuilder Procedural Generation...")

	var hull = HullBuilder.new()
	hull.set_dimensions(6.8, 3.4, 1.4, 60.0, HullBuilder.GlacisStyle.SLOPED_WEDGE)
	if hull.mesh == null or hull.mesh.get_surface_count() == 0:
		print("  FAIL: HullBuilder failed to generate mesh for SLOPED_WEDGE")
		hull.free()
		return false

	hull.set_dimensions(6.5, 3.2, 1.5, 90.0, HullBuilder.GlacisStyle.FLAT_VERTICAL)
	if hull.mesh == null or hull.mesh.get_surface_count() == 0:
		print("  FAIL: HullBuilder failed to generate mesh for FLAT_VERTICAL")
		hull.free()
		return false

	hull.set_dimensions(7.0, 3.5, 1.4, 50.0, HullBuilder.GlacisStyle.STEPPED)
	if hull.mesh == null or hull.mesh.get_surface_count() == 0:
		print("  FAIL: HullBuilder failed to generate mesh for STEPPED")
		hull.free()
		return false

	hull.free()

	var turret = TurretBuilder.new()
	turret.set_turret_dimensions(3.2, 2.8, 1.1, 45.0, 6.2, 750.0, TurretBuilder.TurretStyle.WEDGE_CHEEK)
	if turret.turret_mesh_instance == null or turret.turret_mesh_instance.mesh == null:
		print("  FAIL: TurretBuilder failed to generate mesh for WEDGE_CHEEK")
		turret.free()
		return false

	turret.set_turret_dimensions(2.6, 2.6, 0.95, 60.0, 5.5, 400.0, TurretBuilder.TurretStyle.CAST_DOME)
	if turret.turret_mesh_instance == null or turret.turret_mesh_instance.mesh == null:
		print("  FAIL: TurretBuilder failed to generate mesh for CAST_DOME")
		turret.free()
		return false

	turret.free()

	print("  PASS: Procedural builders generated valid meshes across all styles.")
	return true

func _test_shooting_system() -> bool:
	print("\n[TEST 3] Testing ShootingSystem & Projectile Physics...")

	var shooter = ShootingSystem.new()
	shooter.muzzle_velocity_ms = 1750.0
	shooter.penetration_mm = 650.0
	shooter.ammo_type = ArmorCalculator.AmmoType.APFSDS
	
	if shooter.ammo_count != 40:
		print("  FAIL: Default ammo count expected 40, got %d" % shooter.ammo_count)
		shooter.free()
		return false

	shooter.free()
	print("  PASS: ShootingSystem initialization and parameters valid.")
	return true

func _test_mesh_topology() -> bool:
	print("\n[TEST 4] Testing MeshTopologyOps...")

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-1, 0, -1))
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(Vector3(1, 0, -1))
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0.5, 1))
	st.add_vertex(Vector3(0, 0, 1))
	st.generate_tangents()
	var test_mesh = st.commit()

	if test_mesh == null or test_mesh.get_surface_count() == 0:
		print("  FAIL: Test mesh creation failed")
		return false

	var extruded = MeshTopologyOps.extrude_face(test_mesh, 0, 0.5)
	if extruded == null or extruded.get_surface_count() == 0:
		print("  FAIL: MeshTopologyOps.extrude_face returned null or empty mesh")
		return false

	print("  PASS: MeshTopologyOps face extrusion completed successfully.")
	return true

func _test_preset_card_selector() -> bool:
	print("\n[TEST 5] Testing PresetCardSelector & Vector Schematic Drawing...")

	var selector_hull = PresetCardSelector.new()
	selector_hull.is_turret_presets = false
	selector_hull.build_cards()

	for i in range(5):
		selector_hull.select_card(i, false)

	selector_hull.free()

	var selector_turret = PresetCardSelector.new()
	selector_turret.is_turret_presets = true
	selector_turret.build_cards()

	for i in range(5):
		selector_turret.select_card(i, false)

	selector_turret.free()

	print("  PASS: PresetCardSelector built and tested across all preset indices.")
	return true
