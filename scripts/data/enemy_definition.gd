class_name EnemyDefinition
extends Resource

var id: StringName
var display_name: String
var max_health: float
var speed: float
var damage: float
var xp_value: int
var attack_range: float
var attack_cooldown: float
var texture: Texture2D
var visual_kind: StringName
var behavior: StringName
var scale_factor: float = 3.5
var tint: Color = Color.WHITE


static func create(data: Dictionary) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.id = data.get("id", &"enemy")
	definition.display_name = data.get("name", "敌人")
	definition.max_health = data.get("health", 20.0)
	definition.speed = data.get("speed", 80.0)
	definition.damage = data.get("damage", 8.0)
	definition.xp_value = data.get("xp", 1)
	definition.attack_range = data.get("range", 34.0)
	definition.attack_cooldown = data.get("cooldown", 1.2)
	definition.texture = data.get("texture")
	definition.visual_kind = data.get("visual_kind", &"character")
	definition.behavior = data.get("behavior", &"melee")
	definition.scale_factor = data.get("scale", 3.5)
	definition.tint = data.get("tint", Color.WHITE)
	return definition
