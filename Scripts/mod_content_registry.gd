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
signal manifest_conflict(manifest_id: StringName, conflicting_id: StringName, reason: String)
signal mod_catalog_changed(snapshot: Dictionary)
signal mod_hook_registered(hook_id: StringName, entry_id: StringName, manifest_id: StringName, entry: Dictionary)
signal manifest_toggle_changed(manifest_id: StringName, enabled: bool)
signal mod_option_changed(manifest_id: StringName, option_id: StringName, value: Variant)
signal creator_report_exported(report_path: String)
signal creator_manifest_installed(manifest_id: StringName, manifest_path: String)

const MAX_SCHEMA_VERSION := 4
const DEFAULT_MANIFEST_FILE_NAME := "vector_anomaly_mod.json"
const DEFAULT_MOD_STATE_PATH := "user://mod_state.json"
const LEGACY_MANIFEST_FILE_NAMES := ["mod.json"]
const DEFAULT_EXTERNAL_MOD_ROOT_NAMES := ["mods", "Mods"]
const MAX_SCAN_DEPTH_LIMIT := 8
const CONTENT_BUCKETS := [
	"arenas",
	"levels",
	"level_packs",
	"waves",
	"upgrades",
	"rules",
	"powerups",
	"weapons",
	"enemies",
	"enemy_packs",
	"bosses",
	"boss_packs",
	"arena_events",
	"celestial_bodies",
	"physics_drops",
	"materials",
	"shader_packs",
	"shader_overrides",
	"texture_packs",
	"prefabs",
	"entities",
	"gamemodes",
	"campaigns",
	"biomes",
	"mission_packs",
	"wave_tables",
	"total_conversions",
	"expansion_packs",
	"calamity_mods",
	"npc_behaviors",
	"enemy_behaviors",
	"boss_rules",
	"projectile_profiles",
	"gravity_source_profiles",
	"planet_packs",
	"status_effects",
	"mechanics",
	"sfx",
	"music",
	"soundtrack_packs",
	"hud_badges",
	"ui_skins",
	"localization",
	"accessibility_profiles",
	"maps",
	"tools",
	"creator_tools",
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
	"shader",
	"material",
	"map",
	"pack",
	"manifest",
	"cover_art",
	"font",
	"data",
	"json",
	"localization",
]
const SCRIPT_CONTENT_BUCKETS := ["script_packs", "tools", "npc_behaviors"]
const HOOKABLE_CONTENT_BUCKETS := ["law_weaves", "anomaly_recipes", "challenge_cards"]
const LOCAL_ONLY_CONTENT_BUCKETS := ["mod_palettes", "creator_notes", "hud_badges", "sfx", "music", "soundtrack_packs", "shader_packs", "shader_overrides", "texture_packs", "ui_skins", "localization", "accessibility_profiles"]
const CREATOR_LEVEL_BUCKETS := ["arenas", "levels", "level_packs", "maps", "campaigns", "biomes", "mission_packs", "wave_tables"]
const CREATOR_ENTITY_BUCKETS := ["enemies", "enemy_packs", "enemy_behaviors", "bosses", "boss_packs", "boss_rules", "entities", "prefabs", "projectile_profiles", "gravity_source_profiles", "planet_packs"]
const CREATOR_EXPANSION_BUCKETS := ["total_conversions", "expansion_packs", "calamity_mods", "gamemodes", "rules", "waves", "upgrades", "powerups", "mechanics", "status_effects"]
const WEAPON_FIRE_MODES := ["catalog", "projectile", "beam"]
const NETWORK_CATEGORIES := ["local_visual", "exported_state", "reliable_event", "deterministic_seed"]
const MOD_OPTION_TYPES := ["bool", "int", "float", "string", "choice", "color"]
const MOD_OPTION_OPERATORS := ["equals", "not_equals", "greater_than", "greater_or_equal", "less_than", "less_or_equal"]
const WEAPON_PATTERN_MODES := ["single", "spread", "parallel", "braid", "helix", "ring", "converge", "scissor", "pinwheel"]
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
	"level_loaded",
	"arena_loaded",
	"enemy_spawned",
	"enemy_defeated",
	"mod_pack_enabled",
	"shader_pack_applied",
	"powerup_collected",
	"weapon_changed",
	"player_hit",
	"black_hole_consumed",
	"planet_fractured",
	"level_completed",
	"mod_pack_disabled",
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
	"request_level_transition",
	"offer_level",
	"spawn_enemy_profile",
	"spawn_boss_profile",
	"apply_shader_pack",
	"apply_texture_pack",
	"set_arena_law",
	"queue_mod_story_event",
	"offer_upgrade",
	"set_gravity_profile",
	"apply_status_effect",
	"request_boss_rule",
	"request_wave_table",
	"apply_ui_skin",
	"request_localization",
	"set_level_flag",
]
const LOCAL_VISUAL_EFFECT_ACTIONS := ["emit_hud_badge", "play_sfx", "request_music_layer", "apply_shader_pack", "apply_texture_pack", "apply_ui_skin", "request_localization"]
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
	"level_tag",
	"mod_loaded",
	"content_tag",
	"player_speed_above",
	"projectile_pressure_at_least",
	"enemy_count_at_least",
	"near_gravity_source",
	"black_hole_active",
	"accessibility_mode",
	"mod_option",
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
@export var load_executable_adjacent_mods: bool = true
@export var load_additional_mod_roots: bool = true
@export var allow_relative_asset_paths: bool = true
@export_range(1, 8, 1) var recursive_scan_depth: int = 4
@export var allow_script_pack_registration: bool = false
@export var res_mod_root: String = "res://Mods"
@export var user_mod_root: String = "user://mods"
@export var persist_mod_toggles: bool = true
@export var mod_state_path: String = DEFAULT_MOD_STATE_PATH
@export var manifest_file_name: String = DEFAULT_MANIFEST_FILE_NAME
@export var alternate_manifest_file_names: Array[String] = ["mod.json"]
@export var executable_mod_root_names: Array[String] = ["mods", "Mods"]
@export var additional_mod_roots: Array[String] = []

var _manifests: Dictionary = {}
var _failed_manifests: Dictionary = {}
var _dependency_warnings: Dictionary = {}
var _conflict_warnings: Dictionary = {}
var _disabled_manifests: Dictionary = {}
var _content: Dictionary = {}
var _content_index: Dictionary = {}
var _hook_index: Dictionary = {}
var _load_order: Array[StringName] = []
var _scan_roots: Array[Dictionary] = []
var _loaded_manifest_paths: Dictionary = {}
var _user_disabled_manifests: Dictionary = {}
var _mod_option_values: Dictionary = {}


func _ready() -> void:
	add_to_group("mod_content_registry")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_reset_content_buckets()
	call_deferred("reload_registry")


func reload_registry() -> void:
	if persist_mod_toggles:
		_load_mod_toggle_state()

	_manifests.clear()
	_failed_manifests.clear()
	_dependency_warnings.clear()
	_conflict_warnings.clear()
	_disabled_manifests.clear()
	_content_index.clear()
	_hook_index.clear()
	_load_order.clear()
	_scan_roots.clear()
	_loaded_manifest_paths.clear()
	_reset_content_buckets()

	if enabled:
		_scan_configured_mod_roots()

	_resolve_manifest_load_order()
	_resolve_dependency_warnings()
	_resolve_manifest_conflicts()
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
		"conflict_warnings": _conflict_warnings.size(),
		"disabled": _disabled_manifests.size(),
		"user_disabled": _loaded_user_disabled_count(),
		"content_total": _content_index.size(),
		"hook_count": _hook_index.size(),
		"hook_entry_count": _hook_entry_count(),
		"load_order": _load_order.duplicate(),
		"scan_roots": get_scan_roots(),
		"install_paths": get_mod_install_paths(),
	}
	for bucket in CONTENT_BUCKETS:
		summary[bucket] = (_content[bucket] as Dictionary).size()
	return summary


