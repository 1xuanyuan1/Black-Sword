class_name CharacterDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var actor_scene: PackedScene
@export var portrait: Texture2D
@export var initial_skill_id: StringName
@export var visual_kind: StringName
@export var visual_scale := 1.0
@export var trait_modifiers: Dictionary = {}
@export var trait_description: String
@export var unlock_condition_id: StringName
@export var unlock_condition_value := 0
@export var unlock_description: String
@export var unlock_cost := 0
@export var story_route_id: StringName
@export var accent := Color("a9c7ef")
@export var portrait_region := Rect2()
@export var sort_order := 0
