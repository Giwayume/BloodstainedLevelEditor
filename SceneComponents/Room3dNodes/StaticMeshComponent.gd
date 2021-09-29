extends Spatial

var room_3d_display: Spatial
var definition: Dictionary

func _ready():
	if definition.has("translation"):
		translation = definition["translation"]
	if definition.has("rotation_degrees"):
		rotation_degrees = definition["rotation_degrees"]
	if definition.has("scale"):
		scale = definition["scale"]
	if definition.has("static_mesh_name"):
		room_3d_display.load_3d_model(definition, self, "on_3d_model_loaded")

func on_3d_model_loaded(loaded_model):
	loaded_model.name = "Model3D"
	add_child(loaded_model)
