class_name EffectNode
extends Node2D

var effect_kind: StringName = &"circle"
var duration := 0.5
var elapsed := 0.0
var radius := 80.0
var color := Color.WHITE
var direction := Vector2.RIGHT
var arc := PI * 2.0
var line_end := Vector2.ZERO
var label_text := ""


static func create(kind: StringName, position_value: Vector2, options: Dictionary = {}) -> EffectNode:
	var effect := EffectNode.new()
	effect.effect_kind = kind
	effect.global_position = position_value
	effect.duration = options.get("duration", 0.5)
	effect.radius = options.get("radius", 80.0)
	effect.color = options.get("color", Color.WHITE)
	effect.direction = options.get("direction", Vector2.RIGHT)
	effect.arc = options.get("arc", PI * 2.0)
	effect.line_end = options.get("line_end", Vector2.ZERO)
	effect.label_text = options.get("text", "")
	effect.z_index = options.get("z", 20)
	return effect


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()


func _draw() -> void:
	var t := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var fade := 1.0 - t
	var draw_color := Color(color, color.a * fade)
	match effect_kind:
		&"slash":
			var start_angle := direction.angle() - arc * 0.5
			draw_arc(Vector2.ZERO, radius * (0.78 + t * 0.22), start_angle, start_angle + arc, 22, draw_color, 9.0 * fade + 2.0, true)
			draw_arc(Vector2.ZERO, radius * 0.72, start_angle, start_angle + arc, 22, Color(0.05, 0.07, 0.12, fade), 4.0, true)
		&"pulse":
			draw_circle(Vector2.ZERO, radius * t, Color(draw_color, 0.12 * fade))
			draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 48, draw_color, 7.0 * fade + 1.0, true)
		&"frost":
			draw_circle(Vector2.ZERO, radius * (0.65 + t * 0.35), Color(draw_color, 0.13 * fade))
			for i in range(12):
				var angle := TAU * float(i) / 12.0
				var p := Vector2.from_angle(angle) * radius * (0.35 + 0.6 * t)
				draw_line(p - Vector2(0, 9).rotated(angle), p + Vector2(0, 9).rotated(angle), draw_color, 3.0)
		&"lightning":
			var end := line_end
			var points := PackedVector2Array([Vector2.ZERO])
			for i in range(1, 7):
				var p := end * (float(i) / 7.0)
				p += Vector2.from_angle(end.angle() + PI * 0.5) * sin(float(i) * 8.3 + elapsed * 30.0) * 9.0
				points.append(p)
			points.append(end)
			draw_polyline(points, draw_color, 5.0 * fade + 1.0, true)
		&"warning_circle":
			var pulse := 0.55 + 0.35 * sin(elapsed * 13.0)
			draw_circle(Vector2.ZERO, radius, Color(color, 0.08 * pulse))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.65 * pulse), 3.0, true)
		&"warning_line":
			var normal := direction.normalized()
			var side := normal.rotated(PI * 0.5) * radius
			var length := line_end.length()
			var polygon := PackedVector2Array([-side, side, normal * length + side, normal * length - side])
			draw_colored_polygon(polygon, Color(color, 0.12 + 0.05 * sin(elapsed * 14.0)))
			draw_polyline(PackedVector2Array([Vector2.ZERO, normal * length]), Color(color, 0.8), 3.0, true)
		&"warning_cone":
			var center := direction.angle()
			var points := PackedVector2Array([Vector2.ZERO])
			for i in range(21):
				points.append(Vector2.from_angle(center - arc * 0.5 + arc * i / 20.0) * radius)
			draw_colored_polygon(points, Color(color, 0.14 + 0.05 * sin(elapsed * 14.0)))
			draw_arc(Vector2.ZERO, radius, center - arc * 0.5, center + arc * 0.5, 22, Color(color, 0.8), 3.0, true)
		&"orbit":
			draw_set_transform(Vector2.ZERO, elapsed * 7.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -13), Vector2(3, -13), Vector2(5, 9), Vector2.ZERO, Vector2(-5, 9)]), draw_color)
		&"sword":
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -18), Vector2(3, -18), Vector2(4, 9), Vector2.ZERO, Vector2(-4, 9)]), draw_color)
			draw_line(Vector2(-8, 8), Vector2(8, 8), draw_color, 3.0)
		&"damage_text":
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(-18, -t * 28.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 18, draw_color)
