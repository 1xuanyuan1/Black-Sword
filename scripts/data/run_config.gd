class_name RunConfig
extends RefCounted

var character_id: StringName = &"black_sword"
var attack_multiplier := 1.0
var health_multiplier := 1.0
var experience_multiplier := 1.0
var revive_rank := 0
var move_speed_multiplier := 1.0
var cooldown_multiplier := 1.0
var area_multiplier := 1.0
var status_duration_multiplier := 1.0
var damage_taken_multiplier := 1.0
var melee_damage_multiplier := 1.0
var elite_boss_damage_multiplier := 1.0


static func default_for_character(id: StringName) -> RunConfig:
	var config := RunConfig.new()
	config.character_id = id
	return config
