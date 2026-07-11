class_name SkillController
extends Node

signal skills_changed(levels: Dictionary, active_ids: Array[StringName], passive_ids: Array[StringName])

const DRAGON_TORNADO_TEXTURE := preload("res://assets/vfx/dragon_tornado.png")

var arena: Node
var player: PlayerActor
var definitions: Dictionary
var inventory := SkillInventory.new()
var levels: Dictionary:
	get:
		return inventory.levels
var active_ids: Array[StringName]:
	get:
		return inventory.active_ids
var passive_ids: Array[StringName]:
	get:
		return inventory.passive_ids
var cooldowns: Dictionary = {}
var orbit_angle := 0.0
var orbit_animation_time := 0.0
var orbit_visuals: Array[Sprite2D] = []
var dragon_spear_casts := 0
var nightfall_casts := 0
var rng := RandomNumberGenerator.new()
var base_player_max_health := 100.0


func setup(new_arena: Node, new_player: PlayerActor, skill_definitions: Dictionary, initial_skill_id: StringName = &"black_slash", seed: int = 0) -> void:
	arena = new_arena
	player = new_player
	definitions = skill_definitions
	base_player_max_health = player.max_health
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	inventory.setup(skill_definitions, seed)
	upgrade(initial_skill_id)


func process_skills(delta: float) -> void:
	if not arena.run_active or player.dead:
		_clear_orbit_visuals()
		return
	var orbit_id: StringName = &"wind_god_guard" if inventory.has_skill(&"wind_god_guard") else &"orbit_blades"
	var orbit_level: int = levels.get(orbit_id, 0)
	if orbit_level > 0:
		var orbit_stats: Dictionary = definitions[orbit_id].stats(orbit_level)
		var rotation_speed: float = orbit_stats.get("rotation_speed", 2.0)
		orbit_angle = fposmod(orbit_angle + delta * rotation_speed, TAU)
		orbit_animation_time += delta * (10.0 + rotation_speed * 2.2)
		_update_orbit_visuals(orbit_stats)
	else:
		_clear_orbit_visuals()
	var regen := health_regeneration_per_second()
	if regen > 0.0 and player.health < player.max_health:
		player.heal(player.max_health * regen * delta)
	for id in active_ids:
		cooldowns[id] = float(cooldowns.get(id, 0.0)) - delta
		if cooldowns[id] <= 0.0:
			_cast_skill(id)


func get_upgrade_options(count: int = 3, custom_rng: RandomNumberGenerator = null) -> Array[SkillDefinition]:
	return inventory.get_upgrade_options(count, custom_rng)


func upgrade(id: StringName) -> SkillUpgradeResult:
	if id == SkillInventory.RECOVERY_ID:
		player.heal(player.max_health * 0.20)
		return SkillUpgradeResult.recovery()
	var result := inventory.upgrade(id)
	if not result.success:
		return result
	if result.added_to_slot and definitions[id].skill_type == SkillDefinition.SkillType.ACTIVE:
		cooldowns[id] = 0.15
	_apply_passives()
	skills_changed.emit(levels.duplicate(), active_ids.duplicate(), passive_ids.duplicate())
	return result


func can_add_skill(id: StringName) -> bool:
	return inventory.can_add_skill(id)


func apply_evolution(recipe: EvolutionRecipe) -> SkillUpgradeResult:
	var previous_cooldown: float = cooldowns.get(recipe.active_skill_id, 0.0)
	var result := inventory.apply_evolution(recipe)
	if not result.success:
		return result
	cooldowns.erase(recipe.active_skill_id)
	cooldowns[recipe.evolved_skill_id] = previous_cooldown
	_apply_passives()
	skills_changed.emit(levels.duplicate(), active_ids.duplicate(), passive_ids.duplicate())
	return result


