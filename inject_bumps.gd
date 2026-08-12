@tool
extends SceneTree

func _init() -> void:
	var path = "res://scenes/tank_editor/tank_editor.tscn"
	var packed = ResourceLoader.load(path) as PackedScene
	var scene = packed.instantiate()
	var node3d = scene.get_node("Node3D")
	
	if node3d:
		# Define bump positions
		var offsets = [
			Vector3(5, -0.2, 5),
			Vector3(5, -0.2, -5),
			Vector3(-5, -0.2, 5),
			Vector3(-5, -0.2, -5),
			Vector3(0, -0.3, 10),
			Vector3(0, -0.3, -10),
			Vector3(10, -0.4, 0),
			Vector3(-10, -0.4, 0)
		]
		
		# Create bumps
		for i in range(offsets.size()):
			var cylinder = CSGCylinder3D.new()
			cylinder.name = "TestBump_%d" % i
			cylinder.use_collision = true
			cylinder.radius = 1.5 + (i % 3) * 0.5
			cylinder.height = 1.0 + (i % 2) * 0.5
			cylinder.position = offsets[i]
			cylinder.sides = 16
			node3d.add_child(cylinder)
			cylinder.owner = scene
			
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.4, 0.4, 0.4)
			cylinder.material_override = mat

		var new_packed = PackedScene.new()
		new_packed.pack(scene)
		ResourceSaver.save(new_packed, path)
		print("Bumps successfully injected into tank_editor.tscn")
	else:
		print("Failed to find Node3D in tank_editor.tscn")
		
	quit(0)
