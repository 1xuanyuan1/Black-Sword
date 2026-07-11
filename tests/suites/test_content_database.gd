class_name ContentDatabaseTestSuite
extends RefCounted

const CONTENT_DATABASE_SCRIPT := preload("res://scripts/autoload/content_database.gd")

var suite_name: StringName = &"content_database"


func run(tree: SceneTree, context: RefCounted) -> void:
	var database := tree.root.get_node_or_null("ContentDatabase")
	var owns_database := false
	if database == null:
		database = CONTENT_DATABASE_SCRIPT.new()
		tree.root.add_child(database)
		owns_database = true
	database.reload_content()

	context.check(database.validate_all().is_empty(), "ContentDatabase 的资源引用校验通过")
	context.check(database.content_counts() == {"characters": 5, "skills": 12, "enemies": 4, "waves": 4, "items": 5, "meta_upgrades": 4}, "ContentDatabase 加载五角色、五道具与当前 Demo 内容")

	var expected_skill_ids := [
		&"black_slash", &"rasengan", &"flying_sword", &"sword_wave", &"orbit_blades",
		&"thunder", &"frost", &"sun_palm", &"sword_rain", &"dragon_spear", &"light_step", &"tempered_edge",
	]
	for skill_id in expected_skill_ids:
		var definition: SkillDefinition = database.skill(skill_id)
		context.check(definition != null, "技能资源可按 ID 查询：%s" % skill_id)
		context.check(definition != null and definition.max_level == 5 and definition.values.size() == 5, "技能 %s 保留五级数据" % skill_id)

	context.check(float(database.skill(&"black_slash").stats(1).get("damage")) == 18.0, "黑剑横扫一级伤害保持 18")
	context.check(int(database.skill(&"rasengan").stats(4).get("split_count")) == 3, "螺旋丸四级保持三枚分裂弹")
	context.check(database.skill(&"light_step").skill_type == SkillDefinition.SkillType.PASSIVE, "轻身诀保持被动心法类型")
	context.check(database.skill(&"missing_skill") == null, "未知技能 ID 返回 null")
	for item_id in [&"healing_salve", &"soul_talisman", &"soul_bell", &"binding_talisman", &"soul_wine"]:
		var item_definition: ItemDefinition = database.item(item_id)
		context.check(item_definition != null and item_definition.icon != null and item_definition.world_scene != null, "局内道具 %s 的数据与资源完整" % item_id)

	var expected_enemy_health := {&"corpse": 34.0, &"hound": 24.0, &"lantern": 42.0, &"revenant": 110.0}
	for enemy_id in expected_enemy_health:
		var definition: EnemyDefinition = database.enemy(enemy_id)
		context.check(definition != null and definition.actor_scene != null, "敌人 %s 拥有可加载的独立场景" % enemy_id)
		context.check(definition != null and definition.max_health == expected_enemy_health[enemy_id], "敌人 %s 保留当前基础生命" % enemy_id)

	var expected_wave_titles := ["第一夜·尸行", "第二夜·犬影", "第三夜·鬼灯", "第四夜·怨军"]
	for index in range(1, 5):
		var definition: WaveDefinition = database.wave(index)
		context.check(definition != null and definition.title == expected_wave_titles[index - 1], "第 %d 波标题与顺序保持不变" % index)
	context.check(database.wave(5) == null, "不存在的波次索引返回 null")

	for character_id in [&"black_sword", &"minato", &"ning_shuanghua", &"xuandeng", &"zhao_yun"]:
		var definition: CharacterDefinition = database.character(character_id)
		context.check(definition != null and definition.actor_scene != null and definition.portrait != null, "角色 %s 的场景与头像资源完整" % character_id)
		var actor := definition.actor_scene.instantiate() as PlayerActor
		context.check(actor != null and actor.character_id == definition.id and actor.initial_skill_id == definition.initial_skill_id, "角色 %s 的 Resource 与场景导出值一致" % character_id)
		actor.free()

	var legacy_registry := ContentRegistry.new()
	context.check(legacy_registry.validate().is_empty(), "ContentRegistry 兼容层通过原有内容校验")
	context.check(legacy_registry.skills[&"black_slash"] == database.skill(&"black_slash"), "ContentRegistry 从 ContentDatabase 读取技能资源")
	context.check(legacy_registry.wave_for_time(180.0) == database.wave(3), "ContentRegistry 保留按时间查询波次的旧接口")

	if owns_database:
		database.queue_free()
		await tree.process_frame
