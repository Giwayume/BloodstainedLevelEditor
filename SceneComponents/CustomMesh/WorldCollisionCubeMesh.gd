extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	generate_cube(.3, .3, .3)
	.create_collision_area()
