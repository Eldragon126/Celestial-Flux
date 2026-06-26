extends Node
class_name OptionalChallengeDirector

signal rift_entered(rift_id: StringName, config: Resource)
signal rift_retried(rift_id: StringName)
signal rift_failed(rift_id: StringName, reason: StringName)
signal rift_cleared(rift_id: StringName, clear_time: float, perfect: bool)
signal rift_exited(rift_id: StringName)
signal shard_collected(shard_id: StringName, data: Dictionary)
signal blackbox_tape_collected(tape_id: StringName, unlocks: Array[String])
signal style_contract_selected(contract_id: StringName)

const GRAVITY_FLIP_SCRIPT := preload("res://Scripts/OptionalGameplay/personal_gravity_flip_component.gd")
const STYLE_TRACKER_SCRIPT := preload("res://Scripts/OptionalGameplay/style_contract_tracker.gd")
const GHOST_ECHO_SCRIPT := preload("res://Scripts/OptionalGameplay/anomaly_ghost_echo.gd")
const RIFT_CONFIG_SCRIPT := preload("res://Scripts/OptionalGameplay/anomaly_rift_config.gd")
const STYLE_CONFIG_SCRIPT := preload("res://Scripts/OptionalGameplay/style_contract_config.gd")
const RIFT_RULE_NO_THRUST := 0
const RIFT_RULE_ONE_DASH := 1
const RIFT_RULE_INVERTED_ORBIT := 2
const RIFT_RULE_PERSONAL_GRAVITY_FLIP := 3
const RIFT_RULE_TIME_SCAR := 4
const CONTRACT_TYPE_NO_DASH := 1
const CONTRACT_TYPE_PERFECT_ORBIT := 2
const CONTRACT_TYPE_PACIFIST := 3
const CONTRACT_TYPE_GLASS := 4
const CONTRACT_TYPE_SPEED := 5
const CONTRACT_TYPE_NO_THRUST := 6
const CONTRACT_TYPE_CLEAN_VECTOR := 7

@export var enabled: bool = true
@export var challenge_scene_path: String = "res://Nodes/OptionalGameplay/anomaly_rift_demo.tscn"
@export var return_scene_path: String = "res://Nodes/the_abyss.tscn"
@export var title_scene_path: String = "res://Nodes/title_screen.tscn"
@export var auto_restart_on_failure: bool = false
@export var auto_enter_selected_on_ready: bool = true
@export var install_player_components: bool = true
@export var show_debug_notices: bool = false
@export var default_contract_id: StringName = &""
@export var rift_configs: Array = []
@export var style_contracts: Array = []

var current_rift = null
var current_contract = null
var active: bool = false
var elapsed: float = 0.0

var _player: CharacterBody2D = null
var _player_start_position: Vector2 = Vector2.ZERO
var _player_start_rotation: float = 0.0
var _player_start_velocity: Vector2 = Vector2.ZERO
var _gravity_flip: Node = null
var _style_tracker: Node = null
var _ghost_echo: Node = null


func _ready() -> void:
	add_to_group("optional_challenge_director")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_default_data()
	if not String(default_contract_id).is_empty():
		select_style_contract(default_contract_id)
	if auto_enter_selected_on_ready and RunProgress != null:
		var selected_rift := StringName(str(RunProgress.arena_flags.get("selected_optional_rift", "")))
		var selected_contract := StringName(str(RunProgress.arena_flags.get("selected_style_contract", "")))
		if not String(selected_contract).is_empty():
			select_style_contract(selected_contract)
		if not String(selected_rift).is_empty():
			call_deferred("enter_rift", selected_rift)


func _process(delta: float) -> void:
	if not enabled or not active or current_rift == null:
		return
	elapsed += delta
	if current_contract != null and _style_tracker != null and _style_tracker.has_method("update_contract_time"):
		_style_tracker.call("update_contract_time", elapsed)
	if current_rift.duration_seconds > 0.0 and elapsed > current_rift.duration_seconds:
		fail_rift(&"time_limit")


