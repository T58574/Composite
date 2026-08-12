extends Control

## Main Controller for Sprocket-style Tank Editor (TankEditor.tscn).
## Manages UI navigation, Sprocket-style headers, inspectors, preset shelf, and TTX calculations.

@export var hull_builder: HullBuilder
@export var turret_builder: TurretBuilder
@export var track_generator: TrackGenerator
@export var firepower_builder: FirepowerBuilder
@export var editor_camera: EditorCamera
@export var mesh_editor: MeshEditor
@export var bounding_box_overlay: BoundingBoxOverlay

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

# Panel Collapse/Expand Toggle Buttons & Panel References
@onready var toggle_left_btn: Button = %ToggleLeftBtn
@onready var toggle_right_btn: Button = %ToggleRightBtn
@onready var left_sidebar: Control = %LeftSidebar
@onready var right_structure_inspector: Control = %RightStructureInspector

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

# Preset Shape Options
@export var hull_preset_card_selector: PresetCardSelector
@export var turret_preset_card_selector: PresetCardSelector
@onready var hull_preset_option: OptionButton = %HullPresetOption
@onready var turret_preset_option: OptionButton = %TurretPresetOption
@onready var sprocket_location_option: OptionButton = %SprocketLocationOption

# Sliders & Numeric Value Labels
@onready var hull_length_slider: HSlider = %HullLengthSlider
@onready var hull_length_value_label: Label = %HullLengthValueLabel
@onready var hull_width_slider: HSlider = %HullWidthSlider
@onready var hull_width_value_label: Label = %HullWidthValueLabel
@onready var hull_height_slider: HSlider = %HullHeightSlider
@onready var hull_height_value_label: Label = %HullHeightValueLabel
@onready var glacis_angle_slider: HSlider = %GlacisAngleSlider
@onready var glacis_angle_value_label: Label = %GlacisAngleValueLabel

@onready var turret_x_slider: HSlider = %TurretXSlider
@onready var turret_x_value_label: Label = %TurretXValueLabel
@onready var turret_z_slider: HSlider = %TurretZSlider
@onready var turret_z_value_label: Label = %TurretZValueLabel

@onready var wheels_count_slider: HSlider = %WheelsCountSlider
@onready var wheels_count_value_label: Label = %WheelsCountValueLabel
@onready var wheel_diam_slider: HSlider = %WheelDiamSlider
@onready var wheel_diam_value_label: Label = %WheelDiamValueLabel
@onready var track_w_slider: HSlider = %TrackWSlider
@onready var track_w_value_label: Label = %TrackWValueLabel

@onready var engine_power_slider: HSlider = %EnginePowerSlider
@onready var engine_power_value_label: Label = %EnginePowerValueLabel

@onready var gun_caliber_slider: HSlider = %GunCaliberSlider
@onready var gun_caliber_value_label: Label = %GunCaliberValueLabel
@onready var barrel_length_slider: HSlider = %BarrelLengthSlider
@onready var barrel_length_value_label: Label = %BarrelLengthValueLabel

@onready var crew_count_slider: HSlider = %CrewCountSlider
@onready var crew_count_value_label: Label = %CrewCountValueLabel

# Right Structure Inspector Nodes
@onready var part_name_label: Label = %PartNameLabel
@onready var mode_points_btn: Button = %ModePointsBtn
@onready var mode_edges_btn: Button = %ModeEdgesBtn
@onready var mode_faces_btn: Button = %ModeFacesBtn
@onready var mode_corners_btn: Button = %ModeCornersBtn

@onready var mirror_check: CheckBox = %MirrorCheck
@onready var smooth_angle_slider: HSlider = %SmoothAngleSlider
@onready var smooth_angle_value_label: Label = %SmoothAngleValueLabel
@onready var grid_size_slider: HSlider = %GridSizeSlider
@onready var grid_size_value_label: Label = %GridSizeValueLabel

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

# Bottom Gizmo / Viewport Toolbar & Preset Tabs
@onready var turrets_tab: Button = %TurretsTab
@onready var structural_tab: Button = %StructuralTab
@onready var addon_tab: Button = %AddonTab

@onready var tool_translate_btn: Button = %ToolTranslateBtn
@onready var tool_rotate_btn: Button = %ToolRotateBtn
@onready var tool_scale_btn: Button = %ToolScaleBtn
@onready var tool_snap_btn: Button = %ToolSnapBtn

