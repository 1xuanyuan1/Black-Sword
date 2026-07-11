class_name WaveDefinition
extends Resource

enum WaveKind { NORMAL, MINIBOSS, FINAL_BOSS }

@export var index: int
@export var title: String
@export var start_time: float
@export var end_time: float
@export var spawn_interval: float
@export var enemy_weights: Dictionary
@export var enemy_cap: int
@export var elite_chance: float
@export var kind: WaveKind = WaveKind.NORMAL
@export var target_duration: float = 50.0
@export var rest_duration: float = 5.0
@export var boss_id: StringName
@export var environment_event_ids: Array[StringName] = []
@export var unlock_zone_id: StringName


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
