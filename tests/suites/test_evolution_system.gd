class_name EvolutionSystemTestSuite
extends RefCounted

var suite_name: StringName = &"evolution_system"


func run(tree: SceneTree, context: RefCounted) -> void:
	var recipes := ContentDatabase.all_evolutions()
	context.check(recipes.size() == 10, "ContentDatabase 提供十套进阶配方")
	var active_ids := {}
	var evolved_ids := {}
	for value in recipes.values():
		var recipe := value as EvolutionRecipe
		var active := ContentDatabase.skill(recipe.active_skill_id)
		var passive := ContentDatabase.skill(recipe.passive_skill_id)
		var evolved := ContentDatabase.skill(recipe.evolved_skill_id)
		context.check(active != null and active.skill_type == SkillDefinition.SkillType.ACTIVE, "%s 引用有效主动" % recipe.id)
		context.check(passive != null and passive.skill_type == SkillDefinition.SkillType.PASSIVE, "%s 引用有效心法" % recipe.id)
		context.check(evolved != null and evolved.skill_type == SkillDefinition.SkillType.EVOLVED and evolved.max_level == 1, "%s 引用一级进阶技能" % recipe.id)
		active_ids[recipe.active_skill_id] = true
		evolved_ids[recipe.evolved_skill_id] = true
	context.check(active_ids.size() == 10 and evolved_ids.size() == 10, "十个主动与十个进阶技能保持一一对应")
	context.check(ContentDatabase.evolution_for_active(&"dragon_spear").evolved_skill_id == &"seven_in_seven_out", "龙胆枪按稳定 ID 进阶为七进七出")

	var inventory := SkillInventory.new()
	inventory.setup(ContentDatabase.all_skills(), 7)
	var black_recipe := ContentDatabase.evolution_for_active(&"black_slash")
	inventory.upgrade(&"black_slash")
	for _rank in range(4):
		inventory.upgrade(&"black_slash")
	context.check(not inventory.can_evolve(black_recipe), "主动五级但没有对应心法时不能进阶")
	inventory.upgrade(&"tempered_edge")
	context.check(inventory.can_evolve(black_recipe), "五级主动加一级对应心法即可进阶")
	var slot_index := inventory.active_ids.find(&"black_slash")
	var evolution_result := inventory.apply_evolution(black_recipe)
	context.check(evolution_result.success and inventory.active_ids[slot_index] == &"nightfall_unbound", "进阶在原主动槽位完成替换")
	context.check(inventory.level_of(&"nightfall_unbound") == 1 and inventory.level_of(&"tempered_edge") == 1, "进阶技能固定一级且对应心法保留")
	context.check(not inventory.can_evolve(black_recipe), "同一主动不能重复进阶")

	var battle_scene := load("res://scenes/gameplay/battle_arena.tscn") as PackedScene
	var arena := battle_scene.instantiate() as Arena
	tree.root.add_child(arena)
	await tree.process_frame
	await tree.process_frame
	arena.spawn_timer = 9999.0
	var first_chest := arena.evolution_system.spawn_chest(arena.player.global_position + Vector2(100, 0))
	context.check(first_chest != null and not first_chest.available, "无合法配方时宝匣永久保留并显示锁定")
	context.check(not arena.evolution_system.request_open(first_chest.chest_id) and arena.evolution_system.chests.has(first_chest.chest_id), "锁定宝匣不会被误消耗")
	var pairs := [
		[&"black_slash", &"tempered_edge"],
		[&"rasengan", &"spacetime_formula"],
		[&"flying_sword", &"sword_control"],
		[&"dragon_spear", &"battlefield_tactics"],
	]
	for pair in pairs:
		for _rank in range(5):
			arena.skill_controller.upgrade(pair[0])
		arena.skill_controller.upgrade(pair[1])
	context.check(first_chest.available and arena.evolution_system.legal_recipes().size() == 4, "技能条件后来满足时旧宝匣自动解锁")
	var second_chest := arena.evolution_system.spawn_chest(arena.player.global_position + Vector2(0, 100))
	var third_chest := arena.evolution_system.spawn_chest(arena.player.global_position + Vector2(-100, 0))
	context.check(second_chest != null and third_chest != null and arena.evolution_system.spawn_chest(Vector2.ZERO) == null, "每局最多生成三个悟道宝匣")
	var emitted_holder := [[]]
	arena.evolution_system.evolution_available.connect(func(_chest_id: StringName, options: Array[EvolutionRecipe]) -> void: emitted_holder[0] = options)
	context.check(arena.evolution_system.request_open(first_chest.chest_id), "有合法进阶时宝匣可以开启")
	context.check((emitted_holder[0] as Array).size() == 3, "多个合法进阶时宝匣最多提供三选一")
	arena.skill_controller.cooldowns[&"black_slash"] = 0.37
	var first_result := arena.evolution_system.apply_evolution(first_chest.chest_id, &"nightfall_unbound")
	context.check(first_result.success and is_equal_approx(arena.skill_controller.cooldowns.get(&"nightfall_unbound", 0.0), 0.37), "进阶替换技能并继承原冷却进度")
	context.check(not arena.evolution_system.apply_evolution(first_chest.chest_id, &"nightfall_unbound").success, "同一宝匣只允许成功消费一次")
	var second_result := arena.evolution_system.apply_evolution(second_chest.chest_id, &"flying_thunder_chain")
	var third_result := arena.evolution_system.apply_evolution(third_chest.chest_id, &"seven_in_seven_out")
	context.check(second_result.success and third_result.success and arena.evolution_system.consumed_count == 3, "三个宝匣可形成三套不同进阶")
	context.check(arena.evolution_system.chests.is_empty() and arena.evolution_system.spawn_chest(Vector2.ZERO) == null, "三次进阶后本局上限永久生效")
	arena.skill_controller._cast_skill(&"seven_in_seven_out")
	context.check(arena.player.invulnerability >= 0.54, "七进七出发动瞬间实际提供短暂无敌")
	var result := arena._build_run_result(false)
	context.check(result.evolved_skill_ids.size() == 3 and &"seven_in_seven_out" in result.evolved_skill_ids, "RunResult 记录本局进阶技能用于结算与解锁")
	arena.queue_free()
	await tree.process_frame

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main._start_game()
	await tree.process_frame
	await main._qa_prepare_evolutions()
	var qa_chest_id: StringName = main.arena.evolution_system.chests.keys()[0]
	main.arena.evolution_system.request_open(qa_chest_id)
	await tree.process_frame
	context.check(tree.paused and main.evolving and main.evolution_options.size() == 3, "进阶三选一打开时暂停完整战斗")
	main._choose_evolution(0)
	await tree.process_frame
	context.check(not tree.paused and not main.evolving and main.arena.evolution_system.consumed_count == 1, "选择进阶后消费宝匣并恢复战斗")
	context.check(main.chest_label.text == "悟道宝匣 2", "HUD 显示剩余未开启宝匣数量")
	main.queue_free()
	tree.paused = false
	await tree.process_frame
