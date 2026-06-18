class_name MatchRecorder
extends RefCounted

const MATCH_RECORD_DIR := "user://match_records"
const LATEST_MATCH_RECORD_PATH := "user://match_records/latest_match.json"

var record: Dictionary = {}
var last_error := OK
var last_error_context := ""


func reset(layout_name: String, game_mode: String, player_count: int, random_seed: int, skills_enabled: bool, initial_snapshot: Array) -> void:
	record = {
		"version": 2,
		"created_at": Time.get_datetime_string_from_system(false, true),
		"mode": game_mode,
		"layout": layout_name,
		"players": player_count,
		"random_seed": random_seed,
		"skills_enabled": skills_enabled,
		"initial_pieces": initial_snapshot,
		"entries": [],
	}
	last_error = OK
	last_error_context = ""


func has_record() -> bool:
	return not record.is_empty()


func get_entries() -> Array:
	if record.has("entries") and record["entries"] is Array:
		return record["entries"]
	return []


func get_entry_count() -> int:
	return get_entries().size()


func append_entry(entry: Dictionary) -> void:
	var entries := get_entries()
	entries.append(entry)
	record["entries"] = entries


func mark_last_outcome(outcome: String) -> bool:
	var entries := get_entries()
	if entries.is_empty():
		return false
	var last_entry = entries[entries.size() - 1]
	if not last_entry is Dictionary:
		return false
	last_entry["outcome"] = outcome
	last_entry["turn_ended"] = true
	entries[entries.size() - 1] = last_entry
	record["entries"] = entries
	return true


func save_latest() -> Error:
	return save_to_path(LATEST_MATCH_RECORD_PATH)


func save_to_path(path: String) -> Error:
	if record.is_empty():
		last_error = ERR_UNAVAILABLE
		last_error_context = "empty"
		return last_error

	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		last_error = ERR_CANT_OPEN
		last_error_context = "dir"
		return last_error

	var dir_result := user_dir.make_dir_recursive(MATCH_RECORD_DIR.replace("user://", ""))
	if dir_result != OK:
		last_error = dir_result
		last_error_context = "dir"
		return last_error

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = FileAccess.get_open_error()
		last_error_context = "open"
		return last_error

	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	last_error = OK
	last_error_context = ""
	return OK


func load_latest() -> Error:
	return load_from_path(LATEST_MATCH_RECORD_PATH)


func load_from_path(path: String) -> Error:
	if not FileAccess.file_exists(path):
		last_error = ERR_FILE_NOT_FOUND
		last_error_context = "missing"
		return last_error

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = FileAccess.get_open_error()
		last_error_context = "open"
		return last_error

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		last_error = ERR_PARSE_ERROR
		last_error_context = "parse"
		return last_error

	record = parsed
	last_error = OK
	last_error_context = ""
	return OK