func damage_multiplier() -> float:
	var level: int = levels.get(&"tempered_edge", 0)
	var skill_multiplier := 1.0
	if level > 0:
		skill_multiplier += float(definitions[&"tempered_edge"].stats(level).get("damage", 0.0))
	var meta_multiplier := 1.0
	if is_instance_valid(arena) and arena.get("run_config") is RunConfig:
		meta_multiplier = (arena.get("run_config") as RunConfig).attack_multiplier
	var item_multiplier: float = arena.temporary_item_damage_multiplier() if is_instance_valid(arena) and arena.has_method("temporary_item_damage_multiplier") else 1.0
	return skill_multiplier * meta_multiplier * item_multiplier


func cooldown_multiplier() -> float:
	var level: int = levels.get(&"tempered_edge", 0)
	var multiplier := 1.0
	if level > 0:
		multiplier -= float(definitions[&"tempered_edge"].stats(level).get("cdr", 0.0))
	if is_instance_valid(arena) and arena.get("run_config") is RunConfig:
		multiplier *= (arena.get("run_config") as RunConfig).cooldown_multiplier
	if is_instance_valid(arena) and arena.has_method("temporary_item_cooldown_multiplier"):
		multiplier *= arena.temporary_item_cooldown_multiplier()
	return maxf(multiplier, 0.45)


func area_multiplier() -> float:
	var passive_bonus := _passive_value(&"formation_breaking", "area")
	if is_instance_valid(arena) and arena.get("run_config") is RunConfig:
		return (arena.get("run_config") as RunConfig).area_multiplier + passive_bonus
	return 1.0 + passive_bonus


func status_duration_multiplier() -> float:
	var passive_bonus := _passive_value(&"mystic_yin", "status_duration")
	if is_instance_valid(arena) and arena.get("run_config") is RunConfig:
		return (arena.get("run_config") as RunConfig).status_duration_multiplier + passive_bonus
	return 1.0 + passive_bonus


func melee_damage_multiplier() -> float:
	if is_instance_valid(arena) and arena.get("run_config") is RunConfig:
		return (arena.get("run_config") as RunConfig).melee_damage_multiplier
	return 1.0


func projectile_speed_multiplier() -> float:
	return 1.0 + _passive_value(&"spacetime_formula", "projectile_speed") + _passive_value(&"sword_casket", "projectile_speed")


func projectile_lifetime_multiplier() -> float:
	return 1.0 + _passive_value(&"sword_control", "projectile_lifetime")


func projectile_pierce_bonus() -> int:
	return roundi(_passive_value(&"sword_control", "pierce"))


func quantity_bonus() -> int:
	return roundi(_passive_value(&"sword_casket", "quantity"))


func knockback_multiplier() -> float:
	return 1.0 + _passive_value(&"formation_breaking", "knockback")


func critical_chance() -> float:
	return minf(_passive_value(&"thunder_seal", "critical_chance"), 0.60)


func critical_damage_multiplier() -> float:
	var level := inventory.level_of(&"thunder_seal")
	return 1.5 if level <= 0 else _passive_value(&"thunder_seal", "critical_multiplier")


func target_category_damage_multiplier() -> float:
	return 1.0 + _passive_value(&"battlefield_tactics", "elite_boss_damage")


func health_regeneration_per_second() -> float:
	return _passive_value(&"pure_yang", "regen")


func make_player_damage_event(amount: float, direction: Vector2 = Vector2.ZERO, knockback: float = 0.0, tags: Array[StringName] = []) -> DamageEvent:
	var critical := rng.randf() < critical_chance()
	var final_amount := amount * (critical_damage_multiplier() if critical else 1.0)
	return DamageEvent.create(final_amount, player, direction, knockback * knockback_multiplier(), critical, tags)


func _apply_passives() -> void:
	var speed_bonus := _passive_value(&"light_step", "speed") + _passive_value(&"spacetime_formula", "speed") + _passive_value(&"battlefield_tactics", "speed")
	player.speed_multiplier = player.character_speed_multiplier * (1.0 + speed_bonus)
	player.pickup_range = 92.0 * (1.0 + _passive_value(&"light_step", "pickup"))
	var old_max := player.max_health
	var health_ratio := player.health / old_max if old_max > 0.0 else 1.0
	player.max_health = base_player_max_health * (1.0 + _passive_value(&"pure_yang", "max_health"))
	player.health = minf(player.max_health, player.max_health * health_ratio)
	var base_reduction := 1.0 - player.base_damage_taken_multiplier
	var passive_reduction := _passive_value(&"mystic_yin", "damage_reduction")
	player.damage_taken_multiplier = maxf(0.55, 1.0 - base_reduction - passive_reduction)
	player.health_changed.emit(player.health, player.max_health)


