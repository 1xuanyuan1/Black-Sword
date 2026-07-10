class_name SkillSystem
extends Node

signal skills_changed(levels: Dictionary, active_ids: Array[StringName], passive_ids: Array[StringName])

var arena: Node
var player: PlayerActor
var definitions: Dictionary
var levels: Dictionary = {}
var active_ids: Array[StringName] = []
var passive_ids: Array[StringName] = []
var cooldowns: Dictionary = {}
var orbit_angle := 0.0
var rng := RandomNumberGenerator.new()


func setup(new_arena: Node, new_player: PlayerActor, skill_definitions: Dictionary) -> void:
	arena = new_arena
	player = new_player
	definitions = skill_definitions
	rng.randomize()
	upgrade(&"black_slash")


func process_skills(delta: float) -> void:
	if not arena.run_active or player.dead:
		return
	orbit_angle += delta * 2.6
	for id in active_ids:
		cooldowns[id] = float(cooldowns.get(id, 0.0)) - delta
		if cooldowns[id] <= 0.0:
			_cast_skill(id)


func get_upgrade_options(count: int = 3) -> Array[SkillDefinition]:
	var candidates: Array[SkillDefinition] = []
	for definition in definitions.values():
		var current_level: int = levels.get(definition.id, 0)
		if current_level > 0 and current_level < definition.max_level:
			candidates.append(definition)
		elif current_level == 0:
			if definition.skill_type == SkillDefinition.SkillType.ACTIVE and active_ids.size() < 4:
				candidates.append(definition)
			elif definition.skill_type == SkillDefinition.SkillType.PASSIVE and passive_ids.size() < 2:
				candidates.append(definition)
	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))


func upgrade(id: StringName) -> void:
	if not definitions.has(id):
		return
	var definition: SkillDefinition = definitions[id]
	var current: int = levels.get(id, 0)
	if current >= definition.max_level:
		return
	if current == 0:
		if definition.skill_type == SkillDefinition.SkillType.ACTIVE:
			if active_ids.size() >= 4:
				return
			active_ids.append(id)
			cooldowns[id] = 0.15
		else:
			if passive_ids.size() >= 2:
				return
			passive_ids.append(id)
	levels[id] = current + 1
	_apply_passives()
	skills_changed.emit(levels.duplicate(), active_ids.duplicate(), passive_ids.duplicate())


func damage_multiplier() -> float:
	var level: int = levels.get(&"tempered_edge", 0)
	if level <= 0:
		return 1.0
	return 1.0 + float(definitions[&"tempered_edge"].stats(level).get("damage", 0.0))


func cooldown_multiplier() -> float:
	var level: int = levels.get(&"tempered_edge", 0)
	if level <= 0:
		return 1.0
	return 1.0 - float(definitions[&"tempered_edge"].stats(level).get("cdr", 0.0))


func _apply_passives() -> void:
	var light_level: int = levels.get(&"light_step", 0)
	if light_level > 0:
		var stats: Dictionary = definitions[&"light_step"].stats(light_level)
		player.speed_multiplier = 1.0 + float(stats.get("speed", 0.0))
		player.pickup_range = 92.0 * (1.0 + float(stats.get("pickup", 0.0)))
	else:
		player.speed_multiplier = 1.0
		player.pickup_range = 92.0


func _cast_skill(id: StringName) -> void:
	var level: int = levels.get(id, 0)
	if level <= 0:
		return
	var definition: SkillDefinition = definitions[id]
	var stats := definition.stats(level)
	cooldowns[id] = float(stats.get("cooldown", 1.0)) * cooldown_multiplier()
	match id:
		&"black_slash": _cast_black_slash(stats)
		&"flying_sword": _cast_flying_sword(stats)
		&"sword_wave": _cast_sword_wave(stats)
		&"orbit_blades": _cast_orbit(stats)
		&"thunder": _cast_thunder(stats)
		&"frost": _cast_frost(stats)
		&"sun_palm": _cast_sun_palm(stats)
		&"sword_rain": _cast_sword_rain(stats)


func _cast_black_slash(stats: Dictionary) -> void:
	var target: Variant = arena.nearest_enemy(player.global_position)
	var direction: Vector2 = player.last_direction
	if is_instance_valid(target):
		direction = player.global_position.direction_to(target.global_position)
	player.last_direction = direction
	player.play_attack()
	_perform_slash(direction, stats)
	if stats.get("double", false):
		_delayed_slash(direction.rotated(-0.18), stats)


