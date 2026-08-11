extends Control

## Main Controller for Sprocket-style Tank Editor (TankEditor.tscn).
## Manages UI navigation, Sprocket-style headers, inspectors, preset shelf, and TTX calculations.

@export var hull_builder: HullBuilder
@export var turret_builder: TurretBuilder
@export var track_generator: TrackGenerator
@export var firepower_builder: FirepowerBuilder
@export var editor_camera: EditorCamera
@export var mesh_editor: MeshEditor

# Top Header Nodes
@onready var era_option: OptionButton = %EraOption
@onready var tank_name_edit: LineEdit = %TankNameEdit
@onready var mass_badge_label: Label = %MassBadgeLabel
@onready var space_badge_label: Label = %SpaceBadgeLabel
@onready var test_drive_btn: Button = %TestDriveBtn

@onready var solid_btn: Button = %SolidBtn
@onready var heatmap_btn: Button = %HeatmapBtn
@onready var xray_btn: Button = %XrayBtn
@onready var symmetry_check: CheckBox = %SymmetryCheck

# Left Sidebar Category Buttons
@onready var cat_compartments_btn: Button = %CatCompartmentsBtn
@onready var cat_tracks_btn: Button = %CatTracksBtn
@onready var cat_powertrain_btn: Button = %CatPowertrainBtn
@onready var cat_firepower_btn: Button = %CatFirepowerBtn
@onready var cat_crew_btn: Button = %CatCrewBtn
@onready var cat_paint_btn: Button = %CatPaintBtn
@onready var cat_decals_btn: Button = %CatDecalsBtn

# Left Sub-Panel Container
@onready var category_stack: Control = %CategoryStack

# Right Structure Inspector Nodes
@onready var part_name_label: Label = %PartNameLabel
@onready var mode_points_btn: Button = %ModePointsBtn
@onready var mode_edges_btn: Button = %ModeEdgesBtn
@onready var mode_faces_btn: Button = %ModeFacesBtn
@onready var mode_corners_btn: Button = %ModeCornersBtn

@onready var mirror_check: CheckBox = %MirrorCheck
@onready var smooth_angle_slider: HSlider = %SmoothAngleSlider
@onready var grid_size_slider: HSlider = %GridSizeSlider

@onready var thickness_slider: HSlider = %ThicknessSlider
@onready var thickness_value_label: Label = get_node_or_null("%ThicknessValueLabel") as Label
@onready var armor_type_option: OptionButton = %ArmorTypeOption
@onready var armor_angle_los_label: Label = get_node_or_null("%ArmorAngleLosLabel") as Label

@onready var extrude_btn: Button = get_node_or_null("%ExtrudeBtn") as Button
@onready var flip_btn: Button = get_node_or_null("%FlipBtn") as Button

# Category Sliders & Controls
@onready var hull_length_slider: HSlider = get_node_or_null("%HullLengthSlider") as HSlider
@onready var hull_width_slider: HSlider = get_node_or_null("%HullWidthSlider") as HSlider
@onready var hull_height_slider: HSlider = get_node_or_null("%HullHeightSlider") as HSlider
@onready var glacis_angle_slider: HSlider = get_node_or_null("%GlacisAngleSlider") as HSlider

@onready var wheels_count_slider: HSlider = %WheelsCountSlider
@onready var wheel_diam_slider: HSlider = %WheelDiamSlider
@onready var track_w_slider: HSlider = %TrackWSlider

@onready var engine_power_slider: HSlider = get_node_or_null("%EnginePowerSlider") as HSlider

@onready var gun_caliber_slider: HSlider = %GunCaliberSlider
@onready var barrel_length_slider: HSlider = %BarrelLengthSlider

@onready var crew_count_slider: HSlider = get_node_or_null("%CrewCountSlider") as HSlider

@onready var paint_scheme_option: OptionButton = get_node_or_null("%PaintSchemeOption") as OptionButton
@onready var decal_option: OptionButton = get_node_or_null("%DecalOption") as OptionButton

# Bottom Gizmo / Viewport Toolbar (Transform Mode Switcher)
@onready var tool_translate_btn: Button = %ToolTranslateBtn
@onready var tool_rotate_btn: Button = %ToolRotateBtn
@onready var tool_scale_btn: Button = %ToolScaleBtn
@onready var tool_snap_btn: Button = %ToolSnapBtn

