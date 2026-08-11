extends Control

## Main Menu Controller for Composite - Modern Tank Simulator.

@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var main_menu_vbox: VBoxContainer = %MainMenuVBox

# Settings Controls
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var msaa_option: OptionButton = %MsaaOption
@onready var volume_slider: HSlider = %VolumeSlider

func _ready() -> void:
	if settings_panel:
		settings_panel.visible = false
		
	_setup_settings_options()

func _setup_settings_options() -> void:
	if window_mode_option:
		window_mode_option.clear()
		window_mode_option.add_item("Windowed", 0)
		window_mode_option.add_item("Exclusive Fullscreen", 1)
		window_mode_option.add_item("Borderless Windowed", 2)
		window_mode_option.select(SettingsManager.window_mode)
		
	if resolution_option:
		resolution_option.clear()
		resolution_option.add_item("1280 x 720 (HD)", 0)
		resolution_option.add_item("1600 x 900", 1)
		resolution_option.add_item("1920 x 1080 (FHD)", 2)
		resolution_option.add_item("2560 x 1440 (2K)", 3)
		resolution_option.select(SettingsManager.resolution_index)
		
	if msaa_option:
		msaa_option.clear()
		msaa_option.add_item("Disabled", 0)
		msaa_option.add_item("FXAA Fast", 1)
		msaa_option.add_item("MSAA 2x (Recommended)", 2)
		msaa_option.add_item("MSAA 4x High Quality", 3)
		msaa_option.select(SettingsManager.msaa_index)
		
	if volume_slider:
		volume_slider.value = SettingsManager.master_volume
		if not volume_slider.value_changed.is_connected(_on_volume_changed):
			volume_slider.value_changed.connect(_on_volume_changed)

# Navigation Handlers
func _on_sandbox_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tank_editor/tank_editor.tscn")

func _on_test_range_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/combat/test_range.tscn")

func _on_settings_pressed() -> void:
	if settings_panel:
		_setup_settings_options()
		settings_panel.visible = true

func _on_close_settings_pressed() -> void:
	if settings_panel:
		SettingsManager.save_settings()
		settings_panel.visible = false

func _on_exit_game_pressed() -> void:
	get_tree().quit()

# Settings Change Handlers
func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(index)

func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution(index)

func _on_msaa_selected(index: int) -> void:
	SettingsManager.set_msaa(index)

func _on_volume_changed(val: float) -> void:
	SettingsManager.set_master_volume(val)
