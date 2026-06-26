extends Node
## Progress anchor for Vector Anomaly: not a physics snapshot.

enum Phase {
	PHYSICS_WAVES,
	BOSS_ARC,
	LATE_GAME,
	RUPTURE,
	MUSIC_FINALE,
	CREDITS,
	CHALLENGE,
}

signal phase_changed(old_phase: Phase, new_phase: Phase)
signal anchor_saved
signal anchor_loaded(success: bool)
signal run_completed

const SAVE_PATH := "user://run_anchor.save"
const PERSISTENT_COLLAPSE_PATH := "user://simulation_collapse.save"
const OPTIONAL_CHALLENGE_PATH := "user://optional_challenge_progress.save"
const SAVE_VERSION := 1
const PERSISTENT_COLLAPSE_VERSION := 1
const OPTIONAL_CHALLENGE_VERSION := 1
const MAX_PERSISTENT_COLLAPSE_SCARS := 28

const BOSS_MILESTONE_WAVES: Array[int] = [5, 10, 15, 20, 25, 30, 35, 40]
const LATE_GAME_START_WAVE := 31
const LATE_GAME_END_WAVE := 40
const RUPTURE_DURATION_SEC := 75.0

const BOSS_SCENE_PATHS: Array[String] = [
	"res://Nodes/gravity_warden_boss.tscn",
	"res://Nodes/accretion_core_boss.tscn",
	"res://Nodes/null_vector_seraph_boss.tscn",
	"res://Nodes/magnetar_twins_boss.tscn",
	"res://Nodes/rift_weaver_boss.tscn",
	"res://Nodes/ParametricEquationEnemies/polymorph_boss.tscn",
	"res://Nodes/centrifuge_marshal_boss.tscn",
	"res://Nodes/extradimensional_breacher_boss.tscn",
]

var phase: Phase = Phase.PHYSICS_WAVES
var wave_index: int = 0
var bosses_defeated: int = 0
var run_seed: int = 0
var challenge_mode: bool = false
var boss_rush_mode: bool = false
var arena_flags: Dictionary = {}
var challenge_modifiers: Dictionary = {}
var powerup_stacks: Dictionary = {}
var persistent_collapse_scars: Array[Dictionary] = []
var has_anchor: bool = false
var run_finished: bool = false
var last_death_message: String = ""
var last_gravity_ghost_replay: Dictionary = {}
var optional_challenge_state: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	has_anchor = FileAccess.file_exists(SAVE_PATH)
	_load_persistent_collapse()
	_load_optional_challenge_state()


func begin_new_run(use_challenge: bool = false, seed_override: int = 0) -> void:
	_rng.randomize()
	run_seed = _resolve_start_seed(seed_override)
	challenge_mode = use_challenge
	boss_rush_mode = false
	run_finished = false
	wave_index = 0
	bosses_defeated = 0
	arena_flags.clear()
	challenge_modifiers.clear()
	powerup_stacks.clear()
	last_death_message = ""
	last_gravity_ghost_replay.clear()
	phase = Phase.CHALLENGE if challenge_mode else Phase.PHYSICS_WAVES
	phase_changed.emit(Phase.PHYSICS_WAVES, phase)
	clear_anchor()


func begin_boss_rush(seed_override: int = 0) -> void:
	begin_new_run(true, seed_override)
	boss_rush_mode = true
	challenge_modifiers = {
		"boss_rush": true,
		"wave_rest_multiplier": 0.6,
		"boss_health_multiplier": 1.12,
	}
	arena_flags["boss_rush"] = true


func sync_phase_from_wave(wave: int) -> void:
	if challenge_mode or run_finished:
		return
	var old := phase
	if wave >= LATE_GAME_START_WAVE and wave <= LATE_GAME_END_WAVE:
		phase = Phase.LATE_GAME
	elif is_boss_milestone_wave(wave):
		phase = Phase.BOSS_ARC
	elif wave > 0:
		phase = Phase.PHYSICS_WAVES
	if phase != old:
		phase_changed.emit(old, phase)


