extends Node

const UI_FONT := preload("res://assets/fonts/NotoSansSC.ttf")
const HERO_PORTRAIT := preload("res://assets/actors/hero/portrait_actual.png")
const BATTLE_MUSIC := preload("res://assets/audio/battle.ogg")
const BOSS_MUSIC := preload("res://assets/audio/boss.ogg")
const BATTLE_ARENA_SCENE: PackedScene = preload("res://scenes/gameplay/battle_arena.tscn")
const VIRTUAL_JOYSTICK_SCENE: PackedScene = preload("res://scenes/ui/virtual_joystick.tscn")
const STORY_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/story_overlay.tscn")
const SFX_STREAMS := {
	&"slash": preload("res://assets/audio/slash.wav"),
	&"hit": preload("res://assets/audio/hit.wav"),
	&"level_up": preload("res://assets/audio/level_up.wav"),
	&"game_over": preload("res://assets/audio/game_over.wav"),
	&"victory": preload("res://assets/audio/victory.wav"),
	&"magic": preload("res://assets/audio/magic.wav"),
	&"ui": preload("res://assets/audio/ui_accept.wav"),
}

var world_holder := Node2D.new()
var ui_layer := CanvasLayer.new()
var ui_root := Control.new()
var game_theme := Theme.new()
var arena: Arena
var music_player := AudioStreamPlayer.new()
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index := 0
var hud_root: Control
var hp_bar: ProgressBar
var hp_value_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var level_label: Label
var timer_label: Label
var wave_label: Label
var kills_label: Label
var skill_box: VBoxContainer
var item_effect_box: VBoxContainer
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_value_label: Label
var announcement_label: Label
var chest_label: Label
var movement_joystick: MovementJoystick
var touch_pause_button: Button
var modal_overlay: Control
var level_options: Array[SkillDefinition] = []
var leveling := false
var pause_open := false
var game_running := false
var character_select_open := false
var save_select_open := false
var hub_open := false
var selected_character_id: StringName = &"black_sword"
var orientation_pause_active := false
var current_run_result: RunResult
var evolution_options: Array[EvolutionRecipe] = []
var evolution_chest_id: StringName
var evolving := false
var story_open := false
var pending_story_ids: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_holder.name = "BattleWorld"
	world_holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	ui_layer.name = "UserInterfaceLayer"
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_root.name = "ScreenInterface"
	music_player.name = "MusicPlayer"
	_build_theme()
	add_child(world_holder)
	add_child(ui_layer)
	ui_layer.layer = 20
	ui_layer.add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(music_player)
	music_player.bus = &"Music"
	music_player.finished.connect(_on_music_finished)
	for i in range(10):
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%02d" % (i + 1)
		player.bus = &"SFX"
		add_child(player)
		sfx_players.append(player)
	_show_title()
	if OS.is_debug_build():
		_handle_qa_args()


func _handle_qa_args() -> void:
	if "--qa-battle" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
	elif "--qa-orbit" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_enable_orbit")
	elif "--qa-boss" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_spawn_boss")
	elif "--qa-levelup" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_trigger_levelup")
	elif "--qa-minato" in OS.get_cmdline_user_args():
		selected_character_id = &"minato"
		call_deferred("_start_game")
	elif "--qa-character-select" in OS.get_cmdline_user_args():
		call_deferred("_show_character_selection")
	elif "--qa-save-select" in OS.get_cmdline_user_args():
		call_deferred("_show_save_selection")
	elif "--qa-meta-progression" in OS.get_cmdline_user_args():
		call_deferred("_qa_show_meta_progression")
	elif "--qa-characters" in OS.get_cmdline_user_args():
		call_deferred("_qa_show_characters")
	elif "--qa-items" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_prepare_items")
	elif "--qa-skills" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_prepare_skills")
	elif "--qa-evolutions" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_prepare_evolutions")
	elif "--qa-waves" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_prepare_waves")
	elif "--qa-full-run" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_prepare_full_run")
	elif "--qa-map-boss" in OS.get_cmdline_user_args():
		call_deferred("_start_game")
		call_deferred("_qa_prepare_map_boss")
	elif "--qa-story" in OS.get_cmdline_user_args():
		call_deferred("_qa_prepare_story")


func _process(_delta: float) -> void:
	if not game_running or not _touch_controls_supported():
		orientation_pause_active = false
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var is_portrait := viewport_size.y > viewport_size.x
	if is_portrait and not orientation_pause_active:
		orientation_pause_active = true
		_release_virtual_movement()
		_set_touch_movement_enabled(false)
		if not leveling and not pause_open:
			get_tree().paused = true
	elif not is_portrait and orientation_pause_active:
		orientation_pause_active = false
		if not leveling and not pause_open:
			get_tree().paused = false
			_set_touch_movement_enabled(true)


func _exit_tree() -> void:
	music_player.stop()
	music_player.stream = null
	for player in sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _on_music_finished() -> void:
	if music_player.stream != null:
		music_player.play()


func _qa_trigger_levelup() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(arena):
		arena.collect_xp(12)


func _qa_spawn_boss() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(arena):
		arena.elapsed = Arena.BOSS_SPAWN_TIME
		arena._start_boss()


func _qa_enable_orbit() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(arena):
		for _level in range(5):
			arena.skill_system.upgrade(&"orbit_blades")


func _qa_prepare_skills() -> void:
	if not OS.is_debug_build():
		return
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(arena):
		return
	arena.spawn_timer = 9999.0
	for id in [&"rasengan", &"flying_sword", &"sword_wave", &"orbit_blades", &"thunder"]:
		arena.skill_controller.upgrade(id)
	for id in [&"tempered_edge", &"spacetime_formula", &"sword_control", &"formation_breaking", &"light_step", &"pure_yang"]:
		arena.skill_controller.upgrade(id)
	arena.spawn_enemy(&"corpse", arena.player.global_position + Vector2(280, 0), true)
	arena.announce("QA 技能验收：已填满 6 主动 + 6 心法", Color("ffd38a"))
	await get_tree().create_timer(0.45).timeout
	arena.collect_xp(arena.required_xp)


func _qa_prepare_evolutions() -> void:
	if not OS.is_debug_build():
		return
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(arena):
		return
	arena.spawn_timer = 9999.0
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
	for offset in [Vector2(-120, 130), Vector2(0, 170), Vector2(120, 130)]:
		arena.evolution_system.spawn_chest(arena.player.global_position + offset)
	arena.announce("QA 进阶验收：四套配方就绪，地图有三个永久宝匣", Color("ffd76a"))


func _qa_prepare_waves() -> void:
	if not OS.is_debug_build():
		return
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(arena):
		return
	arena.player.invulnerability = 9999.0
	arena.set_meta("qa_auto_level", true)
	arena.wave_director.duration_scale = 0.05
	arena.spawn_director.qa_auto_defeat_bosses = true
	arena.announce("QA 十二波加速：普通波 2.5 秒，小 Boss 自动验收", Color("ffd38a"))


func _qa_prepare_full_run() -> void:
	if not OS.is_debug_build():
		return
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(arena):
		return
	arena.player.invulnerability = 9999.0
	arena.set_meta("qa_auto_level", true)
	arena.wave_director.duration_scale = 0.01
	arena.spawn_director.qa_auto_defeat_bosses = true
	arena.spawn_director.qa_auto_defeat_delay = 0.08
	arena.announce("QA V1 full run: accelerated twelve-wave flow and automatic Boss validation", Color("ffd38a"))


func _qa_prepare_map_boss() -> void:
	if not OS.is_debug_build():
		return
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(arena):
		return
	arena.spawn_timer = 9999.0
	arena.player.invulnerability = 9999.0
	for zone_id in [&"mountain_gate", &"withered_forest", &"sutra_library", &"seal_hall"]:
		arena.backdrop.unlock_zone(zone_id)
	for gate in arena.backdrop.gates.values():
		(gate as ZoneGate).unlock()
	for event_id in [&"curse_lanterns", &"mist_zone", &"moving_curse", &"seal_pulse", &"seal_columns"]:
		arena.backdrop.trigger_environment_event(event_id)
	arena._start_boss()
	arena.announce("QA 地图/Boss：四区全开，五类危险激活，鬼面剑豪入场", Color("ffd38a"))


