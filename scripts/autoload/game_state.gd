class_name GameStateService
extends Node

signal profile_loaded(profile: ProfileData)
signal profile_cleared
signal night_embers_changed(current: int, delta: int)
signal meta_upgrades_changed(levels: Dictionary)
signal run_result_submitted(result: RunResult)

var current_profile: ProfileData
var _save_manager_override: Node
var _content_database_override: Node


func create_profile(slot_index: int) -> ProfileData:
	var profile: ProfileData = _manager().call("create_slot", slot_index)
	if profile != null:
		_set_current_profile(profile)
	return profile


func load_profile(slot_index: int) -> ProfileData:
	var profile: ProfileData = _manager().call("load_slot", slot_index)
	if profile != null:
		_set_current_profile(profile)
	return profile


func delete_profile(slot_index: int) -> Error:
	var error: Error = _manager().call("delete_slot", slot_index)
	if error == OK and current_profile != null and current_profile.slot_index == slot_index:
		clear_current_profile()
	return error


func save_current(reason: StringName = &"manual") -> Error:
	if current_profile == null:
		return ERR_DOES_NOT_EXIST
	return _manager().call("save_profile", current_profile, reason)


func clear_current_profile() -> void:
	current_profile = null
	profile_cleared.emit()


func has_current_profile() -> bool:
	return current_profile != null


func current_slot_index() -> int:
	return 0 if current_profile == null else current_profile.slot_index


func submit_run_result(result: RunResult) -> Error:
	if current_profile == null or result == null:
		return ERR_DOES_NOT_EXIST
	var run_id := result.ensure_run_id()
	if result.submitted or run_id in current_profile.submitted_run_ids:
		return ERR_ALREADY_EXISTS
	var next := _clone_current_profile()
	var earned := result.calculate_night_embers()
	next.night_embers += earned
	next.play_seconds += maxi(roundi(result.elapsed_seconds), 0)
	next.stats["runs"] = int(next.stats.get("runs", 0)) + 1
	next.stats["victories"] = int(next.stats.get("victories", 0)) + (1 if result.victory else 0)
	next.stats["best_wave"] = maxi(int(next.stats.get("best_wave", 0)), result.completed_waves)
	next.stats["best_time_seconds"] = maxi(int(next.stats.get("best_time_seconds", 0)), roundi(result.elapsed_seconds))
	next.stats["total_kills"] = int(next.stats.get("total_kills", 0)) + maxi(result.kills, 0)
	next.stats["total_night_embers"] = int(next.stats.get("total_night_embers", 0)) + earned
	for story_event in result.story_events:
		if story_event not in next.story_flags:
			next.story_flags.append(story_event)
	next.submitted_run_ids.append(run_id)
	var error := _save_profile_candidate(next, &"run_result")
	if error != OK:
		return error
	result.earned_night_embers = earned
	result.submitted = true
	night_embers_changed.emit(next.night_embers, earned)
	run_result_submitted.emit(result)
	return OK


func purchase_meta_upgrade(id: StringName) -> Error:
	if current_profile == null:
		return ERR_DOES_NOT_EXIST
	var definition := _database().call("meta_upgrade", id) as MetaUpgradeDefinition
	if definition == null:
		return ERR_INVALID_PARAMETER
	var current_level := int(current_profile.meta_upgrades.get(String(id), 0))
	var cost := definition.cost_for_next_level(current_level)
	if cost < 0:
		return ERR_CANT_ACQUIRE_RESOURCE
	if current_profile.night_embers < cost:
		return ERR_UNAVAILABLE
	var next := _clone_current_profile()
	next.night_embers -= cost
	next.meta_upgrades[String(id)] = current_level + 1
	var error := _save_profile_candidate(next, &"meta_upgrade_purchase")
	if error != OK:
		return error
	night_embers_changed.emit(next.night_embers, -cost)
	meta_upgrades_changed.emit(next.meta_upgrades.duplicate(true))
	return OK


func meta_investment_total() -> int:
	if current_profile == null:
		return 0
	var total := 0
	for definition in _database().call("all_meta_upgrades").values():
		var meta_definition := definition as MetaUpgradeDefinition
		total += meta_definition.invested_cost(int(current_profile.meta_upgrades.get(String(meta_definition.id), 0)))
	return total


func reset_meta_upgrades() -> Error:
	if current_profile == null:
		return ERR_DOES_NOT_EXIST
	var refund := meta_investment_total()
	var next := _clone_current_profile()
	next.night_embers += refund
	for id in next.meta_upgrades:
		next.meta_upgrades[id] = 0
	var error := _save_profile_candidate(next, &"meta_upgrade_reset")
	if error != OK:
		return error
	night_embers_changed.emit(next.night_embers, refund)
	meta_upgrades_changed.emit(next.meta_upgrades.duplicate(true))
	return OK


func build_run_config(character_id: StringName = &"") -> RunConfig:
	var selected := character_id
	if selected.is_empty():
		selected = &"black_sword" if current_profile == null else current_profile.selected_character_id
	var config := RunConfig.default_for_character(selected)
	if current_profile == null:
		return config
	var attack_level := int(current_profile.meta_upgrades.get("attack", 0))
	var health_level := int(current_profile.meta_upgrades.get("health", 0))
	var insight_level := int(current_profile.meta_upgrades.get("insight", 0))
	var revive_level := int(current_profile.meta_upgrades.get("revive", 0))
	var attack := _database().call("meta_upgrade", &"attack") as MetaUpgradeDefinition
	var health := _database().call("meta_upgrade", &"health") as MetaUpgradeDefinition
	var insight := _database().call("meta_upgrade", &"insight") as MetaUpgradeDefinition
	config.attack_multiplier = 1.0 + float(attack.stats(attack_level).get("damage", 0.0))
	config.health_multiplier = 1.0 + float(health.stats(health_level).get("health", 0.0))
	config.experience_multiplier = 1.0 + float(insight.stats(insight_level).get("experience", 0.0))
	config.revive_rank = revive_level
	return config


func configure_save_manager_for_tests(manager: Node) -> Error:
	if not OS.is_debug_build():
		return ERR_UNAUTHORIZED
	_save_manager_override = manager
	return OK


func configure_content_database_for_tests(database: Node) -> Error:
	if not OS.is_debug_build():
		return ERR_UNAUTHORIZED
	_content_database_override = database
	return OK


func clear_save_manager_override() -> void:
	_save_manager_override = null


func clear_content_database_override() -> void:
	_content_database_override = null


func _set_current_profile(profile: ProfileData) -> void:
	current_profile = profile
	profile_loaded.emit(profile)


func _manager() -> Node:
	if _save_manager_override != null:
		return _save_manager_override
	return get_node("/root/SaveManager")


func _database() -> Node:
	if _content_database_override != null:
		return _content_database_override
	return get_node("/root/ContentDatabase")


func _clone_current_profile() -> ProfileData:
	return ProfileData.from_dict(current_profile.to_dict())


func _save_profile_candidate(profile: ProfileData, reason: StringName) -> Error:
	var error: Error = _manager().call("save_profile", profile, reason)
	if error == OK:
		_set_current_profile(profile)
	return error
