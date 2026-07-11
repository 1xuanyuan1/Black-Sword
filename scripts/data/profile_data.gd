class_name ProfileData
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1

var schema_version := CURRENT_SCHEMA_VERSION
var slot_index := 0
var created_at_unix := 0
var updated_at_unix := 0
var play_seconds := 0
var night_embers := 0
var meta_upgrades: Dictionary = {
	"attack": 0,
	"health": 0,
	"insight": 0,
	"revive": 0,
}
var unlocked_characters: Array[StringName] = [&"black_sword"]
var available_character_unlocks: Array[StringName] = []
var selected_character_id: StringName = &"black_sword"
var story_flags: Array[StringName] = []
var stats: Dictionary = {
	"runs": 0,
	"victories": 0,
	"best_wave": 0,
	"best_time_seconds": 0,
	"total_kills": 0,
	"total_night_embers": 0,
}


static func create_new(new_slot_index: int) -> ProfileData:
	var profile := ProfileData.new()
	var now := int(Time.get_unix_time_from_system())
	profile.slot_index = new_slot_index
	profile.created_at_unix = now
	profile.updated_at_unix = now
	return profile


static func from_dict(data: Dictionary) -> ProfileData:
	var profile := ProfileData.new()
	profile.schema_version = int(data.get("schema_version", CURRENT_SCHEMA_VERSION))
	profile.slot_index = int(data.get("slot_index", 0))
	profile.created_at_unix = int(data.get("created_at_unix", 0))
	profile.updated_at_unix = int(data.get("updated_at_unix", 0))
	profile.play_seconds = maxi(int(data.get("play_seconds", 0)), 0)
	profile.night_embers = maxi(int(data.get("night_embers", 0)), 0)
	profile.meta_upgrades = _dictionary_with_defaults(data.get("meta_upgrades", {}), profile.meta_upgrades)
	profile.unlocked_characters = _string_name_array(data.get("unlocked_characters", [&"black_sword"]))
	profile.available_character_unlocks = _string_name_array(data.get("available_character_unlocks", []))
	profile.selected_character_id = StringName(data.get("selected_character_id", "black_sword"))
	profile.story_flags = _string_name_array(data.get("story_flags", []))
	profile.stats = _dictionary_with_defaults(data.get("stats", {}), profile.stats)
	if &"black_sword" not in profile.unlocked_characters:
		profile.unlocked_characters.push_front(&"black_sword")
	return profile


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"slot_index": slot_index,
		"created_at_unix": created_at_unix,
		"updated_at_unix": updated_at_unix,
		"play_seconds": play_seconds,
		"night_embers": night_embers,
		"meta_upgrades": meta_upgrades.duplicate(true),
		"unlocked_characters": _string_array(unlocked_characters),
		"available_character_unlocks": _string_array(available_character_unlocks),
		"selected_character_id": String(selected_character_id),
		"story_flags": _string_array(story_flags),
		"stats": stats.duplicate(true),
	}


static func _dictionary_with_defaults(value: Variant, defaults: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	if value is Dictionary:
		for key in value:
			result[key] = value[key]
	return result


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value:
			var id := StringName(item)
			if not id.is_empty() and id not in result:
				result.append(id)
	return result


static func _string_array(value: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for item in value:
		result.append(String(item))
	return result