func _passive_value(id: StringName, key: String) -> float:
	var level := inventory.level_of(id)
	if level <= 0 or not definitions.has(id):
		return 0.0
	return float((definitions[id] as SkillDefinition).stats(level).get(key, 0.0))


func _cast_skill(id: StringName) -> void:
	var level: int = levels.get(id, 0)
	if level <= 0:
		return
	var definition: SkillDefinition = definitions[id]
	var stats := definition.stats(level)
	cooldowns[id] = float(stats.get("cooldown", 1.0)) * cooldown_multiplier()
	match id:
		&"black_slash": _cast_black_slash(stats)
		&"rasengan": _cast_rasengan(stats)
		&"flying_sword": _cast_flying_sword(stats)
		&"sword_wave": _cast_sword_wave(stats)
		&"orbit_blades": _cast_orbit(stats)
		&"thunder": _cast_thunder(stats)
		&"frost": _cast_frost(stats)
		&"sun_palm": _cast_sun_palm(stats)
		&"sword_rain": _cast_sword_rain(stats)
		&"dragon_spear": _cast_dragon_spear(stats)
		&"nightfall_unbound": _cast_nightfall_unbound(stats)
		&"flying_thunder_chain": _cast_flying_thunder_chain(stats)
		&"celestial_sword_river": _cast_celestial_sword_river(stats)
		&"ten_direction_sword_realm": _cast_ten_direction_sword_realm(stats)
		&"wind_god_guard": _cast_orbit(stats)
		&"nine_heavens_thunder_prison": _cast_thunder(stats)
		&"absolute_frost_domain": _cast_frost(stats)
		&"boundless_sun": _cast_boundless_sun(stats)
		&"exorcising_sword_array": _cast_sword_rain(stats)
		&"seven_in_seven_out": _cast_seven_in_seven_out(stats)


func _cast_nightfall_unbound(stats: Dictionary) -> void:
	nightfall_casts += 1
	var radius_value := float(stats.get("range", 178.0)) * area_multiplier()
	var damage := float(stats.get("damage", 82.0)) * damage_multiplier() * melee_damage_multiplier()
	arena.add_effect(EffectNode.create(&"pulse", player.global_position, {"radius": radius_value, "duration": 0.32, "color": Color("eaf4ff")}))
	for enemy in arena.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and player.global_position.distance_to(enemy.global_position) <= radius_value + enemy.hit_radius:
			enemy.take_damage(make_player_damage_event(damage, player.global_position.direction_to(enemy.global_position), 125.0, [&"slash", &"evolved"]))
	if nightfall_casts % 3 == 0:
		_delayed_night_rift(radius_value * 1.25, damage * 0.72)
	player.play_attack(player.last_direction)
	arena.play_sfx(&"slash")


func _delayed_night_rift(radius_value: float, damage: float) -> void:
	await get_tree().create_timer(0.22).timeout
	if not is_instance_valid(player) or not arena.run_active:
		return
	arena.add_effect(EffectNode.create(&"pulse", player.global_position, {"radius": radius_value, "duration": 0.4, "color": Color("8db8ff")}))
	for enemy in arena.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and player.global_position.distance_to(enemy.global_position) <= radius_value + enemy.hit_radius:
			enemy.take_damage(make_player_damage_event(damage, player.global_position.direction_to(enemy.global_position), 80.0, [&"rift", &"evolved"]))


