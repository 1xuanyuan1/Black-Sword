class_name DamageEvent
extends RefCounted

var amount: float
var source: Node
var direction: Vector2
var knockback: float
var critical: bool
var tags: Array[StringName]


static func create(
	new_amount: float,
	new_source: Node,
	new_direction: Vector2 = Vector2.ZERO,
	new_knockback: float = 0.0,
	new_critical: bool = false,
	new_tags: Array[StringName] = []
) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = new_amount
	event.source = new_source
	event.direction = new_direction
	event.knockback = new_knockback
	event.critical = new_critical
	event.tags = new_tags
	return event
