class_name BaselineTestSuite
extends RefCounted

var suite_name: StringName = &"baseline"
var _tree: SceneTree
var _context: RefCounted

var root: Window:
	get:
		return _tree.root

var paused: bool:
	get:
		return _tree.paused
	set(value):
		_tree.paused = value

var process_frame: Signal:
	get:
		return _tree.process_frame


func create_timer(time_sec: float) -> SceneTreeTimer:
	return _tree.create_timer(time_sec)


func _check(condition: bool, message: String) -> void:
	_context.check(condition, message)


func run(tree: SceneTree, context: RefCounted) -> void:
	_tree = tree
	_context = context
	await _run_baseline()


func _check_actor_preset(path: String, root_name: String, script_path: String) -> void:
	var packed_scene: PackedScene = load(path) as PackedScene
	_check(packed_scene != null, "%s 可作为 PackedScene 加载" % path)
	if packed_scene == null:
		return
	var scene_root: Node = packed_scene.instantiate()
	_check(scene_root is CharacterBody2D, "%s 以 CharacterBody2D 为根节点" % root_name)
	_check(scene_root.name == root_name, "%s 根节点按角色职责命名" % root_name)
	_check(scene_root.get_script() != null and scene_root.get_script().resource_path == script_path, "%s 绑定正确的角色脚本" % root_name)
	_check(scene_root.get_node_or_null("CharacterVisual/CharacterSprite") is Sprite2D, "%s 包含命名明确的角色视觉节点" % root_name)
	_check(scene_root.get_node_or_null("BodyCollision") is CollisionShape2D, "%s 包含命名明确的身体碰撞节点" % root_name)
	scene_root.free()


