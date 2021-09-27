extends Control

var loading_screen_status_label: Label

# Called when the node enters the scene tree for the first time.
func _ready():
	loading_screen_status_label = find_node("LoadingScreenStatusLabel", true, true)

func set_status_text(text: String):
	loading_screen_status_label.text = text
