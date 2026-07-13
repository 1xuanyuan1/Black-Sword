class_name ArenaBackdrop
extends Node2D

@onready var world_collision_layer: Node2D = $WorldCollisionLayer
@onready var fog_bank_layer: Node2D = $AtmosphereLayer/FogBanks

var bounds := Rect2(-1536.0, -864.0, 3072.0, 1728.0)
var fog_sprites: Array[Sprite2D] = []
var arena: Arena
var zones: Dictionary = {}
var gates: Dictionary = {}
var hazards: Dictionary = {}


func _ready() -> void:
	for child_node in fog_bank_layer.get_children():
		var fog_sprite: Sprite2D = child_node as Sprite2D
		if fog_sprite != null:
			fog_sprites.append(fog_sprite)
	var zone_layer := get_node_or_null("ZoneLayer")
	if zone_layer != null:
		for child in zone_layer.get_children():
			if child is MapZone:
				zones[(child as MapZone).zone_id] = child
	var gate_layer := get_node_or_null("GateLayer")
	if gate_layer != null:
		for child in gate_layer.get_children():
			if child is ZoneGate:
				gates[(child as ZoneGate).gate_id] = child
	var hazard_layer := get_node_or_null("HazardLayer")
	if hazard_layer != null:
		for child in hazard_layer.get_children():
			if child is HazardArea:
				hazards[(child as HazardArea).hazard_id] = child


func setup(arena_bounds: Rect2, new_arena: Arena = null) -> void:
	bounds = arena_bounds
	arena = new_arena
	z_index = 0
	for hazard in hazards.values():
		(hazard as HazardArea).setup(arena)
	unlock_zone(&"mountain_gate")


func on_wave_started(definition: WaveDefinition) -> void:
	if definition == null:
		return
	if not definition.unlock_zone_id.is_empty():
		unlock_zone(definition.unlock_zone_id)
	for gate in gates.values():
		var zone_gate := gate as ZoneGate
		if definition.index >= zone_gate.unlock_wave:
			zone_gate.unlock()
	for event_id in definition.environment_event_ids:
		trigger_environment_event(event_id)


func unlock_zone(id: StringName) -> void:
	var zone := zones.get(id) as MapZone
	if zone != null:
		zone.set_unlocked(true)


func trigger_environment_event(id: StringName) -> bool:
	var hazard := hazards.get(id) as HazardArea
	if hazard == null:
		return false
	var position := hazard.global_position
	if id in [&"moving_curse", &"seal_pulse"] and is_instance_valid(arena) and is_instance_valid(arena.player):
		position = arena.player.global_position + Vector2.from_angle(float(hazard.activation_count) * 1.9) * 140.0
	hazard.activate(position)
	return true


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
	if not is_inside_tree() or get_world_2d() == null:
		return true
	var probe := CircleShape2D.new()
	probe.radius = maxf(margin, 1.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.transform = Transform2D(0.0, world_position)
	query.collision_mask = 2 | 8
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
