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
signal mod_hook_registered(hook_id: StringName, entry_id: StringName, manifest_id: StringName, entry: Dictionary)

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
	"law_weaves",
	"anomaly_recipes",
	"challenge_cards",
	"mod_palettes",
	"creator_notes",
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
const HOOKABLE_CONTENT_BUCKETS := ["law_weaves", "anomaly_recipes", "challenge_cards"]
const LOCAL_ONLY_CONTENT_BUCKETS := ["mod_palettes", "creator_notes", "hud_badges", "sfx", "music"]
const WEAPON_FIRE_MODES := ["catalog", "projectile", "beam"]
const NETWORK_CATEGORIES := ["local_visual", "exported_state", "reliable_event", "deterministic_seed"]
const WEAPON_PATTERN_MODES := ["single", "spread", "parallel", "braid", "helix", "ring"]
const MOD_HOOKS := [
	"run_start",
	"wave_start",
	"wave_clear",
	"boss_spawned",
	"boss_defeated",
	"slingshot_good",
	"slingshot_great",
	"slingshot_perfect",
	"slingshot_apex",
	"weapon_fired",
	"projectile_hit",
	"resonance_created",
	"gravity_scar_created",
	"near_death",
	"death",
	"recovery_window_started",
	"rare_event_started",
	"rupture_started",
	"music_beat",
	"coop_combo_triggered",
]
const MOD_EFFECT_ACTIONS := [
	"spawn_arena_event",
	"create_resonance_zone",
	"create_gravity_scar",
	"grant_powerup",
	"offer_weapon",
	"spawn_celestial_body",
	"spawn_physics_drop",
	"emit_hud_badge",
	"play_sfx",
	"request_music_layer",
	"adjust_run_pressure",
	"tag_score_event",
	"start_challenge_card",
	"complete_challenge_card",
]
const LOCAL_VISUAL_EFFECT_ACTIONS := ["emit_hud_badge", "play_sfx", "request_music_layer"]
const MOD_CONDITION_TYPES := [
	"min_wave",
	"max_wave",
	"chaos_tier_at_least",
	"chaos_tier_at_most",
	"has_powerup",
	"has_weapon",
	"slingshot_grade_at_least",
	"resonance_type",
	"scar_type",
	"boss_active",
	"player_health_below",
	"player_shield_below",
	"seed_tag",
	"run_modifier",
	"multiplayer_peer_count_at_least",
]
const WEAPON_NUMERIC_FIELDS := [
	"energy_per_shot",
	"energy_per_second",
	"fire_interval",
	"shot_count",
	"spread_radians",
	"damage_min",
	"damage_max",
	"speed",
	"gravity_constant",
	"gravity_pull_radius",
	"player_gravity_deadzone_radius",
	"field_radius",
	"field_force",
	"field_damage",
	"field_slow_multiplier",
	"field_slow_duration",
	"field_max_targets",
	"slow_multiplier",
	"slow_duration",
	"axis_impulse",
	"pierce_count",
	"curve_force",
	"curve_side",
	"curve_frequency",
	"planet_damage",
	"radial_impulse",
	"tangent_impulse",
	"weapon_axis_impulse",
	"weapon_temporal_slow_multiplier",
	"weapon_temporal_slow_duration",
	"weapon_pierce_count",
	"weapon_resonance_radius",
	"weapon_resonance_intensity",
	"weapon_curve_force",
	"weapon_curve_side",
	"weapon_curve_frequency",
	"weapon_planet_damage",
	"weapon_radial_impulse",
	"weapon_tangent_impulse",
	"weapon_field_radius",
	"weapon_field_force",
	"weapon_field_damage",
	"weapon_field_slow_multiplier",
	"weapon_field_slow_duration",
	"weapon_field_max_targets",
	"weapon_scar_radius",
	"weapon_scar_intensity",
	"weapon_scar_duration",
]
const WEAPON_PAYLOAD_ALIASES := {
	"speed": "initial_speed",
	"field_radius": "weapon_field_radius",
	"field_force": "weapon_field_force",
	"field_damage": "weapon_field_damage",
	"field_slow_multiplier": "weapon_field_slow_multiplier",
	"field_slow_duration": "weapon_field_slow_duration",
	"field_max_targets": "weapon_field_max_targets",
	"slow_multiplier": "weapon_temporal_slow_multiplier",
	"slow_duration": "weapon_temporal_slow_duration",
	"axis_impulse": "weapon_axis_impulse",
	"pierce_count": "weapon_pierce_count",
	"curve_force": "weapon_curve_force",
	"curve_side": "weapon_curve_side",
	"curve_frequency": "weapon_curve_frequency",
	"planet_damage": "weapon_planet_damage",
	"radial_impulse": "weapon_radial_impulse",
	"tangent_impulse": "weapon_tangent_impulse",
	"resonance_zone_type": "weapon_resonance_zone_type",
	"resonance_radius": "weapon_resonance_radius",
	"resonance_intensity": "weapon_resonance_intensity",
	"scar_type": "weapon_scar_type",
	"scar_radius": "weapon_scar_radius",
	"scar_intensity": "weapon_scar_intensity",
	"scar_duration": "weapon_scar_duration",
}
const WEAPON_PAYLOAD_FIELDS := [
	"weapon_id",
	"display_name",
	"initial_speed",
	"damage_min",
	"damage_max",
	"gravity_constant",
	"gravity_pull_radius",
	"player_gravity_deadzone_radius",
	"windowkill_visual_scale",
	"vector_core_color",
	"vector_trail_fade_color",
	"weapon_axis_impulse",
	"weapon_temporal_slow_multiplier",
	"weapon_temporal_slow_duration",
	"weapon_pierce_count",
	"weapon_resonance_zone_type",
	"weapon_resonance_radius",
	"weapon_resonance_intensity",
	"weapon_curve_force",
	"weapon_curve_side",
	"weapon_curve_frequency",
	"weapon_planet_damage",
	"weapon_radial_impulse",
	"weapon_tangent_impulse",
	"weapon_field_radius",
	"weapon_field_force",
	"weapon_field_damage",
	"weapon_field_slow_multiplier",
	"weapon_field_slow_duration",
	"weapon_field_max_targets",
	"weapon_scar_type",
	"weapon_scar_radius",
	"weapon_scar_intensity",
	"weapon_scar_duration",
	"phase_offset",
	"relativistic_rail_stacks",
	"vacuum_collapse_stacks",
]
const RESONANCE_ZONE_NAME_TO_ID := {
	"compression": GravityResonanceManager.ZoneType.COMPRESSION,
	"slipstream": GravityResonanceManager.ZoneType.SLIPSTREAM,
	"inversion": GravityResonanceManager.ZoneType.INVERSION,
	"temporal_scar": GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
	"harmonic_orbit": GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
}
const GRAVITY_SCAR_NAME_TO_ID := {
	"curvature": GravityScarManager.ScarType.CURVATURE,
	"velocity_shear": GravityScarManager.ScarType.VELOCITY_SHEAR,
	"inversion_wake": GravityScarManager.ScarType.INVERSION_WAKE,
	"temporal_rip": GravityScarManager.ScarType.TEMPORAL_RIP,
	"harmonic_fracture": GravityScarManager.ScarType.HARMONIC_FRACTURE,
}

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
var _hook_index: Dictionary = {}
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
	_hook_index.clear()
	_load_order.clear()
	_reset_content_buckets()

	if enabled:
		if load_res_mods:
			_scan_mod_root(res_mod_root)
		if load_user_mods:
			_scan_mod_root(user_mod_root)

	_resolve_dependency_warnings()
	_apply_manifest_enabled_state()
	_rebuild_hook_index()
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
		"hook_count": _hook_index.size(),
		"hook_entry_count": _hook_entry_count(),
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
		"hook_index": _hook_index.duplicate(true),
		"load_order": _load_order.duplicate(),
		"buckets": CONTENT_BUCKETS.duplicate(),
		"capabilities": get_modding_capabilities(),
	}


