class_name ItemDropSystem
extends Node

signal item_spawned(id: StringName, guaranteed: bool)
signal item_collected(id: StringName)

const POT_DROP_CHANCE := 0.18
const ELITE_DROP_CHANCE := 0.12
const SWIFT_ELITE_DROP_CHANCE := 0.20
const MAX_ACTIVE_PICKUPS := 3
const GUARANTEE_WAVE_STREAK := 4
const POT_SCENE := preload("res://scenes/items/breakable_pot.tscn")

var arena: Arena
var definitions: Dictionary
var effect_registry := ItemEffectRegistry.new()
var rng := RandomNumberGenerator.new()
var active_pickups: Array[ItemPickup] = []
var active_pots: Array[BreakablePot] = []
var current_wave := 0
var waves_without_item := 0
var item_spawned_this_wave := false


func setup(new_arena: Arena, item_definitions: Dictionary) -> void:
	arena = new_arena
	definitions = item_definitions
	rng.randomize()


func start_wave(wave_index: int) -> void:
	current_wave = wave_index
	item_spawned_this_wave = false
	_cleanup_runtime_lists()
	var pot_count := rng.randi_range(1, 2)
	for _index in range(pot_count):
		spawn_pot(_random_position_around_player())


func complete_wave(_wave_index: int) -> void:
	if item_spawned_this_wave:
		waves_without_item = 0
	else:
		waves_without_item += 1
	if waves_without_item >= GUARANTEE_WAVE_STREAK:
		if spawn_random_item(_random_position_around_player(), true) != null:
			waves_without_item = 0


func spawn_pot(position: Vector2) -> BreakablePot:
	var pot := POT_SCENE.instantiate() as BreakablePot
	arena.pickup_layer.add_child(pot)
	pot.global_position = position
	pot.setup(self)
	active_pots.append(pot)
	return pot


func pot_broken(position: Vector2) -> void:
	_cleanup_runtime_lists()
	if rng.randf() < POT_DROP_CHANCE:
		spawn_random_item(position)


func on_enemy_defeated(enemy: EnemyActor, position: Vector2) -> void:
	if enemy == null or not enemy.elite:
		return
	var chance := SWIFT_ELITE_DROP_CHANCE if enemy.get_meta("elite_affix", &"") == &"swift" else ELITE_DROP_CHANCE
	if rng.randf() < chance:
		spawn_random_item(position)


func spawn_random_item(position: Vector2, guaranteed: bool = false) -> ItemPickup:
	var definition := _weighted_definition()
	return null if definition == null else spawn_item(definition.id, position, guaranteed)


func spawn_item(id: StringName, position: Vector2, guaranteed: bool = false) -> ItemPickup:
	_cleanup_runtime_lists()
	if active_pickups.size() >= MAX_ACTIVE_PICKUPS:
		return null
	var definition := definitions.get(id) as ItemDefinition
	if definition == null or definition.world_scene == null:
		return null
	var pickup := definition.world_scene.instantiate() as ItemPickup
	arena.pickup_layer.add_child(pickup)
	pickup.global_position = position
	pickup.setup(definition, self)
	active_pickups.append(pickup)
	item_spawned_this_wave = true
	item_spawned.emit(id, guaranteed)
	return pickup


func collect_item(id: StringName, pickup: ItemPickup) -> bool:
	var definition := definitions.get(id) as ItemDefinition
	if not effect_registry.apply(definition, arena):
		return false
	active_pickups.erase(pickup)
	item_collected.emit(id)
	arena.announce("拾取 · %s" % definition.display_name, definition.accent)
	pickup.queue_free()
	return true


func configure_rng_seed_for_tests(seed: int) -> Error:
	if not OS.is_debug_build():
		return ERR_UNAUTHORIZED
	rng.seed = seed
	return OK


func _weighted_definition() -> ItemDefinition:
	var candidates: Array[ItemDefinition] = []
	var total_weight := 0.0
	for value in definitions.values():
		var definition := value as ItemDefinition
		var weight := definition.base_weight
		if definition.id == &"healing_salve" and is_instance_valid(arena.player) and arena.player.health >= arena.player.max_health:
			weight *= 0.25
		if weight <= 0.0:
			continue
		candidates.append(definition)
		total_weight += weight
	if candidates.is_empty() or total_weight <= 0.0:
		return null
	var roll := rng.randf() * total_weight
	for definition in candidates:
		var weight := definition.base_weight
		if definition.id == &"healing_salve" and arena.player.health >= arena.player.max_health:
			weight *= 0.25
		roll -= weight
		if roll <= 0.0:
			return definition
	return candidates.back()


func _random_position_around_player() -> Vector2:
	var center := arena.player.global_position if is_instance_valid(arena.player) else Vector2.ZERO
	for _attempt in range(12):
		var position := center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120.0, 360.0)
		position.x = clampf(position.x, arena.bounds.position.x + 40.0, arena.bounds.end.x - 40.0)
		position.y = clampf(position.y, arena.bounds.position.y + 40.0, arena.bounds.end.y - 40.0)
		if not is_instance_valid(arena.backdrop) or arena.backdrop.is_point_clear(position, 24.0):
			return position
	return center + Vector2(120.0, 0.0)


func _cleanup_runtime_lists() -> void:
	for index in range(active_pickups.size() - 1, -1, -1):
		var pickup := active_pickups[index]
		if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
			active_pickups.remove_at(index)
	for index in range(active_pots.size() - 1, -1, -1):
		var pot := active_pots[index]
		if not is_instance_valid(pot) or pot.is_queued_for_deletion():
			active_pots.remove_at(index)
