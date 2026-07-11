class_name MetaUpgradeDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var max_level: int
@export var costs: PackedInt32Array
@export var values: Array[Dictionary] = []


func cost_for_next_level(current_level: int) -> int:
	if current_level < 0 or current_level >= max_level or current_level >= costs.size():
		return -1
	return costs[current_level]


func stats(level: int) -> Dictionary:
	if level <= 0 or values.is_empty():
		return {}
	return values[clampi(level - 1, 0, values.size() - 1)]


func invested_cost(level: int) -> int:
	var result := 0
	for index in range(clampi(level, 0, costs.size())):
		result += costs[index]
	return result
