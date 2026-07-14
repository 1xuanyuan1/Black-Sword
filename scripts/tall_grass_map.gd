class_name TallGrassMap
extends Node2D

signal actor_grass_state_changed(actor: Node2D, inside: bool)

const GRASS_TEXTURE := preload("res://assets/world/tileset_detail.png")
const OCCLUSION_REGION := Rect2(48.0, 32.0, 16.0, 16.0)
const OCCLUSION_SCALE := 3.25

@onready var grass_back: TileMapLayer = $GrassBack
@onready var grass_front: TileMapLayer = $GrassFront

var actor_overlays: Dictionary = {}
var sway_time := 0.0


func _physics_process(delta: float) -> void:
	sway_time += delta
	var actors := _grass_actors()
	var active_ids: Dictionary = {}
	for actor_value in actors:
		var actor := actor_value as Node2D
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var actor_id := actor.get_instance_id()
		active_ids[actor_id] = true
		_set_actor_inside(actor, is_world_position_in_grass(actor.global_position))
		var overlay := actor_overlays.get(actor_id) as Sprite2D
		if overlay != null:
			var phase := sway_time * 4.5 + float(actor_id % 17) * 0.37
			overlay.rotation = sin(phase) * 0.045
			overlay.position = Vector2(sin(phase * 0.73) * 1.6, 11.0)

	for actor_id_value in actor_overlays.keys():
		var actor_id := int(actor_id_value)
		if active_ids.has(actor_id):
			continue
		var stale_overlay := actor_overlays[actor_id] as Sprite2D
		if is_instance_valid(stale_overlay):
			stale_overlay.queue_free()
		actor_overlays.erase(actor_id)


func is_world_position_in_grass(world_position: Vector2) -> bool:
	if grass_back == null:
		return false
	var local_position := grass_back.to_local(world_position)
	var cell := grass_back.local_to_map(local_position)
	return grass_back.get_cell_source_id(cell) >= 0


func _grass_actors() -> Array[Node2D]:
	var actors_by_id: Dictionary = {}
	for group_name in [&"player", &"enemies", &"miniboss"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D:
				actors_by_id[node.get_instance_id()] = node
	var actors: Array[Node2D] = []
	for actor in actors_by_id.values():
		actors.append(actor as Node2D)
	return actors


func _set_actor_inside(actor: Node2D, inside: bool) -> void:
	var was_inside := bool(actor.get_meta("in_tall_grass", false))
	var actor_id := actor.get_instance_id()
	if inside:
		if not was_inside:
			actor.set_meta("in_tall_grass", true)
			actor.add_to_group("in_tall_grass")
			actor_grass_state_changed.emit(actor, true)
		if not actor_overlays.has(actor_id) or not is_instance_valid(actor_overlays[actor_id]):
			actor_overlays[actor_id] = _create_occlusion_overlay(actor)
		return

	if was_inside:
		actor.set_meta("in_tall_grass", false)
		actor.remove_from_group("in_tall_grass")
		actor_grass_state_changed.emit(actor, false)
	var overlay := actor_overlays.get(actor_id) as Sprite2D
	if overlay != null:
		overlay.queue_free()
	actor_overlays.erase(actor_id)


func _create_occlusion_overlay(actor: Node2D) -> Sprite2D:
	var overlay := Sprite2D.new()
	overlay.name = "TallGrassOcclusion"
	overlay.texture = GRASS_TEXTURE
	overlay.region_enabled = true
	overlay.region_rect = OCCLUSION_REGION
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.position = Vector2(0.0, 11.0)
	overlay.scale = Vector2.ONE * OCCLUSION_SCALE
	overlay.modulate = Color(0.48, 0.64, 0.33, 0.0)
	overlay.z_index = 6
	actor.add_child(overlay)
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.94, 0.12)
	return overlay
