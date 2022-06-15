extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	generate_octagon(.3, 1.5, .6, 6)
	.create_collision_area()
