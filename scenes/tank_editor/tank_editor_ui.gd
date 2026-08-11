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
@onready var paint_scheme_option: OptionButton = %PaintSchemeOption
@onready var decal_option: OptionButton = %DecalOption

@onready var hull_length_slider: HSlider = %HullLengthSlider
@onready var hull_width_slider: HSlider = %HullWidthSlider
@onready var hull_height_slider: HSlider = %HullHeightSlider
@onready var glacis_angle_slider: HSlider = %GlacisAngleSlider
@onready var engine_power_slider: HSlider = %EnginePowerSlider

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
@onready var thickness_value_label: Label = %ThicknessValueLabel
@onready var armor_type_option: OptionButton = %ArmorTypeOption
@onready var armor_angle_los_label: Label = %ArmorAngleLosLabel

@onready var extrude_btn: Button = %ExtrudeBtn
@onready var flip_btn: Button = %FlipBtn

# Left Chassis / Gun Sliders
@onready var wheels_count_slider: HSlider = %WheelsCountSlider
@onready var wheel_diam_slider: HSlider = %WheelDiamSlider
@onready var track_w_slider: HSlider = %TrackWSlider
@onready var gun_caliber_slider: HSlider = %GunCaliberSlider
@onready var barrel_length_slider: HSlider = %BarrelLengthSlider

# Bottom Gizmo / Viewport Toolbar (Transform Mode Switcher: Move, Rotate, Resize)
@onready var tool_translate_btn: Button = %ToolTranslateBtn
@onready var tool_rotate_btn: Button = %ToolRotateBtn
@onready var tool_scale_btn: Button = %ToolScaleBtn
@onready var tool_snap_btn: Button = %ToolSnapBtn

@onready var hover_inspection_label: Label = %HoverInspectionLabel
@onready var fps_label: Label = %FPSLabel

func _ready() -> void:
	# Enforce MOUSE_FILTER_IGNORE on overlay root to allow 3D Viewport raycasting
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_options()
	_connect_signals()
	_update_ttx()
	_sync_sliders_with_builders()
	
	if not SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	_setup_options()
	_on_selection_changed()

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _setup_options() -> void:
	if era_option:
		var sel = era_option.selected if era_option.item_count > 0 else 1
		era_option.clear()
		era_option.add_item(tr("ERA_EARLY"), 0)
		era_option.add_item(tr("ERA_MID"), 1)
		era_option.add_item(tr("ERA_LATE"), 2)
		era_option.add_item(tr("ERA_MODERN"), 3)
		era_option.select(sel)

	if armor_type_option:
		var sel = armor_type_option.selected if armor_type_option.item_count > 0 else 0
		armor_type_option.clear()
		armor_type_option.add_item(tr("ARMOR_STEEL"), 0)
		armor_type_option.add_item(tr("ARMOR_COMPOSITE"), 1)
		armor_type_option.add_item(tr("ARMOR_CERAMIC"), 2)
		armor_type_option.select(sel)

	if paint_scheme_option:
		var sel = paint_scheme_option.selected if paint_scheme_option.item_count > 0 else 0
		paint_scheme_option.clear()
		paint_scheme_option.add_item(tr("PAINT_SOLID"), 0)
		paint_scheme_option.add_item(tr("PAINT_NATO"), 1)
		paint_scheme_option.add_item(tr("PAINT_DESERT"), 2)
		paint_scheme_option.add_item(tr("PAINT_WINTER"), 3)
		paint_scheme_option.add_item(tr("PAINT_GREY"), 4)
		paint_scheme_option.select(sel)

	if decal_option:
		var sel = decal_option.selected if decal_option.item_count > 0 else 0
		decal_option.clear()
		decal_option.add_item(tr("DECAL_STAR"), 0)
		decal_option.add_item(tr("DECAL_NUMBER"), 1)
		decal_option.add_item(tr("DECAL_CROSS"), 2)
		decal_option.select(sel)