func _qa_prepare_story() -> void:
	if not OS.is_debug_build():
		return
	SaveManager.configure_storage_root_for_tests("user://tests/manual_story")
	var summaries: Array[SaveSlotSummary] = SaveManager.list_slots()
	var profile: ProfileData = GameState.load_profile(1) if summaries[0].exists else GameState.create_profile(1)
	if profile == null:
		return
	profile.story_flags.erase(&"prologue")
	GameState.save_current(&"qa_story_seed")
	selected_character_id = &"black_sword"
	_start_game()


func _qa_show_meta_progression() -> void:
	if not OS.is_debug_build():
		return
	SaveManager.configure_storage_root_for_tests("user://tests/manual_meta_progression")
	var summaries: Array[SaveSlotSummary] = SaveManager.list_slots()
	var profile: ProfileData = GameState.load_profile(1) if summaries[0].exists else GameState.create_profile(1)
	if profile == null:
		return
	profile.night_embers = maxi(profile.night_embers, 5000)
	GameState.save_current(&"qa_meta_seed")
	selected_character_id = profile.selected_character_id
	_show_meta_progression("QA 验收档：已提供 5000 测试夜烬，不影响正式存档")


func _qa_show_characters() -> void:
	if not OS.is_debug_build():
		return
	SaveManager.configure_storage_root_for_tests("user://tests/manual_characters")
	var summaries: Array[SaveSlotSummary] = SaveManager.list_slots()
	var profile: ProfileData = GameState.load_profile(1) if summaries[0].exists else GameState.create_profile(1)
	if profile == null:
		return
	profile.night_embers = maxi(profile.night_embers, 5000)
	for definition in ContentDatabase.all_characters().values():
		var character := definition as CharacterDefinition
		if character.id not in profile.unlocked_characters and character.id not in profile.available_character_unlocks:
			profile.available_character_unlocks.append(character.id)
	GameState.save_current(&"qa_character_seed")
	selected_character_id = profile.selected_character_id
	_show_character_selection("QA 验收档：所有角色均可支付解锁，使用独立测试存档")


func _qa_prepare_items() -> void:
	if not OS.is_debug_build():
		return
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(arena):
		return
	arena.spawn_timer = 9999.0
	arena.player.health = arena.player.max_health * 0.45
	arena.player.health_changed.emit(arena.player.health, arena.player.max_health)
	for index in range(6):
		arena.spawn_experience_orb(arena.player.global_position + Vector2.from_angle(TAU * float(index) / 6.0) * 150.0, 3)
	arena.spawn_enemy(&"corpse", arena.player.global_position + Vector2(230, 0), false)
	arena.spawn_enemy(&"corpse", arena.player.global_position + Vector2(285, 45), true)
	var queue: Array[StringName] = [&"healing_salve", &"soul_talisman", &"soul_bell", &"binding_talisman", &"soul_wine"]
	arena.item_drop_system.set_meta("qa_item_queue", queue)
	arena.item_drop_system.set_meta("qa_item_spawn_index", 0)
	arena.item_drop_system.item_collected.connect(_qa_fill_item_pickups.bind(arena.item_drop_system))
	_qa_fill_item_pickups(&"", arena.item_drop_system)
	arena.announce("QA 道具验收：靠近光圈依次拾取五种道具", Color("ffd38a"))


func _qa_fill_item_pickups(_collected_id: StringName, drop_system: ItemDropSystem) -> void:
	if not OS.is_debug_build() or not is_instance_valid(drop_system):
		return
	var queue: Array = drop_system.get_meta("qa_item_queue", [])
	var spawn_index := int(drop_system.get_meta("qa_item_spawn_index", 0))
	var offsets := [Vector2(-120, 105), Vector2(0, 105), Vector2(120, 105), Vector2(-70, 180), Vector2(70, 180)]
	while not queue.is_empty() and drop_system.active_pickups.size() < ItemDropSystem.MAX_ACTIVE_PICKUPS:
		var id := StringName(queue.pop_front())
		var offset: Vector2 = offsets[mini(spawn_index, offsets.size() - 1)]
		drop_system.spawn_item(id, arena.player.global_position + offset, true)
		spawn_index += 1
	drop_system.set_meta("qa_item_queue", queue)
	drop_system.set_meta("qa_item_spawn_index", spawn_index)


func _input(event: InputEvent) -> void:
	if save_select_open:
		if event.is_action_pressed("pause"):
			_show_title()
		return
	if character_select_open:
		if event.is_action_pressed("choose_1"):
			_select_character(&"black_sword")
		elif event.is_action_pressed("choose_2"):
			_select_character(&"minato")
		elif event.is_action_pressed("choose_3"):
			_select_character(&"ning_shuanghua")
		elif event.is_action_pressed("pause"):
			if GameState.has_current_profile():
				_show_hub()
			else:
				_show_title()
		return
	if hub_open and event.is_action_pressed("pause"):
		_show_save_selection()
		return
	if leveling:
		if event.is_action_pressed("choose_1"):
			_choose_level_option(0)
		elif event.is_action_pressed("choose_2"):
			_choose_level_option(1)
		elif event.is_action_pressed("choose_3"):
			_choose_level_option(2)
		return
	if game_running and event.is_action_pressed("pause"):
		_toggle_pause()


func _build_theme() -> void:
	game_theme.default_font = UI_FONT
	game_theme.default_font_size = 20
	game_theme.set_color("font_color", "Label", Color("eaf1ff"))
	game_theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.72))
	game_theme.set_constant("shadow_offset_x", "Label", 2)
	game_theme.set_constant("shadow_offset_y", "Label", 2)
	game_theme.set_font_size("font_size", "Button", 22)
	game_theme.set_color("font_color", "Button", Color("f5f0e1"))
	game_theme.set_color("font_hover_color", "Button", Color("ffffff"))
	game_theme.set_stylebox("normal", "Button", _style_box(Color("202c42"), Color("536a8e"), 2, 10))
	game_theme.set_stylebox("hover", "Button", _style_box(Color("30415e"), Color("8fa8d0"), 3, 10))
	game_theme.set_stylebox("pressed", "Button", _style_box(Color("172237"), Color("d5e2ff"), 2, 10))
	game_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	game_theme.set_stylebox("panel", "PanelContainer", _style_box(Color(0.055, 0.075, 0.12, 0.94), Color("40516e"), 2, 12, 22))


