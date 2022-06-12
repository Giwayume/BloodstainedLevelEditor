extends Reference
class_name ObjectExt

# Deep copy any value
static func deep_copy(value):
	var new_value = value
	var value_type = typeof(value)
	if value_type == TYPE_VECTOR3:
		new_value = Vector3(value.x, value.y, value.z)
	elif value_type == TYPE_DICTIONARY:
		new_value = {}
		for key in value:
			new_value[key] = deep_copy(value[key])
	elif value_type == TYPE_ARRAY:
		new_value = []
		for item in value:
			new_value.push_back(deep_copy(item))
	return new_value
