extends Reference
class_name ArrayExt

# SANE slicing where end is non-inclusive, like every other SANE language out there
static func slice(array: Array, start = null, end = null, step = null):
	var stop = array.size()
	var sliced = []
	if step == null:
		step = 1
	if start == null:
		return array
	if start < 0:
		start = start + array.size()
	if end != null:
		if end >= 0:
			stop = end
		else:
			stop = array.size() + end
	for i in range(start, stop, step):
		sliced.push_back(array[i])
	return sliced
