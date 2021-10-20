extends Reference
class_name UE4Convert

static func convert_translation_from_unreal_to_godot(unreal_translation: Vector3):
	return Vector3(
		unreal_translation.x * 0.01,
		unreal_translation.z * 0.01,
		unreal_translation.y * 0.01
	)
	
static func convert_rotation_from_unreal_to_godot(unreal_rotation: Vector3):
	var spatial = Spatial.new()
	spatial.rotate_x(deg2rad(unreal_rotation.z))
	spatial.rotate_z(deg2rad(unreal_rotation.x))
	spatial.rotate_y(deg2rad(-unreal_rotation.y))
	var godot_rotation: Vector3 = Vector3(
		spatial.rotation_degrees.x,
		spatial.rotation_degrees.y,
		spatial.rotation_degrees.z
	)
	spatial = null;
	return godot_rotation

static func convert_scale_from_unreal_to_godot(unreal_scale: Vector3):
	return Vector3(
		unreal_scale.x,
		unreal_scale.z,
		unreal_scale.y
	)

static func convert_translation_from_godot_to_unreal(godot_translation: Vector3):
	return Vector3(
		godot_translation.x * 100,
		godot_translation.z * 100,
		godot_translation.y * 100
	)

static func convert_rotation_from_godot_to_unreal(godot_rotation: Vector3):
	var spatial = Spatial.new()
	spatial.rotate_x(deg2rad(godot_rotation.z))
	spatial.rotate_z(deg2rad(godot_rotation.x))
	spatial.rotate_y(deg2rad(-godot_rotation.y))
	var unreal_rotation: Vector3 = Vector3(
		spatial.rotation_degrees.x,
		spatial.rotation_degrees.y,
		spatial.rotation_degrees.z
	)
	spatial = null;
	return unreal_rotation

static func convert_scale_from_godot_to_unreal(godot_scale: Vector3):
	return Vector3(
		godot_scale.x,
		godot_scale.z,
		godot_scale.y
	)
