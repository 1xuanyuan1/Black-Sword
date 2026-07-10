class_name MovementJoystick
extends Control

signal direction_changed(direction: Vector2)

@export var joystick_radius: float = 68.0
@export var knob_radius: float = 29.0
@export_range(0.0, 0.9, 0.01) var dead_zone: float = 0.12

var direction: Vector2 = Vector2.ZERO
var input_enabled: bool = true
var active_touch_index: int = -1
var mouse_dragging: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and active_touch_index < 0:
			active_touch_index = touch_event.index
			_update_direction(touch_event.position)
			accept_event()
		elif not touch_event.pressed and touch_event.index == active_touch_index:
			reset_input()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == active_touch_index:
			_update_direction(drag_event.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			mouse_dragging = mouse_button.pressed
			if mouse_dragging:
				_update_direction(mouse_button.position)
			else:
				reset_input()
			accept_event()
	elif event is InputEventMouseMotion and mouse_dragging:
		var mouse_motion := event as InputEventMouseMotion
		_update_direction(mouse_motion.position)
		accept_event()


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	modulate.a = 1.0 if value else 0.38
	if not value:
		reset_input()


func reset_input() -> void:
	active_touch_index = -1
	mouse_dragging = false
	_set_direction(Vector2.ZERO)


func _update_direction(local_position: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var raw_direction: Vector2 = (local_position - center) / maxf(joystick_radius, 1.0)
	var next_direction: Vector2 = raw_direction.limit_length(1.0)
	if next_direction.length() < dead_zone:
		next_direction = Vector2.ZERO
	_set_direction(next_direction)


func _set_direction(next_direction: Vector2) -> void:
	if direction.distance_squared_to(next_direction) < 0.000001:
		return
	direction = next_direction
	direction_changed.emit(direction)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var knob_position: Vector2 = center + direction * joystick_radius
	draw_circle(center, joystick_radius + 13.0, Color(0.025, 0.045, 0.08, 0.48))
	draw_circle(center, joystick_radius, Color(0.12, 0.23, 0.34, 0.34))
	draw_arc(center, joystick_radius, 0.0, TAU, 72, Color(0.48, 0.76, 0.88, 0.62), 3.0, true)
	draw_line(center + Vector2(-joystick_radius * 0.68, 0.0), center + Vector2(joystick_radius * 0.68, 0.0), Color(0.65, 0.84, 0.91, 0.24), 2.0)
	draw_line(center + Vector2(0.0, -joystick_radius * 0.68), center + Vector2(0.0, joystick_radius * 0.68), Color(0.65, 0.84, 0.91, 0.24), 2.0)
	draw_circle(knob_position, knob_radius + 5.0, Color(0.03, 0.08, 0.13, 0.72))
	draw_circle(knob_position, knob_radius, Color(0.43, 0.78, 0.88, 0.78))
	draw_arc(knob_position, knob_radius, 0.0, TAU, 48, Color(0.83, 0.96, 1.0, 0.92), 2.0, true)