func get_content_buckets() -> Array:
	return CONTENT_BUCKETS.duplicate()


func get_entries(content_type: StringName) -> Array:
	var key := String(content_type)
	if not _content.has(key):
		return []
	return (_content[key] as Dictionary).values()


func get_playable_weapon_entries() -> Array:
	var playable := []
	var entries := get_entries(&"weapons")
	for value in entries:
		if not (value is Dictionary):
			continue
		var entry := value as Dictionary
		if not bool(entry.get("enabled", true)):
			continue
		if StringName(str(entry.get("activation_state", &"cataloged"))) != &"playable":
			continue
		playable.append(entry.duplicate(true))
	return playable


func get_hook_entries(hook_id: StringName) -> Array:
	var hook_key := String(hook_id)
	var indexed_value: Variant = _hook_index.get(hook_key, [])
	if not (indexed_value is Array):
		return []
	var entries := []
	var indexed_entries := indexed_value as Array
	for entry_value in indexed_entries:
		if entry_value is Dictionary:
			var entry := entry_value as Dictionary
			if bool(entry.get("enabled", true)):
				entries.append(entry.duplicate(true))
	return entries


func get_entries_with_tag(content_type: StringName, tag: StringName) -> Array:
	var tag_text := String(tag)
	if tag_text.is_empty():
		return []
	var matches := []
	for entry_value in get_entries(content_type):
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var tags: Array[String] = _string_array(entry.get("tags", []))
		if tags.has(tag_text):
			matches.append(entry.duplicate(true))
	return matches


