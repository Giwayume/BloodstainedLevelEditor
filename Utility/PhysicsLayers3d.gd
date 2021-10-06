extends Reference
class_name PhysicsLayers3d

const layers: Dictionary = {}
const bits: Dictionary = {}

static func read_layers():
	layers["none"] = 0
	bits[0] = "none"
	for i in range(1, 21):
		var layer_name = ProjectSettings.get_setting(
			str("layer_names/3d_physics/layer_", i)
		)
		if not layer_name:
			layer_name = str("Layer ", i)
		layers[layer_name] = int(pow(2, i - 1))
		bits[pow(2, i - 1)] = layer_name
