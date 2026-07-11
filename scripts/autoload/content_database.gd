extends Node

const CHARACTER_DEFINITION_SCRIPT := preload("res://scripts/data/character_definition.gd")
const SKILL_DEFINITION_SCRIPT := preload("res://scripts/data/skill_definition.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")
const WAVE_DEFINITION_SCRIPT := preload("res://scripts/data/wave_definition.gd")

const CHARACTER_DIRECTORY := "res://data/characters"
const SKILL_DIRECTORY := "res://data/skills"
const ENEMY_DIRECTORY := "res://data/enemies"
const WAVE_DIRECTORY := "res://data/waves"

var _characters: Dictionary = {}
var _skills: Dictionary = {}
var _enemies: Dictionary = {}
var _waves: Array[WaveDefinition] = []
var _load_errors := PackedStringArray()


func _ready() -> void:
	reload_content()
	for error in _load_errors:
		push_error(error)


func reload_content() -> void:
	_characters.clear()
	_skills.clear()
	_enemies.clear()
	_waves.clear()
	_load_errors.clear()
	_load_indexed_resources(CHARACTER_DIRECTORY, CHARACTER_DEFINITION_SCRIPT, _characters)
	_load_indexed_resources(SKILL_DIRECTORY, SKILL_DEFINITION_SCRIPT, _skills)
	_load_indexed_resources(ENEMY_DIRECTORY, ENEMY_DEFINITION_SCRIPT, _enemies)
	_load_waves()
	_load_errors.append_array(_validate_references())


func character(id: StringName) -> CharacterDefinition:
	return _characters.get(id) as CharacterDefinition


func skill(id: StringName) -> SkillDefinition:
	return _skills.get(id) as SkillDefinition


func enemy(id: StringName) -> EnemyDefinition:
	return _enemies.get(id) as EnemyDefinition


func wave(index: int) -> WaveDefinition:
	for definition in _waves:
		if definition.index == index:
			return definition
	return null


func all_characters() -> Dictionary:
	return _characters.duplicate()


func all_skills() -> Dictionary:
	return _skills.duplicate()


func all_enemies() -> Dictionary:
	return _enemies.duplicate()


func all_waves() -> Array[WaveDefinition]:
	return _waves.duplicate()


func validate_all() -> PackedStringArray:
	return _load_errors.duplicate()


func content_counts() -> Dictionary:
	return {
		"characters": _characters.size(),
		"skills": _skills.size(),
		"enemies": _enemies.size(),
		"waves": _waves.size(),
	}


func _load_indexed_resources(directory: String, expected_script: Script, target: Dictionary) -> void:
	var files := DirAccess.get_files_at(directory)
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var path := directory.path_join(file_name)
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if resource == null:
			_load_errors.append("无法加载内容资源：%s" % path)
			continue
		if resource.get_script() != expected_script:
			_load_errors.append("内容资源类型错误：%s" % path)
			continue
		var id := StringName(resource.get("id"))
		if id.is_empty():
			_load_errors.append("内容资源缺少 ID：%s" % path)
			continue
		if target.has(id):
			_load_errors.append("内容资源 ID 重复：%s" % id)
			continue
		target[id] = resource


func _load_waves() -> void:
	var files := DirAccess.get_files_at(WAVE_DIRECTORY)
	files.sort()
	var indices := {}
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var path := WAVE_DIRECTORY.path_join(file_name)
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if resource == null or resource.get_script() != WAVE_DEFINITION_SCRIPT:
			_load_errors.append("波次资源无效：%s" % path)
			continue
		var definition := resource as WaveDefinition
		if definition.index <= 0:
			_load_errors.append("波次索引必须大于零：%s" % path)
			continue
		if indices.has(definition.index):
			_load_errors.append("波次索引重复：%d" % definition.index)
			continue
		indices[definition.index] = true
		_waves.append(definition)
	_waves.sort_custom(func(a: WaveDefinition, b: WaveDefinition) -> bool: return a.index < b.index)


func _validate_references() -> PackedStringArray:
	var errors := PackedStringArray()
	for definition in _characters.values():
		var character_definition := definition as CharacterDefinition
		if character_definition.actor_scene == null:
			errors.append("角色 %s 缺少 actor_scene" % character_definition.id)
		if character_definition.portrait == null:
			errors.append("角色 %s 缺少 portrait" % character_definition.id)
		if not _skills.has(character_definition.initial_skill_id):
			errors.append("角色 %s 的初始技能不存在：%s" % [character_definition.id, character_definition.initial_skill_id])
	for definition in _skills.values():
		var skill_definition := definition as SkillDefinition
		if skill_definition.values.size() != skill_definition.max_level or skill_definition.max_level <= 0:
			errors.append("技能 %s 的等级数据与 max_level 不一致" % skill_definition.id)
	for definition in _enemies.values():
		var enemy_definition := definition as EnemyDefinition
		if enemy_definition.actor_scene == null:
			errors.append("敌人 %s 缺少 actor_scene" % enemy_definition.id)
		if enemy_definition.texture == null:
			errors.append("敌人 %s 缺少 texture" % enemy_definition.id)
	for definition in _waves:
		if definition.end_time <= definition.start_time:
			errors.append("波次 %d 的时间范围无效" % definition.index)
		if definition.spawn_interval <= 0.0 or definition.enemy_cap <= 0:
			errors.append("波次 %d 的生成参数无效" % definition.index)
		var total_weight := 0.0
		for enemy_id in definition.enemy_weights:
			if not _enemies.has(enemy_id):
				errors.append("波次 %d 引用了不存在的敌人：%s" % [definition.index, enemy_id])
			total_weight += float(definition.enemy_weights[enemy_id])
		if not is_equal_approx(total_weight, 1.0):
			errors.append("波次 %d 的敌人权重总和不是 1" % definition.index)
	return errors