func launch_rift_scene(rift_id: StringName, contract_id: StringName = &"") -> void:
	if RunProgress != null:
		RunProgress.set_selected_optional_challenge(rift_id, &"", contract_id)
	get_tree().change_scene_to_file(challenge_scene_path)


func enter_rift(rift_id: StringName, player_override: Node = null) -> bool:
	if not enabled:
		return false
	var config = get_rift_config(rift_id)
	if config == null:
		push_warning("OptionalChallengeDirector: unknown rift id %s" % String(rift_id))
		return false
	_resolve_player(player_override)
	if _player == null:
		return false
	current_rift = config
	current_rift.apply_rule_defaults()
	active = true
	elapsed = 0.0
	_capture_player_start()
	if install_player_components:
		_apply_player_rule_state(true)
	rift_entered.emit(config.rift_id, config)
	return true


func retry_rift() -> void:
	if current_rift == null:
		return
	_restore_player_start()
	elapsed = 0.0
	_apply_player_rule_state(true)
	if _style_tracker != null and _style_tracker.has_method("begin_tracking"):
		_style_tracker.call("begin_tracking", current_contract, current_rift)
	if _ghost_echo != null and _ghost_echo.has_method("restart_recording"):
		_ghost_echo.call("restart_recording")
	rift_retried.emit(current_rift.rift_id)


func fail_rift(reason: StringName = &"failed") -> void:
	if current_rift == null or not active:
		return
	active = false
	_apply_player_rule_state(false)
	rift_failed.emit(current_rift.rift_id, reason)
	if auto_restart_on_failure:
		await get_tree().create_timer(maxf(current_rift.retry_delay, 0.05)).timeout
		retry_rift()


func clear_rift(perfect: bool = false) -> void:
	if current_rift == null or not active:
		return
	var contract_id := StringName("")
	var contract_ok := true
	if _style_tracker != null and _style_tracker.has_method("is_contract_successful"):
		contract_ok = bool(_style_tracker.call("is_contract_successful"))
		if contract_ok and current_contract != null:
			contract_id = current_contract.contract_id
	if RunProgress != null:
		RunProgress.record_rift_cleared(current_rift.rift_id, elapsed, perfect and contract_ok, contract_id)
		if not String(current_rift.blackbox_unlock_id).is_empty():
			RunProgress.unlock_blackbox_challenge(current_rift.blackbox_unlock_id)
	if _ghost_echo != null and _ghost_echo.has_method("save_best_run"):
		_ghost_echo.call("save_best_run", current_rift.rift_id, elapsed)
	active = false
	_apply_player_rule_state(false)
	rift_cleared.emit(current_rift.rift_id, elapsed, perfect and contract_ok)


func exit_rift(to_title: bool = false) -> void:
	var rift_id: StringName = current_rift.rift_id if current_rift != null else StringName("")
	active = false
	_apply_player_rule_state(false)
	current_rift = null
	if rift_id != StringName(""):
		rift_exited.emit(rift_id)
	get_tree().change_scene_to_file(title_scene_path if to_title else return_scene_path)


func select_style_contract(contract_id: StringName) -> void:
	current_contract = get_style_contract(contract_id)
	if RunProgress != null:
		RunProgress.arena_flags["selected_style_contract"] = String(contract_id)
	style_contract_selected.emit(contract_id)


func mark_shard_collected(shard_id: StringName, data: Dictionary = {}) -> void:
	if RunProgress != null:
		RunProgress.record_anomaly_shard_collected(shard_id, data)
	shard_collected.emit(shard_id, data)


func mark_blackbox_tape_collected(tape_id: StringName, unlocks: Array[String] = []) -> void:
	if RunProgress != null:
		RunProgress.record_blackbox_tape_collected(tape_id, unlocks)
	blackbox_tape_collected.emit(tape_id, unlocks)


func get_rift_config(rift_id: StringName):
	_ensure_default_data()
	for config in rift_configs:
		if config != null and config.rift_id == rift_id:
			return config
	return null