@onready var hover_inspection_label: Label = %HoverInspectionLabel
@onready var fps_label: Label = %FPSLabel

func _ready() -> void:
	# Ensure Control root and UI Overlay have mouse_filter = 2 (MOUSE_FILTER_IGNORE)
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parent_ctrl = get_parent() as Control
	if parent_ctrl:
		parent_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_options()
	_connect_signals()
	_update_right_inspector()
	_update_ttx()

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_sync_sliders_with_builders()

func _setup_options() -> void:
	if era_option:
		era_option.clear()
		era_option.add_item("Earlywar (1939-1941)", 0)
		era_option.add_item("Midwar (1942-1944)", 1)
		era_option.add_item("Latewar (1945-1955)", 2)
		era_option.add_item("Modern MBT (1970-2026)", 3)
		era_option.select(1)

	if armor_type_option:
		armor_type_option.clear()
		armor_type_option.add_item("RHA Steel", 0)
		armor_type_option.add_item("NERA Composite", 1)
		armor_type_option.add_item("Ceramic Insert", 2)
		armor_type_option.select(0)

	if paint_scheme_option:
		paint_scheme_option.clear()
		paint_scheme_option.add_item("Solid (Olive Drab)", 0)
		paint_scheme_option.add_item("NATO 3-Color Camo", 1)
		paint_scheme_option.add_item("Desert Sand", 2)
		paint_scheme_option.add_item("Winter Solid", 3)
		paint_scheme_option.add_item("Panzer Grey", 4)
		paint_scheme_option.select(0)

	if decal_option:
		decal_option.clear()
		decal_option.add_item("National Star", 0)
		decal_option.add_item("Unit Number", 1)
		decal_option.add_item("Tactical Cross", 2)
		decal_option.select(0)

func _connect_signals() -> void:
	if mesh_editor:
		mesh_editor.face_hovered.connect(_on_face_hovered)
		mesh_editor.selection_changed.connect(_on_selection_changed)
		if mesh_editor.has_signal("gizmo_mode_changed"):
			mesh_editor.gizmo_mode_changed.connect(_on_gizmo_mode_changed)

	if cat_compartments_btn: cat_compartments_btn.pressed.connect(func(): _on_category_selected(0))
	if cat_tracks_btn: cat_tracks_btn.pressed.connect(func(): _on_category_selected(1))
	if cat_powertrain_btn: cat_powertrain_btn.pressed.connect(func(): _on_category_selected(2))
	if cat_firepower_btn: cat_firepower_btn.pressed.connect(func(): _on_category_selected(3))
	if cat_crew_btn: cat_crew_btn.pressed.connect(func(): _on_category_selected(4))
	if cat_paint_btn: cat_paint_btn.pressed.connect(func(): _on_category_selected(5))
	if cat_decals_btn: cat_decals_btn.pressed.connect(func(): _on_category_selected(6))

	if paint_scheme_option:
		paint_scheme_option.item_selected.connect(_on_paint_scheme_selected)

	if hull_length_slider: hull_length_slider.value_changed.connect(_on_hull_slider_changed)
	if hull_width_slider: hull_width_slider.value_changed.connect(_on_hull_slider_changed)
	if hull_height_slider: hull_height_slider.value_changed.connect(_on_hull_slider_changed)
	if glacis_angle_slider: glacis_angle_slider.value_changed.connect(_on_hull_slider_changed)

	if wheels_count_slider: wheels_count_slider.value_changed.connect(_on_chassis_changed)
	if wheel_diam_slider: wheel_diam_slider.value_changed.connect(_on_chassis_changed)
	if track_w_slider: track_w_slider.value_changed.connect(_on_chassis_changed)

	if engine_power_slider: engine_power_slider.value_changed.connect(func(_v): _update_ttx())

	if gun_caliber_slider: gun_caliber_slider.value_changed.connect(_on_firepower_changed)
	if barrel_length_slider: barrel_length_slider.value_changed.connect(_on_firepower_changed)

	if thickness_slider: thickness_slider.value_changed.connect(_on_thickness_slider_changed)
	if armor_type_option: armor_type_option.item_selected.connect(_on_armor_type_selected)

	if extrude_btn: extrude_btn.pressed.connect(_on_extrude_pressed)
	if flip_btn: flip_btn.pressed.connect(_on_flip_normals_pressed)

	if tool_translate_btn: tool_translate_btn.pressed.connect(_on_tool_translate_pressed)
	if tool_rotate_btn: tool_rotate_btn.pressed.connect(_on_tool_rotate_pressed)
	if tool_scale_btn: tool_scale_btn.pressed.connect(_on_tool_scale_pressed)

