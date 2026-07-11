class_name EvolutionSystem
extends Node

signal chest_spawned(chest_id: StringName)
signal evolution_available(chest_id: StringName, options: Array[EvolutionRecipe])
signal evolution_applied(chest_id: StringName, evolved_skill_id: StringName)

const MAX_EVOLUTIONS := 3
const CHEST_SCENE := preload("res://scenes/items/evolution_chest.tscn")

var arena: Arena
var controller: SkillController
var recipes: Dictionary = {}
var chests: Dictionary = {}
var consumed_count := 0
var next_chest_index := 1


func setup(new_arena: Arena, skill_controller: SkillController, recipe_definitions: Dictionary) -> void:
	arena = new_arena
	controller = skill_controller
	recipes = recipe_definitions.duplicate()
	controller.skills_changed.connect(_refresh_chests.unbind(3))


func spawn_chest(position: Vector2) -> EvolutionChest:
	if chests.size() + consumed_count >= MAX_EVOLUTIONS:
		return null
	var chest := CHEST_SCENE.instantiate() as EvolutionChest
	var chest_id := StringName("chest_%d" % next_chest_index)
	next_chest_index += 1
	arena.pickup_layer.add_child(chest)
	chest.global_position = position
	chest.setup(chest_id, self)
	chests[chest_id] = chest
	_refresh_chests()
	chest_spawned.emit(chest_id)
	return chest


func legal_recipes() -> Array[EvolutionRecipe]:
	var result: Array[EvolutionRecipe] = []
	for value in recipes.values():
		var recipe := value as EvolutionRecipe
		if controller.inventory.can_evolve(recipe):
			result.append(recipe)
	result.sort_custom(func(a: EvolutionRecipe, b: EvolutionRecipe) -> bool: return a.id < b.id)
	return result


func request_open(chest_id: StringName) -> bool:
	var chest := chests.get(chest_id) as EvolutionChest
	if chest == null or chest.consumed:
		return false
	var options := legal_recipes()
	if options.is_empty():
		arena.announce("悟道宝匣尚未共鸣：需要五级主动与对应心法", Color("aab5c6"))
		return false
	evolution_available.emit(chest_id, options.slice(0, mini(3, options.size())))
	return true


func apply_evolution(chest_id: StringName, evolved_skill_id: StringName) -> SkillUpgradeResult:
	var chest := chests.get(chest_id) as EvolutionChest
	if chest == null or chest.consumed or consumed_count >= MAX_EVOLUTIONS:
		return SkillUpgradeResult.failure(evolved_skill_id, &"invalid_chest")
	var selected: EvolutionRecipe
	for recipe in legal_recipes():
		if recipe.evolved_skill_id == evolved_skill_id:
			selected = recipe
			break
	if selected == null:
		return SkillUpgradeResult.failure(evolved_skill_id, &"invalid_recipe")
	var result := controller.apply_evolution(selected)
	if not result.success:
		return result
	chest.consumed = true
	chests.erase(chest_id)
	consumed_count += 1
	chest.consume()
	_refresh_chests()
	evolution_applied.emit(chest_id, evolved_skill_id)
	return result


func _refresh_chests() -> void:
	var has_options := not legal_recipes().is_empty()
	for value in chests.values():
		var chest := value as EvolutionChest
		if is_instance_valid(chest):
			chest.set_available(has_options)
