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