func _run_baseline() -> void:
	var repository_script: GDScript = load("res://addons/npc_library_tool/core/npc_repository.gd") as GDScript
	var npc_repository: RefCounted = repository_script.new() as RefCounted
	var yitu_items: Array = npc_repository.call("scan_npc_files", "res://AI资源库/一图全动作")
	var naruto_items: Array = npc_repository.call("scan_npc_files", "res://AI资源库/火影忍者")
	_check(yitu_items.size() >= 2, "AI资源库的一图全动作分类可以扫描到原插件示例素材")
	_check(naruto_items.size() >= 2, "AI资源库的火影忍者分类可以扫描到波风水门等素材")
	var registry := ContentRegistry.new()
	var rasengan_definition: SkillDefinition = registry.skills[&"rasengan"]
	var rasengan_level_two: Dictionary = rasengan_definition.stats(2)
	var rasengan_level_three: Dictionary = rasengan_definition.stats(3)
	var rasengan_level_four: Dictionary = rasengan_definition.stats(4)
	var rasengan_level_five: Dictionary = rasengan_definition.stats(5)
	_check(registry.validate().is_empty(), "内容注册表包含 11 个五级技能、4 类敌人与 4 个波次")
	_check_actor_preset("res://scenes/actors/player.tscn", "PlayerCharacter", "res://scripts/player_actor.gd")
	_check_actor_preset("res://scenes/actors/player_minato.tscn", "MinatoPlayerCharacter", "res://scripts/player_actor.gd")
	_check_actor_preset("res://scenes/actors/enemies/corpse.tscn", "CorpseEnemy", "res://scripts/enemy_actor.gd")
	_check_actor_preset("res://scenes/actors/enemies/hound.tscn", "ShadowHoundEnemy", "res://scripts/enemy_actor.gd")
	_check_actor_preset("res://scenes/actors/enemies/lantern.tscn", "LanternSpiritEnemy", "res://scripts/enemy_actor.gd")
	_check_actor_preset("res://scenes/actors/enemies/revenant.tscn", "ArmoredRevenantEnemy", "res://scripts/enemy_actor.gd")
	_check_actor_preset("res://scenes/actors/boss.tscn", "GhostSwordsmanBoss", "res://scripts/boss_actor.gd")
	var map_scene: PackedScene = load("res://scenes/world/abandoned_temple_map.tscn") as PackedScene
	var map_root: Node = map_scene.instantiate()
	_check(map_root.name == "AbandonedTempleMap", "荒寺地图拥有职责明确的根节点名称")
	_check(map_root.get_node_or_null("GroundLayer/ArenaBackground") is Sprite2D, "荒寺地图地表层结构完整")
	_check(map_root.get_node_or_null("WorldCollisionLayer/WestGroveTree01/TrunkCollision") is CollisionShape2D, "荒寺地图树干碰撞在预设中可直接编辑")
	_check(map_root.get_node_or_null("AtmosphereLayer/FogBanks/FogBank01") is Sprite2D, "荒寺地图氛围层在预设中可直接编辑")
	map_root.free()
	var battle_scene: PackedScene = load("res://scenes/gameplay/battle_arena.tscn") as PackedScene
	var battle_root: Node = battle_scene.instantiate()
	_check(battle_root.name == "BattleArena", "组装后的战斗场景拥有职责明确的根节点名称")
	_check(battle_root.get_node_or_null("Environment/AbandonedTempleMap") is ArenaBackdrop, "战斗场景引用独立地图预设")
	_check(battle_root.get_node_or_null("ActorLayer/PlayerSpawnPoint") is Marker2D, "战斗场景提供所选玩家预设的出生点")
	_check(battle_root.get_node_or_null("GameplaySystems/SkillSystem") is SkillSystem, "战斗场景显式组织玩法系统")
	_check(battle_root.get_node_or_null("ProjectileLayer") is Node2D and battle_root.get_node_or_null("PickupLayer") is Node2D and battle_root.get_node_or_null("EffectLayer") is Node2D, "战斗场景按职责拆分运行时对象层")
	battle_root.free()
	var joystick_scene: PackedScene = load("res://scenes/ui/virtual_joystick.tscn") as PackedScene
	var joystick: MovementJoystick = joystick_scene.instantiate() as MovementJoystick
	root.add_child(joystick)
	await process_frame
	var floating_joystick_origin := Vector2(180.0, 410.0)
	joystick._begin_input(floating_joystick_origin)
	joystick._update_direction(floating_joystick_origin + Vector2(joystick.joystick_radius, 0.0))
	_check(joystick.mouse_filter == Control.MOUSE_FILTER_STOP and joystick.active and joystick.direction.x > 0.99, "移动端浮动摇杆可在左半屏按下位置出现并输出方向")
	joystick.reset_input()
	_check(not joystick.active and joystick.direction == Vector2.ZERO, "浮动摇杆松手后隐藏并清空移动方向")
	joystick.queue_free()
	_check(int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)) == 4, "移动端窗口使用横屏方向")
	_check(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false)), "触摸可映射到角色卡和菜单按钮")
	var web_shell: String = FileAccess.get_file_as_string("res://assets/web/game_web_shell.html")
	_check(web_shell.contains("orientation-gate") and web_shell.contains("screen.orientation.lock('landscape')"), "手机网页在竖屏时提示旋转并尝试锁定横屏")
	var minato_arena: Arena = battle_scene.instantiate() as Arena
	minato_arena.selected_character_id = &"minato"
	root.add_child(minato_arena)
	await process_frame
	await process_frame
	minato_arena.spawn_timer = 9999.0
	_check(minato_arena.player.character_id == &"minato", "角色选择可实例化独立的波风水门预设")
	_check(minato_arena.skill_system.levels.get(&"rasengan", 0) == 1 and minato_arena.skill_system.levels.get(&"black_slash", 0) == 0, "波风水门以螺旋丸而非黑剑横扫开局")
	var rasengan_target: EnemyActor = minato_arena.spawn_enemy(&"corpse", Vector2(420, 0), false)
	minato_arena.skill_system.cooldowns[&"rasengan"] = 0.0
	minato_arena.skill_system.process_skills(0.1)
	await process_frame
	var found_rasengan := false
	for projectile_node in root.get_tree().get_nodes_in_group("projectiles"):
		var combat_projectile: CombatProjectile = projectile_node as CombatProjectile
		if combat_projectile != null and combat_projectile.projectile_kind == &"rasengan":
			found_rasengan = true
			break
	_check(is_instance_valid(rasengan_target) and found_rasengan, "螺旋丸会自动索敌并生成专用投射物")
	var area_target: EnemyActor = minato_arena.spawn_enemy(&"corpse", Vector2(260, 0), false)
	var area_neighbor: EnemyActor = minato_arena.spawn_enemy(&"corpse", Vector2(300, 0), false)
	var neighbor_health_before: float = area_neighbor.health
	var area_rasengan := CombatProjectile.create({
		"arena": minato_arena,
		"owner": minato_arena.player,
		"position": area_target.global_position,
		"direction": Vector2.RIGHT,
		"speed": 0.0,
		"damage": float(rasengan_level_two.get("damage", 33.0)),
		"radius": float(rasengan_level_two.get("radius", 20.0)),
		"pierce": 0,
		"kind": &"rasengan",
		"explosion_radius": float(rasengan_level_two.get("aoe_radius", 78.0)),
		"explosion_damage_multiplier": float(rasengan_level_two.get("aoe_damage", 0.65)),
	})
	minato_arena.add_projectile(area_rasengan)
	area_rasengan._check_enemy_hits()
	_check(area_neighbor.health < neighbor_health_before, "二级螺旋丸的命中爆炸会伤害附近多个敌人")
	var projectile_count_before_split: int = root.get_tree().get_nodes_in_group("projectiles").size()
	var split_rasengan := CombatProjectile.create({
		"arena": minato_arena,
		"owner": minato_arena.player,
		"position": Vector2(180, 0),
		"direction": Vector2.RIGHT,
		"speed": 320.0,
		"damage": 30.0,
		"radius": 28.0,
		"kind": &"rasengan",
		"split_count": 3,
		"split_damage_multiplier": 0.55,
	})
	minato_arena.add_projectile(split_rasengan)
	split_rasengan._trigger_rasengan_impact(null)
	var projectile_count_after_split: int = root.get_tree().get_nodes_in_group("projectiles").size()
	_check(projectile_count_after_split == projectile_count_before_split + 4, "四级螺旋丸命中后会实际生成三枚分裂弹")
	minato_arena.queue_free()
	await process_frame
	_check(registry.wave_for_time(0.0).title == "第一夜·尸行", "0 秒进入第一波")
	_check(registry.wave_for_time(389.0).title == "第四夜·怨军", "Boss 前处于第四波")
	var third_wave: WaveDefinition = registry.wave_for_time(180.0)
	var fourth_wave: WaveDefinition = registry.wave_for_time(270.0)
	_check(third_wave.spawn_interval <= 0.34 and third_wave.enemy_cap >= 115, "三分钟后刷怪速度与场上密度明显提高")
	_check(fourth_wave.spawn_interval <= 0.25 and fourth_wave.enemy_cap >= 145, "第四波进一步提高刷怪速度与场上密度")
	var orbit_definition: SkillDefinition = registry.skills[&"orbit_blades"]
	_check(float(rasengan_level_two.get("aoe_radius", 0.0)) > 0.0, "二级螺旋丸命中后升级为范围群攻")
	_check(float(rasengan_level_three.get("radius", 0.0)) > float(rasengan_level_two.get("radius", 0.0)) and float(rasengan_level_three.get("aoe_radius", 0.0)) > float(rasengan_level_two.get("aoe_radius", 0.0)), "三级螺旋丸本体和爆炸范围继续变大")
	_check(int(rasengan_level_four.get("split_count", 0)) == 3 and int(rasengan_level_five.get("split_count", 0)) == 4, "四级与五级螺旋丸分别产生三重和四重分裂")
	var orbit_growth_valid := true
	var last_damage := 0.0
	var last_count := 0
	var last_speed := 0.0
	for level in range(1, 6):
		var orbit_stats := orbit_definition.stats(level)
		var total_count: int = int(orbit_stats.get("count", 0)) + int(orbit_stats.get("inner_count", 0))
		if float(orbit_stats.get("damage", 0.0)) <= last_damage or total_count <= last_count or float(orbit_stats.get("rotation_speed", 0.0)) <= last_speed:
			orbit_growth_valid = false
		last_damage = orbit_stats.get("damage", 0.0)
		last_count = total_count
		last_speed = orbit_stats.get("rotation_speed", 0.0)
	_check(orbit_growth_valid, "回风护体每级提升伤害、龙卷数量与旋转速度")
	_check(int(registry.skills[&"flying_sword"].stats(2).get("bounces", 0)) == 1, "二级飞剑开始获得障碍反弹")
	_check(int(registry.skills[&"sword_wave"].stats(5).get("bounces", 0)) == 2, "满级剑气可连续反弹两次")
	var expected_minato_attack_frames: Array[Rect2] = [
		Rect2(0, 168, 42, 42), Rect2(42, 168, 42, 42), Rect2(84, 168, 42, 42),
		Rect2(126, 168, 42, 42), Rect2(168, 168, 42, 42), Rect2(210, 168, 42, 42),
	]
	_check(ActorVisual.OCAD_ATTACK_SIDE == expected_minato_attack_frames, "水门攻击使用六张完整 42×42 宽幅帧，并按 42 像素步进避免串入相邻动作")
	var minato_player_preview: PlayerActor = (load("res://scenes/actors/player_minato.tscn") as PackedScene).instantiate() as PlayerActor
	root.add_child(minato_player_preview)
	await process_frame
	var minato_visual: ActorVisual = minato_player_preview.visual
	minato_visual.setup(minato_player_preview.character_texture, minato_player_preview.character_visual_kind, minato_player_preview.character_visual_scale)
	minato_visual.play_attack(0.22)
	var minato_attack_sequence_valid := true
	for frame_index in range(expected_minato_attack_frames.size()):
		minato_visual.animation_time = minato_visual.attack_animation_duration * (float(frame_index) + 0.1) / float(expected_minato_attack_frames.size())
		minato_visual._update_frame()
		minato_attack_sequence_valid = minato_attack_sequence_valid and minato_visual.sprite.region_rect == expected_minato_attack_frames[frame_index]
	minato_visual.animation_time = minato_visual.attack_animation_duration * 2.0
	minato_visual._update_frame()
	minato_attack_sequence_valid = minato_attack_sequence_valid and minato_visual.sprite.region_rect == expected_minato_attack_frames[-1]
	_check(minato_attack_sequence_valid, "水门攻击六帧按顺序只播放一次，超时保持收招帧而不会循环跳回")
	minato_player_preview.play_attack(Vector2.RIGHT)
	minato_visual._update_frame()
	_check(minato_visual.facing.is_equal_approx(Vector2.RIGHT) and minato_visual.sprite.flip_h, "水门出招时立即朝向右侧目标，不会先显示反向帧再翻转")
	minato_player_preview.queue_free()
	var arena: Arena = battle_scene.instantiate() as Arena
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.spawn_timer = 9999.0
	_check(is_instance_valid(arena.player), "玩家成功创建")
	arena.player.set_virtual_move_input(Vector2(0.75, -0.25))
	_check(arena.player.virtual_move_input.is_equal_approx(Vector2(0.75, -0.25)), "玩家可接收虚拟摇杆的模拟移动输入")
	arena.player.set_virtual_move_input(Vector2.ZERO)
	_check(arena.player.scene_file_path == "res://scenes/actors/player.tscn", "玩家由独立预设实例化")
	_check(arena.backdrop.scene_file_path == "res://scenes/world/abandoned_temple_map.tscn", "战斗地图由独立预设实例化")
	_check(arena.player.get_collision_mask_value(2), "玩家启用世界障碍碰撞层")
	_check(arena.backdrop.world_collision_count(&"world_walls") == 0, "墙体空气碰撞已完全移除")
	_check(arena.backdrop.world_collision_count(&"world_trees") == 14, "十四棵树均创建独立树干碰撞")
	_check(arena.backdrop.is_point_clear(Vector2(800.0, 0.0), 0.0), "视觉石墙区域不再阻挡角色")
	_check(not arena.backdrop.is_point_clear(Vector2(-1352.0, -399.0), 0.0), "树干中心会阻挡实体但树冠不扩大碰撞")
	var bouncing_projectile := CombatProjectile.create({
		"arena": arena, "owner": arena.player, "position": Vector2(-1430.0, -399.0),
		"direction": Vector2.RIGHT, "speed": 500.0, "damage": 1.0,
		"radius": 10.0, "lifetime": 1.2, "pierce": 0, "kind": &"sword", "bounces": 1,
	})
	arena.add_projectile(bouncing_projectile)
	await create_timer(0.32).timeout
	_check(is_instance_valid(bouncing_projectile) and bouncing_projectile.bounce_count == 1 and bouncing_projectile.direction.x < 0.0, "飞剑撞树干后反射并扣除一次反弹")
	if is_instance_valid(bouncing_projectile):
		bouncing_projectile.queue_free()
	var blocked_projectile := CombatProjectile.create({
		"arena": arena, "owner": arena.player, "position": Vector2(-1430.0, -399.0),
		"direction": Vector2.RIGHT, "speed": 500.0, "damage": 1.0,
		"radius": 10.0, "lifetime": 1.2, "pierce": 0, "kind": &"wave", "bounces": 0,
	})
	arena.add_projectile(blocked_projectile)
	await create_timer(0.32).timeout
	_check(not is_instance_valid(blocked_projectile), "无反弹次数的弹丸撞树干后销毁")
	_check(arena.skill_system.levels.get(&"black_slash", 0) == 1, "开局自带黑剑·横扫")
	var system := arena.skill_system
	system.upgrade(&"flying_sword")
	system.upgrade(&"sword_wave")
	system.upgrade(&"orbit_blades")
	system.upgrade(&"thunder")
	system.upgrade(&"light_step")
	system.upgrade(&"tempered_edge")
	_check(system.active_ids.size() == 4, "主动招式槽严格限制为 4")
	_check(system.passive_ids.size() == 2, "心法槽严格限制为 2")
	var options := system.get_upgrade_options(3)
	var options_valid := true
	for option in options:
		if system.levels.get(option.id, 0) == 0:
			options_valid = false
	_check(options.size() == 3 and options_valid, "槽位满后只提供已持有技能升级")
	arena.elapsed = 0.0
	var enemy := arena.spawn_enemy(&"corpse", Vector2(70, 0), false)
	var first_night_health := enemy.max_health if is_instance_valid(enemy) else 0.0
	_check(is_instance_valid(enemy), "尸傀可按 EnemyDefinition 生成")
	_check(first_night_health <= 24.0, "第一波尸傀生命值已下调，初始构筑可以快速击杀")
	_check(is_instance_valid(enemy) and enemy.scene_file_path == "res://scenes/actors/enemies/corpse.tscn", "尸傀由对应独立预设实例化")
	_check(is_instance_valid(enemy) and enemy.get_collision_layer_value(3) and enemy.get_collision_mask_value(2) and not enemy.get_collision_mask_value(3), "怪物穿过彼此但仍与树干碰撞")
	if is_instance_valid(enemy):
		enemy.take_damage(DamageEvent.create(999.0, arena.player, Vector2.RIGHT, 0.0))
	await create_timer(1.2).timeout
	_check(arena.kills == 1, "敌人死亡动画完成后计数并生成经验")
	_check(root.get_tree().get_nodes_in_group("xp_orbs").size() >= 1 or arena.current_xp > 0, "经验球成功生成并可被磁吸拾取")
	arena.elapsed = 179.9
	var health_multiplier_before_three_minutes: float = arena.enemy_health_multiplier()
	arena.elapsed = 180.0
	var health_multiplier_after_three_minutes: float = arena.enemy_health_multiplier()
	_check(health_multiplier_after_three_minutes > health_multiplier_before_three_minutes * 1.25, "三分钟后怪物生命倍率进入高压台阶")
	arena.elapsed = 300.0
	var late_enemy := arena.spawn_enemy(&"corpse", Vector2(120, 0), false)
	_check(is_instance_valid(late_enemy) and late_enemy.max_health > first_night_health * 2.0, "后续波次同类怪物生命值会明显上升")
	if is_instance_valid(late_enemy):
		late_enemy.queue_free()
	await process_frame
	arena._start_boss()
	await process_frame
	_check(arena.boss_started and is_instance_valid(arena.boss), "Boss 只在波次结束后生成")
	_check(is_instance_valid(arena.boss) and arena.boss.scene_file_path == "res://scenes/actors/boss.tscn", "Boss 由独立预设实例化")
	if is_instance_valid(arena.boss):
		var spawned_boss := arena.boss
		arena._start_boss()
		_check(arena.boss == spawned_boss, "Boss 重复触发时不会再次生成")
		arena.boss._set_animation(&"idle")
		_check(arena.boss.sprite.hframes == 6 and arena.boss.sprite.vframes == 1, "Boss 待机贴图按 6×1 切帧")
		arena.boss.pending_direction = Vector2.RIGHT
		arena.boss._set_animation(&"attack")
		_check(arena.boss.sprite.hframes == 4 and arena.boss.sprite.vframes == 1, "Boss 攻击贴图按 4×1 切帧")
		arena.boss._set_animation(&"charge")
		_check(arena.boss.sprite.hframes == 3 and arena.boss.sprite.vframes == 1, "Boss 冲锋贴图按 3×1 切帧")
		arena.boss._set_animation(&"hit")
		_check(arena.boss.sprite.hframes == 4 and arena.boss.sprite.vframes == 1, "Boss 受击贴图按 4×1 切帧")
		arena.boss.take_damage(DamageEvent.create(99999.0, arena.player, Vector2.RIGHT, 0.0))
	await create_timer(2.6).timeout
	_check(not arena.run_active, "Boss 死亡后结束本局")
	arena.queue_free()
	await process_frame
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main._show_character_selection()
	await process_frame
	_check(main.character_select_open and main.ui_root.find_child("MinatoCharacterCard", true, false) != null, "点击开始后显示包含水门的角色选择界面")
	main._select_character(&"minato")
	await process_frame
	_check(main.game_running and main.arena.player.character_id == &"minato", "角色选择结果会传入完整战斗场景")
	_check(main.movement_joystick is MovementJoystick and main.touch_pause_button is Button, "战斗 HUD 包含移动端摇杆和触摸暂停按钮")
	_check(not main.hp_bar.show_percentage and main.hp_value_label.text == "100", "角色血条显示当前生命数字 100 而非百分比")
	var hud_shows_rasengan := false
	for label_node in main.skill_box.find_children("*", "Label", true, false):
		var skill_label: Label = label_node as Label
		if skill_label != null and skill_label.text.contains("螺旋丸"):
			hud_shows_rasengan = true
			break
	_check(hud_shows_rasengan, "进入战斗后 HUD 会立即显示所选角色的初始技能")
	var time_before_pause: float = main.arena.elapsed
	main.arena.collect_xp(12)
	await process_frame
	await process_frame
	var time_during_pause: float = main.arena.elapsed
	_check(paused and main.leveling, "升级三选一会暂停场景树")
	_check(is_equal_approx(time_before_pause, time_during_pause), "升级界面期间战斗计时与世界逻辑完全冻结")
	var touchable_upgrade_cards: Array[Node] = main.modal_overlay.find_children("*", "Button", true, false)
	_check(touchable_upgrade_cards.size() >= 3 and (touchable_upgrade_cards[0] as Button).mouse_filter == Control.MOUSE_FILTER_STOP, "升级选择框可通过触摸按钮选择")
	main._choose_level_option(0)
	await process_frame
	_check(not paused and not main.leveling, "选择技能后恢复战斗")
	main.queue_free()
	paused = false
	await process_frame
	await process_frame