func _perform_slash(direction: Vector2, stats: Dictionary) -> void:
	var radius: float = stats.get("range", 100.0)
	var arc_value: float = stats.get("arc", 2.0)
	var damage: float = stats.get("damage", 10.0) * damage_multiplier()
	arena.add_effect(EffectNode.create(&"slash", player.global_position, {"direction": direction, "radius": radius, "arc": arc_value, "duration": 0.28, "color": Color("edf5ff")}))
	for enemy in arena.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var to_enemy := player.global_position.direction_to(enemy.global_position)
		if player.global_position.distance_to(enemy.global_position) <= radius + enemy.hit_radius and absf(direction.angle_to(to_enemy)) <= arc_value * 0.5:
			enemy.take_damage(DamageEvent.create(damage, player, to_enemy, 90.0, false, [&"slash"]))
	arena.play_sfx(&"slash")


func _delayed_slash(direction: Vector2, stats: Dictionary) -> void:
	await get_tree().create_timer(0.18).timeout
	if is_instance_valid(player) and arena.run_active:
		_perform_slash(direction, stats)


func _cast_flying_sword(stats: Dictionary) -> void:
	var target: Variant = arena.nearest_enemy(player.global_position)
	if not is_instance_valid(target):
		cooldowns[&"flying_sword"] = 0.25
		return
	var base_direction: Vector2 = player.global_position.direction_to(target.global_position)
	var count: int = stats.get("count", 1)
	for i in range(count):
		var offset := (float(i) - float(count - 1) * 0.5) * 0.16
		arena.add_projectile(CombatProjectile.create({
			"arena": arena, "owner": player, "position": player.global_position,
			"direction": base_direction.rotated(offset), "speed": stats.get("speed", 400.0),
			"damage": float(stats.get("damage", 15.0)) * damage_multiplier(), "radius": 13.0,
			"pierce": int(stats.get("pierce", 1)), "lifetime": 2.1, "kind": &"sword",
			"homing": true, "returning": stats.get("returning", false), "knockback": 42.0,
		}))
	arena.play_sfx(&"magic")


func _cast_sword_wave(stats: Dictionary) -> void:
	var target: Variant = arena.nearest_enemy(player.global_position)
	if not is_instance_valid(target):
		cooldowns[&"sword_wave"] = 0.25
		return
	var direction: Vector2 = player.global_position.direction_to(target.global_position)
	_spawn_wave(direction, stats)
	if stats.get("cross", false):
		_spawn_wave(direction.rotated(PI * 0.5), stats)


func _spawn_wave(direction: Vector2, stats: Dictionary) -> void:
	arena.add_projectile(CombatProjectile.create({
		"arena": arena, "owner": player, "position": player.global_position,
		"direction": direction, "speed": stats.get("speed", 450.0),
		"damage": float(stats.get("damage", 22.0)) * damage_multiplier(),
		"radius": float(stats.get("width", 24.0)), "pierce": int(stats.get("pierce", 4)),
		"lifetime": 2.0, "kind": &"wave", "knockback": 70.0,
	}))
	player.play_attack()
	arena.play_sfx(&"slash")


func _cast_orbit(stats: Dictionary) -> void:
	var count: int = stats.get("count", 2)
	var radius_value: float = stats.get("radius", 74.0)
	var damage: float = float(stats.get("damage", 7.0)) * damage_multiplier()
	var positions: Array[Vector2] = []
	for i in range(count):
		positions.append(player.global_position + Vector2.from_angle(orbit_angle + TAU * float(i) / float(count)) * radius_value)
	if stats.get("inner", false):
		for i in range(maxi(2, count / 2)):
			positions.append(player.global_position + Vector2.from_angle(-orbit_angle * 1.35 + TAU * float(i) / float(maxi(2, count / 2))) * radius_value * 0.58)
	for blade_position in positions:
		arena.add_effect(EffectNode.create(&"orbit", blade_position, {"duration": 0.32, "color": Color("e8e2ff")}))
		for enemy in arena.enemies.duplicate():
			if is_instance_valid(enemy) and not enemy.dead and blade_position.distance_to(enemy.global_position) < 26.0 + enemy.hit_radius:
				enemy.take_damage(DamageEvent.create(damage, player, blade_position.direction_to(enemy.global_position), 26.0, false, [&"orbit"]))


func _cast_thunder(stats: Dictionary) -> void:
	var available: Array = []
	for enemy in arena.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			available.append(enemy)
	if available.is_empty():
		cooldowns[&"thunder"] = 0.3
		return
	available.sort_custom(func(a, b) -> bool: return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position))
	var starts: int = stats.get("starts", 1)
	var hit: Dictionary = {}
	for start_index in range(mini(starts, available.size())):
		var current_position := player.global_position
		var current = available[start_index]
		for chain in range(int(stats.get("chains", 3))):
			if not is_instance_valid(current):
				break
			var id: int = current.get_instance_id()
			if hit.has(id):
				current = _nearest_unhit(current.global_position, available, hit)
				continue
			hit[id] = true
			var line: Vector2 = current.global_position - current_position
			arena.add_effect(EffectNode.create(&"lightning", current_position, {"line_end": line, "duration": 0.26, "color": Color("fff36b")}))
			current.take_damage(DamageEvent.create(float(stats.get("damage", 24.0)) * damage_multiplier(), player, line.normalized(), 35.0, false, [&"lightning"]))
			current_position = current.global_position
			current = _nearest_unhit(current_position, available, hit)
	arena.play_sfx(&"magic")


