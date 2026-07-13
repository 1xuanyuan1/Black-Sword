class_name BreakablePot
extends Area2D

var drop_system: ItemDropSystem
var broken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("breakable_pots")
	queue_redraw()


func setup(new_drop_system: ItemDropSystem) -> void:
	drop_system = new_drop_system


func take_damage(_event: DamageEvent = null) -> void:
	break_open()


func break_open() -> void:
	if broken:
		return
	broken = true
	set_deferred("monitoring", false)
	if is_instance_valid(drop_system):
		drop_system.pot_broken(global_position)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerActor:
		break_open()


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -8), Vector2(13, -8), Vector2(10, 13), Vector2(5, 18), Vector2(-5, 18), Vector2(-10, 13)]), Color("7f5138"))
	draw_polyline(PackedVector2Array([Vector2(-13, -8), Vector2(13, -8), Vector2(10, 13), Vector2(5, 18), Vector2(-5, 18), Vector2(-10, 13), Vector2(-13, -8)]), Color("d6a067"), 2.0, true)
	draw_rect(Rect2(-10, -13, 20, 5), Color("b6794d"), true)
	draw_line(Vector2(-8, 2), Vector2(8, 7), Color("4c3028"), 2.0)