func on_wave_cleared(wave: int) -> void:
	wave_index = wave
	sync_phase_from_wave(wave)
	if challenge_mode:
		return
	if wave >= LATE_GAME_END_WAVE and phase == Phase.LATE_GAME:
		enter_rupture()


func on_boss_defeated(boss_scene_path: String) -> void:
	var idx := BOSS_SCENE_PATHS.find(boss_scene_path)
	if idx >= 0:
		bosses_defeated = maxi(bosses_defeated, idx + 1)
		if idx < BOSS_MILESTONE_WAVES.size():
			wave_index = maxi(wave_index, BOSS_MILESTONE_WAVES[idx])
	if boss_rush_mode:
		if bosses_defeated >= BOSS_SCENE_PATHS.size():
			run_finished = true
			run_completed.emit()
			clear_anchor()
		return
	if challenge_mode or phase >= Phase.RUPTURE:
		return
	var final_boss_defeated := idx == BOSS_SCENE_PATHS.size() - 1
	if final_boss_defeated or (bosses_defeated >= BOSS_SCENE_PATHS.size() and wave_index >= LATE_GAME_END_WAVE):
		enter_rupture()


func enter_rupture() -> void:
	if challenge_mode or phase >= Phase.RUPTURE:
		return
	var old := phase
	phase = Phase.RUPTURE
	phase_changed.emit(old, phase)


func enter_music_finale() -> void:
	if challenge_mode or phase >= Phase.MUSIC_FINALE:
		return
	var old := phase
	phase = Phase.MUSIC_FINALE
	phase_changed.emit(old, phase)


func enter_credits() -> void:
	var old := phase
	phase = Phase.CREDITS
	run_finished = true
	run_completed.emit()
	phase_changed.emit(old, phase)
	clear_anchor()


func get_scheduled_boss_scene_path(wave: int) -> String:
	for i in range(BOSS_MILESTONE_WAVES.size()):
		if BOSS_MILESTONE_WAVES[i] == wave:
			return BOSS_SCENE_PATHS[i]
	return BOSS_SCENE_PATHS[0]


func is_boss_milestone_wave(wave: int) -> bool:
	return wave in BOSS_MILESTONE_WAVES


func waves_enabled() -> bool:
	if challenge_mode or boss_rush_mode:
		return not run_finished
	return phase <= Phase.LATE_GAME and not run_finished


func capture_powerup_stacks(inventory: Node) -> void:
	if inventory != null and inventory.has_method("export_anchor_stacks"):
		powerup_stacks = inventory.call("export_anchor_stacks")


func apply_powerup_stacks(inventory: Node) -> void:
	if inventory == null or powerup_stacks.is_empty():
		return
	if inventory.has_method("import_anchor_stacks"):
		inventory.call("import_anchor_stacks", powerup_stacks)


func save_anchor() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"phase": phase,
		"wave_index": wave_index,
		"bosses_defeated": bosses_defeated,
		"run_seed": run_seed,
		"challenge_mode": challenge_mode,
		"boss_rush_mode": boss_rush_mode,
		"arena_flags": arena_flags,
		"challenge_modifiers": challenge_modifiers,
		"powerup_stacks": powerup_stacks,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	has_anchor = true
	anchor_saved.emit()
	return true


func load_anchor() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		anchor_loaded.emit(false)
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		anchor_loaded.emit(false)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		anchor_loaded.emit(false)
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		anchor_loaded.emit(false)
		return false
	phase = int(data.get("phase", Phase.PHYSICS_WAVES)) as Phase
	wave_index = int(data.get("wave_index", 0))
	bosses_defeated = int(data.get("bosses_defeated", 0))
	run_seed = int(data.get("run_seed", 0))
	challenge_mode = bool(data.get("challenge_mode", false))
	boss_rush_mode = bool(data.get("boss_rush_mode", false))
	arena_flags = data.get("arena_flags", {})
	challenge_modifiers = data.get("challenge_modifiers", {})
	powerup_stacks = data.get("powerup_stacks", {})
	run_finished = phase >= Phase.CREDITS
	has_anchor = true
	anchor_loaded.emit(true)
	return true


