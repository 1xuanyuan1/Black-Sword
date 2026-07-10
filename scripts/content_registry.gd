class_name ContentRegistry
extends RefCounted

const HERO_TEXTURE := preload("res://assets/actors/hero/samurai_blue.png")
const CORPSE_TEXTURE := preload("res://assets/actors/enemies/corpse.png")
const HOUND_TEXTURE := preload("res://assets/actors/enemies/shadow_hound.png")
const LANTERN_TEXTURE := preload("res://assets/actors/enemies/lantern.png")
const REVENANT_TEXTURE := preload("res://assets/actors/enemies/revenant.png")

var skills: Dictionary = {}
var enemies: Dictionary = {}
var waves: Array[WaveDefinition] = []


func _init() -> void:
	_build_skills()
	_build_enemies()
	_build_waves()


func _levels(rows: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in rows:
		result.append(row)
	return result


func _build_skills() -> void:
	_add_skill(SkillDefinition.create(&"black_slash", "黑剑·横扫", "斩出凌厉剑弧，专破近身群敌。", SkillDefinition.SkillType.ACTIVE, Color("d8e4ff"), _levels([
		{"damage": 18.0, "range": 92.0, "cooldown": 0.9, "arc": 1.8, "upgrade": "基础剑式"},
		{"damage": 25.0, "range": 102.0, "cooldown": 0.82, "arc": 1.95, "upgrade": "剑弧更宽，伤害提升"},
		{"damage": 33.0, "range": 112.0, "cooldown": 0.74, "arc": 2.1, "upgrade": "出剑更快"},
		{"damage": 44.0, "range": 124.0, "cooldown": 0.66, "arc": 2.25, "upgrade": "剑势大幅增强"},
		{"damage": 54.0, "range": 132.0, "cooldown": 0.58, "arc": 2.4, "double": true, "upgrade": "化境：双重剑弧"},
	])))
	_add_skill(SkillDefinition.create(&"rasengan", "螺旋丸", "将高速旋转的查克拉凝聚成球，自动追击最近的敌人。", SkillDefinition.SkillType.ACTIVE, Color("65cfff"), _levels([
		{"damage": 25.0, "speed": 290.0, "radius": 18.0, "count": 1, "pierce": 0, "cooldown": 1.45, "upgrade": "凝聚一枚单体螺旋丸"},
		{"damage": 33.0, "speed": 310.0, "radius": 20.0, "count": 1, "pierce": 0, "aoe_radius": 78.0, "aoe_damage": 0.65, "cooldown": 1.32, "upgrade": "群攻：命中后爆发螺旋冲击"},
		{"damage": 43.0, "speed": 335.0, "radius": 27.0, "count": 1, "pierce": 0, "aoe_radius": 105.0, "aoe_damage": 0.72, "cooldown": 1.20, "upgrade": "大螺旋丸：本体与爆炸范围变大"},
		{"damage": 55.0, "speed": 360.0, "radius": 29.0, "count": 1, "pierce": 0, "aoe_radius": 116.0, "aoe_damage": 0.78, "split_count": 3, "split_damage": 0.55, "cooldown": 1.08, "upgrade": "命中后分裂三枚小螺旋丸"},
		{"damage": 72.0, "speed": 390.0, "radius": 38.0, "count": 1, "pierce": 0, "aoe_radius": 150.0, "aoe_damage": 0.85, "split_count": 4, "split_damage": 0.65, "cooldown": 0.95, "upgrade": "化境：大玉螺旋丸，爆炸后四重分裂"},
	])))
	_add_skill(SkillDefinition.create(&"flying_sword", "飞剑诀", "御剑追敌，飞剑穿透后折返。", SkillDefinition.SkillType.ACTIVE, Color("7ddcff"), _levels([
		{"damage": 16.0, "speed": 380.0, "count": 1, "pierce": 1, "bounces": 0, "cooldown": 2.0, "upgrade": "御使一柄飞剑"},
		{"damage": 20.0, "speed": 410.0, "count": 2, "pierce": 1, "bounces": 1, "cooldown": 1.9, "upgrade": "飞剑 +1，碰到树干可反弹"},
		{"damage": 26.0, "speed": 440.0, "count": 2, "pierce": 2, "bounces": 1, "cooldown": 1.72, "upgrade": "飞剑穿透 +1"},
		{"damage": 33.0, "speed": 470.0, "count": 3, "pierce": 2, "bounces": 2, "cooldown": 1.55, "upgrade": "飞剑 +1，反弹 +1"},
		{"damage": 42.0, "speed": 500.0, "count": 3, "pierce": 3, "bounces": 3, "cooldown": 1.38, "returning": true, "upgrade": "化境：三次反弹后折返"},
	])))
	_add_skill(SkillDefinition.create(&"sword_wave", "剑气纵横", "向敌群打出贯穿剑气。", SkillDefinition.SkillType.ACTIVE, Color("b8f7ff"), _levels([
		{"damage": 22.0, "speed": 430.0, "width": 22.0, "pierce": 4, "bounces": 0, "cooldown": 2.4, "upgrade": "贯穿四名敌人"},
		{"damage": 29.0, "speed": 450.0, "width": 26.0, "pierce": 5, "bounces": 0, "cooldown": 2.25, "upgrade": "剑气更宽"},
		{"damage": 37.0, "speed": 470.0, "width": 30.0, "pierce": 7, "bounces": 1, "cooldown": 2.05, "upgrade": "剑气可反弹一次"},
		{"damage": 48.0, "speed": 500.0, "width": 34.0, "pierce": 9, "bounces": 1, "cooldown": 1.85, "upgrade": "剑气威力大增"},
		{"damage": 62.0, "speed": 530.0, "width": 38.0, "pierce": 12, "bounces": 2, "cooldown": 1.65, "cross": true, "upgrade": "化境：交叉剑气，反弹两次"},
	])))
	_add_skill(SkillDefinition.create(&"orbit_blades", "回风护体", "剑风化作龙卷，绕身持续绞杀近敌。", SkillDefinition.SkillType.ACTIVE, Color("7ee4df"), _levels([
		{"damage": 8.0, "count": 1, "radius": 78.0, "rotation_speed": 1.8, "cooldown": 0.55, "upgrade": "唤出一道护体龙卷"},
		{"damage": 11.0, "count": 2, "radius": 82.0, "rotation_speed": 2.2, "cooldown": 0.50, "upgrade": "龙卷数量 +1，旋转加快"},
		{"damage": 15.0, "count": 3, "radius": 88.0, "rotation_speed": 2.6, "cooldown": 0.45, "upgrade": "龙卷数量 +1，伤害提升"},
		{"damage": 20.0, "count": 4, "radius": 94.0, "rotation_speed": 3.0, "cooldown": 0.40, "upgrade": "龙卷数量 +1，旋转加快"},
		{"damage": 27.0, "count": 4, "inner_count": 2, "radius": 100.0, "rotation_speed": 3.45, "cooldown": 0.34, "upgrade": "化境：六龙卷内外双环"},
	])))
	_add_skill(SkillDefinition.create(&"thunder", "落雷符", "雷霆在敌群间连续跳跃。", SkillDefinition.SkillType.ACTIVE, Color("ffe66d"), _levels([
		{"damage": 24.0, "chains": 3, "cooldown": 3.2, "upgrade": "雷击三名敌人"},
		{"damage": 31.0, "chains": 4, "cooldown": 3.0, "upgrade": "连锁目标 +1"},
		{"damage": 40.0, "chains": 5, "cooldown": 2.75, "upgrade": "雷霆威力提升"},
		{"damage": 52.0, "chains": 6, "cooldown": 2.5, "upgrade": "连锁目标 +1"},
		{"damage": 66.0, "chains": 7, "cooldown": 2.25, "starts": 2, "upgrade": "化境：双雷齐落"},
	])))
	_add_skill(SkillDefinition.create(&"frost", "寒霜剑阵", "凝霜成阵，伤敌并减缓行动。", SkillDefinition.SkillType.ACTIVE, Color("83cfff"), _levels([
		{"damage": 15.0, "radius": 100.0, "slow": 0.65, "duration": 2.0, "cooldown": 4.2, "upgrade": "布下一座霜阵"},
		{"damage": 21.0, "radius": 116.0, "slow": 0.6, "duration": 2.2, "cooldown": 4.0, "upgrade": "范围和减速提升"},
		{"damage": 29.0, "radius": 132.0, "slow": 0.55, "duration": 2.4, "cooldown": 3.75, "upgrade": "霜阵持续更久"},
		{"damage": 39.0, "radius": 148.0, "slow": 0.5, "duration": 2.7, "cooldown": 3.45, "upgrade": "寒气威力提升"},
		{"damage": 52.0, "radius": 164.0, "slow": 0.42, "duration": 3.0, "cooldown": 3.1, "freeze": true, "upgrade": "化境：冻结群敌"},
	])))
	_add_skill(SkillDefinition.create(&"sun_palm", "烈阳掌", "真气爆发，震退四周邪祟。", SkillDefinition.SkillType.ACTIVE, Color("ff9d56"), _levels([
		{"damage": 18.0, "radius": 92.0, "knockback": 130.0, "cooldown": 4.0, "upgrade": "释放烈阳冲击"},
		{"damage": 25.0, "radius": 108.0, "knockback": 150.0, "cooldown": 3.8, "upgrade": "冲击范围提升"},
		{"damage": 34.0, "radius": 124.0, "knockback": 175.0, "cooldown": 3.55, "upgrade": "击退更强"},
		{"damage": 45.0, "radius": 142.0, "knockback": 200.0, "cooldown": 3.25, "upgrade": "掌力大幅提升"},
		{"damage": 58.0, "radius": 158.0, "knockback": 230.0, "cooldown": 2.9, "double": true, "upgrade": "化境：双重掌劲"},
	])))
	_add_skill(SkillDefinition.create(&"sword_rain", "万剑归宗", "剑雨锁定敌阵，自天而降。", SkillDefinition.SkillType.ACTIVE, Color("d7c7ff"), _levels([
		{"damage": 18.0, "count": 5, "radius": 105.0, "cooldown": 5.0, "upgrade": "降下五道剑光"},
		{"damage": 24.0, "count": 7, "radius": 115.0, "cooldown": 4.7, "upgrade": "剑光数量 +2"},
		{"damage": 31.0, "count": 9, "radius": 125.0, "cooldown": 4.35, "upgrade": "剑光数量 +2"},
		{"damage": 41.0, "count": 12, "radius": 138.0, "cooldown": 4.0, "upgrade": "剑雨覆盖增强"},
		{"damage": 54.0, "count": 15, "radius": 152.0, "cooldown": 3.6, "giant": true, "upgrade": "化境：中心巨剑"},
	])))
	_add_skill(SkillDefinition.create(&"light_step", "轻身诀", "身法愈轻，行动与拾取范围愈广。", SkillDefinition.SkillType.PASSIVE, Color("86f3bd"), _levels([
		{"speed": 0.06, "pickup": 0.12, "upgrade": "移速 +6%，拾取 +12%"},
		{"speed": 0.12, "pickup": 0.24, "upgrade": "移速累计 +12%"},
		{"speed": 0.18, "pickup": 0.36, "upgrade": "移速累计 +18%"},
		{"speed": 0.24, "pickup": 0.48, "upgrade": "移速累计 +24%"},
		{"speed": 0.30, "pickup": 0.60, "upgrade": "化境：身轻如燕"},
	])))
	_add_skill(SkillDefinition.create(&"tempered_edge", "淬锋心法", "磨砺黑剑，提升全局伤害与出招速度。", SkillDefinition.SkillType.PASSIVE, Color("ff8b8b"), _levels([
		{"damage": 0.08, "cdr": 0.04, "upgrade": "伤害 +8%，冷却 -4%"},
		{"damage": 0.16, "cdr": 0.08, "upgrade": "伤害累计 +16%"},
		{"damage": 0.24, "cdr": 0.12, "upgrade": "伤害累计 +24%"},
		{"damage": 0.32, "cdr": 0.16, "upgrade": "伤害累计 +32%"},
		{"damage": 0.40, "cdr": 0.20, "upgrade": "化境：锋芒无匹"},
	])))


func _add_skill(definition: SkillDefinition) -> void:
	skills[definition.id] = definition


func _build_enemies() -> void:
	enemies[&"corpse"] = EnemyDefinition.create({"id": &"corpse", "name": "尸傀", "health": 34.0, "speed": 78.0, "damage": 8.0, "xp": 1, "range": 34.0, "cooldown": 1.3, "texture": CORPSE_TEXTURE, "visual_kind": &"character", "behavior": &"melee", "scale": 3.2, "tint": Color("c3d5c2")})
	enemies[&"hound"] = EnemyDefinition.create({"id": &"hound", "name": "影犬", "health": 24.0, "speed": 126.0, "damage": 7.0, "xp": 2, "range": 30.0, "cooldown": 1.0, "texture": HOUND_TEXTURE, "visual_kind": &"monster", "behavior": &"melee", "scale": 3.0, "tint": Color("9eb1c0")})
	enemies[&"lantern"] = EnemyDefinition.create({"id": &"lantern", "name": "灯笼鬼", "health": 42.0, "speed": 62.0, "damage": 9.0, "xp": 3, "range": 230.0, "cooldown": 2.0, "texture": LANTERN_TEXTURE, "visual_kind": &"monster", "behavior": &"ranged", "scale": 3.1, "tint": Color("ffb3a7")})
	enemies[&"revenant"] = EnemyDefinition.create({"id": &"revenant", "name": "重甲怨卒", "health": 110.0, "speed": 54.0, "damage": 14.0, "xp": 5, "range": 42.0, "cooldown": 1.7, "texture": REVENANT_TEXTURE, "visual_kind": &"character", "behavior": &"charger", "scale": 4.0, "tint": Color("b39ac7")})


func _build_waves() -> void:
	waves = [
		WaveDefinition.create({"title": "第一夜·尸行", "start": 0.0, "end": 90.0, "interval": 0.72, "weights": {&"corpse": 1.0}, "cap": 55, "elite": 0.0}),
		WaveDefinition.create({"title": "第二夜·犬影", "start": 90.0, "end": 180.0, "interval": 0.56, "weights": {&"corpse": 0.62, &"hound": 0.38}, "cap": 75, "elite": 0.03}),
		WaveDefinition.create({"title": "第三夜·鬼灯", "start": 180.0, "end": 270.0, "interval": 0.34, "weights": {&"corpse": 0.42, &"hound": 0.28, &"lantern": 0.3}, "cap": 115, "elite": 0.08}),
		WaveDefinition.create({"title": "第四夜·怨军", "start": 270.0, "end": 390.0, "interval": 0.25, "weights": {&"corpse": 0.27, &"hound": 0.23, &"lantern": 0.24, &"revenant": 0.26}, "cap": 145, "elite": 0.14}),
	]


func wave_for_time(elapsed: float) -> WaveDefinition:
	for wave in waves:
		if elapsed >= wave.start_time and elapsed < wave.end_time:
			return wave
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if skills.size() != 11:
		errors.append("技能数量应为 11，实际为 %d" % skills.size())
	for skill in skills.values():
		if skill.max_level != 5:
			errors.append("%s 的最大等级不是 5" % skill.display_name)
	if enemies.size() != 4:
		errors.append("敌人类型应为 4")
	if waves.size() != 4:
		errors.append("波次数量应为 4")
	return errors
