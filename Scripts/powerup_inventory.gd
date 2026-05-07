extends Node
class_name PowerupInventory

signal powerup_applied(definition: PowerupDefinition, stacks: int)
signal powerup_expired(powerup_id: StringName)

@export_node_path("Node2D") var player_path: NodePath = ^".."
@export var action_pulse_cooldown: float = 0.65

var _player: Node2D = null
var _stacks: Dictionary = {}
var _timed_effects: Dictionary = {}
var _time_pulse_ready = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	set_process(true)

func _process(delta: float) -> void:
	var expired: Array[StringName] = []

	for id in _timed_effects.keys():
		var entry: Dictionary = _timed_effects[id]
		entry["remaining"] = float(entry["remaining"]) - delta
		_timed_effects[id] = entry
		if float(entry["remaining"]) <= 0.0:
			expired.append(id)

	for id in expired:
		_timed_effects.erase(id)
		_stacks.erase(id)
		powerup_expired.emit(id)

func apply_powerup(definition: PowerupDefinition) -> void:
	if definition == null or _player == null:
		return

	var id = definition.powerup_id
	var previous_stack = int(_stacks.get(id, 0))
	var current_stack = previous_stack

	if definition.stack_policy == PowerupDefinition.StackPolicy.MUTUALLY_EXCLUSIVE:
		current_stack = 1
	elif definition.stack_policy == PowerupDefinition.StackPolicy.REFRESH_DURATION:
		current_stack = max(1, current_stack)
	else:
		current_stack = mini(current_stack + 1, max(1, definition.max_stacks))

	_stacks[id] = current_stack

	if definition.duration > 0.0:
		_timed_effects[id] = {
			"definition": definition,
			"remaining": definition.duration,
		}

	if definition.stack_policy == PowerupDefinition.StackPolicy.STACKABLE and current_stack == previous_stack:
		powerup_applied.emit(definition, current_stack)
		return

	_apply_effect(definition, current_stack)
	powerup_applied.emit(definition, current_stack)

func trigger_player_action() -> void:
	if _player == null:
		return

	var now = Time.get_ticks_msec() / 1000.0
	if now < _time_pulse_ready:
		return

	var time_stack = _get_stack_for_effect(&"time_fracture_pulse")
	if time_stack <= 0:
		return

	_time_pulse_ready = now + action_pulse_cooldown
	var pulse_radius = 320.0 + 70.0 * float(time_stack - 1)
	var slow_multiplier = maxf(0.34, 0.52 - 0.06 * float(time_stack - 1))
	var duration = 0.75 + 0.16 * float(time_stack - 1)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_2d = enemy as Node2D
		if enemy_2d == null or not is_instance_valid(enemy_2d):
			continue
		if enemy_2d.global_position.distance_squared_to(_player.global_position) > pulse_radius * pulse_radius:
			continue

		CombatStatus.apply_local_slow(enemy_2d, slow_multiplier, duration)

func get_stack_count(powerup_id: StringName) -> int:
	return int(_stacks.get(powerup_id, 0))

func _apply_effect(definition: PowerupDefinition, stacks: int) -> void:
	match definition.effect_type:
		&"singularity_amplifier":
			if _player.get("gravity_constant") != null:
				_player.set("gravity_constant", float(_player.get("gravity_constant")) + definition.amount)
			if _player.get("gravity_pull_radius") != null:
				_player.set("gravity_pull_radius", float(_player.get("gravity_pull_radius")) + definition.radius)
			if _player.get("recoil_instability") != null:
				_player.set("recoil_instability", float(_player.get("recoil_instability")) + definition.secondary_amount)
		&"time_fracture_pulse":
			trigger_player_action()
		&"shield_overcharge":
			var shield = _player.get_node_or_null("Shield")
			if shield != null:
				if shield.has_method("restore_shield"):
					shield.call("restore_shield", definition.amount)
				if shield.has_method("add_temporary_max_bonus"):
					shield.call("add_temporary_max_bonus", definition.secondary_amount, definition.duration, &"shield_overcharge")
		&"orbital_tether_upgrade":
			if _player.get("max_gravity_anchors") != null:
				_player.set("max_gravity_anchors", int(_player.get("max_gravity_anchors")) + int(definition.amount))
			if _player.get("orbit_control_bonus") != null:
				_player.set("orbit_control_bonus", float(_player.get("orbit_control_bonus")) + definition.secondary_amount)

func _get_stack_for_effect(effect_type: StringName) -> int:
	var best = 0
	for id in _stacks.keys():
		var entry = _timed_effects.get(id, {})
		var definition = entry.get("definition", null) as PowerupDefinition
		if definition == null:
			definition = PowerupLibrary.get_definition(id)
		if definition != null and definition.effect_type == effect_type:
			best = max(best, int(_stacks[id]))
	return best