func _cast_flying_thunder_chain(stats: Dictionary) -> void:
	var targets: Array = arena.enemies.filter(func(enemy) -> bool: return is_instance_valid(enemy) and not enemy.dead)
	targets.sort_custom(func(a, b) -> bool: return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position))
	var count := mini(int(stats.get("targets", 3)), targets.size())
	for index in range(count):
		var target = targets[index]
		var radius_value := float(stats.get("radius", 118.0)) * area_multiplier()
		arena.add_effect(EffectNode.create(&"pulse", target.global_position, {"radius": radius_value, "duration": 0.28, "color": Color("69dcff")}))
		for enemy in arena.enemies.duplicate():
			if is_instance_valid(enemy) and not enemy.dead and target.global_position.distance_to(enemy.global_position) <= radius_value + enemy.hit_radius:
				enemy.take_damage(make_player_damage_event(float(stats.get("damage", 92.0)) * damage_multiplier(), target.global_position.direction_to(enemy.global_position), 95.0, [&"rasengan", &"evolved"]))
	arena.play_sfx(&"magic")


func _cast_celestial_sword_river(stats: Dictionary) -> void:
	var target = arena.nearest_enemy(player.global_position)
	if not is_instance_valid(target):
		cooldowns[&"celestial_sword_river"] = 0.25
		return
	var direction := player.global_position.direction_to(target.global_position)
	var count := int(stats.get("count", 7)) + quantity_bonus()
	for index in range(count):
		var angle := (float(index) - float(count - 1) * 0.5) * 0.12
		arena.add_projectile(CombatProjectile.create({
			"arena": arena, "owner": player, "position": player.global_position,
			"direction": direction.rotated(angle), "speed": float(stats.get("speed", 590.0)) * projectile_speed_multiplier(),
			"damage": float(stats.get("damage", 58.0)) * damage_multiplier(), "radius": 14.0,
			"pierce": int(stats.get("pierce", 6)) + projectile_pierce_bonus(), "lifetime": 3.0 * projectile_lifetime_multiplier(),
			"kind": &"sword", "homing": true, "returning": true, "bounces": 3, "knockback": 45.0,
		}))
	arena.play_sfx(&"magic")


func _cast_ten_direction_sword_realm(stats: Dictionary) -> void:
	var count := int(stats.get("count", 10))
	for index in range(count):
		_spawn_wave(Vector2.from_angle(TAU * float(index) / float(count)), stats)


func _cast_boundless_sun(stats: Dictionary) -> void:
	_cast_sun_palm(stats)
	var nearby := 0
	var radius_value := float(stats.get("radius", 205.0)) * area_multiplier()
	for enemy in arena.enemies:
		if is_instance_valid(enemy) and not enemy.dead and player.global_position.distance_to(enemy.global_position) <= radius_value + enemy.hit_radius:
			nearby += 1
	if nearby > 0:
		player.heal(minf(player.max_health * float(stats.get("heal_ratio", 0.025)) * nearby, player.max_health * 0.10))


func _cast_seven_in_seven_out(stats: Dictionary) -> void:
	player.invulnerability = maxf(player.invulnerability, float(stats.get("invulnerability", 0.55)))
	var count := int(stats.get("count", 7))
	var base_direction := player.last_direction
	var target = arena.nearest_enemy(player.global_position)
	if is_instance_valid(target):
		base_direction = player.global_position.direction_to(target.global_position)
	for index in range(count):
		var spread := remap(float(index), 0.0, float(maxi(count - 1, 1)), -1.25, 1.25)
		_perform_dragon_spear(base_direction.rotated(spread), stats)
	player.play_attack(base_direction)
	arena.play_sfx(&"slash")