@onready var hover_inspection_label: Label = %HoverInspectionLabel
@onready var fps_label: Label = %FPSLabel

var _updating_ui: bool = false
var _left_sidebar_collapsed: bool = false
var _right_inspector_collapsed: bool = false


# ==============================================================================
# 1. LIFECYCLE & INITIALIZATION
# ==============================================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_options()
	_connect_signals()
	_sync_sandwich_ui_from_target()
	_update_ttx()
	_sync_sliders_with_builders()

	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_signal("settings_changed"):
		if not sm.settings_changed.is_connected(_on_settings_changed):
			sm.settings_changed.connect(_on_settings_changed)

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _on_settings_changed() -> void:
	_setup_options()
	_on_selection_changed()


# ==============================================================================
# 2. UI SETUP & SIGNAL CONNECTIONS
# ==============================================================================

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

	# Hide preset cards and preset options completely (Pure from-scratch primitive builder mode)
	if hull_preset_card_selector:
		hull_preset_card_selector.visible = false
	if turret_preset_card_selector:
		turret_preset_card_selector.visible = false
	if hull_preset_option and hull_preset_option.get_parent():
		hull_preset_option.get_parent().visible = false
	if turret_preset_option and turret_preset_option.get_parent():
		turret_preset_option.get_parent().visible = false

	# Drive Sprocket Location Options
	if sprocket_location_option:
		var sel = sprocket_location_option.selected if sprocket_location_option.item_count > 0 else 0
		sprocket_location_option.clear()
		sprocket_location_option.add_item("Front Drive Sprocket", 0)
		sprocket_location_option.add_item("Rear Drive Sprocket", 1)
		sprocket_location_option.select(sel)

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

	# Panel Collapse/Expand Toggles
	if toggle_left_btn: _safe_connect(toggle_left_btn.pressed, _on_toggle_left_pressed)
	if toggle_right_btn: _safe_connect(toggle_right_btn.pressed, _on_toggle_right_pressed)

	# Top Header & Visualization Mode Buttons
	if test_drive_btn: _safe_connect(test_drive_btn.pressed, _on_test_drive_pressed)
	if solid_btn: _safe_connect(solid_btn.pressed, _on_solid_btn_pressed)
	if heatmap_btn: _safe_connect(heatmap_btn.pressed, _on_heatmap_btn_pressed)
	if xray_btn: _safe_connect(xray_btn.pressed, _on_xray_btn_pressed)
	if symmetry_check: _safe_connect(symmetry_check.toggled, _on_symmetry_toggled)

	# Left Sidebar Category Buttons
	if cat_compartments_btn: _safe_connect(cat_compartments_btn.pressed, func(): _on_category_selected(0))
	if cat_tracks_btn: _safe_connect(cat_tracks_btn.pressed, func(): _on_category_selected(1))
	if cat_powertrain_btn: _safe_connect(cat_powertrain_btn.pressed, func(): _on_category_selected(2))
	if cat_firepower_btn: _safe_connect(cat_firepower_btn.pressed, func(): _on_category_selected(3))
	if cat_crew_btn: _safe_connect(cat_crew_btn.pressed, func(): _on_category_selected(4))
	if cat_paint_btn: _safe_connect(cat_paint_btn.pressed, func(): _on_category_selected(5))
	if cat_decals_btn: _safe_connect(cat_decals_btn.pressed, func(): _on_category_selected(6))

	if paint_scheme_option: _safe_connect(paint_scheme_option.item_selected, _on_paint_scheme_selected)

	# Hull Sliders & Preset Selection
	if hull_preset_option: _safe_connect(hull_preset_option.item_selected, _on_hull_preset_selected)
	if hull_length_slider: _safe_connect(hull_length_slider.value_changed, _on_hull_slider_changed)
	if hull_width_slider: _safe_connect(hull_width_slider.value_changed, _on_hull_slider_changed)
	if hull_height_slider: _safe_connect(hull_height_slider.value_changed, _on_hull_slider_changed)
	if glacis_angle_slider: _safe_connect(glacis_angle_slider.value_changed, _on_hull_slider_changed)

	# Turret Offset Position Sliders
	if turret_x_slider: _safe_connect(turret_x_slider.value_changed, _on_turret_offset_changed)
	if turret_z_slider: _safe_connect(turret_z_slider.value_changed, _on_turret_offset_changed)

	# Chassis & Sprocket Controls
	if sprocket_location_option: _safe_connect(sprocket_location_option.item_selected, _on_sprocket_location_selected)
	if wheels_count_slider: _safe_connect(wheels_count_slider.value_changed, _on_chassis_changed)
	if wheel_diam_slider: _safe_connect(wheel_diam_slider.value_changed, _on_chassis_changed)
	if track_w_slider: _safe_connect(track_w_slider.value_changed, _on_chassis_changed)

	# Powertrain & Firepower Sliders & Preset Selection
	if engine_power_slider: _safe_connect(engine_power_slider.value_changed, func(_v):
		if not _updating_ui:
			_update_slider_labels()
			_update_ttx()
	)
	if turret_preset_option: _safe_connect(turret_preset_option.item_selected, _on_turret_preset_selected)
	if gun_caliber_slider: _safe_connect(gun_caliber_slider.value_changed, _on_firepower_changed)
	if barrel_length_slider: _safe_connect(barrel_length_slider.value_changed, _on_firepower_changed)
	if crew_count_slider: _safe_connect(crew_count_slider.value_changed, _on_crew_changed)

	# Structure Inspector Sub-mode Buttons
	if mode_points_btn: _safe_connect(mode_points_btn.pressed, _on_mode_points_pressed)
	if mode_edges_btn: _safe_connect(mode_edges_btn.pressed, _on_mode_edges_pressed)
	if mode_faces_btn: _safe_connect(mode_faces_btn.pressed, _on_mode_faces_pressed)
	if mode_corners_btn: _safe_connect(mode_corners_btn.pressed, _on_mode_corners_pressed)
	if mirror_check: _safe_connect(mirror_check.toggled, _on_symmetry_toggled)

	# Structure Inspector Sliders
	if smooth_angle_slider: _safe_connect(smooth_angle_slider.value_changed, _on_smooth_angle_changed)
	if grid_size_slider: _safe_connect(grid_size_slider.value_changed, _on_grid_size_changed)

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

	# Bottom Preset Tabs
	if turrets_tab: _safe_connect(turrets_tab.pressed, _on_turrets_tab_pressed)
	if structural_tab: _safe_connect(structural_tab.pressed, _on_structural_tab_pressed)
	if addon_tab: _safe_connect(addon_tab.pressed, _on_addon_tab_pressed)


