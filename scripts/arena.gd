class_name Arena
extends Node2D

signal player_health_changed(current: float, maximum: float)
signal xp_changed(current: int, required: int, level: int)
signal stats_changed(elapsed: float, wave_title: String, kills: int)
signal skills_changed(levels: Dictionary, active_ids: Array[StringName], passive_ids: Array[StringName])
signal level_up_requested(level: int, options: Array[SkillDefinition])
signal boss_spawned(boss: BossActor)
signal boss_health_changed(current: float, maximum: float)
signal announcement(text: String, color: Color)
signal run_ended(victory: bool, elapsed: float, level: int, kills: int)
signal sfx_requested(id: StringName)
signal music_requested(id: StringName)
signal temporary_item_effects_changed(effects: Dictionary)
signal evolution_requested(chest_id: StringName, options: Array[EvolutionRecipe])

const BOSS_SPAWN_TIME := 390.0
const BOSS_SCENE: PackedScene = preload("res://scenes/actors/boss.tscn")
const MINIBOSS_SCENES: Dictionary = {
	&"bone_corpse_king": preload("res://scenes/actors/minibosses/bone_corpse_king.tscn"),
	&"red_lantern_lady": preload("res://scenes/actors/minibosses/red_lantern_lady.tscn"),
	&"iron_arm_monk": preload("res://scenes/actors/minibosses/iron_arm_monk.tscn"),
}

@onready var backdrop: ArenaBackdrop = $Environment/AbandonedTempleMap
@onready var actor_layer: Node2D = $ActorLayer
@onready var player_spawn_point: Marker2D = $ActorLayer/PlayerSpawnPoint
@onready var pickup_layer: Node2D = $PickupLayer
@onready var projectile_layer: Node2D = $ProjectileLayer
@onready var effect_layer: Node2D = $EffectLayer
@onready var skill_controller: SkillController = $GameplaySystems/SkillController
@onready var item_drop_system: ItemDropSystem = $GameplaySystems/ItemDropSystem
@onready var evolution_system: EvolutionSystem = $GameplaySystems/EvolutionSystem
@onready var run_controller: RunController = $GameplaySystems/RunController
@onready var wave_director: WaveDirector = $GameplaySystems/WaveDirector
@onready var spawn_director: SpawnDirector = $GameplaySystems/SpawnDirector

var skill_system: SkillController:
	get:
		return skill_controller

var bounds := Rect2(-1536.0, -864.0, 3072.0, 1728.0)
var registry := ContentRegistry.new()
var selected_character_id: StringName = &"black_sword"
var run_config: RunConfig
var last_run_result: RunResult
var player: PlayerActor
var enemies: Array = []
var run_active := true
var elapsed := 0.0
var kills := 0
var player_level := 1
var current_xp := 0
var required_xp := 11
var pending_levelups := 0
var spawn_timer := 0.25
var last_wave_title := ""
var current_wave_index := 0
var boss_started := false
var boss: BossActor
var miniboss: MinibossActor
var projectile_count := 0
var rng := RandomNumberGenerator.new()
var temporary_item_effects: Dictionary = {}
var item_effect_emit_timer := 0.0


func _ready() -> void:
	rng.randomize()
	if run_config == null:
		run_config = RunConfig.default_for_character(selected_character_id)
	else:
		selected_character_id = run_config.character_id
	backdrop.setup(bounds)
	var character_definition := ContentDatabase.character(selected_character_id)
	if character_definition == null:
		selected_character_id = &"black_sword"
		character_definition = ContentDatabase.character(selected_character_id)
	var player_scene: PackedScene = character_definition.actor_scene
	player = player_scene.instantiate() as PlayerActor
	actor_layer.add_child(player)
	player.global_position = player_spawn_point.global_position
	player.setup(self)
	player.apply_run_config(run_config)
	player.health_changed.connect(func(current: float, maximum: float) -> void: player_health_changed.emit(current, maximum))
	player.died.connect(_on_player_death)
	item_drop_system.setup(self, ContentDatabase.all_items())
	skill_controller.setup(self, player, registry.skills, player.initial_skill_id)
	skill_controller.skills_changed.connect(func(levels: Dictionary, active: Array[StringName], passive: Array[StringName]) -> void: skills_changed.emit(levels, active, passive))
	evolution_system.setup(self, skill_controller, ContentDatabase.all_evolutions())
	evolution_system.evolution_available.connect(func(chest_id: StringName, options: Array[EvolutionRecipe]) -> void: evolution_requested.emit(chest_id, options))
	run_controller.setup(self)
	wave_director.setup(ContentDatabase.all_waves())
	spawn_director.setup(self)
	wave_director.wave_started.connect(_on_wave_started)
	wave_director.wave_completed.connect(_on_wave_completed)
	wave_director.rest_started.connect(_on_wave_rest_started)
	xp_changed.emit(current_xp, required_xp, player_level)
	player_health_changed.emit(player.health, player.max_health)
	music_requested.emit(&"battle")
	wave_director.start()


