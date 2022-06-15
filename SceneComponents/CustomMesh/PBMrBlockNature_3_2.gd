extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	generate_octagon(.6, 1.8, 1.8, 6)
	.create_collision_area()