# ==============================================================================
# 3. UI SYNC & READOUT UPDATES
# ==============================================================================

func _sync_sliders_with_builders() -> void:
	_updating_ui = true
	if hull_builder:
		if hull_length_slider: hull_length_slider.value = hull_builder.length
		if hull_width_slider: hull_width_slider.value = hull_builder.width
		if hull_height_slider: hull_height_slider.value = hull_builder.height
		if glacis_angle_slider: glacis_angle_slider.value = hull_builder.front_glacis_angle_deg
		if thickness_slider: thickness_slider.value = hull_builder.front_armor_mm

	if turret_builder:
		if turret_x_slider: turret_x_slider.value = turret_builder.position.x
		if turret_z_slider: turret_z_slider.value = turret_builder.position.z

	if track_generator:
		if wheels_count_slider: wheels_count_slider.value = track_generator.road_wheels_count
		if wheel_diam_slider: wheel_diam_slider.value = track_generator.wheel_diameter
		if track_w_slider: track_w_slider.value = track_generator.track_width
		if sprocket_location_option and "sprocket_at_front" in track_generator:
			sprocket_location_option.select(0 if track_generator.sprocket_at_front else 1)

	if firepower_builder:
		if gun_caliber_slider: gun_caliber_slider.value = firepower_builder.caliber_mm
		if barrel_length_slider: barrel_length_slider.value = firepower_builder.barrel_length_m

	_updating_ui = false
	_update_slider_labels()

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