func get_registry_snapshot() -> Dictionary:
	return {
		"manifests": _manifests.duplicate(true),
		"failed_manifests": _failed_manifests.duplicate(true),
		"dependency_warnings": _dependency_warnings.duplicate(true),
		"conflict_warnings": _conflict_warnings.duplicate(true),
		"disabled_manifests": _disabled_manifests.duplicate(true),
		"user_disabled_manifests": _user_disabled_manifests.duplicate(true),
		"content": _content.duplicate(true),
		"content_index": _content_index.duplicate(true),
		"hook_index": _hook_index.duplicate(true),
		"load_order": _load_order.duplicate(),
		"scan_roots": get_scan_roots(),
		"install_paths": get_mod_install_paths(),
		"buckets": CONTENT_BUCKETS.duplicate(),
		"capabilities": get_modding_capabilities(),
		"mod_option_values": _mod_option_values.duplicate(true),
		"dependency_graph": get_manifest_dependency_graph(),
	}


func validate_manifest_text(json_text: String, source_path: String = "memory://vector_anomaly_mod.json") -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(json_text)
	if parse_error != OK:
		return {
			"valid": false,
			"manifest_id": "",
			"errors": ["JSON line %d: %s" % [parser.get_error_line(), parser.get_error_message()]],
			"source_path": source_path,
		}
	var parsed: Variant = parser.data
	if not (parsed is Dictionary):
		return {"valid": false, "manifest_id": "", "errors": ["Manifest root must be an object."], "source_path": source_path}
	var manifest := parsed as Dictionary
	var context := _manifest_context(source_path, {"source_kind": "creator_validation"})
	var errors := _validate_manifest(manifest, context)
	return {
		"valid": errors.is_empty(),
		"manifest_id": str(manifest.get("id", "")),
		"schema_version": int(manifest.get("schema_version", 1)),
		"errors": errors,
		"source_path": source_path,
	}


func validate_manifest_file(source_path: String) -> Dictionary:
	var clean_path := _normalize_path_text(source_path)
	if clean_path.is_empty() or not FileAccess.file_exists(clean_path):
		return {"valid": false, "manifest_id": "", "errors": ["Manifest file was not found."], "source_path": clean_path}
	var file := FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return {"valid": false, "manifest_id": "", "errors": ["Manifest file could not be opened."], "source_path": clean_path}
	var json_text := file.get_as_text()
	file.close()
	return validate_manifest_text(json_text, clean_path)


func install_manifest_text(json_text: String, overwrite: bool = false) -> Dictionary:
	var validation := validate_manifest_text(json_text)
	if not bool(validation.get("valid", false)):
		return {
			"installed": false,
			"manifest_id": str(validation.get("manifest_id", "")),
			"errors": validation.get("errors", []),
			"path": "",
		}
	var parser := JSON.new()
	if parser.parse(json_text) != OK or not (parser.data is Dictionary):
		return {"installed": false, "manifest_id": "", "errors": ["Manifest could not be normalized."], "path": ""}
	var manifest := parser.data as Dictionary
	var manifest_id := str(manifest.get("id", "")).strip_edges()
	if not _is_safe_identifier(manifest_id):
		return {"installed": false, "manifest_id": manifest_id, "errors": ["Manifest id is not safe for an install folder."], "path": ""}
	var install_dir := _join_path(user_mod_root, manifest_id)
	var install_path := _join_path(install_dir, DEFAULT_MANIFEST_FILE_NAME)
	if FileAccess.file_exists(install_path) and not overwrite:
		return {
			"installed": false,
			"manifest_id": manifest_id,
			"errors": ["A manifest with this id already exists in user mods."],
			"path": ProjectSettings.globalize_path(install_path),
		}
	_ensure_mod_root(install_dir)
	var file := FileAccess.open(install_path, FileAccess.WRITE)
	if file == null:
		return {"installed": false, "manifest_id": manifest_id, "errors": ["The manifest could not be written to user mods."], "path": ""}
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	creator_manifest_installed.emit(StringName(manifest_id), install_path)
	reload_registry()
	return {
		"installed": true,
		"manifest_id": manifest_id,
		"errors": [],
		"path": ProjectSettings.globalize_path(install_path),
	}


func export_creator_report(report_path: String = "user://mod_creator_report.json") -> String:
	var clean_path := _normalize_path_text(report_path)
	if clean_path.is_empty():
		return ""
	var parent_dir := clean_path.get_base_dir()
	if not parent_dir.is_empty() and parent_dir != ".":
		_ensure_mod_root(parent_dir)
	var report := {
		"format": "vector_anomaly_mod_creator_report",
		"schema_version": MAX_SCHEMA_VERSION,
		"generated_unix_time": int(Time.get_unix_time_from_system()),
		"summary": get_registry_summary(),
		"manifests": _manifests.duplicate(true),
		"failed_manifests": _failed_manifests.duplicate(true),
		"dependency_warnings": _dependency_warnings.duplicate(true),
		"conflict_warnings": _conflict_warnings.duplicate(true),
		"disabled_manifests": _disabled_manifests.duplicate(true),
		"mod_option_values": _mod_option_values.duplicate(true),
		"dependency_graph": get_manifest_dependency_graph(),
		"compatibility_signature": get_compatibility_signature(),
		"capabilities": get_modding_capabilities(),
		"install_paths": get_mod_install_paths(),
	}
	var file := FileAccess.open(clean_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	creator_report_exported.emit(clean_path)
	return ProjectSettings.globalize_path(clean_path)


func get_content_buckets() -> Array:
	return CONTENT_BUCKETS.duplicate()


func get_entries(content_type: StringName) -> Array:
	var key := str(content_type)
	if not _content.has(key):
		return []
	return (_content[key] as Dictionary).values()


func get_level_entries() -> Array:
	return _entries_for_buckets(CREATOR_LEVEL_BUCKETS)


func get_enemy_pack_entries() -> Array:
	return _entries_for_buckets(CREATOR_ENTITY_BUCKETS)


func get_shader_pack_entries() -> Array:
	return _entries_for_buckets(["shader_packs", "shader_overrides", "texture_packs", "ui_skins"])


func get_total_conversion_entries() -> Array:
	return _entries_for_buckets(["total_conversions", "expansion_packs", "calamity_mods"])


func get_entries_for_creator_surface(surface: StringName) -> Array:
	match str(surface):
		"levels", "maps", "campaigns":
			return get_level_entries()
		"enemies", "bosses", "entities":
			return get_enemy_pack_entries()
		"shader_packs", "visuals":
			return get_shader_pack_entries()
		"total_conversions", "expansions", "calamity":
			return get_total_conversion_entries()
		"creator_tools", "tools":
			return _entries_for_buckets(["tools", "creator_tools"])
	return []


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
	var hook_key := str(hook_id)
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
	var tag_text := str(tag)
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
		"mod_option_types": MOD_OPTION_TYPES.duplicate(),
		"mod_option_operators": MOD_OPTION_OPERATORS.duplicate(),
		"script_buckets": SCRIPT_CONTENT_BUCKETS.duplicate(),
		"creator_surfaces": {
			"levels": CREATOR_LEVEL_BUCKETS.duplicate(),
			"entities": CREATOR_ENTITY_BUCKETS.duplicate(),
			"expansions": CREATOR_EXPANSION_BUCKETS.duplicate(),
			"shader_packs": ["shader_packs", "shader_overrides", "texture_packs", "ui_skins"],
			"calamity_style_mods": ["total_conversions", "expansion_packs", "calamity_mods", "campaigns", "boss_packs", "enemy_packs", "boss_rules", "mechanics"],
			"creator_tools": ["tools", "creator_tools", "script_packs"],
		},
		"script_pack_registration_enabled": allow_script_pack_registration,
		"safe_data_only": true,
		"manifest_files": _manifest_file_names(),
		"scan_roots": get_scan_roots(),
		"install_paths": get_mod_install_paths(),
		"relative_asset_paths": allow_relative_asset_paths,
		"recursive_scan_depth": clampi(recursive_scan_depth, 1, MAX_SCAN_DEPTH_LIMIT),
		"persistent_toggles": persist_mod_toggles,
		"toggle_state_path": _display_path(mod_state_path),
		"deterministic_load_order": true,
		"dependency_version_bounds": true,
		"manifest_conflicts": true,
		"typed_creator_options": true,
		"creator_sandbox_install": true,
	}


func _entries_for_buckets(buckets: Array) -> Array:
	var entries := []
	for bucket_value in buckets:
		var bucket := str(bucket_value)
		if not _content.has(bucket):
			continue
		for entry_value in (_content[bucket] as Dictionary).values():
			if entry_value is Dictionary:
				var entry := (entry_value as Dictionary)
				if bool(entry.get("enabled", true)):
					entries.append(entry.duplicate(true))
	return entries


