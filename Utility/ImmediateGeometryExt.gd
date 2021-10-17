extends Reference
class_name ImmediateGeometryExt

static func draw_circle_arc(im: ImmediateGeometry, center: Vector3, rotation_axis: Vector3, rotation_phi: float, radius: float, angle_from: float, angle_to: float, nb_points: int = 16):
	var points_arc = PoolVector3Array()
	var transform = Transform()
	transform = transform.rotated(rotation_axis.normalized(), deg2rad(rotation_phi))

	for i in range(nb_points + 1):
		var angle_point = deg2rad(angle_from + i * (angle_to-angle_from) / nb_points - 90)
		var point = center + transform.xform(Vector3(cos(angle_point), sin(angle_point), 0) * radius)
		im.add_vertex(point)
