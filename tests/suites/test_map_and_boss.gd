class_name MapAndBossTestSuite
extends RefCounted

var suite_name: StringName = &"map_and_boss"


func run(tree: SceneTree, context: RefCounted) -> void:
	var arena := (load("res://scenes/gameplay/battle_arena.tscn") as PackedScene).instantiate() as Arena
	tree.root.add_child(arena)
	await tree.process_frame
	await tree.process_frame
	arena.spawn_timer = 9999.0
	var pixel_map := arena.backdrop.get_node_or_null("PixelMapRoot") as Node2D
	var ground := arena.backdrop.get_node_or_null("PixelMapRoot/GroundBase") as TileMapLayer
	var details := arena.backdrop.get_node_or_null("PixelMapRoot/GroundDetail") as TileMapLayer
	var walls := arena.backdrop.get_node_or_null("PixelMapRoot/Walls") as TileMapLayer
	context.check(pixel_map != null and ground != null and details != null and walls != null, "荒寺地图按地表、细节、墙体拆分 TileMapLayer")
	context.check(ground != null and ground.get_used_cells().size() == 48 * 27, "48×27 个逻辑格完整覆盖战斗边界")
	context.check(walls != null and not walls.get_used_cells().is_empty(), "瓦片墙层包含可见且带物理碰撞的墙体")
	context.check(arena.y_sort_enabled and arena.backdrop.y_sort_enabled and pixel_map != null and pixel_map.y_sort_enabled, "地图道具和角色共享 Y 排序链")
	context.check(not arena.backdrop.is_point_clear(Vector2(-544.0, -512.0)), "瓦片墙体位置不可生成角色或掉落")
	context.check(not arena.backdrop.is_point_clear(Vector2(-1352.0, -399.0)), "树干位置不可生成角色或掉落")
	context.check(arena.backdrop.is_point_clear(Vector2.ZERO), "中央开放通道保持可通行")
	context.check(arena.backdrop.zones.size() == 4, "荒寺地图显式包含山门、枯林、经阁、封印殿四区")
	for id in [&"mountain_gate", &"withered_forest", &"sutra_library", &"seal_hall"]:
		context.check(arena.backdrop.zones.get(id) is MapZone, "地图区域可按稳定 ID 查询：%s" % id)
	context.check((arena.backdrop.zones[&"mountain_gate"] as MapZone).unlocked, "开局山门区域开放")
	context.check(not (arena.backdrop.zones[&"sutra_library"] as MapZone).unlocked, "经阁在指定波次前保持封锁")
	context.check(arena.backdrop.gates.size() == 3, "四区之间配置三道可见结界")
	var forest_gate := arena.backdrop.gates[&"withered_forest_gate"] as ZoneGate
	var library_gate := arena.backdrop.gates[&"sutra_library_gate"] as ZoneGate
	var seal_gate := arena.backdrop.gates[&"seal_hall_gate"] as ZoneGate
	context.check(forest_gate.locked and library_gate.locked and seal_gate.locked, "第一波三道结界均处于预期锁定状态")
	context.check(not arena.backdrop.is_point_clear(forest_gate.global_position), "锁定结界参与出生点物理检测")
	arena.backdrop.on_wave_started(ContentDatabase.wave(2))
	await tree.process_frame
	context.check(not forest_gate.locked and (forest_gate.get_node("GateCollision") as CollisionShape2D).disabled, "第二波解除枯林结界并先关闭碰撞")
	context.check(arena.backdrop.is_point_clear(forest_gate.global_position), "结界解锁后通道物理检测同步放行")
	context.check((arena.backdrop.zones[&"withered_forest"] as MapZone).unlocked, "第二波开放枯林区域")
	arena.backdrop.on_wave_started(ContentDatabase.wave(4))
	await tree.process_frame
	context.check(not library_gate.locked and (arena.backdrop.zones[&"sutra_library"] as MapZone).unlocked, "第四波同步开放经阁与对应结界")
	arena.backdrop.on_wave_started(ContentDatabase.wave(7))
	await tree.process_frame
	context.check(not seal_gate.locked and (arena.backdrop.zones[&"seal_hall"] as MapZone).unlocked, "第七波开放封印殿且不会残留碰撞")

	context.check(arena.backdrop.hazards.size() == 5, "地图包含灯阵、雾区、诅咒、封印脉冲与封印柱危险")
	for value in arena.backdrop.hazards.values():
		var hazard := value as HazardArea
		context.check(hazard.warning_duration >= 0.55, "%s 拥有不少于 0.55 秒的可读预警" % hazard.hazard_id)
	var seal_pulse := arena.backdrop.hazards[&"seal_pulse"] as HazardArea
	var health_before := arena.player.health
	arena.player.invulnerability = 0.0
	seal_pulse.activate(arena.player.global_position)
	context.check(seal_pulse.warning_remaining > 0.0 and seal_pulse.active_remaining == 0.0, "环境危险先进入预警而不是立即造成伤害")
	seal_pulse._process(seal_pulse.warning_duration + 0.01)
	seal_pulse._process(0.01)
	context.check(arena.player.health < health_before, "封印危险激活后对范围内玩家实际造成伤害")
	context.check(arena.backdrop.trigger_environment_event(&"missing_hazard") == false, "未知环境事件被安全拒绝")

	arena.player.invulnerability = 9999.0
	arena._start_boss()
	var boss := arena.boss
	context.check(boss != null and boss.state == BossActor.BossState.ENTER, "鬼面剑豪以显式 ENTER 状态入场")
	boss._physics_process(0.81)
	context.check(boss.state == BossActor.BossState.CHASE, "入场结束后显式切换到 CHASE")
	boss._start_slash()
	context.check(boss.state == BossActor.BossState.WINDUP and boss.windup >= 0.68, "高伤斩击进入带 0.68 秒预警的 WINDUP")
	boss._physics_process(0.7)
	context.check(boss.state in [BossActor.BossState.ATTACK, BossActor.BossState.RECOVER], "预警结束后进入 ATTACK/RECOVER 状态")
	boss.set_state(BossActor.BossState.CHASE)
	boss.recovery_timer = 0.0
	boss.health = boss.max_health * 0.69
	boss._physics_process(0.01)
	context.check(boss.phase == 2 and boss.state == BossActor.BossState.PHASE_TRANSITION, "生命低于 70% 进入第二阶段过渡")
	boss._physics_process(0.8)
	boss.health = boss.max_health * 0.34
	boss._physics_process(0.01)
	context.check(boss.phase == 3 and boss.state == BossActor.BossState.PHASE_TRANSITION, "生命低于 35% 进入第三阶段过渡")
	context.check(BossActor.BossState.WINDUP in boss.state_history and BossActor.BossState.PHASE_TRANSITION in boss.state_history, "Boss 状态历史包含预警与阶段转换")
	boss.take_damage(DamageEvent.create(999999.0, arena.player))
	context.check(boss.dead and boss.state == BossActor.BossState.DEAD, "致命伤只通过显式 DEAD 状态结束 Boss")
	arena.queue_free()
	await tree.process_frame
	await tree.process_frame