func _hook_entry_count() -> int:
	var total := 0
	for entries_value in _hook_index.values():
		if entries_value is Array:
			total += (entries_value as Array).size()
	return total


func _loaded_user_disabled_count() -> int:
	var total := 0
	for key in _user_disabled_manifests.keys():
		if _manifests.has(str(key)):
			total += 1
	return total


func get_content(content_type: StringName) -> Array:
	return get_entries(content_type)


func get_entry(content_type: StringName, entry_id: StringName) -> Dictionary:
	var key := str(content_type)
	if not _content.has(key):
		return {}
	var entries := _content[key] as Dictionary
	var id_text := str(entry_id)
	var entry: Variant = entries.get(id_text, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)

	var indexed_key := "%s:%s" % [key, id_text]
	if _content_index.has(indexed_key):
		var qualified_id := str(_content_index[indexed_key])
		entry = entries.get(qualified_id, {})
		if entry is Dictionary:
			return (entry as Dictionary).duplicate(true)
	return {}


func get_content_entry(content_type: StringName, entry_id: StringName) -> Dictionary:
	return get_entry(content_type, entry_id)


func has_content(content_type: StringName, entry_id: StringName) -> bool:
	return not get_entry(content_type, entry_id).is_empty()


func get_manifest(manifest_id: StringName) -> Dictionary:
	var manifest: Variant = _manifests.get(str(manifest_id), {})
	if manifest is Dictionary:
		return (manifest as Dictionary).duplicate(true)
	return {}


func get_manifest_load_order() -> Array[StringName]:
	return _load_order.duplicate()


func get_manifest_dependency_graph() -> Dictionary:
	var nodes: Dictionary = {}
	var edges: Array = []
	var conflicts: Array = []
	for manifest_id in _load_order:
		var manifest_key := str(manifest_id)
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		var load_after_value: Variant = manifest.get("load_after", [])
		var load_before_value: Variant = manifest.get("load_before", [])
		var load_after: Array = (load_after_value as Array).duplicate() if load_after_value is Array else []
		var load_before: Array = (load_before_value as Array).duplicate() if load_before_value is Array else []
		nodes[manifest_key] = {
			"version": str(manifest.get("version", "1")),
			"enabled": bool(manifest.get("enabled", true)),
			"disabled_reason": str(manifest.get("disabled_reason", "")),
			"load_after": load_after,
			"load_before": load_before,
		}
		for dependency_value in manifest.get("dependencies", []):
			if dependency_value is Dictionary:
				var dependency := dependency_value as Dictionary
				edges.append({
					"from": manifest_key,
					"to": str(dependency.get("id", "")),
					"required": bool(dependency.get("required", true)),
					"min_version": str(dependency.get("min_version", "")),
					"max_version": str(dependency.get("max_version", "")),
				})
		for conflict_value in manifest.get("conflicts", []):
			if conflict_value is Dictionary:
				conflicts.append({
					"from": manifest_key,
					"to": str((conflict_value as Dictionary).get("id", "")),
					"reason": str((conflict_value as Dictionary).get("reason", "declared incompatible")),
				})
	return {
		"load_order": _load_order.duplicate(),
		"nodes": nodes,
		"dependency_edges": edges,
		"conflict_edges": conflicts,
	}


func get_user_disabled_manifests() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _user_disabled_manifests.keys():
		ids.append(StringName(str(key)))
	ids.sort()
	return ids


func is_manifest_user_disabled(manifest_id: StringName) -> bool:
	return _user_disabled_manifests.has(str(manifest_id))


func is_manifest_enabled(manifest_id: StringName) -> bool:
	var manifest := get_manifest(manifest_id)
	return not manifest.is_empty() and bool(manifest.get("enabled", true))


func set_manifest_user_enabled(manifest_id: StringName, enabled_state: bool) -> bool:
	var manifest_key := str(manifest_id).strip_edges()
	if manifest_key.is_empty():
		return false
	var new_disabled := not enabled_state
	var was_disabled := _user_disabled_manifests.has(manifest_key)
	if was_disabled == new_disabled:
		return false
	if new_disabled:
		_user_disabled_manifests[manifest_key] = true
	else:
		_user_disabled_manifests.erase(manifest_key)
	if persist_mod_toggles:
		_save_mod_toggle_state()
	reload_registry()
	manifest_toggle_changed.emit(StringName(manifest_key), enabled_state)
	return true


func set_manifest_enabled(manifest_id: StringName, enabled_state: bool) -> bool:
	return set_manifest_user_enabled(manifest_id, enabled_state)


func toggle_manifest_user_enabled(manifest_id: StringName) -> bool:
	var next_enabled := _user_disabled_manifests.has(str(manifest_id))
	set_manifest_user_enabled(manifest_id, next_enabled)
	return next_enabled


func toggle_manifest_enabled(manifest_id: StringName) -> bool:
	return toggle_manifest_user_enabled(manifest_id)


func get_dependency_warnings() -> Dictionary:
	return _dependency_warnings.duplicate(true)


func get_conflict_warnings() -> Dictionary:
	return _conflict_warnings.duplicate(true)


func get_manifest_options(manifest_id: StringName) -> Array:
	var manifest := get_manifest(manifest_id)
	var options_value: Variant = manifest.get("options", [])
	if not (options_value is Array):
		return []
	var options: Array = []
	for option_value in options_value as Array:
		if not (option_value is Dictionary):
			continue
		var option := (option_value as Dictionary).duplicate(true)
		option["value"] = get_mod_option(manifest_id, StringName(str(option.get("id", ""))), option.get("default"))
		options.append(option)
	return options


func get_mod_option(manifest_id: StringName, option_id: StringName, fallback: Variant = null) -> Variant:
	var manifest_key := str(manifest_id)
	var option_key := str(option_id)
	var values_value: Variant = _mod_option_values.get(manifest_key, {})
	if values_value is Dictionary and (values_value as Dictionary).has(option_key):
		var persisted_value: Variant = (values_value as Dictionary).get(option_key)
		var persisted_option := _find_manifest_option(manifest_id, option_id)
		if not persisted_option.is_empty():
			var normalized_persisted: Variant = _normalize_option_value(persisted_option, persisted_value)
			if normalized_persisted != null:
				return normalized_persisted
	var manifest := get_manifest(manifest_id)
	var options_value: Variant = manifest.get("options", [])
	if options_value is Array:
		for option_value in options_value as Array:
			if option_value is Dictionary and str((option_value as Dictionary).get("id", "")) == option_key:
				return (option_value as Dictionary).get("default", fallback)
	return fallback


func set_mod_option(manifest_id: StringName, option_id: StringName, value: Variant) -> bool:
	var manifest_key := str(manifest_id)
	var option_key := str(option_id)
	var option := _find_manifest_option(manifest_id, option_id)
	if option.is_empty():
		return false
	var normalized: Variant = _normalize_option_value(option, value)
	if normalized == null:
		return false
	var values_value: Variant = _mod_option_values.get(manifest_key, {})
	var values: Dictionary = values_value.duplicate(true) if values_value is Dictionary else {}
	if values.get(option_key, option.get("default")) == normalized:
		return false
	values[option_key] = normalized
	_mod_option_values[manifest_key] = values
	if persist_mod_toggles:
		_save_mod_toggle_state()
	mod_option_changed.emit(manifest_id, option_id, normalized)
	mod_catalog_changed.emit(get_registry_snapshot())
	return true


func reset_manifest_options(manifest_id: StringName) -> bool:
	var manifest_key := str(manifest_id)
	if not _mod_option_values.has(manifest_key):
		return false
	_mod_option_values.erase(manifest_key)
	if persist_mod_toggles:
		_save_mod_toggle_state()
	mod_catalog_changed.emit(get_registry_snapshot())
	return true


func get_entries_by_network_category(network_category: StringName) -> Array:
	var category := str(network_category)
	if not NETWORK_CATEGORIES.has(category):
		return []
	var matches: Array = []
	for bucket in CONTENT_BUCKETS:
		for entry_value in (_content[bucket] as Dictionary).values():
			if not (entry_value is Dictionary):
				continue
			var entry := entry_value as Dictionary
			if bool(entry.get("enabled", true)) and str(entry.get("network_category", _default_network_category(bucket))) == category:
				matches.append(entry.duplicate(true))
	return matches


