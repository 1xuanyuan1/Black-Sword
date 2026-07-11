class_name RunConfig
extends RefCounted

var character_id: StringName = &"black_sword"
var attack_multiplier := 1.0
var health_multiplier := 1.0
var experience_multiplier := 1.0
var revive_rank := 0


static func default_for_character(id: StringName) -> RunConfig:
	var config := RunConfig.new()
	config.character_id = id
	return config
