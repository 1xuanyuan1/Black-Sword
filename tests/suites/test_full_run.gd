extends RefCounted

var suite_name: StringName = &"full_run"


func run(tree: SceneTree, context) -> void:
	_test_release_configuration(context)
	_test_balance_projection(context)
	await _test_runtime_pool(tree, context)
	await _test_accelerated_full_run(tree, context)


func _test_release_configuration(context) -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	context.check(presets.contains('name="Windows Desktop"'), "Windows Desktop 导出预设已配置")
	context.check(presets.contains('name="Web"'), "Web 导出预设保持可用")
	context.check(presets.contains("assets/items/*") == false, "发布包不会再排除正式道具图标")
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	context.check(credits.contains("Ninja Adventure Asset Pack") and credits.contains("Noto Sans SC"), "CC0 与字体许可证记录完整")
	context.check(credits.contains("仅适合本地非商业原型") and credits.contains("不得进入公开或商业发布包"), "未决角色授权被明确标记为发布阻断项")


func _test_balance_projection(context) -> void:
	var total_seconds := 0.0
	var projected_xp := 0.0
	for wave in ContentDatabase.all_waves():
		total_seconds += wave.target_duration + wave.rest_duration
		var weighted_xp := 0.0
		for enemy_id in wave.enemy_weights:
			var enemy := ContentDatabase.enemy(enemy_id)
			if enemy != null:
				weighted_xp += float(wave.enemy_weights[enemy_id]) * float(enemy.xp_value)
		projected_xp += wave.target_duration / wave.spawn_interval * weighted_xp * 0.60
	var projected_level := _level_for_xp(roundi(projected_xp))
	context.check(total_seconds >= 690.0 and total_seconds <= 780.0, "十二波基线总时长保持在 11分30秒～13分钟")
	context.check(projected_level >= 36 and projected_level <= 42, "按 60% 击杀效率估算的结算等级保持在 36～42")
	context.check(ContentDatabase.wave(10).enemy_cap == 135 and ContentDatabase.wave(11).enemy_cap == 150, "第十、十一响保留最高密度性能档")


func _level_for_xp(total_xp: int) -> int:
	var level := 1
	var required := 11
	var remaining := total_xp
	while remaining >= required:
		remaining -= required
		level += 1
		required = 8 + level * 3
	return level


func _test_runtime_pool(tree: SceneTree, context) -> void:
	var arena := (load("res://scenes/gameplay/battle_arena.tscn") as PackedScene).instantiate() as Arena
	tree.root.add_child(arena)
	await tree.process_frame
	arena.run_active = false
	context.check(arena.runtime_pool != null, "战斗场景装配高频运行时对象池")
	var projectile := arena.spawn_projectile({"position": Vector2.ZERO, "direction": Vector2.RIGHT, "lifetime": 4.0})
	var projectile_id := projectile.get_instance_id()
	projectile.retire()
	await tree.process_frame
	await tree.process_frame
	var reused := arena.spawn_projectile({"position": Vector2.ZERO, "direction": Vector2.RIGHT, "lifetime": 4.0})
	context.check(reused != null and reused.get_instance_id() == projectile_id, "投射物结束后由对象池复用同一实例")
	reused.retire()
	var orb := arena.spawn_experience_orb(Vector2.ZERO, 3)
	var orb_id := orb.get_instance_id()
	orb.retire()
	var effect := arena.spawn_effect(&"pulse", Vector2.ZERO, {"duration": 2.0})
	var effect_id := effect.get_instance_id()
	effect.retire()
	await tree.process_frame
	await tree.process_frame
	var reused_orb := arena.spawn_experience_orb(Vector2.ZERO, 4)
	var reused_effect := arena.spawn_effect(&"pulse", Vector2.ZERO, {"duration": 2.0})
	context.check(reused_orb != null and reused_orb.get_instance_id() == orb_id, "经验球结束后由对象池复用同一实例")
	context.check(reused_effect != null and reused_effect.get_instance_id() == effect_id, "短时特效结束后由对象池复用同一实例")
	for _index in range(205):
		arena.spawn_projectile({"position": Vector2.ZERO, "direction": Vector2.RIGHT, "lifetime": 4.0})
	context.check(tree.get_nodes_in_group("projectiles").size() == 200, "最高密度下活动投射物严格限制为 200")
	context.check(int(RuntimeObjectPool.POOL_LIMITS[&"projectile"]) >= 200 and int(RuntimeObjectPool.POOL_LIMITS[&"experience_orb"]) >= 220, "对象池容量覆盖正式同屏上限")
	arena.queue_free()
	await tree.process_frame


func _test_accelerated_full_run(tree: SceneTree, context) -> void:
	var arena := (load("res://scenes/gameplay/battle_arena.tscn") as PackedScene).instantiate() as Arena
	tree.root.add_child(arena)
	await tree.process_frame
	arena.player.invulnerability = 9999.0
	arena.set_meta("qa_auto_level", true)
	arena.wave_director.duration_scale = 0.001
	arena.spawn_director.qa_auto_defeat_bosses = true
	arena.spawn_director.qa_auto_defeat_delay = 0.05
	var deadline := Time.get_ticks_msec() + 12000
	while arena.run_active and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var result := arena.last_run_result
	context.check(not arena.run_active and result != null and result.victory, "加速完整跑局在超时前击败最终 Boss")
	context.check(result != null and result.completed_waves == 12, "加速完整跑局严格完成十二波")
	context.check(result != null and result.miniboss_kills == 3 and result.final_boss_kill, "加速完整跑局记录三名小 Boss 与最终 Boss")
	context.check(arena.active_enemy_count() <= 150, "完整跑局最高密度不突破敌人硬上限")
	arena.queue_free()
	await tree.process_frame
