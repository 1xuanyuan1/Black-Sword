@tool
extends SceneTree

const TILESET_PATH := "res://assets/world/abandoned_temple_tileset.tres"
const TILE_WORLD_PATH := "res://scenes/world/abandoned_temple_tile_world.tscn"
const MAP_ORIGIN := Vector2(-1536.0, -864.0)
const MAP_SCALE := 4.0
const MAP_SIZE := Vector2i(48, 27)

const FLOOR_SOURCE_ID := 0
const COURTYARD_SOURCE_ID := 1
const DETAIL_SOURCE_ID := 2
const WALL_SOURCE_ID := 3

const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(14, 16), Vector2i(15, 16), Vector2i(16, 16),
	Vector2i(17, 16), Vector2i(18, 16), Vector2i(19, 16),
]
const COURTYARD_TILES: Array[Vector2i] = [
	Vector2i(15, 14), Vector2i(16, 14), Vector2i(17, 14),
	Vector2i(19, 14), Vector2i(20, 14),
]
const DETAIL_TILES: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(4, 2), Vector2i(7, 2), Vector2i(13, 0), Vector2i(15, 0),
]
const WALL_TILE := Vector2i(15, 12)
const TREE_REGION := Rect2(64.0, 96.0, 32.0, 32.0)
const HOUSE_REGION := Rect2(192.0, 96.0, 48.0, 80.0)

const TREE_WORLD_POSITIONS: Array[Vector2] = [
	Vector2(-1351.84, -398.48), Vector2(-1065.44, -275.68),
	Vector2(-1274.24, -42.28), Vector2(-1015.68, 127.04),
	Vector2(-1361.28, 333.84), Vector2(-1104.8, 521.4),
	Vector2(-1304.96, 708.88), Vector2(1326.24, -421.72),
	Vector2(1067.84, -221.52), Vector2(1289.44, 7.68),
	Vector2(980.96, 188.12), Vector2(1257.12, 408.64),
	Vector2(1028.16, 605.52), Vector2(1333.76, 726.72),
]


func _init() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var tile_set := _build_tile_set()
	var tileset_error := ResourceSaver.save(tile_set, TILESET_PATH)
	if tileset_error != OK:
		push_error("无法保存荒寺 TileSet：%s" % error_string(tileset_error))
		quit(tileset_error)
		return

	var saved_tile_set := load(TILESET_PATH) as TileSet
	if saved_tile_set == null:
		push_error("无法重新加载已保存的荒寺 TileSet")
		quit(ERR_FILE_CANT_READ)
		return
	var tile_world := _build_tile_world(saved_tile_set)
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(tile_world)
	if pack_error != OK:
		push_error("无法打包荒寺瓦片地图：%s" % error_string(pack_error))
		quit(pack_error)
		return
	var scene_error := ResourceSaver.save(packed_scene, TILE_WORLD_PATH)
	if scene_error != OK:
		push_error("无法保存荒寺瓦片地图：%s" % error_string(scene_error))
		quit(scene_error)
		return

	print("GENERATED ", TILESET_PATH)
	print("GENERATED ", TILE_WORLD_PATH)
	tile_world.free()
	quit(OK)


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 2)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var floor_source := _create_atlas_source("res://assets/world/tileset_floor.png", FLOOR_TILES)
	tile_set.add_source(floor_source, FLOOR_SOURCE_ID)
	var courtyard_source := _create_atlas_source("res://assets/world/tileset_courtyard.png", COURTYARD_TILES)
	tile_set.add_source(courtyard_source, COURTYARD_SOURCE_ID)
	var detail_source := _create_atlas_source("res://assets/world/tileset_detail.png", DETAIL_TILES)
	tile_set.add_source(detail_source, DETAIL_SOURCE_ID)
	var wall_source := _create_atlas_source("res://assets/world/tileset_courtyard.png", [WALL_TILE])
	tile_set.add_source(wall_source, WALL_SOURCE_ID)

	var wall_data := wall_source.get_tile_data(WALL_TILE, 0)
	wall_data.add_collision_polygon(0)
	wall_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8.0, -8.0), Vector2(8.0, -8.0),
		Vector2(8.0, 8.0), Vector2(-8.0, 8.0),
	]))
	return tile_set


func _create_atlas_source(texture_path: String, coords: Array[Vector2i]) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path) as Texture2D
	source.texture_region_size = Vector2i(16, 16)
	for coord in coords:
		source.create_tile(coord)
	return source


