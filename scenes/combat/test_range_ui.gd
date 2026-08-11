extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_sandbox_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tank_editor/tank_editor.tscn")
