class_name StoryEventDefinition
extends Resource

@export var id: StringName
@export var title: String
@export_multiline var body: String
@export var route_id: StringName = &"main"
@export var pause_battle := true
@export var once_per_profile := true
