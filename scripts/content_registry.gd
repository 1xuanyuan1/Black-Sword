class_name ContentRegistry
extends RefCounted

const CONTENT_DATABASE_SCRIPT := preload("res://scripts/autoload/content_database.gd")

var skills: Dictionary = {}
var enemies: Dictionary = {}
var waves: Array[WaveDefinition] = []
var characters: Dictionary = {}
var items: Dictionary = {}
var evolutions: Dictionary = {}
var _database_errors := PackedStringArray()


func _init() -> void:
	var database := _resolve_database()
	skills = database.call("all_skills")
	enemies = database.call("all_enemies")
	characters = database.call("all_characters")
	items = database.call("all_items")
	evolutions = database.call("all_evolutions")
	for wave_resource in database.call("all_waves"):
		waves.append(wave_resource as WaveDefinition)
	_database_errors = database.call("validate_all")
	if database.get_parent() == null:
		database.free()


func _resolve_database() -> Node:
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop != null:
		var autoload_database := main_loop.root.get_node_or_null("ContentDatabase")
		if autoload_database != null:
			return autoload_database
	var local_database := CONTENT_DATABASE_SCRIPT.new() as Node
	local_database.call("reload_content")
	return local_database


func wave_for_time(elapsed: float) -> WaveDefinition:
	for wave in waves:
		if elapsed >= wave.start_time and elapsed < wave.end_time:
			return wave
	return null


func validate() -> PackedStringArray:
	var errors := _database_errors.duplicate()
	if skills.size() != 30:
		errors.append("技能数量应为 30，实际为 %d" % skills.size())
	var active_count := 0
	var passive_count := 0
	var evolved_count := 0
	for skill in skills.values():
		if skill.skill_type == SkillDefinition.SkillType.ACTIVE:
			active_count += 1
		elif skill.skill_type == SkillDefinition.SkillType.PASSIVE:
			passive_count += 1
		elif skill.skill_type == SkillDefinition.SkillType.EVOLVED:
			evolved_count += 1
		var expected_level := 1 if skill.skill_type == SkillDefinition.SkillType.EVOLVED else 5
		if skill.max_level != expected_level:
			errors.append("%s 的最大等级不符合类型" % skill.display_name)
	if active_count != 10 or passive_count != 10 or evolved_count != 10:
		errors.append("技能池应为 10 主动 + 10 心法 + 10 进阶，实际为 %d + %d + %d" % [active_count, passive_count, evolved_count])
	if evolutions.size() != 10:
		errors.append("进阶配方数量应为 10")
	if enemies.size() != 6:
		errors.append("普通敌人类型应为 6")
	if waves.size() != 12:
		errors.append("波次数量应为 12")
	if items.size() != 5:
		errors.append("局内道具数量应为 5")
	return errors