func get_modding_capabilities() -> Dictionary:
	return {
		"schema_version_max": MAX_SCHEMA_VERSION,
		"buckets": CONTENT_BUCKETS.duplicate(),
		"hookable_buckets": HOOKABLE_CONTENT_BUCKETS.duplicate(),
		"hooks": MOD_HOOKS.duplicate(),
		"effect_actions": MOD_EFFECT_ACTIONS.duplicate(),
		"local_visual_effect_actions": LOCAL_VISUAL_EFFECT_ACTIONS.duplicate(),
		"condition_types": MOD_CONDITION_TYPES.duplicate(),
		"weapon_fire_modes": WEAPON_FIRE_MODES.duplicate(),
		"weapon_patterns": WEAPON_PATTERN_MODES.duplicate(),
		"network_categories": NETWORK_CATEGORIES.duplicate(),
		"script_buckets": SCRIPT_CONTENT_BUCKETS.duplicate(),
		"script_pack_registration_enabled": allow_script_pack_registration,
		"safe_data_only": true,
	}


func _hook_entry_count() -> int:
	var total := 0
	for entries_value in _hook_index.values():
		if entries_value is Array:
			total += (entries_value as Array).size()
	return total


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


func get_compatibility_signature() -> String:
	var tokens: Array[String] = []
	var content_tokens: Array[String] = []
	var gameplay_manifest_keys := {}
	for bucket in CONTENT_BUCKETS:
		var entries := _content[bucket] as Dictionary
		var ids := entries.keys()
		ids.sort()
		for qualified_id in ids:
			var entry: Dictionary = entries[qualified_id]
			if not bool(entry.get("enabled", true)):
				continue
			var network_category := String(entry.get("network_category", _default_network_category(bucket)))
			if network_category == "local_visual":
				continue
			gameplay_manifest_keys[String(entry.get("manifest_id", ""))] = true
			content_tokens.append(_content_signature_token(bucket, String(qualified_id), entry))
	for manifest_id in _load_order:
		var manifest_key := String(manifest_id)
		if not gameplay_manifest_keys.has(manifest_key):
			continue
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		if manifest.is_empty() or not bool(manifest.get("enabled", true)):
			continue
		tokens.append("%s:%s:%d" % [
			manifest_key,
			String(manifest.get("version", "1")),
			int(manifest.get("schema_version", 1)),
		])
	for token in content_tokens:
		tokens.append(token)
	var packed := PackedStringArray()
	for token in tokens:
		packed.append(token)
	return ("mods:%s" % "|".join(packed)).sha256_text().substr(0, 16)


func _reset_content_buckets() -> void:
	_content.clear()
	_hook_index.clear()
	for bucket in CONTENT_BUCKETS:
		_content[bucket] = {}


func _content_signature_token(bucket: String, qualified_id: String, entry: Dictionary) -> String:
	var token := "%s:%s:%s" % [
		bucket,
		qualified_id,
		String(entry.get("network_category", _default_network_category(bucket))),
	]
	if bucket != "weapons":
		if HOOKABLE_CONTENT_BUCKETS.has(bucket):
			var hook_signature := _signature_dictionary(entry, [
				"hooks",
				"conditions",
				"effects",
				"weight",
				"cooldown",
				"max_triggers",
				"exclusive_group",
			])
			return "%s:%s" % [token, _stable_dictionary_digest(hook_signature)]
		return token

	var payload_value: Variant = entry.get("payload", {})
	var payload_digest := ""
	if payload_value is Dictionary:
		payload_digest = _stable_dictionary_digest(payload_value as Dictionary)
	return "%s:%s:%s:%s:%s:%s:%s" % [
		token,
		String(entry.get("fire_mode", "catalog")),
		String(entry.get("base_weapon_id", "")),
		String(entry.get("pattern", "single")),
		String(entry.get("shot_count", 1)),
		String(entry.get("spread_radians", 0.0)),
		payload_digest,
	]


