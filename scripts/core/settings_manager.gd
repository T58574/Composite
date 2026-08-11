extends Node

## Global Settings Manager for Composite.
## Handles loading, applying, and saving game graphics & audio settings using ConfigFile.

const SETTINGS_PATH: String = "user://settings.cfg"

signal settings_changed()

# Default Settings State
var window_mode: int = 0 # 0 = Windowed, 1 = Exclusive Fullscreen, 2 = Borderless Fullscreen
var resolution_index: int = 0 # 0 = 1280x720, 1 = 1600x900, 2 = 1920x1080, 3 = 2560x1440
var msaa_index: int = 2 # 0 = Disabled, 1 = FXAA, 2 = MSAA 2x, 3 = MSAA 4x
var master_volume: float = 80.0

func _ready() -> void:
	load_settings()

## Loads settings from user://settings.cfg or applies defaults if file doesn't exist
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err == OK:
		window_mode = config.get_value("graphics", "window_mode", 0)
		resolution_index = config.get_value("graphics", "resolution_index", 0)
		msaa_index = config.get_value("graphics", "msaa_index", 2)
		master_volume = config.get_value("audio", "master_volume", 80.0)
	
	apply_all_settings()

## Saves current settings to disk
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "window_mode", window_mode)
	config.set_value("graphics", "resolution_index", resolution_index)
	config.set_value("graphics", "msaa_index", msaa_index)
	config.set_value("audio", "master_volume", master_volume)
	
	var err = config.save(SETTINGS_PATH)
	if err == OK:
		print("[SettingsManager] Settings saved successfully to user://settings.cfg")

## Applies graphics & audio settings to engine
func apply_all_settings() -> void:
	set_window_mode(window_mode)
	set_resolution(resolution_index)
	set_msaa(msaa_index)
	set_master_volume(master_volume)
	settings_changed.emit()

func set_window_mode(index: int) -> void:
	window_mode = index
	match index:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_resolution(index: int) -> void:
	resolution_index = index
	var res = Vector2i(1280, 720)
	match index:
		0: res = Vector2i(1280, 720)
		1: res = Vector2i(1600, 900)
		2: res = Vector2i(1920, 1080)
		3: res = Vector2i(2560, 1440)
	get_window().size = res

func set_msaa(index: int) -> void:
	msaa_index = index
	var viewport = get_viewport()
	if viewport == null:
		return
		
	match index:
		0:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		1:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		3:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

func set_master_volume(vol: float) -> void:
	master_volume = vol
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		if vol <= 0.0:
			AudioServer.set_bus_mute(bus_index, true)
		else:
			AudioServer.set_bus_mute(bus_index, false)
			# Convert 0..100 to dB (-40dB to +6dB)
			var db = linear_to_db(vol / 100.0)
			AudioServer.set_bus_volume_db(bus_index, db)