func get_style_contract(contract_id: StringName):
	_ensure_default_data()
	for contract in style_contracts:
		if contract != null and contract.contract_id == contract_id:
			return contract
	return null


func get_archive_rows() -> Array[Dictionary]:
	_ensure_default_data()
	var summary := RunProgress.get_optional_challenge_summary() if RunProgress != null else {}
	var rows: Array[Dictionary] = []
	for config in rift_configs:
		if config == null:
			continue
		var row: Dictionary = config.call("get_summary")
		row["cleared"] = bool(summary.get("cleared_rifts", {}).get(String(config.rift_id), false))
		row["best_time"] = float(summary.get("best_times", {}).get(String(config.rift_id), 0.0))
		rows.append(row)
	return rows


func _resolve_player(player_override: Node = null) -> void:
	if player_override is CharacterBody2D:
		_player = player_override as CharacterBody2D
		return
	if _player != null and is_instance_valid(_player):
		return
	_player = MultiplayerTargeting.local_player(get_tree()) as CharacterBody2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as CharacterBody2D


func _capture_player_start() -> void:
	if _player == null:
		return
	_player_start_position = _player.global_position
	_player_start_rotation = _player.global_rotation
	_player_start_velocity = _player.velocity


func _restore_player_start() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.global_position = _player_start_position
	_player.global_rotation = _player_start_rotation
	_player.velocity = _player_start_velocity
	if _player.has_meta(&"anomaly_dash_used"):
		_player.remove_meta(&"anomaly_dash_used")
	if _player.get("can_dash") != null:
		_player.set("can_dash", true)


func _apply_player_rule_state(apply: bool) -> void:
	if _player == null or current_rift == null:
		return
	_player.set_meta(&"anomaly_no_thrust", apply and current_rift.disable_normal_thrust)
	_player.set_meta(&"anomaly_one_dash_only", apply and current_rift.one_dash_only)
	_player.set_meta(&"anomaly_rift_active", apply)
	if apply and (current_rift.enable_personal_gravity_flip or current_rift.inverted_orbit_for_player):
		_ensure_gravity_flip()
		if _gravity_flip != null and _gravity_flip.has_method("configure_from_rift"):
			_gravity_flip.call("configure_from_rift", current_rift)
	elif _gravity_flip != null and _gravity_flip.has_method("set_enabled"):
		_gravity_flip.call("set_enabled", false)
	_ensure_style_tracker()
	if _style_tracker != null and _style_tracker.has_method("begin_tracking"):
		_style_tracker.call("begin_tracking", current_contract, current_rift if apply else null)
	if apply and (current_rift.time_scar_trail_enabled or current_rift.ghost_echo_required):
		_ensure_ghost_echo()
		if _ghost_echo != null and _ghost_echo.has_method("configure_from_rift"):
			_ghost_echo.call("configure_from_rift", current_rift)
	elif _ghost_echo != null and _ghost_echo.has_method("set_recording_enabled"):
		_ghost_echo.call("set_recording_enabled", false)


func _ensure_gravity_flip() -> void:
	if _gravity_flip != null and is_instance_valid(_gravity_flip):
		return
	_gravity_flip = _player.get_node_or_null("PersonalGravityFlipComponent")
	if _gravity_flip == null:
		_gravity_flip = GRAVITY_FLIP_SCRIPT.new()
		_gravity_flip.name = "PersonalGravityFlipComponent"
		_player.add_child(_gravity_flip)


func _ensure_style_tracker() -> void:
	if _style_tracker != null and is_instance_valid(_style_tracker):
		return
	var root := get_tree().current_scene
	if root == null:
		return
	_style_tracker = root.get_node_or_null("StyleContractTracker")
	if _style_tracker == null:
		_style_tracker = STYLE_TRACKER_SCRIPT.new()
		_style_tracker.name = "StyleContractTracker"
		root.add_child(_style_tracker)


