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

# Sandwich Construction UI Controls
@onready var layer1_material_option: OptionButton = %Layer1MaterialOption
@onready var layer1_thickness_slider: HSlider = %Layer1ThicknessSlider
@onready var layer1_thickness_label: Label = %Layer1ThicknessLabel

@onready var layer2_material_option: OptionButton = %Layer2MaterialOption
@onready var layer2_thickness_slider: HSlider = %Layer2ThicknessSlider
@onready var layer2_thickness_label: Label = %Layer2ThicknessLabel

@onready var layer3_material_option: OptionButton = %Layer3MaterialOption
@onready var layer3_thickness_slider: HSlider = %Layer3ThicknessSlider
@onready var layer3_thickness_label: Label = %Layer3ThicknessLabel

@onready var spall_liner_check: CheckBox = %SpallLinerCheck
@onready var addon_protection_option: OptionButton = %AddonProtectionOption

@onready var sandwich_total_thickness_label: Label = %SandwichTotalThicknessLabel
@onready var sandwich_weight_label: Label = %SandwichWeightLabel
@onready var sandwich_effective_ke_label: Label = %SandwichEffectiveKeLabel
@onready var sandwich_effective_heat_label: Label = %SandwichEffectiveHeatLabel

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

var _updating_ui: bool = false

func _ready() -> void:
	# Enforce MOUSE_FILTER_IGNORE on overlay root to allow 3D Viewport raycasting
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_options()
	_connect_signals()
	_sync_sandwich_ui_from_target()
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

	# Populate Layer 1 Outer Material
	if layer1_material_option:
		var sel_id = layer1_material_option.get_selected_id() if layer1_material_option.item_count > 0 else ArmorCalculator.MaterialType.RHA_STEEL
		layer1_material_option.clear()
		layer1_material_option.add_item("RHA Steel", ArmorCalculator.MaterialType.RHA_STEEL)
		layer1_material_option.add_item("Cast Steel", ArmorCalculator.MaterialType.CAST_STEEL)
		layer1_material_option.add_item("HHRA Steel", ArmorCalculator.MaterialType.HHRA_STEEL)
		layer1_material_option.add_item("Face-Hardened", ArmorCalculator.MaterialType.FACE_HARDENED)
		_select_option_by_id(layer1_material_option, sel_id)

	# Populate Layer 2 Filler Material
	if layer2_material_option:
		var sel_id = layer2_material_option.get_selected_id() if layer2_material_option.item_count > 0 else ArmorCalculator.MaterialType.GLASS_TEXTOLITE_STK
		layer2_material_option.clear()
		layer2_material_option.add_item("None", -1)
		layer2_material_option.add_item("Glass Composite STK", ArmorCalculator.MaterialType.GLASS_TEXTOLITE_STK)
		layer2_material_option.add_item("Ceramic Chobham", ArmorCalculator.MaterialType.CERAMIC_SIC_AL2O3)
		layer2_material_option.add_item("NERA Air/Rubber", ArmorCalculator.MaterialType.NERA_AIR_RUBBER)
		layer2_material_option.add_item("Depleted Uranium", ArmorCalculator.MaterialType.DEPLETED_URANIUM)
		_select_option_by_id(layer2_material_option, sel_id)

	# Populate Layer 3 Rear Material
	if layer3_material_option:
		var sel_id = layer3_material_option.get_selected_id() if layer3_material_option.item_count > 0 else ArmorCalculator.MaterialType.RHA_STEEL
		layer3_material_option.clear()
		layer3_material_option.add_item("RHA Steel", ArmorCalculator.MaterialType.RHA_STEEL)
		layer3_material_option.add_item("HHRA Steel", ArmorCalculator.MaterialType.HHRA_STEEL)
		_select_option_by_id(layer3_material_option, sel_id)

	# Populate Add-on Protection Options
	if addon_protection_option:
		var sel_id = addon_protection_option.get_selected_id() if addon_protection_option.item_count > 0 else ArmorCalculator.AddonProtectionType.NONE
		addon_protection_option.clear()
		addon_protection_option.add_item("None", ArmorCalculator.AddonProtectionType.NONE)
		addon_protection_option.add_item("Kontakt-1 ERA", ArmorCalculator.AddonProtectionType.ERA_KONTAKT1)
		addon_protection_option.add_item("Kontakt-5 ERA", ArmorCalculator.AddonProtectionType.ERA_KONTAKT5)
		addon_protection_option.add_item("Relikt ERA", ArmorCalculator.AddonProtectionType.ERA_RELIKT)
		addon_protection_option.add_item("Slat Grid", ArmorCalculator.AddonProtectionType.SLAT_CAGE_GRID)
		addon_protection_option.add_item("Soft Side Skirts", ArmorCalculator.AddonProtectionType.SIDE_SKIRTS_SOFT)
		addon_protection_option.add_item("Roof Cope Cage", ArmorCalculator.AddonProtectionType.COPE_CAGE_MANGAL)
		addon_protection_option.add_item("Nakidka Stealth", ArmorCalculator.AddonProtectionType.STEALTH_NAKIDKA)
		_select_option_by_id(addon_protection_option, sel_id)


