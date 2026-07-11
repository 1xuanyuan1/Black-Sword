class_name StoryUITestSuite
extends RefCounted

var suite_name: StringName = &"story_ui"


func run(tree: SceneTree, context: RefCounted) -> void:
	var stories := ContentDatabase.all_stories()
	context.check(stories.size() == 8, "故事数据库包含序章、首次死亡、三次真相与三条结局")
	context.check(ContentDatabase.story(&"prologue").body.contains("建安二十四年") and ContentDatabase.story(&"prologue").body.contains("你又来了"), "序章采用确认的三国时代与轮回文本")
	context.check(ContentDatabase.story(&"ending_main").body.contains("第十三响"), "沈砚主线以第十三响收束")
	context.check(ContentDatabase.story(&"ending_zhao_yun").body.contains("褒斜支路已清") and ContentDatabase.story(&"ending_zhao_yun").route_id == &"zhao_yun", "赵云支线保持三国军报视角")
	context.check(ContentDatabase.story(&"ending_minato").body.contains("术式坐标") and ContentDatabase.story(&"ending_minato").route_id == &"minato", "水门支线保持独立异界坐标叙事")
	for index in range(1, 13):
		context.check(not ContentDatabase.wave(index).entry_text.is_empty(), "第 %d 响拥有一行战斗入场提示" % index)

	var ui_scenes := {
		"res://scenes/ui/title_screen.tscn": "TitleScreen",
		"res://scenes/ui/save_select_screen.tscn": "SaveSelectScreen",
		"res://scenes/ui/hub_screen.tscn": "HubScreen",
		"res://scenes/ui/character_select_screen.tscn": "CharacterSelectScreen",
		"res://scenes/ui/battle_hud.tscn": "BattleHUD",
		"res://scenes/ui/result_screen.tscn": "ResultScreen",
		"res://scenes/ui/story_archive_screen.tscn": "StoryArchiveScreen",
		"res://scenes/ui/story_overlay.tscn": "StoryOverlay",
	}
	for path in ui_scenes:
		var scene := load(path) as PackedScene
		var instance := scene.instantiate() if scene != null else null
		context.check(instance != null and instance.name == ui_scenes[path], "%s 可作为独立 UI 场景加载" % ui_scenes[path])
		if instance != null:
			instance.free()

	var test_root := "user://tests/story_ui_suite"
	_cleanup_directory(test_root)
	SaveManager.configure_storage_root_for_tests(test_root)
	GameState.clear_current_profile()
	var profile := GameState.create_profile(1)
	context.check(profile != null and GameState.mark_story_flag(&"manual_story") == OK, "故事已读标记通过 GameState 原子保存")
	context.check(GameState.has_story_flag(&"manual_story") and GameState.mark_story_flag(&"manual_story") == OK, "重复写入故事标记保持幂等")

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main._start_game()
	await tree.process_frame
	await tree.process_frame
	var prologue_overlay := main.ui_root.find_child("StoryOverlay", true, false) as StoryOverlay
	context.check(main.story_open and tree.paused and prologue_overlay != null, "新档首次进入战斗暂停并展示序章")
	context.check(prologue_overlay.title_label.text == "序章·无月之夜" and prologue_overlay.continue_button.text == "继续", "序章模态显示正式标题与继续按钮")
	prologue_overlay._close()
	await tree.process_frame
	context.check(not tree.paused and GameState.has_story_flag(&"prologue"), "关闭序章后恢复战斗并保存已读标记")
	main._start_game()
	await tree.process_frame
	await tree.process_frame
	context.check(not main.story_open and main.ui_root.find_child("StoryOverlay", true, false) == null, "已读序章在后续开局自动跳过")

	main._show_story_event(&"truth_03")
	await tree.process_frame
	var truth_overlay := main.ui_root.find_child("StoryOverlay", true, false) as StoryOverlay
	context.check(truth_overlay != null and truth_overlay.body_label.text.contains("第一只宝匣"), "第三响真相使用最终对白文本")
	truth_overlay._close()
	await tree.process_frame
	main._show_hub()
	await tree.process_frame
	context.check(main.ui_root.find_child("OpenStoryArchiveButton", true, false) is Button, "守夜庭提供故事档案入口")
	main._show_story_archive()
	await tree.process_frame
	context.check(main.ui_root.find_child("StoryArchiveEntries", true, false).get_child_count() == 8, "故事档案列出全部八段残响")
	context.check(not (main.ui_root.find_child("StoryEntry_prologue", true, false) as Button).disabled, "已读故事可从档案重看")
	context.check((main.ui_root.find_child("StoryEntry_ending_main", true, false) as Button).disabled, "未达成结局在档案中保持锁定")

	main.selected_character_id = &"zhao_yun"
	main._show_result(true, 720.0, 40, 500)
	await tree.process_frame
	var ending_text := main.modal_overlay.find_child("ResultStoryText", true, false) as RichTextLabel
	context.check(ending_text != null and ending_text.text.contains("常山支线") and ending_text.text.contains("不该再惊扰活人"), "赵云通关结算显示正史支线结局")
	context.check(GameState.has_story_flag(&"ending_zhao_yun"), "角色支线结局已写入当前存档")
	context.check(main.SFX_STREAMS.size() >= 7 and main.BATTLE_MUSIC != null and main.BOSS_MUSIC != null, "战斗、Boss、升级、胜负和 UI 音频均已接入")
	main.queue_free()
	tree.paused = false
	await tree.process_frame
	GameState.clear_current_profile()
	SaveManager.reset_storage_root()
	_cleanup_directory(test_root)


func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		directory.remove(file_name)
	for directory_name in directory.get_directories():
		_cleanup_directory(path.path_join(directory_name))
		directory.remove(directory_name)
	DirAccess.remove_absolute(path)
