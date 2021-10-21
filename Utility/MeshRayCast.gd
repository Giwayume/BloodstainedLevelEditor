extends Reference
class_name MeshRayCast

# mesh_instance - MeshInstance node that contains the mesh you want to raycast with
# global_ray_from - Starting position of the raycast in world coordinates
# global_ray_to - Ending position of the raycast in world coordinates
static func intersect_ray(mesh_instance: MeshInstance, global_ray_from: Vector3, global_ray_to: Vector3):
	var direction: Vector3 = global_ray_to - global_ray_from
	var intersections: Array = []
	var closest = null
	var closest_distance = INF
	if mesh_instance != null:
		var mesh: Mesh = mesh_instance.mesh
		for surface_index in mesh.get_surface_count():
			var surface_arrays = mesh.surface_get_arrays(surface_index)
			var vertex_array = mesh_instance.get_global_transform().xform(surface_arrays[Mesh.ARRAY_VERTEX])
			var vertex_array_length = len(vertex_array)
			var face_array = surface_arrays[Mesh.ARRAY_INDEX]
			var face_array_length = len(face_array)
			for face_index in range(0, face_array_length, 3):
				var intersection = Geometry.ray_intersects_triangle(
					global_ray_from,
					direction,
					vertex_array[face_array[face_index + 2]],
					vertex_array[face_array[face_index + 1]],
					vertex_array[face_array[face_index + 0]]
				)
				if intersection != null:
					intersections.push_back(
						intersection
					)
		if len(intersections) > 0:
			closest = intersections[0]
			closest_distance = global_ray_from.distance_to(intersections[0])
			for intersection_index in range(1, len(intersections)):
				var distance = global_ray_from.distance_to(intersections[intersection_index])
				if distance < closest_distance:
					closest_distance = distance
					closest = intersections[intersection_index]
	return {
		"intersections": intersections,
		"closest": closest,
		"closest_distance": closest_distance
	}