func get_scan_roots() -> Array:
	var roots := []
	for root_value in _scan_roots:
		roots.append(root_value.duplicate(true))
	return roots


func get_mod_install_paths() -> Dictionary:
	var executable_root := _executable_base_dir()
	return {
		"platform": OS.get_name(),
		"user_mods": ProjectSettings.globalize_path(user_mod_root),
		"bundled_mods": res_mod_root,
		"executable_mods": _join_path(executable_root, "mods") if not executable_root.is_empty() else "",
		"manifest_files": _manifest_file_names(),
		"toggle_state": _display_path(mod_state_path),
		"external_roots_enabled": load_executable_adjacent_mods,
		"relative_paths_enabled": allow_relative_asset_paths,
	}


func resolve_entry_path(entry: Dictionary, field: String) -> String:
	if not entry.has(field):
		return ""
	var value: Variant = entry.get(field)
	if not (value is String):
		return ""
	return resolve_mod_path(str(value), entry)


func resolve_mod_path(raw_path: String, context_value: Variant = {}) -> String:
	return _resolve_manifest_path(raw_path, _context_from_value(context_value))


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
			var network_category := str(entry.get("network_category", _default_network_category(bucket)))
			if network_category == "local_visual":
				continue
			gameplay_manifest_keys[str(entry.get("manifest_id", ""))] = true
			content_tokens.append(_content_signature_token(bucket, str(qualified_id), entry))
	for manifest_id in _load_order:
		var manifest_key := str(manifest_id)
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		if manifest.is_empty() or not bool(manifest.get("enabled", true)):
			continue
		var gameplay_options: Array[String] = []
		for option_value in manifest.get("options", []):
			if not (option_value is Dictionary):
				continue
			var option := option_value as Dictionary
			if str(option.get("network_category", "local_visual")) == "local_visual":
				continue
			gameplay_manifest_keys[manifest_key] = true
			var option_id := str(option.get("id", ""))
			gameplay_options.append("%s=%s" % [option_id, _stable_value_text(get_mod_option(manifest_id, StringName(option_id), option.get("default")))])
		if not gameplay_manifest_keys.has(manifest_key):
			continue
		tokens.append("%s:%s:%d" % [
			manifest_key,
			str(manifest.get("version", "1")),
			int(manifest.get("schema_version", 1)),
		])
		gameplay_options.sort()
		for option_token in gameplay_options:
			tokens.append("option:%s:%s" % [manifest_key, option_token])
	for token in content_tokens:
		tokens.append(token)
	tokens.sort()
	var packed := PackedStringArray()
	var seen_tokens := {}
	for token in tokens:
		if seen_tokens.has(token):
			continue
		seen_tokens[token] = true
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
		str(entry.get("network_category", _default_network_category(bucket))),
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
		str(entry.get("fire_mode", "catalog")),
		str(entry.get("base_weapon_id", "")),
		str(entry.get("pattern", "single")),
		str(entry.get("shot_count", 1)),
		str(entry.get("spread_radians", 0.0)),
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


func _manifest_file_names() -> Array[String]:
	var names: Array[String] = []
	var primary := manifest_file_name.strip_edges()
	_append_unique_string(names, primary if not primary.is_empty() else DEFAULT_MANIFEST_FILE_NAME)
	for name in alternate_manifest_file_names:
		_append_unique_string(names, str(name).strip_edges())
	for name in LEGACY_MANIFEST_FILE_NAMES:
		_append_unique_string(names, str(name).strip_edges())
	return names


func _append_unique_string(values: Array[String], value: String) -> void:
	var clean := value.strip_edges()
	if clean.is_empty() or values.has(clean):
		return
	values.append(clean)


func _load_mod_toggle_state() -> void:
	_user_disabled_manifests.clear()
	_mod_option_values.clear()
	var clean_path := _normalize_path_text(mod_state_path)
	if clean_path.is_empty() or not FileAccess.file_exists(clean_path):
		return
	var file := FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var data := parsed as Dictionary
	var disabled_value: Variant = data.get("disabled_manifests", data.get("disabled", []))
	if disabled_value is Array:
		for value in (disabled_value as Array):
			_add_user_disabled_manifest_id(str(value))
	elif disabled_value is Dictionary:
		var disabled_map := disabled_value as Dictionary
		for key in disabled_map.keys():
			if bool(disabled_map.get(key, false)):
				_add_user_disabled_manifest_id(str(key))
	var option_values_value: Variant = data.get("mod_option_values", {})
	if option_values_value is Dictionary:
		for manifest_key_value in (option_values_value as Dictionary).keys():
			var manifest_key := str(manifest_key_value).strip_edges()
			var manifest_values: Variant = (option_values_value as Dictionary).get(manifest_key_value, {})
			if _is_safe_identifier(manifest_key) and manifest_values is Dictionary:
				_mod_option_values[manifest_key] = (manifest_values as Dictionary).duplicate(true)


func _save_mod_toggle_state() -> bool:
	var clean_path := _normalize_path_text(mod_state_path)
	if clean_path.is_empty():
		return false
	var parent_dir := clean_path.get_base_dir()
	if not parent_dir.is_empty() and parent_dir != ".":
		_ensure_mod_root(parent_dir)
	var ids: Array[String] = []
	for key in _user_disabled_manifests.keys():
		ids.append(str(key))
	ids.sort()
	var file := FileAccess.open(clean_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"version": 2,
		"disabled_manifests": ids,
		"mod_option_values": _mod_option_values,
	}, "\t"))
	file.close()
	return true


func _add_user_disabled_manifest_id(manifest_id: String) -> void:
	var clean_id := manifest_id.strip_edges()
	if clean_id.is_empty() or not _is_safe_identifier(clean_id):
		return
	_user_disabled_manifests[clean_id] = true


func _ensure_mod_root(root_path: String) -> void:
	var clean := _normalize_path_text(root_path)
	if clean.is_empty():
		return
	var filesystem_path := ProjectSettings.globalize_path(clean) if _is_virtual_path(clean) else clean
	if filesystem_path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(filesystem_path)


func _scan_root_context(root_path: String, source_kind: String) -> Dictionary:
	var clean := _normalize_path_text(root_path)
	if clean.is_empty():
		return {}
	return {
		"source_root": clean,
		"source_kind": source_kind,
		"display_path": _display_path(clean),
		"exists": DirAccess.open(clean) != null,
		"external_source": source_kind == "executable" or source_kind == "custom",
		"manifest_files": _manifest_file_names(),
		"recursive_depth": clampi(recursive_scan_depth, 1, MAX_SCAN_DEPTH_LIMIT),
	}


func _scan_root_has_path(root_path: String) -> bool:
	var root_key := _path_key(root_path)
	for value in _scan_roots:
		if _path_key(str(value.get("source_root", ""))) == root_key:
			return true
	return false


func _manifest_context(manifest_path: String, source_context: Dictionary) -> Dictionary:
	var context := source_context.duplicate(true)
	var manifest_dir := manifest_path.get_base_dir()
	context["source_path"] = manifest_path
	context["source_dir"] = manifest_dir
	if str(context.get("source_root", "")).is_empty():
		context["source_root"] = manifest_dir
	if str(context.get("source_kind", "")).is_empty():
		context["source_kind"] = _source_kind_for_path(manifest_path)
	context["display_path"] = _display_path(manifest_path)
	context["external_source"] = bool(context.get("external_source", not _is_virtual_path(manifest_path)))
	return context


func _validate_mod_path_text(path: String, location: String, errors: Array[String], _source_context: Dictionary = {}) -> void:
	var clean := _normalize_path_text(path)
	if clean.is_empty():
		return
	if _path_contains_parent_segment(clean):
		errors.append("%s must not contain .." % location)
	if _has_unsupported_scheme(clean):
		errors.append("%s must use res://, user://, or a manifest-relative path" % location)
	if _is_absolute_filesystem_path(clean):
		errors.append("%s must be relative to the manifest, res://, or user://" % location)
	if not allow_relative_asset_paths and not _is_virtual_path(clean):
		errors.append("%s must use res:// or user://" % location)


func _resolve_manifest_path(raw_path: String, source_context: Dictionary) -> String:
	var clean := _normalize_path_text(raw_path)
	if clean.is_empty() or _path_contains_parent_segment(clean) or _has_unsupported_scheme(clean):
		return ""
	if _is_virtual_path(clean) or _is_absolute_filesystem_path(clean):
		return clean
	var source_dir := str(source_context.get("source_dir", source_context.get("manifest_source_dir", ""))).strip_edges()
	if source_dir.is_empty():
		return clean
	return _join_path(source_dir, clean)


