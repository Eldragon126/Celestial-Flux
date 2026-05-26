extends Node
class_name ModContentRegistry
## Data-driven content registry. It discovers manifests but never executes them.

signal registry_loaded(summary: Dictionary)
signal manifest_loaded(manifest_id: StringName, source_path: String)
signal manifest_failed(source_path: String, reason: String)

@export var enabled: bool = true
@export var load_res_mods: bool = true
@export var load_user_mods: bool = true
@export var res_mod_root: String = "res://Mods"
@export var user_mod_root: String = "user://mods"
@export var manifest_file_name: String = "vectorfall_mod.json"

var _manifests: Dictionary = {}
var _content: Dictionary = {
	"arenas": {},
	"waves": {},
	"upgrades": {},
	"rules": {},
}


func _ready() -> void:
	add_to_group("mod_content_registry")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("reload_registry")


func reload_registry() -> void:
	_manifests.clear()
	for key in _content.keys():
		_content[key].clear()

	if enabled:
		if load_res_mods:
			_scan_mod_root(res_mod_root)
		if load_user_mods:
			_scan_mod_root(user_mod_root)

	registry_loaded.emit(get_registry_summary())


func get_registry_summary() -> Dictionary:
	return {
		"manifest_count": _manifests.size(),
		"arenas": _content["arenas"].size(),
		"waves": _content["waves"].size(),
		"upgrades": _content["upgrades"].size(),
		"rules": _content["rules"].size(),
	}


func get_registry_snapshot() -> Dictionary:
	return {
		"manifests": _manifests.duplicate(true),
		"content": _content.duplicate(true),
	}


func get_entries(content_type: StringName) -> Array:
	var key := String(content_type)
	if not _content.has(key):
		return []
	return (_content[key] as Dictionary).values()


func get_entry(content_type: StringName, entry_id: StringName) -> Dictionary:
	var key := String(content_type)
	if not _content.has(key):
		return {}
	var entries := _content[key] as Dictionary
	var entry: Variant = entries.get(String(entry_id), {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}


func _scan_mod_root(root_path: String) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var child_path := "%s/%s" % [root_path.trim_suffix("/"), entry]
		if dir.current_is_dir():
			_load_manifest_path("%s/%s" % [child_path, manifest_file_name])
		elif entry == manifest_file_name:
			_load_manifest_path(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _load_manifest_path(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		manifest_failed.emit(path, "cannot_open")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		manifest_failed.emit(path, "invalid_json")
		return

	var manifest := parsed as Dictionary
	var manifest_id := StringName(str(manifest.get("id", "")))
	if String(manifest_id).is_empty():
		manifest_failed.emit(path, "missing_id")
		return

	_manifests[String(manifest_id)] = {
		"id": manifest_id,
		"display_name": str(manifest.get("display_name", manifest_id)),
		"version": int(manifest.get("version", 1)),
		"source_path": path,
	}
	_register_content_array(manifest, manifest_id, "arenas")
	_register_content_array(manifest, manifest_id, "waves")
	_register_content_array(manifest, manifest_id, "upgrades")
	_register_content_array(manifest, manifest_id, "rules")
	manifest_loaded.emit(manifest_id, path)


func _register_content_array(manifest: Dictionary, manifest_id: StringName, key: String) -> void:
	var entries_value: Variant = manifest.get(key, [])
	if not (entries_value is Array):
		return
	var entries := entries_value as Array
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := (entry_value as Dictionary).duplicate(true)
		var entry_id := str(entry.get("id", ""))
		if entry_id.is_empty():
			continue
		entry["manifest_id"] = manifest_id
		entry["content_type"] = key
		(_content[key] as Dictionary)[entry_id] = entry
