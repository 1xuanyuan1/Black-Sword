class_name ItemSystemTestSuite
extends RefCounted

var suite_name: StringName = &"item_system"


func run(tree: SceneTree, context: RefCounted) -> void:
	_test_item_definitions(context)
	await _test_item_effects_and_drop_rules(tree, context)
	await _test_temporary_effect_hud(tree, context)


func _test_item_definitions(context: RefCounted) -> void:
	var expected_effects := {
		&"healing_salve": &"heal_ratio",
		&"soul_talisman": &"gather_experience",
		&"soul_bell": &"soul_bell",
		&"binding_talisman": &"binding_talisman",
		&"soul_wine": &"soul_wine",
	}
	context.check(ContentDatabase.all_items().size() == 5, "ContentDatabase 提供五种局内道具")
	var registry := ItemEffectRegistry.new()
	for item_id in expected_effects:
		var definition := ContentDatabase.item(item_id)
		context.check(definition != null and definition.effect_id == expected_effects[item_id] and registry.supports(definition.effect_id), "道具 %s 使用白名单效果" % item_id)
		context.check(definition != null and definition.icon != null and definition.world_scene != null and definition.base_weight > 0.0, "道具 %s 的图标、场景与权重完整" % item_id)
	context.check(is_equal_approx(float(ContentDatabase.item(&"healing_salve").effect_values.get("health_ratio")), 0.30), "金疮药恢复 30% 最大生命")
	context.check(is_equal_approx(float(ContentDatabase.item(&"soul_wine").effect_values.get("duration")), 15.0), "烈魂酒持续 15 秒")
	context.check(ItemDropSystem.MAX_ACTIVE_PICKUPS == 3 and ItemDropSystem.GUARANTEE_WAVE_STREAK == 4, "同屏上限为三个且连续四波触发保底")
	context.check(is_equal_approx(ItemDropSystem.POT_DROP_CHANCE, 0.18) and is_equal_approx(ItemDropSystem.ELITE_DROP_CHANCE, 0.12), "陶罐与精英掉落率符合 18% 和 12% 基线")


