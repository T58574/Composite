class_name MeshTopologyOps
extends RefCounted

## Utility library for Sprocket-style mesh topology operations:
## Extrude Face, Face Deletion, and Normal Smoothing calculations.

## Extrudes target face along its normal vector by distance on an ArrayMesh
static func extrude_face(array_mesh: ArrayMesh, face_index: int, distance: float = 0.4) -> ArrayMesh:
	if array_mesh == null or array_mesh.get_surface_count() == 0:
		return array_mesh

	var arrays = array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	if indices.size() == 0:
		indices = PackedInt32Array()
		indices.resize(vertices.size())
		for i in range(vertices.size()):
			indices[i] = i

	if normals.size() != vertices.size():
		normals = PackedVector3Array()
		normals.resize(vertices.size())

	if uvs.size() != vertices.size():
		uvs = PackedVector2Array()
		uvs.resize(vertices.size())

	var total_faces = indices.size() / 3
	if face_index < 0 or face_index >= total_faces:
		return array_mesh

	# Get target face vertex indices
	var i0: int = indices[face_index * 3 + 0]
	var i1: int = indices[face_index * 3 + 1]
	var i2: int = indices[face_index * 3 + 2]

	# Original vertex positions
	var p0: Vector3 = vertices[i0]
	var p1: Vector3 = vertices[i1]
	var p2: Vector3 = vertices[i2]

	# Face normal
	var face_normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
	if face_normal.length_squared() < 0.0001:
		face_normal = Vector3.UP

	var offset: Vector3 = face_normal * distance

	# Duplicate target face vertices for extruded top cap
	var new_i0: int = vertices.size()
	var new_i1: int = vertices.size() + 1
	var new_i2: int = vertices.size() + 2

	vertices.append(p0 + offset)
	vertices.append(p1 + offset)
	vertices.append(p2 + offset)

	normals.append(face_normal)
	normals.append(face_normal)
	normals.append(face_normal)

	uvs.append(uvs[i0] if i0 < uvs.size() else Vector2(0, 0))
	uvs.append(uvs[i1] if i1 < uvs.size() else Vector2(1, 0))
	uvs.append(uvs[i2] if i2 < uvs.size() else Vector2(0.5, 1))

	# Update original face indices to point to extruded top cap
	indices[face_index * 3 + 0] = new_i0
	indices[face_index * 3 + 1] = new_i1
	indices[face_index * 3 + 2] = new_i2

	# Add connecting quad faces (2 triangles per boundary edge)
	# Edge 0: (i0, i1) -> top (new_i0, new_i1)
	indices.append(i0)
	indices.append(i1)
	indices.append(new_i1)
	indices.append(i0)
	indices.append(new_i1)
	indices.append(new_i0)

	# Edge 1: (i1, i2) -> top (new_i1, new_i2)
	indices.append(i1)
	indices.append(i2)
	indices.append(new_i2)
	indices.append(i1)
	indices.append(new_i2)
	indices.append(new_i1)

	# Edge 2: (i2, i0) -> top (new_i2, new_i0)
	indices.append(i2)
	indices.append(i0)
	indices.append(new_i0)
	indices.append(i2)
	indices.append(new_i0)
	indices.append(new_i2)

	# Recalculate smooth normals across mesh
	normals = calculate_smooth_normals(vertices, indices, 60.0)

	# Update mesh surface
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return array_mesh


## Alias for extrude_face to match editor conventions
static func extrude_selected_face(array_mesh: ArrayMesh, face_index: int, distance: float = 0.4) -> ArrayMesh:
	return extrude_face(array_mesh, face_index, distance)


## Deletes a face from an ArrayMesh and removes orphaned vertices
static func delete_face(array_mesh: ArrayMesh, face_index: int) -> ArrayMesh:
	if array_mesh == null or array_mesh.get_surface_count() == 0:
		return array_mesh

	var arrays = array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	if indices.size() == 0:
		indices = PackedInt32Array()
		indices.resize(vertices.size())
		for i in range(vertices.size()):
			indices[i] = i

	var total_faces = indices.size() / 3
	if face_index < 0 or face_index >= total_faces:
		return array_mesh

	var remove_idx = face_index * 3
	indices.remove_at(remove_idx + 2)
	indices.remove_at(remove_idx + 1)
	indices.remove_at(remove_idx + 0)

	return _compact_mesh_arrays(array_mesh, arrays, vertices, normals, uvs, indices)


## Deletes faces connected to a vertex and removes orphaned vertices
static func delete_vertex(array_mesh: ArrayMesh, vert_index: int) -> ArrayMesh:
	if array_mesh == null or array_mesh.get_surface_count() == 0:
		return array_mesh

	var arrays = array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	if indices.size() == 0:
		indices = PackedInt32Array()
		indices.resize(vertices.size())
		for i in range(vertices.size()):
			indices[i] = i

	var total_faces = indices.size() / 3
	var faces_to_delete: Array[int] = []

	for f in range(total_faces):
		var i0 = indices[f * 3 + 0]
		var i1 = indices[f * 3 + 1]
		var i2 = indices[f * 3 + 2]
		if i0 == vert_index or i1 == vert_index or i2 == vert_index:
			faces_to_delete.append(f)

	faces_to_delete.sort()
	faces_to_delete.reverse()

	for f in faces_to_delete:
		indices.remove_at(f * 3 + 2)
		indices.remove_at(f * 3 + 1)
		indices.remove_at(f * 3 + 0)

	return _compact_mesh_arrays(array_mesh, arrays, vertices, normals, uvs, indices)