func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func _connect_signals() -> void:
	if mesh_editor:
		_safe_connect(mesh_editor.face_hovered, _on_face_hovered)
		_safe_connect(mesh_editor.selection_changed, _on_selection_changed)
		if mesh_editor.has_signal("gizmo_mode_changed"):
			_safe_connect(mesh_editor.gizmo_mode_changed, _on_gizmo_mode_changed)

	if cat_compartments_btn: _safe_connect(cat_compartments_btn.pressed, func(): _on_category_selected(0))
	if cat_tracks_btn: _safe_connect(cat_tracks_btn.pressed, func(): _on_category_selected(1))
	if cat_powertrain_btn: _safe_connect(cat_powertrain_btn.pressed, func(): _on_category_selected(2))
	if cat_firepower_btn: _safe_connect(cat_firepower_btn.pressed, func(): _on_category_selected(3))
	if cat_crew_btn: _safe_connect(cat_crew_btn.pressed, func(): _on_category_selected(4))
	if cat_paint_btn: _safe_connect(cat_paint_btn.pressed, func(): _on_category_selected(5))
	if cat_decals_btn: _safe_connect(cat_decals_btn.pressed, func(): _on_category_selected(6))

	if paint_scheme_option: _safe_connect(paint_scheme_option.item_selected, _on_paint_scheme_selected)

	if hull_length_slider: _safe_connect(hull_length_slider.value_changed, _on_hull_slider_changed)
	if hull_width_slider: _safe_connect(hull_width_slider.value_changed, _on_hull_slider_changed)
	if hull_height_slider: _safe_connect(hull_height_slider.value_changed, _on_hull_slider_changed)
	if glacis_angle_slider: _safe_connect(glacis_angle_slider.value_changed, _on_hull_slider_changed)

	if wheels_count_slider: _safe_connect(wheels_count_slider.value_changed, _on_chassis_changed)
	if wheel_diam_slider: _safe_connect(wheel_diam_slider.value_changed, _on_chassis_changed)
	if track_w_slider: _safe_connect(track_w_slider.value_changed, _on_chassis_changed)

	if engine_power_slider: _safe_connect(engine_power_slider.value_changed, func(_v): _update_ttx())

	if gun_caliber_slider: _safe_connect(gun_caliber_slider.value_changed, _on_firepower_changed)
	if barrel_length_slider: _safe_connect(barrel_length_slider.value_changed, _on_firepower_changed)

	if thickness_slider: _safe_connect(thickness_slider.value_changed, _on_thickness_slider_changed)
	if armor_type_option: _safe_connect(armor_type_option.item_selected, _on_armor_type_selected)

	if extrude_btn: _safe_connect(extrude_btn.pressed, _on_extrude_pressed)
	if flip_btn: _safe_connect(flip_btn.pressed, _on_flip_normals_pressed)

	if tool_translate_btn: _safe_connect(tool_translate_btn.pressed, _on_tool_translate_pressed)
	if tool_rotate_btn: _safe_connect(tool_rotate_btn.pressed, _on_tool_rotate_pressed)
	if tool_scale_btn: _safe_connect(tool_scale_btn.pressed, _on_tool_scale_pressed)

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

	_sync_sliders_with_builders()
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
	if mesh_editor: mesh_editor.extrude_selected_face()

func _on_flip_normals_pressed() -> void:
	if mesh_editor: mesh_editor.flip_selected_normals()

# Category Sidebar Switching
func _on_category_selected(cat_index: int) -> void:
	if category_stack:
		for i in range(category_stack.get_child_count()):
			category_stack.get_child(i).visible = (i == cat_index)

# Sliders & Parameter Handlers
func _on_hull_slider_changed(_val: float) -> void:
	if hull_builder:
		var l = hull_length_slider.value if hull_length_slider else 6.8
		var w = hull_width_slider.value if hull_width_slider else 3.4
		var h = hull_height_slider.value if hull_height_slider else 1.4
		var g = glacis_angle_slider.value if glacis_angle_slider else 60.0
		hull_builder.set_dimensions(l, w, h, g)
	_update_ttx()