func _test_item_effects_and_drop_rules(tree: SceneTree, context: RefCounted) -> void:
	var battle_scene := load("res://scenes/gameplay/battle_arena.tscn") as PackedScene
	var arena := battle_scene.instantiate() as Arena
	arena.run_config = RunConfig.default_for_character(&"black_sword")
	tree.root.add_child(arena)
	await tree.process_frame
	arena.spawn_timer = 9999.0
	var registry := ItemEffectRegistry.new()

	arena.player.health = 10.0
	context.check(registry.apply(ContentDatabase.item(&"healing_salve"), arena), "金疮药效果可以通过白名单注册器执行")
	context.check(is_equal_approx(arena.player.health, 40.0), "金疮药实际恢复 30% 最大生命")
	var orb := ExperienceOrb.create(arena, arena.player.global_position + Vector2(500, 0), 5)
	orb.add_to_group("xp_orbs")
	arena.pickup_layer.add_child(orb)
	context.check(registry.apply(ContentDatabase.item(&"soul_talisman"), arena) and orb.force_magnet, "聚魂符令地图经验球进入强制磁吸状态")

	var normal := arena.spawn_enemy(&"corpse", arena.player.global_position + Vector2(180, 0), false)
	var elite := arena.spawn_enemy(&"corpse", arena.player.global_position + Vector2(240, 0), true)
	var normal_before: float = normal.health
	var elite_before: float = elite.health
	registry.apply(ContentDatabase.item(&"soul_bell"), arena)
	context.check(is_equal_approx(normal_before - normal.health, normal.max_health * 0.40), "镇魂铃对普通敌人造成 40% 最大生命伤害")
	context.check(is_equal_approx(elite_before - elite.health, elite.max_health * 0.20), "镇魂铃对精英造成 20% 最大生命伤害")
	arena._start_boss()
	await tree.process_frame
	var boss_health_before: float = arena.boss.health
	registry.apply(ContentDatabase.item(&"soul_bell"), arena)
	context.check(is_equal_approx(arena.boss.health, boss_health_before), "镇魂铃不会伤害 Boss")

	var bound_normal := arena.spawn_enemy(&"corpse", arena.player.global_position + Vector2(200, 0), false)
	var bound_elite := arena.spawn_enemy(&"corpse", arena.player.global_position + Vector2(260, 0), true)
	registry.apply(ContentDatabase.item(&"binding_talisman"), arena)
	context.check(is_equal_approx(bound_normal.slow_multiplier, 0.0) and bound_normal.slow_timer >= 5.9, "定身符冻结普通敌人 6 秒")
	context.check(is_equal_approx(bound_elite.slow_multiplier, 0.0) and bound_elite.slow_timer >= 2.9, "定身符冻结精英 3 秒")
	context.check(is_equal_approx(arena.boss.slow_multiplier, 0.70) and arena.boss.slow_timer >= 2.9, "定身符令 Boss 减速 30% 持续 3 秒")

	var base_damage_multiplier: float = arena.skill_system.damage_multiplier()
	registry.apply(ContentDatabase.item(&"soul_wine"), arena)
	context.check(is_equal_approx(arena.skill_system.damage_multiplier(), base_damage_multiplier * 1.30), "烈魂酒使最终伤害提高 30%")
	context.check(is_equal_approx(arena.skill_system.cooldown_multiplier(), 0.85), "烈魂酒使主动冷却缩短 15%")
	arena.temporary_item_effects[&"soul_wine"]["remaining"] = 2.0
	registry.apply(ContentDatabase.item(&"soul_wine"), arena)
	context.check(is_equal_approx(float(arena.temporary_item_effects[&"soul_wine"]["remaining"]), 15.0) and is_equal_approx(arena.skill_system.damage_multiplier(), base_damage_multiplier * 1.30), "重复拾取烈魂酒刷新时间但不叠加数值")

	var drop_system := arena.item_drop_system
	for pickup in drop_system.active_pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	drop_system.active_pickups.clear()
	await tree.process_frame
	for index in range(3):
		context.check(drop_system.spawn_item(&"healing_salve", arena.player.global_position + Vector2(index * 35, 80)) != null, "同屏上限内可生成第 %d 个道具" % (index + 1))
	context.check(drop_system.spawn_item(&"soul_wine", arena.player.global_position + Vector2(120, 80)) == null, "同屏已有三个道具时拒绝继续生成")
	for pickup in drop_system.active_pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	drop_system.active_pickups.clear()
	await tree.process_frame
	for wave in range(1, 5):
		drop_system.item_spawned_this_wave = false
		drop_system.complete_wave(wave)
	context.check(drop_system.active_pickups.size() == 1 and drop_system.waves_without_item == 0, "连续四波未出现道具时保底生成一个并重置计数")
	var pots_before := drop_system.active_pots.size()
	drop_system.start_wave(2)
	var pots_added := drop_system.active_pots.size() - pots_before
	context.check(pots_added >= 1 and pots_added <= 2, "普通波开始时生成 1～2 个可破坏陶罐")

	drop_system.configure_rng_seed_for_tests(4242)
	arena.player.health = arena.player.max_health
	var full_health_salve_count := 0
	for _index in range(400):
		if drop_system._weighted_definition().id == &"healing_salve":
			full_health_salve_count += 1
	drop_system.configure_rng_seed_for_tests(4242)
	arena.player.health = arena.player.max_health * 0.5
	var injured_salve_count := 0
	for _index in range(400):
		if drop_system._weighted_definition().id == &"healing_salve":
			injured_salve_count += 1
	context.check(full_health_salve_count < injured_salve_count, "满生命时金疮药的随机权重会降低")

	arena.queue_free()
	await tree.process_frame


func _test_temporary_effect_hud(tree: SceneTree, context: RefCounted) -> void:
	GameState.clear_current_profile()
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main = main_scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main._start_game()
	await tree.process_frame
	main.arena.item_drop_system.effect_registry.apply(ContentDatabase.item(&"soul_wine"), main.arena)
	await tree.process_frame
	var hud_text := _collect_label_text(main.item_effect_box)
	var hud_icons: Array[Node] = main.item_effect_box.find_children("*", "TextureRect", true, false)
	context.check(main.item_effect_box.get_child_count() == 1 and hud_icons.size() == 1 and hud_text.contains("烈魂酒") and hud_text.contains("伤害 +30%") and hud_text.contains("冷却 -15%"), "临时效果 HUD 显示烈魂酒图标、数值与倒计时")
	main.queue_free()
	tree.paused = false
	await tree.process_frame


func _collect_label_text(root: Node) -> String:
	var text := ""
	for child in root.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text
