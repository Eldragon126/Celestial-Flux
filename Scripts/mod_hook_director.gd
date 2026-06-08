extends Node
class_name ModHookDirector

signal mod_hook_triggered(hook_id: StringName, entry_id: StringName, data: Dictionary)
signal mod_effect_applied(action: StringName, entry_id: StringName, data: Dictionary)
signal mod_weapon_offered(weapon_id: StringName, entry: Dictionary, data: Dictionary)

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
const GRADE_RANK := {
	"assist": 0,
	"good": 1,
	"great": 2,
	"perfect": 3,
	"apex": 4,
}
const NETWORKED_PLAYER_HOOKS := [
	&"slingshot_good",
	&"slingshot_great",
	&"slingshot_perfect",
	&"slingshot_apex",
	&"weapon_fired",
	&"projectile_hit",
	&"coop_combo_triggered",
]
const LOCAL_VISUAL_ACTIONS := [&"emit_hud_badge", &"play_sfx", &"request_music_layer"]

@export var enabled: bool = true
@export var reconnect_interval: float = 0.5
@export var max_entries_per_hook: int = 8
@export var max_effects_per_entry: int = 4
@export var max_resonance_radius: float = 420.0
@export var max_gravity_scar_radius: float = 420.0
@export var max_effect_duration: float = 6.0
@export var auto_select_weapon_offers: bool = false
@export var hud_notice_duration: float = 1.65

var _registry: Node = null
var _player: Node2D = null
var _weapon_system: Node = null
var _resonance_manager: Node = null
var _scar_manager: Node = null
var _wave_director: Node = null
var _run_variation_director: Node = null
var _coop_combo_director: Node = null
var _hud: Node = null
var _audio_players: Array[AudioStreamPlayer2D] = []
var _reconnect_elapsed: float = 999.0
var _run_start_emitted: bool = false
var _trigger_counts: Dictionary = {}
var _cooldown_until: Dictionary = {}
var _network_replay_guard: Dictionary = {}