func _ensure_ghost_echo() -> void:
	if _ghost_echo != null and is_instance_valid(_ghost_echo):
		return
	var root := get_tree().current_scene
	if root == null:
		return
	_ghost_echo = root.get_node_or_null("AnomalyGhostEcho")
	if _ghost_echo == null:
		_ghost_echo = GHOST_ECHO_SCRIPT.new()
		_ghost_echo.name = "AnomalyGhostEcho"
		root.add_child(_ghost_echo)


func _ensure_default_data() -> void:
	if rift_configs.is_empty():
		rift_configs = _make_default_rifts()
	if style_contracts.is_empty():
		style_contracts = _make_default_contracts()


func _make_default_rifts() -> Array:
	var result: Array = []
	result.append(_rift(&"no_thrust_rift", "NO-THRUST RIFT", RIFT_RULE_NO_THRUST, "THRUST LOCKED // SLINGSHOT ONLY", Vector2(1180.0, -20.0)))
	result.append(_rift(&"one_dash_rift", "ONE-DASH RIFT", RIFT_RULE_ONE_DASH, "ONE DASH // RECHARGE CRYSTALS RESET IT", Vector2(1320.0, 180.0)))
	result.append(_rift(&"inverted_orbit_rift", "INVERTED ORBIT RIFT", RIFT_RULE_INVERTED_ORBIT, "PLAYER POLARITY INVERTED", Vector2(1240.0, -220.0)))
	result.append(_rift(&"personal_gravity_flip_rift", "PERSONAL GRAVITY FLIP RIFT", RIFT_RULE_PERSONAL_GRAVITY_FLIP, "FLIP POLARITY WITH F", Vector2(1460.0, 0.0)))
	result.append(_rift(&"time_scar_rift", "TIME SCAR RIFT", RIFT_RULE_TIME_SCAR, "YOUR ROUTE BECOMES DANGER", Vector2(1260.0, 260.0)))
	return result


func _rift(id: StringName, label: String, rule: int, instruction: String, exit_position: Vector2):
	var config := RIFT_CONFIG_SCRIPT.new()
	config.rift_id = id
	config.display_name = label
	config.rule = rule
	config.instruction_text = instruction
	config.exit_position = exit_position
	config.apply_rule_defaults()
	match rule:
		RIFT_RULE_ONE_DASH:
			config.shard_positions = PackedVector2Array([Vector2(520.0, 160.0), Vector2(900.0, -120.0)])
		RIFT_RULE_PERSONAL_GRAVITY_FLIP:
			config.gravity_flip_mode = 0
			config.tunnel_positions = PackedVector2Array([Vector2(760.0, 0.0)])
		RIFT_RULE_TIME_SCAR:
			config.time_scar_trail_enabled = true
			config.shard_positions = PackedVector2Array([Vector2(420.0, -220.0), Vector2(980.0, 220.0)])
	return config


func _make_default_contracts() -> Array:
	var result: Array = []
	result.append(_contract(&"no_dash", "NO DASH CONTRACT", CONTRACT_TYPE_NO_DASH))
	result.append(_contract(&"perfect_orbit", "PERFECT ORBIT CONTRACT", CONTRACT_TYPE_PERFECT_ORBIT))
	result.append(_contract(&"pacifist", "PACIFIST CONTRACT", CONTRACT_TYPE_PACIFIST))
	result.append(_contract(&"glass", "GLASS CONTRACT", CONTRACT_TYPE_GLASS))
	result.append(_contract(&"speed", "SPEED CONTRACT", CONTRACT_TYPE_SPEED))
	result.append(_contract(&"no_thrust", "NO THRUST CONTRACT", CONTRACT_TYPE_NO_THRUST))
	result.append(_contract(&"clean_vector", "CLEAN VECTOR CONTRACT", CONTRACT_TYPE_CLEAN_VECTOR))
	return result


func _contract(id: StringName, label: String, type: int):
	var contract := STYLE_CONFIG_SCRIPT.new()
	contract.contract_id = id
	contract.display_name = label
	contract.contract_type = type
	if type == CONTRACT_TYPE_GLASS:
		contract.failure_fails_rift = true
	if type == CONTRACT_TYPE_SPEED:
		contract.time_limit_seconds = 32.0
	return contract