func _signature_dictionary(entry: Dictionary, fields: Array) -> Dictionary:
	var signature := {}
	for field in fields:
		if entry.has(field):
			signature[field] = entry[field]
	return signature


func _stable_dictionary_digest(source: Dictionary) -> String:
	var keys := source.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(a) < str(b)
	)
	var parts := PackedStringArray()
	for key in keys:
		parts.append("%s=%s" % [str(key), _stable_value_text(source[key])])
	return "|".join(parts).sha256_text().substr(0, 12)


func _stable_value_text(value: Variant) -> String:
	if value is Dictionary:
		return _stable_dictionary_digest(value)
	if value is Array:
		var parts := PackedStringArray()
		for item in value:
			parts.append(_stable_value_text(item))
		return "[%s]" % ",".join(parts)
	if value is Color:
		var color: Color = value
		return "color(%.4f,%.4f,%.4f,%.4f)" % [color.r, color.g, color.b, color.a]
	return str(value)


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
	elif not _is_safe_identifier(manifest_id):
		errors.append("id contains unsafe characters")
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
		var entry_id := str(entry.get("id", "")).strip_edges()
		if entry_id.is_empty():
			errors.append("%s[%d] missing id" % [key, index])
		elif not _is_safe_identifier(entry_id):
			errors.append("%s[%d] id contains unsafe characters" % [key, index])
		_validate_entry_paths(entry, key, index, errors)
		_validate_bucket_specific_entry(entry, key, index, errors)


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
		if path.contains(".."):
			errors.append("%s[%d].%s must not contain .." % [key, index, field])
		if field == "script" and not SCRIPT_CONTENT_BUCKETS.has(key):
			errors.append("%s[%d].script is only allowed in trusted script content buckets" % [key, index])


func _validate_bucket_specific_entry(entry: Dictionary, key: String, index: int, errors: Array[String]) -> void:
	if key == "weapons":
		_validate_weapon_entry(entry, index, errors)
		return
	if HOOKABLE_CONTENT_BUCKETS.has(key):
		_validate_hookable_entry(entry, key, index, errors)
		return
	if key == "mod_palettes":
		_validate_palette_entry(entry, key, index, errors)
		return
	_validate_network_category_field(entry, key, index, errors)


func _validate_weapon_entry(entry: Dictionary, index: int, errors: Array[String]) -> void:
	_validate_network_category_field(entry, "weapons", index, errors)
	var fire_mode := str(entry.get("fire_mode", "catalog")).strip_edges()
	if fire_mode.is_empty():
		fire_mode = "catalog"
	if not WEAPON_FIRE_MODES.has(fire_mode):
		errors.append("weapons[%d].fire_mode must be catalog, projectile, or beam" % index)
	var pattern := str(entry.get("pattern", "single")).strip_edges()
	if pattern.is_empty():
		pattern = "single"
	if not WEAPON_PATTERN_MODES.has(pattern):
		errors.append("weapons[%d].pattern is invalid" % index)
	var base_weapon_id := str(entry.get("base_weapon_id", "vector_bolt")).strip_edges()
	if not base_weapon_id.is_empty() and not _is_safe_identifier(base_weapon_id):
		errors.append("weapons[%d].base_weapon_id contains unsafe characters" % index)
	for field in WEAPON_NUMERIC_FIELDS:
		if not entry.has(field):
			continue
		var value: Variant = entry.get(field)
		if not (value is float or value is int):
			errors.append("weapons[%d].%s must be numeric" % [index, field])
	var payload_value: Variant = entry.get("payload", {})
	if payload_value != null and not (payload_value is Dictionary):
		errors.append("weapons[%d].payload must be an object" % index)
	elif payload_value is Dictionary:
		_validate_weapon_payload(payload_value as Dictionary, index, errors)


func _validate_hookable_entry(entry: Dictionary, key: String, index: int, errors: Array[String]) -> void:
	_validate_network_category_field(entry, key, index, errors)
	_validate_hook_array(entry, key, index, errors)
	_validate_condition_array(entry, key, index, errors)
	_validate_effect_array(entry, key, index, errors)
	for field in ["weight", "cooldown", "max_triggers"]:
		if not entry.has(field):
			continue
		var value: Variant = entry.get(field)
		if not (value is float or value is int):
			errors.append("%s[%d].%s must be numeric" % [key, index, field])
	if entry.has("exclusive_group"):
		var group_id := str(entry.get("exclusive_group", "")).strip_edges()
		if not group_id.is_empty() and not _is_safe_identifier(group_id):
			errors.append("%s[%d].exclusive_group contains unsafe characters" % [key, index])


