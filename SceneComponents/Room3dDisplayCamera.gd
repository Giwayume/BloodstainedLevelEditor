extends Camera

signal transform_changed

export(float, 0.0, 1.0) var sensitivity = 0.25

# Updated by RoomEdit.gd
var can_capture_mouse: bool = false
var can_capture_keyboard: bool = false
var viewport_position: Vector2 = Vector2()

# Mouse state
var _mouse_position = Vector2(0.0, 0.0)
var _total_pitch = 0.0
var _captured_mouse_position = Vector2(0.0, 0.0)

# Movement state
var _direction = Vector3(0.0, 0.0, 0.0)
var _velocity = Vector3(0.0, 0.0, 0.0)
var _acceleration = 30
var _deceleration = -10
var _vel_multiplier = 10

# Keyboard state
var _w = false
var _s = false
var _a = false
var _d = false
var _q = false
var _e = false

func _input(event):
	
	# Receives mouse motion
	if event is InputEventMouseMotion:
		_mouse_position = event.relative
	
	# Receives mouse button input
	if event is InputEventMouseButton:
		match event.button_index:
			BUTTON_RIGHT: # Only allows rotation if right click down
				if can_capture_mouse and event.pressed:
					_captured_mouse_position = get_viewport().get_mouse_position()
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				if not event.pressed:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					if _captured_mouse_position != null:
						get_viewport().warp_mouse(viewport_position + _captured_mouse_position)
						_captured_mouse_position = null
#			BUTTON_WHEEL_UP: # Increases max velocity
#				_vel_multiplier = clamp(_vel_multiplier * 1.1, 0.2, 20)
#			BUTTON_WHEEL_DOWN: # Decereases max velocity
#				_vel_multiplier = clamp(_vel_multiplier / 1.1, 0.2, 20)

	# Receives key input
	if event is InputEventKey:
		match event.scancode:
			KEY_W:
				_w = event.pressed
			KEY_S:
				_s = event.pressed
			KEY_A:
				_a = event.pressed
			KEY_D:
				_d = event.pressed
			KEY_Q:
				_q = event.pressed
			KEY_E:
				_e = event.pressed
			KEY_ESCAPE:
				if _captured_mouse_position != null:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					get_viewport().warp_mouse(viewport_position + _captured_mouse_position)
					_captured_mouse_position = null

# Updates mouselook and movement every frame
func _process(delta):
	_update_mouselook()
	_update_movement(delta)
	emit_signal("transform_changed", transform)

# Updates camera movement
func _update_movement(delta):
	if can_capture_keyboard:
		# Computes desired direction from key states
		_direction = Vector3(_d as float - _a as float, 
							 _e as float - _q as float,
							 _s as float - _w as float)
		
		# Computes the change in velocity due to desired direction and "drag"
		# The "drag" is a constant acceleration on the camera to bring it's velocity to 0
		var offset = _direction.normalized() * _acceleration * _vel_multiplier * delta \
			+ _velocity.normalized() * _deceleration * _vel_multiplier * delta
		
		# Checks if we should bother translating the camera
		if _direction == Vector3.ZERO and offset.length_squared() > _velocity.length_squared():
			# Sets the velocity to 0 to prevent jittering due to imperfect deceleration
			_velocity = Vector3.ZERO
		else:
			# Clamps speed to stay within maximum value (_vel_multiplier)
			_velocity.x = clamp(_velocity.x + offset.x, -_vel_multiplier, _vel_multiplier)
			_velocity.y = clamp(_velocity.y + offset.y, -_vel_multiplier, _vel_multiplier)
			_velocity.z = clamp(_velocity.z + offset.z, -_vel_multiplier, _vel_multiplier)
		
			translate(_velocity * delta)

# Updates mouse look 
func _update_mouselook():
	# Only rotates mouse if the mouse is captured
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if can_capture_mouse:
			_mouse_position *= sensitivity
			var yaw = _mouse_position.x
			var pitch = _mouse_position.y
			_mouse_position = Vector2(0, 0)
			
			# Prevents looking up/down too far
			pitch = clamp(pitch, -90 - _total_pitch, 90 - _total_pitch)
			_total_pitch += pitch
		
			rotate_y(deg2rad(-yaw))
			rotate_object_local(Vector3(1,0,0), deg2rad(-pitch))
		else:
			if _captured_mouse_position != null:
				get_viewport().warp_mouse(viewport_position + _captured_mouse_position)
				_captured_mouse_position = null
