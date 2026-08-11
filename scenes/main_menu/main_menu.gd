extends Control

## Main Menu Controller for Composite - Modern Tank Simulator.

@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var main_menu_vbox: VBoxContainer = %MainMenuVBox

# Settings Controls
@onready var language_option: OptionButton = %LanguageOption
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var msaa_option: OptionButton = %MsaaOption
@onready var volume_slider: HSlider = %VolumeSlider

func _ready() -> void:
	if settings_panel:
		settings_panel.visible = false
		
	if not SettingsManager.settings_changed.is_connected(_setup_settings_options):
		SettingsManager.settings_changed.connect(_setup_settings_options)
		
	_setup_settings_options()

func _setup_settings_options() -> void:
	if language_option:
		language_option.clear()
		language_option.add_item("Русский", 0)
		language_option.add_item("English", 1)
		language_option.select(0 if SettingsManager.language == "ru" else 1)

	if window_mode_option:
		window_mode_option.clear()
		window_mode_option.add_item(tr("WIN_MODE_WINDOWED"), 0)
		window_mode_option.add_item(tr("WIN_MODE_FULLSCREEN"), 1)
		window_mode_option.add_item(tr("WIN_MODE_BORDERLESS"), 2)
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
		msaa_option.add_item(tr("MSAA_DISABLED"), 0)
		msaa_option.add_item(tr("MSAA_FXAA"), 1)
		msaa_option.add_item(tr("MSAA_2X"), 2)
		msaa_option.add_item(tr("MSAA_4X"), 3)
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
func _on_language_selected(index: int) -> void:
	var lang = "ru" if index == 0 else "en"
	SettingsManager.set_language(lang)

func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(index)

func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution(index)

func _on_msaa_selected(index: int) -> void:
	SettingsManager.set_msaa(index)

func _on_volume_changed(val: float) -> void:
	SettingsManager.set_master_volume(val)