func _build_tile_world(tile_set: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = "PixelMapRoot"
	root.position = MAP_ORIGIN
	root.scale = Vector2.ONE * MAP_SCALE
	root.y_sort_enabled = true
	root.editor_description = "16×16 TileSet，整数 4 倍缩放，对齐 3072×1728 战斗边界。"

	var ground := _create_layer("GroundBase", tile_set, -50, false)
	root.add_child(ground)
	var details := _create_layer("GroundDetail", tile_set, -49, false)
	root.add_child(details)
	var walls := _create_layer("Walls", tile_set, 0, true)
	walls.y_sort_enabled = true
	root.add_child(walls)

	_paint_ground(ground)
	_paint_details(details)
	_paint_walls(walls)
	_add_ground_seal(root)
	_add_props(root)
	_assign_scene_owner(root, root)
	return root


func _create_layer(layer_name: String, tile_set: TileSet, layer_z: int, collisions: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = layer_z
	layer.collision_enabled = collisions
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer


func _paint_ground(layer: TileMapLayer) -> void:
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var variation := _cell_hash(cell)
			if _is_courtyard_cell(cell):
				var courtyard_coord := COURTYARD_TILES[variation % COURTYARD_TILES.size()]
				layer.set_cell(cell, COURTYARD_SOURCE_ID, courtyard_coord)
			else:
				var floor_coord := FLOOR_TILES[variation % FLOOR_TILES.size()]
				layer.set_cell(cell, FLOOR_SOURCE_ID, floor_coord)
	layer.modulate = Color(0.58, 0.62, 0.72, 1.0)


func _is_courtyard_cell(cell: Vector2i) -> bool:
	var mountain_gate := Rect2i(17, 14, 14, 12)
	var scripture_library := Rect2i(32, 3, 15, 21)
	var seal_hall := Rect2i(16, 1, 16, 10)
	var central_cross := Rect2i(15, 10, 18, 8)
	return mountain_gate.has_point(cell) \
		or scripture_library.has_point(cell) \
		or seal_hall.has_point(cell) \
		or central_cross.has_point(cell)


func _paint_details(layer: TileMapLayer) -> void:
	for y in range(3, 24):
		for x in range(1, 15):
			var cell := Vector2i(x, y)
			var variation := _cell_hash(cell)
			if variation % 6 == 0:
				var detail_coord := DETAIL_TILES[variation % 5]
				layer.set_cell(cell, DETAIL_SOURCE_ID, detail_coord)

	for cell in [Vector2i(20, 6), Vector2i(29, 4), Vector2i(35, 9), Vector2i(42, 18)]:
		layer.set_cell(cell, DETAIL_SOURCE_ID, Vector2i(13, 0))
	for cell in [Vector2i(22, 8), Vector2i(27, 7), Vector2i(38, 14), Vector2i(44, 21)]:
		layer.set_cell(cell, DETAIL_SOURCE_ID, Vector2i(15, 0))
	layer.modulate = Color(0.62, 0.7, 0.68, 0.82)


func _paint_walls(layer: TileMapLayer) -> void:
	var wall_cells: Dictionary = {}
	for y in range(3, 24):
		if y < 13 or y > 17:
			wall_cells[Vector2i(15, y)] = true
			wall_cells[Vector2i(32, y)] = true
	for x in range(16, 32):
		if x < 22 or x > 26:
			wall_cells[Vector2i(x, 10)] = true

	for cell in [
		Vector2i(36, 6), Vector2i(36, 7), Vector2i(36, 8),
		Vector2i(42, 10), Vector2i(42, 11), Vector2i(42, 12),
		Vector2i(38, 17), Vector2i(39, 17), Vector2i(40, 17),
		Vector2i(18, 3), Vector2i(29, 3), Vector2i(18, 8), Vector2i(29, 8),
	]:
		wall_cells[cell] = true

	for cell in wall_cells.keys():
		layer.set_cell(cell as Vector2i, WALL_SOURCE_ID, WALL_TILE)
	layer.modulate = Color(0.74, 0.76, 0.84, 1.0)


func _add_ground_seal(root: Node2D) -> void:
	var seal := Sprite2D.new()
	seal.name = "SealHallGroundMark"
	seal.texture = load("res://assets/vfx/magic_circle.png") as Texture2D
	seal.hframes = 4
	seal.frame = 0
	seal.position = _world_to_local(Vector2(0.0, -470.0))
	seal.scale = Vector2.ONE * 2.6
	seal.modulate = Color(0.46, 0.64, 0.9, 0.32)
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seal.z_index = -48
	root.add_child(seal)


func _add_props(root: Node2D) -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = 0
	props.y_sort_enabled = true
	root.add_child(props)
	var ruins_texture := load("res://assets/world/tileset_ruins.png") as Texture2D

	for index in range(TREE_WORLD_POSITIONS.size()):
		var tree_anchor := Node2D.new()
		tree_anchor.name = "TreeVisual%02d" % (index + 1)
		tree_anchor.position = _world_to_local(TREE_WORLD_POSITIONS[index])
		var tree_sprite := _create_region_sprite(ruins_texture, TREE_REGION)
		tree_sprite.position = Vector2(0.0, -10.0)
		tree_sprite.modulate = Color(0.52, 0.62, 0.45, 1.0)
		tree_anchor.add_child(tree_sprite)
		props.add_child(tree_anchor)

	_add_house(props, ruins_texture, "SealHallShrine", Vector2(0.0, -540.0))
	_add_house(props, ruins_texture, "NorthScriptureHall", Vector2(1080.0, -280.0))
	_add_house(props, ruins_texture, "SouthScriptureHall", Vector2(1080.0, 520.0))


func _add_house(parent: Node2D, texture: Texture2D, node_name: String, world_position: Vector2) -> void:
	var house := StaticBody2D.new()
	house.name = node_name
	house.position = _world_to_local(world_position)
	house.collision_layer = 2
	house.collision_mask = 0
	house.add_to_group("world_walls", true)
	var sprite := _create_region_sprite(texture, HOUSE_REGION)
	sprite.position = Vector2(0.0, -40.0)
	sprite.modulate = Color(0.62, 0.58, 0.58, 1.0)
	house.add_child(sprite)
	var collision := CollisionShape2D.new()
	collision.name = "BuildingCollision"
	collision.position = Vector2(0.0, -28.0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44.0, 40.0)
	collision.shape = shape
	house.add_child(collision)
	parent.add_child(house)


func _create_region_sprite(texture: Texture2D, region: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _world_to_local(world_position: Vector2) -> Vector2:
	return (world_position - MAP_ORIGIN) / MAP_SCALE


func _cell_hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)


func _assign_scene_owner(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_assign_scene_owner(child, scene_root)
