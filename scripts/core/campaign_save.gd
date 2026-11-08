class_name CampaignSave
extends RefCounted

const VERSION := 1
var path := "user://campaign.json"


func load_progress() -> Dictionary:
	var current := _read(path)
	return _read(path + ".previous") if current.is_empty() else current


func save_progress(progress: Dictionary) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var payload := progress.duplicate(true)
	payload["version"] = VERSION
	var written := file.store_string(JSON.stringify(payload))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not written or write_error != OK:
		return ERR_FILE_CANT_WRITE

	var backup := path + ".previous"
	# Preserve a known-good backup if the primary file was already corrupt.
	if not _read(path).is_empty():
		var backup_error := DirAccess.rename_absolute(path, backup)
		if backup_error != OK:
			return backup_error
	var replace_error := DirAccess.rename_absolute(temporary, path)
	if replace_error != OK and not FileAccess.file_exists(path) and FileAccess.file_exists(backup):
		DirAccess.copy_absolute(backup, path)
	return replace_error


func _read(filename: String) -> Dictionary:
	if not FileAccess.file_exists(filename):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(filename))
	if not data is Dictionary or data.get("version") != VERSION:
		return {}
	var credits: Variant = data.get("agency_credits")
	if not _whole_number(credits, 9007199254740991.0):
		return {}
	for key: String in ["completed_missions", "discovered_ids"]:
		if not data.get(key) is Array:
			return {}
		for entry: Variant in data[key]:
			if not entry is String or entry.is_empty():
				return {}
	if not data.get("best_scores") is Dictionary:
		return {}
	for mission: Variant in data.best_scores:
		if not mission is String or not _whole_number(data.best_scores[mission], 100.0):
			return {}
	return data


func _whole_number(value: Variant, maximum: float) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= 0.0 and value <= maximum and value == floorf(float(value))