func _update_slider_labels() -> void:
	if hull_length_slider and hull_length_value_label:
		hull_length_value_label.text = "%.1f m" % hull_length_slider.value
	if hull_width_slider and hull_width_value_label:
		hull_width_value_label.text = "%.1f m" % hull_width_slider.value
	if hull_height_slider and hull_height_value_label:
		hull_height_value_label.text = "%.1f m" % hull_height_slider.value
	if glacis_angle_slider and glacis_angle_value_label:
		glacis_angle_value_label.text = "%.0f°" % glacis_angle_slider.value

	if turret_x_slider and turret_x_value_label:
		turret_x_value_label.text = "%.2f m" % turret_x_slider.value
	if turret_z_slider and turret_z_value_label:
		turret_z_value_label.text = "%.2f m" % turret_z_slider.value

	if wheels_count_slider and wheels_count_value_label:
		wheels_count_value_label.text = "%d pairs" % int(wheels_count_slider.value)
	if wheel_diam_slider and wheel_diam_value_label:
		wheel_diam_value_label.text = "%.2f m" % wheel_diam_slider.value
	if track_w_slider and track_w_value_label:
		track_w_value_label.text = "%.2f m" % track_w_slider.value

	if engine_power_slider and engine_power_value_label:
		engine_power_value_label.text = "%.0f hp" % engine_power_slider.value

	if gun_caliber_slider and gun_caliber_value_label:
		gun_caliber_value_label.text = "%.0f mm" % gun_caliber_slider.value
	if barrel_length_slider and barrel_length_value_label:
		barrel_length_value_label.text = "%.1f m" % barrel_length_slider.value

	if crew_count_slider and crew_count_value_label:
		crew_count_value_label.text = "%d crew" % int(crew_count_slider.value)

	if smooth_angle_slider and smooth_angle_value_label:
		smooth_angle_value_label.text = "%.0f°" % smooth_angle_slider.value
	if grid_size_slider and grid_size_value_label:
		grid_size_value_label.text = "%.0f mm" % grid_size_slider.value

	if thickness_slider and thickness_value_label:
		thickness_value_label.text = "%.0f mm" % thickness_slider.value

func _update_ttx() -> void:
	if _updating_ui:
		return
	var power_hp = engine_power_slider.value if engine_power_slider else 1200.0
	var ttx = TankStatsCalculator.calculate_stats(hull_builder, turret_builder, track_generator, power_hp)

	if mass_badge_label and ttx: mass_badge_label.text = "%.2ft" % ttx.total_mass_tons
	if space_badge_label and ttx: space_badge_label.text = "%.2fk" % (ttx.total_mass_tons * 0.8)

func _get_current_target_builder() -> Object:
	if mesh_editor != null and mesh_editor.selected_target != null:
		if mesh_editor.selected_target == hull_builder:
			return hull_builder
		elif turret_builder and (mesh_editor.selected_target == turret_builder or mesh_editor.selected_target == turret_builder.turret_mesh_instance):
			return turret_builder
	return hull_builder


# ==============================================================================
# 4. HEADER & MAIN ACTIONS
# ==============================================================================

var _in_constructor_test_drive: bool = false
var _test_vehicle_body: RigidBody3D = null
var _test_chase_cam: Node3D = null
var _test_shooting_sys: ShootingSystem = null
var _test_drive_hud_overlay: Control = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit:
				return
			get_viewport().set_input_as_handled()
			toggle_in_constructor_test_drive()

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_test_drive_pressed() -> void:
	var name_str = tank_name_edit.text if tank_name_edit and tank_name_edit.text != "" else "Temp_Tank"
	var era_str = era_option.get_item_text(era_option.selected) if (era_option and era_option.selected >= 0 and era_option.item_count > era_option.selected) else "Midwar"
	TankSerializer.save_preset("user://temp_tank.json", name_str, era_str, hull_builder, turret_builder, track_generator, firepower_builder)
	get_tree().change_scene_to_file("res://scenes/combat/test_range.tscn")

func toggle_in_constructor_test_drive() -> void:
	_in_constructor_test_drive = not _in_constructor_test_drive
	if _in_constructor_test_drive:
		_start_in_constructor_test_drive()
	else:
		_stop_in_constructor_test_drive()

