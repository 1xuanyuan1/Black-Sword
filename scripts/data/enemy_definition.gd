class_name EnemyDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var max_health: float
@export var speed: float
@export var damage: float
@export var xp_value: int
@export var attack_range: float
@export var attack_cooldown: float
@export var texture: Texture2D
@export var actor_scene: PackedScene
@export var visual_kind: StringName
@export var behavior: StringName
@export var scale_factor: float = 3.5
@export var tint: Color = Color.WHITE
@export var enemy_class: StringName = &"normal"
@export var tags: Array[StringName] = []


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
