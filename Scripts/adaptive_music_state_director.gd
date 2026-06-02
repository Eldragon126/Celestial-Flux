extends Node
class_name AdaptiveMusicStateDirector
## Lightweight music-state hooks. Sound design can bind to these signals later
## without turning gameplay systems into an audio manager.

signal music_intensity_changed(intensity: float, layer: StringName, reason: StringName)
signal music_beat_hint(event_id: StringName, intensity: float)

@export var enabled: bool = true
@export var sample_interval: float = 0.2
@export var intensity_lerp_rate: float = 2.4
@export var beat_hint_interval: float = 3.0
@export_range(0.0, 1.0, 0.01) var emit_threshold: float = 0.08

var _arena_chaos: float = 0.0
var _resonance_pressure: float = 0.0
var _time_pressure: float = 0.0
var _boss_pressure: float = 0.0
var _target_intensity: float = 0.0
var _current_intensity: float = 0.0
var _last_emitted_intensity: float = -1.0
var _last_layer: StringName = &"silence"
var _sample_timer: float = 0.0
var _beat_timer: float = 0.0
var _wave_director: Node = null


func _ready() -> void:
	add_to_group("adaptive_music_state_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_bootstrap")


func _process(delta: float) -> void:
	if not enabled:
		return
	_sample_timer += delta
	_beat_timer += delta
	if _sample_timer >= sample_interval:
		_sample_timer = 0.0
		_refresh_boss_pressure()
		_update_target_intensity()
	_current_intensity = lerpf(
		_current_intensity,
		_target_intensity,
		clampf(delta * intensity_lerp_rate, 0.0, 1.0)
	)
	_emit_music_state_if_needed(&"pressure")
	_emit_beat_hint_if_needed()


func get_music_state() -> Dictionary:
	return {
		"intensity": _current_intensity,
		"target_intensity": _target_intensity,
		"layer": _layer_for_intensity(_current_intensity),
		"arena_chaos": _arena_chaos,
		"resonance_pressure": _resonance_pressure,
		"time_pressure": _time_pressure,
		"boss_pressure": _boss_pressure,
	}


func _bootstrap() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_wave_director = root.find_child("WaveDirector", true, false)
	var arena := root.find_child("ArenaDestabilizationManager", true, false)
	var resonance := root.find_child("GravityResonanceManager", true, false)
	var time_manager := root.find_child("TimeDilationManager", true, false)
	_connect_once(arena, &"chaos_level_changed", Callable(self, "_on_chaos_level_changed"))
	_connect_once(resonance, &"resonance_zone_created", Callable(self, "_on_resonance_zone_changed"))
	_connect_once(resonance, &"resonance_zone_intensified", Callable(self, "_on_resonance_zone_changed"))
	_connect_once(resonance, &"resonance_zone_decayed_detailed", Callable(self, "_on_resonance_zone_decayed"))
	_connect_once(time_manager, &"time_tear_intensity_changed", Callable(self, "_on_time_tear_intensity_changed"))
	_connect_once(_wave_director, &"boss_wave", Callable(self, "_on_boss_wave"))
	_connect_once(_wave_director, &"regular_wave", Callable(self, "_on_regular_wave"))


func _connect_once(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _update_target_intensity() -> void:
	_target_intensity = clampf(
		_arena_chaos * 0.38
		+ _resonance_pressure * 0.24
		+ _time_pressure * 0.18
		+ _boss_pressure * 0.2,
		0.0,
		1.0
	)


func _emit_music_state_if_needed(reason: StringName) -> void:
	var layer := _layer_for_intensity(_current_intensity)
	var changed_amount := absf(_current_intensity - _last_emitted_intensity)
	if layer == _last_layer and changed_amount < emit_threshold:
		return
	_last_layer = layer
	_last_emitted_intensity = _current_intensity
	music_intensity_changed.emit(_current_intensity, layer, reason)


func _emit_beat_hint_if_needed() -> void:
	if _current_intensity < 0.58 or _beat_timer < beat_hint_interval:
		return
	_beat_timer = 0.0
	var event_id := &"pulse"
	if _current_intensity > 0.86:
		event_id = &"collapse"
	elif _current_intensity > 0.72:
		event_id = &"burst"
	music_beat_hint.emit(event_id, _current_intensity)


func _layer_for_intensity(intensity: float) -> StringName:
	if intensity >= 0.82:
		return &"collapse"
	if intensity >= 0.58:
		return &"overload"
	if intensity >= 0.32:
		return &"tension"
	if intensity > 0.05:
		return &"drift"
	return &"silence"


func _refresh_boss_pressure() -> void:
	_boss_pressure = 0.0
	if RuntimeRegistry != null:
		_boss_pressure = 1.0 if RuntimeRegistry.get_count(&"bosses") > 0 else 0.0
		return
	for boss in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(boss) and not boss.is_queued_for_deletion():
			_boss_pressure = 1.0
			return


func _on_chaos_level_changed(value: float) -> void:
	_arena_chaos = clampf(value, 0.0, 1.0)


func _on_resonance_zone_changed(zone_data: Dictionary) -> void:
	var intensity := clampf(float(zone_data.get("intensity", 0.0)), 0.0, 1.0)
	_resonance_pressure = maxf(_resonance_pressure, intensity)


func _on_resonance_zone_decayed(_zone_data: Dictionary) -> void:
	_resonance_pressure = maxf(_resonance_pressure - 0.16, 0.0)


func _on_time_tear_intensity_changed(intensity: float) -> void:
	_time_pressure = clampf(intensity, 0.0, 1.0)


func _on_boss_wave() -> void:
	_boss_pressure = 1.0
	_emit_music_state_if_needed(&"boss_wave")


func _on_regular_wave() -> void:
	_boss_pressure = 0.0
	_emit_music_state_if_needed(&"regular_wave")