func _process(delta: float) -> void:
	if not run_active:
		return
	elapsed += delta
	_update_temporary_item_effects(delta)
	stats_changed.emit(elapsed, "鬼面剑豪" if boss_started else last_wave_title, kills)
	wave_director.process(delta)
	if spawn_timer < 9999.0:
		spawn_director.process(delta)


func _physics_process(delta: float) -> void:
	if run_active and is_instance_valid(skill_controller):
		skill_controller.process_skills(delta)


func spawn_enemy(id: StringName, at_position: Vector2, elite_value: Variant = false) -> EnemyActor:
	var definition := ContentDatabase.enemy(id)
	if definition == null or definition.actor_scene == null or active_enemy_count() >= 150:
		return null
	var enemy_scene: PackedScene = definition.actor_scene
	var enemy: EnemyActor = enemy_scene.instantiate() as EnemyActor
	actor_layer.add_child(enemy)
	enemy.global_position = at_position
	enemy.setup(self, definition, elite_value, enemy_health_multiplier())
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)
	return enemy


func enemy_health_multiplier() -> float:
	return clampf(0.68 + float(maxi(current_wave_index - 1, 0)) * 0.22, 0.68, 3.10)


func _on_wave_started(index: int, definition: WaveDefinition) -> void:
	current_wave_index = index
	last_wave_title = definition.title
	if definition.kind == WaveDefinition.WaveKind.NORMAL:
		item_drop_system.start_wave(index)
	spawn_director.begin_wave(definition)
	announce(definition.title, Color("d9e4ff"))


func _on_wave_completed(index: int) -> void:
	spawn_director.complete_wave()
	var definition := ContentDatabase.wave(index)
	if definition != null and definition.kind == WaveDefinition.WaveKind.NORMAL:
		item_drop_system.complete_wave(index)
	run_controller.record_wave_completed(index)


func _on_wave_rest_started(next_index: int, _duration: float) -> void:
	announce("钟息片刻 · 下一响 %d" % next_index, Color("a8c4d8"))


func summon_minions(count: int) -> void:
	var center := boss.global_position if is_instance_valid(boss) else miniboss.global_position if is_instance_valid(miniboss) else player.global_position
	summon_minions_at(center, count)


func summon_minions_at(center: Vector2, count: int) -> void:
	for i in range(count):
		var id: StringName = [&"corpse", &"hound", &"lantern"][i % 3]
		spawn_enemy(id, center + Vector2.from_angle(TAU * float(i) / float(count)) * 130.0, false)


func weighted_enemy(weights: Dictionary) -> StringName:
	var roll := rng.randf()
	var accumulated := 0.0
	for id in weights:
		accumulated += float(weights[id])
		if roll <= accumulated:
			return id
	return weights.keys().back()


func spawn_position_around_player() -> Vector2:
	var fallback := player.global_position + Vector2(420.0, 0.0)
	for _attempt in range(16):
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(460.0, 650.0)
		var position := player.global_position + Vector2.from_angle(angle) * distance
		position.x = clampf(position.x, bounds.position.x + 48.0, bounds.end.x - 48.0)
		position.y = clampf(position.y, bounds.position.y + 48.0, bounds.end.y - 48.0)
		fallback = position
		if not is_instance_valid(backdrop) or backdrop.is_point_clear(position, 34.0):
			return position
	return fallback


func _weighted_enemy(weights: Dictionary) -> StringName:
	return weighted_enemy(weights)


func _spawn_position_around_player() -> Vector2:
	return spawn_position_around_player()


func spawn_miniboss(id: StringName) -> MinibossActor:
	if not MINIBOSS_SCENES.has(id) or is_instance_valid(miniboss):
		return null
	miniboss = (MINIBOSS_SCENES[id] as PackedScene).instantiate() as MinibossActor
	actor_layer.add_child(miniboss)
	miniboss.global_position = player.global_position + Vector2(0, -330)
	miniboss.setup(self, enemy_health_multiplier())
	miniboss.defeated.connect(_on_miniboss_defeated)
	enemies.append(miniboss)
	wave_director.register_boss(miniboss.get_instance_id())
	announce("小 Boss · %s" % miniboss.display_name, Color("ffb078"))
	return miniboss


func spawn_delayed_sigil(position: Vector2, damage: float, source: Node) -> void:
	telegraph_circle(position, 72.0, 0.72, Color("c87955"))
	_resolve_delayed_sigil(position, damage, source)


