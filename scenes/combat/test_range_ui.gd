extends Control

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_sandbox_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tank_builder/tank_builder.tscn")