func _validate_palette_entry(entry: Dictionary, key: String, index: int, errors: Array[String]) -> void:
	_validate_network_category_field(entry, key, index, errors)
	for field in ["colors", "accent_colors"]:
		if not entry.has(field):
			continue
		var value: Variant = entry.get(field)
		if not (value is Array):
			errors.append("%s[%d].%s must be an array" % [key, index, field])
			continue
		for color_index in range((value as Array).size()):
			var color_value: Variant = (value as Array)[color_index]
			if _color_entry_is_valid(color_value):
				continue
			errors.append("%s[%d].%s[%d] must be a color string or numeric rgba array" % [key, index, field, color_index])


func _validate_network_category_field(entry: Dictionary, key: String, index: int, errors: Array[String]) -> void:
	var network_category := str(entry.get("network_category", _default_network_category(key))).strip_edges()
	if network_category.is_empty():
		network_category = _default_network_category(key)
	if not NETWORK_CATEGORIES.has(network_category):
		errors.append("%s[%d].network_category is invalid" % [key, index])


func _validate_hook_array(entry: Dictionary, key: String, index: int, errors: Array[String]) -> void:
	var hooks_value: Variant = entry.get("hooks", null)
	if hooks_value == null:
		return
	if not (hooks_value is Array):
		errors.append("%s[%d].hooks must be an array" % [key, index])
		return
	var hooks := hooks_value as Array
	if hooks.is_empty():
		errors.append("%s[%d].hooks must not be empty" % [key, index])
	for hook_index in range(hooks.size()):
		var hook := str(hooks[hook_index]).strip_edges()
		if hook.is_empty() or not MOD_HOOKS.has(hook):
			errors.append("%s[%d].hooks[%d] is not a supported hook" % [key, index, hook_index])


func _validate_condition_array(entry: Dictionary, key: String, index: int, errors: Array[String]) -> void:
	var conditions_value: Variant = entry.get("conditions", [])
	if not (conditions_value is Array):
		errors.append("%s[%d].conditions must be an array" % [key, index])
		return
	var conditions := conditions_value as Array
	for condition_index in range(conditions.size()):
		var condition_value: Variant = conditions[condition_index]
		if not (condition_value is Dictionary):
			errors.append("%s[%d].conditions[%d] must be an object" % [key, index, condition_index])
			continue
		var condition := condition_value as Dictionary
		var condition_type := str(condition.get("type", "")).strip_edges()
		if condition_type.is_empty() or not MOD_CONDITION_TYPES.has(condition_type):
			errors.append("%s[%d].conditions[%d].type is not supported" % [key, index, condition_index])
		if condition.has("script"):
			errors.append("%s[%d].conditions[%d].script is not allowed" % [key, index, condition_index])


func _validate_effect_array(entry: Dictionary, key: String, index: int, errors: Array[String]) -> void:
	var effects_value: Variant = entry.get("effects", [])
	if not (effects_value is Array):
		errors.append("%s[%d].effects must be an array" % [key, index])
		return
	var effects := effects_value as Array
	for effect_index in range(effects.size()):
		var effect_value: Variant = effects[effect_index]
		if not (effect_value is Dictionary):
			errors.append("%s[%d].effects[%d] must be an object" % [key, index, effect_index])
			continue
		var effect := effect_value as Dictionary
		var action := str(effect.get("action", "")).strip_edges()
		if action.is_empty() or not MOD_EFFECT_ACTIONS.has(action):
			errors.append("%s[%d].effects[%d].action is not supported" % [key, index, effect_index])
		elif str(entry.get("network_category", _default_network_category(key))) == "local_visual" and not LOCAL_VISUAL_EFFECT_ACTIONS.has(action):
			errors.append("%s[%d].effects[%d].action is not local_visual safe" % [key, index, effect_index])
		if effect.has("script"):
			errors.append("%s[%d].effects[%d].script is not allowed" % [key, index, effect_index])


