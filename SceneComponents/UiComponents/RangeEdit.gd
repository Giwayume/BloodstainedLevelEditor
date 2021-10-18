tool
extends Container
class_name RangeEdit

signal value_changed
signal value_committed

export(float) var value: float setget set_value, get_value
var _value: float = 0

export(float) var min_value: float setget set_min_value, get_min_value
var _min_value: float = 0

export(float) var max_value: float setget set_max_value, get_max_value
var _max_value: float = 100

export(float) var step: float setget set_step, get_step
var _step: float = 1

const slider_grabber_hidden_icon = preload("res://Icons/Editor/SliderGrabberHidden.png")

var line_edit: LineEdit
var slider: HSlider

var is_line_edit_dirty: bool = false
var is_line_edit_focused: bool = false
var is_slider_dirty: bool = false
var is_slider_focused: bool = false
var is_control_modifier_pressed: bool = false
var is_shift_modifier_pressed: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	line_edit = $LineEdit
	slider = $HSlider
	
	line_edit.text = str(_value)
	slider.min_value = _min_value
	slider.max_value = _max_value
	slider.step = _step
	slider.value = _value
	
	slider.add_icon_override("grabber", slider_grabber_hidden_icon)
	slider.add_icon_override("grabber_highlight", slider_grabber_hidden_icon)
	
	line_edit.connect("text_changed", self, "on_line_edit_text_changed")
	line_edit.connect("text_entered", self, "on_line_edit_text_entered")
	line_edit.connect("focus_entered", self, "on_line_edit_focus_entered")
	line_edit.connect("focus_exited", self, "on_line_edit_focus_exited")
	slider.connect("mouse_entered", self, "on_slider_mouse_entered")
	slider.connect("mouse_exited", self, "on_slider_mouse_exited")
	slider.connect("value_changed", self, "on_slider_value_changed")
	slider.connect("focus_entered", self, "on_slider_focus_entered")
	slider.connect("focus_exited", self, "on_slider_focus_exited")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and not event.pressed:
			if is_slider_focused:
				slider.release_focus()
	if event is InputEventKey:
		if event.scancode == KEY_CONTROL:
			is_control_modifier_pressed = event.pressed
		elif event.scancode == KEY_SHIFT:
			is_shift_modifier_pressed = event.pressed
		elif is_control_modifier_pressed and not is_shift_modifier_pressed and event.scancode == KEY_Z:
			if event.pressed:
				if is_line_edit_focused:
					line_edit.release_focus()
		elif (is_control_modifier_pressed and event.scancode == KEY_Y) or (is_control_modifier_pressed and is_shift_modifier_pressed and event.scancode == KEY_Z):
			if event.pressed:
				if is_line_edit_focused:
					line_edit.release_focus()
		elif event.scancode == KEY_ESCAPE:
			if is_line_edit_focused:
				line_edit.release_focus()

func _notification(what):
	if what == NOTIFICATION_SORT_CHILDREN:
		rect_size.y = 22
		if line_edit:
			fit_child_in_rect(line_edit, Rect2(Vector2(), rect_size))
		if slider:
			fit_child_in_rect(slider, Rect2(Vector2(3, rect_size.y - (slider.rect_size.y / 2) - 4), Vector2(rect_size.x - 6, rect_size.y)))
		call_deferred("adjust_margin_after_sort")

func adjust_margin_after_sort():
	margin_top = -(anchor_top * rect_size.y)

func on_line_edit_focus_entered():
	call_deferred("emit_focus_entered_signal", is_line_edit_focused, is_slider_focused)
	is_line_edit_focused = true
	slider.hide()

func on_line_edit_focus_exited():
	call_deferred("emit_focus_exited_signal", is_line_edit_focused, is_slider_focused)
	is_line_edit_focused = false
	slider.show()
	if is_line_edit_dirty:
		is_line_edit_dirty = false
		emit_signal("value_committed", _value)

func on_line_edit_text_changed(new_text: String):
	is_line_edit_dirty = true
	var new_value = float(new_text)
	if new_value != _value:
		_value = new_value
		emit_signal("value_changed", _value)
	
func on_line_edit_text_entered(new_text: String):
	if is_line_edit_dirty:
		is_line_edit_dirty = false
		if slider.value != _value:
			slider.value = _value
		emit_signal("value_committed", _value)

func on_slider_value_changed(value: float):
	is_slider_dirty = true
	if value != _value:
		_value = value
		line_edit.text = str(_value)
		emit_signal("value_changed", _value)

func on_slider_focus_entered():
	call_deferred("emit_focus_entered_signal", is_line_edit_focused, is_slider_focused)
	is_slider_focused = true

func on_slider_focus_exited():
	call_deferred("emit_focus_exited_signal", is_line_edit_focused, is_slider_focused)
	is_slider_focused = false
	if is_slider_dirty:
		is_slider_dirty = false
		emit_signal("value_committed", _value)

func on_slider_mouse_entered():
	slider.add_icon_override("grabber", null)
	slider.add_icon_override("grabber_highlight", null)
	
func on_slider_mouse_exited():
	slider.add_icon_override("grabber", slider_grabber_hidden_icon)
	slider.add_icon_override("grabber_highlight", slider_grabber_hidden_icon)

func emit_focus_entered_signal(old_is_line_edit_focused: bool, old_is_slider_focused: bool):
	if (
		(is_line_edit_focused or is_slider_focused) and not (old_is_line_edit_focused or old_is_slider_focused)
	):
		Editor.history_shortcuts_disabled = true
		emit_signal("focus_entered")

func emit_focus_exited_signal(old_is_line_edit_focused: bool, old_is_slider_focused: bool):
	if (
		(old_is_line_edit_focused or old_is_slider_focused) and not is_line_edit_focused and not is_slider_focused
	):
		Editor.history_shortcuts_disabled = false
		emit_signal("focus_exited")

func grab_focus():
	line_edit.grab_focus()

func release_focus():
	if is_line_edit_focused:
		line_edit.release_focus()
	elif is_slider_focused:
		slider.release_focus()

func set_value(value: float):
	_value = value
	if line_edit != null:
		line_edit.text = str(_value)
	if slider != null and not is_line_edit_focused:
		var slider_value = _value
		if slider_value < _min_value:
			slider_value = _min_value
		if slider_value > _max_value:
			slider_value = _max_value
		if slider.value != slider_value:
			slider.value = slider_value

func get_value():
	return _value

func set_min_value(min_value: float):
	_min_value = min_value
	if slider != null:
		slider.min_value = _min_value
	if _value < _min_value:
		set_value(_min_value)

func get_min_value():
	return _min_value

func set_max_value(max_value: float):
	_max_value = max_value
	if slider != null:
		slider.max_value = _max_value
	if _value > _max_value:
		set_value(_max_value)

func get_max_value():
	return _max_value
	
func set_step(step: float):
	_step = step
	if slider != null:
		slider.step = _step

func get_step():
	return _step


