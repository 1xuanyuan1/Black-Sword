class_name MetaProgressionTestSuite
extends RefCounted

const SAVE_MANAGER_SCRIPT := preload("res://scripts/autoload/save_manager.gd")
const GAME_STATE_SCRIPT := preload("res://scripts/autoload/game_state.gd")

var suite_name: StringName = &"meta_progression"


func run(tree: SceneTree, context: RefCounted) -> void:
	_test_definitions_and_formula(context)
	await _test_profile_transactions(tree, context)
	await _test_battle_application(tree, context)
	await _test_hub_ui(tree, context)


func _test_definitions_and_formula(context: RefCounted) -> void:
	var definitions: Dictionary = ContentDatabase.all_meta_upgrades()
	context.check(definitions.size() == 4, "ContentDatabase 提供攻击、生命、悟性、复生四条养成")
	context.check(ContentDatabase.meta_upgrade(&"attack").max_level == 10, "攻击养成上限为 10 级")
	context.check(ContentDatabase.meta_upgrade(&"insight").cost_for_next_level(4) == 800, "悟性第五级费用为 800 夜烬")
	context.check(ContentDatabase.meta_upgrade(&"revive").stats(3).get("invulnerability") == 3.0, "复生三级提供 3 秒无敌")
	context.check(ContentDatabase.meta_upgrade(&"attack").invested_cost(10) == 3050, "攻击满级累计费用为 3050")

	var empty := RunResult.new()
	context.check(empty.calculate_night_embers() == 0, "零波退出不会获得夜烬")
	var partial := RunResult.new()
	partial.completed_waves = 6
	partial.miniboss_kills = 2
	partial.kills = 400
	context.check(partial.calculate_night_embers() == 300, "部分进度按波次、小 Boss 和封顶击杀奖励结算")
	var victory := RunResult.new()
	victory.completed_waves = 12
	victory.miniboss_kills = 3
	victory.final_boss_kill = true
	victory.kills = 400
	victory.victory = true
	context.check(victory.calculate_night_embers() == 680, "完整胜利最高基线结算为 680 夜烬")


