class_name SaveManagerService
extends Node

signal profile_saved(slot_index: int, reason: StringName)
signal recovery_performed(slot_index: int)

const DEFAULT_STORAGE_ROOT := "user://saves"
const TEST_STORAGE_PREFIX := "user://tests/"
const SLOT_COUNT := 3

var storage_root := DEFAULT_STORAGE_ROOT
var last_error_message := ""
var last_recovery_message := ""


func _ready() -> void:
	_ensure_storage_directory()


func list_slots() -> Array[SaveSlotSummary]:
	var result: Array[SaveSlotSummary] = []
	for slot_index in range(1, SLOT_COUNT + 1):
		result.append(_slot_summary(slot_index))
	return result


func create_slot(slot_index: int) -> ProfileData:
	_reset_messages()
	if not _validate_slot_index(slot_index):
		return null
	if FileAccess.file_exists(_slot_path(slot_index)):
		last_error_message = "档位 %d 已存在" % slot_index
		return null
	var profile := ProfileData.create_new(slot_index)
	if save_profile(profile, &"create_slot") != OK:
		return null
	return profile


func load_slot(slot_index: int) -> ProfileData:
	_reset_messages()
	if not _validate_slot_index(slot_index):
		return null
	var profile := _read_profile(_slot_path(slot_index), slot_index)
	if profile != null:
		return profile
	var backup_profile := _read_profile(_backup_path(slot_index), slot_index)
	if backup_profile == null:
		last_error_message = "存档 %d 无法读取，且没有可用备份" % slot_index
		return null
	if _write_profile_without_backup(backup_profile, _slot_path(slot_index)) != OK:
		last_error_message = "存档 %d 的备份有效，但恢复正式文件失败" % slot_index
		return null
	last_recovery_message = "存档 %d 已从上一次完整记录恢复" % slot_index
	recovery_performed.emit(slot_index)
	return backup_profile


func save_profile(profile: ProfileData, reason: StringName = &"manual") -> Error:
	_reset_messages()
	if profile == null or not _validate_slot_index(profile.slot_index):
		last_error_message = "无法保存无效档案"
		return ERR_INVALID_PARAMETER
	profile.schema_version = ProfileData.CURRENT_SCHEMA_VERSION
	profile.updated_at_unix = int(Time.get_unix_time_from_system())
	var validation_errors := _validate_profile(profile)
	if not validation_errors.is_empty():
		last_error_message = validation_errors[0]
		return ERR_INVALID_DATA
	_ensure_storage_directory()
	var target_path := _slot_path(profile.slot_index)
	var temporary_path := _temporary_path(profile.slot_index)
	var backup_path := _backup_path(profile.slot_index)
	var write_error := _write_profile_without_backup(profile, temporary_path)
	if write_error != OK:
		last_error_message = "写入临时存档失败：%s" % error_string(write_error)
		return write_error
	if _read_profile(temporary_path, profile.slot_index) == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		last_error_message = "临时存档校验失败"
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(target_path):
		var backup_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(target_path),
			ProjectSettings.globalize_path(backup_path)
		)
		if backup_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
			last_error_message = "创建存档备份失败：%s" % error_string(backup_error)
			return backup_error
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(target_path)
	)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(target_path))
		last_error_message = "替换正式存档失败：%s" % error_string(rename_error)
		return rename_error
	profile_saved.emit(profile.slot_index, reason)
	return OK


func delete_slot(slot_index: int) -> Error:
	_reset_messages()
	if not _validate_slot_index(slot_index):
		return ERR_INVALID_PARAMETER
	var first_error := OK
	for path in [_slot_path(slot_index), _backup_path(slot_index), _temporary_path(slot_index)]:
		if not FileAccess.file_exists(path):
			continue
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if error != OK and first_error == OK:
			first_error = error
	if first_error != OK:
		last_error_message = "删除存档失败：%s" % error_string(first_error)
	return first_error


func export_slot(slot_index: int, target_path: String) -> Error:
	_reset_messages()
	var profile := load_slot(slot_index)
	if profile == null:
		return ERR_FILE_CANT_READ
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		last_error_message = "无法创建导出文件：%s" % target_path
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	file.close()
	return OK


func export_slot_json(slot_index: int) -> String:
	var profile := load_slot(slot_index)
	return "" if profile == null else JSON.stringify(profile.to_dict(), "\t")


