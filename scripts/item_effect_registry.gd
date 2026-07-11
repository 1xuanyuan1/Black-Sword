class_name ItemEffectRegistry
extends RefCounted

var _handlers: Dictionary


func _init() -> void:
	_handlers = {
		&"heal_ratio": _apply_heal,
		&"gather_experience": _apply_gather_experience,
		&"soul_bell": _apply_soul_bell,
		&"binding_talisman": _apply_binding_talisman,
		&"soul_wine": _apply_soul_wine,
	}


func supports(effect_id: StringName) -> bool:
	return _handlers.has(effect_id)


func apply(definition: ItemDefinition, arena: Arena) -> bool:
	if definition == null or not _handlers.has(definition.effect_id) or not is_instance_valid(arena) or not is_instance_valid(arena.player):
		return false
	return bool((_handlers[definition.effect_id] as Callable).call(definition, arena))


func _apply_heal(definition: ItemDefinition, arena: Arena) -> bool:
	var ratio := float(definition.effect_values.get("health_ratio", 0.30))
	arena.player.heal(arena.player.max_health * ratio)
	return true


func _apply_gather_experience(_definition: ItemDefinition, arena: Arena) -> bool:
	for node in arena.get_tree().get_nodes_in_group("xp_orbs"):
		var orb := node as ExperienceOrb
		if is_instance_valid(orb):
			orb.pull_to_player()
	return true


func _apply_soul_bell(definition: ItemDefinition, arena: Arena) -> bool:
	var normal_ratio := float(definition.effect_values.get("normal_ratio", 0.40))
	var elite_ratio := float(definition.effect_values.get("elite_ratio", 0.20))
	for enemy in arena.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_in_group("boss"):
			continue
		var ratio := elite_ratio if enemy is EnemyActor and enemy.elite else normal_ratio
		enemy.take_damage(DamageEvent.create(enemy.max_health * ratio, arena.player, Vector2.ZERO, 0.0, false, [&"item", &"soul_bell"]))
	return true


func _apply_binding_talisman(definition: ItemDefinition, arena: Arena) -> bool:
	var normal_duration := float(definition.effect_values.get("normal_duration", 6.0))
	var elite_duration := float(definition.effect_values.get("elite_duration", 3.0))
	var boss_duration := float(definition.effect_values.get("boss_duration", 3.0))
	var boss_slow := float(definition.effect_values.get("boss_slow", 0.70))
	for enemy in arena.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.is_in_group("boss"):
			enemy.apply_slow(boss_slow, boss_duration)
		elif enemy is EnemyActor and enemy.elite:
			enemy.apply_slow(0.0, elite_duration, true)
		else:
			enemy.apply_slow(0.0, normal_duration, true)
	return true


func _apply_soul_wine(definition: ItemDefinition, arena: Arena) -> bool:
	arena.activate_temporary_item_effect(definition.id, definition.effect_values)
	return true