func _context_from_value(context_value: Variant) -> Dictionary:
	if context_value is Dictionary:
		var dictionary := context_value as Dictionary
		return {
			"source_path": str(dictionary.get("manifest_source_path", dictionary.get("source_path", ""))),
			"source_dir": str(dictionary.get("manifest_source_dir", dictionary.get("source_dir", dictionary.get("manifest_dir", "")))),
			"source_root": str(dictionary.get("manifest_source_root", dictionary.get("source_root", ""))),
			"source_kind": str(dictionary.get("manifest_source_kind", dictionary.get("source_kind", ""))),
			"display_path": str(dictionary.get("source_display_path", dictionary.get("display_path", ""))),
			"external_source": bool(dictionary.get("external_source", false)),
		}

	var manifest_id := str(context_value).strip_edges()
	if not manifest_id.is_empty():
		var manifest := get_manifest(StringName(manifest_id))
		if not manifest.is_empty():
			return _context_from_value(manifest)
	return {}


func _normalize_path_text(path: String) -> String:
	var clean := path.strip_edges().replace("\\", "/")
	while clean.ends_with("/") and clean.length() > 1 and not clean.ends_with("://"):
		clean = clean.trim_suffix("/")
	return clean


func _path_key(path: String) -> String:
	var clean := _normalize_path_text(path)
	var os_name := OS.get_name().to_lower()
	return clean.to_lower() if os_name == "windows" or os_name == "macos" else clean


func _join_path(base_path: String, child_path: String) -> String:
	var clean_child := _normalize_path_text(child_path)
	if clean_child.is_empty():
		return _normalize_path_text(base_path)
	if _is_virtual_path(clean_child) or _is_absolute_filesystem_path(clean_child):
		return clean_child
	var clean_base := _normalize_path_text(base_path)
	if clean_base.is_empty():
		return clean_child
	return "%s/%s" % [clean_base, clean_child.trim_prefix("/")]


func _display_path(path: String) -> String:
	var clean := _normalize_path_text(path)
	if clean.begins_with("user://"):
		return ProjectSettings.globalize_path(clean)
	return clean


func _source_kind_for_path(path: String) -> String:
	if path.begins_with("res://"):
		return "bundled"
	if path.begins_with("user://"):
		return "user"
	return "external"


func _executable_base_dir() -> String:
	if OS.has_feature("editor"):
		return ""
	var executable_path := _normalize_path_text(OS.get_executable_path())
	if executable_path.is_empty():
		return ""
	return executable_path.get_base_dir()


func _is_virtual_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")


func _has_unsupported_scheme(path: String) -> bool:
	var scheme_index := path.find("://")
	if scheme_index < 0:
		return false
	return not _is_virtual_path(path)


func _is_absolute_filesystem_path(path: String) -> bool:
	var clean := _normalize_path_text(path)
	return clean.begins_with("/") or clean.begins_with("//") or _looks_like_windows_drive_path(clean)


func _looks_like_windows_drive_path(path: String) -> bool:
	return path.length() >= 2 and path.substr(1, 1) == ":"


func _path_contains_parent_segment(path: String) -> bool:
	var clean := _normalize_path_text(path)
	for segment in clean.split("/"):
		if segment == "..":
			return true
	return false


func _scan_configured_mod_roots() -> void:
	if load_res_mods:
		_scan_mod_root(res_mod_root, "bundled")
	if load_user_mods:
		_ensure_mod_root(user_mod_root)
		_scan_mod_root(user_mod_root, "user")
	if load_executable_adjacent_mods:
		var executable_root := _executable_base_dir()
		if not executable_root.is_empty():
			for root_name in executable_mod_root_names:
				var clean_name := str(root_name).strip_edges()
				if clean_name.is_empty():
					continue
				_scan_mod_root(_join_path(executable_root, clean_name), "executable")
	if load_additional_mod_roots:
		for root_path in additional_mod_roots:
			var clean_path := str(root_path).strip_edges()
			if clean_path.is_empty():
				continue
			_scan_mod_root(clean_path, "custom")


func _scan_mod_root(root_path: String, source_kind: String = "custom") -> void:
	var scan_root := _scan_root_context(root_path, source_kind)
	if scan_root.is_empty():
		return
	if _scan_root_has_path(str(scan_root.get("source_root", ""))):
		return
	var scan_index := _scan_roots.size()
	_scan_roots.append(scan_root.duplicate(true))

	var dir := DirAccess.open(str(scan_root.get("source_root", "")))
	if dir == null:
		scan_root["exists"] = false
		_scan_roots[scan_index] = scan_root
		return
	scan_root["exists"] = true
	_scan_roots[scan_index] = scan_root
	_scan_directory_for_manifests(str(scan_root.get("source_root", "")), scan_root, 0)


func _scan_directory_for_manifests(directory_path: String, source_context: Dictionary, depth: int) -> void:
	if depth > clampi(recursive_scan_depth, 1, MAX_SCAN_DEPTH_LIMIT):
		return
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return

	var names := _manifest_file_names()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var child_path := _join_path(directory_path, entry)
		if dir.current_is_dir():
			_scan_directory_for_manifests(child_path, source_context, depth + 1)
		elif names.has(entry):
			_load_manifest_path(child_path, source_context)
		entry = dir.get_next()
	dir.list_dir_end()


func _load_manifest_path(path: String, source_context: Dictionary = {}) -> void:
	var manifest_path := _normalize_path_text(path)
	if manifest_path.is_empty():
		return
	var path_key := _path_key(manifest_path)
	if _loaded_manifest_paths.has(path_key):
		return
	_loaded_manifest_paths[path_key] = true
	if not FileAccess.file_exists(manifest_path):
		return
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		_record_failed_manifest(manifest_path, "cannot_open")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_record_failed_manifest(manifest_path, "invalid_json")
		return

	var manifest := parsed as Dictionary
	var manifest_context := _manifest_context(manifest_path, source_context)
	var validation_errors := _validate_manifest(manifest, manifest_context)
	if not validation_errors.is_empty():
		var reason := _join_errors(validation_errors)
		_record_failed_manifest(manifest_path, reason)
		return

	var manifest_id := StringName(str(manifest.get("id", "")))
	var manifest_key := str(manifest_id)
	if _manifests.has(manifest_key):
		_record_failed_manifest(manifest_path, "duplicate manifest id %s" % manifest_key)
		return

	var metadata := {
		"id": manifest_id,
		"display_name": str(manifest.get("display_name", manifest_id)),
		"version": str(manifest.get("version", "1")),
		"schema_version": int(manifest.get("schema_version", 1)),
		"author": str(manifest.get("author", "")),
		"description": str(manifest.get("description", "")),
		"source_path": manifest_path,
		"source_dir": str(manifest_context.get("source_dir", "")),
		"source_root": str(manifest_context.get("source_root", "")),
		"source_kind": str(manifest_context.get("source_kind", "custom")),
		"source_display_path": str(manifest_context.get("display_path", manifest_path)),
		"manifest_file": manifest_path.get_file(),
		"external_source": bool(manifest_context.get("external_source", false)),
		"tags": _string_array(manifest.get("tags", [])),
		"dependencies": _dependency_array(manifest.get("dependencies", [])),
		"conflicts": _conflict_array(manifest.get("conflicts", [])),
		"load_after": _string_array(manifest.get("load_after", [])),
		"load_before": _string_array(manifest.get("load_before", [])),
		"options": _normalize_manifest_options(manifest.get("options", [])),
		"enabled": true,
		"user_enabled": true,
		"user_disabled": false,
	}
	_manifests[manifest_key] = metadata
	_load_order.append(manifest_id)

	for bucket in CONTENT_BUCKETS:
		_register_content_array(manifest, manifest_id, bucket)

	manifest_validated.emit(manifest_id, manifest_path)
	manifest_loaded.emit(manifest_id, manifest_path)


