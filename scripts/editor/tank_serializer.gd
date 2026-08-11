class_name TankSerializer
extends RefCounted

## Serializes and deserializes full Sprocket tank configurations to JSON files.

static func save_preset(file_path: String, tank_name: String, era: String, hull: HullBuilder, turret: TurretBuilder, tracks: TrackGenerator, firepower: FirepowerBuilder, vertex_offsets: Dictionary = {}) -> bool:
	var data = {
		"version": "0.2.53.2",
		"name": tank_name,
		"era": era,
		"hull": {
			"length": hull.length if hull else 6.8,
			"width": hull.width if hull else 3.4,
			"height": hull.height if hull else 1.4,
			"front_glacis_angle_deg": hull.front_glacis_angle_deg if hull else 60.0,
			"front_armor_mm": hull.front_armor_mm if hull else 450.0,
			"side_armor_mm": hull.side_armor_mm if hull else 80.0,
			"rear_armor_mm": hull.rear_armor_mm if hull else 50.0
		},
		"turret": {
			"length": turret.turret_length if turret else 3.2,
			"width": turret.turret_width if turret else 2.6,
			"height": turret.turret_height if turret else 1.1,
			"barrel_length": turret.barrel_length if turret else 6.2
		},
		"chassis": {
			"road_wheel_pairs": tracks.road_wheel_pairs if tracks else 6,
			"wheel_diameter": tracks.wheel_diameter if tracks else 0.65,
			"track_width": tracks.track_width if tracks else 0.6
		},
		"firepower": {
			"caliber_mm": firepower.caliber_mm if firepower else 120.0,
			"barrel_length_m": firepower.barrel_length_m if firepower else 6.2
		}
	}

	if not vertex_offsets.is_empty():
		var serialized_offsets = {}
		for builder_name in vertex_offsets:
			var builder_offsets = vertex_offsets[builder_name]
			var serialized_builder_offsets = {}
			for vertex_index in builder_offsets:
				var offset = builder_offsets[vertex_index]
				serialized_builder_offsets[str(vertex_index)] = [offset.x, offset.y, offset.z]
			serialized_offsets[builder_name] = serialized_builder_offsets
		data["vertex_offsets"] = serialized_offsets

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		return true
	return false

static func load_preset(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result == OK and json.data is Dictionary:
		return json.data
	return {}

## Extracts vertex offsets from loaded preset data, converting [x,y,z] arrays back to Vector3
static func extract_vertex_offsets(data: Dictionary) -> Dictionary:
	if not data.has("vertex_offsets"):
		return {}
	var offsets := {}
	var raw: Dictionary = data["vertex_offsets"]
	for builder_name in raw:
		var builder_offsets := {}
		var raw_builder: Dictionary = raw[builder_name]
		for idx_str in raw_builder:
			var arr = raw_builder[idx_str]
			if arr is Array and arr.size() == 3:
				builder_offsets[int(idx_str)] = Vector3(arr[0], arr[1], arr[2])
		if not builder_offsets.is_empty():
			offsets[builder_name] = builder_offsets
	return offsets
