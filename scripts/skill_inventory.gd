class_name SkillInventory
extends RefCounted

const ACTIVE_LIMIT := 6
const PASSIVE_LIMIT := 6
const RECOVERY_ID: StringName = &"recovery"

var definitions: Dictionary = {}
var levels: Dictionary = {}
var active_ids: Array[StringName] = []
var passive_ids: Array[StringName] = []
var evolved_ids: Dictionary = {}
var rng := RandomNumberGenerator.new()


func setup(skill_definitions: Dictionary, seed: int = 0) -> void:
	definitions = skill_definitions.duplicate()
	levels.clear()
	active_ids.clear()
	passive_ids.clear()
	evolved_ids.clear()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed


func get_upgrade_options(count: int = 3, custom_rng: RandomNumberGenerator = null) -> Array[SkillDefinition]:
	var candidates: Array[SkillDefinition] = []
	for value in definitions.values():
		var definition := value as SkillDefinition
		if definition == null or definition.skill_type == SkillDefinition.SkillType.EVOLVED:
			continue
		var current_level: int = levels.get(definition.id, 0)
		if current_level > 0 and current_level < definition.max_level:
			candidates.append(definition)
		elif current_level == 0 and can_add_skill(definition.id):
			candidates.append(definition)
	candidates.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool: return a.id < b.id)
	_shuffle(candidates, custom_rng if custom_rng != null else rng)
	var options: Array[SkillDefinition] = candidates.slice(0, mini(count, candidates.size()))
	while options.size() < count:
		options.append(_recovery_definition())
	return options


func can_add_skill(id: StringName) -> bool:
	var definition := definitions.get(id) as SkillDefinition
	if definition == null or levels.get(id, 0) > 0:
		return false
	match definition.skill_type:
		SkillDefinition.SkillType.ACTIVE:
			return active_ids.size() < ACTIVE_LIMIT
		SkillDefinition.SkillType.PASSIVE:
			return passive_ids.size() < PASSIVE_LIMIT
		_:
			return false


func upgrade(id: StringName) -> SkillUpgradeResult:
	var definition := definitions.get(id) as SkillDefinition
	if definition == null:
		return SkillUpgradeResult.failure(id, &"unknown_skill")
	if definition.skill_type == SkillDefinition.SkillType.EVOLVED:
		return SkillUpgradeResult.failure(id, &"evolved_not_upgradeable")
	var current_level: int = levels.get(id, 0)
	if current_level >= definition.max_level:
		return SkillUpgradeResult.failure(id, &"max_level")
	var added := false
	if current_level == 0:
		if not can_add_skill(id):
			return SkillUpgradeResult.failure(id, &"slot_full")
		if definition.skill_type == SkillDefinition.SkillType.ACTIVE:
			active_ids.append(id)
		else:
			passive_ids.append(id)
		added = true
	levels[id] = current_level + 1
	return SkillUpgradeResult.upgraded(id, current_level, current_level + 1, added)


func level_of(id: StringName) -> int:
	return int(levels.get(id, 0))


func has_skill(id: StringName) -> bool:
	return level_of(id) > 0


func _shuffle(values: Array[SkillDefinition], random: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var held := values[index]
		values[index] = values[other]
		values[other] = held


func _recovery_definition() -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = RECOVERY_ID
	definition.display_name = "调息"
	definition.description = "恢复 20% 最大生命。"
	definition.skill_type = SkillDefinition.SkillType.PASSIVE
	definition.max_level = 1
	definition.accent = Color("7fe5a5")
	definition.values = [{"heal_ratio": 0.20, "upgrade": "恢复 20% 最大生命"}]
	return definition