func _cast_rasengan(stats: Dictionary) -> void:
	var target: Variant = arena.nearest_enemy(player.global_position)
	if not is_instance_valid(target):
		cooldowns[&"rasengan"] = 0.25
		return
	var base_direction: Vector2 = player.global_position.direction_to(target.global_position)
	player.play_attack(base_direction)
	var count: int = int(stats.get("count", 1)) + quantity_bonus()
	for i in range(count):
		var offset: float = (float(i) - float(count - 1) * 0.5) * 0.20
		arena.add_projectile(CombatProjectile.create({
			"arena": arena,
			"owner": player,
			"position": player.global_position + base_direction * 22.0,
			"direction": base_direction.rotated(offset),
			"speed": float(stats.get("speed", 290.0)) * projectile_speed_multiplier(),
			"damage": float(stats.get("damage", 25.0)) * damage_multiplier(),
			"radius": float(stats.get("radius", 18.0)),
			"pierce": int(stats.get("pierce", 0)) + projectile_pierce_bonus(),
			"lifetime": 2.4 * projectile_lifetime_multiplier(),
			"kind": &"rasengan",
			"homing": true,
			"turn_speed": 3.8,
			"knockback": 115.0,
			"explosion_radius": float(stats.get("aoe_radius", 0.0)),
			"explosion_damage_multiplier": float(stats.get("aoe_damage", 0.0)),
			"split_count": int(stats.get("split_count", 0)),
			"split_damage_multiplier": float(stats.get("split_damage", 0.5)),
		}))
	arena.play_sfx(&"magic")


func _cast_black_slash(stats: Dictionary) -> void:
	var target: Variant = arena.nearest_enemy(player.global_position)
	var direction: Vector2 = player.last_direction
	if is_instance_valid(target):
		direction = player.global_position.direction_to(target.global_position)
	player.play_attack(direction)
	_perform_slash(direction, stats)
	if stats.get("double", false):
		_delayed_slash(direction.rotated(-0.18), stats)


func _perform_slash(direction: Vector2, stats: Dictionary) -> void:
	var radius: float = float(stats.get("range", 100.0)) * area_multiplier()
	var arc_value: float = stats.get("arc", 2.0)
	var damage: float = stats.get("damage", 10.0) * damage_multiplier() * melee_damage_multiplier()
	arena.add_effect(EffectNode.create(&"slash", player.global_position, {"direction": direction, "radius": radius, "arc": arc_value, "duration": 0.28, "color": Color("edf5ff")}))
	for enemy in arena.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var to_enemy := player.global_position.direction_to(enemy.global_position)
		if player.global_position.distance_to(enemy.global_position) <= radius + enemy.hit_radius and absf(direction.angle_to(to_enemy)) <= arc_value * 0.5:
			enemy.take_damage(make_player_damage_event(damage, to_enemy, 90.0, [&"slash"]))
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
	var count: int = int(stats.get("count", 1)) + quantity_bonus()
	for i in range(count):
		var offset := (float(i) - float(count - 1) * 0.5) * 0.16
		arena.add_projectile(CombatProjectile.create({
			"arena": arena, "owner": player, "position": player.global_position,
			"direction": base_direction.rotated(offset), "speed": float(stats.get("speed", 400.0)) * projectile_speed_multiplier(),
			"damage": float(stats.get("damage", 15.0)) * damage_multiplier(), "radius": 13.0,
			"pierce": int(stats.get("pierce", 1)) + projectile_pierce_bonus(), "lifetime": 2.1 * projectile_lifetime_multiplier(), "kind": &"sword",
			"homing": true, "returning": stats.get("returning", false), "knockback": 42.0,
			"bounces": int(stats.get("bounces", 0)),
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
		"direction": direction, "speed": float(stats.get("speed", 450.0)) * projectile_speed_multiplier(),
		"damage": float(stats.get("damage", 22.0)) * damage_multiplier(),
		"radius": float(stats.get("width", 24.0)), "pierce": int(stats.get("pierce", 4)) + projectile_pierce_bonus(),
		"lifetime": 2.0 * projectile_lifetime_multiplier(), "kind": &"wave", "knockback": 70.0,
		"bounces": int(stats.get("bounces", 0)),
	}))
	player.play_attack(direction)
	arena.play_sfx(&"slash")


func _cast_orbit(stats: Dictionary) -> void:
	var damage: float = float(stats.get("damage", 7.0)) * damage_multiplier()
	var hit_radius: float = float(stats.get("hit_radius", 31.0)) * area_multiplier()
	for tornado_position in _orbit_positions(stats):
		for enemy in arena.enemies.duplicate():
			if is_instance_valid(enemy) and not enemy.dead and tornado_position.distance_to(enemy.global_position) < hit_radius + enemy.hit_radius:
				enemy.take_damage(make_player_damage_event(damage, tornado_position.direction_to(enemy.global_position), 38.0, [&"tornado", &"orbit"]))


