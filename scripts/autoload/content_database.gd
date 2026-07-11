extends Node

const CHARACTER_DEFINITION_SCRIPT := preload("res://scripts/data/character_definition.gd")
const SKILL_DEFINITION_SCRIPT := preload("res://scripts/data/skill_definition.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")
const WAVE_DEFINITION_SCRIPT := preload("res://scripts/data/wave_definition.gd")
const ITEM_DEFINITION_SCRIPT := preload("res://scripts/data/item_definition.gd")
const META_UPGRADE_DEFINITION_SCRIPT := preload("res://scripts/data/meta_upgrade_definition.gd")
const EVOLUTION_RECIPE_SCRIPT := preload("res://scripts/data/evolution_recipe.gd")

const CHARACTER_DIRECTORY := "res://data/characters"
const SKILL_DIRECTORY := "res://data/skills"
const ENEMY_DIRECTORY := "res://data/enemies"
const WAVE_DIRECTORY := "res://data/waves"
const ITEM_DIRECTORY := "res://data/items"
const META_UPGRADE_DIRECTORY := "res://data/meta"
const EVOLUTION_DIRECTORY := "res://data/evolutions"

var _characters: Dictionary = {}
var _skills: Dictionary = {}
var _enemies: Dictionary = {}
var _waves: Array[WaveDefinition] = []
var _items: Dictionary = {}
var _meta_upgrades: Dictionary = {}
var _evolutions: Dictionary = {}
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
	_items.clear()
	_meta_upgrades.clear()
	_evolutions.clear()
	_load_errors.clear()
	_load_indexed_resources(CHARACTER_DIRECTORY, CHARACTER_DEFINITION_SCRIPT, _characters)
	_load_indexed_resources(SKILL_DIRECTORY, SKILL_DEFINITION_SCRIPT, _skills)
	_load_indexed_resources(ENEMY_DIRECTORY, ENEMY_DEFINITION_SCRIPT, _enemies)
	_load_waves()
	_load_indexed_resources(ITEM_DIRECTORY, ITEM_DEFINITION_SCRIPT, _items)
	_load_indexed_resources(META_UPGRADE_DIRECTORY, META_UPGRADE_DEFINITION_SCRIPT, _meta_upgrades)
	_load_indexed_resources(EVOLUTION_DIRECTORY, EVOLUTION_RECIPE_SCRIPT, _evolutions)
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


func meta_upgrade(id: StringName) -> MetaUpgradeDefinition:
	return _meta_upgrades.get(id) as MetaUpgradeDefinition


func item(id: StringName) -> ItemDefinition:
	return _items.get(id) as ItemDefinition


func evolution(id: StringName) -> EvolutionRecipe:
	return _evolutions.get(id) as EvolutionRecipe


func evolution_for_active(id: StringName) -> EvolutionRecipe:
	for value in _evolutions.values():
		var recipe := value as EvolutionRecipe
		if recipe.active_skill_id == id:
			return recipe
	return null


func all_characters() -> Dictionary:
	return _characters.duplicate()


func all_skills() -> Dictionary:
	return _skills.duplicate()


func all_enemies() -> Dictionary:
	return _enemies.duplicate()


func all_waves() -> Array[WaveDefinition]:
	return _waves.duplicate()


func all_meta_upgrades() -> Dictionary:
	return _meta_upgrades.duplicate()


func all_items() -> Dictionary:
	return _items.duplicate()


func all_evolutions() -> Dictionary:
	return _evolutions.duplicate()


func validate_all() -> PackedStringArray:
	return _load_errors.duplicate()


func content_counts() -> Dictionary:
	return {
		"characters": _characters.size(),
		"skills": _skills.size(),
		"enemies": _enemies.size(),
		"waves": _waves.size(),
		"items": _items.size(),
		"meta_upgrades": _meta_upgrades.size(),
		"evolutions": _evolutions.size(),
	}