func _on_thickness_slider_changed(val: float) -> void:
	if thickness_value_label:
		thickness_value_label.text = "%.0f mm" % val

	if mesh_editor and mesh_editor.selected_target == hull_builder:
		hull_builder.front_armor_mm = val
		hull_builder.generate_hull_mesh()
	elif mesh_editor and mesh_editor.selected_target and turret_builder and mesh_editor.selected_target == turret_builder.turret_mesh_instance:
		turret_builder.front_turret_armor_mm = val
		turret_builder.generate_turret_and_gun()
	elif hull_builder:
		hull_builder.front_armor_mm = val
		hull_builder.generate_hull_mesh()
	_update_ttx()

func _on_armor_type_selected(index: int) -> void:
	# 0: RHA Steel, 1: NERA Composite, 2: Ceramic Insert
	var is_comp = (index != 0)
	if mesh_editor and mesh_editor.heatmap_material:
		mesh_editor.heatmap_material.set_shader_parameter("is_composite", is_comp)

func _on_paint_scheme_selected(index: int) -> void:
	if mesh_editor and mesh_editor.pbr_material is ShaderMaterial:
		mesh_editor.pbr_material.set_shader_parameter("camo_type", index)

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

func _on_selection_changed() -> void:
	if mesh_editor == null:
		return

	if mesh_editor.selected_target != null:
		var target_name = tr("PART_HULL_PLATE")
		var thickness = 450.0
		if mesh_editor.selected_target == hull_builder:
			target_name = tr("PART_FRONT_GLACIS")
			thickness = hull_builder.front_armor_mm
		elif turret_builder and mesh_editor.selected_target == turret_builder.turret_mesh_instance:
			target_name = tr("PART_TURRET_CHEEK")
			thickness = turret_builder.front_turret_armor_mm

		if part_name_label:
			part_name_label.text = target_name
		if thickness_slider:
			thickness_slider.value = thickness
		if thickness_value_label:
			thickness_value_label.text = "%.0f mm" % thickness
	else:
		if part_name_label:
			part_name_label.text = tr("PART_NO_SELECTION")

func _on_face_hovered(thickness_mm: float, angle_deg: float, effective_rha_mm: float) -> void:
	if hover_inspection_label:
		hover_inspection_label.text = tr("HOVER_INSPECT_FMT") % [thickness_mm, angle_deg, effective_rha_mm]
	if armor_angle_los_label:
		armor_angle_los_label.text = tr("ARMOR_LOS_FMT") % [angle_deg, effective_rha_mm]


func _sync_sliders_with_builders() -> void:
	if hull_builder:
		if hull_length_slider: hull_length_slider.value = hull_builder.length
		if hull_width_slider: hull_width_slider.value = hull_builder.width
		if hull_height_slider: hull_height_slider.value = hull_builder.height
		if glacis_angle_slider: glacis_angle_slider.value = hull_builder.front_glacis_angle_deg
		if thickness_slider: thickness_slider.value = hull_builder.front_armor_mm
		if thickness_value_label: thickness_value_label.text = "%.0f mm" % hull_builder.front_armor_mm

	if track_generator:
		if wheels_count_slider: wheels_count_slider.value = track_generator.road_wheels_count
		if wheel_diam_slider: wheel_diam_slider.value = track_generator.wheel_diameter
		if track_w_slider: track_w_slider.value = track_generator.track_width

	if firepower_builder:
		if gun_caliber_slider: gun_caliber_slider.value = firepower_builder.caliber_mm
		if barrel_length_slider: barrel_length_slider.value = firepower_builder.barrel_length_m

func _update_ttx() -> void:
	var power_hp = engine_power_slider.value if engine_power_slider else 1200.0
	var ttx = TankStatsCalculator.calculate_stats(hull_builder, turret_builder, track_generator, power_hp)

	if mass_badge_label: mass_badge_label.text = "%.2ft" % ttx.total_mass_tons
	if space_badge_label: space_badge_label.text = "%.2fk" % (ttx.total_mass_tons * 0.8)
