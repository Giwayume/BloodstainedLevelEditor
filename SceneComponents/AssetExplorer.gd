extends Control

var editor: Node
var uasset_parser: Node

var search_edit: LineEdit
var search_clear_button: Button
var asset_item_list: ItemList

var asset_list: Array
var asset_list_filtered: Array

func _ready():
	editor = get_node("/root/Editor");
	uasset_parser = get_node("/root/UAssetParser")
	
	search_edit = find_node("SearchEdit", true, true)
	search_clear_button = find_node("SearchClearButton", true, true)
	asset_item_list = find_node("AssetItemList", true, true)
	
	search_edit.connect("text_changed", self, "on_search_edit_text_changed")
	search_clear_button.connect("pressed", self, "on_search_clear_button_pressed")

func on_search_clear_button_pressed():
	search_edit.text = ""
	filter_asset_list("")

func on_search_edit_text_changed(new_text: String):
	filter_asset_list(new_text)

func load_asset_list():
	for asset_path in uasset_parser.AssetPathToPakFilePathMap:
		asset_list.push_back(asset_path)
	asset_list.sort()
	filter_asset_list("")

func filter_asset_list(search_text: String):
	search_text = search_text.to_lower()
	var search_terms: Array = search_text.rsplit(" ");
	asset_item_list.clear()
	asset_list_filtered = []
	for asset_path in asset_list:
		var is_include: bool = true
		for search_term in search_terms:
			if search_term != "" and not search_term in asset_path.to_lower():
				is_include = false
				break
		if is_include:
			asset_item_list.add_item(asset_path)
			asset_list_filtered.push_back(asset_path)