# Transform Mode Switcher Handlers (Move [G], Rotate [R], Resize [S])
func _on_tool_translate_pressed() -> void:
	if mesh_editor:
		mesh_editor.set_gizmo_mode(Gizmo3D.GizmoMode.TRANSLATE)

func _on_tool_rotate_pressed() -> void:
	if mesh_editor:
		mesh_editor.set_gizmo_mode(Gizmo3D.GizmoMode.ROTATE)

func _on_tool_scale_pressed() -> void:
	if mesh_editor:
		mesh_editor.set_gizmo_mode(Gizmo3D.GizmoMode.SCALE)

func _on_gizmo_mode_changed(mode: int) -> void:
	if tool_translate_btn:
		tool_translate_btn.flat = (mode != 0)
	if tool_rotate_btn:
		tool_rotate_btn.flat = (mode != 1)
	if tool_scale_btn:
		tool_scale_btn.flat = (mode != 2)

# Header Action Handlers
func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_test_drive_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/combat/test_range.tscn")

func _on_save_preset_pressed() -> void:
	var name_str = tank_name_edit.text if tank_name_edit and tank_name_edit.text != "" else "Custom_Tank"
	var era_str = era_option.get_item_text(era_option.selected) if era_option else "Midwar"
	var path = "user://%s.json" % name_str
	TankSerializer.save_preset(path, name_str, era_str, hull_builder, turret_builder, track_generator, firepower_builder)

func _on_load_preset_pressed() -> void:
	var name_str = tank_name_edit.text if tank_name_edit and tank_name_edit.text != "" else "Custom_Tank"
	var path = "user://%s.json" % name_str
	var data = TankSerializer.load_preset(path)
	if not data.is_empty():
		_apply_preset_data(data)

func _apply_preset_data(data: Dictionary) -> void:
	if data.has("hull") and hull_builder:
		var h = data["hull"]
		hull_builder.set_dimensions(h.get("length", 6.8), h.get("width", 3.4), h.get("height", 1.4), h.get("front_glacis_angle_deg", 60.0))
		hull_builder.front_armor_mm = h.get("front_armor_mm", 450.0)
		if thickness_slider: thickness_slider.value = hull_builder.front_armor_mm

	if data.has("chassis") and track_generator:
		var c = data["chassis"]
		track_generator.set_chassis_parameters(c.get("road_wheel_pairs", 6), c.get("wheel_diameter", 0.65), c.get("track_width", 0.6), 0.6)

	_update_right_inspector()
	_update_ttx()

# View Visualization Handlers
func _on_solid_btn_pressed() -> void:
	if mesh_editor: mesh_editor.set_visualization_mode(MeshEditor.VisualizationMode.SOLID)

func _on_heatmap_btn_pressed() -> void:
	if mesh_editor: mesh_editor.set_visualization_mode(MeshEditor.VisualizationMode.ARMOR_HEATMAP)

func _on_xray_btn_pressed() -> void:
	if mesh_editor: mesh_editor.set_visualization_mode(MeshEditor.VisualizationMode.XRAY)

func _on_symmetry_toggled(button_pressed: bool) -> void:
	if mesh_editor: mesh_editor.symmetry_x_enabled = button_pressed

# Structure Element Sub-Modes (Points, Edges, Faces, Corners)
func _on_mode_points_pressed() -> void:
	if mesh_editor: mesh_editor.set_edit_mode(MeshEditor.EditMode.VERTEX)

func _on_mode_edges_pressed() -> void:
	if mesh_editor: mesh_editor.set_edit_mode(MeshEditor.EditMode.EDGE)

func _on_mode_faces_pressed() -> void:
	if mesh_editor: mesh_editor.set_edit_mode(MeshEditor.EditMode.FACE)

func _on_mode_corners_pressed() -> void:
	if mesh_editor: mesh_editor.set_edit_mode(MeshEditor.EditMode.CORNER)

# Topology Operations
func _on_extrude_pressed() -> void:
	if mesh_editor:
		mesh_editor.extrude_selected_face()
	_update_right_inspector()

func _on_flip_normals_pressed() -> void:
	if mesh_editor:
		mesh_editor.flip_selected_normals()
	_update_right_inspector()