func _ensure_ground_collision() -> void:
	var scene_root = get_tree().current_scene
	if scene_root == null or scene_root.get_node_or_null("ConstructorGroundBody") != null:
		return
	var static_body = StaticBody3D.new()
	static_body.name = "ConstructorGroundBody"
	static_body.transform = Transform3D(Basis.IDENTITY, Vector3(0, -1.0, 0))
	var col_shape = CollisionShape3D.new()
	col_shape.name = "GroundCollision"
	var box = BoxShape3D.new()
	box.size = Vector3(500.0, 2.0, 500.0)
	col_shape.shape = box
	static_body.add_child(col_shape)
	scene_root.add_child(static_body)

func _start_in_constructor_test_drive() -> void:
	_ensure_ground_collision()
	if left_sidebar: left_sidebar.visible = false
	if right_structure_inspector: right_structure_inspector.visible = false
	if category_stack: category_stack.visible = false
	if bounding_box_overlay: bounding_box_overlay.visible = false
	var top_header = get_node_or_null("%TopHeader") if has_node("%TopHeader") else null
	if top_header: top_header.visible = false

	var scene_root = get_tree().current_scene

	if _test_vehicle_body == null:
		_test_vehicle_body = RigidBody3D.new()
		_test_vehicle_body.name = "ConstructorTestVehicle"
		_test_vehicle_body.script = load("res://scripts/physics/raycast_suspension.gd")
		scene_root.add_child(_test_vehicle_body)

	_test_vehicle_body.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0))
	_test_vehicle_body.freeze = false
	_test_vehicle_body.linear_velocity = Vector3.ZERO
	_test_vehicle_body.angular_velocity = Vector3.ZERO

	if hull_builder and hull_builder.get_parent() != _test_vehicle_body:
		hull_builder.reparent(_test_vehicle_body)
		hull_builder.transform = Transform3D.IDENTITY
	if turret_builder and turret_builder.get_parent() != _test_vehicle_body:
		turret_builder.reparent(_test_vehicle_body)
		turret_builder.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0))
	if track_generator and track_generator.get_parent() != _test_vehicle_body:
		track_generator.reparent(_test_vehicle_body)
		track_generator.transform = Transform3D.IDENTITY

	var power_hp = engine_power_slider.value if engine_power_slider else 1200.0
	_test_vehicle_body.setup_vehicle_from_builder(hull_builder, turret_builder, track_generator, power_hp)

	if _test_chase_cam == null:
		var cam_script = load("res://scripts/combat/chase_camera.gd")
		_test_chase_cam = Node3D.new()
		_test_chase_cam.name = "TestDriveChaseCam"
		_test_chase_cam.script = cam_script
		var cam3d = Camera3D.new()
		cam3d.name = "Camera3D"
		_test_chase_cam.add_child(cam3d)
		scene_root.add_child(_test_chase_cam)

	_test_chase_cam.target = _test_vehicle_body
	var cam_node = _test_chase_cam.get_node_or_null("Camera3D")
	if cam_node is Camera3D:
		cam_node.make_current()

	if editor_camera:
		editor_camera.enabled = false

	if _test_shooting_sys == null:
		_test_shooting_sys = ShootingSystem.new()
		_test_shooting_sys.name = "TestDriveShootingSys"
		_test_vehicle_body.add_child(_test_shooting_sys)
		_test_shooting_sys.turret_builder = turret_builder

	if _test_drive_hud_overlay == null:
		_test_drive_hud_overlay = Control.new()
		_test_drive_hud_overlay.name = "TestDriveHUD"
		_test_drive_hud_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_test_drive_hud_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var banner = Label.new()
		banner.name = "HUDLabel"
		banner.text = "🎯 [ПРОБЕЛ] - ВЕРНУТЬСЯ В РЕДАКТОР  |  WASD - ДВИЖЕНИЕ  |  ЛКМ - СТРЕЛЬБА"
		banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		banner.offset_top = 25
		banner.offset_left = -400
		banner.offset_right = 400
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_theme_font_size_override("font_size", 22)
		banner.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
		_test_drive_hud_overlay.add_child(banner)
		add_child(_test_drive_hud_overlay)

	_test_drive_hud_overlay.visible = true

