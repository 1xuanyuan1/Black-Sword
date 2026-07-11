class_name MapZone
extends Node2D

@export var zone_id: StringName
@export var display_name := "区域"
@export var size := Vector2(600, 500)
@export var zone_color := Color(0.2, 0.3, 0.4, 0.08)
@export var unlocked := false


func _ready() -> void:
	queue_redraw()


func set_unlocked(value: bool) -> void:
	unlocked = value
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var color := zone_color if unlocked else Color(zone_color, zone_color.a * 0.32)
	draw_rect(rect, color, true)
	draw_rect(rect, Color(zone_color.lightened(0.35), 0.42 if unlocked else 0.16), false, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5 + 24, -size.y * 0.5 + 42), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.82, 0.88, 0.96, 0.72 if unlocked else 0.28))
