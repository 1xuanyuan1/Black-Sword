class_name ContentRegistry
extends RefCounted

const CONTENT_DATABASE_SCRIPT := preload("res://scripts/autoload/content_database.gd")

var skills: Dictionary = {}
var enemies: Dictionary = {}
var waves: Array[WaveDefinition] = []
var characters: Dictionary = {}
var _database_errors := PackedStringArray()


func _init() -> void:
	var database := _resolve_database()
	skills = database.call("all_skills")
	enemies = database.call("all_enemies")
	characters = database.call("all_characters")
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
