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
var language: String = "ru" # "ru" or "en"

func _ready() -> void:
	_setup_translations()
	load_settings()

func _setup_translations() -> void:
	var trans_ru = Translation.new()
	trans_ru.locale = "ru"
	var trans_en = Translation.new()
	trans_en.locale = "en"

	var dictionary = {
		# Main Menu
		"MENU_TITLE_SUBTITLE": ["MODERN ARMORED VEHICLE SIMULATOR", "СОВРЕМЕННЫЙ СИМУЛЯТОР БРОНЕТЕХНИКИ"],
		"MENU_SANDBOX_BTN": ["🛠️ 1. TANK BUILDER SANDBOX", "🛠️ 1. ПЕСОЧНИЦА КОНСТРУКТОР"],
		"MENU_SANDBOX_DESC": ["   Flat world for procedural hull and turret design", "   Flat-мир для процедурного проектирования корпуса и башни"],
		"MENU_TEST_RANGE_BTN": ["🎯 2. COMBAT TEST RANGE", "🎯 2. ПОЛИГОН ИСПЫТАНИЙ"],
		"MENU_TEST_RANGE_DESC": ["   Test range with bumps, targets, and Jolt Raycast suspension physics", "   Полигон с кочками, мишенями и физикой Raycast-подвески Jolt"],
		"MENU_SETTINGS_BTN": ["⚙️ 3. GAME SETTINGS", "⚙️ 3. НАСТРОЙКИ ИГРЫ"],
		"MENU_EXIT_BTN": ["❌ 4. EXIT GAME", "❌ 4. ВЫХОД ИЗ ИГРЫ"],
		"SETTINGS_TITLE": ["⚙️ GAME SETTINGS", "⚙️ НАСТРОЙКИ ИГРЫ"],
		"SETTINGS_WINDOW_MODE": ["Window Mode:", "Режим экрана:"],
		"SETTINGS_RESOLUTION": ["Screen Resolution:", "Разрешение экрана:"],
		"SETTINGS_MSAA": ["Anti-Aliasing (MSAA):", "Сглаживание (Anti-Aliasing / MSAA):"],
		"SETTINGS_VOLUME": ["Master Volume:", "Общая громкость:"],
		"SETTINGS_LANGUAGE": ["Language:", "Язык (Language):"],
		"SETTINGS_CLOSE": ["APPLY & CLOSE", "ПРИМЕНИТЬ И ЗАКРЫТЬ"],

		# Window modes
		"WIN_MODE_WINDOWED": ["Windowed", "Оконный"],
		"WIN_MODE_FULLSCREEN": ["Exclusive Fullscreen", "Полноэкранный (Эксклюзивный)"],
		"WIN_MODE_BORDERLESS": ["Borderless Windowed", "Полноэкранный в окне"],

		# MSAA modes
		"MSAA_DISABLED": ["Disabled", "Отключено"],
		"MSAA_FXAA": ["FXAA Fast", "FXAA (Быстрое)"],
		"MSAA_2X": ["MSAA 2x (Recommended)", "MSAA 2x (Рекомендуется)"],
		"MSAA_4X": ["MSAA 4x High Quality", "MSAA 4x (Высокое качество)"],

		# Tank Editor Header
		"EDITOR_MENU": ["Menu", "Меню"],
		"EDITOR_ERA": ["Era:", "Эра:"],
		"EDITOR_SAVE": ["Save", "Сохранить"],
		"EDITOR_LOAD": ["Load", "Загрузить"],
		"EDITOR_RESET": ["Reset", "Сброс"],
		"EDITOR_MASS": ["Mass:", "Масса:"],
		"EDITOR_VOLUME": ["Volume:", "Объем:"],
		"EDITOR_SOLID": ["Solid [F1]", "Сплошной [F1]"],
		"EDITOR_HEATMAP": ["Armor Heatmap [F2]", "Теплокарта брони [F2]"],
		"EDITOR_XRAY": ["X-Ray [F3]", "Рентген [F3]"],
		"EDITOR_SYMMETRY": ["Symmetry X", "Симметрия X"],
		"EDITOR_TEST_RANGE": ["Test Range", "Полигон"],

		# Eras
		"ERA_EARLY": ["Earlywar (1939-1941)", "Начало войны (1939-1941)"],
		"ERA_MID": ["Midwar (1942-1944)", "Середина войны (1942-1944)"],
		"ERA_LATE": ["Latewar (1945-1955)", "Конец войны (1945-1955)"],
		"ERA_MODERN": ["Modern MBT (1970-2026)", "Современный ОБТ (1970-2026)"],

		# Left Sidebar Categories
		"CAT_COMPARTMENTS": ["Compartments", "Корпус"],
		"CAT_TRACKS": ["Tracks", "Гусеницы"],
		"CAT_POWERTRAIN": ["Powertrain", "Двигатель"],
		"CAT_FIREPOWER": ["Firepower", "Вооружение"],
		"CAT_CREW": ["Crew", "Экипаж"],
		"CAT_PAINT": ["Paint", "Окраска"],
		"CAT_DECALS": ["Decals", "Декали"],

		# Category panels
		"TITLE_COMPARTMENTS": ["Compartment Specs", "Параметры корпуса"],
		"LBL_HULL_LENGTH": ["Hull Length (m)", "Длина корпуса (м)"],
		"LBL_HULL_WIDTH": ["Hull Width (m)", "Ширина корпуса (м)"],
		"LBL_HULL_HEIGHT": ["Hull Height (m)", "Высота корпуса (м)"],
		"LBL_GLACIS_ANGLE": ["Glacis Angle (°)", "Угол ВЛД (°)"],

		"LBL_WHEEL_PAIRS": ["Road Wheel Pairs", "Пар опорных катков"],
		"LBL_WHEEL_DIAM": ["Wheel Diameter (m)", "Диаметр катков (м)"],
		"LBL_TRACK_WIDTH": ["Track Width (m)", "Ширина гусениц (м)"],

		"TITLE_POWERTRAIN": ["Powertrain Specs", "Силовая установка"],
		"LBL_ENGINE_HP": ["Engine Output (HP)", "Мощность двигателя (л.с.)"],

		"LBL_GUN_CALIBER": ["Gun Caliber (mm)", "Калибр орудия (мм)"],
		"LBL_BARREL_LENGTH": ["Barrel Length (m)", "Длина ствола (м)"],

		"TITLE_CREW": ["Crew Ergonomics", "Эргономика экипажа"],
		"LBL_CREW_COUNT": ["Crew Members", "Количество членов экипажа"],

		"TITLE_PAINT": ["Paint & Camouflage", "Окраска и камуфляж"],
		"LBL_CAMO_PATTERN": ["Camouflage Pattern", "Тип камуфляжа"],

		"PAINT_SOLID": ["Solid (Olive Drab)", "Однотонный (Защитный)"],
		"PAINT_NATO": ["NATO 3-Color Camo", "НАТО 3-цветный"],
		"PAINT_DESERT": ["Desert Sand", "Пустынный песок"],
		"PAINT_WINTER": ["Winter Solid", "Зимний белый"],
		"PAINT_GREY": ["Panzer Grey", "Танковый серый"],

		"TITLE_DECALS": ["Insignia & Marking", "Опознавательные знаки"],
		"LBL_INSIGNIA_SYMBOL": ["Insignia Symbol", "Символ"],

		"DECAL_STAR": ["National Star", "Звезда"],
		"DECAL_NUMBER": ["Unit Number", "Номер подразделения"],
		"DECAL_CROSS": ["Tactical Cross", "Тактический крест"],

		# Inspector
		"INSPECTOR_TITLE": ["Structure", "Конструкция"],
		"BTN_POINTS": ["Points [1]", "Точки [1]"],
		"BTN_EDGES": ["Edges [2]", "Ребра [2]"],
		"BTN_FACES": ["Faces [3]", "Грани [3]"],
		"BTN_CORNERS": ["Corners [4]", "Углы [4]"],
		"EDIT_ACTIONS": ["Edit Actions", "Действия редактирования"],
		"BTN_DELETE": ["Delete [Del]", "Удалить [Del]"],
		"BTN_EXTRUDE": ["Extrude [E]", "Выдавить [E]"],
		"BTN_SPLIT": ["Split Face", "Разделить грань"],
		"BTN_FLIP": ["Flip Normals", "Инверсия нормалей"],
		"CHK_MIRROR": ["Mirror X", "Отразить X"],
		"LBL_SMOOTH_ANGLE": ["Smooth Angle", "Угол сглаживания"],
		"LBL_GRID_SIZE": ["Grid Size (mm)", "Размер сетки (мм)"],
		"TITLE_ARMOR_THICKNESS": ["Armor Thickness", "Толщина брони"],
		"LBL_MATERIAL_TYPE": ["Material Type", "Тип материала"],

		"ARMOR_STEEL": ["RHA Steel", "Сталь RHA"],
		"ARMOR_COMPOSITE": ["NERA Composite", "Композит NERA"],
		"ARMOR_CERAMIC": ["Ceramic Insert", "Керамика"],

		"PART_FRONT_GLACIS": ["Front Glacis Plate", "Передний лист ВЛД"],
		"PART_TURRET_CHEEK": ["Turret Cheek Armor", "Лобовая броня башни"],
		"PART_HULL_PLATE": ["Hull Plate", "Бронелист корпуса"],
		"PART_NO_SELECTION": ["No Selection", "Ничего не выбрано"],

		# Bottom toolbar & Hover
		"TAB_TURRETS": ["Turrets", "Башни"],
		"TAB_STRUCTURAL": ["Structural", "Конструкция"],
		"TAB_ADDON": ["Addon Structures", "Навесные элементы"],
		"BTN_MOVE": ["Move [G]", "Сдвиг [G]"],
		"BTN_ROTATE": ["Rotate [R]", "Поворот [R]"],
		"BTN_RESIZE": ["Resize [S]", "Масштаб [S]"],
		"BTN_SNAP": ["Snap", "Привязка"],
		"HOVER_INSPECT_PROMPT": ["Hover over armor to inspect...", "Наведите на броню для инспекции..."],
		"HOVER_INSPECT_FMT": ["Thickness: %.0fmm | Angle: %.1f° | Effective: %.0fmm RHA", "Толщина: %.0fмм | Угол: %.1f° | Приведенная: %.0fмм RHA"],
		"ARMOR_LOS_FMT": ["Angle: %.1f° | LOS: %.0fmm RHA", "Угол: %.1f° | Приведенная: %.0fмм RHA"],

		# Tank builder stats
		"STATS_TOTAL_MASS": ["Total Mass: %.1f Tons (Hull: %.1ft, Turret: %.1ft)", "Общая масса: %.1f т (Корпус: %.1fт, Башня: %.1fт)"],
		"STATS_HULL_VOLUME": ["Hull Volume: %.2f m³", "Объем корпуса: %.2f м³"],
		"STATS_FRONT_ARMOR": ["Hull Front: %.0fmm RHA (LOS Eff: %.0fmm)", "Лоб корпуса: %.0fмм RHA (Приведенная: %.0fмм)"],

		# Preset Cards
		"PRESET_HULL_WEDGE_TITLE": ["Standard MBT", "Стандарт ОБТ"],
		"PRESET_HULL_WEDGE_SUB": ["60° Glacis (Standard)", "ВЛД 60° (Стандарт)"],
		"PRESET_HULL_BOX_TITLE": ["Challenger 2", "Challenger 2"],
		"PRESET_HULL_BOX_SUB": ["Heavy Chobham Box", "Тяжёлый Чобхэм"],
		"PRESET_HULL_PIKE_TITLE": ["T-90M Proryv", "Т-90М Прорыв"],
		"PRESET_HULL_PIKE_SUB": ["Relikt ERA & Glacis", "ДЗ Реликт & ВЛД"],
		"PRESET_HULL_MODERN_TITLE": ["M1A2 / Leopard 2A7", "M1A2 / Leopard 2A7"],
		"PRESET_HULL_MODERN_SUB": ["Composite Wedge", "Композитный Клин"],
		"PRESET_HULL_COMPACT_TITLE": ["Light Tank", "Лёгкий Танк"],
		"PRESET_HULL_COMPACT_SUB": ["Compact Chassis", "Малогабаритный"],

		"PRESET_TURRET_WEDGE_TITLE": ["Standard Wedge", "Стандарт Клин"],
		"PRESET_TURRET_WEDGE_SUB": ["Sloped Cheeks", "Наклонные щёки"],
		"PRESET_TURRET_DOME_TITLE": ["T-54 / T-62 Dome", "Башня Т-54 / Т-62"],
		"PRESET_TURRET_DOME_SUB": ["Cast Hemisphere", "Литой купол"],
		"PRESET_TURRET_BOX_TITLE": ["M1A2 Abrams", "M1A2 Abrams"],
		"PRESET_TURRET_BOX_SUB": ["Welded Bustle & Blowout", "Ниша БК & Вышибные"],
		"PRESET_TURRET_ANGULAR_TITLE": ["Leopard 2A7", "Leopard 2A7"],
		"PRESET_TURRET_ANGULAR_SUB": ["Wedge Armor Cheeks", "Клиновидные щёки"],
		"PRESET_TURRET_COMPACT_TITLE": ["Light Turret", "Малая Башня"],
		"PRESET_TURRET_COMPACT_SUB": ["Compact Turret", "Компактная башня"],

		# Combat Test Range
		"RANGE_MAIN_MENU": ["← Main Menu", "← Главное меню"],
		"RANGE_TO_BUILDER": ["🛠️ To Builder", "🛠️ В конструктор"],
		"RANGE_TITLE": ["COMBAT TEST RANGE", "БОЕВОЙ ПОЛИГОН"],
		"RANGE_CONTROLS": ["WASD / Arrows: Vehicle movement\nN: FCS Optics (Day/Thermal/NVG)\nR: Laser Rangefinder", "WASD / Стрелки: Движение танка\nN: Оптика СУО (День/Тепловизор/ПНВ)\nR: Лазерный дальномер"]
	}

	for key in dictionary:
		var en_val = dictionary[key][0]
		var ru_val = dictionary[key][1]
		trans_en.add_message(key, en_val)
		trans_ru.add_message(key, ru_val)

	TranslationServer.add_translation(trans_en)
	TranslationServer.add_translation(trans_ru)

## Loads settings from user://settings.cfg or applies defaults if file doesn't exist
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err == OK:
		window_mode = config.get_value("graphics", "window_mode", 0)
		resolution_index = config.get_value("graphics", "resolution_index", 0)
		msaa_index = config.get_value("graphics", "msaa_index", 2)
		master_volume = config.get_value("audio", "master_volume", 80.0)
		language = config.get_value("general", "language", "ru")
	
	apply_all_settings()

## Saves current settings to disk
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "window_mode", window_mode)
	config.set_value("graphics", "resolution_index", resolution_index)
	config.set_value("graphics", "msaa_index", msaa_index)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("general", "language", language)
	
	var err = config.save(SETTINGS_PATH)
	if err == OK:
		print("[SettingsManager] Settings saved successfully to user://settings.cfg")

## Applies graphics & audio settings to engine
func apply_all_settings() -> void:
	set_window_mode(window_mode)
	set_resolution(resolution_index)
	set_msaa(msaa_index)
	set_master_volume(master_volume)
	set_language(language)

func set_language(lang_code: String) -> void:
	if lang_code != "ru" and lang_code != "en":
		lang_code = "ru"
	language = lang_code
	TranslationServer.set_locale(language)
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

