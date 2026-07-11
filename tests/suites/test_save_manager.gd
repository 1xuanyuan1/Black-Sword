class_name SaveManagerTestSuite
extends RefCounted

const SAVE_MANAGER_SCRIPT := preload("res://scripts/autoload/save_manager.gd")
const GAME_STATE_SCRIPT := preload("res://scripts/autoload/game_state.gd")

var suite_name: StringName = &"save_manager"


func run(tree: SceneTree, context: RefCounted) -> void:
	var test_root := "user://tests/save_manager_suite"
	_cleanup_directory(test_root)
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	tree.root.add_child(manager)
	context.check(manager.configure_storage_root_for_tests(test_root) == OK, "测试存档只能配置在 user://tests/ 下")

	var empty_slots: Array[SaveSlotSummary] = manager.list_slots()
	context.check(empty_slots.size() == 3, "SaveManager 固定提供三个档位")
	context.check(empty_slots.all(func(summary: SaveSlotSummary) -> bool: return not summary.exists), "新测试目录中的三个档位均为空")
	context.check(manager.create_slot(0) == null and manager.create_slot(4) == null, "拒绝范围外的档位编号")

	var slot_one: ProfileData = manager.create_slot(1)
	context.check(slot_one != null and slot_one.slot_index == 1, "可以创建第一档")
	context.check(slot_one != null and &"black_sword" in slot_one.unlocked_characters, "新档默认解锁黑剑客")
	context.check(manager.create_slot(1) == null, "不会覆盖已经存在的档位")
	if slot_one != null:
		slot_one.night_embers = 42
		slot_one.story_flags.append(&"test_story")
		slot_one.stats["runs"] = 3
	context.check(manager.save_profile(slot_one, &"test_round_trip") == OK, "档案可通过临时文件与备份流程保存")
	var loaded_one: ProfileData = manager.load_slot(1)
	context.check(loaded_one != null and loaded_one.night_embers == 42 and &"test_story" in loaded_one.story_flags, "夜烬与故事标记可往返序列化")
	context.check(loaded_one != null and int(loaded_one.stats.get("runs")) == 3, "统计数据可往返序列化")

	var slot_two: ProfileData = manager.create_slot(2)
	context.check(slot_two != null and slot_two.night_embers == 0, "第二档拥有独立的初始数据")
	context.check(manager.load_slot(1).night_embers == 42 and manager.load_slot(2).night_embers == 0, "不同档位的数据互不污染")

	var export_path := test_root.path_join("export_slot_1.json")
	context.check(manager.export_slot(1, export_path) == OK and FileAccess.file_exists(export_path), "档位可以导出为 JSON")
	var imported: ProfileData = manager.import_slot(3, export_path)
	context.check(imported != null and imported.slot_index == 3 and imported.night_embers == 42, "导出文件可以导入到另一个档位")

	var invalid_path := test_root.path_join("invalid.json")
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string("{ invalid save")
	invalid_file.close()
	context.check(manager.import_slot(3, invalid_path) == null, "非法 JSON 导入会被拒绝")
	context.check(manager.load_slot(3).night_embers == 42, "失败的导入不会覆盖原档")

	var slot_one_path := test_root.path_join("slot_1.json")
	var corrupt_file := FileAccess.open(slot_one_path, FileAccess.WRITE)
	corrupt_file.store_string("corrupt primary")
	corrupt_file.close()
	var recoverable_summary: SaveSlotSummary = manager.list_slots()[0]
	context.check(recoverable_summary.corrupt and recoverable_summary.recoverable, "正式档损坏时档位摘要标记为可恢复")
	var recovered: ProfileData = manager.load_slot(1)
	context.check(recovered != null and not manager.last_recovery_message.is_empty(), "正式档损坏时自动读取上一次完整备份")
	context.check(JSON.parse_string(FileAccess.get_file_as_string(slot_one_path)) is Dictionary, "恢复后重新生成合法的正式档")

	var invalid_profile := ProfileData.create_new(2)
	invalid_profile.selected_character_id = &"locked_character"
	context.check(manager.save_profile(invalid_profile, &"invalid_profile") == ERR_INVALID_DATA, "拒绝保存选择了未解锁角色的档案")
	context.check(manager.load_slot(2) != null, "无效档案不会覆盖第二档")

	var local_state: Node = GAME_STATE_SCRIPT.new()
	tree.root.add_child(local_state)
	context.check(local_state.configure_save_manager_for_tests(manager) == OK, "GameState 测试时可以注入隔离的 SaveManager")
	context.check(local_state.load_profile(2) != null and local_state.current_slot_index() == 2, "GameState 可以载入并持有当前档位")
	local_state.clear_current_profile()
	context.check(not local_state.has_current_profile(), "GameState 可以清除当前档位")
	local_state.queue_free()

	await _test_save_selection_ui(tree, context)

	manager.queue_free()
	await tree.process_frame
	_cleanup_directory(test_root)


func _test_save_selection_ui(tree: SceneTree, context: RefCounted) -> void:
	var ui_test_root := "user://tests/save_ui_suite"
	_cleanup_directory(ui_test_root)
	SaveManager.configure_storage_root_for_tests(ui_test_root)
	GameState.clear_current_profile()
	SaveManager.create_slot(1)
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main = main_scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main._show_save_selection()
	await tree.process_frame
	context.check(main.save_select_open and main.ui_root.find_child("SaveSelectionBackground", true, false) != null, "标题页可以进入三档存档选择界面")
	context.check(main.ui_root.find_child("SaveSlotCard1", true, false) != null and main.ui_root.find_child("SaveSlotCard3", true, false) != null, "存档选择界面显示三个档位卡片")
	context.check(main.ui_root.find_child("LoadSlot1Button", true, false) != null, "已有档位显示进入按钮")
	context.check(main.ui_root.find_child("CreateSlot2Button", true, false) != null, "空档位显示创建按钮")
	main._create_or_load_slot(2)
	await tree.process_frame
	context.check(GameState.current_slot_index() == 2 and main.hub_open, "创建空档后进入局外大厅并记录当前档位")
	context.check(main.ui_root.find_child("HubNightEmbersLabel", true, false) != null, "局外大厅显示当前档位夜烬")
	main._show_save_selection()
	await tree.process_frame
	main._delete_slot_immediately(2)
	await tree.process_frame
	context.check(GameState.current_slot_index() == 0 and main.ui_root.find_child("CreateSlot2Button", true, false) != null, "删除当前档后清除 GameState 并恢复空档卡片")
	main.queue_free()
	await tree.process_frame
	GameState.clear_current_profile()
	SaveManager.reset_storage_root()
	_cleanup_directory(ui_test_root)


func _cleanup_directory(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory != null:
		for file_name in directory.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file_name)))
	DirAccess.remove_absolute(absolute)