func _orbit_positions(stats: Dictionary) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var outer_count: int = stats.get("count", 1)
	var inner_count: int = stats.get("inner_count", 0)
	var radius_value: float = float(stats.get("radius", 78.0)) * area_multiplier()
	for i in range(outer_count):
		positions.append(player.global_position + Vector2.from_angle(orbit_angle + TAU * float(i) / float(outer_count)) * radius_value)
	for i in range(inner_count):
		positions.append(player.global_position + Vector2.from_angle(-orbit_angle * 1.35 + TAU * float(i) / float(inner_count)) * radius_value * 0.58)
	return positions


func _update_orbit_visuals(stats: Dictionary) -> void:
	var outer_count: int = stats.get("count", 1)
	var inner_count: int = stats.get("inner_count", 0)
	var total_count := outer_count + inner_count
	while orbit_visuals.size() < total_count:
		var tornado := Sprite2D.new()
		tornado.texture = DRAGON_TORNADO_TEXTURE
		tornado.hframes = 6
		tornado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tornado.z_index = 7
		add_child(tornado)
		orbit_visuals.append(tornado)
	while orbit_visuals.size() > total_count:
		var removed: Sprite2D = orbit_visuals.pop_back()
		removed.queue_free()
	var positions := _orbit_positions(stats)
	for i in range(orbit_visuals.size()):
		var tornado := orbit_visuals[i]
		tornado.global_position = positions[i]
		tornado.frame = (int(orbit_animation_time) + i * 2) % 6
		tornado.scale = Vector2.ONE * (0.88 if i >= outer_count else 1.0)
		tornado.modulate = Color(0.88, 1.0, 1.0, 0.94)


func _clear_orbit_visuals() -> void:
	for tornado in orbit_visuals:
		if is_instance_valid(tornado):
			tornado.queue_free()
	orbit_visuals.clear()


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
			current.take_damage(make_player_damage_event(float(stats.get("damage", 24.0)) * damage_multiplier(), line.normalized(), 35.0, [&"lightning"]))
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
	var radius_value: float = float(stats.get("radius", 100.0)) * area_multiplier()
	var duration_value: float = float(stats.get("duration", 2.0)) * status_duration_multiplier()
	arena.add_effect(EffectNode.create(&"frost", center, {"radius": radius_value, "duration": duration_value, "color": Color("7edbff"), "z": 3}))
	for enemy in arena.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and center.distance_to(enemy.global_position) <= radius_value + enemy.hit_radius:
			enemy.take_damage(make_player_damage_event(float(stats.get("damage", 15.0)) * damage_multiplier(), center.direction_to(enemy.global_position), 22.0, [&"frost"]))
			enemy.apply_slow(stats.get("slow", 0.65), duration_value, stats.get("freeze", false))
	arena.play_sfx(&"magic")


func _cast_sun_palm(stats: Dictionary) -> void:
	_perform_palm(stats, 1.0)
	if stats.get("double", false):
		_delayed_palm(stats)


func _perform_palm(stats: Dictionary, scale_value: float) -> void:
	var radius_value: float = float(stats.get("radius", 100.0)) * scale_value * area_multiplier()
	arena.add_effect(EffectNode.create(&"pulse", player.global_position, {"radius": radius_value, "duration": 0.45, "color": Color("ff984c")}))
	for enemy in arena.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and player.global_position.distance_to(enemy.global_position) <= radius_value + enemy.hit_radius:
			var direction := player.global_position.direction_to(enemy.global_position)
			enemy.take_damage(make_player_damage_event(float(stats.get("damage", 18.0)) * damage_multiplier(), direction, float(stats.get("knockback", 130.0)), [&"palm"]))
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
	var radius_value: float = float(stats.get("radius", 110.0)) * area_multiplier()
	arena.telegraph_circle(center, radius_value, 0.48, Color("bfa9ff"))
	_resolve_sword_rain(center, stats)


