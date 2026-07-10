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


func _run() -> void:
	var registry := ContentRegistry.new()
	_check(registry.validate().is_empty(), "内容注册表包含 10 个五级技能、4 类敌人与 4 个波次")
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
	_check(int(registry.skills[&"flying_sword"].stats(2).get("bounces", 0)) == 1, "二级飞剑开始获得墙壁反弹")
	_check(int(registry.skills[&"sword_wave"].stats(5).get("bounces", 0)) == 2, "满级剑气可连续反弹两次")
	var arena := Arena.new()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.spawn_timer = 9999.0
	_check(is_instance_valid(arena.player), "玩家成功创建")
	_check(arena.player.get_collision_mask_value(2), "玩家启用世界障碍碰撞层")
	_check(arena.backdrop.world_collision_count(&"world_walls") == 6, "庭院六段墙体碰撞成功创建并保留上下入口")
	_check(arena.backdrop.world_collision_count(&"world_trees") == 14, "十四棵树均创建独立树干碰撞")
	_check(not arena.backdrop.is_point_clear(Vector2(800.0, 0.0), 0.0), "右侧石墙区域会阻挡实体")
	_check(arena.backdrop.is_point_clear(Vector2(0.0, -540.0), 10.0), "北侧院门保留可通行缺口")
	_check(not arena.backdrop.is_point_clear(Vector2(-1352.0, -399.0), 0.0), "树干中心会阻挡实体但树冠不扩大碰撞")
	var routed_direction := arena.navigation_direction(Vector2(1000.0, 0.0), Vector2.ZERO)
	_check(routed_direction.x < 0.0 and routed_direction.y < -0.1, "院外敌人会先绕向最近入口而非卡在侧墙")
	var bouncing_projectile := CombatProjectile.create({
		"arena": arena, "owner": arena.player, "position": Vector2(700.0, 0.0),
		"direction": Vector2.RIGHT, "speed": 500.0, "damage": 1.0,
		"radius": 10.0, "lifetime": 1.2, "pierce": 0, "kind": &"sword", "bounces": 1,
	})
	arena.add_projectile(bouncing_projectile)
	await create_timer(0.32).timeout
	_check(is_instance_valid(bouncing_projectile) and bouncing_projectile.bounce_count == 1 and bouncing_projectile.direction.x < 0.0, "飞剑撞墙后反射并扣除一次反弹")
	if is_instance_valid(bouncing_projectile):
		bouncing_projectile.queue_free()
	var blocked_projectile := CombatProjectile.create({
		"arena": arena, "owner": arena.player, "position": Vector2(700.0, 80.0),
		"direction": Vector2.RIGHT, "speed": 500.0, "damage": 1.0,
		"radius": 10.0, "lifetime": 1.2, "pierce": 0, "kind": &"wave", "bounces": 0,
	})
	arena.add_projectile(blocked_projectile)
	await create_timer(0.32).timeout
	_check(not is_instance_valid(blocked_projectile), "无反弹次数的弹丸撞墙后销毁")
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
