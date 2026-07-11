class_name EvolutionChest
extends Area2D

var chest_id: StringName
var evolution_system: EvolutionSystem
var consumed := false
var available := false
var pulse := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func setup(id: StringName, system: EvolutionSystem) -> void:
	chest_id = id
	evolution_system = system
	add_to_group("evolution_chests")
	queue_redraw()


func set_available(value: bool) -> void:
	available = value
	queue_redraw()


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not consumed and body is PlayerActor and is_instance_valid(evolution_system):
		evolution_system.request_open(chest_id)


func consume() -> void:
	consumed = true
	monitoring = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.35, 0.15), 0.18)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var color := Color("ffd76a") if available else Color("78869a")
	var glow := 0.12 + sin(pulse * 4.0) * 0.04
	draw_circle(Vector2.ZERO, 28.0, Color(color, glow))
	draw_rect(Rect2(-22, -12, 44, 28), Color("35291b"), true)
	draw_rect(Rect2(-22, -12, 44, 28), color, false, 3.0)
	draw_rect(Rect2(-24, -19, 48, 10), Color("4a3820"), true)
	draw_rect(Rect2(-24, -19, 48, 10), color, false, 3.0)
	draw_circle(Vector2(0, 2), 4.0, color)
	if not available:
		draw_string(ThemeDB.fallback_font, Vector2(-7, -28), "锁", HORIZONTAL_ALIGNMENT_CENTER, 14, 14, Color("cbd2dc"))