func import_slot(slot_index: int, source_path: String) -> ProfileData:
	_reset_messages()
	if not _validate_slot_index(slot_index):
		return null
	var profile := _read_profile(source_path, -1)
	if profile == null:
		last_error_message = "导入文件不是有效的 V1 存档"
		return null
	profile.slot_index = slot_index
	profile.updated_at_unix = int(Time.get_unix_time_from_system())
	if save_profile(profile, &"import_slot") != OK:
		return null
	return profile


func configure_storage_root_for_tests(path: String) -> Error:
	if not OS.is_debug_build() or not path.begins_with(TEST_STORAGE_PREFIX):
		return ERR_UNAUTHORIZED
	storage_root = path.trim_suffix("/")
	_ensure_storage_directory()
	return OK


func reset_storage_root() -> void:
	storage_root = DEFAULT_STORAGE_ROOT
	_ensure_storage_directory()


func _slot_summary(slot_index: int) -> SaveSlotSummary:
	var primary_exists := FileAccess.file_exists(_slot_path(slot_index))
	var backup_exists := FileAccess.file_exists(_backup_path(slot_index))
	if not primary_exists and not backup_exists:
		return SaveSlotSummary.empty(slot_index)
	var primary := _read_profile(_slot_path(slot_index), slot_index) if primary_exists else null
	if primary != null:
		return SaveSlotSummary.from_profile(primary)
	var backup := _read_profile(_backup_path(slot_index), slot_index) if backup_exists else null
	if backup != null:
		var recoverable := SaveSlotSummary.from_profile(backup)
		recoverable.corrupt = true
		recoverable.recoverable = true
		return recoverable
	var corrupt := SaveSlotSummary.empty(slot_index)
	corrupt.exists = true
	corrupt.corrupt = true
	return corrupt


func _read_profile(path: String, expected_slot_index: int) -> ProfileData:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return null
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return null
	var migrated := _migrate_to_current(parsed)
	if migrated.is_empty():
		return null
	var profile := ProfileData.from_dict(migrated)
	if expected_slot_index > 0 and profile.slot_index != expected_slot_index:
		return null
	return profile if _validate_profile(profile).is_empty() else null


func _migrate_to_current(data: Dictionary) -> Dictionary:
	var version := int(data.get("schema_version", 0))
	if version == ProfileData.CURRENT_SCHEMA_VERSION:
		return data
	return {}


func _validate_profile(profile: ProfileData) -> PackedStringArray:
	var errors := PackedStringArray()
	if profile.schema_version != ProfileData.CURRENT_SCHEMA_VERSION:
		errors.append("不支持的存档版本：%d" % profile.schema_version)
	if profile.slot_index < 1 or profile.slot_index > SLOT_COUNT:
		errors.append("存档档位超出范围")
	if profile.play_seconds < 0 or profile.night_embers < 0:
		errors.append("存档包含负数进度")
	if &"black_sword" not in profile.unlocked_characters:
		errors.append("默认角色 black_sword 必须解锁")
	if profile.selected_character_id not in profile.unlocked_characters:
		errors.append("当前选择角色尚未解锁")
	for upgrade_id in profile.meta_upgrades:
		if not ProfileData.META_UPGRADE_MAX_LEVELS.has(upgrade_id):
			errors.append("未知的养成分支：%s" % upgrade_id)
	for upgrade_id in ProfileData.META_UPGRADE_MAX_LEVELS:
		var level := int(profile.meta_upgrades.get(upgrade_id, 0))
		if level < 0 or level > int(ProfileData.META_UPGRADE_MAX_LEVELS[upgrade_id]):
			errors.append("养成等级超出范围：%s" % upgrade_id)
	return errors


func _write_profile_without_backup(profile: ProfileData, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	file.close()
	return OK


func _validate_slot_index(slot_index: int) -> bool:
	if slot_index >= 1 and slot_index <= SLOT_COUNT:
		return true
	last_error_message = "档位编号必须为 1～%d" % SLOT_COUNT
	return false


func _ensure_storage_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_root))


func _slot_path(slot_index: int) -> String:
	return storage_root.path_join("slot_%d.json" % slot_index)


func _backup_path(slot_index: int) -> String:
	return storage_root.path_join("slot_%d.bak" % slot_index)


func _temporary_path(slot_index: int) -> String:
	return storage_root.path_join("slot_%d.tmp" % slot_index)


func _reset_messages() -> void:
	last_error_message = ""
	last_recovery_message = ""
