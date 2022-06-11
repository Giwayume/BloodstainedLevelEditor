extends CustomCollisionMesh

# Called when the node enters the scene tree for the first time.
func create_collision_area():
	generate_box_slope(.6, .6, .3, .6)
	.create_collision_area()
