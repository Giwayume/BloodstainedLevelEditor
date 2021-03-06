extends Reference
class_name DirectoryExt

static func remove_recursive(path):
	var directory = Directory.new()
	
	# Open directory
	var error = directory.open(path)
	if error == OK:
		# List directory content
		directory.list_dir_begin(true)
		var file_name = directory.get_next()
		while file_name != "":
			if directory.current_is_dir():
				remove_recursive(path + "/" + file_name)
			else:
				directory.remove(file_name)
			file_name = directory.get_next()
		
		# Remove current path
		directory.remove(path)
	else:
		print_debug("Error removing " + path)

static func list_files(path):
	var directory = Directory.new()
	var files = []
	directory.open(path)
	directory.list_dir_begin()
	
	while true:
		var file = directory.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and not directory.current_is_dir():
			files.append(file)
	
	directory.list_dir_end()
	
	return files
