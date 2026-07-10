class_name ArenaBackdrop
extends Node2D

const RUINS_TEXTURE := preload("res://assets/world/tileset_ruins.png")
const FOG_TEXTURE := preload("res://assets/world/Fog.png")
const RAYLIGHT_TEXTURE := preload("res://assets/world/Raylight.png")
const ARENA_TEXTURE := preload("res://assets/world/arena_background.png")

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
	_create_fog()


func _process(delta: float) -> void:
	for index in range(fog_sprites.size()):
		var fog := fog_sprites[index]
		fog.position.x += (8.0 + index * 2.0) * delta
		if fog.position.x > bounds.end.x + 240.0:
			fog.position.x = bounds.position.x - 240.0


func _draw() -> void:
	pass


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