func _select_option_by_id(opt: OptionButton, target_id: int) -> void:
	if opt == null:
		return
	for i in range(opt.item_count):
		if opt.get_item_id(i) == target_id:
			opt.select(i)
			return
	if opt.item_count > 0:
		opt.select(0)


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

	# Sandwich UI signal connections
	if layer1_material_option: _safe_connect(layer1_material_option.item_selected, func(_idx): _update_sandwich_from_ui())
	if layer1_thickness_slider: _safe_connect(layer1_thickness_slider.value_changed, func(val):
		if layer1_thickness_label: layer1_thickness_label.text = "%.0f mm" % val
		_update_sandwich_from_ui()
	)

	if layer2_material_option: _safe_connect(layer2_material_option.item_selected, func(_idx): _update_sandwich_from_ui())
	if layer2_thickness_slider: _safe_connect(layer2_thickness_slider.value_changed, func(val):
		if layer2_thickness_label: layer2_thickness_label.text = "%.0f mm" % val
		_update_sandwich_from_ui()
	)

	if layer3_material_option: _safe_connect(layer3_material_option.item_selected, func(_idx): _update_sandwich_from_ui())
	if layer3_thickness_slider: _safe_connect(layer3_thickness_slider.value_changed, func(val):
		if layer3_thickness_label: layer3_thickness_label.text = "%.0f mm" % val
		_update_sandwich_from_ui()
	)

	if spall_liner_check: _safe_connect(spall_liner_check.toggled, func(_toggled): _update_sandwich_from_ui())
	if addon_protection_option: _safe_connect(addon_protection_option.item_selected, func(_idx): _update_sandwich_from_ui())

	if extrude_btn: _safe_connect(extrude_btn.pressed, _on_extrude_pressed)
	if flip_btn: _safe_connect(flip_btn.pressed, _on_flip_normals_pressed)

	if tool_translate_btn: _safe_connect(tool_translate_btn.pressed, _on_tool_translate_pressed)
	if tool_rotate_btn: _safe_connect(tool_rotate_btn.pressed, _on_tool_rotate_pressed)
	if tool_scale_btn: _safe_connect(tool_scale_btn.pressed, _on_tool_scale_pressed)


func _get_current_target_builder() -> Object:
	if mesh_editor != null and mesh_editor.selected_target != null:
		if mesh_editor.selected_target == hull_builder:
			return hull_builder
		elif turret_builder and (mesh_editor.selected_target == turret_builder or mesh_editor.selected_target == turret_builder.turret_mesh_instance):
			return turret_builder
	return hull_builder


func _update_sandwich_from_ui() -> void:
	if _updating_ui:
		return

	var target = _get_current_target_builder()
	if target == null:
		return

	if not ("armor_sandwich" in target) or target.armor_sandwich == null:
		target.armor_sandwich = ArmorCalculator.ArmorSandwich.new()

	var sandwich: ArmorCalculator.ArmorSandwich = target.armor_sandwich

	# Layer 1 Outer
	if layer1_material_option:
		var mat1_id = layer1_material_option.get_selected_id()
		var thick1 = layer1_thickness_slider.value if layer1_thickness_slider else 60.0
		if sandwich.outer_layer == null:
			sandwich.outer_layer = ArmorCalculator.ArmorLayer.new(mat1_id, thick1)
		else:
			sandwich.outer_layer.material = mat1_id
			sandwich.outer_layer.thickness_mm = thick1

	# Layer 2 Filler
	if layer2_material_option:
		var mat2_id = layer2_material_option.get_selected_id()
		var thick2 = layer2_thickness_slider.value if layer2_thickness_slider else 0.0
		if mat2_id == -1 or thick2 <= 0.0:
			sandwich.filler_layer = null
		else:
			if sandwich.filler_layer == null:
				sandwich.filler_layer = ArmorCalculator.ArmorLayer.new(mat2_id, thick2)
			else:
				sandwich.filler_layer.material = mat2_id
				sandwich.filler_layer.thickness_mm = thick2

	# Layer 3 Rear
	if layer3_material_option:
		var mat3_id = layer3_material_option.get_selected_id()
		var thick3 = layer3_thickness_slider.value if layer3_thickness_slider else 50.0
		if sandwich.rear_layer == null:
			sandwich.rear_layer = ArmorCalculator.ArmorLayer.new(mat3_id, thick3)
		else:
			sandwich.rear_layer.material = mat3_id
			sandwich.rear_layer.thickness_mm = thick3

	# Spall Liner
	if spall_liner_check:
		sandwich.has_spall_liner = spall_liner_check.button_pressed

	# Addon Protection
	if addon_protection_option:
		var addon_id = addon_protection_option.get_selected_id()
		sandwich.addon_protection = addon_id

	var total_phys = sandwich.get_total_physical_thickness_mm()
	if thickness_slider:
		thickness_slider.value = total_phys
	if thickness_value_label:
		thickness_value_label.text = "%.0f mm" % total_phys

	if target == hull_builder:
		hull_builder.front_armor_mm = total_phys
		hull_builder.generate_hull_mesh()
	elif turret_builder and (target == turret_builder or target == turret_builder.turret_mesh_instance):
		turret_builder.front_turret_armor_mm = total_phys
		turret_builder.generate_turret_and_gun()

	_update_sandwich_ui_readout()
	_update_ttx()


