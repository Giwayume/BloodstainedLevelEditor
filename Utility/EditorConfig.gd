extends Reference
class_name EditorConfig

const config_path = "user://Editor.conf"

static func create_config_if_not_exist():
	var config_file = File.new()
	if not config_file.file_exists(config_path):
		config_file.open(config_path, File.WRITE)
		config_file.store_line("{}")
		config_file.close()

static func read_config():
	create_config_if_not_exist()
	var config_file = File.new()
	var file_error = config_file.open(config_path, File.READ)
	if file_error == OK:
		var config_json = config_file.get_as_text()
		var config_dictionary_parse = JSON.parse(config_json)
		if config_dictionary_parse.error == OK:
			config_file.close()
			return config_dictionary_parse.result
	config_file.close()
	return {}

static func write_config_prop(prop_name: String, prop_data):
	create_config_if_not_exist()
	var config_dictionary = read_config()
	if config_dictionary != null:
		config_dictionary[prop_name] = prop_data
		var config_file = File.new()
		var file_error = config_file.open(config_path, File.READ_WRITE)
		if file_error == OK:
			config_file.store_string(JSON.print(config_dictionary, "    "))
		config_file.close()
	
