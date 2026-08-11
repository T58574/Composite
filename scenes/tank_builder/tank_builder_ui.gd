extends Control

## Main UI Controller for TankBuilder3D scene.
## Handles real-time procedural vehicle customization, turret elevation/traverse, mass & armor stats updates.

@export var hull_builder: HullBuilder
@export var turret_builder: TurretBuilder
@export var orbit_camera_pivot: Node3D
@export var camera_node: Camera3D

# UI Nodes - Hull
@onready var length_slider: HSlider = %LengthSlider
@onready var width_slider: HSlider = %WidthSlider
@onready var height_slider: HSlider = %HeightSlider
@onready var glacis_slider: HSlider = %GlacisSlider
@onready var armor_slider: HSlider = %ArmorSlider

# UI Nodes - Turret & Gun
@onready var turret_l_slider: HSlider = %TurretLengthSlider
@onready var turret_w_slider: HSlider = %TurretWidthSlider
@onready var barrel_slider: HSlider = %BarrelSlider
@onready var yaw_slider: HSlider = %TurretYawSlider
@onready var pitch_slider: HSlider = %GunPitchSlider

@onready var mass_label: Label = %MassLabel
@onready var volume_label: Label = %VolumeLabel
@onready var armor_eff_label: Label = %ArmorEffLabel
@onready var status_label: Label = %StatusLabel

# Orbit Camera settings
var is_orbiting: bool = false
var orbit_sensitivity: float = 0.3
var zoom_speed: float = 0.5
var camera_distance: float = 12.0

func _ready() -> void:
	_connect_ui_signals()
	if not SettingsManager.settings_changed.is_connected(_update_stats_display):
		SettingsManager.settings_changed.connect(_update_stats_display)
	_update_stats_display()

func _unhandled_input(event: InputEvent) -> void:
	# Right-click drag to orbit camera around vehicle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clamp(camera_distance - zoom_speed, 4.0, 30.0)
			_update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clamp(camera_distance + zoom_speed, 4.0, 30.0)
			_update_camera_position()
			
	elif event is InputEventMouseMotion and is_orbiting:
		if orbit_camera_pivot:
			orbit_camera_pivot.rotate_y(deg_to_rad(-event.relative.x * orbit_sensitivity))
			var rot_x = orbit_camera_pivot.rotation_degrees.x - (event.relative.y * orbit_sensitivity)
			orbit_camera_pivot.rotation_degrees.x = clamp(rot_x, -45.0, 60.0)

func _update_camera_position() -> void:
	if camera_node:
		camera_node.position.z = camera_distance

func _connect_ui_signals() -> void:
	if length_slider: length_slider.value_changed.connect(_on_dimension_changed)
	if width_slider: width_slider.value_changed.connect(_on_dimension_changed)
	if height_slider: height_slider.value_changed.connect(_on_dimension_changed)
	if glacis_slider: glacis_slider.value_changed.connect(_on_dimension_changed)
	if armor_slider: armor_slider.value_changed.connect(_on_dimension_changed)
	
	if turret_l_slider: turret_l_slider.value_changed.connect(_on_turret_changed)
	if turret_w_slider: turret_w_slider.value_changed.connect(_on_turret_changed)
	if barrel_slider: barrel_slider.value_changed.connect(_on_turret_changed)
	
	if yaw_slider: yaw_slider.value_changed.connect(_on_aim_changed)
	if pitch_slider: pitch_slider.value_changed.connect(_on_aim_changed)

func _on_dimension_changed(_value: float) -> void:
	if hull_builder == null:
		return
		
	var l = length_slider.value if length_slider else 6.8
	var w = width_slider.value if width_slider else 3.4
	var h = height_slider.value if height_slider else 1.4
	var g = glacis_slider.value if glacis_slider else 60.0
	var front_mm = armor_slider.value if armor_slider else 450.0
	
	hull_builder.front_armor_mm = front_mm
	hull_builder.set_dimensions(l, w, h, g)
	
	# Reposition Turret on top of Hull
	if turret_builder:
		turret_builder.position.y = (h * 0.5) + 0.55
		
	_update_stats_display()

func _on_turret_changed(_value: float) -> void:
	if turret_builder == null:
		return
		
	var tl = turret_l_slider.value if turret_l_slider else 3.2
	var tw = turret_w_slider.value if turret_w_slider else 2.8
	var bl = barrel_slider.value if barrel_slider else 6.2
	
	turret_builder.set_turret_dimensions(tl, tw, 1.1, 45.0, bl, 750.0)
	_update_stats_display()

func _on_aim_changed(_value: float) -> void:
	if turret_builder == null:
		return
		
	var yaw = yaw_slider.value if yaw_slider else 0.0
	var pitch = pitch_slider.value if pitch_slider else 0.0
	turret_builder.set_aim_target(yaw, pitch)

func _update_stats_display() -> void:
	var hull_mass = hull_builder.calculated_mass_kg if hull_builder else 0.0
	var turret_mass = turret_builder.calculated_turret_mass_kg if turret_builder else 0.0
	var total_mass_tons = (hull_mass + turret_mass) / 1000.0
	var vol_m3 = hull_builder.calculated_volume_m3 if hull_builder else 0.0
	
	# Effective armor math: T_eff = T / cos(glacis_angle)
	var eff_front_armor = 0.0
	if hull_builder:
		eff_front_armor = ArmorCalculator.calculate_effective_thickness(
			hull_builder.front_armor_mm,
			Vector3(0, sin(deg_to_rad(hull_builder.front_glacis_angle_deg)), cos(deg_to_rad(hull_builder.front_glacis_angle_deg))),
			Vector3(0, 0, -1)
		)
	
	if mass_label: mass_label.text = tr("STATS_TOTAL_MASS") % [total_mass_tons, hull_mass / 1000.0, turret_mass / 1000.0]
	if volume_label: volume_label.text = tr("STATS_HULL_VOLUME") % vol_m3
	if armor_eff_label: armor_eff_label.text = tr("STATS_FRONT_ARMOR") % [hull_builder.front_armor_mm if hull_builder else 0.0, eff_front_armor]

# Navigation Handlers
func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_test_range_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/combat/test_range.tscn")

# Preset Application Handlers
func _on_preset_mbt_selected() -> void:
	_set_slider_values(6.8, 3.5, 1.4, 62.0, 550.0, 3.2, 2.8, 6.2)

func _on_preset_ifv_selected() -> void:
	_set_slider_values(5.5, 2.8, 1.2, 45.0, 150.0, 2.2, 1.8, 3.5)

func _set_slider_values(l: float, w: float, h: float, g: float, a: float, tl: float, tw: float, bl: float) -> void:
	if length_slider: length_slider.value = l
	if width_slider: width_slider.value = w
	if height_slider: height_slider.value = h
	if glacis_slider: glacis_slider.value = g
	if armor_slider: armor_slider.value = a
	if turret_l_slider: turret_l_slider.value = tl
	if turret_w_slider: turret_w_slider.value = tw
	if barrel_slider: barrel_slider.value = bl
	_on_dimension_changed(0.0)
	_on_turret_changed(0.0)