# Category Sidebar Switching
func _on_category_selected(cat_index: int) -> void:
	if category_stack:
		var margin = category_stack.get_node_or_null("Margin")
		if margin:
			for i in range(margin.get_child_count()):
				var child = margin.get_child(i)
				if child is Control:
					child.visible = (i == cat_index)

# Sliders & Parameter Handlers
func _on_hull_slider_changed(_val: float = 0.0) -> void:
	if hull_builder:
		var l = hull_length_slider.value if hull_length_slider else hull_builder.length
		var w = hull_width_slider.value if hull_width_slider else hull_builder.width
		var h = hull_height_slider.value if hull_height_slider else hull_builder.height
		var g = glacis_angle_slider.value if glacis_angle_slider else hull_builder.front_glacis_angle_deg
		hull_builder.set_dimensions(l, w, h, g)
	_update_right_inspector()
	_update_ttx()

func _on_thickness_slider_changed(val: float) -> void:
	if thickness_value_label:
		thickness_value_label.text = "%.0f mm" % val

	if mesh_editor and mesh_editor.selected_target:
		var target = mesh_editor.selected_target
		if target == hull_builder:
			hull_builder.front_armor_mm = val
			hull_builder.generate_hull_mesh()
		elif turret_builder and (target == turret_builder.turret_mesh_instance or target == turret_builder):
			turret_builder.front_turret_armor_mm = val
			turret_builder.generate_turret_and_gun()
	elif hull_builder:
		hull_builder.front_armor_mm = val
		hull_builder.generate_hull_mesh()

	_update_right_inspector()
	_update_ttx()

func _on_armor_type_selected(_idx: int) -> void:
	_update_right_inspector()
	_update_ttx()

func _on_chassis_changed(_val: float) -> void:
	if track_generator:
		var cnt = int(wheels_count_slider.value) if wheels_count_slider else 6
		var diam = wheel_diam_slider.value if wheel_diam_slider else 0.65
		var w = track_w_slider.value if track_w_slider else 0.6
		track_generator.set_chassis_parameters(cnt, diam, w, 0.6)
	_update_ttx()

func _on_firepower_changed(_val: float) -> void:
	if firepower_builder:
		var cal = gun_caliber_slider.value if gun_caliber_slider else 120.0
		var len_m = barrel_length_slider.value if barrel_length_slider else 6.2
		firepower_builder.set_caliber_and_length(cal, len_m)
	_update_ttx()

func _on_paint_scheme_selected(idx: int) -> void:
	var type_map = [1, 3, 2, 0, 4]
	var c_type = type_map[clampi(idx, 0, 4)]
	
	var materials: Array[ShaderMaterial] = []
	if hull_builder and hull_builder.hull_material is ShaderMaterial:
		materials.append(hull_builder.hull_material as ShaderMaterial)
	if turret_builder and turret_builder.turret_material is ShaderMaterial:
		materials.append(turret_builder.turret_material as ShaderMaterial)
	if track_generator and track_generator.track_material is ShaderMaterial:
		materials.append(track_generator.track_material as ShaderMaterial)
	if mesh_editor and mesh_editor.pbr_material is ShaderMaterial:
		materials.append(mesh_editor.pbr_material as ShaderMaterial)

	for mat in materials:
		mat.set_shader_parameter("camo_type", c_type)

func _on_face_hovered(thickness_mm: float, angle_deg: float, effective_rha_mm: float) -> void:
	if hover_inspection_label:
		hover_inspection_label.text = "Armor: %.0fmm | Angle: %.1f° | Effective: %.0fmm RHA" % [thickness_mm, angle_deg, effective_rha_mm]

func _sync_sliders_with_builders() -> void:
	if hull_builder:
		if hull_length_slider and not hull_length_slider.has_focus():
			hull_length_slider.set_value_no_signal(hull_builder.length)
		if hull_width_slider and not hull_width_slider.has_focus():
			hull_width_slider.set_value_no_signal(hull_builder.width)
		if hull_height_slider and not hull_height_slider.has_focus():
			hull_height_slider.set_value_no_signal(hull_builder.height)
		if glacis_angle_slider and not glacis_angle_slider.has_focus():
			glacis_angle_slider.set_value_no_signal(hull_builder.front_glacis_angle_deg)

func _on_selection_changed() -> void:
	_update_right_inspector()
	_update_ttx()