func _resolve_delayed_sigil(position: Vector2, damage: float, source: Node) -> void:
	await get_tree().create_timer(0.72).timeout
	if not run_active:
		return
	add_effect(EffectNode.create(&"pulse", position, {"radius": 72.0, "duration": 0.36, "color": Color("d66a52")}))
	if is_instance_valid(player) and position.distance_to(player.global_position) <= 90.0:
		var damage_source: Node = source if is_instance_valid(source) else null
		player.take_damage(DamageEvent.create(damage, damage_source, position.direction_to(player.global_position), 95.0, false, [&"sigil"]))


func _on_miniboss_defeated(actor: MinibossActor) -> void:
	if actor != miniboss:
		return
	var instance_id := actor.get_instance_id()
	var death_position := actor.global_position
	enemies.erase(actor)
	kills += 1
	run_controller.record_miniboss_defeated()
	evolution_system.spawn_chest(death_position)
	wave_director.notify_boss_defeated(instance_id)
	miniboss = null


func _start_boss() -> void:
	if boss_started or not run_active:
		return
	boss_started = true
	var absorbed_xp := 0
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy):
			if enemy is EnemyActor and not enemy.dead:
				absorbed_xp += enemy.definition.xp_value
			enemy.queue_free()
	enemies.clear()
	if absorbed_xp > 0:
		collect_xp(absorbed_xp)
	announce("鬼门震动——鬼面剑豪现身", Color("ff6b6b"))
	boss = BOSS_SCENE.instantiate() as BossActor
	actor_layer.add_child(boss)
	boss.global_position = Vector2(0, -390)
	boss.setup(self)
	boss.health_changed.connect(func(current: float, maximum: float) -> void: boss_health_changed.emit(current, maximum))
	boss.defeated.connect(_on_boss_defeated)
	enemies.append(boss)
	boss_spawned.emit(boss)
	wave_director.register_boss(boss.get_instance_id())
	music_requested.emit(&"boss")


func _on_enemy_defeated(enemy: EnemyActor, xp_value: int, death_position: Vector2) -> void:
	enemies.erase(enemy)
	item_drop_system.on_enemy_defeated(enemy, death_position)
	kills += 1
	if get_tree().get_nodes_in_group("xp_orbs").size() < 220:
		var orb := ExperienceOrb.create(self, death_position, xp_value)
		orb.add_to_group("xp_orbs")
		pickup_layer.add_child(orb)
	else:
		collect_xp(xp_value)


func _on_boss_defeated() -> void:
	var instance_id := boss.get_instance_id()
	enemies.erase(boss)
	kills += 1
	run_controller.record_final_boss_defeated()
	wave_director.notify_boss_defeated(instance_id)
	run_active = false
	last_run_result = _build_run_result(true)
	announce("黑剑归鞘，荒寺复寂", Color("ffe6a6"))
	play_sfx(&"victory")
	await get_tree().create_timer(1.2).timeout
	run_ended.emit(true, elapsed, player_level, kills)


func _on_player_death() -> void:
	if not run_active:
		return
	run_active = false
	last_run_result = _build_run_result(false)
	play_sfx(&"game_over")
	await get_tree().create_timer(0.45).timeout
	run_ended.emit(false, elapsed, player_level, kills)


func collect_xp(amount: int) -> void:
	if not run_active:
		return
	current_xp += maxi(1, roundi(float(amount) * run_config.experience_multiplier))
	var gained := 0
	while current_xp >= required_xp:
		current_xp -= required_xp
		player_level += 1
		required_xp = 8 + player_level * 3
		pending_levelups += 1
		gained += 1
	xp_changed.emit(current_xp, required_xp, player_level)
	if gained > 0 and pending_levelups == gained:
		_request_next_levelup()


func complete_levelup() -> void:
	pending_levelups = maxi(pending_levelups - 1, 0)
	if pending_levelups > 0:
		call_deferred("_request_next_levelup")


func _request_next_levelup() -> void:
	var options := skill_controller.get_upgrade_options(3)
	if OS.is_debug_build() and get_meta("qa_auto_level", false) and not options.is_empty():
		skill_controller.upgrade(options[0].id)
		complete_levelup()
		return
	if options.is_empty():
		player.heal(12.0)
		complete_levelup()
		return
	level_up_requested.emit(player_level, options)


func choose_upgrade(id: StringName) -> void:
	var result := skill_controller.upgrade(id)
	if result.success and not result.recovered_health:
		player.heal(3.0)
	complete_levelup()


func choose_evolution(chest_id: StringName, evolved_skill_id: StringName) -> SkillUpgradeResult:
	return evolution_system.apply_evolution(chest_id, evolved_skill_id)


func finish_run_as_failure() -> void:
	if not run_active:
		return
	run_active = false
	last_run_result = _build_run_result(false)
	run_ended.emit(false, elapsed, player_level, kills)


