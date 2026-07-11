class_name SkillInventoryTestSuite
extends RefCounted

var suite_name: StringName = &"skill_inventory"


func run(tree: SceneTree, context: RefCounted) -> void:
	var definitions: Dictionary = ContentDatabase.all_skills()
	var active_ids: Array[StringName] = []
	var passive_ids: Array[StringName] = []
	for value in definitions.values():
		var definition := value as SkillDefinition
		if definition.skill_type == SkillDefinition.SkillType.ACTIVE:
			active_ids.append(definition.id)
		elif definition.skill_type == SkillDefinition.SkillType.PASSIVE:
			passive_ids.append(definition.id)
	active_ids.sort()
	passive_ids.sort()
	context.check(active_ids.size() == 10, "V1 内容池包含 10 个主动技能")
	context.check(passive_ids.size() == 10, "V1 内容池包含 10 个被动心法")
	for id in passive_ids:
		var definition := definitions[id] as SkillDefinition
		context.check(definition.max_level == 5 and definition.values.size() == 5, "心法 %s 拥有完整五级累计数据" % id)

	var inventory := SkillInventory.new()
	inventory.setup(definitions, 20260711)
	for id in active_ids.slice(0, 6):
		context.check(inventory.upgrade(id).success, "主动槽可加入 %s" % id)
	var rejected_active := inventory.upgrade(active_ids[6])
	context.check(inventory.active_ids.size() == 6 and not rejected_active.success and rejected_active.reason == &"slot_full", "第七个主动被 6 槽上限拒绝")
	for id in passive_ids.slice(0, 6):
		context.check(inventory.upgrade(id).success, "心法槽可加入 %s" % id)
	var rejected_passive := inventory.upgrade(passive_ids[6])
	context.check(inventory.passive_ids.size() == 6 and not rejected_passive.success and rejected_passive.reason == &"slot_full", "第七个心法被 6 槽上限拒绝")
	var held_ids: Array[StringName] = inventory.active_ids.duplicate()
	held_ids.append_array(inventory.passive_ids)
	for id in held_ids:
		for _rank in range(4):
			inventory.upgrade(id)
		context.check(inventory.level_of(id) == 5, "%s 可以升至五级" % id)
		context.check(not inventory.upgrade(id).success, "%s 满级后拒绝继续升级" % id)
	var recovery_options := inventory.get_upgrade_options(3)
	context.check(recovery_options.size() == 3 and recovery_options.all(func(option: SkillDefinition) -> bool: return option.id == &"recovery"), "满槽且全部满级时三个候选自动转为调息")

	var seeded_a := SkillInventory.new()
	var seeded_b := SkillInventory.new()
	seeded_a.setup(definitions, 99)
	seeded_b.setup(definitions, 99)
	var option_ids_a: Array[StringName] = []
	var option_ids_b: Array[StringName] = []
	var unique_ids := {}
	for option in seeded_a.get_upgrade_options(3):
		option_ids_a.append(option.id)
		unique_ids[option.id] = true
	for option in seeded_b.get_upgrade_options(3):
		option_ids_b.append(option.id)
	context.check(option_ids_a == option_ids_b, "升级候选使用可复现的本局随机种子")
	context.check(unique_ids.size() == 3, "普通升级候选为三个不同内容")

	var battle_scene := load("res://scenes/gameplay/battle_arena.tscn") as PackedScene
	var arena := battle_scene.instantiate() as Arena
	tree.root.add_child(arena)
	await tree.process_frame
	await tree.process_frame
	arena.spawn_timer = 9999.0
	var controller := arena.skill_controller
	for id in [&"tempered_edge", &"spacetime_formula", &"sword_control", &"formation_breaking", &"light_step", &"thunder_seal"]:
		for _rank in range(5):
			controller.upgrade(id)
	context.check(is_equal_approx(controller.damage_multiplier(), 1.4), "五级淬锋心法提供全局伤害 +40%")
	context.check(is_equal_approx(controller.cooldown_multiplier(), 0.8), "五级淬锋心法提供冷却 -20%")
	context.check(is_equal_approx(controller.projectile_speed_multiplier(), 1.4), "五级时空间术式提供投射速度 +40%")
	context.check(is_equal_approx(controller.projectile_lifetime_multiplier(), 1.5) and controller.projectile_pierce_bonus() == 2, "五级御剑心诀提供寿命 +50% 与贯穿 +2")
	context.check(is_equal_approx(controller.area_multiplier(), 1.35) and is_equal_approx(controller.knockback_multiplier(), 1.5), "五级破阵真意提供范围 +35% 与击退 +50%")
	context.check(is_equal_approx(controller.critical_chance(), 0.15) and is_equal_approx(controller.critical_damage_multiplier(), 2.0), "五级引雷法印提供 15% 暴击率与 200% 暴击倍率")
	context.check(is_equal_approx(arena.player.speed_multiplier, arena.player.character_speed_multiplier * 1.45) and is_equal_approx(arena.player.pickup_range, 147.2), "时空间术式与轻身诀聚合到移动和拾取属性")
	controller.rng.seed = 71
	var critical_count := 0
	for _roll in range(100):
		if controller.make_player_damage_event(10.0).critical:
			critical_count += 1
	context.check(critical_count > 0 and critical_count < 40, "引雷法印实际进入伤害事件暴击判定")
	arena.queue_free()
	await tree.process_frame

	var support_arena := battle_scene.instantiate() as Arena
	tree.root.add_child(support_arena)
	await tree.process_frame
	await tree.process_frame
	support_arena.spawn_timer = 9999.0
	var support := support_arena.skill_controller
	for id in [&"mystic_yin", &"pure_yang", &"sword_casket", &"battlefield_tactics"]:
		for _rank in range(5):
			support.upgrade(id)
	context.check(is_equal_approx(support.status_duration_multiplier(), 1.5) and is_equal_approx(support_arena.player.damage_taken_multiplier, 0.9), "五级玄阴心法提供控制 +50% 与减伤 10%")
	context.check(is_equal_approx(support_arena.player.max_health, 140.0) and is_equal_approx(support.health_regeneration_per_second(), 0.005), "五级纯阳功提供最大生命 +40% 与每秒恢复 0.5%")
	support_arena.player.health = 100.0
	support.process_skills(1.0)
	context.check(is_equal_approx(support_arena.player.health, 100.7), "纯阳功的持续恢复实际作用于角色")
	context.check(is_equal_approx(support.projectile_speed_multiplier(), 1.3) and support.quantity_bonus() == 2, "五级藏剑匣提供速度 +30% 与数量 +2")
	context.check(is_equal_approx(support.target_category_damage_multiplier(), 1.25), "五级陷阵兵法提供对精英与 Boss 伤害 +25%")
	context.check(is_equal_approx(support_arena.player.speed_multiplier, support_arena.player.character_speed_multiplier * 1.15), "五级陷阵兵法提供移动速度 +15%")
	var elite := support_arena.spawn_enemy(&"corpse", support_arena.player.global_position + Vector2(150, 0), true)
	var elite_health := elite.health
	elite.take_damage(DamageEvent.create(10.0, support_arena.player))
	context.check(is_equal_approx(elite_health - elite.health, 12.5), "陷阵兵法实际乘入精英受伤结算")
	support_arena.player.health = 20.0
	var recovery := support.upgrade(&"recovery")
	context.check(recovery.success and recovery.recovered_health and is_equal_approx(support_arena.player.health, 48.0), "调息候选恢复 20% 最大生命")
	support_arena.queue_free()
	await tree.process_frame

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main._start_game()
	await tree.process_frame
	var active_row: Node = main.skill_box.get_node_or_null("ActiveSkillRow")
	var passive_row: Node = main.skill_box.get_node_or_null("PassiveSkillRow")
	context.check(active_row is HBoxContainer and active_row.get_child_count() == 7, "HUD 固定显示标题与六个主动槽")
	context.check(passive_row is HBoxContainer and passive_row.get_child_count() == 7, "HUD 固定显示标题与六个心法槽")
	main.queue_free()
	await tree.process_frame