func _load_indexed_resources(directory: String, expected_script: Script, target: Dictionary) -> void:
	var files := DirAccess.get_files_at(directory)
	files.sort()
	for raw_file_name in files:
		var file_name := raw_file_name.trim_suffix(".remap") if raw_file_name.ends_with(".remap") else raw_file_name
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
	for raw_file_name in files:
		var file_name := raw_file_name.trim_suffix(".remap") if raw_file_name.ends_with(".remap") else raw_file_name
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
		if character_definition.unlock_condition_id not in [&"default", &"wave_complete", &"first_evolution", &"first_victory"]:
			errors.append("角色 %s 的解锁条件无效：%s" % [character_definition.id, character_definition.unlock_condition_id])
		if character_definition.unlock_condition_id == &"default" and character_definition.unlock_cost != 0:
			errors.append("默认角色 %s 不应收取解锁费用" % character_definition.id)
		if character_definition.unlock_condition_id != &"default" and character_definition.unlock_cost <= 0:
			errors.append("可解锁角色 %s 的费用必须大于零" % character_definition.id)
		if character_definition.trait_description.is_empty() or character_definition.trait_modifiers.is_empty():
			errors.append("角色 %s 缺少固有特性数据" % character_definition.id)
	for definition in _skills.values():
		var skill_definition := definition as SkillDefinition
		if skill_definition.values.size() != skill_definition.max_level or skill_definition.max_level <= 0:
			errors.append("技能 %s 的等级数据与 max_level 不一致" % skill_definition.id)
	var active_skill_count := 0
	var passive_skill_count := 0
	var evolved_skill_count := 0
	for definition in _skills.values():
		var skill_definition := definition as SkillDefinition
		if skill_definition.skill_type == SkillDefinition.SkillType.ACTIVE:
			active_skill_count += 1
		elif skill_definition.skill_type == SkillDefinition.SkillType.PASSIVE:
			passive_skill_count += 1
		elif skill_definition.skill_type == SkillDefinition.SkillType.EVOLVED:
			evolved_skill_count += 1
	if active_skill_count != 10 or passive_skill_count != 10 or evolved_skill_count != 10:
		errors.append("V1 技能池必须为 10 主动 + 10 心法 + 10 进阶")
	var used_actives := {}
	var used_evolved := {}
	for value in _evolutions.values():
		var recipe := value as EvolutionRecipe
		var active := _skills.get(recipe.active_skill_id) as SkillDefinition
		var passive := _skills.get(recipe.passive_skill_id) as SkillDefinition
		var evolved := _skills.get(recipe.evolved_skill_id) as SkillDefinition
		if active == null or active.skill_type != SkillDefinition.SkillType.ACTIVE:
			errors.append("进阶配方 %s 的主动引用无效" % recipe.id)
		if passive == null or passive.skill_type != SkillDefinition.SkillType.PASSIVE:
			errors.append("进阶配方 %s 的心法引用无效" % recipe.id)
		if evolved == null or evolved.skill_type != SkillDefinition.SkillType.EVOLVED:
			errors.append("进阶配方 %s 的进阶引用无效" % recipe.id)
		if used_actives.has(recipe.active_skill_id):
			errors.append("主动技能存在重复进阶配方：%s" % recipe.active_skill_id)
		if used_evolved.has(recipe.evolved_skill_id):
			errors.append("进阶技能被多个配方引用：%s" % recipe.evolved_skill_id)
		used_actives[recipe.active_skill_id] = true
		used_evolved[recipe.evolved_skill_id] = true
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
	for definition in _meta_upgrades.values():
		var meta_definition := definition as MetaUpgradeDefinition
		if meta_definition.max_level <= 0:
			errors.append("局外养成 %s 的等级上限无效" % meta_definition.id)
		if meta_definition.costs.size() != meta_definition.max_level:
			errors.append("局外养成 %s 的费用数量与等级上限不一致" % meta_definition.id)
		if meta_definition.values.size() != meta_definition.max_level:
			errors.append("局外养成 %s 的效果数量与等级上限不一致" % meta_definition.id)
		for cost in meta_definition.costs:
			if cost <= 0:
				errors.append("局外养成 %s 包含无效费用" % meta_definition.id)
				break
	for definition in _items.values():
		var item_definition := definition as ItemDefinition
		if item_definition.icon == null:
			errors.append("局内道具 %s 缺少图标" % item_definition.id)
		if item_definition.world_scene == null:
			errors.append("局内道具 %s 缺少世界场景" % item_definition.id)
		if item_definition.base_weight <= 0.0:
			errors.append("局内道具 %s 的掉落权重无效" % item_definition.id)
		if not ItemEffectRegistry.new().supports(item_definition.effect_id):
			errors.append("局内道具 %s 使用了未注册效果：%s" % [item_definition.id, item_definition.effect_id])
	return errors