func _resolve_sword_rain(center: Vector2, stats: Dictionary) -> void:
	await get_tree().create_timer(0.48).timeout
	if not arena.run_active:
		return
	var targets: Array = []
	for enemy in arena.enemies:
		if is_instance_valid(enemy) and not enemy.dead and center.distance_to(enemy.global_position) <= float(stats.get("radius", 110.0)) * area_multiplier() + enemy.hit_radius:
			targets.append(enemy)
	targets.shuffle()
	var count: int = int(stats.get("count", 5)) + quantity_bonus()
	for i in range(mini(count, targets.size())):
		var enemy = targets[i]
		arena.add_effect(EffectNode.create(&"sword", enemy.global_position + Vector2(0, -22), {"duration": 0.38, "color": Color("d8c9ff")}))
		enemy.take_damage(make_player_damage_event(float(stats.get("damage", 18.0)) * damage_multiplier(), Vector2.DOWN, 40.0, [&"sword_rain"]))
	if stats.get("giant", false):
		arena.add_effect(EffectNode.create(&"sword", center + Vector2(0, -30), {"duration": 0.62, "color": Color("fff2cf")}))
		for enemy in targets:
			if is_instance_valid(enemy):
				enemy.take_damage(make_player_damage_event(float(stats.get("damage", 18.0)) * 0.55 * damage_multiplier(), center.direction_to(enemy.global_position), 70.0, [&"giant_sword"]))
	arena.play_sfx(&"slash")


func _cast_dragon_spear(stats: Dictionary) -> void:
	var target: Variant = arena.nearest_enemy(player.global_position)
	if not is_instance_valid(target):
		cooldowns[&"dragon_spear"] = 0.2
		return
	var direction := player.global_position.direction_to(target.global_position)
	dragon_spear_casts += 1
	player.play_attack(direction)
	_perform_dragon_spear(direction, stats)
	if stats.get("triple", false):
		_delayed_dragon_spear(direction.rotated(-0.17), stats, 0.10)
		_delayed_dragon_spear(direction.rotated(0.17), stats, 0.20)
	elif int(stats.get("side_every", 0)) > 0 and dragon_spear_casts % int(stats.get("side_every", 1)) == 0:
		_delayed_dragon_spear(direction.rotated(0.28), stats, 0.12)
	arena.play_sfx(&"slash")


func _perform_dragon_spear(direction: Vector2, stats: Dictionary) -> int:
	var length: float = float(stats.get("distance", 150.0)) * area_multiplier()
	var width: float = float(stats.get("width", 22.0)) * area_multiplier()
	var damage: float = float(stats.get("damage", 20.0)) * damage_multiplier() * melee_damage_multiplier()
	var max_targets: int = int(stats.get("pierce", 3))
	arena.add_effect(EffectNode.create(&"spear", player.global_position, {
		"direction": direction,
		"line_end": direction.normalized() * length,
		"radius": width,
		"duration": 0.24,
		"color": Color("b9e5ff"),
	}))
	var candidates: Array = []
	for enemy in arena.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var offset: Vector2 = enemy.global_position - player.global_position
		var forward := offset.dot(direction)
		var side_distance := absf(offset.cross(direction))
		if forward >= 0.0 and forward <= length + enemy.hit_radius and side_distance <= width * 0.5 + enemy.hit_radius:
			candidates.append({"enemy": enemy, "forward": forward})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["forward"]) < float(b["forward"]))
	var hit_count := 0
	for candidate in candidates:
		var enemy = candidate["enemy"]
		enemy.take_damage(make_player_damage_event(damage, direction, 105.0, [&"dragon_spear", &"melee"]))
		hit_count += 1
		if hit_count >= max_targets:
			break
	return hit_count


func _delayed_dragon_spear(direction: Vector2, stats: Dictionary, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(player) and arena.run_active:
		_perform_dragon_spear(direction, stats)