## Deletes faces sharing an edge and removes orphaned vertices
static func delete_edge(array_mesh: ArrayMesh, vert_idx_a: int, vert_idx_b: int) -> ArrayMesh:
	if array_mesh == null or array_mesh.get_surface_count() == 0:
		return array_mesh

	var arrays = array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	if indices.size() == 0:
		indices = PackedInt32Array()
		indices.resize(vertices.size())
		for i in range(vertices.size()):
			indices[i] = i

	var total_faces = indices.size() / 3
	var faces_to_delete: Array[int] = []

	for f in range(total_faces):
		var i0 = indices[f * 3 + 0]
		var i1 = indices[f * 3 + 1]
		var i2 = indices[f * 3 + 2]
		var has_a = (i0 == vert_idx_a or i1 == vert_idx_a or i2 == vert_idx_a)
		var has_b = (i0 == vert_idx_b or i1 == vert_idx_b or i2 == vert_idx_b)
		if has_a and has_b:
			faces_to_delete.append(f)

	faces_to_delete.sort()
	faces_to_delete.reverse()

	for f in faces_to_delete:
		indices.remove_at(f * 3 + 2)
		indices.remove_at(f * 3 + 1)
		indices.remove_at(f * 3 + 0)

	return _compact_mesh_arrays(array_mesh, arrays, vertices, normals, uvs, indices)


## Helper function to find the symmetric face index across X axis (X -> -X)
static func find_symmetric_face_index(array_mesh: ArrayMesh, face_index: int) -> int:
	if array_mesh == null or array_mesh.get_surface_count() == 0:
		return -1

	var arrays = array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	if indices.size() == 0:
		indices = PackedInt32Array()
		indices.resize(vertices.size())
		for i in range(vertices.size()):
			indices[i] = i

	var total_faces = indices.size() / 3
	if face_index < 0 or face_index >= total_faces:
		return -1

	var p0 = vertices[indices[face_index * 3 + 0]]
	var p1 = vertices[indices[face_index * 3 + 1]]
	var p2 = vertices[indices[face_index * 3 + 2]]
	var center = (p0 + p1 + p2) / 3.0
	var sym_center = Vector3(-center.x, center.y, center.z)

	for f in range(total_faces):
		if f == face_index:
			continue
		var fp0 = vertices[indices[f * 3 + 0]]
		var fp1 = vertices[indices[f * 3 + 1]]
		var fp2 = vertices[indices[f * 3 + 2]]
		var f_center = (fp0 + fp1 + fp2) / 3.0
		if f_center.distance_to(sym_center) < 0.05:
			return f

	return -1


## Compacts mesh arrays after face deletion to strip unused/orphaned vertices
static func _compact_mesh_arrays(
	array_mesh: ArrayMesh,
	arrays: Array,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	var is_used: Array[bool] = []
	is_used.resize(vertices.size())
	is_used.fill(false)

	for idx in indices:
		if idx >= 0 and idx < is_used.size():
			is_used[idx] = true

	var old_to_new = PackedInt32Array()
	old_to_new.resize(vertices.size())
	old_to_new.fill(-1)

	var new_vertices = PackedVector3Array()
	var new_normals = PackedVector3Array()
	var new_uvs = PackedVector2Array()

	var new_count = 0
	for i in range(vertices.size()):
		if is_used[i]:
			old_to_new[i] = new_count
			new_vertices.append(vertices[i])
			if i < normals.size():
				new_normals.append(normals[i])
			if i < uvs.size():
				new_uvs.append(uvs[i])
			new_count += 1

	var new_indices = PackedInt32Array()
	new_indices.resize(indices.size())
	for i in range(indices.size()):
		new_indices[i] = old_to_new[indices[i]]

	array_mesh.clear_surfaces()
	if new_vertices.size() > 0 and new_indices.size() > 0:
		new_normals = calculate_smooth_normals(new_vertices, new_indices, 60.0)
		arrays[Mesh.ARRAY_VERTEX] = new_vertices
		arrays[Mesh.ARRAY_NORMAL] = new_normals
		arrays[Mesh.ARRAY_TEX_UV] = new_uvs
		arrays[Mesh.ARRAY_INDEX] = new_indices
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return array_mesh


## Calculates smoothed vertex normals based on maximum smoothing threshold angle in degrees
static func calculate_smooth_normals(vertices: PackedVector3Array, indices: PackedInt32Array, smooth_angle_deg: float) -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	var cos_threshold = cos(deg_to_rad(smooth_angle_deg))

	# Compute face normals
	var face_normals: Array[Vector3] = []
	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]
		var fn = (vertices[i1] - vertices[i0]).cross(vertices[i2] - vertices[i0]).normalized()
		face_normals.append(fn)

	# Accumulate face normals into vertices
	for i in range(0, indices.size(), 3):
		var face_idx = i / 3
		var fn = face_normals[face_idx]
		for j in range(3):
			var vert_idx = indices[i + j]
			if normals[vert_idx].length_squared() == 0 or normals[vert_idx].normalized().dot(fn) >= cos_threshold:
				normals[vert_idx] += fn

	# Normalize
	for i in range(normals.size()):
		if normals[i].length_squared() > 0:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	return normals
