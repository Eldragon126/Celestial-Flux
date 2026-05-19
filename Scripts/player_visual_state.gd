extends Node
## Phase-driven visual hooks for trails, glow, shield, and orbit readability.

signal visual_state_changed(state_name: StringName, intensity: float)

@export var player_path: NodePath = ^".."

var _player: Node2D = null
var _thrusters: Node = null
var _shield: Node = null
var _current_state: StringName = &"stable"
var _intensity: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_parent() as Node2D
	if _player != null:
		_thrusters = _player.get_node_or_null("PlayerThrusterTrails")
		_shield = _player.get_node_or_null("Shield")

	if not RunProgress.phase_changed.is_connected(_on_phase_changed):
		RunProgress.phase_changed.connect(_on_phase_changed)
	_apply_phase(RunProgress.phase)


func _on_phase_changed(_old: RunProgress.Phase, new_phase: RunProgress.Phase) -> void:
	_apply_phase(new_phase)


func _apply_phase(phase: RunProgress.Phase) -> void:
	match phase:
		RunProgress.Phase.RUPTURE:
			_set_visual_state(&"rupture", 0.85)
		RunProgress.Phase.MUSIC_FINALE:
			_set_visual_state(&"finale", 1.0)
		RunProgress.Phase.LATE_GAME:
			_set_visual_state(&"late", 0.65)
		RunProgress.Phase.BOSS_ARC:
			_set_visual_state(&"boss", 0.5)
		RunProgress.Phase.CREDITS:
			_set_visual_state(&"calm", 0.0)
		_:
			_set_visual_state(&"stable", 0.25)


func _set_visual_state(state_name: StringName, intensity: float) -> void:
	_current_state = state_name
	_intensity = clampf(intensity, 0.0, 1.0)
	_apply_thruster_mod()
	_apply_shield_mod()
	visual_state_changed.emit(_current_state, _intensity)


func _apply_thruster_mod() -> void:
	if _thrusters == null:
		return
	var boost := 1.0 + _intensity * 0.35
	_thrusters.modulate = Color(boost, boost, boost + _intensity * 0.2, 1.0)


func _apply_shield_mod() -> void:
	if _shield == null:
		return
	if _shield.get("shader_time_parameter") == null:
		return
	# Shield shader time is driven internally; modulate for phase read.
	_shield.modulate = Color(1.0, 1.0, 1.0 + _intensity * 0.25, 1.0)


func get_visual_state() -> StringName:
	return _current_state
