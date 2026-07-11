class_name ItemPickup
extends Area2D

@onready var icon_sprite: Sprite2D = $Icon

var definition: ItemDefinition
var drop_system: ItemDropSystem
var elapsed := 0.0
var collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(new_definition: ItemDefinition, new_drop_system: ItemDropSystem) -> void:
	definition = new_definition
	drop_system = new_drop_system
	icon_sprite.texture = definition.icon
	icon_sprite.modulate = definition.accent
	icon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_sprite.scale = Vector2.ONE * 3.2
	add_to_group("item_pickups")
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	icon_sprite.position.y = sin(elapsed * 4.5) * 3.0
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not collected and body is PlayerActor and is_instance_valid(drop_system):
		collected = drop_system.collect_item(definition.id, self)


func _draw() -> void:
	if definition == null:
		return
	var pulse := 0.75 + sin(elapsed * 5.0) * 0.15
	draw_circle(Vector2.ZERO, 20.0, Color(definition.accent, 0.10 * pulse))
	draw_arc(Vector2.ZERO, 18.0 + pulse * 2.0, 0.0, TAU, 24, Color(definition.accent, 0.72), 2.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-50, -29), definition.display_name, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 14, Color(definition.accent, 0.95))