func _validate_manifest(manifest: Dictionary, source_context: Dictionary = {}) -> Array[String]:
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
	var conflicts: Variant = manifest.get("conflicts", [])
	if not (conflicts is Array):
		errors.append("conflicts must be an array")
	else:
		_validate_conflicts(conflicts as Array, errors)
	if dependencies is Array and conflicts is Array:
		_validate_manifest_relationships(manifest_id, dependencies as Array, conflicts as Array, errors)
	for ordering_field in ["load_after", "load_before"]:
		var ordering_value: Variant = manifest.get(ordering_field, [])
		if not (ordering_value is Array):
			errors.append("%s must be an array" % ordering_field)
			continue
		for ordering_index in range((ordering_value as Array).size()):
			var ordering_id := str((ordering_value as Array)[ordering_index]).strip_edges()
			if ordering_id.is_empty() or not _is_safe_identifier(ordering_id) or ordering_id == manifest_id:
				errors.append("%s[%d] must be a different safe mod id" % [ordering_field, ordering_index])
	var options: Variant = manifest.get("options", [])
	if not (options is Array):
		errors.append("options must be an array")
	else:
		_validate_manifest_options(options as Array, errors)

	var content_value: Variant = manifest.get("content", {})
	if content_value != null and not (content_value is Dictionary):
		errors.append("content must be an object")

	for bucket in CONTENT_BUCKETS:
		var entries_value: Variant = _manifest_bucket_entries(manifest, bucket)
		if entries_value == null or not (entries_value is Array):
			errors.append("%s must be an array" % bucket)
			continue
		var entries := entries_value as Array
		_validate_entry_array(entries, bucket, errors, source_context)
	return errors


func _validate_dependencies(entries: Array, errors: Array[String]) -> void:
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		if entry is String:
			var string_id := str(entry).strip_edges()
			if string_id.is_empty():
				errors.append("dependencies[%d] missing id" % index)
			elif not _is_safe_identifier(string_id):
				errors.append("dependencies[%d] contains unsafe characters" % index)
			continue
		if not (entry is Dictionary):
			errors.append("dependencies[%d] must be a string or object" % index)
			continue
		var dependency := entry as Dictionary
		var dependency_id := str(dependency.get("id", "")).strip_edges()
		if dependency_id.is_empty():
			errors.append("dependencies[%d] missing id" % index)
		elif not _is_safe_identifier(dependency_id):
			errors.append("dependencies[%d].id contains unsafe characters" % index)
		for version_field in ["min_version", "max_version"]:
			if dependency.has(version_field) and str(dependency.get(version_field, "")).strip_edges().is_empty():
				errors.append("dependencies[%d].%s must not be empty" % [index, version_field])
		var min_version := str(dependency.get("min_version", "")).strip_edges()
		var max_version := str(dependency.get("max_version", "")).strip_edges()
		if not min_version.is_empty() and not max_version.is_empty() and _compare_versions(min_version, max_version) > 0:
			errors.append("dependencies[%d] min_version must not exceed max_version" % index)


func _validate_conflicts(entries: Array, errors: Array[String]) -> void:
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		var conflict_id := str(entry).strip_edges() if entry is String else ""
		if entry is Dictionary:
			conflict_id = str((entry as Dictionary).get("id", "")).strip_edges()
		elif not (entry is String):
			errors.append("conflicts[%d] must be a string or object" % index)
			continue
		if conflict_id.is_empty() or not _is_safe_identifier(conflict_id):
			errors.append("conflicts[%d] must contain a safe mod id" % index)


func _validate_manifest_relationships(manifest_id: String, dependencies: Array, conflicts: Array, errors: Array[String]) -> void:
	var dependency_ids := {}
	for dependency_value in dependencies:
		var dependency_id := str(dependency_value).strip_edges() if dependency_value is String else ""
		if dependency_value is Dictionary:
			dependency_id = str((dependency_value as Dictionary).get("id", "")).strip_edges()
		if dependency_id.is_empty():
			continue
		if dependency_id == manifest_id:
			errors.append("manifest cannot depend on itself")
		if dependency_ids.has(dependency_id):
			errors.append("dependency %s is duplicated" % dependency_id)
		dependency_ids[dependency_id] = true
	var conflict_ids := {}
	for conflict_value in conflicts:
		var conflict_id := str(conflict_value).strip_edges() if conflict_value is String else ""
		if conflict_value is Dictionary:
			conflict_id = str((conflict_value as Dictionary).get("id", "")).strip_edges()
		if conflict_id.is_empty():
			continue
		if conflict_id == manifest_id:
			errors.append("manifest cannot conflict with itself")
		if conflict_ids.has(conflict_id):
			errors.append("conflict %s is duplicated" % conflict_id)
		if dependency_ids.has(conflict_id):
			errors.append("%s cannot be both a dependency and a conflict" % conflict_id)
		conflict_ids[conflict_id] = true


func _validate_manifest_options(options: Array, errors: Array[String]) -> void:
	var ids := {}
	for index in range(options.size()):
		var option_value: Variant = options[index]
		if not (option_value is Dictionary):
			errors.append("options[%d] must be an object" % index)
			continue
		var option := option_value as Dictionary
		var option_id := str(option.get("id", "")).strip_edges()
		var option_type := str(option.get("type", "bool")).strip_edges()
		if option_id.is_empty() or not _is_safe_identifier(option_id):
			errors.append("options[%d].id must be a safe identifier" % index)
		elif ids.has(option_id):
			errors.append("options[%d].id is duplicated" % index)
		ids[option_id] = true
		if not MOD_OPTION_TYPES.has(option_type):
			errors.append("options[%d].type is invalid" % index)
			continue
		var network_category := str(option.get("network_category", "local_visual"))
		if not NETWORK_CATEGORIES.has(network_category):
			errors.append("options[%d].network_category is invalid" % index)
		if not option.has("default"):
			errors.append("options[%d].default is required" % index)
			continue
		if _normalize_option_value(option, option.get("default")) == null:
			errors.append("options[%d].default does not match its type or bounds" % index)
		if option_type == "choice":
			var choices_value: Variant = option.get("choices", [])
			if not (choices_value is Array) or (choices_value as Array).is_empty():
				errors.append("options[%d].choices must be a non-empty array" % index)


func _validate_entry_array(entries: Array, key: String, errors: Array[String], source_context: Dictionary = {}) -> void:
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
		_validate_entry_paths(entry, key, index, errors, source_context)
		_validate_bucket_specific_entry(entry, key, index, errors, source_context)


func _validate_entry_paths(entry: Dictionary, key: String, index: int, errors: Array[String], source_context: Dictionary = {}) -> void:
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
		_validate_mod_path_text(path, "%s[%d].%s" % [key, index, field], errors, source_context)
		if field == "script" and not SCRIPT_CONTENT_BUCKETS.has(key):
			errors.append("%s[%d].script is only allowed in trusted script content buckets" % [key, index])


func _validate_bucket_specific_entry(entry: Dictionary, key: String, index: int, errors: Array[String], source_context: Dictionary = {}) -> void:
	if key == "weapons":
		_validate_weapon_entry(entry, index, errors)
		return
	if HOOKABLE_CONTENT_BUCKETS.has(key):
		_validate_hookable_entry(entry, key, index, errors, source_context)
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


func _validate_hookable_entry(entry: Dictionary, key: String, index: int, errors: Array[String], source_context: Dictionary = {}) -> void:
	_validate_network_category_field(entry, key, index, errors)
	_validate_hook_array(entry, key, index, errors)
	_validate_condition_array(entry, key, index, errors)
	_validate_effect_array(entry, key, index, errors, source_context)
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
		elif condition_type == "mod_option":
			var manifest_id := str(condition.get("manifest_id", condition.get("mod_id", ""))).strip_edges()
			var option_id := str(condition.get("option_id", condition.get("id", ""))).strip_edges()
			var operator := str(condition.get("operator", "equals"))
			if manifest_id.is_empty() or not _is_safe_identifier(manifest_id):
				errors.append("%s[%d].conditions[%d].manifest_id is required" % [key, index, condition_index])
			if option_id.is_empty() or not _is_safe_identifier(option_id):
				errors.append("%s[%d].conditions[%d].option_id is required" % [key, index, condition_index])
			if not MOD_OPTION_OPERATORS.has(operator):
				errors.append("%s[%d].conditions[%d].operator is invalid" % [key, index, condition_index])
		if condition.has("script"):
			errors.append("%s[%d].conditions[%d].script is not allowed" % [key, index, condition_index])


