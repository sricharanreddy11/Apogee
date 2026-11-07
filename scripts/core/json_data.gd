class_name JsonData
extends RefCounted


static func read_object(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open %s (error %s)." % [path, FileAccess.get_open_error()])
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_error("%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	if not parser.data is Dictionary:
		push_error("Expected a JSON object in %s." % path)
		return {}
	return parser.data