func _test_profile_transactions(tree: SceneTree, context: RefCounted) -> void:
	var test_root := "user://tests/meta_progression_suite"
	_cleanup_directory(test_root)
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	tree.root.add_child(manager)
	manager.configure_storage_root_for_tests(test_root)
	var state: Node = GAME_STATE_SCRIPT.new()
	tree.root.add_child(state)
	state.configure_save_manager_for_tests(manager)
	state.configure_content_database_for_tests(ContentDatabase)
	var profile: ProfileData = state.create_profile(1)
	profile.night_embers = 10000
	manager.save_profile(profile, &"test_seed")
	state.load_profile(1)

	context.check(state.purchase_meta_upgrade(&"attack") == OK, "余额充足时可购买攻击养成")
	context.check(state.current_profile.night_embers == 9950 and int(state.current_profile.meta_upgrades["attack"]) == 1, "购买扣除 50 夜烬并提升一级")
	for _index in range(9):
		state.purchase_meta_upgrade(&"attack")
	context.check(int(state.current_profile.meta_upgrades["attack"]) == 10 and state.current_profile.night_embers == 6950, "攻击可购买至十级且累计消耗 3050")
	context.check(state.purchase_meta_upgrade(&"attack") == ERR_CANT_ACQUIRE_RESOURCE, "满级养成拒绝继续购买")

	state.current_profile.meta_upgrades["health"] = 2
	state.current_profile.meta_upgrades["insight"] = 3
	state.current_profile.meta_upgrades["revive"] = 2
	manager.save_profile(state.current_profile, &"test_config")
	var config: RunConfig = state.build_run_config(&"black_sword")
	context.check(is_equal_approx(config.attack_multiplier, 1.20) and is_equal_approx(config.health_multiplier, 1.21), "攻击养成与黑剑客生命特性按乘区转换为单局乘数")
	context.check(is_equal_approx(config.experience_multiplier, 1.15) and config.revive_rank == 2, "悟性与复生等级写入 RunConfig")

	var before_result: int = state.current_profile.night_embers
	var result := RunResult.new()
	result.run_id = "meta-test-run"
	result.character_id = &"black_sword"
	result.completed_waves = 3
	result.kills = 40
	result.elapsed_seconds = 181.2
	context.check(state.submit_run_result(result) == OK and result.earned_night_embers == 70, "RunResult 首次提交计算并写入 70 夜烬")
	context.check(state.current_profile.night_embers == before_result + 70 and int(state.current_profile.stats["runs"]) == 1, "结算同步更新余额、局数与用时")
	context.check(state.submit_run_result(result) == ERR_ALREADY_EXISTS, "同一 RunResult 对象不能重复提交")
	var duplicate := RunResult.new()
	duplicate.run_id = "meta-test-run"
	state.load_profile(1)
	context.check(state.submit_run_result(duplicate) == ERR_ALREADY_EXISTS, "重新载入后仍通过 run_id 阻止重复刷取夜烬")

	var investment: int = state.meta_investment_total()
	var before_reset: int = state.current_profile.night_embers
	context.check(investment == 6025, "重置返还额依据四条定义重新计算")
	context.check(state.reset_meta_upgrades() == OK, "可以免费重置全部局外养成")
	context.check(state.current_profile.night_embers == before_reset + investment, "重置全额返还实际投入夜烬")
	context.check(state.current_profile.meta_upgrades.values().all(func(level: Variant) -> bool: return int(level) == 0), "重置后四条养成都回到零级")

	state.current_profile.night_embers = 1900
	for upgrade_id in ProfileData.META_UPGRADE_MAX_LEVELS:
		state.current_profile.meta_upgrades[upgrade_id] = ProfileData.META_UPGRADE_MAX_LEVELS[upgrade_id]
	context.check(manager.save_profile(state.current_profile, &"test_full_meta_seed") == OK, "四项满级且持有 1900 夜烬的 QA 档案合法")
	state.load_profile(1)
	context.check(state.meta_investment_total() == 12500, "四项满级累计投入为 12500 夜烬")
	var full_meta_result := RunResult.new()
	full_meta_result.run_id = "full-meta-run"
	full_meta_result.completed_waves = 4
	full_meta_result.kills = 1028
	full_meta_result.elapsed_seconds = 394.0
	context.check(state.submit_run_result(full_meta_result) == OK, "四项满级 QA 档案可以正常保存战斗结算")
	var after_full_result: int = state.current_profile.night_embers
	context.check(state.reset_meta_upgrades() == OK, "四项满级 QA 档案可以免费重置")
	context.check(state.current_profile.night_embers == after_full_result + 12500, "满级重置完整返还 12500 夜烬")

	state.current_profile.night_embers = 0
	manager.save_profile(state.current_profile, &"test_empty")
	state.load_profile(1)
	context.check(state.purchase_meta_upgrade(&"insight") == ERR_UNAVAILABLE, "余额不足时购买失败且不产生负数")
	var invalid_profile := ProfileData.create_new(2)
	invalid_profile.meta_upgrades["revive"] = 4
	context.check(manager.save_profile(invalid_profile, &"invalid_meta") == ERR_INVALID_DATA, "存档校验拒绝超上限养成等级")

	state.queue_free()
	manager.queue_free()
	await tree.process_frame
	_cleanup_directory(test_root)


func _test_battle_application(tree: SceneTree, context: RefCounted) -> void:
	var scene := load("res://scenes/gameplay/battle_arena.tscn") as PackedScene
	var arena := scene.instantiate() as Arena
	var config := RunConfig.default_for_character(&"black_sword")
	config.attack_multiplier = 1.20
	config.health_multiplier = 1.50
	config.experience_multiplier = 1.25
	config.revive_rank = 1
	arena.run_config = config
	tree.root.add_child(arena)
	await tree.process_frame
	context.check(is_equal_approx(arena.player.max_health, 150.0) and is_equal_approx(arena.player.health, 150.0), "生命养成在玩家创建时应用")
	context.check(is_equal_approx(arena.skill_system.damage_multiplier(), 1.20), "攻击养成乘入最终技能伤害")
	arena.collect_xp(8)
	context.check(arena.current_xp == 10, "悟性按四舍五入提高实际经验")
	var nearby := arena.spawn_enemy(&"corpse", arena.player.global_position + Vector2(100, 0))
	arena.player.take_damage(DamageEvent.create(9999.0, arena.player, Vector2.ZERO, 0.0))
	await tree.process_frame
	context.check(not arena.player.dead and arena.player.revive_used and is_equal_approx(arena.player.health, 45.0), "一级复生以 30% 最大生命阻止首次死亡")
	context.check(arena.player.invulnerability > 1.4, "一级复生提供约 1.5 秒无敌")
	context.check(not is_instance_valid(nearby) or nearby.is_queued_for_deletion(), "复生清除 180 范围内普通敌人")
	arena.player.invulnerability = 0.0
	arena.player.take_damage(DamageEvent.create(9999.0, arena.player, Vector2.ZERO, 0.0))
	context.check(arena.player.dead, "同一局第二次致命伤不会再次复生")
	arena.queue_free()
	await tree.process_frame


