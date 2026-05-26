extends Node
class_name RunScoreTracker
## Signal-driven score/challenge-code tracker for shareable runs.

signal score_changed(score: int, snapshot: Dictionary)
signal challenge_code_changed(code: String)

@export var enabled: bool = true
@export var wave_clear_score: int = 800
@export var boss_defeat_score: int = 5000
@export var secret_boss_score: int = 9000
@export var perfect_slingshot_score: int = 320
@export var apex_slingshot_score: int = 700
@export var event_horizon_escape_score: int = 1400
@export var rare_event_score: int = 1200
@export var coop_combo_score: int = 1800

var score: int = 0
var waves_cleared: int = 0
var bosses_defeated: int = 0
var secret_bosses_defeated: int = 0
var perfect_slingshots: int = 0
var apex_slingshots: int = 0
var event_horizon_escapes: int = 0
var rare_events: int = 0
var coop_combos: int = 0

var _last_challenge_code := ""


func _ready() -> void:
	add_to_group("run_score_tracker")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_bootstrap")


func reset_score() -> void:
	score = 0
	waves_cleared = 0
	bosses_defeated = 0
	secret_bosses_defeated = 0
	perfect_slingshots = 0
	apex_slingshots = 0
	event_horizon_escapes = 0
	rare_events = 0
	coop_combos = 0
	_emit_score_changed()


func get_score_snapshot() -> Dictionary:
	return {
		"score": score,
		"waves_cleared": waves_cleared,
		"bosses_defeated": bosses_defeated,
		"secret_bosses_defeated": secret_bosses_defeated,
		"perfect_slingshots": perfect_slingshots,
		"apex_slingshots": apex_slingshots,
		"event_horizon_escapes": event_horizon_escapes,
		"rare_events": rare_events,
		"coop_combos": coop_combos,
		"seed_code": RunProgress.get_run_seed_code() if RunProgress != null else "no-seed",
	}


func get_challenge_code() -> String:
	var snapshot := get_score_snapshot()
	var checksum := absi(int(hash(JSON.stringify(snapshot)))) % 100000
	return "%s:S%d:C%05d" % [
		str(snapshot.get("seed_code", "no-seed")),
		score,
		checksum,
	]


func _bootstrap() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var wave_director := root.find_child("WaveDirector", true, false)
	_connect_once(wave_director, &"wave_cleared", Callable(self, "_on_wave_cleared"))
	_connect_once(wave_director, &"boss_defeated_anchor", Callable(self, "_on_boss_defeated"))

	var run_variation := root.find_child("RunVariationDirector", true, false)
	_connect_once(run_variation, &"rare_event_started", Callable(self, "_on_rare_event_started"))

	var secret_boss_director := root.find_child("SecretBossDirector", true, false)
	_connect_once(secret_boss_director, &"secret_boss_defeated", Callable(self, "_on_secret_boss_defeated"))

	var event_horizon := root.find_child("EventHorizonDirector", true, false)
	_connect_once(event_horizon, &"horizon_escape_scored", Callable(self, "_on_horizon_escape_scored"))

	var coop_combo := root.find_child("CoopComboDirector", true, false)
	_connect_once(coop_combo, &"coop_combo_triggered", Callable(self, "_on_coop_combo_triggered"))

	var player := get_tree().get_first_node_in_group("Player")
	_connect_once(player, &"slingshot_mastery_scored", Callable(self, "_on_slingshot_mastery_scored"))
	_emit_score_changed()


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _add_score(amount: int) -> void:
	if not enabled:
		return
	score = maxi(score + amount, 0)
	_emit_score_changed()


func _emit_score_changed() -> void:
	var snapshot := get_score_snapshot()
	score_changed.emit(score, snapshot)
	var code := get_challenge_code()
	if code == _last_challenge_code:
		return
	_last_challenge_code = code
	challenge_code_changed.emit(code)


func _on_wave_cleared(wave: int) -> void:
	waves_cleared = maxi(waves_cleared, wave)
	_add_score(wave_clear_score + maxi(wave - 1, 0) * 90)


func _on_boss_defeated(_boss_scene_path: String) -> void:
	bosses_defeated += 1
	_add_score(boss_defeat_score + bosses_defeated * 450)


func _on_secret_boss_defeated(_secret_id: StringName) -> void:
	secret_bosses_defeated += 1
	_add_score(secret_boss_score)


func _on_rare_event_started(_event_id: StringName, _wave: int) -> void:
	rare_events += 1
	_add_score(rare_event_score)


func _on_horizon_escape_scored(_data: Dictionary) -> void:
	event_horizon_escapes += 1
	_add_score(event_horizon_escape_score)


func _on_coop_combo_triggered(_combo_id: StringName, _data: Dictionary) -> void:
	coop_combos += 1
	_add_score(coop_combo_score)


func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	var grade := StringName(data.get("grade", &""))
	if grade == &"apex":
		apex_slingshots += 1
		_add_score(apex_slingshot_score)
	elif grade == &"perfect":
		perfect_slingshots += 1
		_add_score(perfect_slingshot_score)
