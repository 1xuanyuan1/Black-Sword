class_name ArenaBackdrop
extends Node2D

const RUINS_TEXTURE := preload("res://assets/world/tileset_ruins.png")
const FOG_TEXTURE := preload("res://assets/world/Fog.png")
const RAYLIGHT_TEXTURE := preload("res://assets/world/Raylight.png")
const ARENA_TEXTURE := preload("res://assets/world/arena_background.png")
const BASE_MAP_SIZE := Vector2(768.0, 432.0)
const TREE_LAYOUT_BASE := [
	Vector3(31.0, 91.0, 0.94), Vector3(101.0, 119.0, 1.04),
	Vector3(48.0, 176.0, 1.09), Vector3(116.0, 224.0, 0.88),
	Vector3(28.0, 273.0, 0.98), Vector3(91.0, 318.0, 1.05),
	Vector3(44.0, 370.0, 0.86), Vector3(701.0, 86.0, 0.91),
	Vector3(634.0, 132.0, 1.06), Vector3(691.0, 192.0, 0.96),
	Vector3(615.0, 239.0, 0.89), Vector3(681.0, 289.0, 1.08),
	Vector3(626.0, 342.0, 0.94), Vector3(704.0, 375.0, 0.84),
]
const WALL_RECTS_BASE := [
	Rect2(177.0, 76.0, 167.0, 10.0),
	Rect2(416.0, 76.0, 175.0, 10.0),
	Rect2(177.0, 358.0, 167.0, 10.0),
	Rect2(416.0, 358.0, 175.0, 10.0),
	Rect2(177.0, 84.0, 13.0, 276.0),
	Rect2(578.0, 84.0, 13.0, 276.0),
]

var bounds := Rect2(-1536.0, -864.0, 3072.0, 1728.0)
var fog_sprites: Array[Sprite2D] = []


func setup(arena_bounds: Rect2) -> void:
	bounds = arena_bounds
	z_index = -50
	var background := Sprite2D.new()
	background.texture = ARENA_TEXTURE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.position = Vector2.ZERO
	background.z_index = -2
	add_child(background)
	_create_world_collisions()
	_create_fog()


func _process(delta: float) -> void:
	for index in range(fog_sprites.size()):
		var fog := fog_sprites[index]
		fog.position.x += (8.0 + index * 2.0) * delta
		if fog.position.x > bounds.end.x + 240.0:
			fog.position.x = bounds.position.x - 240.0


func _draw() -> void:
	pass


func _create_world_collisions() -> void:
	var scale_factor: Vector2 = bounds.size / BASE_MAP_SIZE
	for wall_value in WALL_RECTS_BASE:
		var wall_rect: Rect2 = wall_value
		var wall := StaticBody2D.new()
		wall.name = "CourtyardWall"
		wall.collision_layer = 0
		wall.set_collision_layer_value(2, true)
		wall.collision_mask = 0
		wall.add_to_group("world_walls")
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall_rect.size * scale_factor
		collision.shape = shape
		wall.position = bounds.position + (wall_rect.position + wall_rect.size * 0.5) * scale_factor
		wall.add_child(collision)
		add_child(wall)
	for tree_value in TREE_LAYOUT_BASE:
		var tree_data: Vector3 = tree_value
		var tree := StaticBody2D.new()
		tree.name = "TreeTrunk"
		tree.collision_layer = 0
		tree.set_collision_layer_value(2, true)
		tree.collision_mask = 0
		tree.add_to_group("world_trees")
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 6.3 * tree_data.z * scale_factor.x
		collision.shape = shape
		var trunk_center_base: Vector2 = Vector2(tree_data.x + 16.0 * tree_data.z, tree_data.y + 27.0 * tree_data.z)
		tree.position = bounds.position + trunk_center_base * scale_factor
		tree.add_child(collision)
		add_child(tree)


func world_collision_count(group_name: StringName) -> int:
	return get_tree().get_nodes_in_group(group_name).size()


func is_point_clear(world_position: Vector2, margin: float = 0.0) -> bool:
	var scale_factor: Vector2 = bounds.size / BASE_MAP_SIZE
	for wall_value in WALL_RECTS_BASE:
		var wall_rect: Rect2 = wall_value
		var world_rect: Rect2 = Rect2(bounds.position + wall_rect.position * scale_factor, wall_rect.size * scale_factor)
		if world_rect.grow(margin).has_point(world_position):
			return false
	for tree_value in TREE_LAYOUT_BASE:
		var tree_data: Vector3 = tree_value
		var trunk_center_base: Vector2 = Vector2(tree_data.x + 16.0 * tree_data.z, tree_data.y + 27.0 * tree_data.z)
		var tree_position: Vector2 = bounds.position + trunk_center_base * scale_factor
		var tree_radius: float = 6.3 * tree_data.z * scale_factor.x
		if world_position.distance_to(tree_position) <= tree_radius + margin:
			return false
	return true


func _create_ruins() -> void:
	var gate_atlas := AtlasTexture.new()
	gate_atlas.atlas = RUINS_TEXTURE
	gate_atlas.region = Rect2(0, 0, 82, 48)
	var gate := Sprite2D.new()
	gate.texture = gate_atlas
	gate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gate.scale = Vector2.ONE * 4.4
	gate.position = Vector2(0, bounds.position.y + 118.0)
	gate.modulate = Color("77829a")
	add_child(gate)
	var side_atlas := AtlasTexture.new()
	side_atlas.atlas = RUINS_TEXTURE
	side_atlas.region = Rect2(0, 48, 112, 46)
	for x in [-1180.0, 1180.0]:
		var ruins := Sprite2D.new()
		ruins.texture = side_atlas
		ruins.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ruins.scale = Vector2.ONE * 3.8
		ruins.position = Vector2(x, -260.0)
		ruins.modulate = Color("59677f")
		add_child(ruins)


func _create_fog() -> void:
	for i in range(7):
		var fog := Sprite2D.new()
		fog.texture = FOG_TEXTURE
		fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fog.scale = Vector2(7.5, 5.0)
		fog.modulate = Color(0.42, 0.55, 0.68, 0.055)
		fog.position = Vector2(bounds.position.x + i * 510.0, -650.0 + (i % 4) * 420.0)
		fog_sprites.append(fog)
		add_child(fog)
	for x in [-980.0, 980.0]:
		var ray := Sprite2D.new()
		ray.texture = RAYLIGHT_TEXTURE
		ray.scale = Vector2(4.0, 10.0)
		ray.position = Vector2(x, -520.0)
		ray.modulate = Color(0.55, 0.66, 0.85, 0.06)
		add_child(ray)
