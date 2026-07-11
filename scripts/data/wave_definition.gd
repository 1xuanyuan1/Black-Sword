class_name WaveDefinition
extends Resource

@export var index: int
@export var title: String
@export var start_time: float
@export var end_time: float
@export var spawn_interval: float
@export var enemy_weights: Dictionary
@export var enemy_cap: int
@export var elite_chance: float


static func create(data: Dictionary) -> WaveDefinition:
	var definition := WaveDefinition.new()
	definition.title = data.get("title", "夜行")
	definition.start_time = data.get("start", 0.0)
	definition.end_time = data.get("end", 60.0)
	definition.spawn_interval = data.get("interval", 1.0)
	definition.enemy_weights = data.get("weights", {})
	definition.enemy_cap = data.get("cap", 50)
	definition.elite_chance = data.get("elite", 0.0)
	return definition
