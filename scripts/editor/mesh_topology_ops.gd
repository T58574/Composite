class_name MeshTopologyOps
extends RefCounted

## Utility library for Sprocket-style mesh topology operations:
## Extrude Face, Subdivide / Split, and Normal Smoothing calculations.

## Extrudes target quad/triangle face along its normal vector by distance
static func extrude_face(mesh_data: Array, face_indices: Array[int], distance: float) -> Array:
	# Returns updated vertex array with extruded geometry
	var updated_mesh = mesh_data.duplicate(true)
	if face_indices.size() < 3:
		return updated_mesh

	# Compute normal for the face
	var p0: Vector3 = updated_mesh[face_indices[0]]
	var p1: Vector3 = updated_mesh[face_indices[1]]
	var p2: Vector3 = updated_mesh[face_indices[2]]
	var normal = (p1 - p0).cross(p2 - p0).normalized()

	var offset = normal * distance
	for idx in face_indices:
		if idx >= 0 and idx < updated_mesh.size():
			updated_mesh[idx] += offset

	return updated_mesh

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
