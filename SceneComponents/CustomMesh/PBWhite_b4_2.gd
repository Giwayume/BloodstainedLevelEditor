extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	generate_sectioned_slope_4(.5, .533333, .566667, .6, 6)
	.create_collision_area()