func _stop_in_constructor_test_drive() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _test_drive_hud_overlay:
		_test_drive_hud_overlay.visible = false

	if _test_vehicle_body:
		_test_vehicle_body.freeze = true
		_test_vehicle_body.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))

	var scene_root = get_tree().current_scene
	if hull_builder and is_instance_valid(hull_builder):
		hull_builder.reparent(scene_root)
		hull_builder.transform = Transform3D.IDENTITY
		hull_builder.generate_hull_mesh()
	if turret_builder and is_instance_valid(turret_builder):
		turret_builder.reparent(scene_root)
		turret_builder.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0))
		turret_builder.generate_turret_and_gun()
	if track_generator and is_instance_valid(track_generator):
		track_generator.reparent(scene_root)
		track_generator.transform = Transform3D.IDENTITY
		track_generator.generate_tracks_and_wheels()

	if editor_camera:
		editor_camera.enabled = true
		if editor_camera.camera_3d:
			editor_camera.camera_3d.make_current()

	if left_sidebar: left_sidebar.visible = not _left_sidebar_collapsed
	if right_structure_inspector: right_structure_inspector.visible = not _right_inspector_collapsed
	if category_stack: category_stack.visible = not _left_sidebar_collapsed
	if bounding_box_overlay:
		bounding_box_overlay.visible = bounding_box_overlay.show_overlay
		if bounding_box_overlay.has_method("update_overlay"):
			bounding_box_overlay.update_overlay()
	var top_header = get_node_or_null("%TopHeader") if has_node("%TopHeader") else null
	if top_header: top_header.visible = true

func _on_save_preset_pressed() -> void:
	var name_str = tank_name_edit.text if tank_name_edit and tank_name_edit.text != "" else "Custom_Tank"
	var era_str = era_option.get_item_text(era_option.selected) if (era_option and era_option.selected >= 0 and era_option.item_count > era_option.selected) else "Midwar"
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


# ==============================================================================
# 5. SIDEBAR & VIEW CONTROLS
# ==============================================================================

func _on_toggle_left_pressed() -> void:
	_left_sidebar_collapsed = not _left_sidebar_collapsed
	if left_sidebar: left_sidebar.visible = not _left_sidebar_collapsed
	if category_stack: category_stack.visible = not _left_sidebar_collapsed
	if toggle_left_btn:
		toggle_left_btn.text = "▶ Sidebar" if _left_sidebar_collapsed else "◀ Sidebar"

func _on_toggle_right_pressed() -> void:
	_right_inspector_collapsed = not _right_inspector_collapsed
	if right_structure_inspector: right_structure_inspector.visible = not _right_inspector_collapsed
	if toggle_right_btn:
		toggle_right_btn.text = "Inspector ◀" if _right_inspector_collapsed else "Inspector ▶"

func _on_category_selected(cat_index: int) -> void:
	if category_stack:
		for i in range(category_stack.get_child_count()):
			category_stack.get_child(i).visible = (i == cat_index)

func _on_solid_btn_pressed() -> void:
	if mesh_editor: mesh_editor.set_visualization_mode(MeshEditor.VisualizationMode.SOLID)

func _on_heatmap_btn_pressed() -> void:
	if mesh_editor: mesh_editor.set_visualization_mode(MeshEditor.VisualizationMode.ARMOR_HEATMAP)

func _on_xray_btn_pressed() -> void:
	if mesh_editor: mesh_editor.set_visualization_mode(MeshEditor.VisualizationMode.XRAY)

func _on_symmetry_toggled(button_pressed: bool) -> void:
	if _updating_ui:
		return
	if mesh_editor: mesh_editor.symmetry_x_enabled = button_pressed
	if mirror_check and mirror_check.button_pressed != button_pressed:
		mirror_check.set_pressed_no_signal(button_pressed)
	if symmetry_check and symmetry_check.button_pressed != button_pressed:
		symmetry_check.set_pressed_no_signal(button_pressed)


# ==============================================================================
# 6. PRESETS & PRESET TABS
# ==============================================================================

