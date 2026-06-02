extends CanvasLayer
class_name GameplayTeachingDirector

## Lightweight run messaging: first-contact fantasy, readable law prompts,
## and death lessons. Kept separate from player/combat systems.

@export var opening_duration: float = 30.0
@export var prompt_interval: float = 5.2
@export var death_lesson_duration: float = 2.15
@export var max_projectile_warning_count: int = 90

var _player: Node2D = null
var _resonance_manager: Node = null
var _time_manager: Node = null
var _elapsed := 0.0
var _prompt_elapsed := 99.0
var _death_lesson_time := 0.0
var _prompt_index := 0
var _death_mode := false
var _opening_prompts := [
	"VECTOR ANOMALY ONLINE",
	"ORBIT THE WELL",
	"SLINGSHOT TO SURVIVE",
	"TIME BENDS UNDER PRESSURE",
	"READ THE LAW, THEN BREAK IT",
]

@onready var _root: Control = $Root
@onready var _prompt_label: Label = $Root/PromptLabel


func _ready() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_references()
	_connect_player()
	_show_prompt(_opening_prompts[0], Color(0.42, 1.0, 0.9, 1.0))


func _process(delta: float) -> void:
	_elapsed += delta
	_prompt_elapsed += delta
	_resolve_references()
	_update_death_lesson(delta)
	if _death_mode:
		return
	_update_opening_prompt()
	_update_context_prompt()


func _resolve_references() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		_connect_player()

	var scene := get_tree().current_scene
	if scene == null:
		return
	if _resonance_manager == null or not is_instance_valid(_resonance_manager):
		_resonance_manager = scene.find_child("GravityResonanceManager", true, false)
	if _time_manager == null or not is_instance_valid(_time_manager):
		_time_manager = scene.find_child("TimeDilationManager", true, false)


func _connect_player() -> void:
	if _player == null or not _player.has_signal("death_lesson_generated"):
		return
	var callable := Callable(self, "_on_death_lesson_generated")
	if not _player.is_connected("death_lesson_generated", callable):
		_player.connect("death_lesson_generated", callable)


func _update_opening_prompt() -> void:
	if _elapsed > opening_duration or _prompt_elapsed < prompt_interval:
		return

	_prompt_elapsed = 0.0
	_prompt_index = (_prompt_index + 1) % _opening_prompts.size()
	_show_prompt(_opening_prompts[_prompt_index], Color(0.42, 1.0, 0.9, 1.0))


func _update_context_prompt() -> void:
	if _elapsed <= opening_duration:
		return
	if _prompt_elapsed < prompt_interval:
		return

	var boss_hint := _upcoming_boss_hint()
	if not boss_hint.is_empty():
		_prompt_elapsed = 0.0
		_show_prompt(boss_hint, Color(1.0, 0.82, 0.28, 1.0))
		return

	var projectile_count := _projectile_count()
	if projectile_count >= max_projectile_warning_count:
		_prompt_elapsed = 0.0
		_show_prompt("CHAOS SPIKE: TRUST ORBITS, NOT NOISE", Color(1.0, 0.76, 0.32, 1.0))
		return

	if _time_manager != null and bool(_time_manager.get("is_dilating")):
		_prompt_elapsed = 0.0
		_show_prompt("TIME TEAR ACTIVE", Color(0.78, 0.48, 1.0, 1.0))
		return

	if _player != null and _resonance_manager != null and _resonance_manager.has_method("get_resonance_zone_at_position"):
		var zone_value: Variant = _resonance_manager.call("get_resonance_zone_at_position", _player.global_position)
		if typeof(zone_value) == TYPE_DICTIONARY:
			var zone: Dictionary = zone_value
			if not zone.is_empty():
				_prompt_elapsed = 0.0
				_show_prompt(
					"%s LAW: %s" % [
						String(zone.get("zone_display_name", "FIELD")).to_upper(),
						String(zone.get("zone_rule_hint", "READ THE VECTOR")).to_upper(),
					],
					zone.get("zone_color", Color(0.42, 1.0, 0.9, 1.0))
				)


func _on_death_lesson_generated(lesson: String) -> void:
	_death_mode = true
	_death_lesson_time = death_lesson_duration
	_show_prompt(lesson, Color(1.0, 0.34, 0.24, 1.0))


func _update_death_lesson(delta: float) -> void:
	if not _death_mode:
		return

	_death_lesson_time -= delta
	var color := _prompt_label.modulate
	color.a = clampf(_death_lesson_time / maxf(death_lesson_duration * 0.32, 0.01), 0.0, 1.0)
	_prompt_label.modulate = color


func _show_prompt(text: String, color: Color) -> void:
	_prompt_label.text = text
	_prompt_label.modulate = color
	_root.visible = true


func _upcoming_boss_hint() -> String:
	if RunProgress == null:
		return ""
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var wave_director := scene.find_child("WaveDirector", true, false)
	if wave_director == null or not wave_director.has_method("get_current_wave"):
		return ""
	var next_wave := int(wave_director.call("get_current_wave")) + 1
	if not RunProgress.is_boss_milestone_wave(next_wave):
		return ""
	var hints := [
		"WARDEN APPROACHES: READ RESONANCE FIELDS",
		"ACCRETION CORE: DODGE COMPRESSION DEBRIS",
		"NULL SERAPH: WATCH TIME DISRUPTION LANES",
		"MAGNETAR TWINS: TRACK PUSH/PULL WINDOWS",
		"RIFT WEAVER: RIFT LANES MEET TIDE POCKETS",
		"POLYMORPH: LAWS WILL SHIFT MID-FIGHT",
		"CENTRIFUGE MARSHAL: DODGE ROTATING SHEAR HALOS",
	]
	var index := 0
	for milestone in RunProgress.BOSS_MILESTONE_WAVES:
		if milestone == next_wave:
			break
		index += 1
	return hints[mini(index, hints.size() - 1)]


func _projectile_count() -> int:
	if RuntimeRegistry != null:
		return (
			RuntimeRegistry.get_count(&"Projectiles")
			+ RuntimeRegistry.get_count(&"enemy_projectiles")
			+ RuntimeRegistry.get_count(&"player_projectiles")
		)
	var count := get_tree().get_nodes_in_group("Projectiles").size()
	count += get_tree().get_nodes_in_group("enemy_projectiles").size()
	count += get_tree().get_nodes_in_group("player_projectiles").size()
	return count
