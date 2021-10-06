extends Reference
class_name UE4Convert

static func convert_translation_from_unreal_to_godot(unreal_translation: Vector3):
	return Vector3(
		unreal_translation.x,
		unreal_translation.z,
		unreal_translation.y
	)
	
static func convert_rotation_from_unreal_to_godot(unreal_rotation: Vector3):
	return Vector3(
		unreal_rotation.z,
		-unreal_rotation.y,
		unreal_rotation.x
	)

static func convert_scale_from_unreal_to_godot(unreal_scale: Vector3):
	return Vector3(
		unreal_scale.x,
		unreal_scale.z,
		unreal_scale.y
	)

static func convert_translation_from_godot_to_unreal(godot_translation: Vector3):
	return Vector3(
		godot_translation.x,
		godot_translation.z,
		godot_translation.y
	)

static func convert_rotation_from_godot_to_unreal(godot_rotation: Vector3):
	return Vector3(
		godot_rotation.z,
		-godot_rotation.y,
		godot_rotation.x
	)

static func convert_scale_from_godot_to_unreal(godot_scale: Vector3):
	return Vector3(
		godot_scale.x,
		godot_scale.z,
		godot_scale.y
	)
