class_name FireControlSystem
extends Node3D

## Fire Control System (FCS) managing Optics, Laser Rangefinder, and Ballistics.

enum OpticsMode { DAY, FLIR_WHITE_HOT, FLIR_BLACK_HOT, NVG }

@export var camera_node: Camera3D
@export var lrf_raycast: RayCast3D
@export var thermal_viewport_rect: ColorRect

var current_optics_mode: OpticsMode = OpticsMode.DAY
var target_distance_m: float = 0.0
var measured_range_m: float = 0.0
var ballistic_drop_compensation_mrad: float = 0.0

signal rangefinder_updated(distance_m: float)
signal optics_mode_changed(mode_name: String)

func _ready() -> void:
	set_optics_mode(OpticsMode.DAY)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next") or (event is InputEventKey and event.pressed and event.keycode == KEY_N):
		_cycle_optics_mode()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		trigger_laser_rangefinder()

func _cycle_optics_mode() -> void:
	var next_mode = (current_optics_mode + 1) % 4
	set_optics_mode(next_mode as OpticsMode)

func set_optics_mode(mode: OpticsMode) -> void:
	current_optics_mode = mode
	var mode_name = "DAY"
	
	if thermal_viewport_rect:
		var mat = thermal_viewport_rect.material as ShaderMaterial
		match mode:
			OpticsMode.DAY:
				thermal_viewport_rect.visible = false
				mode_name = "DAY OPTICS"
			OpticsMode.FLIR_WHITE_HOT:
				thermal_viewport_rect.visible = true
				if mat:
					mat.set_shader_parameter("thermal_intensity", 1.2)
					mat.set_shader_parameter("white_hot", true)
				mode_name = "FLIR (WHITE HOT)"
			OpticsMode.FLIR_BLACK_HOT:
				thermal_viewport_rect.visible = true
				if mat:
					mat.set_shader_parameter("thermal_intensity", 1.2)
					mat.set_shader_parameter("white_hot", false)
				mode_name = "FLIR (BLACK HOT)"
			OpticsMode.NVG:
				thermal_viewport_rect.visible = true
				if mat:
					mat.set_shader_parameter("thermal_intensity", 2.0)
				mode_name = "NVG (NIGHT VISION)"
				
	optics_mode_changed.emit(mode_name)

## Fires Laser Rangefinder to calculate target distance and ballistic arc drop
func trigger_laser_rangefinder() -> float:
	if lrf_raycast and lrf_raycast.is_colliding():
		var hit_point = lrf_raycast.get_collision_point()
		measured_range_m = lrf_raycast.global_position.distance_to(hit_point)
	else:
		measured_range_m = 9999.0 # Out of range / sky
		
	target_distance_m = measured_range_m
	_calculate_ballistic_drop(1750.0) # 1750 m/s APFSDS muzzle velocity
	rangefinder_updated.emit(measured_range_m)
	return measured_range_m

func _calculate_ballistic_drop(muzzle_velocity_ms: float) -> void:
	if measured_range_m <= 0.0 or measured_range_m >= 9000.0:
		ballistic_drop_compensation_mrad = 0.0
		return
		
	var time_of_flight_s = measured_range_m / muzzle_velocity_ms
	var drop_meters = 0.5 * 9.81 * time_of_flight_s * time_of_flight_s
	# Convert vertical drop to milliradian offset: mrad = (drop / range) * 1000
	ballistic_drop_compensation_mrad = (drop_meters / measured_range_m) * 1000.0
