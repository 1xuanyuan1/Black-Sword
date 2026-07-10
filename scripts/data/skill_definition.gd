class_name SkillDefinition
extends Resource

enum SkillType { ACTIVE, PASSIVE }

var id: StringName
var display_name: String
var description: String
var skill_type: SkillType = SkillType.ACTIVE
var max_level: int = 5
var accent: Color = Color.WHITE
var values: Array[Dictionary] = []


static func create(
	new_id: StringName,
	new_name: String,
	new_description: String,
	new_type: SkillType,
	new_accent: Color,
	new_values: Array[Dictionary]
) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = new_id
	definition.display_name = new_name
	definition.description = new_description
	definition.skill_type = new_type
	definition.accent = new_accent
	definition.values = new_values
	definition.max_level = new_values.size()
	return definition


func stats(level: int) -> Dictionary:
	if values.is_empty():
		return {}
	return values[clampi(level - 1, 0, values.size() - 1)]


func level_text(level: int) -> String:
	if level <= 0:
		return "习得新招式"
	if level >= max_level:
		return "已臻化境"
	var current := stats(level)
	var next := stats(level + 1)
	if next.has("upgrade"):
		return str(next["upgrade"])
	return "强化伤害、范围与释放频率"