func clear_nearby_for_revive(center: Vector2, radius: float = 180.0) -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or center.distance_to(enemy.global_position) > radius:
			continue
		if enemy.is_in_group("boss"):
			enemy.knockback_velocity += center.direction_to(enemy.global_position) * 260.0
			continue
		enemies.erase(enemy)
		enemy.queue_free()


func _build_run_result(victory: bool) -> RunResult:
	return run_controller.build_result(victory)


func nearest_enemy(from_position: Vector2):
	var nearest = null
	var best_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var distance := from_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = enemy
	return nearest


func densest_enemy(from_position: Vector2, max_distance: float):
	var candidates: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and from_position.distance_to(enemy.global_position) <= max_distance:
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	var best = candidates[0]
	var best_count := 0
	for candidate in candidates.slice(0, mini(24, candidates.size())):
		var count := 0
		for other in candidates:
			if candidate.global_position.distance_squared_to(other.global_position) < 145.0 * 145.0:
				count += 1
		if count > best_count:
			best_count = count
			best = candidate
	return best


func active_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count


func add_effect(effect: EffectNode) -> void:
	effect_layer.add_child(effect)


func add_projectile(projectile: CombatProjectile) -> void:
	if get_tree().get_nodes_in_group("projectiles").size() >= 200:
		return
	projectile.add_to_group("projectiles")
	projectile_layer.add_child(projectile)


func spawn_enemy_projectile(position: Vector2, direction: Vector2, damage: float, owner_node: Node, speed: float = 250.0) -> void:
	add_projectile(CombatProjectile.create({
		"arena": self, "owner": owner_node, "position": position, "direction": direction,
		"speed": speed, "damage": damage, "radius": 11.0, "lifetime": 3.2,
		"kind": &"orb", "hostile": true, "knockback": 90.0,
	}))


func show_damage(position: Vector2, amount: float, color: Color, critical: bool = false) -> void:
	add_effect(EffectNode.create(&"damage_text", position, {"text": "%s%d" % ["!" if critical else "", roundi(amount)], "duration": 0.65, "color": color, "z": 40}))


func telegraph_circle(position: Vector2, radius: float, duration: float, color: Color = Color("ff485e")) -> void:
	add_effect(EffectNode.create(&"warning_circle", position, {"radius": radius, "duration": duration, "color": color, "z": 4}))


func telegraph_line(position: Vector2, direction: Vector2, width: float, length: float, duration: float) -> void:
	add_effect(EffectNode.create(&"warning_line", position, {"direction": direction, "radius": width, "line_end": direction.normalized() * length, "duration": duration, "color": Color("ff485e"), "z": 4}))


func telegraph_cone(position: Vector2, direction: Vector2, radius: float, arc: float, duration: float) -> void:
	add_effect(EffectNode.create(&"warning_cone", position, {"direction": direction, "radius": radius, "arc": arc, "duration": duration, "color": Color("ff485e"), "z": 4}))


func announce(text: String, color: Color = Color.WHITE) -> void:
	announcement.emit(text, color)


func play_sfx(id: StringName) -> void:
	sfx_requested.emit(id)


func activate_temporary_item_effect(id: StringName, values: Dictionary) -> void:
	var duration := float(values.get("duration", 0.0))
	if duration <= 0.0:
		return
	temporary_item_effects[id] = {
		"remaining": duration,
		"duration": duration,
		"damage": float(values.get("damage", 0.0)),
		"cooldown_reduction": float(values.get("cooldown_reduction", 0.0)),
	}
	temporary_item_effects_changed.emit(temporary_item_effects.duplicate(true))


func temporary_item_damage_multiplier() -> float:
	var multiplier := 1.0
	for effect in temporary_item_effects.values():
		multiplier += float(effect.get("damage", 0.0))
	return multiplier


func temporary_item_cooldown_multiplier() -> float:
	var reduction := 0.0
	for effect in temporary_item_effects.values():
		reduction += float(effect.get("cooldown_reduction", 0.0))
	return maxf(0.45, 1.0 - reduction)


func current_temporary_item_effects() -> Dictionary:
	return temporary_item_effects.duplicate(true)


func _update_temporary_item_effects(delta: float) -> void:
	if temporary_item_effects.is_empty():
		return
	var expired: Array[StringName] = []
	for id in temporary_item_effects:
		var effect: Dictionary = temporary_item_effects[id]
		effect["remaining"] = maxf(float(effect.get("remaining", 0.0)) - delta, 0.0)
		if effect["remaining"] <= 0.0:
			expired.append(id)
	for id in expired:
		temporary_item_effects.erase(id)
	item_effect_emit_timer -= delta
	if item_effect_emit_timer <= 0.0 or not expired.is_empty():
		item_effect_emit_timer = 0.10
		temporary_item_effects_changed.emit(temporary_item_effects.duplicate(true))
