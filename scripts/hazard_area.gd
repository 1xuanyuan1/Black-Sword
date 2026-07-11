class_name HazardArea
extends Node2D

@export var hazard_id: StringName
@export var radius := 120.0
@export var damage := 12.0
@export var warning_duration := 0.7
@export var active_duration := 2.5
@export var hazard_color := Color("c94f5d")

var arena: Arena
var warning_remaining := 0.0
var active_remaining := 0.0
var damage_timer := 0.0
var activation_count := 0


func setup(new_arena: Arena) -> void:
	arena = new_arena
	visible = false
	queue_redraw()


func activate(at_position: Vector2 = Vector2.INF) -> void:
	if at_position != Vector2.INF:
		global_position = at_position
	warning_remaining = warning_duration
	active_remaining = 0.0
	damage_timer = 0.0
	activation_count += 1
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if warning_remaining > 0.0:
		warning_remaining -= delta
		if warning_remaining <= 0.0:
			active_remaining = active_duration
		queue_redraw()
		return
	if active_remaining <= 0.0:
		visible = false
		return
	active_remaining -= delta
	damage_timer -= delta
	if damage_timer <= 0.0 and is_instance_valid(arena.player) and global_position.distance_to(arena.player.global_position) <= radius + 18.0:
		damage_timer = 0.55
		arena.player.take_damage(DamageEvent.create(damage, self, global_position.direction_to(arena.player.global_position), 55.0, false, [&"environment", hazard_id]))
	queue_redraw()


func _draw() -> void:
	if warning_remaining > 0.0:
		var progress := 1.0 - warning_remaining / warning_duration
		draw_circle(Vector2.ZERO, radius, Color(hazard_color, 0.05 + progress * 0.12))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU * progress, 48, Color(hazard_color, 0.9), 5.0)
	elif active_remaining > 0.0:
		draw_circle(Vector2.ZERO, radius, Color(hazard_color, 0.24))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(hazard_color, 0.8), 4.0)
