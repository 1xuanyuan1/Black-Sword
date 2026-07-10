class_name ArenaBackdrop
extends Node2D

@onready var world_collision_layer: Node2D = $WorldCollisionLayer
@onready var fog_bank_layer: Node2D = $AtmosphereLayer/FogBanks

var bounds := Rect2(-1536.0, -864.0, 3072.0, 1728.0)
var fog_sprites: Array[Sprite2D] = []


func _ready() -> void:
	for child_node in fog_bank_layer.get_children():
		var fog_sprite: Sprite2D = child_node as Sprite2D
		if fog_sprite != null:
			fog_sprites.append(fog_sprite)


func setup(arena_bounds: Rect2) -> void:
	bounds = arena_bounds
	z_index = -50


func _process(delta: float) -> void:
	for index in range(fog_sprites.size()):
		var fog := fog_sprites[index]
		fog.position.x += (8.0 + index * 2.0) * delta
		if fog.position.x > bounds.end.x + 240.0:
			fog.position.x = bounds.position.x - 240.0


func world_collision_count(group_name: StringName) -> int:
	var count := 0
	for collision_body in world_collision_layer.get_children():
		if collision_body.is_in_group(group_name):
			count += 1
	return count


func is_point_clear(world_position: Vector2, margin: float = 0.0) -> bool:
	for child_node in world_collision_layer.get_children():
		var tree_body: StaticBody2D = child_node as StaticBody2D
		if tree_body == null or not tree_body.is_in_group("world_trees"):
			continue
		var trunk_collision: CollisionShape2D = tree_body.get_node_or_null("TrunkCollision") as CollisionShape2D
		if trunk_collision == null:
			continue
		var trunk_shape: CircleShape2D = trunk_collision.shape as CircleShape2D
		if trunk_shape == null:
			continue
		var trunk_center: Vector2 = tree_body.global_position + trunk_collision.position
		if world_position.distance_to(trunk_center) <= trunk_shape.radius + margin:
			return false
	return true