func _update_right_inspector() -> void:
	var part_name = "Front Glacis Plate"
	var thickness = 450.0
	var face_normal = Vector3(0.0, 0.5, -0.866).normalized()

	if mesh_editor and mesh_editor.selected_target and mesh_editor.selected_target.mesh:
		var target = mesh_editor.selected_target
		var face_idx = mesh_editor.selected_face_index
		var faces = target.mesh.get_faces()

		if face_idx >= 0 and face_idx * 3 + 2 < faces.size():
			var gt = target.global_transform
			var v0 = gt * faces[face_idx * 3]
			var v1 = gt * faces[face_idx * 3 + 1]
			var v2 = gt * faces[face_idx * 3 + 2]
			face_normal = (v1 - v0).cross(v2 - v0).normalized()

			var local_norm = target.global_transform.basis.inverse() * face_normal
			if target == hull_builder:
				if local_norm.z < -0.4:
					part_name = "Front Glacis Plate"
					thickness = hull_builder.front_armor_mm
				elif local_norm.z > 0.4:
					part_name = "Rear Hull Plate"
					thickness = hull_builder.rear_armor_mm
				elif abs(local_norm.x) > 0.4:
					part_name = "Side Hull Armor"
					thickness = hull_builder.side_armor_mm
				elif local_norm.y > 0.4:
					part_name = "Hull Roof Plate"
					thickness = hull_builder.front_armor_mm * 0.2
				elif local_norm.y < -0.4:
					part_name = "Belly Armor Plate"
					thickness = hull_builder.side_armor_mm * 0.5
				else:
					part_name = "Front Glacis Plate"
					thickness = hull_builder.front_armor_mm
			elif turret_builder and (target == turret_builder.turret_mesh_instance or target == turret_builder.gun_barrel_mesh_instance):
				if local_norm.z < -0.4:
					part_name = "Turret Front Cheek"
					thickness = turret_builder.front_turret_armor_mm
				elif local_norm.z > 0.4:
					part_name = "Turret Rear Bustle"
					thickness = turret_builder.front_turret_armor_mm * 0.2
				elif abs(local_norm.x) > 0.4:
					part_name = "Turret Side Armor"
					thickness = turret_builder.front_turret_armor_mm * 0.4
				elif local_norm.y > 0.4:
					part_name = "Turret Roof Plate"
					thickness = turret_builder.front_turret_armor_mm * 0.15
				else:
					part_name = "Turret Front Plate"
					thickness = turret_builder.front_turret_armor_mm
			else:
				part_name = target.name if target.name != "" else "Structure Face"
	elif hull_builder:
		part_name = "Front Glacis Plate"
		thickness = hull_builder.front_armor_mm

	var threat_dir = Vector3(0, 0, -1)
	var cos_theta = clamp(abs(face_normal.dot(-threat_dir)), 0.0, 1.0)
	var angle_deg = rad_to_deg(acos(cos_theta))

	var armor_type_idx = armor_type_option.selected if armor_type_option else 0
	var mult = 1.0
	match armor_type_idx:
		0: mult = 1.0  # RHA Steel
		1: mult = 1.45 # NERA Composite
		2: mult = 1.8  # Ceramic Insert

	var los_rha = ArmorCalculator.calculate_effective_thickness(thickness, face_normal, threat_dir) * mult

	if part_name_label:
		part_name_label.text = part_name
	if thickness_slider and not thickness_slider.has_focus():
		thickness_slider.set_value_no_signal(thickness)
	if thickness_value_label:
		thickness_value_label.text = "%.0f mm" % thickness
	if armor_angle_los_label:
		armor_angle_los_label.text = "Angle: %.1f° | LOS: %.0fmm RHA" % [angle_deg, los_rha]

func _update_ttx() -> void:
	var hp: float = engine_power_slider.value if engine_power_slider else 1200.0
	var ttx = TankStatsCalculator.calculate_stats(hull_builder, turret_builder, track_generator, hp)

	if mass_badge_label:
		mass_badge_label.text = "Mass: %.1ft | P/W: %.1f hp/t" % [ttx.total_mass_tons, ttx.power_to_weight_hp_ton]
	if space_badge_label:
		var armor_rating = hull_builder.front_armor_mm if hull_builder else 450.0
		space_badge_label.text = "Spd: %.0f km/h | Arm: %.0fmm RHA" % [ttx.max_speed_kmh, armor_rating]
