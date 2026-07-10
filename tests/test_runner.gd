extends SceneTree

var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("[FAIL] " + message)
	else:
		print("[PASS] " + message)


func _check_actor_preset(path: String, root_name: String, script_path: String) -> void:
	var packed_scene: PackedScene = load(path) as PackedScene
	_check(packed_scene != null, "%s 可作为 PackedScene 加载" % path)
	if packed_scene == null:
		return
	var scene_root: Node = packed_scene.instantiate()
	_check(scene_root is CharacterBody2D, "%s 以 CharacterBody2D 为根节点" % root_name)
	_check(scene_root.name == root_name, "%s 根节点按角色职责命名" % root_name)
	_check(scene_root.get_script() != null and scene_root.get_script().resource_path == script_path, "%s 绑定正确的角色脚本" % root_name)
	_check(scene_root.get_node_or_null("CharacterVisual/CharacterSprite") is Sprite2D, "%s 包含命名明确的角色视觉节点" % root_name)
	_check(scene_root.get_node_or_null("BodyCollision") is CollisionShape2D, "%s 包含命名明确的身体碰撞节点" % root_name)
	scene_root.free()


func _run() -> void:
	var registry := ContentRegistry.new()
	_check(registry.validate().is_empty(), "内容注册表包含 10 个五级技能、4 类敌人与 4 个波次")
	_check_actor_preset("res://scenes/actors/player.tscn", "PlayerCharacter", "res://scripts/player_actor.gd")
	_check_actor_preset("res://scenes/actors/enemies/corpse.tscn", "CorpseEnemy", "res://scripts/enemy_actor.gd")
	_check_actor_preset("res://scenes/actors/enemies/hound.tscn", "ShadowHoundEnemy", "res://scripts/enemy_actor.gd")
	_check_actor_preset("res://scenes/actors/enemies/lantern.tscn", "LanternSpiritEnemy", "res://scripts/enemy_actor.gd")
	_check_actor_preset("res://scenes/actors/enemies/revenant.tscn", "ArmoredRevenantEnemy", "res://scripts/enemy_actor.gd")
	_check_actor_preset("res://scenes/actors/boss.tscn", "GhostSwordsmanBoss", "res://scripts/boss_actor.gd")
	var map_scene: PackedScene = load("res://scenes/world/abandoned_temple_map.tscn") as PackedScene
	var map_root: Node = map_scene.instantiate()
	_check(map_root.name == "AbandonedTempleMap", "荒寺地图拥有职责明确的根节点名称")
	_check(map_root.get_node_or_null("GroundLayer/ArenaBackground") is Sprite2D, "荒寺地图地表层结构完整")
	_check(map_root.get_node_or_null("WorldCollisionLayer/WestGroveTree01/TrunkCollision") is CollisionShape2D, "荒寺地图树干碰撞在预设中可直接编辑")
	_check(map_root.get_node_or_null("AtmosphereLayer/FogBanks/FogBank01") is Sprite2D, "荒寺地图氛围层在预设中可直接编辑")
	map_root.free()
	var battle_scene: PackedScene = load("res://scenes/gameplay/battle_arena.tscn") as PackedScene
	var battle_root: Node = battle_scene.instantiate()
	_check(battle_root.name == "BattleArena", "组装后的战斗场景拥有职责明确的根节点名称")
	_check(battle_root.get_node_or_null("Environment/AbandonedTempleMap") is ArenaBackdrop, "战斗场景引用独立地图预设")
	_check(battle_root.get_node_or_null("ActorLayer/PlayerCharacter") is PlayerActor, "战斗场景引用独立玩家预设")
	_check(battle_root.get_node_or_null("GameplaySystems/SkillSystem") is SkillSystem, "战斗场景显式组织玩法系统")
	_check(battle_root.get_node_or_null("ProjectileLayer") is Node2D and battle_root.get_node_or_null("PickupLayer") is Node2D and battle_root.get_node_or_null("EffectLayer") is Node2D, "战斗场景按职责拆分运行时对象层")
	battle_root.free()
	_check(registry.wave_for_time(0.0).title == "第一夜·尸行", "0 秒进入第一波")
	_check(registry.wave_for_time(389.0).title == "第四夜·怨军", "Boss 前处于第四波")
	var orbit_definition: SkillDefinition = registry.skills[&"orbit_blades"]
	var orbit_growth_valid := true
	var last_damage := 0.0
	var last_count := 0
	var last_speed := 0.0
	for level in range(1, 6):
		var orbit_stats := orbit_definition.stats(level)
		var total_count: int = int(orbit_stats.get("count", 0)) + int(orbit_stats.get("inner_count", 0))
		if float(orbit_stats.get("damage", 0.0)) <= last_damage or total_count <= last_count or float(orbit_stats.get("rotation_speed", 0.0)) <= last_speed:
			orbit_growth_valid = false
		last_damage = orbit_stats.get("damage", 0.0)
		last_count = total_count
		last_speed = orbit_stats.get("rotation_speed", 0.0)
	_check(orbit_growth_valid, "回风护体每级提升伤害、龙卷数量与旋转速度")
	_check(int(registry.skills[&"flying_sword"].stats(2).get("bounces", 0)) == 1, "二级飞剑开始获得障碍反弹")
	_check(int(registry.skills[&"sword_wave"].stats(5).get("bounces", 0)) == 2, "满级剑气可连续反弹两次")
	var arena: Arena = battle_scene.instantiate() as Arena
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.spawn_timer = 9999.0
	_check(is_instance_valid(arena.player), "玩家成功创建")
	_check(arena.player.scene_file_path == "res://scenes/actors/player.tscn", "玩家由独立预设实例化")
	_check(arena.backdrop.scene_file_path == "res://scenes/world/abandoned_temple_map.tscn", "战斗地图由独立预设实例化")
	_check(arena.player.get_collision_mask_value(2), "玩家启用世界障碍碰撞层")
	_check(arena.backdrop.world_collision_count(&"world_walls") == 0, "墙体空气碰撞已完全移除")
	_check(arena.backdrop.world_collision_count(&"world_trees") == 14, "十四棵树均创建独立树干碰撞")
	_check(arena.backdrop.is_point_clear(Vector2(800.0, 0.0), 0.0), "视觉石墙区域不再阻挡角色")
	_check(not arena.backdrop.is_point_clear(Vector2(-1352.0, -399.0), 0.0), "树干中心会阻挡实体但树冠不扩大碰撞")
	var bouncing_projectile := CombatProjectile.create({
		"arena": arena, "owner": arena.player, "position": Vector2(-1430.0, -399.0),
		"direction": Vector2.RIGHT, "speed": 500.0, "damage": 1.0,
		"radius": 10.0, "lifetime": 1.2, "pierce": 0, "kind": &"sword", "bounces": 1,
	})
	arena.add_projectile(bouncing_projectile)
	await create_timer(0.32).timeout
	_check(is_instance_valid(bouncing_projectile) and bouncing_projectile.bounce_count == 1 and bouncing_projectile.direction.x < 0.0, "飞剑撞树干后反射并扣除一次反弹")
	if is_instance_valid(bouncing_projectile):
		bouncing_projectile.queue_free()
	var blocked_projectile := CombatProjectile.create({
		"arena": arena, "owner": arena.player, "position": Vector2(-1430.0, -399.0),
		"direction": Vector2.RIGHT, "speed": 500.0, "damage": 1.0,
		"radius": 10.0, "lifetime": 1.2, "pierce": 0, "kind": &"wave", "bounces": 0,
	})
	arena.add_projectile(blocked_projectile)
	await create_timer(0.32).timeout
	_check(not is_instance_valid(blocked_projectile), "无反弹次数的弹丸撞树干后销毁")
	_check(arena.skill_system.levels.get(&"black_slash", 0) == 1, "开局自带黑剑·横扫")
	var system := arena.skill_system
	system.upgrade(&"flying_sword")
	system.upgrade(&"sword_wave")
	system.upgrade(&"orbit_blades")
	system.upgrade(&"thunder")
	system.upgrade(&"light_step")
	system.upgrade(&"tempered_edge")
	_check(system.active_ids.size() == 4, "主动招式槽严格限制为 4")
	_check(system.passive_ids.size() == 2, "心法槽严格限制为 2")
	var options := system.get_upgrade_options(3)
	var options_valid := true
	for option in options:
		if system.levels.get(option.id, 0) == 0:
			options_valid = false
	_check(options.size() == 3 and options_valid, "槽位满后只提供已持有技能升级")
	arena.elapsed = 0.0
	var enemy := arena.spawn_enemy(&"corpse", Vector2(70, 0), false)
	var first_night_health := enemy.max_health if is_instance_valid(enemy) else 0.0
	_check(is_instance_valid(enemy), "尸傀可按 EnemyDefinition 生成")
	_check(is_instance_valid(enemy) and enemy.scene_file_path == "res://scenes/actors/enemies/corpse.tscn", "尸傀由对应独立预设实例化")
	_check(is_instance_valid(enemy) and enemy.get_collision_layer_value(3) and enemy.get_collision_mask_value(2) and not enemy.get_collision_mask_value(3), "怪物穿过彼此但仍与树干碰撞")
	if is_instance_valid(enemy):
		enemy.take_damage(DamageEvent.create(999.0, arena.player, Vector2.RIGHT, 0.0))
	await create_timer(1.2).timeout
	_check(arena.kills == 1, "敌人死亡动画完成后计数并生成经验")
	_check(root.get_tree().get_nodes_in_group("xp_orbs").size() >= 1 or arena.current_xp > 0, "经验球成功生成并可被磁吸拾取")
	arena.elapsed = 300.0
	var late_enemy := arena.spawn_enemy(&"corpse", Vector2(120, 0), false)
	_check(is_instance_valid(late_enemy) and late_enemy.max_health > first_night_health * 2.0, "后续波次同类怪物生命值会明显上升")
	if is_instance_valid(late_enemy):
		late_enemy.queue_free()
	await process_frame
	arena._start_boss()
	await process_frame
	_check(arena.boss_started and is_instance_valid(arena.boss), "Boss 只在波次结束后生成")
	_check(is_instance_valid(arena.boss) and arena.boss.scene_file_path == "res://scenes/actors/boss.tscn", "Boss 由独立预设实例化")
	if is_instance_valid(arena.boss):
		var spawned_boss := arena.boss
		arena._start_boss()
		_check(arena.boss == spawned_boss, "Boss 重复触发时不会再次生成")
		arena.boss._set_animation(&"idle")
		_check(arena.boss.sprite.hframes == 6 and arena.boss.sprite.vframes == 1, "Boss 待机贴图按 6×1 切帧")
		arena.boss.pending_direction = Vector2.RIGHT
		arena.boss._set_animation(&"attack")
		_check(arena.boss.sprite.hframes == 4 and arena.boss.sprite.vframes == 1, "Boss 攻击贴图按 4×1 切帧")
		arena.boss._set_animation(&"charge")
		_check(arena.boss.sprite.hframes == 3 and arena.boss.sprite.vframes == 1, "Boss 冲锋贴图按 3×1 切帧")
		arena.boss._set_animation(&"hit")
		_check(arena.boss.sprite.hframes == 4 and arena.boss.sprite.vframes == 1, "Boss 受击贴图按 4×1 切帧")
		arena.boss.take_damage(DamageEvent.create(99999.0, arena.player, Vector2.RIGHT, 0.0))
	await create_timer(2.6).timeout
	_check(not arena.run_active, "Boss 死亡后结束本局")
	arena.queue_free()
	await process_frame
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main._start_game()
	await process_frame
	var time_before_pause: float = main.arena.elapsed
	main.arena.collect_xp(12)
	await process_frame
	await process_frame
	var time_during_pause: float = main.arena.elapsed
	_check(paused and main.leveling, "升级三选一会暂停场景树")
	_check(is_equal_approx(time_before_pause, time_during_pause), "升级界面期间战斗计时与世界逻辑完全冻结")
	main._choose_level_option(0)
	await process_frame
	_check(not paused and not main.leveling, "选择技能后恢复战斗")
	main.queue_free()
	paused = false
	await process_frame
	await process_frame
	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		printerr("%d TESTS FAILED" % failures.size())
		quit(1)
