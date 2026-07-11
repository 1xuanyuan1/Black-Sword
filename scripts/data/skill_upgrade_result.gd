class_name SkillUpgradeResult
extends RefCounted

var success := false
var skill_id: StringName
var previous_level := 0
var new_level := 0
var added_to_slot := false
var recovered_health := false
var reason: StringName


static func failure(id: StringName, failure_reason: StringName) -> SkillUpgradeResult:
	var result := SkillUpgradeResult.new()
	result.skill_id = id
	result.reason = failure_reason
	return result


static func upgraded(id: StringName, old_level: int, level: int, added: bool) -> SkillUpgradeResult:
	var result := SkillUpgradeResult.new()
	result.success = true
	result.skill_id = id
	result.previous_level = old_level
	result.new_level = level
	result.added_to_slot = added
	return result


static func recovery() -> SkillUpgradeResult:
	var result := SkillUpgradeResult.new()
	result.success = true
	result.skill_id = &"recovery"
	result.recovered_health = true
	return result
