extends Node
class_name FairPacingDirector
## Adjusts recovery pacing from player condition without nerfing physics depth.

signal recovery_window_adjusted(multiplier: float, reason: StringName)

@export var enabled: bool = true
@export var low_health_threshold: float = 0.34
@export var broken_shield_rest_multiplier: float = 1.22
@export var low_health_rest_multiplier: float = 1.38
@export var mastery_rest_multiplier: float = 0.88
@export var mastery_score_threshold: float = 0.92

var _player: Node = null
var _wave_director: Node = null
var _base_rest: float = 4.0
var _last_mastery_time: float = -999.0


func _ready() -> void:
	add_to_group("fair_pacing_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	_resolve_sources()
	_capture_base_rest()
	_connect_sources()


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player")
	if root != null:
		_wave_director = root.find_child("WaveDirector", true, false)


func _capture_base_rest() -> void:
	if _wave_director != null and _wave_director.get("rest_between_waves") != null:
		_base_rest = float(_wave_director.get("rest_between_waves"))


func _connect_sources() -> void:
	_connect_once(_wave_director, &"regular_wave", Callable(self, "_on_wave_started"))
	_connect_once(_wave_director, &"boss_wave", Callable(self, "_on_wave_started"))
	_connect_once(_wave_director, &"wave_cleared", Callable(self, "_on_wave_cleared"))
	_connect_once(_player, &"slingshot_mastery_scored", Callable(self, "_on_slingshot_mastery_scored"))


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_wave_started() -> void:
	_restore_base_rest()


func _on_wave_cleared(_wave: int) -> void:
	if not enabled or _wave_director == null:
		return
	var multiplier := _recovery_multiplier()
	var current_rest := float(_wave_director.get("rest_between_waves"))
	_wave_director.set("rest_between_waves", current_rest * multiplier)
	recovery_window_adjusted.emit(multiplier, _recovery_reason(multiplier))


func _on_slingshot_mastery_scored(data: Dictionary) -> void:
	var score := clampf(float(data.get("score", 0.0)), 0.0, 1.0)
	if score >= mastery_score_threshold:
		_last_mastery_time = Time.get_ticks_msec() / 1000.0


func _restore_base_rest() -> void:
	if _wave_director != null and _wave_director.get("rest_between_waves") != null:
		_wave_director.set("rest_between_waves", _base_rest)


func _recovery_multiplier() -> float:
	if _health_ratio() <= low_health_threshold:
		return low_health_rest_multiplier
	if _shield_broken():
		return broken_shield_rest_multiplier
	if _recent_mastery():
		return mastery_rest_multiplier
	return 1.0


func _recovery_reason(multiplier: float) -> StringName:
	if multiplier == low_health_rest_multiplier:
		return &"low_health"
	if multiplier == broken_shield_rest_multiplier:
		return &"shield_broken"
	if multiplier == mastery_rest_multiplier:
		return &"mastery_flow"
	return &"standard"


func _health_ratio() -> float:
	if _player == null:
		return 1.0
	var health := _player.get_node_or_null("HealthComponent")
	if health == null:
		return 1.0
	var current := float(health.get("current_health"))
	var maximum := maxf(float(health.get("max_health")), 1.0)
	return clampf(current / maximum, 0.0, 1.0)


func _shield_broken() -> bool:
	if _player == null:
		return false
	var shield := _player.get("shield_component") as Node
	if shield == null:
		return false
	return bool(shield.get("is_broken")) if shield.get("is_broken") != null else false


func _recent_mastery() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return now - _last_mastery_time <= 7.0
