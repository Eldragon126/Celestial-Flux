extends Node
class_name DeathFairnessDirector
## Adds deterministic context to death messages so failure feels learnable.

signal death_readout_captured(readout: Dictionary)

@export var enabled: bool = true
@export var sample_interval: float = 0.35
@export var max_projectiles_label_threshold: int = 80

var _player: Node2D = null
var _wave_director: Node = null
var _resonance_manager: Node = null
var _arena_manager: Node = null
var _sample_timer: float = 0.0
var _last_readout: Dictionary = {}


func _ready() -> void:
	add_to_group("death_fairness_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_bootstrap")


func _process(delta: float) -> void:
	if not enabled:
		return
	_sample_timer += delta
	if _sample_timer < sample_interval:
		return
	_sample_timer = 0.0
	_last_readout = _capture_readout()


func _bootstrap() -> void:
	_resolve_sources()
	_connect_player()
	_last_readout = _capture_readout()


func _resolve_sources() -> void:
	var root := get_tree().current_scene
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if root == null:
		return
	_wave_director = root.find_child("WaveDirector", true, false)
	_resonance_manager = root.find_child("GravityResonanceManager", true, false)
	_arena_manager = root.find_child("ArenaDestabilizationManager", true, false)


func _connect_player() -> void:
	if _player == null or not _player.has_signal("death_lesson_generated"):
		return
	var callable := Callable(self, "_on_death_lesson_generated")
	if not _player.is_connected("death_lesson_generated", callable):
		_player.connect("death_lesson_generated", callable)


func _capture_readout() -> Dictionary:
	_resolve_sources()
	return {
		"wave": _current_wave(),
		"speed": _player_speed(),
		"field_rule": _field_rule(),
		"chaos": _chaos_level(),
		"projectiles": _projectile_count(),
		"boss_active": _boss_active(),
	}


func _on_death_lesson_generated(lesson: String) -> void:
	if not enabled:
		return
	var readout := _capture_readout()
	death_readout_captured.emit(readout.duplicate(true))
	var message := "%s\n%s" % [lesson, _format_readout(readout)]
	if RunProgress != null:
		RunProgress.set_last_death_message(message)


func _format_readout(readout: Dictionary) -> String:
	var projectile_note := "clear"
	if int(readout.get("projectiles", 0)) >= max_projectiles_label_threshold:
		projectile_note = "dense"
	return "READOUT: wave %d | speed %d | field %s | chaos %d%% | shots %s%s" % [
		int(readout.get("wave", 0)),
		int(readout.get("speed", 0.0)),
		String(readout.get("field_rule", "NONE")).to_upper(),
		int(round(float(readout.get("chaos", 0.0)) * 100.0)),
		projectile_note,
		" | boss law active" if bool(readout.get("boss_active", false)) else "",
	]


func _current_wave() -> int:
	if _wave_director != null and _wave_director.has_method("get_current_wave"):
		return int(_wave_director.call("get_current_wave"))
	return int(RunProgress.wave_index if RunProgress != null else 0)


func _player_speed() -> float:
	if _player == null:
		return 0.0
	var velocity: Variant = _player.get("velocity")
	if velocity is Vector2:
		return velocity.length()
	return 0.0


func _field_rule() -> String:
	if _player == null or _resonance_manager == null:
		return "none"
	if not _resonance_manager.has_method("get_resonance_zone_at_position"):
		return "none"
	var zone_value: Variant = _resonance_manager.call("get_resonance_zone_at_position", _player.global_position)
	if typeof(zone_value) != TYPE_DICTIONARY:
		return "none"
	var zone: Dictionary = zone_value
	if zone.is_empty():
		return "none"
	return String(zone.get("zone_rule_name", "none"))


func _chaos_level() -> float:
	if _arena_manager == null:
		return 0.0
	var value: Variant = _arena_manager.get("chaos_level")
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return 0.0


func _projectile_count() -> int:
	if RuntimeRegistry != null:
		return (
			RuntimeRegistry.get_count(&"enemy_projectiles")
			+ RuntimeRegistry.get_count(&"Projectiles")
		)
	return (
		get_tree().get_nodes_in_group("enemy_projectiles").size()
		+ get_tree().get_nodes_in_group("Projectiles").size()
	)


func _boss_active() -> bool:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(&"bosses") > 0
	for boss in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(boss) and not boss.is_queued_for_deletion():
			return true
	return false
