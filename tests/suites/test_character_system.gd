class_name CharacterSystemTestSuite
extends RefCounted

const SAVE_MANAGER_SCRIPT := preload("res://scripts/autoload/save_manager.gd")
const GAME_STATE_SCRIPT := preload("res://scripts/autoload/game_state.gd")

var suite_name: StringName = &"character_system"


func run(tree: SceneTree, context: RefCounted) -> void:
	_test_character_definitions(context)
	await _test_unlocks_and_profile_isolation(tree, context)
	await _test_character_traits_and_dragon_spear(tree, context)
	await _test_character_selection_ui(tree, context)


func _test_character_definitions(context: RefCounted) -> void:
	var expected := {
		&"black_sword": [&"black_slash", &"default", 0],
		&"minato": [&"rasengan", &"wave_complete", 300],
		&"ning_shuanghua": [&"frost", &"first_evolution", 600],
		&"xuandeng": [&"sun_palm", &"first_victory", 900],
		&"zhao_yun": [&"dragon_spear", &"wave_complete", 1200],
	}
	context.check(ContentDatabase.all_characters().size() == 5, "ContentDatabase 提供五名角色定义")
	context.check(ContentDatabase.character(&"black_sword").portrait.resource_path == "res://assets/actors/hero/portrait_actual.png", "黑剑客角色卡使用独立立绘而不是战斗动作图")
	for character_id in expected:
		var definition := ContentDatabase.character(character_id)
		context.check(definition != null and definition.initial_skill_id == expected[character_id][0], "角色 %s 的初始技能正确" % character_id)
		context.check(definition != null and definition.unlock_condition_id == expected[character_id][1] and definition.unlock_cost == expected[character_id][2], "角色 %s 的解锁条件与费用正确" % character_id)
		context.check(definition != null and definition.actor_scene != null and definition.portrait != null, "角色 %s 拥有独立场景与头像" % character_id)
		var actor := definition.actor_scene.instantiate() as PlayerActor
		context.check(actor != null and actor.character_id == character_id and actor.initial_skill_id == definition.initial_skill_id, "角色 %s 的场景导出值与 Resource 一致" % character_id)
		actor.free()
	var dragon_spear := ContentDatabase.skill(&"dragon_spear")
	context.check(dragon_spear != null and dragon_spear.max_level == 5 and dragon_spear.values.size() == 5, "龙胆枪拥有完整五级数据")
	context.check(float(dragon_spear.stats(1).get("damage")) == 20.0 and int(dragon_spear.stats(1).get("pierce")) == 3, "一级龙胆枪使用 20 伤害与 3 贯穿基线")
	context.check(float(dragon_spear.stats(5).get("damage")) == 62.0 and dragon_spear.stats(5).get("triple", false), "五级龙胆枪升级为梅花三连")
	for file_name in ["ning_shuanghua.png", "xuandeng.png", "zhao_yun.png"]:
		var texture := load("res://assets/actors/characters/" + file_name) as Texture2D
		var image := texture.get_image() if texture != null else null
		context.check(image != null and image.get_size() == Vector2i(1024, 1568) and image.detect_alpha() != Image.ALPHA_NONE, "%s 是透明 4×7 角色图集" % file_name)
	var zhao_image := (load("res://assets/actors/characters/zhao_yun.png") as Texture2D).get_image()
	var grid_probe_points := [Vector2i(546, 50), Vector2i(20, 232), Vector2i(522, 500), Vector2i(1013, 1200), Vector2i(20, 1383)]
	context.check(grid_probe_points.all(func(point: Vector2i) -> bool: return zhao_image.get_pixelv(point).a == 0.0), "赵云动作帧已清除横向、纵向与 L 形网格残线")


