extends Node
class_name ModContentRegistry
## Data-driven mod catalog. It discovers manifests, registers content, and
## exposes safe hooks, but it does not execute arbitrary mod scripts.

signal registry_loaded(summary: Dictionary)
signal registry_reloaded(summary: Dictionary)
signal manifest_loaded(manifest_id: StringName, source_path: String)
signal manifest_failed(source_path: String, reason: String)
signal manifest_validated(manifest_id: StringName, source_path: String)
signal content_registered(content_type: StringName, entry_id: StringName, manifest_id: StringName, entry: Dictionary)
signal dependency_warning(manifest_id: StringName, dependency_id: StringName, reason: String)
signal mod_catalog_changed(snapshot: Dictionary)

const MAX_SCHEMA_VERSION := 2
const CONTENT_BUCKETS := [
	"arenas",
	"waves",
	"upgrades",
	"rules",
	"powerups",
	"weapons",
	"enemies",
	"bosses",
	"arena_events",
	"celestial_bodies",
	"physics_drops",
	"materials",
	"prefabs",
	"entities",
	"gamemodes",
	"npc_behaviors",
	"sfx",
	"music",
	"hud_badges",
	"maps",
	"tools",
	"script_packs",
	"workshop_tags",
]
const PATH_FIELDS := [
	"scene",
	"resource",
	"script",
	"audio",
	"stream",
	"texture",
	"icon",
	"thumbnail",
	"preview",
]
const SCRIPT_CONTENT_BUCKETS := ["script_packs", "tools", "npc_behaviors"]

@export var enabled: bool = true
@export var load_res_mods: bool = true
@export var load_user_mods: bool = true
@export var allow_script_pack_registration: bool = false
@export var res_mod_root: String = "res://Mods"
@export var user_mod_root: String = "user://mods"
@export var manifest_file_name: String = "vector_anomaly_mod.json"

var _manifests: Dictionary = {}
var _failed_manifests: Dictionary = {}
var _dependency_warnings: Dictionary = {}
var _disabled_manifests: Dictionary = {}
var _content: Dictionary = {}
var _content_index: Dictionary = {}
var _load_order: Array[StringName] = []


func _ready() -> void:
	add_to_group("mod_content_registry")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_reset_content_buckets()
	call_deferred("reload_registry")


func reload_registry() -> void:
	_manifests.clear()
	_failed_manifests.clear()
	_dependency_warnings.clear()
	_disabled_manifests.clear()
	_content_index.clear()
	_load_order.clear()
	_reset_content_buckets()

	if enabled:
		if load_res_mods:
			_scan_mod_root(res_mod_root)
		if load_user_mods:
			_scan_mod_root(user_mod_root)

	_resolve_dependency_warnings()
	_apply_manifest_enabled_state()
	var summary := get_registry_summary()
	registry_loaded.emit(summary)
	registry_reloaded.emit(summary)
	mod_catalog_changed.emit(get_registry_snapshot())


func get_registry_summary() -> Dictionary:
	var summary := {
		"manifest_count": _manifests.size(),
		"failed": _failed_manifests.size(),
		"dependency_warnings": _dependency_warnings.size(),
		"disabled": _disabled_manifests.size(),
		"content_total": _content_index.size(),
		"load_order": _load_order.duplicate(),
	}
	for bucket in CONTENT_BUCKETS:
		summary[bucket] = (_content[bucket] as Dictionary).size()
	return summary


func get_registry_snapshot() -> Dictionary:
	return {
		"manifests": _manifests.duplicate(true),
		"failed_manifests": _failed_manifests.duplicate(true),
		"dependency_warnings": _dependency_warnings.duplicate(true),
		"disabled_manifests": _disabled_manifests.duplicate(true),
		"content": _content.duplicate(true),
		"content_index": _content_index.duplicate(true),
		"load_order": _load_order.duplicate(),
		"buckets": CONTENT_BUCKETS.duplicate(),
	}


func get_content_buckets() -> Array:
	return CONTENT_BUCKETS.duplicate()