func _validate_effect_array(entry: Dictionary, key: String, index: int, errors: Array[String], source_context: Dictionary = {}) -> void:
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
		for field in PATH_FIELDS:
			if not effect.has(field):
				continue
			var path_value: Variant = effect.get(field)
			if path_value == null or str(path_value).is_empty():
				continue
			if not (path_value is String):
				errors.append("%s[%d].effects[%d].%s must be a string path" % [key, index, effect_index, field])
				continue
			_validate_mod_path_text(str(path_value), "%s[%d].effects[%d].%s" % [key, index, effect_index, field], errors, source_context)


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


func _resolved_path_map(entry: Dictionary, manifest_metadata: Dictionary) -> Dictionary:
	var paths := {}
	for field in PATH_FIELDS:
		if not entry.has(field):
			continue
		var value: Variant = entry.get(field)
		if value == null or not (value is String) or str(value).strip_edges().is_empty():
			continue
		var resolved := _resolve_manifest_path(str(value), manifest_metadata)
		if not resolved.is_empty():
			paths[field] = resolved
	return paths


func _resolved_effect_path_maps(entry: Dictionary, manifest_metadata: Dictionary) -> Array:
	var resolved_effects := []
	var effects_value: Variant = entry.get("effects", [])
	if not (effects_value is Array):
		return resolved_effects
	var effects := effects_value as Array
	for effect_index in range(effects.size()):
		var effect_value: Variant = effects[effect_index]
		if not (effect_value is Dictionary):
			continue
		var effect := effect_value as Dictionary
		var effect_paths := {}
		for field in PATH_FIELDS:
			if not effect.has(field):
				continue
			var value: Variant = effect.get(field)
			if value == null or not (value is String) or str(value).strip_edges().is_empty():
				continue
			var resolved := _resolve_manifest_path(str(value), manifest_metadata)
			if not resolved.is_empty():
				effect_paths[field] = resolved
		if not effect_paths.is_empty():
			effect_paths["effect_index"] = effect_index
			effect_paths["action"] = str(effect.get("action", ""))
			resolved_effects.append(effect_paths)
	return resolved_effects


func _register_content_array(manifest: Dictionary, manifest_id: StringName, key: String) -> void:
	var entries_value: Variant = _manifest_bucket_entries(manifest, key)
	if not (entries_value is Array):
		return
	var entries := entries_value as Array
	var manifest_metadata_value: Variant = _manifests.get(str(manifest_id), {})
	var manifest_metadata: Dictionary = manifest_metadata_value if manifest_metadata_value is Dictionary else {}
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
		entry["manifest_source_path"] = str(manifest_metadata.get("source_path", ""))
		entry["manifest_source_dir"] = str(manifest_metadata.get("source_dir", ""))
		entry["manifest_source_root"] = str(manifest_metadata.get("source_root", ""))
		entry["manifest_source_kind"] = str(manifest_metadata.get("source_kind", "custom"))
		entry["source_display_path"] = str(manifest_metadata.get("source_display_path", ""))
		entry["external_source"] = bool(manifest_metadata.get("external_source", false))
		entry["resolved_paths"] = _resolved_path_map(entry, manifest_metadata)
		if HOOKABLE_CONTENT_BUCKETS.has(key):
			entry["resolved_effect_paths"] = _resolved_effect_path_maps(entry, manifest_metadata)

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


func _resolve_manifest_load_order() -> void:
	if _load_order.size() < 2:
		return
	var original_index := {}
	var indegree := {}
	var edges := {}
	for index in range(_load_order.size()):
		var manifest_key := str(_load_order[index])
		original_index[manifest_key] = index
		indegree[manifest_key] = 0
		edges[manifest_key] = []
	for manifest_id in _load_order:
		var manifest_key := str(manifest_id)
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		for dependency_value in manifest.get("dependencies", []):
			if dependency_value is Dictionary:
				_add_load_order_edge(str((dependency_value as Dictionary).get("id", "")), manifest_key, edges, indegree)
		for after_id in manifest.get("load_after", []):
			_add_load_order_edge(str(after_id), manifest_key, edges, indegree)
		for before_id in manifest.get("load_before", []):
			_add_load_order_edge(manifest_key, str(before_id), edges, indegree)
	var ready: Array[String] = []
	for manifest_key in indegree.keys():
		if int(indegree[manifest_key]) == 0:
			ready.append(str(manifest_key))
	ready.sort_custom(func(a: String, b: String) -> bool: return int(original_index.get(a, 0)) < int(original_index.get(b, 0)))
	var ordered: Array[StringName] = []
	while not ready.is_empty():
		var manifest_key = ready.pop_front()
		ordered.append(StringName(manifest_key))
		for target_value in edges.get(manifest_key, []):
			var target := str(target_value)
			indegree[target] = int(indegree.get(target, 0)) - 1
			if int(indegree[target]) == 0:
				ready.append(target)
				ready.sort_custom(func(a: String, b: String) -> bool: return int(original_index.get(a, 0)) < int(original_index.get(b, 0)))
	if ordered.size() != _load_order.size():
		for manifest_id in _load_order:
			if not ordered.has(manifest_id):
				ordered.append(manifest_id)
				_add_dependency_warning(manifest_id, &"load_order", "load order cycle detected")
	_load_order = ordered


func _add_load_order_edge(source: String, target: String, edges: Dictionary, indegree: Dictionary) -> void:
	if source.is_empty() or target.is_empty() or source == target:
		return
	if not indegree.has(source) or not indegree.has(target):
		return
	var targets: Array = edges.get(source, [])
	if targets.has(target):
		return
	targets.append(target)
	edges[source] = targets
	indegree[target] = int(indegree.get(target, 0)) + 1


func _resolve_manifest_conflicts() -> void:
	for manifest_id in _load_order:
		var manifest_key := str(manifest_id)
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		for conflict_value in manifest.get("conflicts", []):
			if not (conflict_value is Dictionary):
				continue
			var conflict := conflict_value as Dictionary
			var conflicting_key := str(conflict.get("id", ""))
			if conflicting_key.is_empty() or not _manifests.has(conflicting_key):
				continue
			var reason := str(conflict.get("reason", "declared incompatible"))
			_add_conflict_warning(manifest_id, StringName(conflicting_key), reason)
			if _disabled_manifests.has(manifest_key) or _disabled_manifests.has(conflicting_key):
				continue
			if _user_disabled_manifests.has(manifest_key) or _user_disabled_manifests.has(conflicting_key):
				continue
			var manifest_index := _load_order.find(manifest_id)
			var conflicting_index := _load_order.find(StringName(conflicting_key))
			var disabled_key := manifest_key if manifest_index >= conflicting_index else conflicting_key
			if not _disabled_manifests.has(disabled_key):
				_disabled_manifests[disabled_key] = "conflicts with %s: %s" % [conflicting_key if disabled_key == manifest_key else manifest_key, reason]


func _resolve_dependency_warnings() -> void:
	for manifest_id in _load_order:
		var manifest_key := str(manifest_id)
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		var dependencies: Array = manifest.get("dependencies", [])
		for dependency_value in dependencies:
			var dependency: Dictionary = dependency_value if dependency_value is Dictionary else {}
			var dependency_id := StringName(str(dependency.get("id", "")))
			if str(dependency_id).is_empty():
				continue
			if not _manifests.has(str(dependency_id)):
				_add_dependency_warning(manifest_id, dependency_id, "missing dependency")
				if bool(dependency.get("required", true)):
					_disabled_manifests[manifest_key] = "missing dependency %s" % str(dependency_id)
				continue
			if _user_disabled_manifests.has(str(dependency_id)):
				_add_dependency_warning(manifest_id, dependency_id, "dependency disabled by user")
				if bool(dependency.get("required", true)):
					_disabled_manifests[manifest_key] = "dependency %s disabled" % str(dependency_id)
				continue
			if _disabled_manifests.has(str(dependency_id)):
				_add_dependency_warning(manifest_id, dependency_id, "dependency blocked by its own contract")
				if bool(dependency.get("required", true)):
					_disabled_manifests[manifest_key] = "dependency %s is blocked" % str(dependency_id)
				continue
			var loaded_version := str((_manifests[str(dependency_id)] as Dictionary).get("version", "0"))
			var min_version := str(dependency.get("min_version", "")).strip_edges()
			if not min_version.is_empty() and _compare_versions(loaded_version, min_version) < 0:
				_add_dependency_warning(manifest_id, dependency_id, "dependency below min_version %s" % min_version)
				if bool(dependency.get("required", true)):
					_disabled_manifests[manifest_key] = "dependency %s below %s" % [str(dependency_id), min_version]
			var max_version := str(dependency.get("max_version", "")).strip_edges()
			if not max_version.is_empty() and _compare_versions(loaded_version, max_version) > 0:
				_add_dependency_warning(manifest_id, dependency_id, "dependency above max_version %s" % max_version)
				if bool(dependency.get("required", true)):
					_disabled_manifests[manifest_key] = "dependency %s above %s" % [str(dependency_id), max_version]

	if not allow_script_pack_registration:
		for manifest_id in _load_order:
			var script_entries := _entries_for_manifest(manifest_id, SCRIPT_CONTENT_BUCKETS)
			if script_entries.is_empty():
				continue
			_add_dependency_warning(manifest_id, &"script_packs", "script content discovered but locked")


