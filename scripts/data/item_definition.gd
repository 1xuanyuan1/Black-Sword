class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var world_scene: PackedScene
@export var effect_id: StringName
@export var effect_values: Dictionary = {}
@export var base_weight := 1.0
@export var accent := Color.WHITE