func _on_hull_preset_selected(index: int) -> void:
	if hull_builder == null or _updating_ui:
		return
	_updating_ui = true
	if hull_preset_option and hull_preset_option.selected != index:
		hull_preset_option.select(index)
	if hull_preset_card_selector and hull_preset_card_selector.selected_index != index:
		hull_preset_card_selector.select_card(index, false)
	match index:
		0: # Standard Wedge MBT
			hull_builder.set_dimensions(6.8, 3.4, 1.4, 60.0)
			hull_builder.front_armor_mm = 550.0
		1: # Heavy Box (Challenger 2 style)
			hull_builder.set_dimensions(7.7, 3.6, 1.5, 35.0)
			hull_builder.front_armor_mm = 650.0
		2: # Pike Nose (T-90M Relikt style)
			hull_builder.set_dimensions(6.8, 3.4, 1.25, 72.0)
			hull_builder.front_armor_mm = 700.0
		3: # Modern Angular MBT (M1A2 Abrams / Leopard 2A7 style)
			hull_builder.set_dimensions(7.8, 3.7, 1.3, 68.0)
			hull_builder.front_armor_mm = 750.0
		4: # Compact Light
			hull_builder.set_dimensions(5.4, 2.8, 1.2, 50.0)
			hull_builder.front_armor_mm = 180.0
	_updating_ui = false
	_sync_sliders_with_builders()
	_update_ttx()

func _on_turret_preset_selected(index: int) -> void:
	if turret_builder == null or _updating_ui:
		return
	_updating_ui = true
	if turret_preset_option and turret_preset_option.selected != index:
		turret_preset_option.select(index)
	if turret_preset_card_selector and turret_preset_card_selector.selected_index != index:
		turret_preset_card_selector.select_card(index, false)
	match index:
		0: # Standard Wedge
			turret_builder.set_turret_dimensions(3.4, 2.8, 1.1, 45.0, 6.2, 750.0)
		1: # Cast Dome (T-54 / T-62)
			turret_builder.set_turret_dimensions(2.8, 2.6, 0.95, 65.0, 5.8, 450.0)
		2: # Box Bustle (Abrams style)
			turret_builder.set_turret_dimensions(4.0, 3.0, 1.15, 35.0, 6.6, 850.0)
		3: # Angular MBT (Leopard 2A7 style)
			turret_builder.set_turret_dimensions(4.2, 3.3, 1.1, 48.0, 6.6, 950.0)
		4: # Compact Light
			turret_builder.set_turret_dimensions(2.5, 2.1, 0.85, 40.0, 4.8, 220.0)
	_updating_ui = false
	_sync_sliders_with_builders()
	_update_ttx()

func _on_turrets_tab_pressed() -> void:
	_on_category_selected(3) # Switch to Firepower/Turret tab
	if turret_preset_option:
		var next_idx = (turret_preset_option.selected + 1) % turret_preset_option.item_count
		turret_preset_option.select(next_idx)
		_on_turret_preset_selected(next_idx)

func _on_structural_tab_pressed() -> void:
	_on_category_selected(0) # Switch to Compartments/Hull tab
	if hull_preset_option:
		var next_idx = (hull_preset_option.selected + 1) % hull_preset_option.item_count
		hull_preset_option.select(next_idx)
		_on_hull_preset_selected(next_idx)

func _on_addon_tab_pressed() -> void:
	_on_category_selected(5) # Switch to Paint/Addon tab


# ==============================================================================
# 7. BUILDER PARAMETER HANDLERS
# ==============================================================================

func _on_hull_slider_changed(_val: float) -> void:
	if _updating_ui:
		return
	if hull_builder:
		var l = hull_length_slider.value if hull_length_slider else 6.8
		var w = hull_width_slider.value if hull_width_slider else 3.4
		var h = hull_height_slider.value if hull_height_slider else 1.4
		var g = glacis_angle_slider.value if glacis_angle_slider else 60.0
		hull_builder.set_dimensions(l, w, h, g)
	_update_slider_labels()
	_update_ttx()

func _on_turret_offset_changed(_val: float = 0.0) -> void:
	if _updating_ui:
		return
	var x_off = turret_x_slider.value if turret_x_slider else 0.0
	var z_off = turret_z_slider.value if turret_z_slider else 0.0

	if turret_builder:
		if turret_builder.has_method("set_turret_offset"):
			turret_builder.set_turret_offset(x_off, z_off)
		else:
			turret_builder.position.x = x_off
			turret_builder.position.z = z_off
	if firepower_builder:
		firepower_builder.position.x = x_off
		firepower_builder.position.z = z_off

	_update_slider_labels()
	_update_ttx()

func _on_sprocket_location_selected(index: int) -> void:
	if _updating_ui:
		return
	if track_generator:
		if track_generator.has_method("set_sprocket_location"):
			track_generator.set_sprocket_location(index)
		elif "sprocket_at_front" in track_generator:
			track_generator.sprocket_at_front = (index == 0)
			track_generator.generate_tracks_and_wheels()
	_update_ttx()