func _apply_manifest_enabled_state() -> void:
	_apply_user_disabled_manifests()
	for manifest_id in _load_order:
		var manifest_key := str(manifest_id)
		var user_disabled := _user_disabled_manifests.has(manifest_key)
		var enabled_state := not _disabled_manifests.has(manifest_key)
		var manifest: Dictionary = _manifests.get(manifest_key, {})
		manifest["enabled"] = enabled_state
		manifest["user_enabled"] = not user_disabled
		manifest["user_disabled"] = user_disabled
		manifest["disabled_reason"] = str(_disabled_manifests.get(manifest_key, ""))
		_manifests[manifest_key] = manifest

	for bucket in CONTENT_BUCKETS:
		var entries := _content[bucket] as Dictionary
		for qualified_id in entries.keys():
			var entry: Dictionary = entries[qualified_id]
			var manifest_key := str(entry.get("manifest_id", ""))
			var entry_user_disabled := _user_disabled_manifests.has(manifest_key)
			var enabled_state := not _disabled_manifests.has(manifest_key)
			entry["enabled"] = enabled_state
			entry["manifest_user_enabled"] = not entry_user_disabled
			entry["manifest_user_disabled"] = entry_user_disabled
			entry["disabled_reason"] = str(_disabled_manifests.get(manifest_key, ""))
			entries[qualified_id] = entry


func _apply_user_disabled_manifests() -> void:
	for key in _user_disabled_manifests.keys():
		var manifest_key := str(key)
		if not _manifests.has(manifest_key):
			continue
		var existing_reason := str(_disabled_manifests.get(manifest_key, "")).strip_edges()
		_disabled_manifests[manifest_key] = "user disabled" if existing_reason.is_empty() else "user disabled; %s" % existing_reason


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
			if str(entry.get("manifest_id", "")) == str(manifest_id):
				found.append(entry)
	return found


func _add_dependency_warning(manifest_id: StringName, dependency_id: StringName, reason: String) -> void:
	var key := "%s:%s:%s" % [str(manifest_id), str(dependency_id), reason]
	if _dependency_warnings.has(key):
		return
	_dependency_warnings[key] = {
		"manifest_id": manifest_id,
		"dependency_id": dependency_id,
		"reason": reason,
	}
	dependency_warning.emit(manifest_id, dependency_id, reason)


func _add_conflict_warning(manifest_id: StringName, conflicting_id: StringName, reason: String) -> void:
	var key := "%s:%s:%s" % [str(manifest_id), str(conflicting_id), reason]
	if _conflict_warnings.has(key):
		return
	_conflict_warnings[key] = {
		"manifest_id": manifest_id,
		"conflicting_id": conflicting_id,
		"reason": reason,
	}
	manifest_conflict.emit(manifest_id, conflicting_id, reason)


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


func _conflict_array(value: Variant) -> Array:
	var conflicts: Array = []
	if not (value is Array):
		return conflicts
	for entry in value as Array:
		if entry is String:
			conflicts.append({"id": str(entry), "reason": "declared incompatible"})
		elif entry is Dictionary:
			var conflict := (entry as Dictionary).duplicate(true)
			conflict["id"] = str(conflict.get("id", ""))
			conflict["reason"] = str(conflict.get("reason", "declared incompatible"))
			conflicts.append(conflict)
	return conflicts


func _normalize_manifest_options(value: Variant) -> Array:
	var options: Array = []
	if not (value is Array):
		return options
	for option_value in value as Array:
		if not (option_value is Dictionary):
			continue
		var option := (option_value as Dictionary).duplicate(true)
		option["id"] = str(option.get("id", ""))
		option["type"] = str(option.get("type", "bool"))
		option["display_name"] = str(option.get("display_name", option.get("id", "Option")))
		option["description"] = str(option.get("description", ""))
		option["network_category"] = str(option.get("network_category", "local_visual"))
		option["default"] = _normalize_option_value(option, option.get("default"))
		options.append(option)
	return options


func _find_manifest_option(manifest_id: StringName, option_id: StringName) -> Dictionary:
	var manifest := get_manifest(manifest_id)
	var options_value: Variant = manifest.get("options", [])
	if not (options_value is Array):
		return {}
	for option_value in options_value as Array:
		if option_value is Dictionary and str((option_value as Dictionary).get("id", "")) == str(option_id):
			return (option_value as Dictionary).duplicate(true)
	return {}


func _normalize_option_value(option: Dictionary, value: Variant) -> Variant:
	var option_type := str(option.get("type", "bool"))
	match option_type:
		"bool":
			if value is bool:
				return value
		"int":
			if value is int or value is float:
				var int_value := int(value)
				var minimum := int(option.get("min", -2147483648))
				var maximum := int(option.get("max", 2147483647))
				return clampi(int_value, minimum, maximum)
		"float":
			if value is int or value is float:
				var float_value := float(value)
				var minimum := float(option.get("min", -1.0e20))
				var maximum := float(option.get("max", 1.0e20))
				return clampf(float_value, minimum, maximum)
		"string":
			if value is String:
				return str(value).substr(0, 256)
		"choice":
			var choices_value: Variant = option.get("choices", [])
			if choices_value is Array and (choices_value as Array).has(value):
				return value
		"color":
			if value is String and Color.from_string(str(value), Color(-1.0, -1.0, -1.0, -1.0)) != Color(-1.0, -1.0, -1.0, -1.0):
				return str(value)
	return null


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
	if bucket == "shader_packs" or bucket == "shader_overrides" or bucket == "texture_packs" or bucket == "ui_skins":
		return &"visual_pack"
	if CREATOR_LEVEL_BUCKETS.has(bucket):
		return &"creator_level"
	if CREATOR_ENTITY_BUCKETS.has(bucket):
		return &"creator_entity"
	if bucket == "total_conversions" or bucket == "expansion_packs" or bucket == "calamity_mods":
		return &"expansion"
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
	if CREATOR_LEVEL_BUCKETS.has(bucket):
		return "deterministic_seed"
	if CREATOR_EXPANSION_BUCKETS.has(bucket):
		return "deterministic_seed"
	if bucket == "arenas" or bucket == "waves" or bucket == "rules" or bucket == "arena_events":
		return "deterministic_seed"
	return "exported_state"


func _qualified_content_id(manifest_id: StringName, local_id: String) -> String:
	return "%s/%s" % [str(manifest_id), local_id]


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


func _compare_versions(left: String, right: String) -> int:
	var left_core := left.strip_edges().split("-", false, 1)[0]
	var right_core := right.strip_edges().split("-", false, 1)[0]
	var left_parts := left_core.split(".")
	var right_parts := right_core.split(".")
	var count := maxi(left_parts.size(), right_parts.size())
	for index in range(count):
		var left_value := int(left_parts[index]) if index < left_parts.size() and str(left_parts[index]).is_valid_int() else 0
		var right_value := int(right_parts[index]) if index < right_parts.size() and str(right_parts[index]).is_valid_int() else 0
		if left_value < right_value:
			return -1
		if left_value > right_value:
			return 1
	var left_prerelease := left.contains("-")
	var right_prerelease := right.contains("-")
	if left_prerelease != right_prerelease:
		return -1 if left_prerelease else 1
	return 0


func _join_errors(errors: Array[String]) -> String:
	var parts := PackedStringArray()
	for error in errors:
		parts.append(error)
	return "; ".join(parts)


func _record_failed_manifest(path: String, reason: String) -> void:
	_failed_manifests[path] = reason
	manifest_failed.emit(path, reason)
