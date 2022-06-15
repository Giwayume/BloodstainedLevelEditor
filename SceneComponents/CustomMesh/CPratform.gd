extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	
	var static_mesh = ""
	if definition.has("static_mesh_asset_path"):
		static_mesh = definition.static_mesh_asset_path
	
	if static_mesh == "BloodstainedRotN/Content/Core/Environment/ACT02_VIL/Meshes/VillageBridge.uasset":
		generate_village_bridge()
	else:
		generate_cube(.3, .3, .5)
	.create_collision_area()

func generate_village_bridge():
	var depth = 6
	var halfdepth = depth / 2
	
	var area = Area.new()
	area.set_script(node_selection_area_script)
	area.selectable_parent = self
	var collision_polygon = CollisionPolygon.new()
	collision_polygon.polygon = PoolVector2Array([
		Vector2(0, 0),
		Vector2(0, .6),
		Vector2(.139095, .460957),
		Vector2(2.94865, -1.78992),
		Vector2(2.8361, -1.93039),
		Vector2(.425754, 0)
	])
	collision_polygon.depth = depth
	collision_polygon.transform.origin = Vector3(0, 0, 0)
	area.add_child(collision_polygon)
	collision_area = area
	
	var cv = ImmediateGeometry.new()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, 0, -halfdepth))
	cv.add_vertex(Vector3(0, .6, -halfdepth))
	cv.add_vertex(Vector3(0.139095, 0.460957, -halfdepth))
	cv.add_vertex(Vector3(2.94865, -1.78992, -halfdepth))
	cv.add_vertex(Vector3(2.8361, -1.93039, -halfdepth))
	cv.add_vertex(Vector3(.425754, 0, -halfdepth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINE_LOOP)
	cv.add_vertex(Vector3(0, 0, halfdepth))
	cv.add_vertex(Vector3(0, .6, halfdepth))
	cv.add_vertex(Vector3(0.139095, 0.460957, halfdepth))
	cv.add_vertex(Vector3(2.94865, -1.78992, halfdepth))
	cv.add_vertex(Vector3(2.8361, -1.93039, halfdepth))
	cv.add_vertex(Vector3(.425754, 0, halfdepth))
	cv.end()
	cv.begin(Mesh.PRIMITIVE_LINES)
	cv.add_vertex(Vector3(0, 0, halfdepth))
	cv.add_vertex(Vector3(0, 0, -halfdepth))
	cv.add_vertex(Vector3(0, .6, halfdepth))
	cv.add_vertex(Vector3(0, .6, -halfdepth))
	cv.add_vertex(Vector3(0.139095, 0.460957, halfdepth))
	cv.add_vertex(Vector3(0.139095, 0.460957, -halfdepth))
	cv.add_vertex(Vector3(2.94865, -1.78992, halfdepth))
	cv.add_vertex(Vector3(2.94865, -1.78992, -halfdepth))
	cv.add_vertex(Vector3(2.8361, -1.93039, halfdepth))
	cv.add_vertex(Vector3(2.8361, -1.93039, -halfdepth))
	cv.add_vertex(Vector3(.425754, 0, halfdepth))
	cv.add_vertex(Vector3(.425754, 0, -halfdepth))
	cv.end()
	collision_visualization = cv