func clear_anchor() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	has_anchor = false


func record_persistent_collapse_scar(scar_data: Dictionary) -> void:
	var position: Vector2 = scar_data.get("position", Vector2.ZERO)
	var radius := maxf(float(scar_data.get("radius", 240.0)), 80.0)
	var intensity := clampf(float(scar_data.get("intensity", 0.5)), 0.05, 1.0)
	var scar_type := int(scar_data.get("type", 0))
	var source := StringName(scar_data.get("source", &"collapse"))

	for idx in range(persistent_collapse_scars.size()):
		var existing := persistent_collapse_scars[idx]
		var existing_position: Vector2 = existing.get("position", Vector2.ZERO)
		if existing_position.distance_to(position) > maxf(radius, float(existing.get("radius", radius))) * 0.65:
			continue
		if int(existing.get("type", scar_type)) != scar_type:
			continue
		existing["position"] = existing_position.lerp(position, 0.35)
		existing["radius"] = maxf(float(existing.get("radius", radius)), radius)
		existing["intensity"] = clampf(maxf(float(existing.get("intensity", intensity)), intensity) + 0.04, 0.05, 1.0)
		existing["source"] = source
		persistent_collapse_scars[idx] = existing
		_save_persistent_collapse()
		return

	persistent_collapse_scars.append({
		"position": position,
		"radius": radius,
		"intensity": intensity,
		"type": scar_type,
		"source": source,
	})
	while persistent_collapse_scars.size() > MAX_PERSISTENT_COLLAPSE_SCARS:
		persistent_collapse_scars.remove_at(0)
	_save_persistent_collapse()


func get_persistent_collapse_scars() -> Array[Dictionary]:
	return persistent_collapse_scars.duplicate(true)


func clear_persistent_collapse_scars() -> void:
	persistent_collapse_scars.clear()
	if FileAccess.file_exists(PERSISTENT_COLLAPSE_PATH):
		DirAccess.remove_absolute(PERSISTENT_COLLAPSE_PATH)


func _load_persistent_collapse() -> void:
	persistent_collapse_scars.clear()
	if not FileAccess.file_exists(PERSISTENT_COLLAPSE_PATH):
		return
	var file := FileAccess.open(PERSISTENT_COLLAPSE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != PERSISTENT_COLLAPSE_VERSION:
		return
	var scars_value: Variant = data.get("scars", [])
	if typeof(scars_value) != TYPE_ARRAY:
		return
	for scar_value in scars_value:
		if typeof(scar_value) != TYPE_DICTIONARY:
			continue
		var scar: Dictionary = scar_value
		persistent_collapse_scars.append({
			"position": Vector2(float(scar.get("x", 0.0)), float(scar.get("y", 0.0))),
			"radius": maxf(float(scar.get("radius", 240.0)), 80.0),
			"intensity": clampf(float(scar.get("intensity", 0.5)), 0.05, 1.0),
			"type": int(scar.get("type", 0)),
			"source": StringName(scar.get("source", "collapse")),
		})


func _save_persistent_collapse() -> void:
	var serialized_scars: Array[Dictionary] = []
	for scar in persistent_collapse_scars:
		var position: Vector2 = scar.get("position", Vector2.ZERO)
		serialized_scars.append({
			"x": position.x,
			"y": position.y,
			"radius": float(scar.get("radius", 240.0)),
			"intensity": float(scar.get("intensity", 0.5)),
			"type": int(scar.get("type", 0)),
			"source": String(scar.get("source", &"collapse")),
		})
	var file := FileAccess.open(PERSISTENT_COLLAPSE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": PERSISTENT_COLLAPSE_VERSION,
		"scars": serialized_scars,
	}))
	file.close()


func set_last_death_message(message: String) -> void:
	last_death_message = message


