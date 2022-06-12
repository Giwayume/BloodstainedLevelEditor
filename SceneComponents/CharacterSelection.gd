extends ConfirmationDialog

signal character_selected

const character_profiles = preload("res://Config/CharacterProfiles.gd").character_profiles

var character_selection_dialog: ConfirmationDialog
var character_item_list: ItemList

var character_list_selection_map: Array = []

func _ready():
	character_selection_dialog = self
	character_item_list = find_node("CharacterItemList", true, true)
	
	character_selection_dialog.connect("confirmed", self, "on_dialog_ok")
	character_selection_dialog.connect("about_to_show", self, "on_dialog_show")
	character_item_list.connect("item_activated", self, "on_item_activated")

func on_dialog_show():
	character_item_list.clear()
	
	var profile_index = 0
	for character_profile in character_profiles:
		if character_profile["example_placement_package"] and character_profile["example_placement_export_object_name"]:
			character_list_selection_map.push_back(profile_index)
			character_item_list.add_item(character_profile.character_id + " " + character_profile.character_name)
		profile_index += 1
	
	character_item_list.select(0)

func on_item_activated(index):
	on_dialog_ok()
	character_selection_dialog.visible = false

func on_dialog_ok():
	var selected = character_item_list.get_selected_items()[0]
	var character_index = character_list_selection_map[selected]
	emit_signal("character_selected", character_profiles[character_index])

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