func _update_sandwich_ui_readout() -> void:
	var target = _get_current_target_builder()
	if target == null or not ("armor_sandwich" in target) or target.armor_sandwich == null:
		return

	var sandwich: ArmorCalculator.ArmorSandwich = target.armor_sandwich
	var total_phys_mm = sandwich.get_total_physical_thickness_mm()
	var mass_kg_m2 = sandwich.get_area_mass_kg_m2()
	var ke_rha_mm = sandwich.get_effective_rha_mm(ArmorCalculator.AmmoType.APFSDS, 1.0)
	var heat_rha_mm = sandwich.get_effective_rha_mm(ArmorCalculator.AmmoType.HEAT, 1.0)

	if sandwich_total_thickness_label:
		sandwich_total_thickness_label.text = "Physical: %.0f mm" % total_phys_mm
	if sandwich_weight_label:
		sandwich_weight_label.text = "Weight: %.0f kg/m²" % mass_kg_m2
	if sandwich_effective_ke_label:
		sandwich_effective_ke_label.text = "Effective KE: %.0f mm RHA" % ke_rha_mm
	if sandwich_effective_heat_label:
		sandwich_effective_heat_label.text = "Effective HEAT: %.0f mm RHA" % heat_rha_mm


func _sync_sandwich_ui_from_target() -> void:
	_updating_ui = true

	var target = _get_current_target_builder()
	if target != null:
		if not ("armor_sandwich" in target) or target.armor_sandwich == null:
			if target == hull_builder:
				target.armor_sandwich = ArmorCalculator.ArmorSandwich.create_default_glacis()
			elif turret_builder and (target == turret_builder or target == turret_builder.turret_mesh_instance):
				target.armor_sandwich = ArmorCalculator.ArmorSandwich.create_default_turret()
			else:
				target.armor_sandwich = ArmorCalculator.ArmorSandwich.new()

		var sandwich: ArmorCalculator.ArmorSandwich = target.armor_sandwich

		if layer1_material_option and sandwich.outer_layer != null:
			_select_option_by_id(layer1_material_option, sandwich.outer_layer.material)
			if layer1_thickness_slider:
				layer1_thickness_slider.value = sandwich.outer_layer.thickness_mm
			if layer1_thickness_label:
				layer1_thickness_label.text = "%.0f mm" % sandwich.outer_layer.thickness_mm

		if layer2_material_option:
			if sandwich.filler_layer != null:
				_select_option_by_id(layer2_material_option, sandwich.filler_layer.material)
				if layer2_thickness_slider:
					layer2_thickness_slider.value = sandwich.filler_layer.thickness_mm
				if layer2_thickness_label:
					layer2_thickness_label.text = "%.0f mm" % sandwich.filler_layer.thickness_mm
			else:
				_select_option_by_id(layer2_material_option, -1)
				if layer2_thickness_slider:
					layer2_thickness_slider.value = 0.0
				if layer2_thickness_label:
					layer2_thickness_label.text = "0 mm"

		if layer3_material_option and sandwich.rear_layer != null:
			_select_option_by_id(layer3_material_option, sandwich.rear_layer.material)
			if layer3_thickness_slider:
				layer3_thickness_slider.value = sandwich.rear_layer.thickness_mm
			if layer3_thickness_label:
				layer3_thickness_label.text = "%.0f mm" % sandwich.rear_layer.thickness_mm

		if spall_liner_check:
			spall_liner_check.button_pressed = sandwich.has_spall_liner

		if addon_protection_option:
			_select_option_by_id(addon_protection_option, sandwich.addon_protection)

	_updating_ui = false
	_update_sandwich_ui_readout()

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

	if not _updating_ui:
		var target = _get_current_target_builder()
		if target and "armor_sandwich" in target and target.armor_sandwich != null:
			if target.armor_sandwich.outer_layer != null:
				target.armor_sandwich.outer_layer.thickness_mm = val
				if layer1_thickness_slider:
					layer1_thickness_slider.value = val
				if layer1_thickness_label:
					layer1_thickness_label.text = "%.0f mm" % val
				_update_sandwich_ui_readout()

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

	_sync_sandwich_ui_from_target()

func _on_face_hovered(thickness_mm: float, angle_deg: float, eff_ke_mm: float, eff_heat_mm: float = 0.0) -> void:
	if eff_heat_mm == 0.0:
		eff_heat_mm = eff_ke_mm
	if hover_inspection_label:
		hover_inspection_label.text = "Thickness: %.0fmm | Angle: %.1f° | Effective KE: %.0fmm RHA | HEAT: %.0fmm RHA" % [thickness_mm, angle_deg, eff_ke_mm, eff_heat_mm]
	if armor_angle_los_label:
		armor_angle_los_label.text = "Angle: %.1f° | KE: %.0fmm | HEAT: %.0fmm RHA" % [angle_deg, eff_ke_mm, eff_heat_mm]


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

