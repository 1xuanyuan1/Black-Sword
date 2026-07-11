class_name RuntimeObjectPool
extends Node

const POOL_LIMITS := {
	&"projectile": 220,
	&"experience_orb": 240,
	&"effect": 180,
}

var inactive: Dictionary = {
	&"projectile": [],
	&"experience_orb": [],
	&"effect": [],
}
var created_counts: Dictionary = {}
var reused_counts: Dictionary = {}
var recycled_counts: Dictionary = {}


func acquire(kind: StringName) -> Node:
	if not inactive.has(kind):
		return null
	var bucket: Array = inactive[kind]
	while not bucket.is_empty():
		var candidate: Node = bucket.pop_back()
		if is_instance_valid(candidate):
			if candidate.get_parent() == self:
				remove_child(candidate)
			reused_counts[kind] = int(reused_counts.get(kind, 0)) + 1
			if candidate is CanvasItem:
				(candidate as CanvasItem).visible = true
			return candidate
	var instance := _create_instance(kind)
	if instance != null:
		created_counts[kind] = int(created_counts.get(kind, 0)) + 1
	return instance


func recycle(kind: StringName, instance: Node) -> void:
	if not inactive.has(kind) or not is_instance_valid(instance):
		return
	if instance.get_parent() != null:
		instance.get_parent().remove_child(instance)
	instance.remove_from_group("projectiles")
	instance.remove_from_group("xp_orbs")
	instance.set_process(false)
	instance.set_physics_process(false)
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	var bucket: Array = inactive[kind]
	if bucket.size() >= int(POOL_LIMITS[kind]):
		instance.queue_free()
		return
	add_child(instance)
	bucket.append(instance)
	recycled_counts[kind] = int(recycled_counts.get(kind, 0)) + 1


func inactive_count(kind: StringName) -> int:
	return (inactive.get(kind, []) as Array).size()


func stats() -> Dictionary:
	return {
		"created": created_counts.duplicate(),
		"reused": reused_counts.duplicate(),
		"recycled": recycled_counts.duplicate(),
		"inactive_projectiles": inactive_count(&"projectile"),
		"inactive_experience_orbs": inactive_count(&"experience_orb"),
		"inactive_effects": inactive_count(&"effect"),
	}


func _create_instance(kind: StringName) -> Node:
	match kind:
		&"projectile":
			return CombatProjectile.new()
		&"experience_orb":
			return ExperienceOrb.new()
		&"effect":
			return EffectNode.new()
	return null