func get_entries(content_type: StringName) -> Array:
	var key := String(content_type)
	if not _content.has(key):
		return []
	return (_content[key] as Dictionary).values()


func get_content(content_type: StringName) -> Array:
	return get_entries(content_type)


func get_entry(content_type: StringName, entry_id: StringName) -> Dictionary:
	var key := String(content_type)
	if not _content.has(key):
		return {}
	var entries := _content[key] as Dictionary
	var id_text := String(entry_id)
	var entry: Variant = entries.get(id_text, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)

	var indexed_key := "%s:%s" % [key, id_text]
	if _content_index.has(indexed_key):
		var qualified_id := String(_content_index[indexed_key])
		entry = entries.get(qualified_id, {})
		if entry is Dictionary:
			return (entry as Dictionary).duplicate(true)
	return {}


func get_content_entry(content_type: StringName, entry_id: StringName) -> Dictionary:
	return get_entry(content_type, entry_id)


func has_content(content_type: StringName, entry_id: StringName) -> bool:
	return not get_entry(content_type, entry_id).is_empty()


func get_manifest(manifest_id: StringName) -> Dictionary:
	var manifest: Variant = _manifests.get(String(manifest_id), {})
	if manifest is Dictionary:
		return (manifest as Dictionary).duplicate(true)
	return {}


func get_manifest_load_order() -> Array[StringName]:
	return _load_order.duplicate()


func get_dependency_warnings() -> Dictionary:
	return _dependency_warnings.duplicate(true)


func _reset_content_buckets() -> void:
	_content.clear()
	for bucket in CONTENT_BUCKETS:
		_content[bucket] = {}


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
		_record_failed_manifest(path, "cannot_open")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_record_failed_manifest(path, "invalid_json")
		return

	var manifest := parsed as Dictionary
	var validation_errors := _validate_manifest(manifest)
	if not validation_errors.is_empty():
		var reason := _join_errors(validation_errors)
		_record_failed_manifest(path, reason)
		return

	var manifest_id := StringName(str(manifest.get("id", "")))
	var manifest_key := String(manifest_id)
	if _manifests.has(manifest_key):
		_record_failed_manifest(path, "duplicate manifest id %s" % manifest_key)
		return

	var metadata := {
		"id": manifest_id,
		"display_name": str(manifest.get("display_name", manifest_id)),
		"version": str(manifest.get("version", "1")),
		"schema_version": int(manifest.get("schema_version", 1)),
		"author": str(manifest.get("author", "")),
		"description": str(manifest.get("description", "")),
		"source_path": path,
		"tags": _string_array(manifest.get("tags", [])),
		"dependencies": _dependency_array(manifest.get("dependencies", [])),
		"load_after": _string_array(manifest.get("load_after", [])),
		"enabled": true,
	}
	_manifests[manifest_key] = metadata
	_load_order.append(manifest_id)

	for bucket in CONTENT_BUCKETS:
		_register_content_array(manifest, manifest_id, bucket)

	manifest_validated.emit(manifest_id, path)
	manifest_loaded.emit(manifest_id, path)