func _test_hub_ui(tree: SceneTree, context: RefCounted) -> void:
	var test_root := "user://tests/meta_ui_suite"
	_cleanup_directory(test_root)
	SaveManager.configure_storage_root_for_tests(test_root)
	GameState.clear_current_profile()
	var profile := GameState.create_profile(1)
	profile.night_embers = 100
	GameState.save_current(&"ui_seed")
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main = main_scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main._show_hub()
	await tree.process_frame
	context.check(main.hub_open and main.ui_root.find_child("StartChallengeButton", true, false) != null, "守夜庭提供开始挑战入口")
	context.check((main.ui_root.find_child("HubNightEmbersLabel", true, false) as Label).text.contains("100"), "守夜庭显示当前夜烬余额")
	main._show_meta_progression()
	await tree.process_frame
	context.check(main.ui_root.find_child("MetaUpgradeCards", true, false).get_child_count() == 4, "夜烬养成页显示四张分支卡")
	context.check(main.ui_root.find_child("PurchaseMeta_attack", true, false) != null, "养成卡提供购买按钮")
	context.check((main.ui_root.find_child("PurchaseMeta_attack", true, false) as Button).text.contains("50"), "攻击养成卡显示首级 50 夜烬费用")
	main._purchase_meta_upgrade(&"attack")
	await tree.process_frame
	context.check(GameState.current_profile.night_embers == 50 and int(GameState.current_profile.meta_upgrades["attack"]) == 1, "养成页购买会立即保存并刷新余额")
	var attack_effect := main.ui_root.find_child("MetaCurrentEffect_attack", true, false) as RichTextLabel
	context.check(attack_effect != null and attack_effect.text.contains("最终伤害") and attack_effect.text.contains("+2%"), "养成卡使用玩家可读文案而非原始数据字典")
	context.check(attack_effect != null and attack_effect.text.contains("[color=#72e6a5]") and attack_effect.text.contains("[font_size=24]"), "当前效果的增益数值使用高亮颜色与放大字号")
	var before_result_balance: int = GameState.current_profile.night_embers
	main._show_result(false, 394.0, 42, 1028)
	var result_text := _collect_label_text(main.modal_overlay)
	context.check(main.current_run_result != null and main.current_run_result.submitted, "战斗结束界面通过正式路径提交 RunResult")
	context.check(main.current_run_result.earned_night_embers == 180, "06:34、四波、1028 击杀的失败结算获得 180 夜烬")
	context.check(GameState.current_profile.night_embers == before_result_balance + 180, "战斗结束结算将夜烬写入当前档位")
	context.check(result_text.contains("带回夜烬  180") and not result_text.contains("结算保存失败"), "战斗结算界面显示入账结果且不再报 Invalid data")
	var persisted := SaveManager.load_slot(1)
	context.check(persisted != null and int(persisted.stats["runs"]) == 1 and int(persisted.stats["total_kills"]) == 1028, "战斗结算统计已写入 JSON 并可重新载入")
	tree.paused = false
	main.queue_free()
	await tree.process_frame
	GameState.clear_current_profile()
	SaveManager.reset_storage_root()
	_cleanup_directory(test_root)


func _collect_label_text(root: Node) -> String:
	var text := ""
	for child in root.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text


func _cleanup_directory(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory != null:
		for file_name in directory.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file_name)))
	DirAccess.remove_absolute(absolute)