func _validate_weapon_payload(payload: Dictionary, index: int, errors: Array[String]) -> void:
	for field in WEAPON_NUMERIC_FIELDS:
		var canonical_field := str(WEAPON_PAYLOAD_ALIASES.get(field, field))
		for key in [field, canonical_field]:
			if not payload.has(key):
				continue
			var value: Variant = payload.get(key)
			if canonical_field == "weapon_resonance_zone_type" or canonical_field == "weapon_scar_type":
				if value is String and _weapon_named_type_is_valid(canonical_field, str(value)):
					continue
				if value is int:
					continue
				errors.append("weapons[%d].payload.%s must be numeric or a known type name" % [index, key])
				continue
			if not (value is float or value is int):
				errors.append("weapons[%d].payload.%s must be numeric" % [index, key])
	for typed_key in ["resonance_zone_type", "weapon_resonance_zone_type", "scar_type", "weapon_scar_type"]:
		if not payload.has(typed_key):
			continue
		var canonical_typed_key := _canonical_payload_key(typed_key)
		var typed_value: Variant = payload.get(typed_key)
		if typed_value is String and _weapon_named_type_is_valid(canonical_typed_key, str(typed_value)):
			continue
		if typed_value is int:
			continue
		errors.append("weapons[%d].payload.%s must be numeric or a known type name" % [index, typed_key])


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


func _normalize_hookable_entry(entry: Dictionary, bucket: String) -> Dictionary:
	var normalized := entry.duplicate(true)
	normalized["network_category"] = _normalized_network_category(normalized, bucket)
	normalized["hooks"] = _normalize_known_string_array(
		normalized.get("hooks", []),
		MOD_HOOKS,
		_default_hook_for_bucket(bucket)
	)
	normalized["conditions"] = _normalize_typed_dictionary_array(normalized.get("conditions", []), "type", MOD_CONDITION_TYPES)
	normalized["effects"] = _normalize_typed_dictionary_array(normalized.get("effects", []), "action", MOD_EFFECT_ACTIONS)
	normalized["weight"] = maxf(0.0, float(normalized.get("weight", 1.0)))
	normalized["cooldown"] = maxf(0.0, float(normalized.get("cooldown", 0.0)))
	normalized["max_triggers"] = maxi(0, int(normalized.get("max_triggers", 0)))
	normalized["exclusive_group"] = str(normalized.get("exclusive_group", "")).strip_edges()
	return normalized


func _normalize_palette_entry(entry: Dictionary) -> Dictionary:
	var normalized := entry.duplicate(true)
	normalized["network_category"] = _normalized_network_category(normalized, "mod_palettes")
	normalized["colors"] = _normalize_color_array(normalized.get("colors", []), Color(0.34, 1.0, 0.86, 1.0))
	normalized["accent_colors"] = _normalize_color_array(normalized.get("accent_colors", []), Color(1.0, 0.68, 0.28, 1.0))
	return normalized


func _normalize_creator_note_entry(entry: Dictionary) -> Dictionary:
	var normalized := entry.duplicate(true)
	normalized["network_category"] = _normalized_network_category(normalized, "creator_notes")
	normalized["note"] = str(normalized.get("note", normalized.get("description", "")))
	return normalized


func _normalize_weapon_entry(entry: Dictionary) -> Dictionary:
	var normalized := entry.duplicate(true)
	var fire_mode := str(normalized.get("fire_mode", "catalog")).strip_edges()
	if fire_mode.is_empty() or not WEAPON_FIRE_MODES.has(fire_mode):
		fire_mode = "catalog"
	normalized["fire_mode"] = fire_mode

	var network_category := str(normalized.get("network_category", _default_network_category("weapons"))).strip_edges()
	if network_category.is_empty() or not NETWORK_CATEGORIES.has(network_category):
		network_category = _default_network_category("weapons")
	normalized["network_category"] = network_category

	var base_weapon_id := str(normalized.get("base_weapon_id", "vector_bolt")).strip_edges()
	if base_weapon_id.is_empty() or not _is_safe_identifier(base_weapon_id):
		base_weapon_id = "vector_bolt"
	normalized["base_weapon_id"] = base_weapon_id

	var pattern := str(normalized.get("pattern", "single")).strip_edges()
	if pattern.is_empty() or not WEAPON_PATTERN_MODES.has(pattern):
		pattern = "single"
	normalized["pattern"] = pattern
	normalized["shot_count"] = clampi(int(normalized.get("shot_count", 1)), 1, 6)
	normalized["spread_radians"] = clampf(float(normalized.get("spread_radians", 0.12)), 0.0, 0.75)
	normalized["payload"] = _normalize_weapon_payload(normalized)
	return normalized


