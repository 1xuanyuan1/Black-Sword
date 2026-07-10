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

const BOSS_SPAWN_TIME := 390.0
const BOSS_SCENE: PackedScene = preload("res://scenes/actors/boss.tscn")
const PLAYER_SCENES: Dictionary = {
	&"black_sword": preload("res://scenes/actors/player.tscn"),
	&"minato": preload("res://scenes/actors/player_minato.tscn"),
}
const ENEMY_SCENES: Dictionary = {
	&"corpse": preload("res://scenes/actors/enemies/corpse.tscn"),
	&"hound": preload("res://scenes/actors/enemies/hound.tscn"),
	&"lantern": preload("res://scenes/actors/enemies/lantern.tscn"),
	&"revenant": preload("res://scenes/actors/enemies/revenant.tscn"),
}

@onready var backdrop: ArenaBackdrop = $Environment/AbandonedTempleMap
@onready var actor_layer: Node2D = $ActorLayer
@onready var player_spawn_point: Marker2D = $ActorLayer/PlayerSpawnPoint
@onready var pickup_layer: Node2D = $PickupLayer
@onready var projectile_layer: Node2D = $ProjectileLayer
@onready var effect_layer: Node2D = $EffectLayer
@onready var skill_system: SkillSystem = $GameplaySystems/SkillSystem

var bounds := Rect2(-1536.0, -864.0, 3072.0, 1728.0)
var registry := ContentRegistry.new()
var selected_character_id: StringName = &"black_sword"
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
var boss_started := false
var boss: BossActor
var projectile_count := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	backdrop.setup(bounds)
	var player_scene: PackedScene = PLAYER_SCENES.get(selected_character_id, PLAYER_SCENES[&"black_sword"]) as PackedScene
	player = player_scene.instantiate() as PlayerActor
	actor_layer.add_child(player)
	player.global_position = player_spawn_point.global_position
	player.setup(self)
	player.health_changed.connect(func(current: float, maximum: float) -> void: player_health_changed.emit(current, maximum))
	player.died.connect(_on_player_death)
	skill_system.setup(self, player, registry.skills, player.initial_skill_id)
	skill_system.skills_changed.connect(func(levels: Dictionary, active: Array[StringName], passive: Array[StringName]) -> void: skills_changed.emit(levels, active, passive))
	xp_changed.emit(current_xp, required_xp, player_level)
	player_health_changed.emit(player.health, player.max_health)
	announce("第一夜·尸行", Color("d9e4ff"))
	music_requested.emit(&"battle")


func _process(delta: float) -> void:
	if not run_active:
		return
	elapsed += delta
	stats_changed.emit(elapsed, "鬼面剑豪" if boss_started else last_wave_title, kills)
	if boss_started:
		return
	if elapsed >= BOSS_SPAWN_TIME:
		_start_boss()
		return
	var wave := registry.wave_for_time(elapsed)
	if wave == null:
		return
	if wave.title != last_wave_title:
		last_wave_title = wave.title
		announce(wave.title, Color("d9e4ff"))
	spawn_timer -= delta
	if spawn_timer <= 0.0 and active_enemy_count() < wave.enemy_cap:
		spawn_timer = wave.spawn_interval * rng.randf_range(0.82, 1.16)
		spawn_enemy(_weighted_enemy(wave.enemy_weights), _spawn_position_around_player(), rng.randf() < wave.elite_chance)


func _physics_process(delta: float) -> void:
	if run_active and is_instance_valid(skill_system):
		skill_system.process_skills(delta)


func spawn_enemy(id: StringName, at_position: Vector2, is_elite: bool = false) -> EnemyActor:
	if not registry.enemies.has(id) or not ENEMY_SCENES.has(id) or active_enemy_count() >= 150:
		return null
	var enemy_scene: PackedScene = ENEMY_SCENES[id] as PackedScene
	var enemy: EnemyActor = enemy_scene.instantiate() as EnemyActor
	actor_layer.add_child(enemy)
	enemy.global_position = at_position
	enemy.setup(self, registry.enemies[id], is_elite, enemy_health_multiplier())
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)
	return enemy


func enemy_health_multiplier() -> float:
	# 每一夜提供明确的血量台阶；三分钟后进入高压阶段，第四夜继续增长。
	if elapsed < 90.0:
		# 第一夜作为构筑起步期：尸傀约 23~31 点生命，避免初始技能刮痧。
		return 0.68 + elapsed / 90.0 * 0.22
	if elapsed < 180.0:
		return 1.35 + (elapsed - 90.0) / 90.0 * 0.22
	if elapsed < 270.0:
		return 2.05 + (elapsed - 180.0) / 90.0 * 0.30
	return minf(2.65 + (elapsed - 270.0) / 120.0 * 0.55, 3.20)


func summon_minions(count: int) -> void:
	if not is_instance_valid(boss):
		return
	for i in range(count):
		var id: StringName = [&"corpse", &"hound", &"lantern"][i % 3]
		spawn_enemy(id, boss.global_position + Vector2.from_angle(TAU * float(i) / float(count)) * 130.0, false)


func _weighted_enemy(weights: Dictionary) -> StringName:
	var roll := rng.randf()
	var accumulated := 0.0
	for id in weights:
		accumulated += float(weights[id])
		if roll <= accumulated:
			return id
	return weights.keys().back()


func _spawn_position_around_player() -> Vector2:
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
	music_requested.emit(&"boss")


func _on_enemy_defeated(enemy: EnemyActor, xp_value: int, death_position: Vector2) -> void:
	enemies.erase(enemy)
	kills += 1
	if get_tree().get_nodes_in_group("xp_orbs").size() < 220:
		var orb := ExperienceOrb.create(self, death_position, xp_value)
		orb.add_to_group("xp_orbs")
		pickup_layer.add_child(orb)
	else:
		collect_xp(xp_value)


func _on_boss_defeated() -> void:
	enemies.erase(boss)
	kills += 1
	run_active = false
	announce("黑剑归鞘，荒寺复寂", Color("ffe6a6"))
	play_sfx(&"victory")
	await get_tree().create_timer(1.2).timeout
	run_ended.emit(true, elapsed, player_level, kills)


func _on_player_death() -> void:
	if not run_active:
		return
	run_active = false
	play_sfx(&"game_over")
	await get_tree().create_timer(0.45).timeout
	run_ended.emit(false, elapsed, player_level, kills)


func collect_xp(amount: int) -> void:
	if not run_active:
		return
	current_xp += amount
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
	var options := skill_system.get_upgrade_options(3)
	if options.is_empty():
		player.heal(12.0)
		complete_levelup()
		return
	level_up_requested.emit(player_level, options)


func choose_upgrade(id: StringName) -> void:
	skill_system.upgrade(id)
	player.heal(3.0)
	complete_levelup()


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