func _style_box(fill: Color, border: Color, width: int, radius: int, content: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = content
	style.content_margin_right = content
	style.content_margin_top = content
	style.content_margin_bottom = content
	return style


func _clear_ui() -> void:
	_release_virtual_movement()
	evolving = false
	evolution_options.clear()
	evolution_chest_id = &""
	story_open = false
	pending_story_ids.clear()
	for child in ui_root.get_children():
		child.queue_free()
	modal_overlay = null
	hud_root = null
	movement_joystick = null
	touch_pause_button = null


func _clear_world() -> void:
	for child in world_holder.get_children():
		child.queue_free()
	arena = null


func _show_title() -> void:
	game_running = false
	orientation_pause_active = false
	character_select_open = false
	save_select_open = false
	hub_open = false
	leveling = false
	pause_open = false
	get_tree().paused = false
	_clear_world()
	_clear_ui()
	_play_music(&"battle", -12.0)
	var background := ColorRect.new()
	background.color = Color("0a101c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(background)
	var moon := Panel.new()
	moon.position = Vector2(870, 80)
	moon.size = Vector2(250, 250)
	moon.add_theme_stylebox_override("panel", _style_box(Color("dce8ef"), Color("7c91a5"), 5, 125, 0))
	background.add_child(moon)
	var mist := ColorRect.new()
	mist.position = Vector2(0, 500)
	mist.size = Vector2(1280, 220)
	mist.color = Color(0.2, 0.3, 0.42, 0.18)
	background.add_child(mist)
	var portrait := TextureRect.new()
	portrait.texture = HERO_PORTRAIT
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(750, 190)
	portrait.size = Vector2(390, 390)
	background.add_child(portrait)
	var main_margin := MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 84)
	main_margin.add_theme_constant_override("margin_top", 70)
	main_margin.add_theme_constant_override("margin_right", 84)
	main_margin.add_theme_constant_override("margin_bottom", 48)
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(main_margin)
	var content := VBoxContainer.new()
	content.theme = game_theme
	content.add_theme_constant_override("separation", 12)
	main_margin.add_child(content)
	var eyebrow := _label("八分钟武侠生存试炼", 22, Color("9eb2cf"))
	content.add_child(eyebrow)
	var title := _label("黑剑·荒寺夜行", 62, Color("f2ead7"))
	content.add_child(title)
	var subtitle := _label("风过荒寺，百鬼夜行。唯有一剑，可破黎明。", 24, Color("b9c6d8"))
	content.add_child(subtitle)
	content.add_child(_spacer(26))
	var start := _button("选择存档", Vector2(310, 58))
	start.name = "OpenSaveSelectionButton"
	start.pressed.connect(func() -> void: _play_sfx(&"ui"); _show_save_selection())
	content.add_child(start)
	var help := _button("玩法说明", Vector2(310, 54))
	content.add_child(help)
	var help_text := _label("WASD / 方向键移动 · 招式自动释放\n升级时鼠标点击或按 1 / 2 / 3 · Esc 暂停", 19, Color("aebbd0"))
	help_text.visible = false
	content.add_child(help_text)
	help.pressed.connect(func() -> void: _play_sfx(&"ui"); help_text.visible = not help_text.visible)
	content.add_child(_spacer(10))
	var volume_panel := PanelContainer.new()
	volume_panel.custom_minimum_size = Vector2(420, 128)
	content.add_child(volume_panel)
	var volume_box := VBoxContainer.new()
	volume_box.add_theme_constant_override("separation", 8)
	volume_panel.add_child(volume_box)
	volume_box.add_child(_volume_row("音乐", &"Music"))
	volume_box.add_child(_volume_row("音效", &"SFX"))
	content.add_child(_spacer(6))
	var credits := _label("CC0 美术与音频：Pixel-Boy & AAA · 引擎：Godot 4.7", 16, Color("77879f"))
	content.add_child(credits)


func _show_save_selection(notice: String = "") -> void:
	game_running = false
	save_select_open = true
	hub_open = false
	character_select_open = false
	leveling = false
	pause_open = false
	get_tree().paused = false
	_clear_world()
	_clear_ui()
	var background := ColorRect.new()
	background.name = "SaveSelectionBackground"
	background.color = Color("080f1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)
	var header := _label("三盏守夜灯", 42, Color("f2ead7"))
	header.position = Vector2(0, 28)
	header.size = Vector2(1280, 58)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(header)
	var hint := _label("每盏灯保存独立的角色、养成与故事进度", 18, Color("9fb2cc"))
	hint.position = Vector2(0, 82)
	hint.size = Vector2(1280, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(hint)
	var notice_label := _label(notice, 17, Color("ffd38a"))
	notice_label.name = "SaveNoticeLabel"
	notice_label.position = Vector2(100, 116)
	notice_label.size = Vector2(1080, 28)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(notice_label)
	var cards := HBoxContainer.new()
	cards.name = "SaveSlotCards"
	cards.position = Vector2(70, 158)
	cards.size = Vector2(1140, 430)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 24)
	background.add_child(cards)
	for summary in SaveManager.list_slots():
		cards.add_child(_save_slot_card(summary))
	var back := _button("返回标题", Vector2(240, 48))
	back.name = "BackToTitleButton"
	back.position = Vector2(520, 632)
	back.pressed.connect(_show_title)
	background.add_child(back)


func _save_slot_card(summary: SaveSlotSummary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "SaveSlotCard%d" % summary.slot_index
	panel.custom_minimum_size = Vector2(350, 410)
	panel.theme = game_theme
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var current_marker := " · 当前" if GameState.current_slot_index() == summary.slot_index else ""
	var title := _label("守夜灯 %d%s" % [summary.slot_index, current_marker], 28, Color("f2ead7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	if not summary.exists:
		var empty_text := _label("未点燃\n此档位尚无记录", 19, Color("8392a8"))
		empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_text.custom_minimum_size.y = 130
		column.add_child(empty_text)
		var create_button := _button("点燃此灯", Vector2(270, 52))
		create_button.name = "CreateSlot%dButton" % summary.slot_index
		create_button.pressed.connect(_create_or_load_slot.bind(summary.slot_index))
		column.add_child(create_button)
	else:
		var status_text := "记录损坏"
		if summary.recoverable:
			status_text = "可从上一次完整记录恢复"
		elif not summary.corrupt:
			var updated := Time.get_datetime_string_from_unix_time(summary.updated_at_unix, true).replace("T", " ")
			status_text = "上次记录  %s\n游玩时间  %s\n挑战 %d 次 · 胜利 %d 次" % [updated, _format_play_time(summary.play_seconds), summary.runs, summary.victories]
		var status := _label(status_text, 17, Color("ff9b9b") if summary.corrupt else Color("b9c8dc"))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size = Vector2(300, 130)
		column.add_child(status)
		if not summary.corrupt or summary.recoverable:
			var load_button := _button("恢复并进入" if summary.recoverable else "进入此档", Vector2(270, 50))
			load_button.name = "LoadSlot%dButton" % summary.slot_index
			load_button.pressed.connect(_create_or_load_slot.bind(summary.slot_index))
			column.add_child(load_button)
		var export_button := _button("导出灯火", Vector2(270, 44))
		export_button.name = "ExportSlot%dButton" % summary.slot_index
		export_button.disabled = summary.corrupt and not summary.recoverable
		export_button.pressed.connect(_export_slot.bind(summary.slot_index))
		column.add_child(export_button)
		var delete_button := _button("熄灭此灯", Vector2(270, 42))
		delete_button.name = "DeleteSlot%dButton" % summary.slot_index
		delete_button.pressed.connect(_request_delete_slot.bind(summary.slot_index))
		column.add_child(delete_button)
	var import_button := _button("导入灯火", Vector2(270, 42))
	import_button.name = "ImportSlot%dButton" % summary.slot_index
	import_button.pressed.connect(_import_slot.bind(summary.slot_index))
	column.add_child(import_button)
	return panel


func _create_or_load_slot(slot_index: int) -> void:
	var summaries: Array[SaveSlotSummary] = SaveManager.list_slots()
	var summary := summaries[slot_index - 1]
	var profile: ProfileData = GameState.load_profile(slot_index) if summary.exists else GameState.create_profile(slot_index)
	if profile == null:
		_show_save_selection(SaveManager.last_error_message)
		return
	selected_character_id = profile.selected_character_id
	var recovery_notice: String = SaveManager.last_recovery_message
	_show_hub()
	if not recovery_notice.is_empty():
		var recovery_label := _label(recovery_notice, 17, Color("ffd38a"))
		recovery_label.name = "RecoveryNoticeLabel"
		recovery_label.position = Vector2(100, 126)
		recovery_label.size = Vector2(1080, 28)
		recovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui_root.add_child(recovery_label)


func _show_hub(notice: String = "") -> void:
	game_running = false
	save_select_open = false
	character_select_open = false
	hub_open = true
	leveling = false
	pause_open = false
	get_tree().paused = false
	_clear_world()
	_clear_ui()
	var profile: ProfileData = GameState.current_profile
	if profile == null:
		_show_save_selection("请先选择一盏守夜灯")
		return
	var background := ColorRect.new()
	background.name = "HubBackground"
	background.color = Color("080f1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)
	var title := _label("守夜庭 · 灯火未熄", 42, Color("f2ead7"))
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(title)
	var profile_text := _label("守夜灯 %d    夜烬  %d" % [profile.slot_index, profile.night_embers], 25, Color("ffd38a"))
	profile_text.name = "HubNightEmbersLabel"
	profile_text.position = Vector2(0, 92)
	profile_text.size = Vector2(1280, 38)
	profile_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(profile_text)
	var notice_label := _label(notice, 17, Color("9fd7b0"))
	notice_label.name = "HubNoticeLabel"
	notice_label.position = Vector2(100, 132)
	notice_label.size = Vector2(1080, 28)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(notice_label)
	var levels := profile.meta_upgrades
	var progression := _label(
		"局外养成  攻击 %d/10 · 生命 %d/10 · 悟性 %d/5 · 复生 %d/3" % [
			int(levels.get("attack", 0)), int(levels.get("health", 0)),
			int(levels.get("insight", 0)), int(levels.get("revive", 0)),
		],
		20,
		Color("b9c8dc")
	)
	progression.name = "HubProgressionSummary"
	progression.position = Vector2(0, 188)
	progression.size = Vector2(1280, 36)
	progression.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(progression)
	var panel := PanelContainer.new()
	panel.position = Vector2(390, 248)
	panel.size = Vector2(500, 350)
	panel.theme = game_theme
	background.add_child(panel)
	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	panel.add_child(actions)
	var challenge := _button("开始挑战", Vector2(360, 62))
	challenge.name = "StartChallengeButton"
	challenge.pressed.connect(_show_character_selection)
	actions.add_child(challenge)
	var progression_button := _button("夜烬养成", Vector2(360, 58))
	progression_button.name = "OpenMetaProgressionButton"
	progression_button.pressed.connect(_show_meta_progression)
	actions.add_child(progression_button)
	var story_button := _button("故事档案", Vector2(360, 54))
	story_button.name = "OpenStoryArchiveButton"
	story_button.pressed.connect(_show_story_archive)
	actions.add_child(story_button)
	var switch_slot := _button("切换守夜灯", Vector2(360, 54))
	switch_slot.name = "SwitchSaveSlotButton"
	switch_slot.pressed.connect(_show_save_selection)
	actions.add_child(switch_slot)
	var back := _button("返回标题", Vector2(260, 46))
	back.name = "HubBackToTitleButton"
	back.position = Vector2(510, 625)
	back.pressed.connect(func() -> void: GameState.save_current(&"return_to_title"); _show_title())
	background.add_child(back)


func _show_story_archive() -> void:
	if not GameState.has_current_profile():
		return
	game_running = false
	hub_open = false
	get_tree().paused = false
	_clear_world()
	_clear_ui()
	var background := ColorRect.new()
	background.name = "StoryArchiveBackground"
	background.color = Color("080f1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)
	var title := _label("故事档案 · 长夜残响", 40, Color("f2ead7"))
	title.position = Vector2(0, 28)
	title.size = Vector2(1280, 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(250, 105)
	scroll.size = Vector2(780, 500)
	background.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.name = "StoryArchiveEntries"
	entries.custom_minimum_size.x = 750
	entries.add_theme_constant_override("separation", 10)
	scroll.add_child(entries)
	var stories := ContentDatabase.all_stories().values()
	stories.sort_custom(func(a: StoryEventDefinition, b: StoryEventDefinition) -> bool: return a.id < b.id)
	for value in stories:
		var story := value as StoryEventDefinition
		var read := GameState.has_story_flag(story.id)
		var button := _button(("已读 · " + story.title) if read else "未解锁的残响", Vector2(730, 54))
		button.name = "StoryEntry_" + String(story.id)
		button.disabled = not read
		if read:
			button.pressed.connect(_show_story_event.bind(story.id, true))
		entries.add_child(button)
	var back := _button("返回守夜庭", Vector2(260, 50))
	back.position = Vector2(510, 630)
	back.pressed.connect(_show_hub)
	background.add_child(back)


func _show_meta_progression(notice: String = "") -> void:
	if not GameState.has_current_profile():
		_show_save_selection("请先选择存档")
		return
	game_running = false
	hub_open = false
	character_select_open = false
	get_tree().paused = false
	_clear_world()
	_clear_ui()
	var background := ColorRect.new()
	background.name = "MetaProgressionBackground"
	background.color = Color("080f1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)
	var title := _label("夜烬养成", 42, Color("f2ead7"))
	title.position = Vector2(0, 24)
	title.size = Vector2(1280, 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(title)
	var currency := _label("持有夜烬  %d" % GameState.current_profile.night_embers, 24, Color("ffd38a"))
	currency.name = "MetaNightEmbersLabel"
	currency.position = Vector2(0, 80)
	currency.size = Vector2(1280, 36)
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(currency)
	var notice_label := _label(notice, 17, Color("9fd7b0") if not notice.contains("不足") else Color("ff9b9b"))
	notice_label.name = "MetaNoticeLabel"
	notice_label.position = Vector2(100, 116)
	notice_label.size = Vector2(1080, 26)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(notice_label)
	var cards := HBoxContainer.new()
	cards.name = "MetaUpgradeCards"
	cards.position = Vector2(42, 168)
	cards.size = Vector2(1196, 360)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	background.add_child(cards)
	for id in [&"attack", &"health", &"insight", &"revive"]:
		cards.add_child(_meta_upgrade_card(ContentDatabase.meta_upgrade(id)))
	var reset := _button("免费重置并返还 %d 夜烬" % GameState.meta_investment_total(), Vector2(330, 48))
	reset.name = "ResetMetaUpgradesButton"
	reset.position = Vector2(285, 600)
	reset.pressed.connect(_request_meta_reset)
	background.add_child(reset)
	var back := _button("返回守夜庭", Vector2(280, 48))
	back.name = "BackToHubButton"
	back.position = Vector2(665, 600)
	back.pressed.connect(_show_hub)
	background.add_child(back)


func _meta_upgrade_card(definition: MetaUpgradeDefinition) -> Control:
	if definition == null:
		var missing := PanelContainer.new()
		missing.custom_minimum_size = Vector2(275, 340)
		missing.add_child(_label("养成数据缺失", 18, Color("ff9b9b")))
		return missing
	var panel := PanelContainer.new()
	panel.name = "MetaUpgradeCard_" + String(definition.id)
	panel.custom_minimum_size = Vector2(275, 340)
	panel.theme = game_theme
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 13)
	panel.add_child(column)
	var level := int(GameState.current_profile.meta_upgrades.get(String(definition.id), 0))
	var title := _label(definition.display_name, 29, Color("f2ead7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var level_label := _label(str(level) + " / " + str(definition.max_level) + " 级", 21, Color("9fc5ef"))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(level_label)
	var description := _label(definition.description, 16, Color("b9c8dc"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.custom_minimum_size = Vector2(235, 92)
	column.add_child(description)
	var effect_panel := PanelContainer.new()
	effect_panel.name = "MetaCurrentEffectPanel_" + String(definition.id)
	effect_panel.custom_minimum_size = Vector2(235, 76)
	effect_panel.add_theme_stylebox_override("panel", _style_box(Color("0b1726"), Color("365778"), 1, 8, 7))
	column.add_child(effect_panel)
	var effect := RichTextLabel.new()
	effect.name = "MetaCurrentEffect_" + String(definition.id)
	effect.theme = game_theme
	effect.bbcode_enabled = true
	effect.fit_content = true
	effect.scroll_active = false
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.custom_minimum_size = Vector2(220, 60)
	effect.text = _meta_effect_bbcode(definition, level)
	effect_panel.add_child(effect)
	var cost := definition.cost_for_next_level(level)
	var purchase := _button("已满级" if cost < 0 else "提升 · " + str(cost) + " 夜烬", Vector2(230, 50))
	purchase.name = "PurchaseMeta_" + String(definition.id)
	purchase.disabled = cost < 0
	purchase.pressed.connect(_purchase_meta_upgrade.bind(definition.id))
	column.add_child(purchase)
	return panel


func _meta_effect_bbcode(definition: MetaUpgradeDefinition, level: int) -> String:
	if level <= 0:
		return "[center][color=#8b9bb1]当前效果[/color]\n[color=#66778e]尚未修习[/color][/center]"
	var stats := definition.stats(level)
	match definition.id:
		&"attack":
			return _meta_stat_bbcode("最终伤害", "+" + str(roundi(float(stats.get("damage", 0.0)) * 100.0)) + "%")
		&"health":
			return _meta_stat_bbcode("最大生命", "+" + str(roundi(float(stats.get("health", 0.0)) * 100.0)) + "%")
		&"insight":
			return _meta_stat_bbcode("经验获取", "+" + str(roundi(float(stats.get("experience", 0.0)) * 100.0)) + "%")
		&"revive":
			var health_value := str(roundi(float(stats.get("health", 0.0)) * 100.0)) + "%"
			var invulnerability_value := str(float(stats.get("invulnerability", 0.0))) + " 秒"
			return "[center][color=#9fb2cc][font_size=14]当前效果 · 每局一次复生[/font_size][/color]\n[color=#d7e2ef]恢复[/color] [color=#72e6a5][font_size=22]" + health_value + "[/font_size][/color] [color=#d7e2ef]生命  ·  无敌[/color] [color=#78d8ff][font_size=22]" + invulnerability_value + "[/font_size][/color][/center]"
	return "[center][color=#9fb2cc]当前等级[/color] [color=#72e6a5][font_size=22]" + str(level) + "[/font_size][/color][/center]"


func _meta_stat_bbcode(stat_name: String, value_text: String) -> String:
	return "[center][color=#9fb2cc][font_size=14]当前效果[/font_size][/color]\n[color=#d7e2ef][font_size=17]" + stat_name + "[/font_size][/color]  [color=#72e6a5][font_size=24][b]" + value_text + "[/b][/font_size][/color][/center]"


func _purchase_meta_upgrade(id: StringName) -> void:
	var error := GameState.purchase_meta_upgrade(id)
	var notice := "养成已提升"
	if error == ERR_UNAVAILABLE:
		notice = "夜烬不足"
	elif error == ERR_CANT_ACQUIRE_RESOURCE:
		notice = "此分支已满级"
	elif error != OK:
		notice = "保存失败：%s" % _save_error_text(error)
	_show_meta_progression(notice)


func _request_meta_reset() -> void:
	var refund := GameState.meta_investment_total()
	if refund <= 0:
		_show_meta_progression("当前没有可重置的养成")
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "ResetMetaConfirmation"
	dialog.title = "重置夜烬养成"
	dialog.dialog_text = "将全部养成重置为 0 级，并返还 %d 夜烬。" % refund
	dialog.ok_button_text = "确认重置"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(func() -> void:
		var error := GameState.reset_meta_upgrades()
		_show_meta_progression("已返还 %d 夜烬" % refund if error == OK else "重置失败：%s" % _save_error_text(error))
	)
	background_add_dialog(dialog)


func background_add_dialog(dialog: Window) -> void:
	ui_root.add_child(dialog)
	dialog.popup_centered(Vector2i(540, 240))


func _request_delete_slot(slot_index: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "DeleteSlot%dConfirmation" % slot_index
	dialog.title = "熄灭守夜灯"
	dialog.dialog_text = "此操作会永久删除存档 %d 的全部记录，且无法撤销。" % slot_index
	dialog.ok_button_text = "确认删除"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(func() -> void: _delete_slot_immediately(slot_index))
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	ui_root.add_child(dialog)
	dialog.popup_centered(Vector2i(520, 220))


func _delete_slot_immediately(slot_index: int) -> void:
	var error := GameState.delete_profile(slot_index)
	_show_save_selection("存档 %d 已删除" % slot_index if error == OK else SaveManager.last_error_message)


func _export_slot(slot_index: int) -> void:
	var file_name := "black_sword_slot_%d_%d.json" % [slot_index, int(Time.get_unix_time_from_system())]
	if OS.has_feature("web"):
		var json_text: String = SaveManager.export_slot_json(slot_index)
		if json_text.is_empty():
			_show_save_selection(SaveManager.last_error_message)
			return
		JavaScriptBridge.download_buffer(json_text.to_utf8_buffer(), file_name, "application/json")
		_show_save_selection("存档 %d 已交给浏览器下载" % slot_index)
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; 黑剑存档"])
	dialog.current_file = file_name
	dialog.file_selected.connect(func(path: String) -> void:
		var error := SaveManager.export_slot(slot_index, path)
		_show_save_selection("存档已导出" if error == OK else SaveManager.last_error_message)
	)
	ui_root.add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _import_slot(slot_index: int) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; 黑剑存档"])
	dialog.file_selected.connect(func(path: String) -> void: _finish_import_slot(slot_index, path))
	ui_root.add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _finish_import_slot(slot_index: int, path: String) -> void:
	var profile: ProfileData = SaveManager.import_slot(slot_index, path)
	if profile == null:
		_show_save_selection(SaveManager.last_error_message)
		return
	if GameState.current_slot_index() == slot_index:
		GameState.load_profile(slot_index)
	_show_save_selection("存档 %d 已导入" % slot_index)


func _format_play_time(total_seconds: int) -> String:
	return "%02d:%02d:%02d" % [int(total_seconds / 3600), int(total_seconds / 60) % 60, total_seconds % 60]


func _show_character_selection(notice: String = "") -> void:
	game_running = false
	save_select_open = false
	hub_open = false
	character_select_open = true
	leveling = false
	pause_open = false
	get_tree().paused = false
	_clear_world()
	_clear_ui()
	var background := ColorRect.new()
	background.name = "CharacterSelectionBackground"
	background.color = Color("080f1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)
	var header := _label("择一人 · 夜闯荒寺", 42, Color("f2ead7"))
	header.position = Vector2(0, 34)
	header.size = Vector2(1280, 64)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(header)
	var hint := _label("点击角色卡选择；未解锁角色会明确显示条件与夜烬费用", 18, Color("9fb2cc"))
	hint.position = Vector2(0, 94)
	hint.size = Vector2(1280, 36)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(hint)
	var notice_label := _label(notice, 16, Color("9fd7b0") if not notice.contains("不足") and not notice.contains("失败") else Color("ff9b9b"))
	notice_label.name = "CharacterSelectionNotice"
	notice_label.position = Vector2(80, 126)
	notice_label.size = Vector2(1120, 26)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background.add_child(notice_label)
	var cards := GridContainer.new()
	cards.name = "CharacterCards"
	cards.columns = 5
	cards.position = Vector2(38, 158)
	cards.size = Vector2(1204, 448)
	cards.add_theme_constant_override("h_separation", 14)
	background.add_child(cards)
	var definitions := _ordered_characters()
	for index in range(definitions.size()):
		cards.add_child(_character_card(definitions[index], index + 1))
	var back := _button("返回守夜庭" if GameState.has_current_profile() else "返回标题", Vector2(240, 48))
	back.name = "BackToTitleButton"
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.offset_left = -120
	back.offset_top = -84
	back.offset_right = 120
	back.offset_bottom = -36
	back.pressed.connect(_show_hub if GameState.has_current_profile() else _show_title)
	background.add_child(back)


func _character_card(definition: CharacterDefinition, display_index: int) -> Button:
	var id := definition.id
	var accent := definition.accent
	var unlocked := definition.unlock_condition_id == &"default" if not GameState.has_current_profile() else GameState.is_character_unlocked(id)
	var available := GameState.is_character_unlock_available(id)
	var card := _button("", Vector2(226, 438))
	card.name = "CharacterCard_" + String(id)
	card.add_theme_stylebox_override("normal", _style_box(Color("111a2a"), Color(accent, 0.72), 3, 14, 18))
	card.add_theme_stylebox_override("hover", _style_box(Color("1b2b43"), accent, 4, 14, 18))
	card.add_theme_stylebox_override("disabled", _style_box(Color("0b101b"), Color("354158"), 2, 14, 18))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var portrait := TextureRect.new()
	portrait.texture = _character_portrait_texture(definition)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if definition.id == &"black_sword" else CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(194, 170)
	portrait.modulate = Color.WHITE if unlocked or available else Color(0.20, 0.24, 0.31, 0.78)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)
	var name_label := _label("%d · %s" % [display_index, definition.display_name], 21, Color("f6f1e5"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var initial_skill := ContentDatabase.skill(definition.initial_skill_id)
	var skill_name := String(definition.initial_skill_id) if initial_skill == null else initial_skill.display_name
	var skill_label := _label("初始：" + skill_name, 16, accent)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(skill_label)
	var description_label := _label(definition.description, 13, Color("b6c4d8"))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(198, 48)
	column.add_child(description_label)
	var trait_label := _label(definition.trait_description, 13, Color("9fd7b0"))
	trait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_label.custom_minimum_size = Vector2(198, 40)
	column.add_child(trait_label)
	var state_text := "已解锁 · 点击出战"
	var state_color := Color("72e6a5")
	if not unlocked and available:
		state_text = "可解锁 · %d 夜烬" % definition.unlock_cost
		state_color = Color("ffd38a")
	elif not unlocked:
		state_text = "%s\n费用 %d 夜烬" % [definition.unlock_description, definition.unlock_cost]
		state_color = Color("8392a8")
	var state_label := _label(state_text, 14, state_color)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.custom_minimum_size = Vector2(198, 44)
	column.add_child(state_label)
	card.disabled = not unlocked and not available
	if unlocked:
		card.pressed.connect(_select_character.bind(id))
	elif available:
		card.pressed.connect(_unlock_character.bind(id))
	return card


func _ordered_characters() -> Array[CharacterDefinition]:
	var result: Array[CharacterDefinition] = []
	for value in ContentDatabase.all_characters().values():
		result.append(value as CharacterDefinition)
	result.sort_custom(func(a: CharacterDefinition, b: CharacterDefinition) -> bool: return a.sort_order < b.sort_order)
	return result


func _character_portrait_texture(definition: CharacterDefinition) -> Texture2D:
	if definition.portrait_region.size.x <= 0.0 or definition.portrait_region.size.y <= 0.0:
		return definition.portrait
	var portrait := AtlasTexture.new()
	portrait.atlas = definition.portrait
	portrait.region = definition.portrait_region
	return portrait


func _unlock_character(id: StringName) -> void:
	var definition := ContentDatabase.character(id)
	var error := GameState.unlock_character(id)
	if error == OK:
		_show_character_selection("%s 已解锁" % definition.display_name)
	elif error == ERR_CANT_ACQUIRE_RESOURCE:
		_show_character_selection("夜烬不足：解锁 %s 需要 %d 夜烬" % [definition.display_name, definition.unlock_cost])
	elif error == ERR_UNAVAILABLE:
		_show_character_selection("尚未达成解锁条件：%s" % definition.unlock_description)
	else:
		_show_character_selection("角色解锁保存失败：%s" % _save_error_text(error))


func _select_character(id: StringName) -> void:
	var definition := ContentDatabase.character(id)
	if definition == null:
		return
	if GameState.has_current_profile() and not GameState.is_character_unlocked(id):
		_show_character_selection("%s 尚未解锁" % definition.display_name)
		return
	if not GameState.has_current_profile() and definition.unlock_condition_id != &"default":
		_show_character_selection("请先选择存档并解锁角色")
		return
	selected_character_id = id
	if GameState.has_current_profile():
		var save_error := GameState.select_character(id)
		if save_error != OK:
			_show_character_selection("角色选择保存失败：%s" % _save_error_text(save_error))
			return
	character_select_open = false
	_play_sfx(&"ui")
	_start_game()


func _volume_row(title: String, bus: StringName) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(390, 36)
	var label := _label(title, 18, Color("dce5f3"))
	label.custom_minimum_size.x = 70
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(285, 28)
	slider.min_value = -36.0
	slider.max_value = 0.0
	slider.step = 1.0
	var bus_index := AudioServer.get_bus_index(bus)
	slider.value = AudioServer.get_bus_volume_db(bus_index)
	slider.value_changed.connect(func(value: float) -> void: AudioServer.set_bus_volume_db(bus_index, value))
	row.add_child(slider)
	return row


func _start_game() -> void:
	get_tree().paused = false
	save_select_open = false
	character_select_open = false
	hub_open = false
	_clear_world()
	_clear_ui()
	game_running = true
	orientation_pause_active = false
	arena = BATTLE_ARENA_SCENE.instantiate() as Arena
	arena.selected_character_id = selected_character_id
	arena.run_config = GameState.build_run_config(selected_character_id)
	current_run_result = null
	world_holder.add_child(arena)
	_connect_arena()
	_build_hud()
	_refresh_hud_from_arena()
	if GameState.has_current_profile():
		call_deferred("_show_story_event", &"prologue")


func _refresh_hud_from_arena() -> void:
	if not is_instance_valid(arena):
		return
	_update_health(arena.player.health, arena.player.max_health)
	_update_xp(arena.current_xp, arena.required_xp, arena.player_level)
	_update_skills(arena.skill_system.levels, arena.skill_system.active_ids, arena.skill_system.passive_ids)
	_update_temporary_item_effects(arena.current_temporary_item_effects())
	_update_chest_count()


func _connect_arena() -> void:
	arena.player_health_changed.connect(_update_health)
	arena.xp_changed.connect(_update_xp)
	arena.stats_changed.connect(_update_stats)
	arena.skills_changed.connect(_update_skills)
	arena.temporary_item_effects_changed.connect(_update_temporary_item_effects)
	arena.level_up_requested.connect(_show_level_up)
	arena.evolution_requested.connect(_show_evolution)
	arena.story_event_requested.connect(_show_story_event)
	arena.evolution_system.chest_spawned.connect(func(_id: StringName) -> void: _update_chest_count())
	arena.evolution_system.evolution_applied.connect(func(_chest: StringName, _skill: StringName) -> void: _update_chest_count())
	arena.boss_spawned.connect(_show_boss)
	arena.boss_health_changed.connect(_update_boss_health)
	arena.announcement.connect(_show_announcement)
	arena.run_ended.connect(_show_result)
	arena.sfx_requested.connect(_play_sfx)
	arena.music_requested.connect(_play_music)


func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.theme = game_theme
	ui_root.add_child(hud_root)
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(24, 20)
	top_panel.size = Vector2(430, 104)
	hud_root.add_child(top_panel)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 5)
	top_panel.add_child(top_box)
	var hp_row := HBoxContainer.new()
	top_box.add_child(hp_row)
	var hp_title := _label("气血", 19, Color("f4d9d9"))
	hp_title.custom_minimum_size.x = 58
	hp_row.add_child(hp_title)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(325, 24)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.add_theme_stylebox_override("background", _style_box(Color("161d2b"), Color("3b4659"), 1, 5, 0))
	hp_bar.add_theme_stylebox_override("fill", _style_box(Color("b94155"), Color("ef7788"), 1, 5, 0))
	hp_row.add_child(hp_bar)
	hp_value_label = _label("100", 16, Color("fff4f4"))
	hp_value_label.name = "HealthValueLabel"
	hp_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_child(hp_value_label)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 18)
	top_box.add_child(info_row)
	level_label = _label("境界 1", 18, Color("ffe69b"))
	timer_label = _label("00:00", 18, Color("d6e3f5"))
	wave_label = _label("第一夜", 18, Color("b8c9df"))
	kills_label = _label("斩敌 0", 18, Color("b8c9df"))
	info_row.add_child(level_label)
	info_row.add_child(timer_label)
	info_row.add_child(wave_label)
	info_row.add_child(kills_label)
	skill_box = VBoxContainer.new()
	skill_box.name = "SkillInventorySlots"
	skill_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skill_box.offset_left = -650
	skill_box.offset_top = -178
	skill_box.offset_right = -24
	skill_box.offset_bottom = -46
	skill_box.alignment = BoxContainer.ALIGNMENT_END
	skill_box.add_theme_constant_override("separation", 5)
	hud_root.add_child(skill_box)
	item_effect_box = VBoxContainer.new()
	item_effect_box.name = "TemporaryItemEffects"
	item_effect_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	item_effect_box.offset_left = -330
	item_effect_box.offset_top = 82
	item_effect_box.offset_right = -24
	item_effect_box.offset_bottom = 190
	item_effect_box.alignment = BoxContainer.ALIGNMENT_END
	item_effect_box.add_theme_constant_override("separation", 6)
	hud_root.add_child(item_effect_box)
	boss_panel = PanelContainer.new()
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -250
	boss_panel.offset_top = 20
	boss_panel.offset_right = 250
	boss_panel.offset_bottom = 90
	boss_panel.visible = false
	hud_root.add_child(boss_panel)
	var boss_box := VBoxContainer.new()
	boss_box.add_theme_constant_override("separation", 3)
	boss_panel.add_child(boss_box)
	var boss_name := _label("鬼面剑豪", 20, Color("ffb0a3"))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size.y = 22
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("background", _style_box(Color("1a1721"), Color("614052"), 1, 5, 0))
	boss_bar.add_theme_stylebox_override("fill", _style_box(Color("a52743"), Color("ff6f74"), 1, 5, 0))
	boss_box.add_child(boss_bar)
	boss_value_label = _label("", 14, Color("f4d7d9"))
	boss_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_value_label.position.y = 39
	boss_panel.add_child(boss_value_label)
	xp_bar = ProgressBar.new()
	xp_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	xp_bar.offset_left = 24
	xp_bar.offset_top = -34
	xp_bar.offset_right = -24
	xp_bar.offset_bottom = -12
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", _style_box(Color("101827"), Color("344761"), 1, 5, 0))
	xp_bar.add_theme_stylebox_override("fill", _style_box(Color("4fb9d1"), Color("91ecff"), 1, 5, 0))
	hud_root.add_child(xp_bar)
	xp_label = _label("修为 0 / 11", 15, Color("d7f8ff"))
	xp_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	xp_label.offset_left = -130
	xp_label.offset_top = -58
	xp_label.offset_right = 130
	xp_label.offset_bottom = -36
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(xp_label)
	announcement_label = _label("", 30, Color.WHITE)
	announcement_label.position = Vector2(330, 138)
	announcement_label.size = Vector2(620, 54)
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.modulate.a = 0.0
	hud_root.add_child(announcement_label)
	chest_label = _label("悟道宝匣 0", 16, Color("d7c58a"))
	chest_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chest_label.offset_left = -250
	chest_label.offset_top = 198
	chest_label.offset_right = -24
	chest_label.offset_bottom = 230
	chest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_root.add_child(chest_label)
	movement_joystick = VIRTUAL_JOYSTICK_SCENE.instantiate() as MovementJoystick
	movement_joystick.visible = _touch_controls_supported()
	movement_joystick.direction_changed.connect(_on_virtual_movement_changed)
	hud_root.add_child(movement_joystick)
	touch_pause_button = _button("暂停", Vector2(112, 50))
	touch_pause_button.name = "TouchPauseButton"
	touch_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	touch_pause_button.offset_left = -136
	touch_pause_button.offset_top = 20
	touch_pause_button.offset_right = -24
	touch_pause_button.offset_bottom = 70
	touch_pause_button.visible = _touch_controls_supported()
	touch_pause_button.pressed.connect(_toggle_pause)
	hud_root.add_child(touch_pause_button)


func _touch_controls_supported() -> bool:
	return DisplayServer.is_touchscreen_available() or "--qa-touch" in OS.get_cmdline_user_args()


func _on_virtual_movement_changed(direction: Vector2) -> void:
	if is_instance_valid(arena) and is_instance_valid(arena.player):
		arena.player.set_virtual_move_input(direction)


func _release_virtual_movement() -> void:
	if is_instance_valid(movement_joystick):
		movement_joystick.reset_input()
	if is_instance_valid(arena) and is_instance_valid(arena.player):
		arena.player.set_virtual_move_input(Vector2.ZERO)


func _set_touch_movement_enabled(value: bool) -> void:
	if is_instance_valid(movement_joystick):
		movement_joystick.set_input_enabled(value)


func _update_health(current: float, maximum: float) -> void:
	if is_instance_valid(hp_bar):
		hp_bar.max_value = maximum
		hp_bar.value = current
	if is_instance_valid(hp_value_label):
		hp_value_label.text = str(roundi(current))


func _update_xp(current: int, required: int, level: int) -> void:
	if is_instance_valid(xp_bar):
		xp_bar.max_value = required
		xp_bar.value = current
	if is_instance_valid(level_label):
		level_label.text = "境界 %d" % level
	if is_instance_valid(xp_label):
		xp_label.text = "修为 %d / %d" % [current, required]


func _update_stats(elapsed: float, wave_title: String, kills: int) -> void:
	if not is_instance_valid(timer_label):
		return
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	wave_label.text = wave_title
	kills_label.text = "斩敌 %d" % kills


func _update_skills(levels: Dictionary, active_ids: Array[StringName], passive_ids: Array[StringName]) -> void:
	if not is_instance_valid(skill_box):
		return
	for child in skill_box.get_children():
		child.queue_free()
	_skill_slot_row("主动", active_ids, levels, Color("6ecbff"), "ActiveSkillRow")
	_skill_slot_row("心法", passive_ids, levels, Color("d4a7ff"), "PassiveSkillRow")


func _skill_slot_row(title: String, ids: Array[StringName], levels: Dictionary, row_color: Color, node_name: String) -> void:
	var row := HBoxContainer.new()
	row.name = node_name
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	var title_label := _label(title, 14, row_color)
	title_label.custom_minimum_size = Vector2(38, 52)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)
	for i in range(6):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(90, 54)
		if i < ids.size():
			var id := ids[i]
			var definition: SkillDefinition = arena.registry.skills[id]
			slot.add_theme_stylebox_override("panel", _style_box(Color(0.06, 0.08, 0.13, 0.94), Color(definition.accent, 0.7), 2, 7, 4))
			var label := _label("%s\n%s" % [_short_skill_name(definition.display_name), "◆".repeat(levels.get(id, 1))], 13, definition.accent)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(label)
		else:
			slot.add_theme_stylebox_override("panel", _style_box(Color(0.04, 0.055, 0.09, 0.8), Color(row_color, 0.28), 1, 7, 4))
			var empty := _label("空", 14, Color(row_color, 0.42))
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(empty)
		row.add_child(slot)
	skill_box.add_child(row)


func _update_temporary_item_effects(effects: Dictionary) -> void:
	if not is_instance_valid(item_effect_box):
		return
	for child in item_effect_box.get_children():
		child.queue_free()
	for id in effects:
		var definition := ContentDatabase.item(id)
		if definition == null:
			continue
		var effect: Dictionary = effects[id]
		var panel := PanelContainer.new()
		panel.name = "TemporaryItemEffect_" + String(id)
		panel.custom_minimum_size = Vector2(292, 48)
		panel.add_theme_stylebox_override("panel", _style_box(Color(0.04, 0.07, 0.12, 0.92), Color(definition.accent, 0.75), 2, 8, 6))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var icon := TextureRect.new()
		icon.texture = definition.icon
		icon.modulate = definition.accent
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(34, 34)
		row.add_child(icon)
		var remaining := float(effect.get("remaining", 0.0))
		var label := _label("%s  %.1f 秒\n伤害 +30%% · 冷却 -15%%" % [definition.display_name, remaining], 15, definition.accent)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		item_effect_box.add_child(panel)


func _short_skill_name(name: String) -> String:
	return name.replace("黑剑·", "").replace("心法", "").substr(0, 5)


func _show_level_up(level: int, options: Array[SkillDefinition]) -> void:
	if not game_running:
		return
	leveling = true
	level_options = options
	_release_virtual_movement()
	_set_touch_movement_enabled(false)
	get_tree().paused = true
	_play_sfx(&"level_up")
	modal_overlay = _modal_background()
	ui_root.add_child(modal_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -540
	panel.offset_top = -265
	panel.offset_right = 540
	panel.offset_bottom = 265
	panel.theme = game_theme
	modal_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := _label("境界突破 · 第 %d 重" % level, 36, Color("ffe6a6"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := _label("选择一项招式或心法继续修行（1 / 2 / 3）", 19, Color("9fb0c8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 22)
	box.add_child(cards)
	for i in range(options.size()):
		var definition := options[i]
		var current: int = arena.skill_system.levels.get(definition.id, 0)
		var card := _button("", Vector2(310, 350))
		card.add_theme_stylebox_override("normal", _style_box(Color("111a2b"), Color(definition.accent, 0.72), 3, 12, 18))
		card.add_theme_stylebox_override("hover", _style_box(Color("1b2940"), definition.accent, 4, 12, 18))
		var card_box := VBoxContainer.new()
		card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_theme_constant_override("separation", 14)
		card.add_child(card_box)
		var number := _label(str(i + 1), 22, definition.accent)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(number)
		var name := _label(definition.display_name, 26, Color("f4f0e6"))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(name)
		var rank_text := "新招式" if current == 0 else "第 %d → %d 重" % [current, current + 1]
		var rank := _label(rank_text, 18, definition.accent)
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(rank)
		var description := _label(definition.description + "\n\n" + definition.level_text(current), 18, Color("bdc9da"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(265, 145)
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(description)
		card.pressed.connect(_choose_level_option.bind(i))
		cards.add_child(card)


func _choose_level_option(index: int) -> void:
	if not leveling or index < 0 or index >= level_options.size():
		return
	var definition := level_options[index]
	_play_sfx(&"ui")
	leveling = false
	if is_instance_valid(modal_overlay):
		modal_overlay.queue_free()
	modal_overlay = null
	get_tree().paused = false
	arena.choose_upgrade(definition.id)
	_set_touch_movement_enabled(true)


func _show_evolution(chest_id: StringName, options: Array[EvolutionRecipe]) -> void:
	if not game_running or options.is_empty() or evolving:
		return
	evolving = true
	evolution_chest_id = chest_id
	evolution_options = options
	_release_virtual_movement()
	_set_touch_movement_enabled(false)
	get_tree().paused = true
	_play_sfx(&"level_up")
	modal_overlay = _modal_background()
	ui_root.add_child(modal_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -540
	panel.offset_top = -260
	panel.offset_right = 540
	panel.offset_bottom = 260
	modal_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := _label("悟道宝匣 · 招式进阶", 34, Color("ffe29a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 20)
	box.add_child(cards)
	for index in range(options.size()):
		var recipe := options[index]
		var evolved := ContentDatabase.skill(recipe.evolved_skill_id)
		var original := ContentDatabase.skill(recipe.active_skill_id)
		var card := _button("%s\n\n%s → %s\n\n%s" % [index + 1, original.display_name, evolved.display_name, evolved.description], Vector2(310, 350))
		card.add_theme_font_size_override("font_size", 20)
		card.add_theme_color_override("font_color", evolved.accent)
		card.pressed.connect(_choose_evolution.bind(index))
		cards.add_child(card)


func _choose_evolution(index: int) -> void:
	if not evolving or index < 0 or index >= evolution_options.size():
		return
	var recipe := evolution_options[index]
	var result := arena.choose_evolution(evolution_chest_id, recipe.evolved_skill_id)
	if not result.success:
		return
	evolving = false
	evolution_options.clear()
	evolution_chest_id = &""
	if is_instance_valid(modal_overlay):
		modal_overlay.queue_free()
	modal_overlay = null
	get_tree().paused = false
	_set_touch_movement_enabled(true)


func _show_story_event(id: StringName, force: bool = false) -> void:
	var definition := ContentDatabase.story(id)
	if definition == null:
		return
	var already_read := GameState.has_story_flag(id)
	if definition.once_per_profile and already_read and not force:
		return
	if story_open or leveling or evolving or pause_open:
		if id not in pending_story_ids:
			pending_story_ids.append(id)
		return
	story_open = true
	if definition.pause_battle and game_running:
		_release_virtual_movement()
		_set_touch_movement_enabled(false)
		get_tree().paused = true
	var overlay := STORY_OVERLAY_SCENE.instantiate() as StoryOverlay
	overlay.theme = game_theme
	ui_root.add_child(overlay)
	overlay.setup(definition, already_read)
	overlay.closed.connect(_on_story_closed.bind(definition.pause_battle))


func _on_story_closed(id: StringName, paused_battle: bool) -> void:
	story_open = false
	if GameState.has_current_profile():
		GameState.mark_story_flag(id)
	if paused_battle and game_running and not leveling and not evolving and not pause_open:
		get_tree().paused = false
		_set_touch_movement_enabled(true)
	if not pending_story_ids.is_empty():
		var next_id: StringName = pending_story_ids.pop_front()
		call_deferred("_show_story_event", next_id)


func _update_chest_count() -> void:
	if is_instance_valid(chest_label) and is_instance_valid(arena):
		chest_label.text = "悟道宝匣 %d" % arena.evolution_system.chests.size()


func _toggle_pause() -> void:
	if not game_running or leveling or evolving:
		return
	if pause_open:
		pause_open = false
		get_tree().paused = false
		if is_instance_valid(modal_overlay):
			modal_overlay.queue_free()
		modal_overlay = null
		_set_touch_movement_enabled(true)
		return
	pause_open = true
	_release_virtual_movement()
	_set_touch_movement_enabled(false)
	get_tree().paused = true
	modal_overlay = _modal_background()
	ui_root.add_child(modal_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_top = -210
	panel.offset_right = 210
	panel.offset_bottom = 210
	panel.theme = game_theme
	modal_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 15)
	panel.add_child(box)
	var title := _label("夜行暂歇", 38, Color("f4ead5"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := _button("继续", Vector2(300, 55))
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var restart := _button("重新开始", Vector2(300, 55))
	restart.pressed.connect(func() -> void: pause_open = false; get_tree().paused = false; _start_game())
	box.add_child(restart)
	var title_button := _button("结束本局并结算", Vector2(300, 55))
	title_button.pressed.connect(_end_run_from_pause)
	box.add_child(title_button)


func _end_run_from_pause() -> void:
	pause_open = false
	get_tree().paused = false
	if is_instance_valid(arena):
		arena.finish_run_as_failure()


func _show_boss(_boss: BossActor) -> void:
	if is_instance_valid(boss_panel):
		boss_panel.visible = true


func _update_boss_health(current: float, maximum: float) -> void:
	if not is_instance_valid(boss_bar):
		return
	boss_bar.max_value = maximum
	boss_bar.value = current
	boss_value_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _show_announcement(text: String, color: Color) -> void:
	if not is_instance_valid(announcement_label):
		return
	announcement_label.text = text
	announcement_label.modulate = Color(color, 0.0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(announcement_label, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.5)
	tween.tween_property(announcement_label, "modulate:a", 0.0, 0.45)


func _show_result(victory: bool, elapsed: float, level: int, kills: int) -> void:
	game_running = false
	leveling = false
	evolving = false
	pause_open = false
	_release_virtual_movement()
	_set_touch_movement_enabled(false)
	get_tree().paused = true
	current_run_result = arena.last_run_result if is_instance_valid(arena) else null
	if current_run_result == null:
		current_run_result = RunResult.new()
		current_run_result.character_id = selected_character_id
		current_run_result.victory = victory
		current_run_result.elapsed_seconds = elapsed
		current_run_result.completed_waves = 4 if victory else clampi(floori(elapsed / 90.0), 0, 4)
		current_run_result.final_boss_kill = victory
		current_run_result.kills = kills
		current_run_result.player_level = level
	var result_story_id: StringName
	if victory:
		result_story_id = &"ending_zhao_yun" if selected_character_id == &"zhao_yun" else &"ending_minato" if selected_character_id == &"minato" else &"ending_main"
	elif not GameState.has_story_flag(&"first_death"):
		result_story_id = &"first_death"
	if not result_story_id.is_empty() and result_story_id not in current_run_result.story_events:
		current_run_result.story_events.append(result_story_id)
	var submit_error := OK
	if GameState.has_current_profile():
		submit_error = GameState.submit_run_result(current_run_result)
	modal_overlay = _modal_background()
	ui_root.add_child(modal_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -430
	panel.offset_top = -345
	panel.offset_right = 430
	panel.offset_bottom = 345
	panel.theme = game_theme
	modal_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title_text := "长夜已尽" if victory else "灯火未熄"
	var title_color := Color("ffe2a6") if victory else Color("ff8e9b")
	var title := _label(title_text, 40, title_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	var ember_text := ""
	if GameState.has_current_profile() and submit_error == OK:
		ember_text = "\n带回夜烬  %d · 当前持有 %d" % [current_run_result.earned_night_embers, GameState.current_profile.night_embers]
	elif GameState.has_current_profile():
		ember_text = "\n结算保存失败：%s" % _save_error_text(submit_error)
	var result_text := "存活时间  %02d:%02d\n最终境界  %d\n斩敌数量  %d%s" % [minutes, seconds, level, kills, ember_text]
	var stats := _label(result_text, 24, Color("c8d4e4"))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_constant_override("line_spacing", 10)
	box.add_child(stats)
	if not result_story_id.is_empty():
		var story := ContentDatabase.story(result_story_id)
		if story != null:
			var story_text := RichTextLabel.new()
			story_text.name = "ResultStoryText"
			story_text.theme = game_theme
			story_text.bbcode_enabled = false
			story_text.text = "%s\n%s" % [story.title, story.body]
			story_text.custom_minimum_size = Vector2(760, 205)
			story_text.fit_content = false
			story_text.scroll_active = true
			story_text.add_theme_font_size_override("normal_font_size", 17)
			story_text.add_theme_color_override("default_color", Color("bdc9da"))
			box.add_child(story_text)
	var retry := _button("再入荒寺", Vector2(320, 58))
	retry.pressed.connect(func() -> void: get_tree().paused = false; _start_game())
	box.add_child(retry)
	var back := _button("返回守夜庭" if GameState.has_current_profile() else "返回标题", Vector2(320, 54))
	back.pressed.connect(_show_hub if GameState.has_current_profile() else _show_title)
	box.add_child(back)


func _save_error_text(error: Error) -> String:
	var detail := String(SaveManager.last_error_message).strip_edges()
	return detail if not detail.is_empty() else error_string(error)


func _modal_background() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.015, 0.022, 0.04, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	return overlay


func _button(text: String, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.theme = game_theme
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme = game_theme
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _play_music(id: StringName, volume_db: float = -5.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = BOSS_MUSIC if id == &"boss" else BATTLE_MUSIC
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stop()
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()


func _play_sfx(id: StringName) -> void:
	if DisplayServer.get_name() == "headless" or not SFX_STREAMS.has(id) or sfx_players.is_empty():
		return
	var player := sfx_players[sfx_index % sfx_players.size()]
	sfx_index += 1
	player.stop()
	player.stream = SFX_STREAMS[id]
	player.pitch_scale = randf_range(0.96, 1.04) if id in [&"slash", &"hit", &"magic"] else 1.0
	player.play()
