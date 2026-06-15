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
const SAVE_VERSION := 1
const PERSISTENT_COLLAPSE_VERSION := 1
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

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	has_anchor = FileAccess.file_exists(SAVE_PATH)
	_load_persistent_collapse()


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


func get_run_seed_code() -> String:
	var mode := "boss_rush" if boss_rush_mode else ("challenge" if challenge_mode else "standard")
	return "%s:%d:%d" % [mode, run_seed, wave_index]


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