func _on_chassis_changed(_val: float) -> void:
	if _updating_ui:
		return
	if track_generator:
		var cnt = int(wheels_count_slider.value) if wheels_count_slider else 6
		var diam = wheel_diam_slider.value if wheel_diam_slider else 0.65
		var w = track_w_slider.value if track_w_slider else 0.6
		track_generator.set_chassis_parameters(cnt, diam, w, 0.6)
	_update_slider_labels()
	_update_ttx()

func _on_firepower_changed(_val: float) -> void:
	if _updating_ui:
		return
	if firepower_builder:
		var cal = gun_caliber_slider.value if gun_caliber_slider else 120.0
		var len_m = barrel_length_slider.value if barrel_length_slider else 6.2
		firepower_builder.set_caliber_and_length(cal, len_m)
	_update_slider_labels()
	_update_ttx()

func _on_crew_changed(_val: float) -> void:
	if _updating_ui:
		return
	_update_slider_labels()
	_update_ttx()


# ==============================================================================
# 8. MESH EDITOR & GIZMO HANDLERS
# ==============================================================================

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

func _on_mode_points_pressed() -> void:
	if mesh_editor: mesh_editor.set_edit_mode(MeshEditor.EditMode.VERTEX)

func _on_mode_edges_pressed() -> void:
	if mesh_editor: mesh_editor.set_edit_mode(MeshEditor.EditMode.EDGE)

func _on_mode_faces_pressed() -> void:
	if mesh_editor: mesh_editor.set_edit_mode(MeshEditor.EditMode.FACE)

func _on_mode_corners_pressed() -> void:
	if mesh_editor: mesh_editor.set_edit_mode(MeshEditor.EditMode.CORNER)

func _on_extrude_pressed() -> void:
	if mesh_editor: mesh_editor.extrude_selected_face()

func _on_flip_normals_pressed() -> void:
	if mesh_editor: mesh_editor.flip_selected_normals()

func _on_smooth_angle_changed(val: float) -> void:
	if _updating_ui:
		return
	if mesh_editor and "smooth_angle" in mesh_editor:
		mesh_editor.smooth_angle = val
	_update_slider_labels()

func _on_grid_size_changed(val: float) -> void:
	if _updating_ui:
		return
	if mesh_editor and "grid_snap_size" in mesh_editor:
		mesh_editor.grid_snap_size = val
	_update_slider_labels()


# ==============================================================================
# 9. ARMOR & SANDWICH HANDLERS
# ==============================================================================

func _on_thickness_slider_changed(val: float) -> void:
	if _updating_ui:
		return
	if thickness_value_label:
		thickness_value_label.text = "%.0f mm" % val

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
	_update_slider_labels()
	_update_ttx()

func _on_armor_type_selected(index: int) -> void:
	if _updating_ui:
		return
	var is_comp = (index != 0)
	if mesh_editor and mesh_editor.heatmap_material:
		mesh_editor.heatmap_material.set_shader_parameter("is_composite", is_comp)

func _on_paint_scheme_selected(index: int) -> void:
	if _updating_ui:
		return
	if mesh_editor and mesh_editor.pbr_material is ShaderMaterial:
		mesh_editor.pbr_material.set_shader_parameter("camo_type", index)

func set_edge_wear(val: float) -> void:
	if mesh_editor and mesh_editor.pbr_material is ShaderMaterial:
		mesh_editor.pbr_material.set_shader_parameter("edge_wear", val)

func set_dirt_amount(val: float) -> void:
	if mesh_editor and mesh_editor.pbr_material is ShaderMaterial:
		mesh_editor.pbr_material.set_shader_parameter("dirt_amount", val)

func set_paint_metallic(val: float) -> void:
	if mesh_editor and mesh_editor.pbr_material is ShaderMaterial:
		mesh_editor.pbr_material.set_shader_parameter("metallic", val)

func set_paint_roughness(val: float) -> void:
	if mesh_editor and mesh_editor.pbr_material is ShaderMaterial:
		mesh_editor.pbr_material.set_shader_parameter("roughness", val)


# ==============================================================================
# 10. INSPECTION & HOVER CALLBACKS
# ==============================================================================

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