func set_last_gravity_ghost_replay(snapshot: Dictionary) -> void:
	last_gravity_ghost_replay = snapshot.duplicate(true)


func get_last_gravity_ghost_replay() -> Dictionary:
	return last_gravity_ghost_replay.duplicate(true)


func get_run_seed_code() -> String:
	var mode := "boss_rush" if boss_rush_mode else ("challenge" if challenge_mode else "standard")
	return "%s:%d:%d" % [mode, run_seed, wave_index]


func get_optional_challenge_summary() -> Dictionary:
	_ensure_optional_challenge_defaults()
	return optional_challenge_state.duplicate(true)


func set_selected_optional_challenge(rift_id: StringName, blackbox_id: StringName = &"", contract_id: StringName = &"") -> void:
	arena_flags["selected_optional_rift"] = String(rift_id)
	arena_flags["selected_blackbox_challenge"] = String(blackbox_id)
	arena_flags["selected_style_contract"] = String(contract_id)


func record_anomaly_shard_collected(shard_id: StringName, data: Dictionary = {}) -> void:
	_ensure_optional_challenge_defaults()
	if String(shard_id).is_empty():
		return
	var shards: Dictionary = optional_challenge_state.get("collected_shards", {})
	shards[String(shard_id)] = _simple_optional_record(data)
	optional_challenge_state["collected_shards"] = shards
	_save_optional_challenge_state()


func is_anomaly_shard_collected(shard_id: StringName) -> bool:
	_ensure_optional_challenge_defaults()
	var shards: Dictionary = optional_challenge_state.get("collected_shards", {})
	return shards.has(String(shard_id))


func record_blackbox_tape_collected(tape_id: StringName, unlocks: Array = []) -> void:
	_ensure_optional_challenge_defaults()
	if String(tape_id).is_empty():
		return
	var tapes: Dictionary = optional_challenge_state.get("collected_blackbox_tapes", {})
	tapes[String(tape_id)] = {
		"collected": true,
		"unlocks": _string_array(unlocks),
		"timestamp_msec": Time.get_ticks_msec(),
	}
	optional_challenge_state["collected_blackbox_tapes"] = tapes
	for unlock in unlocks:
		unlock_blackbox_challenge(StringName(str(unlock)), false)
	_save_optional_challenge_state()


func is_blackbox_tape_collected(tape_id: StringName) -> bool:
	_ensure_optional_challenge_defaults()
	var tapes: Dictionary = optional_challenge_state.get("collected_blackbox_tapes", {})
	return tapes.has(String(tape_id))


func unlock_blackbox_challenge(challenge_id: StringName, save_now: bool = true) -> void:
	_ensure_optional_challenge_defaults()
	if String(challenge_id).is_empty():
		return
	var unlocked: Dictionary = optional_challenge_state.get("unlocked_blackbox", {})
	unlocked[String(challenge_id)] = true
	optional_challenge_state["unlocked_blackbox"] = unlocked
	if save_now:
		_save_optional_challenge_state()


func is_blackbox_challenge_unlocked(challenge_id: StringName) -> bool:
	_ensure_optional_challenge_defaults()
	var unlocked: Dictionary = optional_challenge_state.get("unlocked_blackbox", {})
	return bool(unlocked.get(String(challenge_id), false))


func record_rift_cleared(rift_id: StringName, clear_time: float, perfect: bool = false, contract_id: StringName = &"") -> void:
	_ensure_optional_challenge_defaults()
	if String(rift_id).is_empty():
		return
	var rift_key := String(rift_id)
	var cleared: Dictionary = optional_challenge_state.get("cleared_rifts", {})
	cleared[rift_key] = true
	optional_challenge_state["cleared_rifts"] = cleared

	var best_times: Dictionary = optional_challenge_state.get("best_times", {})
	var previous := float(best_times.get(rift_key, INF))
	if clear_time > 0.0 and clear_time < previous:
		best_times[rift_key] = clear_time
	optional_challenge_state["best_times"] = best_times

	if perfect:
		var perfects: Dictionary = optional_challenge_state.get("perfect_clears", {})
		perfects[rift_key] = true
		optional_challenge_state["perfect_clears"] = perfects

	if not String(contract_id).is_empty():
		var contracts: Dictionary = optional_challenge_state.get("completed_contracts", {})
		if not contracts.has(rift_key):
			contracts[rift_key] = {}
		var rift_contracts: Dictionary = contracts[rift_key]
		rift_contracts[String(contract_id)] = true
		contracts[rift_key] = rift_contracts
		optional_challenge_state["completed_contracts"] = contracts
	_save_optional_challenge_state()