func _nearest_unhit(position: Vector2, available: Array, hit: Dictionary):
	var best = null
	var best_distance := 180.0 * 180.0
	for enemy in available:
		if not is_instance_valid(enemy) or hit.has(enemy.get_instance_id()):
			continue
		var distance := position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _cast_frost(stats: Dictionary) -> void:
	var target: Variant = arena.densest_enemy(player.global_position, 420.0)
	if not is_instance_valid(target):
		cooldowns[&"frost"] = 0.3
		return
	var center: Vector2 = target.global_position
	var radius_value: float = stats.get("radius", 100.0)
	arena.add_effect(EffectNode.create(&"frost", center, {"radius": radius_value, "duration": stats.get("duration", 2.0), "color": Color("7edbff"), "z": 3}))
	for enemy in arena.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and center.distance_to(enemy.global_position) <= radius_value + enemy.hit_radius:
			enemy.take_damage(DamageEvent.create(float(stats.get("damage", 15.0)) * damage_multiplier(), player, center.direction_to(enemy.global_position), 22.0, false, [&"frost"]))
			enemy.apply_slow(stats.get("slow", 0.65), stats.get("duration", 2.0), stats.get("freeze", false))
	arena.play_sfx(&"magic")


func _cast_sun_palm(stats: Dictionary) -> void:
	_perform_palm(stats, 1.0)
	if stats.get("double", false):
		_delayed_palm(stats)


func _perform_palm(stats: Dictionary, scale_value: float) -> void:
	var radius_value: float = float(stats.get("radius", 100.0)) * scale_value
	arena.add_effect(EffectNode.create(&"pulse", player.global_position, {"radius": radius_value, "duration": 0.45, "color": Color("ff984c")}))
	for enemy in arena.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and player.global_position.distance_to(enemy.global_position) <= radius_value + enemy.hit_radius:
			var direction := player.global_position.direction_to(enemy.global_position)
			enemy.take_damage(DamageEvent.create(float(stats.get("damage", 18.0)) * damage_multiplier(), player, direction, float(stats.get("knockback", 130.0)), false, [&"palm"]))
	arena.play_sfx(&"magic")


func _delayed_palm(stats: Dictionary) -> void:
	await get_tree().create_timer(0.24).timeout
	if is_instance_valid(player) and arena.run_active:
		_perform_palm(stats, 1.14)


func _cast_sword_rain(stats: Dictionary) -> void:
	var target: Variant = arena.densest_enemy(player.global_position, 560.0)
	if not is_instance_valid(target):
		cooldowns[&"sword_rain"] = 0.3
		return
	var center: Vector2 = target.global_position
	var radius_value: float = stats.get("radius", 110.0)
	arena.telegraph_circle(center, radius_value, 0.48, Color("bfa9ff"))
	_resolve_sword_rain(center, stats)


func _resolve_sword_rain(center: Vector2, stats: Dictionary) -> void:
	await get_tree().create_timer(0.48).timeout
	if not arena.run_active:
		return
	var targets: Array = []
	for enemy in arena.enemies:
		if is_instance_valid(enemy) and not enemy.dead and center.distance_to(enemy.global_position) <= float(stats.get("radius", 110.0)) + enemy.hit_radius:
			targets.append(enemy)
	targets.shuffle()
	var count: int = stats.get("count", 5)
	for i in range(mini(count, targets.size())):
		var enemy = targets[i]
		arena.add_effect(EffectNode.create(&"sword", enemy.global_position + Vector2(0, -22), {"duration": 0.38, "color": Color("d8c9ff")}))
		enemy.take_damage(DamageEvent.create(float(stats.get("damage", 18.0)) * damage_multiplier(), player, Vector2.DOWN, 40.0, false, [&"sword_rain"]))
	if stats.get("giant", false):
		arena.add_effect(EffectNode.create(&"sword", center + Vector2(0, -30), {"duration": 0.62, "color": Color("fff2cf")}))
		for enemy in targets:
			if is_instance_valid(enemy):
				enemy.take_damage(DamageEvent.create(float(stats.get("damage", 18.0)) * 0.55 * damage_multiplier(), player, center.direction_to(enemy.global_position), 70.0, false, [&"giant_sword"]))
	arena.play_sfx(&"slash")