func _test_unlocks_and_profile_isolation(tree: SceneTree, context: RefCounted) -> void:
	var test_root := "user://tests/character_unlock_suite"
	_cleanup_directory(test_root)
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	tree.root.add_child(manager)
	manager.configure_storage_root_for_tests(test_root)
	var state: Node = GAME_STATE_SCRIPT.new()
	tree.root.add_child(state)
	state.configure_save_manager_for_tests(manager)
	state.configure_content_database_for_tests(ContentDatabase)
	var profile: ProfileData = state.create_profile(1)
	profile.night_embers = 5000
	manager.save_profile(profile, &"character_test_seed")
	state.load_profile(1)

	var wave_three := _result("character-wave-3", 3)
	context.check(state.submit_run_result(wave_three) == OK and state.is_character_unlock_available(&"minato"), "完成第 3 波后水门进入可解锁状态")
	var before_minato: int = state.current_profile.night_embers
	context.check(state.unlock_character(&"minato") == OK and state.current_profile.night_embers == before_minato - 300, "支付 300 夜烬解锁水门并立即保存")

	var evolution := _result("character-evolution", 1)
	evolution.evolved_skill_ids.append(&"test_evolution")
	context.check(state.submit_run_result(evolution) == OK and state.is_character_unlock_available(&"ning_shuanghua"), "首次技能进阶后宁霜华进入可解锁状态")
	var before_ning: int = state.current_profile.night_embers
	context.check(state.unlock_character(&"ning_shuanghua") == OK and state.current_profile.night_embers == before_ning - 600, "支付 600 夜烬解锁宁霜华")

	var victory := _result("character-victory", 4)
	victory.victory = true
	victory.final_boss_kill = true
	context.check(state.submit_run_result(victory) == OK and state.is_character_unlock_available(&"xuandeng"), "首次通关后玄灯进入可解锁状态")
	var before_xuandeng: int = state.current_profile.night_embers
	context.check(state.unlock_character(&"xuandeng") == OK and state.current_profile.night_embers == before_xuandeng - 900, "支付 900 夜烬解锁玄灯")

	var wave_nine := _result("character-wave-9", 9)
	context.check(state.submit_run_result(wave_nine) == OK and state.is_character_unlock_available(&"zhao_yun"), "完成第 9 波后赵云进入可解锁状态")
	var before_zhao: int = state.current_profile.night_embers
	context.check(state.unlock_character(&"zhao_yun") == OK and state.current_profile.night_embers == before_zhao - 1200, "支付 1200 夜烬解锁赵云")
	context.check(state.select_character(&"zhao_yun") == OK and state.load_profile(1).selected_character_id == &"zhao_yun", "角色选择写入当前存档并可重新载入")

	var second_profile: ProfileData = state.create_profile(2)
	context.check(second_profile != null and second_profile.unlocked_characters == [&"black_sword"] and second_profile.available_character_unlocks.is_empty(), "第二档角色解锁与第一档完全隔离")
	state.queue_free()
	manager.queue_free()
	await tree.process_frame
	_cleanup_directory(test_root)


func _test_character_traits_and_dragon_spear(tree: SceneTree, context: RefCounted) -> void:
	var test_root := "user://tests/character_trait_suite"
	_cleanup_directory(test_root)
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	tree.root.add_child(manager)
	manager.configure_storage_root_for_tests(test_root)
	var state: Node = GAME_STATE_SCRIPT.new()
	tree.root.add_child(state)
	state.configure_save_manager_for_tests(manager)
	state.configure_content_database_for_tests(ContentDatabase)
	var profile: ProfileData = state.create_profile(1)
	profile.unlocked_characters = [&"black_sword", &"minato", &"ning_shuanghua", &"xuandeng", &"zhao_yun"]
	manager.save_profile(profile, &"character_trait_seed")
	state.load_profile(1)

	var black_config: RunConfig = state.build_run_config(&"black_sword")
	context.check(is_equal_approx(black_config.health_multiplier, 1.10) and is_equal_approx(black_config.melee_damage_multiplier, 1.08), "黑剑客获得生命与近身伤害特性")
	var minato_config: RunConfig = state.build_run_config(&"minato")
	context.check(is_equal_approx(minato_config.move_speed_multiplier, 1.12) and is_equal_approx(minato_config.cooldown_multiplier, 0.92), "水门获得移速与冷却特性")
	var ning_config: RunConfig = state.build_run_config(&"ning_shuanghua")
	context.check(is_equal_approx(ning_config.area_multiplier, 1.10) and is_equal_approx(ning_config.status_duration_multiplier, 1.15), "宁霜华获得范围与状态持续特性")
	var xuandeng_config: RunConfig = state.build_run_config(&"xuandeng")
	context.check(is_equal_approx(xuandeng_config.health_multiplier, 1.20) and is_equal_approx(xuandeng_config.damage_taken_multiplier, 0.92) and is_equal_approx(xuandeng_config.move_speed_multiplier, 0.95), "玄灯获得生命、减伤与移速权衡特性")
	var zhao_config: RunConfig = state.build_run_config(&"zhao_yun")
	context.check(is_equal_approx(zhao_config.move_speed_multiplier, 1.08) and is_equal_approx(zhao_config.elite_boss_damage_multiplier, 1.12), "赵云获得移速与精英伤害特性")

	var battle_scene := load("res://scenes/gameplay/battle_arena.tscn") as PackedScene
	var minato_arena := battle_scene.instantiate() as Arena
	minato_arena.run_config = minato_config
	tree.root.add_child(minato_arena)
	await tree.process_frame
	minato_arena.spawn_timer = 9999.0
	context.check(minato_arena.player.character_id == &"minato" and is_equal_approx(minato_arena.player.speed_multiplier, 1.12) and is_equal_approx(minato_arena.skill_system.cooldown_multiplier(), 0.92), "水门特性实际作用于玩家移动与技能冷却")
	minato_arena.queue_free()
	await tree.process_frame

	var ning_arena := battle_scene.instantiate() as Arena
	ning_arena.run_config = ning_config
	tree.root.add_child(ning_arena)
	await tree.process_frame
	ning_arena.spawn_timer = 9999.0
	context.check(ning_arena.player.character_id == &"ning_shuanghua" and ning_arena.skill_system.levels.get(&"frost", 0) == 1, "宁霜华由数据场景实例化并以寒霜剑阵开局")
	context.check(is_equal_approx(ning_arena.skill_system.area_multiplier(), 1.10) and is_equal_approx(ning_arena.skill_system.status_duration_multiplier(), 1.15), "宁霜华的范围与控制持续乘数进入技能系统")
	ning_arena.queue_free()
	await tree.process_frame

	var xuandeng_arena := battle_scene.instantiate() as Arena
	xuandeng_arena.run_config = xuandeng_config
	tree.root.add_child(xuandeng_arena)
	await tree.process_frame
	xuandeng_arena.spawn_timer = 9999.0
	xuandeng_arena.player.take_damage(DamageEvent.create(10.0, xuandeng_arena, Vector2.ZERO, 0.0))
	context.check(is_equal_approx(xuandeng_arena.player.max_health, 120.0) and is_equal_approx(xuandeng_arena.player.health, 110.8), "玄灯的最大生命与 8% 减伤实际生效")
	xuandeng_arena.queue_free()
	await tree.process_frame

	var zhao_arena := battle_scene.instantiate() as Arena
	zhao_arena.run_config = zhao_config
	tree.root.add_child(zhao_arena)
	await tree.process_frame
	zhao_arena.spawn_timer = 9999.0
	context.check(zhao_arena.player.character_id == &"zhao_yun" and zhao_arena.skill_system.levels.get(&"dragon_spear", 0) == 1, "赵云由数据场景实例化并以龙胆枪开局")
	var normal := zhao_arena.spawn_enemy(&"corpse", zhao_arena.player.global_position + Vector2(90, 0), false)
	var elite := zhao_arena.spawn_enemy(&"corpse", zhao_arena.player.global_position + Vector2(125, 0), true)
	var normal_before: float = normal.health
	var elite_before: float = elite.health
	var hit_count: int = zhao_arena.skill_system._perform_dragon_spear(Vector2.RIGHT, ContentDatabase.skill(&"dragon_spear").stats(1))
	context.check(hit_count == 2 and is_equal_approx(normal_before - normal.health, 20.0), "一级龙胆枪沿直线贯穿并造成基础伤害")
	context.check(is_equal_approx(elite_before - elite.health, 22.4), "赵云对精英的 12% 额外伤害实际生效")
	zhao_arena.queue_free()
	await tree.process_frame

	state.queue_free()
	manager.queue_free()
	await tree.process_frame
	_cleanup_directory(test_root)


