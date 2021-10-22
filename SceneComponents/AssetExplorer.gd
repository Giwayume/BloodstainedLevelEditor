extends Control

var icon_action_copy = preload("res://Icons/Editor/ActionCopy.svg")

var editor: Node
var uasset_parser: Node

var asset_popup_menu: PopupMenu
var search_edit: LineEdit
var search_clear_button: Button
var asset_item_list: ItemList

var asset_list: Array
var asset_list_filtered: Array
var selected_item_index: int = -1

enum { ASSET_POPUP_COPY_PATH }
var asset_popup_menu_items: Array = [
	{
		"id": ASSET_POPUP_COPY_PATH,
		"type": "icon",
		"texture": icon_action_copy,
		"label": "Copy Path"
	}
]

func _ready():
	editor = get_node("/root/Editor");
	uasset_parser = get_node("/root/UAssetParser")
	
	asset_item_list = find_node("AssetItemList", true, true)
	asset_popup_menu = find_node("AssetPopupMenu", true, true)
	search_edit = find_node("SearchEdit", true, true)
	search_clear_button = find_node("SearchClearButton", true, true)
	
	asset_item_list.allow_rmb_select = true
	
	asset_item_list.connect("item_selected", self, "on_asset_list_item_selected")
	asset_item_list.connect("item_rmb_selected", self, "on_asset_list_item_rmb_selected")
	asset_popup_menu.connect("id_pressed", self, "on_asset_popup_menu_id_pressed")
	search_edit.connect("text_changed", self, "on_search_edit_text_changed")
	search_clear_button.connect("pressed", self, "on_search_clear_button_pressed")

func on_asset_popup_menu_id_pressed(id: int):
	if id == ASSET_POPUP_COPY_PATH and selected_item_index > -1:
		OS.set_clipboard(asset_list_filtered[selected_item_index])

func on_asset_list_item_selected(index: int):
	selected_item_index = index

func on_asset_list_item_rmb_selected(index: int, position: Vector2):
	selected_item_index = index
	build_asset_popup_menu()
	var viewport_size = get_viewport().size
	var popup_position: Vector2 = asset_item_list.rect_global_position + position
	asset_popup_menu.popup()
	asset_popup_menu.rect_global_position = popup_position
	asset_popup_menu.set_as_minsize()
	if popup_position.x + asset_popup_menu.rect_size.x > viewport_size.x:
		popup_position.x = viewport_size.x - asset_popup_menu.rect_size.x
	if popup_position.y + asset_popup_menu.rect_size.y > viewport_size.y:
		popup_position.y = viewport_size.y - asset_popup_menu.rect_size.y
	asset_popup_menu.rect_global_position = popup_position

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
	selected_item_index = -1
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

func build_asset_popup_menu():
	asset_popup_menu.clear()
	for item in asset_popup_menu_items:
		build_popup_menu_item(item, asset_popup_menu)

func build_popup_menu_item(item, popup_menu):
	if item.type == "icon":
		popup_menu.add_icon_item(item.texture, item.label, item.id)
	elif item.type == "separator":
		popup_menu.add_separator()
