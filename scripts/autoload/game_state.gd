class_name GameStateService
extends Node

signal profile_loaded(profile: ProfileData)
signal profile_cleared

var current_profile: ProfileData
var _save_manager_override: Node


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


func configure_save_manager_for_tests(manager: Node) -> Error:
	if not OS.is_debug_build():
		return ERR_UNAUTHORIZED
	_save_manager_override = manager
	return OK


func clear_save_manager_override() -> void:
	_save_manager_override = null


func _set_current_profile(profile: ProfileData) -> void:
	current_profile = profile
	profile_loaded.emit(profile)


func _manager() -> Node:
	if _save_manager_override != null:
		return _save_manager_override
	return get_node("/root/SaveManager")
