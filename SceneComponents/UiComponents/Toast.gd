extends CenterContainer

var label: Label
var show_timeout: float = 3
var fade_timeout: float = .5
var fade_timeout_max: float = .5

# Called when the node enters the scene tree for the first time.
func _ready():
	label = find_node("Label", true, true)

func set_text(text: String):
	label.text = text

func _process(delta):
	if show_timeout > 0:
		show_timeout -= delta
	elif fade_timeout > 0:
		fade_timeout -= delta
		modulate.a = fade_timeout / fade_timeout_max
	else:
		queue_free()
