extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	generate_sectioned_slope_3(.5, .576765, .6, 6)
	.create_collision_area()
