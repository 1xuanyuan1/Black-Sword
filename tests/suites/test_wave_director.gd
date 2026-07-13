class_name WaveDirectorTestSuite
extends RefCounted

var suite_name: StringName = &"wave_director"


func run(tree: SceneTree, context: RefCounted) -> void:
	var waves := ContentDatabase.all_waves()
	context.check(waves.size() == 12, "V1 波次数据严格包含十二波")
	for index in range(12):
		context.check(waves[index].index == index + 1, "波次索引连续：%d" % (index + 1))
	for index in [3, 6, 9]:
		context.check(ContentDatabase.wave(index).kind == WaveDefinition.WaveKind.MINIBOSS and not ContentDatabase.wave(index).boss_id.is_empty(), "第 %d 波为具名小 Boss 波" % index)
	context.check(ContentDatabase.wave(12).kind == WaveDefinition.WaveKind.FINAL_BOSS and ContentDatabase.wave(12).boss_id == &"ghost_swordsman", "第十二波必须击败鬼面剑豪")
	context.check(ContentDatabase.wave(10).enemy_weights.size() == 6 and ContentDatabase.wave(11).enemy_weights.size() == 6, "第十至十一波混合全部六类普通敌人")

	var director := WaveDirector.new()
	director.setup(waves)
	director.duration_scale = 0.01
	var started: Array[int] = []
	var completed: Array[int] = []
	director.wave_started.connect(func(index: int, _definition: WaveDefinition) -> void: started.append(index))
	director.wave_completed.connect(func(index: int) -> void: completed.append(index))
	director.start()
	var boss_instance_id := 1000
	while director.state != WaveDirector.State.COMPLETED:
		if director.state == WaveDirector.State.ACTIVE:
			director.process(director.current_wave.target_duration * director.duration_scale + 0.01)
		elif director.state == WaveDirector.State.WAITING_FOR_BOSS_DEATH:
			boss_instance_id += 1
			director.register_boss(boss_instance_id)
			director.process(100.0)
			context.check(director.state == WaveDirector.State.WAITING_FOR_BOSS_DEATH, "Boss 波超时不会自动判胜：%d" % director.current_wave.index)
			context.check(not director.notify_boss_defeated(boss_instance_id + 99), "Boss 死亡实例 ID 去重：%d" % director.current_wave.index)
			context.check(director.notify_boss_defeated(boss_instance_id), "正确 Boss 死亡推进波次：%d" % director.current_wave.index)
		elif director.state == WaveDirector.State.RESTING:
			director.process(director.current_wave.rest_duration * director.duration_scale + 0.01)
	context.check(started == Array(range(1, 13)), "十二波严格按 1 到 12 顺序启动")
	context.check(completed == Array(range(1, 13)), "十二波严格按 1 到 12 顺序完成")
	director.free()

	var battle_scene := load("res://scenes/gameplay/battle_arena.tscn") as PackedScene
	var battle_root := battle_scene.instantiate() as Arena
	context.check(battle_root.get_node_or_null("GameplaySystems/RunController") is RunController, "战斗场景显式装配 RunController")
	context.check(battle_root.get_node_or_null("GameplaySystems/WaveDirector") is WaveDirector, "战斗场景显式装配 WaveDirector")
	context.check(battle_root.get_node_or_null("GameplaySystems/SpawnDirector") is SpawnDirector, "战斗场景显式装配 SpawnDirector")
	tree.root.add_child(battle_root)
	await tree.process_frame
	await tree.process_frame
	battle_root.spawn_timer = 9999.0
	var paper := battle_root.spawn_enemy(&"paper_wraith", Vector2(180, 0), false)
	var monk := battle_root.spawn_enemy(&"rogue_monk", Vector2(-180, 0), false)
	context.check(paper != null and paper.definition.behavior == &"diver" and paper.definition.tags.has(&"flying"), "纸煞使用飞行俯冲行为")
	context.check(paper != null and paper.get_collision_mask_value(2) and not paper.get_collision_mask_value(4), "纸煞只穿树干但仍受瓦片墙阻挡")
	context.check(monk != null and monk.definition.behavior == &"sigil", "破戒僧使用延迟符印行为")
	var lingering_projectile := CombatProjectile.create({"arena": battle_root, "owner": monk, "position": battle_root.player.global_position, "hostile": true, "damage": 1.0})
	battle_root.add_projectile(lingering_projectile)
	lingering_projectile.set_physics_process(false)
	if is_instance_valid(paper):
		paper.queue_free()
	if is_instance_valid(monk):
		monk.queue_free()
	await tree.process_frame
	battle_root.player.invulnerability = 0.0
	lingering_projectile._check_player_hit()
	context.check(battle_root.player.health < battle_root.player.max_health, "施法者先死亡后残留弹丸仍可安全结算")
	var base_health := ContentDatabase.enemy(&"corpse").max_health * battle_root.enemy_health_multiplier()
	var blood := battle_root.spawn_enemy(&"corpse", Vector2(120, 0), &"blood")
	var swift := battle_root.spawn_enemy(&"corpse", Vector2(-120, 0), &"swift")
	context.check(is_equal_approx(blood.max_health, base_health * 1.6) and is_equal_approx(blood.outgoing_damage_multiplier, 1.25) and blood.xp_multiplier == 2, "血煞词缀提供生命 +60%、伤害 +25% 与双倍经验")
	context.check(is_equal_approx(swift.max_health, base_health * 0.85) and is_equal_approx(swift.move_speed_multiplier, 1.35) and is_equal_approx(swift.attack_cooldown_multiplier, 0.8), "迅影词缀提供移速 +35%、冷却 -20% 与生命 -15%")
	context.check(blood.get_meta("elite_affix") == &"blood" and swift.get_meta("elite_affix") == &"swift", "同一敌人只携带一个显式精英词缀")
	if is_instance_valid(blood):
		blood.queue_free()
	if is_instance_valid(swift):
		swift.queue_free()
	await tree.process_frame
	var first_miniboss := battle_root.spawn_miniboss(&"bone_corpse_king")
	context.check(first_miniboss != null and first_miniboss.display_name == "腐骨尸王", "第三波腐骨尸王拥有独立实例")
	context.check(battle_root.spawn_miniboss(&"red_lantern_lady") == null, "同一时间只允许生成一名小 Boss")
	var chests_before := battle_root.evolution_system.chests.size()
	first_miniboss.take_damage(DamageEvent.create(999999.0, battle_root.player))
	await tree.process_frame
	context.check(battle_root.run_controller.miniboss_kills == 1 and battle_root.evolution_system.chests.size() == chests_before + 1, "小 Boss 死亡只计数一次并掉落悟道宝匣")
	var red_lady := battle_root.spawn_miniboss(&"red_lantern_lady")
	context.check(red_lady != null and red_lady.display_name == "红灯鬼姬", "第六波红灯鬼姬拥有独立实例")
	red_lady.take_damage(DamageEvent.create(999999.0, battle_root.player))
	await tree.process_frame
	var iron_monk := battle_root.spawn_miniboss(&"iron_arm_monk")
	context.check(iron_monk != null and iron_monk.display_name == "铁臂怨僧", "第九波铁臂怨僧拥有独立实例")
	iron_monk.take_damage(DamageEvent.create(999999.0, battle_root.player))
	await tree.process_frame
	context.check(battle_root.run_controller.miniboss_kills == 3 and battle_root.evolution_system.chests.size() == 3, "三名小 Boss 各提供一个且最多三个宝匣")
	battle_root.run_controller.record_wave_completed(9)
	var partial_result := battle_root._build_run_result(false)
	context.check(partial_result.completed_waves == 9 and partial_result.miniboss_kills == 3, "RunController 将波次与小 Boss 统计写入 RunResult")
	battle_root.queue_free()
	await tree.process_frame
	await tree.process_frame