func _normalized_network_category(entry: Dictionary, bucket: String) -> String:
	var network_category := str(entry.get("network_category", _default_network_category(bucket))).strip_edges()
	if network_category.is_empty() or not NETWORK_CATEGORIES.has(network_category):
		network_category = _default_network_category(bucket)
	return network_category


func _normalize_known_string_array(value: Variant, allowed_values: Array, fallback: String) -> Array[String]:
	var normalized: Array[String] = []
	if value is Array:
		var values := value as Array
		for raw_value in values:
			var text := str(raw_value).strip_edges()
			if text.is_empty() or not allowed_values.has(text) or normalized.has(text):
				continue
			normalized.append(text)
	if normalized.is_empty() and not fallback.is_empty():
		normalized.append(fallback)
	return normalized


func _normalize_typed_dictionary_array(value: Variant, type_field: String, allowed_values: Array) -> Array:
	var normalized := []
	if not (value is Array):
		return normalized
	var values := value as Array
	for raw_value in values:
		if not (raw_value is Dictionary):
			continue
		var entry := (raw_value as Dictionary).duplicate(true)
		var typed_value := str(entry.get(type_field, "")).strip_edges()
		if typed_value.is_empty() or not allowed_values.has(typed_value):
			continue
		entry[type_field] = typed_value
		entry.erase("script")
		normalized.append(entry)
	return normalized


func _normalize_color_array(value: Variant, fallback: Color) -> Array:
	var colors := []
	if not (value is Array):
		return colors
	var values := value as Array
	for raw_value in values:
		if not _color_entry_is_valid(raw_value):
			continue
		colors.append(_color_from_variant(raw_value, fallback))
	return colors


func _default_hook_for_bucket(bucket: String) -> String:
	if bucket == "law_weaves":
		return "run_start"
	if bucket == "anomaly_recipes":
		return "wave_start"
	if bucket == "challenge_cards":
		return "run_start"
	return ""