func _validate_manifest(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var manifest_id := str(manifest.get("id", "")).strip_edges()
	if manifest_id.is_empty():
		errors.append("missing id")
	if str(manifest.get("version", "")).strip_edges().is_empty():
		errors.append("missing version")
	var schema_version := int(manifest.get("schema_version", 1))
	if schema_version < 1 or schema_version > MAX_SCHEMA_VERSION:
		errors.append("schema_version must be 1-%d" % MAX_SCHEMA_VERSION)

	var dependencies: Variant = manifest.get("dependencies", [])
	if not (dependencies is Array):
		errors.append("dependencies must be an array")
	else:
		var dependency_entries := dependencies as Array
		_validate_dependencies(dependency_entries, errors)

	var content_value: Variant = manifest.get("content", {})
	if content_value != null and not (content_value is Dictionary):
		errors.append("content must be an object")

	for bucket in CONTENT_BUCKETS:
		var entries_value: Variant = _manifest_bucket_entries(manifest, bucket)
		if entries_value == null or not (entries_value is Array):
			errors.append("%s must be an array" % bucket)
			continue
		var entries := entries_value as Array
		_validate_entry_array(entries, bucket, errors)
	return errors


func _validate_dependencies(entries: Array, errors: Array[String]) -> void:
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		if entry is String:
			if str(entry).strip_edges().is_empty():
				errors.append("dependencies[%d] missing id" % index)
			continue
		if not (entry is Dictionary):
			errors.append("dependencies[%d] must be a string or object" % index)
			continue
		var dependency := entry as Dictionary
		if str(dependency.get("id", "")).strip_edges().is_empty():
			errors.append("dependencies[%d] missing id" % index)


func _validate_entry_array(entries: Array, key: String, errors: Array[String]) -> void:
	for index in range(entries.size()):
		var entry_value: Variant = entries[index]
		if not (entry_value is Dictionary):
			errors.append("%s[%d] must be an object" % [key, index])
			continue
		var entry := entry_value as Dictionary
		if str(entry.get("id", "")).strip_edges().is_empty():
			errors.append("%s[%d] missing id" % [key, index])
		_validate_entry_paths(entry, key, index, errors)


func _validate_entry_paths(entry: Dictionary, key: String, index: int, errors: Array[String]) -> void:
	for field in PATH_FIELDS:
		if not entry.has(field):
			continue
		var value: Variant = entry.get(field)
		if value == null or str(value).is_empty():
			continue
		if not (value is String):
			errors.append("%s[%d].%s must be a string path" % [key, index, field])
			continue
		var path := str(value)
		if not (path.begins_with("res://") or path.begins_with("user://")):
			errors.append("%s[%d].%s must use res:// or user://" % [key, index, field])


func _manifest_bucket_entries(manifest: Dictionary, bucket: String) -> Variant:
	var root_value: Variant = manifest.get(bucket, [])
	if not (root_value is Array):
		return null
	var entries := (root_value as Array).duplicate(true)
	var content_value: Variant = manifest.get("content", {})
	if content_value is Dictionary:
		var nested_value: Variant = (content_value as Dictionary).get(bucket, [])
		if not (nested_value is Array):
			return null
		var nested_entries := nested_value as Array
		for nested_entry in nested_entries:
			entries.append(nested_entry)
	return entries


func _register_content_array(manifest: Dictionary, manifest_id: StringName, key: String) -> void:
	var entries_value: Variant = _manifest_bucket_entries(manifest, key)
	if not (entries_value is Array):
		return
	var entries := entries_value as Array
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := (entry_value as Dictionary).duplicate(true)
		var local_id := str(entry.get("id", "")).strip_edges()
		if local_id.is_empty():
			continue

		var qualified_id := _qualified_content_id(manifest_id, local_id)
		entry["id"] = qualified_id
		entry["local_id"] = local_id
		entry["qualified_id"] = qualified_id
		entry["manifest_id"] = manifest_id
		entry["content_type"] = key
		entry["enabled"] = true
		entry["activation_state"] = _entry_activation_state(key)
		entry["script_execution_allowed"] = allow_script_pack_registration and SCRIPT_CONTENT_BUCKETS.has(key)

		(_content[key] as Dictionary)[qualified_id] = entry
		_content_index["%s:%s" % [key, local_id]] = qualified_id
		content_registered.emit(StringName(key), StringName(qualified_id), manifest_id, entry.duplicate(true))


func _resolve_dependency_warnings() -> void:
	for manifest_id in _load_order:
		var manifest_key := String(manifest_id)
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		var dependencies: Array = manifest.get("dependencies", [])
		for dependency_value in dependencies:
			var dependency: Dictionary = dependency_value if dependency_value is Dictionary else {}
			var dependency_id := StringName(str(dependency.get("id", "")))
			if String(dependency_id).is_empty():
				continue
			if not _manifests.has(String(dependency_id)):
				_add_dependency_warning(manifest_id, dependency_id, "missing dependency")
				if bool(dependency.get("required", true)):
					_disabled_manifests[manifest_key] = "missing dependency %s" % String(dependency_id)
				continue
			var min_version := str(dependency.get("min_version", "")).strip_edges()
			if min_version.is_empty():
				continue
			var loaded_version := str((_manifests[String(dependency_id)] as Dictionary).get("version", "0"))
			if _version_sort_value(loaded_version) < _version_sort_value(min_version):
				_add_dependency_warning(manifest_id, dependency_id, "dependency below min_version %s" % min_version)
				if bool(dependency.get("required", true)):
					_disabled_manifests[manifest_key] = "dependency %s below %s" % [String(dependency_id), min_version]

	if not allow_script_pack_registration:
		for manifest_id in _load_order:
			var script_entries := _entries_for_manifest(manifest_id, SCRIPT_CONTENT_BUCKETS)
			if script_entries.is_empty():
				continue
			_add_dependency_warning(manifest_id, &"script_packs", "script content discovered but locked")


func _apply_manifest_enabled_state() -> void:
	for manifest_id in _load_order:
		var manifest_key := String(manifest_id)
		var enabled_state := not _disabled_manifests.has(manifest_key)
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		manifest["enabled"] = enabled_state
		manifest["disabled_reason"] = str(_disabled_manifests.get(manifest_key, ""))
		_manifests[manifest_key] = manifest

	for bucket in CONTENT_BUCKETS:
		var entries := _content[bucket] as Dictionary
		for qualified_id in entries.keys():
			var entry: Dictionary = entries[qualified_id]
			var manifest_key := String(entry.get("manifest_id", ""))
			var enabled_state := not _disabled_manifests.has(manifest_key)
			entry["enabled"] = enabled_state
			entry["disabled_reason"] = str(_disabled_manifests.get(manifest_key, ""))
			entries[qualified_id] = entry


func _entries_for_manifest(manifest_id: StringName, buckets: Array) -> Array:
	var found := []
	for bucket in buckets:
		if not _content.has(bucket):
			continue
		var bucket_entries := _content[bucket] as Dictionary
		for entry_value in bucket_entries.values():
			if not (entry_value is Dictionary):
				continue
			var entry := entry_value as Dictionary
			if String(entry.get("manifest_id", "")) == String(manifest_id):
				found.append(entry)
	return found


func _add_dependency_warning(manifest_id: StringName, dependency_id: StringName, reason: String) -> void:
	var key := "%s:%s:%s" % [String(manifest_id), String(dependency_id), reason]
	_dependency_warnings[key] = {
		"manifest_id": manifest_id,
		"dependency_id": dependency_id,
		"reason": reason,
	}
	dependency_warning.emit(manifest_id, dependency_id, reason)


func _dependency_array(value: Variant) -> Array:
	var dependencies := []
	if not (value is Array):
		return dependencies
	var dependency_values := value as Array
	for entry in dependency_values:
		if entry is String:
			dependencies.append({
				"id": str(entry),
				"required": true,
			})
		elif entry is Dictionary:
			var dependency := (entry as Dictionary).duplicate(true)
			dependency["id"] = str(dependency.get("id", ""))
			dependency["required"] = bool(dependency.get("required", true))
			dependencies.append(dependency)
	return dependencies


func _string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if not (value is Array):
		return strings
	var values := value as Array
	for entry in values:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			strings.append(text)
	return strings


func _entry_activation_state(bucket: String) -> StringName:
	if SCRIPT_CONTENT_BUCKETS.has(bucket):
		return &"locked" if not allow_script_pack_registration else &"cataloged"
	return &"cataloged"


func _qualified_content_id(manifest_id: StringName, local_id: String) -> String:
	return "%s/%s" % [String(manifest_id), local_id]


func _version_sort_value(version_text: String) -> int:
	var parts := version_text.split(".")
	var value := 0
	var multiplier := 1000000
	for part in parts:
		value += int(part) * multiplier
		multiplier = maxi(int(multiplier / 1000), 1)
	return value


func _join_errors(errors: Array[String]) -> String:
	var parts := PackedStringArray()
	for error in errors:
		parts.append(error)
	return "; ".join(parts)


func _record_failed_manifest(path: String, reason: String) -> void:
	_failed_manifests[path] = reason
	manifest_failed.emit(path, reason)