func is_rift_cleared(rift_id: StringName) -> bool:
	_ensure_optional_challenge_defaults()
	var cleared: Dictionary = optional_challenge_state.get("cleared_rifts", {})
	return bool(cleared.get(String(rift_id), false))


func _load_optional_challenge_state() -> void:
	optional_challenge_state = _default_optional_challenge_state()
	if not FileAccess.file_exists(OPTIONAL_CHALLENGE_PATH):
		return
	var file := FileAccess.open(OPTIONAL_CHALLENGE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != OPTIONAL_CHALLENGE_VERSION:
		return
	for key in optional_challenge_state.keys():
		if data.has(key):
			optional_challenge_state[key] = data[key]


func _save_optional_challenge_state() -> void:
	_ensure_optional_challenge_defaults()
	var data := optional_challenge_state.duplicate(true)
	data["version"] = OPTIONAL_CHALLENGE_VERSION
	var file := FileAccess.open(OPTIONAL_CHALLENGE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _ensure_optional_challenge_defaults() -> void:
	if optional_challenge_state.is_empty():
		optional_challenge_state = _default_optional_challenge_state()
	var defaults := _default_optional_challenge_state()
	for key in defaults.keys():
		if not optional_challenge_state.has(key):
			optional_challenge_state[key] = defaults[key]


func _default_optional_challenge_state() -> Dictionary:
	return {
		"version": OPTIONAL_CHALLENGE_VERSION,
		"collected_shards": {},
		"collected_blackbox_tapes": {},
		"unlocked_blackbox": {},
		"cleared_rifts": {},
		"best_times": {},
		"perfect_clears": {},
		"completed_contracts": {},
		"unlocked_rifts": {
			"no_thrust_rift": true,
			"one_dash_rift": true,
			"inverted_orbit_rift": true,
			"personal_gravity_flip_rift": true,
			"time_scar_rift": true,
		},
	}


func _simple_optional_record(data: Dictionary) -> Dictionary:
	var record := {
		"collected": true,
		"timestamp_msec": Time.get_ticks_msec(),
	}
	for key in data.keys():
		var value: Variant = data[key]
		if value is Vector2:
			var vec := value as Vector2
			record[String(key)] = {"x": vec.x, "y": vec.y}
		elif value is StringName:
			record[String(key)] = String(value)
		elif typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			record[String(key)] = value
	return record


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func seed_from_code(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return 0
	var parts := trimmed.split(":", false)
	if parts.size() >= 2:
		var parsed_code_seed := _seed_from_numeric_text(String(parts[1]))
		if parsed_code_seed != 0:
			return parsed_code_seed
	var direct_seed := _seed_from_numeric_text(trimmed)
	if direct_seed != 0:
		return direct_seed
	return maxi(absi(int(hash(trimmed))), 1)


func _resolve_start_seed(seed_override: int) -> int:
	if seed_override != 0:
		return maxi(absi(seed_override), 1)
	return maxi(absi(int(_rng.randi())), 1)


func _seed_from_numeric_text(text: String) -> int:
	var clean := text.strip_edges()
	if clean.is_empty():
		return 0
	var start := 1 if clean.begins_with("-") else 0
	if start >= clean.length():
		return 0
	for i in range(start, clean.length()):
		if not clean.substr(i, 1).is_valid_int():
			return 0
	return int(clean)
