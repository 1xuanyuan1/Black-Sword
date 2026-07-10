extends Node

const UI_FONT := preload("res://assets/fonts/NotoSansSC.ttf")
const HERO_PORTRAIT := preload("res://assets/actors/hero/portrait_actual.png")
const BATTLE_MUSIC := preload("res://assets/audio/battle.ogg")
const BOSS_MUSIC := preload("res://assets/audio/boss.ogg")
const BATTLE_ARENA_SCENE: PackedScene = preload("res://scenes/gameplay/battle_arena.tscn")
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
var xp_bar: ProgressBar
var xp_label: Label
var level_label: Label
var timer_label: Label
var wave_label: Label
var kills_label: Label
var skill_box: HBoxContainer
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_value_label: Label
var announcement_label: Label
var modal_overlay: Control
var level_options: Array[SkillDefinition] = []
var leveling := false
var pause_open := false
var game_running := false


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
	music_player.finished.connect(func() -> void: if music_player.stream != null: music_player.play())
	for i in range(10):
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%02d" % (i + 1)
		player.bus = &"SFX"
		add_child(player)
		sfx_players.append(player)
	_show_title()
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


func _exit_tree() -> void:
	music_player.stop()
	for player in sfx_players:
		if is_instance_valid(player):
			player.stop()


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


func _input(event: InputEvent) -> void:
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
	for child in ui_root.get_children():
		child.queue_free()
	modal_overlay = null
	hud_root = null


func _clear_world() -> void:
	for child in world_holder.get_children():
		child.queue_free()
	arena = null


func _show_title() -> void:
	game_running = false
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
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var start := _button("踏入荒寺", Vector2(310, 58))
	start.pressed.connect(func() -> void: _play_sfx(&"ui"); _start_game())
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
	_clear_world()
	_clear_ui()
	game_running = true
	arena = BATTLE_ARENA_SCENE.instantiate() as Arena
	world_holder.add_child(arena)
	_connect_arena()
	_build_hud()


func _connect_arena() -> void:
	arena.player_health_changed.connect(_update_health)
	arena.xp_changed.connect(_update_xp)
	arena.stats_changed.connect(_update_stats)
	arena.skills_changed.connect(_update_skills)
	arena.level_up_requested.connect(_show_level_up)
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
	hp_bar.show_percentage = true
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.add_theme_stylebox_override("background", _style_box(Color("161d2b"), Color("3b4659"), 1, 5, 0))
	hp_bar.add_theme_stylebox_override("fill", _style_box(Color("b94155"), Color("ef7788"), 1, 5, 0))
	hp_row.add_child(hp_bar)
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
	skill_box = HBoxContainer.new()
	skill_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skill_box.offset_left = -548
	skill_box.offset_top = -118
	skill_box.offset_right = -24
	skill_box.offset_bottom = -46
	skill_box.alignment = BoxContainer.ALIGNMENT_END
	skill_box.add_theme_constant_override("separation", 8)
	hud_root.add_child(skill_box)
	for i in range(6):
		var empty_slot := PanelContainer.new()
		empty_slot.custom_minimum_size = Vector2(84, 68)
		empty_slot.add_theme_stylebox_override("panel", _style_box(Color(0.04, 0.055, 0.09, 0.8), Color("374660"), 1, 7, 5))
		var slot_label := _label("空", 15, Color("61708a"))
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_slot.add_child(slot_label)
		skill_box.add_child(empty_slot)
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
	xp_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	xp_label.offset_left = 30
	xp_label.offset_top = -58
	xp_label.offset_right = 230
	xp_label.offset_bottom = -36
	hud_root.add_child(xp_label)
	announcement_label = _label("", 30, Color.WHITE)
	announcement_label.position = Vector2(330, 138)
	announcement_label.size = Vector2(620, 54)
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.modulate.a = 0.0
	hud_root.add_child(announcement_label)


func _update_health(current: float, maximum: float) -> void:
	if is_instance_valid(hp_bar):
		hp_bar.max_value = maximum
		hp_bar.value = current


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
	var ids: Array[StringName] = active_ids.duplicate()
	ids.append_array(passive_ids)
	for i in range(6):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(84, 68)
		if i < ids.size():
			var id := ids[i]
			var definition: SkillDefinition = arena.registry.skills[id]
			slot.add_theme_stylebox_override("panel", _style_box(Color(0.06, 0.08, 0.13, 0.94), Color(definition.accent, 0.7), 2, 7, 5))
			var label := _label("%s\n%s" % [_short_skill_name(definition.display_name), "◆".repeat(levels.get(id, 1))], 14, definition.accent)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(label)
		else:
			slot.add_theme_stylebox_override("panel", _style_box(Color(0.04, 0.055, 0.09, 0.8), Color("374660"), 1, 7, 5))
			var empty := _label("空", 15, Color("61708a"))
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(empty)
		skill_box.add_child(slot)


func _short_skill_name(name: String) -> String:
	return name.replace("黑剑·", "").replace("心法", "").substr(0, 5)


func _show_level_up(level: int, options: Array[SkillDefinition]) -> void:
	if not game_running:
		return
	leveling = true
	level_options = options
	get_tree().paused = true
	_play_sfx(&"level_up")
	modal_overlay = _modal_background()
	ui_root.add_child(modal_overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(100, 95)
	panel.size = Vector2(1080, 530)
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


func _toggle_pause() -> void:
	if not game_running or leveling:
		return
	if pause_open:
		pause_open = false
		get_tree().paused = false
		if is_instance_valid(modal_overlay):
			modal_overlay.queue_free()
		modal_overlay = null
		return
	pause_open = true
	get_tree().paused = true
	modal_overlay = _modal_background()
	ui_root.add_child(modal_overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(430, 150)
	panel.size = Vector2(420, 420)
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
	var title_button := _button("返回标题", Vector2(300, 55))
	title_button.pressed.connect(_show_title)
	box.add_child(title_button)


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
	pause_open = false
	get_tree().paused = true
	modal_overlay = _modal_background()
	ui_root.add_child(modal_overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(360, 100)
	panel.size = Vector2(560, 520)
	panel.theme = game_theme
	modal_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title_text := "破晓·荒寺复寂" if victory else "剑折·百鬼未休"
	var title_color := Color("ffe2a6") if victory else Color("ff8e9b")
	var title := _label(title_text, 40, title_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	var result_text := "存活时间  %02d:%02d\n最终境界  %d\n斩敌数量  %d" % [minutes, seconds, level, kills]
	var stats := _label(result_text, 24, Color("c8d4e4"))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_constant_override("line_spacing", 10)
	box.add_child(stats)
	var retry := _button("再入荒寺", Vector2(320, 58))
	retry.pressed.connect(func() -> void: get_tree().paused = false; _start_game())
	box.add_child(retry)
	var back := _button("返回标题", Vector2(320, 54))
	back.pressed.connect(_show_title)
	box.add_child(back)


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