func _normalize_weapon_payload(entry: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	var payload_value: Variant = entry.get("payload", {})
	var raw_payload: Dictionary = payload_value.duplicate(true) if payload_value is Dictionary else {}

	for field in WEAPON_NUMERIC_FIELDS:
		if not entry.has(field):
			continue
		var canonical := _canonical_payload_key(field)
		if WEAPON_PAYLOAD_FIELDS.has(canonical) and not raw_payload.has(canonical):
			raw_payload[canonical] = entry[field]

	for key_value in raw_payload.keys():
		var key := str(key_value)
		var canonical_key := _canonical_payload_key(key)
		if not WEAPON_PAYLOAD_FIELDS.has(canonical_key):
			continue
		var value: Variant = raw_payload[key_value]
		if canonical_key == "weapon_resonance_zone_type":
			value = _normalize_weapon_type_value(value, RESONANCE_ZONE_NAME_TO_ID, -1)
		elif canonical_key == "weapon_scar_type":
			value = _normalize_weapon_type_value(value, GRAVITY_SCAR_NAME_TO_ID, -1)
		normalized[canonical_key] = value

	if entry.has("color"):
		var parsed_color := _color_from_variant(entry.get("color"), Color(0.34, 1.0, 0.86, 0.82))
		normalized["vector_core_color"] = parsed_color
		normalized["vector_trail_fade_color"] = Color(parsed_color.r, parsed_color.g, parsed_color.b, minf(parsed_color.a, 0.92))
	return normalized


func _canonical_payload_key(key: String) -> String:
	return str(WEAPON_PAYLOAD_ALIASES.get(key, key))


func _normalize_weapon_type_value(value: Variant, lookup: Dictionary, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	var key := str(value).strip_edges().to_lower()
	if lookup.has(key):
		return int(lookup[key])
	return fallback


func _weapon_named_type_is_valid(field: String, value: String) -> bool:
	var key := value.strip_edges().to_lower()
	if field == "weapon_resonance_zone_type":
		return RESONANCE_ZONE_NAME_TO_ID.has(key)
	if field == "weapon_scar_type":
		return GRAVITY_SCAR_NAME_TO_ID.has(key)
	return false


func _weapon_activation_state(entry: Dictionary) -> StringName:
	if str(entry.get("fire_mode", "catalog")) != "projectile":
		return &"cataloged"
	if str(entry.get("network_category", _default_network_category("weapons"))) == "local_visual":
		return &"cataloged"
	return &"playable"


func _color_entry_is_valid(value: Variant) -> bool:
	if value is Color:
		return true
	if value is String:
		var text := str(value).strip_edges()
		return text.begins_with("#") and (text.length() == 7 or text.length() == 9)
	if value is Array:
		var values := value as Array
		if values.size() < 3:
			return false
		for index in range(mini(values.size(), 4)):
			var channel: Variant = values[index]
			if not (channel is float or channel is int):
				return false
		return true
	return false


func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String:
		var text := str(value).strip_edges()
		if text.begins_with("#") and (text.length() == 7 or text.length() == 9):
			return Color.html(text)
	if value is Array:
		var values := value as Array
		if values.size() >= 3:
			return Color(
				clampf(float(values[0]), 0.0, 1.0),
				clampf(float(values[1]), 0.0, 1.0),
				clampf(float(values[2]), 0.0, 1.0),
				clampf(float(values[3]), 0.0, 1.0) if values.size() >= 4 else fallback.a
			)
	return fallback


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
		if key == "weapons":
			entry = _normalize_weapon_entry(entry)
		elif HOOKABLE_CONTENT_BUCKETS.has(key):
			entry = _normalize_hookable_entry(entry, key)
		elif key == "mod_palettes":
			entry = _normalize_palette_entry(entry)
		elif key == "creator_notes":
			entry = _normalize_creator_note_entry(entry)

		var qualified_id := _qualified_content_id(manifest_id, local_id)
		entry["id"] = qualified_id
		entry["local_id"] = local_id
		entry["qualified_id"] = qualified_id
		entry["manifest_id"] = manifest_id
		entry["content_type"] = key
		entry["enabled"] = true
		entry["network_category"] = str(entry.get("network_category", _default_network_category(key)))
		entry["activation_state"] = _weapon_activation_state(entry) if key == "weapons" else _entry_activation_state(key)
		entry["script_execution_allowed"] = allow_script_pack_registration and SCRIPT_CONTENT_BUCKETS.has(key)

		(_content[key] as Dictionary)[qualified_id] = entry
		_content_index["%s:%s" % [key, local_id]] = qualified_id
		content_registered.emit(StringName(key), StringName(qualified_id), manifest_id, entry.duplicate(true))


func _rebuild_hook_index() -> void:
	_hook_index.clear()
	for bucket in HOOKABLE_CONTENT_BUCKETS:
		var entries := _content[bucket] as Dictionary
		for entry_value in entries.values():
			if entry_value is Dictionary:
				_register_hook_index(entry_value as Dictionary)


func _register_hook_index(entry: Dictionary) -> void:
	var hooks: Array[String] = _string_array(entry.get("hooks", []))
	for hook in hooks:
		if hook.is_empty() or not MOD_HOOKS.has(hook):
			continue
		if not _hook_index.has(hook):
			_hook_index[hook] = []
		(_hook_index[hook] as Array).append(entry.duplicate(true))
		if bool(entry.get("enabled", true)):
			mod_hook_registered.emit(
				StringName(hook),
				StringName(str(entry.get("qualified_id", entry.get("id", "")))),
				StringName(str(entry.get("manifest_id", ""))),
				entry.duplicate(true)
			)


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
	if HOOKABLE_CONTENT_BUCKETS.has(bucket):
		return &"hookable"
	if bucket == "mod_palettes":
		return &"visual"
	if bucket == "creator_notes":
		return &"documentation"
	if SCRIPT_CONTENT_BUCKETS.has(bucket):
		return &"locked" if not allow_script_pack_registration else &"cataloged"
	return &"cataloged"


func _default_network_category(bucket: String) -> String:
	if bucket == "weapons":
		return "reliable_event"
	if LOCAL_ONLY_CONTENT_BUCKETS.has(bucket):
		return "local_visual"
	if HOOKABLE_CONTENT_BUCKETS.has(bucket):
		return "deterministic_seed"
	if bucket == "arenas" or bucket == "waves" or bucket == "rules" or bucket == "arena_events":
		return "deterministic_seed"
	return "exported_state"


func _qualified_content_id(manifest_id: StringName, local_id: String) -> String:
	return "%s/%s" % [String(manifest_id), local_id]


func _is_safe_identifier(text: String) -> bool:
	if text.is_empty() or text.contains("/") or text.contains("\\") or text.contains(".."):
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_symbol := code == 95 or code == 45 or code == 46
		if not (is_digit or is_upper or is_lower or is_symbol):
			return false
	return true


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