func _test_character_selection_ui(tree: SceneTree, context: RefCounted) -> void:
	var test_root := "user://tests/character_ui_suite"
	_cleanup_directory(test_root)
	SaveManager.configure_storage_root_for_tests(test_root)
	GameState.clear_current_profile()
	var profile := GameState.create_profile(1)
	profile.night_embers = 1000
	profile.available_character_unlocks.append(&"minato")
	GameState.save_current(&"character_ui_seed")
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main = main_scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main._show_character_selection()
	await tree.process_frame
	var cards: Node = main.ui_root.find_child("CharacterCards", true, false)
	context.check(cards != null and cards.get_child_count() == 5, "角色选择页显示五张角色卡")
	var black_card := main.ui_root.find_child("CharacterCard_black_sword", true, false) as Button
	var minato_card := main.ui_root.find_child("CharacterCard_minato", true, false) as Button
	var ning_card := main.ui_root.find_child("CharacterCard_ning_shuanghua", true, false) as Button
	context.check(black_card != null and not black_card.disabled and minato_card != null and not minato_card.disabled, "已解锁与可支付解锁角色卡可以交互")
	context.check(ning_card != null and ning_card.disabled and _collect_label_text(ning_card).contains("让任意主动招式首次完成进阶"), "未达条件角色卡显示明确解锁条件并禁用")
	main._unlock_character(&"minato")
	await tree.process_frame
	context.check(GameState.is_character_unlocked(&"minato") and GameState.current_profile.night_embers == 700, "角色卡支付解锁后立即扣费并保存")
	var reloaded := SaveManager.load_slot(1)
	context.check(reloaded != null and &"minato" in reloaded.unlocked_characters, "角色解锁状态已写入隔离测试存档")
	main.queue_free()
	await tree.process_frame
	GameState.clear_current_profile()
	SaveManager.reset_storage_root()
	_cleanup_directory(test_root)


func _result(run_id: String, waves: int) -> RunResult:
	var result := RunResult.new()
	result.run_id = run_id
	result.completed_waves = waves
	return result


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