func _ready() -> void:
	add_to_group("mod_hook_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(enabled)
	call_deferred("_bootstrap")


func _process(delta: float) -> void:
	if not enabled:
		return
	_reconnect_elapsed += delta
	_prune_audio_players()
	if _reconnect_elapsed < maxf(reconnect_interval, 0.1):
		return
	_reconnect_elapsed = 0.0
	_bootstrap()


func _bootstrap() -> void:
	if not enabled:
		return
	_resolve_sources()
	_connect_sources()
	if not _run_start_emitted and _registry != null and is_instance_valid(_registry) and _registry.has_method("get_hook_entries"):
		_run_start_emitted = true
		call_deferred("_trigger_hook", &"run_start", _base_hook_data(&"run_start"), false)


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = MultiplayerTargeting.local_player(get_tree())
	_weapon_system = _player.get_node_or_null("WeaponSystem") if _player != null else get_tree().get_first_node_in_group("weapon_system")
	if root == null:
		return
	_registry = root.find_child("ModContentRegistry", true, false)
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	_scar_manager = root.find_child("GravityScarManager", true, false)
	_wave_director = root.find_child("WaveDirector", true, false)
	_run_variation_director = root.find_child("RunVariationDirector", true, false)
	_coop_combo_director = root.find_child("CoopComboDirector", true, false)
	_hud = root.find_child("OrbitalHUD", true, false)


func _connect_sources() -> void:
	_connect_once(_registry, &"mod_catalog_changed", Callable(self, "_on_mod_catalog_changed"))
	_connect_once(_registry, &"registry_reloaded", Callable(self, "_on_registry_reloaded"))
	_connect_once(_player, &"slingshot_mastery_scored", Callable(self, "_on_slingshot_mastery_scored"))
	_connect_once(_player, &"death_lesson_generated", Callable(self, "_on_death_lesson_generated"))
	_connect_once(_player, &"momentum_projectile_spawned", Callable(self, "_on_projectile_spawned"))
	_connect_once(_weapon_system, &"weapon_fired", Callable(self, "_on_weapon_fired"))
	_connect_once(_wave_director, &"regular_wave", Callable(self, "_on_wave_started"))
	_connect_once(_wave_director, &"boss_wave", Callable(self, "_on_boss_wave_started"))
	_connect_once(_wave_director, &"wave_cleared", Callable(self, "_on_wave_cleared"))
	_connect_once(_wave_director, &"boss_defeated_anchor", Callable(self, "_on_boss_defeated"))
	_connect_once(_run_variation_director, &"rare_event_started", Callable(self, "_on_rare_event_started"))
	_connect_once(_resonance_manager, &"resonance_zone_created", Callable(self, "_on_resonance_zone_created"))
	_connect_once(_scar_manager, &"gravity_scar_created", Callable(self, "_on_gravity_scar_created"))
	_connect_once(_coop_combo_director, &"coop_combo_triggered", Callable(self, "_on_coop_combo_triggered"))
	if NetworkSession != null:
		_connect_once(NetworkSession, &"network_mod_hook_received", Callable(self, "_on_network_mod_hook_received"))
	_connect_projectile_hit_sources()


func _connect_projectile_hit_sources() -> void:
	for node in get_tree().get_nodes_in_group("player_projectiles"):
		_connect_once(node, &"projectile_hit", Callable(self, "_on_projectile_hit"))


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _on_mod_catalog_changed(_snapshot: Dictionary) -> void:
	_trigger_counts.clear()
	_cooldown_until.clear()


func _on_registry_reloaded(_summary: Dictionary) -> void:
	_on_mod_catalog_changed({})


func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	var grade := String(data.get("grade", "good")).to_lower()
	var hook := &"slingshot_good"
	if grade == "great":
		hook = &"slingshot_great"
	elif grade == "perfect":
		hook = &"slingshot_perfect"
	elif grade == "apex":
		hook = &"slingshot_apex"
	_trigger_hook(hook, data, true)


func _on_death_lesson_generated(lesson: String) -> void:
	_trigger_hook(&"death", {"lesson": lesson, "position": _default_position()}, false)


func _on_weapon_fired(weapon_id: StringName, weapon_data: Dictionary) -> void:
	var data := weapon_data.duplicate(true)
	data["weapon_id"] = String(weapon_id)
	data["position"] = _event_position(data)
	_trigger_hook(&"weapon_fired", data, true)


func _on_projectile_spawned(projectile: Node, _direction: Vector2) -> void:
	_connect_once(projectile, &"projectile_hit", Callable(self, "_on_projectile_hit"))


func _on_projectile_hit(hit_data: Dictionary) -> void:
	if _is_remote_projectile_hit(hit_data):
		return
	var data := hit_data.duplicate(true)
	data["position"] = _event_position(data)
	_trigger_hook(&"projectile_hit", data, true)


func _on_wave_started() -> void:
	_trigger_hook(&"wave_start", _base_hook_data(&"wave_start"), false)


func _on_boss_wave_started() -> void:
	var data := _base_hook_data(&"boss_spawned")
	data["boss_active"] = true
	_trigger_hook(&"boss_spawned", data, false)
	_trigger_hook(&"wave_start", data, false)


func _on_wave_cleared(wave: int) -> void:
	_trigger_hook(&"wave_clear", {"wave": wave, "position": _default_position()}, false)


func _on_boss_defeated(boss_scene_path: String) -> void:
	_trigger_hook(&"boss_defeated", {
		"boss_scene": boss_scene_path,
		"wave": _current_wave(),
		"position": _default_position(),
	}, false)


func _on_rare_event_started(event_id: StringName, wave: int) -> void:
	_trigger_hook(&"rare_event_started", {
		"event_id": String(event_id),
		"wave": wave,
		"position": _default_position(),
	}, false)


func _on_resonance_zone_created(zone_data: Dictionary) -> void:
	var data := zone_data.duplicate(true)
	data["position"] = _event_position(data)
	_trigger_hook(&"resonance_created", data, false)


func _on_gravity_scar_created(scar_data: Dictionary) -> void:
	var data := scar_data.duplicate(true)
	data["position"] = _event_position(data)
	_trigger_hook(&"gravity_scar_created", data, false)


func _on_coop_combo_triggered(combo_id: StringName, data: Dictionary) -> void:
	var hook_data := data.duplicate(true)
	hook_data["combo_id"] = String(combo_id)
	hook_data["position"] = _event_position(hook_data)
	_trigger_hook(&"coop_combo_triggered", hook_data, true)


func _on_network_mod_hook_received(hook_id: StringName, entry_id: StringName, data: Dictionary) -> void:
	var guard_key := "%s:%s:%d" % [String(hook_id), String(entry_id), int(data.get("time", 0.0) * 1000.0)]
	if _network_replay_guard.has(guard_key):
		return
	_network_replay_guard[guard_key] = true
	_trigger_specific_entry(hook_id, entry_id, data)


func _trigger_hook(hook_id: StringName, data: Dictionary, allow_network: bool = true) -> void:
	if _registry == null or not is_instance_valid(_registry) or not _registry.has_method("get_hook_entries"):
		return
	var entries_value: Variant = _registry.call("get_hook_entries", hook_id)
	if not (entries_value is Array):
		return
	var entries := entries_value as Array
	var hook_data := _normalized_hook_data(data)
	var applied := 0
	for entry_value in entries:
		if applied >= max_entries_per_hook:
			return
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if not _entry_can_trigger(entry, hook_id, hook_data):
			continue
		if allow_network and _should_network_replicate(hook_id, entry):
			_broadcast_hook_event(hook_id, entry, hook_data)
		_mark_entry_triggered(entry)
		_apply_entry_effects(entry, hook_id, hook_data)
		mod_hook_triggered.emit(hook_id, _entry_id(entry), hook_data.duplicate(true))
		applied += 1


func _trigger_specific_entry(hook_id: StringName, entry_id: StringName, data: Dictionary) -> void:
	if _registry == null or not is_instance_valid(_registry) or not _registry.has_method("get_hook_entries"):
		return
	var entries_value: Variant = _registry.call("get_hook_entries", hook_id)
	if not (entries_value is Array):
		return
	var entries := entries_value as Array
	var hook_data := _normalized_hook_data(data)
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if _entry_id(entry) != entry_id and StringName(str(entry.get("local_id", ""))) != entry_id:
			continue
		if not _entry_can_trigger(entry, hook_id, hook_data):
			return
		_mark_entry_triggered(entry)
		_apply_entry_effects(entry, hook_id, hook_data)
		mod_hook_triggered.emit(hook_id, _entry_id(entry), hook_data.duplicate(true))
		return


func _entry_can_trigger(entry: Dictionary, hook_id: StringName, data: Dictionary) -> bool:
	if not bool(entry.get("enabled", true)):
		return false
	var entry_id := _entry_id(entry)
	var now := _now_seconds()
	if float(_cooldown_until.get(entry_id, -999.0)) > now:
		return false
	var max_triggers := int(entry.get("max_triggers", 0))
	if max_triggers > 0 and int(_trigger_counts.get(entry_id, 0)) >= max_triggers:
		return false
	return _conditions_match(entry, hook_id, data)


func _mark_entry_triggered(entry: Dictionary) -> void:
	var entry_id := _entry_id(entry)
	_trigger_counts[entry_id] = int(_trigger_counts.get(entry_id, 0)) + 1
	var cooldown := maxf(float(entry.get("cooldown", 0.0)), 0.0)
	if cooldown > 0.0:
		_cooldown_until[entry_id] = _now_seconds() + cooldown


func _conditions_match(entry: Dictionary, _hook_id: StringName, data: Dictionary) -> bool:
	var conditions_value: Variant = entry.get("conditions", [])
	if not (conditions_value is Array):
		return true
	var conditions := conditions_value as Array
	for condition_value in conditions:
		if not (condition_value is Dictionary):
			return false
		if not _condition_matches(condition_value as Dictionary, data):
			return false
	return true


func _condition_matches(condition: Dictionary, data: Dictionary) -> bool:
	var condition_type := StringName(str(condition.get("type", "")))
	match condition_type:
		&"min_wave":
			return _current_wave() >= int(condition.get("value", 0))
		&"max_wave":
			return _current_wave() <= int(condition.get("value", 9999))
		&"chaos_tier_at_least":
			return _current_chaos_tier() >= int(condition.get("value", 0))
		&"chaos_tier_at_most":
			return _current_chaos_tier() <= int(condition.get("value", 9999))
		&"has_powerup":
			return _has_powerup(StringName(str(condition.get("powerup_id", condition.get("id", "")))))
		&"has_weapon":
			return _has_weapon(str(condition.get("weapon_id", condition.get("id", ""))))
		&"slingshot_grade_at_least":
			return _grade_rank(String(data.get("grade", "assist"))) >= _grade_rank(String(condition.get("grade", "good")))
		&"resonance_type":
			return _typed_name_matches(data, condition, "zone_type", "zone_type_name")
		&"scar_type":
			return _typed_name_matches(data, condition, "scar_type", "scar_type_name")
		&"boss_active":
			return _boss_active() == bool(condition.get("value", true))
		&"player_health_below":
			return _player_health_ratio() < clampf(float(condition.get("value", 1.0)), 0.0, 1.0)
		&"player_shield_below":
			return _player_shield_ratio() < clampf(float(condition.get("value", 1.0)), 0.0, 1.0)
		&"seed_tag":
			return _run_flag_matches("seed_tag", str(condition.get("value", condition.get("tag", ""))))
		&"run_modifier":
			return _run_flag_matches("run_modifier", str(condition.get("value", condition.get("modifier", ""))))
		&"multiplayer_peer_count_at_least":
			return _multiplayer_peer_count() >= int(condition.get("value", 1))
	return false


func _apply_entry_effects(entry: Dictionary, _hook_id: StringName, data: Dictionary) -> void:
	var effects_value: Variant = entry.get("effects", [])
	if not (effects_value is Array):
		return
	var effects := effects_value as Array
	var effect_count := 0
	for effect_value in effects:
		if effect_count >= max_effects_per_entry:
			return
		if not (effect_value is Dictionary):
			continue
		var effect: Dictionary = effect_value
		var action := StringName(str(effect.get("action", "")))
		if _is_local_visual_entry(entry) and not LOCAL_VISUAL_ACTIONS.has(action):
			continue
		var applied := false
		match action:
			&"create_resonance_zone":
				applied = _apply_create_resonance_zone(effect, entry, data)
			&"create_gravity_scar":
				applied = _apply_create_gravity_scar(effect, entry, data)
			&"grant_powerup":
				applied = _apply_grant_powerup(effect, entry, data)
			&"offer_weapon":
				applied = _apply_offer_weapon(effect, entry, data)
			&"emit_hud_badge":
				applied = _apply_hud_badge(effect, entry, data)
			&"play_sfx":
				applied = _apply_play_sfx(effect, entry, data)
			&"request_music_layer":
				applied = _record_mod_event(action, effect, entry, data)
			&"adjust_run_pressure":
				applied = _record_mod_event(action, effect, entry, data)
			&"tag_score_event":
				applied = _record_mod_event(action, effect, entry, data)
			&"start_challenge_card":
				applied = _record_mod_event(action, effect, entry, data)
			&"complete_challenge_card":
				applied = _record_mod_event(action, effect, entry, data)
			&"spawn_arena_event":
				applied = _record_mod_event(action, effect, entry, data)
			&"spawn_celestial_body":
				applied = _record_mod_event(action, effect, entry, data)
			&"spawn_physics_drop":
				applied = _record_mod_event(action, effect, entry, data)
			_:
				applied = false
		if applied:
			mod_effect_applied.emit(action, _entry_id(entry), data.duplicate(true))
			effect_count += 1
			if action != &"emit_hud_badge":
				_show_notice(_effect_notice(action, effect, entry), _entry_color(entry), 1.15)


func _apply_create_resonance_zone(effect: Dictionary, entry: Dictionary, data: Dictionary) -> bool:
	if _resonance_manager == null or not _resonance_manager.has_method("create_manual_resonance_zone"):
		return false
	var position := _event_position(data)
	var radius := clampf(float(effect.get("radius", 180.0)), 40.0, max_resonance_radius)
	var intensity := clampf(float(effect.get("intensity", 0.45)), 0.05, 0.85)
	var duration := clampf(float(effect.get("duration", 2.0)), 0.15, max_effect_duration)
	var zone_type := _zone_type_from_value(effect.get("zone_type", effect.get("type", data.get("zone_type", "harmonic_orbit"))))
	_resonance_manager.call("create_manual_resonance_zone", position, radius, zone_type, intensity, duration)
	_record_mod_event(&"create_resonance_zone", effect, entry, data)
	return true


func _apply_create_gravity_scar(effect: Dictionary, entry: Dictionary, data: Dictionary) -> bool:
	if _scar_manager == null or not _scar_manager.has_method("create_gravity_scar"):
		return false
	var position := _event_position(data)
	var radius := clampf(float(effect.get("radius", 190.0)), 60.0, max_gravity_scar_radius)
	var intensity := clampf(float(effect.get("intensity", 0.42)), 0.05, 0.8)
	var duration := clampf(float(effect.get("duration", 18.0)), 1.0, maxf(max_effect_duration, 18.0))
	var scar_type := _scar_type_from_value(effect.get("scar_type", effect.get("type", data.get("scar_type", "curvature"))))
	_scar_manager.call("create_gravity_scar", position, radius, scar_type, intensity, duration, _entry_id(entry))
	_record_mod_event(&"create_gravity_scar", effect, entry, data)
	return true


func _apply_grant_powerup(effect: Dictionary, entry: Dictionary, data: Dictionary) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var inventory := _player.get_node_or_null("PowerupInventory")
	if inventory == null or not inventory.has_method("apply_powerup"):
		return false
	var powerup_id := StringName(str(effect.get("powerup_id", effect.get("content_id", effect.get("id", "")))))
	if String(powerup_id).is_empty():
		return false
	var definition := PowerupLibrary.get_definition(powerup_id)
	if definition == null:
		return false
	inventory.call("apply_powerup", definition)
	_record_mod_event(&"grant_powerup", effect, entry, data)
	return true


func _apply_offer_weapon(effect: Dictionary, entry: Dictionary, data: Dictionary) -> bool:
	var weapon_entry := _resolve_weapon_entry(str(effect.get("weapon_id", effect.get("content_id", ""))))
	if weapon_entry.is_empty():
		return false
	var weapon_id := StringName(str(weapon_entry.get("qualified_id", weapon_entry.get("id", ""))))
	if String(weapon_id).is_empty():
		return false
	_record_weapon_offer(weapon_id, weapon_entry, entry, data)
	var should_select := auto_select_weapon_offers or bool(effect.get("auto_select", false))
	if should_select and _weapon_system != null and _weapon_system.has_method("select_weapon_by_id"):
		_weapon_system.call("select_weapon_by_id", weapon_id)
	mod_weapon_offered.emit(weapon_id, weapon_entry.duplicate(true), data.duplicate(true))
	_show_notice("WEAPON OFFERED: %s" % String(weapon_entry.get("display_name", weapon_id)).to_upper(), _entry_color(weapon_entry), hud_notice_duration)
	return true


func _apply_hud_badge(effect: Dictionary, entry: Dictionary, data: Dictionary) -> bool:
	var text := str(effect.get("text", effect.get("display_name", entry.get("display_name", "MOD HOOK")))).strip_edges()
	if text.is_empty():
		text = "MOD HOOK"
	_show_notice(text.to_upper(), _entry_color(entry), hud_notice_duration)
	_record_mod_event(&"emit_hud_badge", effect, entry, data)
	return true


func _apply_play_sfx(effect: Dictionary, entry: Dictionary, data: Dictionary) -> bool:
	var sfx_entry := _resolve_registry_entry(&"sfx", str(effect.get("sfx_id", effect.get("content_id", ""))))
	var stream_path := str(effect.get("stream", sfx_entry.get("stream", sfx_entry.get("audio", "")))).strip_edges()
	if stream_path.is_empty():
		return false
	var stream := load(stream_path) as AudioStream
	if stream == null:
		return false
	var root := get_tree().current_scene
	if root == null:
		return false
	var player := AudioStreamPlayer2D.new()
	player.name = "ModHookCue"
	player.stream = stream
	player.global_position = _event_position(data)
	player.volume_db = clampf(float(effect.get("volume_db", -10.0)), -36.0, 3.0)
	player.pitch_scale = clampf(float(effect.get("pitch", 1.0)), 0.45, 1.8)
	root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	_audio_players.append(player)
	_record_mod_event(&"play_sfx", effect, entry, data)
	return true


func _record_mod_event(action: StringName, effect: Dictionary, entry: Dictionary, data: Dictionary) -> bool:
	if RunProgress == null:
		return true
	var events: Array = RunProgress.arena_flags.get("mod_hook_events", [])
	events.append({
		"action": String(action),
		"entry_id": String(_entry_id(entry)),
		"effect": effect.duplicate(true),
		"wave": _current_wave(),
		"position": _event_position(data),
		"time": _now_seconds(),
	})
	while events.size() > 24:
		events.pop_front()
	RunProgress.arena_flags["mod_hook_events"] = events
	return true


func _record_weapon_offer(weapon_id: StringName, weapon_entry: Dictionary, source_entry: Dictionary, _data: Dictionary) -> void:
	if RunProgress != null:
		var offers: Array = RunProgress.arena_flags.get("mod_weapon_offers", [])
		offers.append({
			"weapon_id": String(weapon_id),
			"display_name": String(weapon_entry.get("display_name", weapon_id)),
			"source_entry": String(_entry_id(source_entry)),
			"wave": _current_wave(),
			"time": _now_seconds(),
		})
		while offers.size() > 12:
			offers.pop_front()
		RunProgress.arena_flags["mod_weapon_offers"] = offers
	if _player != null and is_instance_valid(_player):
		_player.set_meta(&"last_mod_weapon_offer", String(weapon_id))


func _broadcast_hook_event(hook_id: StringName, entry: Dictionary, data: Dictionary) -> void:
	if NetworkSession == null or not NetworkSession.is_network_active():
		return
	if not NETWORKED_PLAYER_HOOKS.has(hook_id):
		return
	if _is_local_visual_entry(entry):
		return
	if NetworkSession.has_method("broadcast_mod_hook_event"):
		NetworkSession.call("broadcast_mod_hook_event", hook_id, _entry_id(entry), data, _player)


func _should_network_replicate(hook_id: StringName, entry: Dictionary) -> bool:
	return NetworkSession != null and NetworkSession.is_network_active() and NETWORKED_PLAYER_HOOKS.has(hook_id) and not _is_local_visual_entry(entry)


func _resolve_weapon_entry(weapon_id: String) -> Dictionary:
	return _resolve_registry_entry(&"weapons", weapon_id)


func _resolve_registry_entry(content_type: StringName, content_id: String) -> Dictionary:
	if _registry == null or not _registry.has_method("get_entry"):
		return {}
	var clean_id := content_id.strip_edges()
	if clean_id.is_empty():
		return {}
	var value: Variant = _registry.call("get_entry", content_type, StringName(clean_id))
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _normalized_hook_data(data: Dictionary) -> Dictionary:
	var normalized := data.duplicate(true)
	normalized["position"] = _event_position(normalized)
	normalized["wave"] = int(normalized.get("wave", _current_wave()))
	normalized["time"] = float(normalized.get("time", _now_seconds()))
	return normalized


func _base_hook_data(hook_id: StringName) -> Dictionary:
	return {
		"hook_id": String(hook_id),
		"wave": _current_wave(),
		"position": _default_position(),
		"time": _now_seconds(),
	}


func _event_position(data: Dictionary) -> Vector2:
	for key in ["position", "origin", "midpoint", "center"]:
		var value: Variant = data.get(key, null)
		if value is Vector2:
			return value
	return _default_position()


func _default_position() -> Vector2:
	if _player != null and is_instance_valid(_player):
		return _player.global_position
	return Vector2.ZERO


func _current_wave() -> int:
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		return int(_wave_director.call("get_current_wave"))
	if RunProgress != null:
		return int(RunProgress.wave_index)
	return 0


func _current_chaos_tier() -> int:
	var root := get_tree().current_scene
	var destabilization := root.find_child("ArenaDestabilizationManager", true, false) if root != null else null
	if destabilization != null:
		var value: Variant = destabilization.get("chaos_tier")
		if typeof(value) == TYPE_INT:
			return int(value)
	return 0


func _has_powerup(powerup_id: StringName) -> bool:
	if _player == null or String(powerup_id).is_empty():
		return false
	var inventory := _player.get_node_or_null("PowerupInventory")
	return inventory != null and inventory.has_method("get_stack_count") and int(inventory.call("get_stack_count", powerup_id)) > 0


func _has_weapon(weapon_id: String) -> bool:
	if _weapon_system == null or not _weapon_system.has_method("get_weapon_debug_state"):
		return false
	var state_value: Variant = _weapon_system.call("get_weapon_debug_state")
	if not (state_value is Dictionary):
		return false
	var state: Dictionary = state_value
	var current_id := String(state.get("weapon_id", ""))
	if current_id == weapon_id or current_id.ends_with("/%s" % weapon_id):
		return true
	var offered: Array = RunProgress.arena_flags.get("mod_weapon_offers", []) if RunProgress != null else []
	for offer_value in offered:
		if offer_value is Dictionary:
			var offered_id := String((offer_value as Dictionary).get("weapon_id", ""))
			if offered_id == weapon_id or offered_id.ends_with("/%s" % weapon_id):
				return true
	return false


func _typed_name_matches(data: Dictionary, condition: Dictionary, type_key: String, name_key: String) -> bool:
	var expected := str(condition.get("value", condition.get("name", condition.get("type_name", "")))).strip_edges().to_lower()
	if expected.is_empty():
		return false
	var actual_name := str(data.get(name_key, "")).strip_edges().to_lower()
	if actual_name == expected:
		return true
	var actual_type := int(data.get(type_key, -999))
	if type_key == "zone_type" and RESONANCE_ZONE_NAME_TO_ID.has(expected):
		return actual_type == int(RESONANCE_ZONE_NAME_TO_ID[expected])
	if type_key == "scar_type" and GRAVITY_SCAR_NAME_TO_ID.has(expected):
		return actual_type == int(GRAVITY_SCAR_NAME_TO_ID[expected])
	return false


func _boss_active() -> bool:
	for node in get_tree().get_nodes_in_group("bosses"):
		if node != null and is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
			return true
	return false


func _player_health_ratio() -> float:
	if _player == null:
		return 1.0
	var health := _player.get_node_or_null("HealthComponent")
	if health == null:
		return 1.0
	var current := float(health.get("current_health"))
	var max_value := maxf(float(health.get("max_health")), 1.0)
	return current / max_value


func _player_shield_ratio() -> float:
	if _player == null:
		return 1.0
	var shield := _player.get_node_or_null("Shield")
	if shield == null:
		return 1.0
	var current_value: Variant = shield.get("current_energy")
	var max_value: Variant = shield.get("max_capacity")
	if not (current_value is float or current_value is int) or not (max_value is float or max_value is int):
		return 1.0
	return float(current_value) / maxf(float(max_value), 1.0)


func _run_flag_matches(flag_name: String, expected: String) -> bool:
	if RunProgress == null or expected.is_empty():
		return false
	return str(RunProgress.arena_flags.get(flag_name, "")).strip_edges() == expected


func _multiplayer_peer_count() -> int:
	if NetworkSession != null and NetworkSession.has_method("get_status_snapshot"):
		var status_value: Variant = NetworkSession.call("get_status_snapshot")
		if status_value is Dictionary:
			var status: Dictionary = status_value
			return int(status.get("peer_count", 1))
	return 1


func _is_remote_projectile_hit(data: Dictionary) -> bool:
	if NetworkSession == null or not NetworkSession.is_network_active():
		return false
	var owner_peer_id := int(data.get("owner_peer_id", 0))
	if owner_peer_id <= 0 or not NetworkSession.has_method("is_local_peer"):
		return false
	return not bool(NetworkSession.call("is_local_peer", owner_peer_id))


func _grade_rank(grade: String) -> int:
	return int(GRADE_RANK.get(grade.strip_edges().to_lower(), 0))


func _zone_type_from_value(value: Variant) -> int:
	if value is int or value is float:
		return clampi(int(value), GravityResonanceManager.ZoneType.COMPRESSION, GravityResonanceManager.ZoneType.HARMONIC_ORBIT)
	var key := str(value).strip_edges().to_lower()
	return int(RESONANCE_ZONE_NAME_TO_ID.get(key, GravityResonanceManager.ZoneType.HARMONIC_ORBIT))


func _scar_type_from_value(value: Variant) -> int:
	if value is int or value is float:
		return clampi(int(value), GravityScarManager.ScarType.CURVATURE, GravityScarManager.ScarType.HARMONIC_FRACTURE)
	var key := str(value).strip_edges().to_lower()
	return int(GRAVITY_SCAR_NAME_TO_ID.get(key, GravityScarManager.ScarType.CURVATURE))


func _entry_id(entry: Dictionary) -> StringName:
	return StringName(str(entry.get("qualified_id", entry.get("id", ""))))


func _is_local_visual_entry(entry: Dictionary) -> bool:
	return str(entry.get("network_category", "")).strip_edges() == "local_visual"


func _entry_color(entry: Dictionary) -> Color:
	var value: Variant = entry.get("color", entry.get("accent_color", Color(0.34, 1.0, 0.86, 1.0)))
	if value is Color:
		return value
	if value is Array:
		var values := value as Array
		if values.size() >= 3:
			return Color(
				clampf(float(values[0]), 0.0, 1.0),
				clampf(float(values[1]), 0.0, 1.0),
				clampf(float(values[2]), 0.0, 1.0),
				clampf(float(values[3]), 0.0, 1.0) if values.size() >= 4 else 1.0
			)
	if value is String:
		var text := str(value)
		if text.begins_with("#"):
			return Color.html(text)
	return Color(0.34, 1.0, 0.86, 1.0)


func _show_notice(text: String, color: Color, duration: float) -> void:
	if _hud == null or not is_instance_valid(_hud):
		_resolve_sources()
	if _hud != null and _hud.has_method("show_mod_notice"):
		_hud.call("show_mod_notice", text, color, duration)


func _effect_notice(action: StringName, effect: Dictionary, entry: Dictionary) -> String:
	if effect.has("notice"):
		return str(effect.get("notice", ""))
	var entry_name := String(entry.get("display_name", entry.get("id", "MOD"))).to_upper()
	match action:
		&"create_resonance_zone":
			return "%s: RESONANCE" % entry_name
		&"create_gravity_scar":
			return "%s: SCAR" % entry_name
		&"grant_powerup":
			return "%s: LAW" % entry_name
		&"offer_weapon":
			return "%s: WEAPON" % entry_name
	return entry_name


func _prune_audio_players() -> void:
	for index in range(_audio_players.size() - 1, -1, -1):
		var player := _audio_players[index]
		if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
			_audio_players.remove_at(index)


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
