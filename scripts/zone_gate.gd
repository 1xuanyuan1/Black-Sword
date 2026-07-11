class_name ZoneGate
extends StaticBody2D

@export var gate_id: StringName
@export var unlock_wave := 1
var locked := true


func _ready() -> void:
	add_to_group("zone_gates")
	collision_layer = 2
	collision_mask = 0
	queue_redraw()


func unlock() -> void:
	if not locked:
		return
	locked = false
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	queue_redraw()


func _draw() -> void:
	if not locked:
		return
	var height := 250.0
	for index in range(7):
		var y := -height * 0.5 + float(index) * height / 6.0
		draw_line(Vector2(-18, y), Vector2(18, y), Color(0.45, 0.75, 1.0, 0.62), 4.0)
	draw_line(Vector2.ZERO, Vector2(0, -height * 0.5), Color(0.7, 0.9, 1.0, 0.8), 5.0)
	draw_line(Vector2.ZERO, Vector2(0, height * 0.5), Color(0.7, 0.9, 1.0, 0.8), 5.0)
