class_name SaveSlotSummary
extends RefCounted

var slot_index := 0
var exists := false
var corrupt := false
var recoverable := false
var updated_at_unix := 0
var play_seconds := 0
var selected_character_id: StringName = &"black_sword"
var runs := 0
var victories := 0


static func empty(new_slot_index: int) -> SaveSlotSummary:
	var summary := SaveSlotSummary.new()
	summary.slot_index = new_slot_index
	return summary


static func from_profile(profile: ProfileData) -> SaveSlotSummary:
	var summary := SaveSlotSummary.new()
	summary.slot_index = profile.slot_index
	summary.exists = true
	summary.updated_at_unix = profile.updated_at_unix
	summary.play_seconds = profile.play_seconds
	summary.selected_character_id = profile.selected_character_id
	summary.runs = int(profile.stats.get("runs", 0))
	summary.victories = int(profile.stats.get("victories", 0))
	return summary
