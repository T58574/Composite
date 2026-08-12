class_name TestRangeHUD
extends Control

## Tactical HUD for Test Range with speedometer, compass, ammo counter, and impact log.

@export var vehicle: RigidBody3D
@export var shooting_system: ShootingSystem
@export var fcs: FireControlSystem

# HUD elements
var speed_label: Label
var heading_label: Label
var ammo_label: Label
var reload_bar: ProgressBar
var range_label: Label
var optics_label: Label
var impact_log: Label
var crosshair: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	_connect_signals()

func _build_hud() -> void:
	## Bottom-left: Speed + Heading
	var bottom_left := VBoxContainer.new()
	bottom_left.name = "BottomLeftHUD"
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.offset_left = 20
	bottom_left.offset_bottom = -20
	bottom_left.offset_top = -100
	bottom_left.offset_right = 280
	bottom_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_left)
	
	speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.text = "0 km/h"
	speed_label.add_theme_font_size_override("font_size", 28)
	bottom_left.add_child(speed_label)
	
	heading_label = Label.new()
	heading_label.name = "HeadingLabel"
	heading_label.text = "HDG: 000°"
	heading_label.add_theme_font_size_override("font_size", 18)
	bottom_left.add_child(heading_label)
	
	## Bottom-right: Ammo + Reload + Range
	var bottom_right := VBoxContainer.new()
	bottom_right.name = "BottomRightHUD"
	bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_right.offset_right = -20
	bottom_right.offset_bottom = -20
	bottom_right.offset_top = -140
	bottom_right.offset_left = -280
	bottom_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_right)
	
	ammo_label = Label.new()
	ammo_label.name = "AmmoLabel"
	ammo_label.text = "APFSDS: 40"
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 24)
	bottom_right.add_child(ammo_label)
	
	reload_bar = ProgressBar.new()
	reload_bar.name = "ReloadBar"
	reload_bar.value = 100
	reload_bar.custom_minimum_size = Vector2(250, 16)
	reload_bar.show_percentage = false
	reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_right.add_child(reload_bar)
	
	range_label = Label.new()
	range_label.name = "RangeLabel"
	range_label.text = "RNG: ----m"
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	range_label.add_theme_font_size_override("font_size", 18)
	bottom_right.add_child(range_label)
	
	optics_label = Label.new()
	optics_label.name = "OpticsLabel"
	optics_label.text = "DAY OPTICS"
	optics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	optics_label.add_theme_font_size_override("font_size", 16)
	bottom_right.add_child(optics_label)
	
	## Top-center: Impact log
	impact_log = Label.new()
	impact_log.name = "ImpactLog"
	impact_log.set_anchors_preset(Control.PRESET_CENTER_TOP)
	impact_log.offset_top = 40
	impact_log.offset_left = -200
	impact_log.offset_right = 200
	impact_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact_log.add_theme_font_size_override("font_size", 20)
	impact_log.add_theme_color_override("font_color", Color.YELLOW)
	add_child(impact_log)
	
	## Center: Simple crosshair
	var crosshair_label := Label.new()
	crosshair_label.name = "Crosshair"
	crosshair_label.text = "+"
	crosshair_label.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_label.offset_left = -10
	crosshair_label.offset_right = 10
	crosshair_label.offset_top = -10
	crosshair_label.offset_bottom = 10
	crosshair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair_label.add_theme_font_size_override("font_size", 24)
	crosshair_label.add_theme_color_override("font_color", Color(0.1, 1.0, 0.1))
	add_child(crosshair_label)
	
	## Top-left: Nav buttons
	var nav_box := HBoxContainer.new()
	nav_box.name = "NavBox"
	nav_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nav_box.offset_left = 20
	nav_box.offset_top = 20
	nav_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nav_box)
	
	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.pressed.connect(_on_main_menu_pressed)
	menu_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	nav_box.add_child(menu_btn)
	
	var editor_btn := Button.new()
	editor_btn.text = "Editor"
	editor_btn.pressed.connect(_on_editor_pressed)
	editor_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	nav_box.add_child(editor_btn)
	
	## Top-right: Controls help
	var help_label := Label.new()
	help_label.name = "ControlsHelp"
	help_label.text = "W/S Drive | A/D Pivot | Mouse Aim | LMB Fire | RMB Free Look | R Reset | V Scope"
	help_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help_label.offset_right = -20
	help_label.offset_top = 20
	help_label.offset_left = -650
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_label.add_theme_font_size_override("font_size", 14)
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(help_label)

func _connect_signals() -> void:
	if shooting_system:
		if not shooting_system.shot_fired.is_connected(_on_shot_fired):
			shooting_system.shot_fired.connect(_on_shot_fired)
		if not shooting_system.impact_result.is_connected(_on_impact_result):
			shooting_system.impact_result.connect(_on_impact_result)
		if not shooting_system.reload_progress.is_connected(_on_reload_progress):
			shooting_system.reload_progress.connect(_on_reload_progress)
	if fcs:
		if not fcs.rangefinder_updated.is_connected(_on_rangefinder_updated):
			fcs.rangefinder_updated.connect(_on_rangefinder_updated)
		if not fcs.optics_mode_changed.is_connected(_on_optics_mode_changed):
			fcs.optics_mode_changed.connect(_on_optics_mode_changed)

func _process(_delta: float) -> void:
	if vehicle:
		var speed_kmh := vehicle.linear_velocity.length() * 3.6
		speed_label.text = "%.0f km/h" % speed_kmh
		
		var forward := vehicle.global_transform.basis.x
		var heading := rad_to_deg(atan2(-forward.z, forward.x))
		if heading < 0:
			heading += 360.0
		heading_label.text = "HDG: %03.0f°" % heading

func _on_shot_fired(ammo_remaining: int) -> void:
	ammo_label.text = "APFSDS: %d" % ammo_remaining
	reload_bar.value = 0

func _on_impact_result(result: ArmorCalculator.ImpactResult) -> void:
	if result.penetrated:
		impact_log.add_theme_color_override("font_color", Color.RED)
	else:
		impact_log.add_theme_color_override("font_color", Color.GREEN)
	impact_log.text = result.description
	# Auto-clear after 4 seconds
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_callback(func(): impact_log.text = "")

func _on_reload_progress(progress: float) -> void:
	reload_bar.value = progress * 100.0

func _on_rangefinder_updated(distance_m: float) -> void:
	if distance_m >= 9000.0:
		range_label.text = "RNG: ----m"
	else:
		range_label.text = "RNG: %.0fm" % distance_m

func _on_optics_mode_changed(mode_name: String) -> void:
	optics_label.text = mode_name

func _on_main_menu_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_editor_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/tank_editor/tank_editor.tscn")
