extends Node
class_name NetworkSessionManager

signal session_status_changed(status: Dictionary)
signal peer_roster_changed(roster: Array)
signal network_run_started(config: Dictionary)
signal network_wave_state_received(state: Dictionary)
signal network_mod_hook_received(hook_id: StringName, entry_id: StringName, data: Dictionary)
signal network_weapon_field_received(data: Dictionary)
signal session_error(message: String)

enum SessionMode {
	OFFLINE,
	LAN_HOST,
	LAN_CLIENT,
	STEAM_HOST,
	STEAM_CLIENT,
}

const DEFAULT_PORT := 28942
const DEFAULT_MAX_PEERS := 4
const NETWORK_PROTOCOL_VERSION := 7
const RUN_SCENE_PATH := "res://Nodes/the_abyss.tscn"
const RUN_LOADING_SCENE_PATH := "res://Nodes/run_loading_screen.tscn"
const TITLE_SCENE_PATH := "res://Nodes/title_screen.tscn"
const CAMPAIGN_SCENE_PATH := "res://Nodes/campaign_mode.tscn"
const KING_OF_THE_HILL_SCENE_PATH := "res://Nodes/king_of_the_hill_mode.tscn"
const PLAYER_SCENE := preload("res://Nodes/player.tscn")
const PROJECTILE_FALLBACK_SCENE_PATH := "res://Nodes/projectile.tscn"
const MOD_MANIFEST_FILE_NAME := "vector_anomaly_mod.json"
const MOD_MANIFEST_FILE_NAMES: Array[String] = ["vector_anomaly_mod.json", "mod.json"]
const MOD_SCAN_ROOTS: Array[String] = ["res://Mods", "user://mods"]
const MOD_EXTERNAL_ROOT_NAMES: Array[String] = ["mods", "Mods"]
const MOD_SCAN_DEPTH_LIMIT := 4
const LOCAL_ONLY_MOD_BUCKETS := ["mod_palettes", "creator_notes", "hud_badges", "sfx", "music"]
const HOOKABLE_MOD_BUCKETS := ["law_weaves", "anomaly_recipes", "challenge_cards"]
const GAMEPLAY_MOD_BUCKETS := [
	"arenas",
	"waves",
	"upgrades",
	"rules",
	"powerups",
	"weapons",
	"enemies",
	"bosses",
	"arena_events",
	"celestial_bodies",
	"physics_drops",
	"materials",
	"prefabs",
	"entities",
	"gamemodes",
	"maps",
	"law_weaves",
	"anomaly_recipes",
	"challenge_cards",
]
const PROJECTILE_PAYLOAD_KEYS: Array[String] = [
	"weapon_id",
	"display_name",
	"initial_speed",
	"damage_min",
	"damage_max",
	"gravity_constant",
	"gravity_pull_radius",
	"player_gravity_deadzone_radius",
	"windowkill_visual_scale",
	"vector_core_color",
	"vector_trail_fade_color",
	"weapon_axis_impulse",
	"weapon_temporal_slow_multiplier",
	"weapon_temporal_slow_duration",
	"weapon_pierce_count",
	"weapon_resonance_zone_type",
	"weapon_resonance_radius",
	"weapon_resonance_intensity",
	"weapon_curve_force",
	"weapon_curve_side",
	"weapon_curve_frequency",
	"weapon_planet_damage",
	"weapon_radial_impulse",
	"weapon_tangent_impulse",
	"weapon_field_radius",
	"weapon_field_force",
	"weapon_field_damage",
	"weapon_field_slow_multiplier",
	"weapon_field_slow_duration",
	"weapon_field_max_targets",
	"weapon_scar_type",
	"weapon_scar_radius",
	"weapon_scar_intensity",
	"weapon_scar_duration",
	"phase_offset",
	"relativistic_rail_stacks",
	"vacuum_collapse_stacks",
]
const PLAYER_COLORS: Array[Color] = [
	Color(0.08, 0.88, 1.0, 1.0),
	Color(1.0, 0.28, 0.58, 1.0),
	Color(0.72, 1.0, 0.28, 1.0),
	Color(1.0, 0.76, 0.18, 1.0),
]

@export_group("Network Performance")
@export_range(0.1, 5.0, 0.05) var heartbeat_interval: float = 1.0

@export_group("Steam Multiplayer")
@export var steam_auto_initialize_singleton: bool = true
@export var steam_pump_callbacks: bool = true
@export_range(1, 16, 1) var steam_default_max_peers: int = DEFAULT_MAX_PEERS
@export_enum("Private:0", "Friends Only:1", "Public:2", "Invisible:3") var steam_default_lobby_type: int = 2
@export var steam_host_method_names: Array[String] = ["create_lobby", "create_host", "create_hosted_lobby", "host_lobby"]
@export var steam_join_method_names: Array[String] = ["connect_lobby", "join_lobby", "create_client"]
@export var steam_lobby_id_methods: Array[String] = ["get_lobby_id", "get_lobby", "get_current_lobby_id"]
@export var steam_lobby_name: String = "VECTOR ANOMALY"
@export var steam_lobby_protocol_key: String = "net_protocol"
@export var steam_lobby_mod_key: String = "mod_signature"
@export var steam_lobby_scene_key: String = "scene_path"
@export var steam_lobby_name_key: String = "name"
@export var steam_lobby_id_pending_text: String = "LOBBY PENDING"
@export var steam_adapter_missing_message: String = "STEAM NEEDS GODOTSTEAM MULTIPLAYERPEER"

var mode: SessionMode = SessionMode.OFFLINE
var local_player_name: String = "VECTOR"
var local_peer_id: int = 1
var listen_port: int = DEFAULT_PORT
var max_peer_count: int = DEFAULT_MAX_PEERS
var host_address: String = ""

var _peer: MultiplayerPeer = null
var _peer_records: Dictionary = {}
var _player_nodes_by_peer: Dictionary = {}
var _run_config: Dictionary = {}
var _last_wave_state: Dictionary = {}
var _run_in_progress := false
var _base_spawn_position := Vector2(135.0, 227.0)
var _last_error := ""
var _status_label := "OFFLINE"
var _last_heartbeat_sent := 0.0
var _heartbeat_nonce := 1
var _peer_ping_ms: Dictionary = {}
var _session_ready_ack: Dictionary = {}
var _steam_lobby_id: int = 0
var _steam_peer_object: Object = null
var _player_scan_buffer: Array[Node2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_connect_multiplayer_signals()
	_reset_roster()
	_publish_status()


func _process(_delta: float) -> void:
	if steam_pump_callbacks:
		_pump_steam_callbacks()
	if not is_network_active():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_heartbeat_sent < maxf(heartbeat_interval, 0.1):
		return
	_last_heartbeat_sent = now
	_heartbeat_nonce += 1
	var sent_msec := Time.get_ticks_msec()
	if multiplayer.is_server():
		_rpc_heartbeat_ping.rpc(sent_msec, _heartbeat_nonce)
	else:
		_rpc_heartbeat_ping.rpc_id(1, sent_msec, _heartbeat_nonce)


func host_and_play(player_name: String, port: int = DEFAULT_PORT, peer_limit: int = DEFAULT_MAX_PEERS, seed_override: int = 0) -> int:
	var err := start_lan_host(player_name, port, peer_limit)
	if err != OK:
		return err
	_begin_host_run(seed_override)
	return OK


func host_scene_and_play(player_name: String, scene_path: String, port: int = DEFAULT_PORT, peer_limit: int = DEFAULT_MAX_PEERS, seed_override: int = 0, mode_flags: Dictionary = {}) -> int:
	var err := start_lan_host(player_name, port, peer_limit)
	if err != OK:
		return err
	_begin_host_run(seed_override, scene_path, mode_flags)
	return OK


func start_hosted_scene_run(scene_path: String, seed_override: int = 0, mode_flags: Dictionary = {}) -> int:
	if not is_network_active() or not multiplayer.is_server():
		_fail_session("ONLY THE HOST CAN START A NETWORK SCENE")
		return ERR_UNAUTHORIZED
	_begin_host_run(seed_override, scene_path, mode_flags)
	return OK


func restart_hosted_run() -> int:
	if not is_network_active() or not multiplayer.is_server():
		_fail_session("ONLY THE HOST CAN RESTART NETWORK RUN")
		return ERR_UNAUTHORIZED
	var scene_path := String(_run_config.get("scene_path", RUN_SCENE_PATH))
	var mode_flags := _network_mode_flags_from_config(_run_config)
	_begin_host_run(0, scene_path, mode_flags)
	return OK


func start_lan_host(player_name: String, port: int = DEFAULT_PORT, peer_limit: int = DEFAULT_MAX_PEERS) -> int:
	leave_session(false)
	local_player_name = _normalize_player_name(player_name)
	listen_port = clampi(port, 1, 65535)
	max_peer_count = clampi(peer_limit, 1, 16)
	host_address = get_lan_address_hint()

	var enet := ENetMultiplayerPeer.new()
	var client_capacity := maxi(max_peer_count - 1, 1)
	var err := enet.create_server(listen_port, client_capacity)
	if err != OK:
		_fail_session("LAN HOST FAILED: %s" % error_string(err))
		return err

	_peer = enet
	multiplayer.multiplayer_peer = _peer
	mode = SessionMode.LAN_HOST
	local_peer_id = _effective_local_peer_id()
	_status_label = "LAN HOST ONLINE"
	_last_error = ""
	_reset_roster()
	_upsert_peer_record(local_peer_id, local_player_name)
	_publish_roster()
	_publish_status()
	return OK


func join_lan_game(address: String, port: int = DEFAULT_PORT, player_name: String = "VECTOR") -> int:
	leave_session(false)
	local_player_name = _normalize_player_name(player_name)
	host_address = address.strip_edges()
	listen_port = clampi(port, 1, 65535)

	if host_address.is_empty():
		_fail_session("JOIN FAILED: no host address")
		return ERR_INVALID_PARAMETER

	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(host_address, listen_port)
	if err != OK:
		_fail_session("JOIN FAILED: %s" % error_string(err))
		return err

	_peer = enet
	multiplayer.multiplayer_peer = _peer
	mode = SessionMode.LAN_CLIENT
	local_peer_id = _effective_local_peer_id()
	_status_label = "JOINING LAN HOST"
	_last_error = ""
	_peer_records.clear()
	_publish_status()
	return OK


func leave_session(publish: bool = true) -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	mode = SessionMode.OFFLINE
	local_peer_id = 1
	host_address = ""
	_run_in_progress = false
	_run_config.clear()
	_last_wave_state.clear()
	_player_nodes_by_peer.clear()
	_peer_ping_ms.clear()
	_session_ready_ack.clear()
	_steam_lobby_id = 0
	_steam_peer_object = null
	_status_label = "OFFLINE"
	_reset_roster()
	if publish:
		_publish_roster()
		_publish_status()


func is_network_active() -> bool:
	return mode != SessionMode.OFFLINE and _peer != null


func is_lan_host() -> bool:
	return mode == SessionMode.LAN_HOST and multiplayer.is_server()


func is_steam_host() -> bool:
	return mode == SessionMode.STEAM_HOST and multiplayer.is_server()


func is_session_host() -> bool:
	return is_network_active() and multiplayer.is_server()


func is_local_peer(peer_id: int) -> bool:
	return int(peer_id) == _effective_local_peer_id()


func get_status_snapshot() -> Dictionary:
	return {
		"active": is_network_active(),
		"mode": mode,
		"mode_label": _mode_label(),
		"status": _status_label,
		"error": _last_error,
		"local_peer_id": _effective_local_peer_id(),
		"peer_count": _sorted_peer_records().size(),
		"port": listen_port,
		"address": host_address,
		"lan_hint": get_lan_address_hint(),
		"run_in_progress": _run_in_progress,
		"network_protocol": NETWORK_PROTOCOL_VERSION,
		"mod_signature": _local_mod_signature(),
		"diagnostics": get_network_diagnostics(),
		"connection_quality": _connection_quality_label(),
		"readiness": get_multiplayer_readiness_snapshot(),
		"steam_available": is_steam_multiplayer_available(),
		"steam_message": get_steam_support_message(),
		"steam_lobby_id": _steam_lobby_id,
		"steam_lobby_text": _steam_lobby_text(),
	}


func get_network_diagnostics() -> Dictionary:
	return {
		"peer_ping_ms": _peer_ping_ms.duplicate(true),
		"average_ping_ms": _average_peer_ping_ms(),
		"quality": _connection_quality_label(),
		"run_seed": int(_run_config.get("seed", 0)),
		"last_wave": int(_last_wave_state.get("wave", 0)),
		"heartbeat_nonce": _heartbeat_nonce,
		"protocol": NETWORK_PROTOCOL_VERSION,
		"steam_lobby_id": _steam_lobby_id,
	}


func get_multiplayer_readiness_snapshot() -> Dictionary:
	return {
		"protocol": NETWORK_PROTOCOL_VERSION,
		"transport": _mode_label(),
		"lan_ready": true,
		"steam_transport_available": is_steam_multiplayer_available(),
		"mod_signature": _local_mod_signature(),
		"late_join_reconciliation": not _run_config.is_empty() and (_last_wave_state.has("wave") or not _run_in_progress),
		"host_authoritative": not is_network_active() or multiplayer.is_server() or mode == SessionMode.LAN_CLIENT or mode == SessionMode.STEAM_CLIENT,
		"peer_count": _sorted_peer_records().size(),
		"average_ping_ms": _average_peer_ping_ms(),
		"quality": _connection_quality_label(),
		"platform": OS.get_name(),
	}


func get_roster_snapshot() -> Array:
	return _roster_array()


func get_lan_address_hint() -> String:
	var addresses := IP.get_local_addresses()
	for address in addresses:
		if not address.contains("."):
			continue
		if address.begins_with("127.") or address.begins_with("169.254."):
			continue
		return address
	return "127.0.0.1"


func is_steam_multiplayer_available() -> bool:
	return ClassDB.class_exists("SteamMultiplayerPeer")


func get_steam_support_message() -> String:
	if not is_steam_multiplayer_available():
		return steam_adapter_missing_message
	if _steam_lobby_id > 0:
		return "STEAM LOBBY %d" % _steam_lobby_id
	if mode == SessionMode.STEAM_HOST:
		return "STEAM HOST READY"
	if mode == SessionMode.STEAM_CLIENT:
		return "STEAM CLIENT READY"
	return "STEAM TRANSPORT READY"


func host_steam_lobby(player_name: String, seed_override: int = 0) -> int:
	return host_steam_scene_and_play(player_name, RUN_SCENE_PATH, seed_override, {})


func host_steam_scene_and_play(player_name: String, scene_path: String, seed_override: int = 0, mode_flags: Dictionary = {}) -> int:
	var err := start_steam_host(player_name, steam_default_max_peers)
	if err != OK:
		return err
	_begin_host_run(seed_override, scene_path, mode_flags)
	return OK


func start_steam_host(player_name: String, peer_limit: int = DEFAULT_MAX_PEERS) -> int:
	leave_session(false)
	local_player_name = _normalize_player_name(player_name)
	max_peer_count = clampi(peer_limit, 1, 16)
	listen_port = 0
	host_address = steam_lobby_id_pending_text

	var runtime_error := _prepare_steam_runtime()
	if not runtime_error.is_empty():
		_fail_session("STEAM HOST FAILED: %s" % runtime_error)
		return ERR_UNAVAILABLE

	var peer_object := _instantiate_steam_peer()
	if peer_object == null:
		_fail_session("STEAM HOST FAILED: %s" % steam_adapter_missing_message)
		return ERR_UNAVAILABLE

	var err := _create_steam_host_peer(peer_object, max_peer_count)
	if err != OK:
		_fail_session("STEAM HOST FAILED: %s" % _steam_error_text(err))
		return err

	var steam_peer := peer_object as MultiplayerPeer
	if steam_peer == null:
		_fail_session("STEAM HOST FAILED: SteamMultiplayerPeer is not a MultiplayerPeer")
		return ERR_UNAVAILABLE

	_peer = steam_peer
	_steam_peer_object = peer_object
	multiplayer.multiplayer_peer = _peer
	mode = SessionMode.STEAM_HOST
	local_peer_id = _effective_local_peer_id()
	_status_label = "STEAM HOST ONLINE"
	_last_error = ""
	_reset_roster()
	_upsert_peer_record(local_peer_id, local_player_name)
	_connect_steam_signals()
	_refresh_steam_lobby_state()
	_publish_roster()
	_publish_status()
	return OK


func join_steam_lobby(lobby_id: int, player_name: String = "VECTOR") -> int:
	leave_session(false)
	local_player_name = _normalize_player_name(player_name)
	_steam_lobby_id = lobby_id
	host_address = str(lobby_id)
	listen_port = 0

	if lobby_id <= 0:
		_fail_session("STEAM JOIN FAILED: no lobby id")
		return ERR_INVALID_PARAMETER

	var runtime_error := _prepare_steam_runtime()
	if not runtime_error.is_empty():
		_fail_session("STEAM JOIN FAILED: %s" % runtime_error)
		return ERR_UNAVAILABLE

	var peer_object := _instantiate_steam_peer()
	if peer_object == null:
		_fail_session("STEAM JOIN FAILED: %s" % steam_adapter_missing_message)
		return ERR_UNAVAILABLE

	var err := _connect_steam_lobby_peer(peer_object, lobby_id)
	if err != OK:
		_fail_session("STEAM JOIN FAILED: %s" % _steam_error_text(err))
		return err

	var steam_peer := peer_object as MultiplayerPeer
	if steam_peer == null:
		_fail_session("STEAM JOIN FAILED: SteamMultiplayerPeer is not a MultiplayerPeer")
		return ERR_UNAVAILABLE

	_peer = steam_peer
	_steam_peer_object = peer_object
	multiplayer.multiplayer_peer = _peer
	mode = SessionMode.STEAM_CLIENT
	local_peer_id = _effective_local_peer_id()
	_status_label = "JOINING STEAM LOBBY"
	_last_error = ""
	_peer_records.clear()
	_connect_steam_signals()
	_refresh_steam_lobby_state()
	_publish_status()
	return OK


func _prepare_steam_runtime() -> String:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return steam_adapter_missing_message
	var steam := _steam_singleton()
	if steam_auto_initialize_singleton and steam != null:
		for method_name in ["steamInitEx", "steam_init_ex", "steamInit", "steam_init"]:
			if steam.has_method(method_name) and _method_accepts_arg_count(steam, method_name, 0):
				steam.callv(method_name, [])
				break
	return ""


func _instantiate_steam_peer() -> Object:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	var peer_object: Object = ClassDB.instantiate("SteamMultiplayerPeer") as Object
	return peer_object as Object


func _create_steam_host_peer(peer_object: Object, peer_limit: int) -> int:
	var argument_sets: Array = [
		[steam_default_lobby_type, peer_limit],
		[peer_limit],
		[],
	]
	return _call_first_steam_peer_method(peer_object, steam_host_method_names, argument_sets)


func _connect_steam_lobby_peer(peer_object: Object, lobby_id: int) -> int:
	var argument_sets: Array = [
		[lobby_id],
		[str(lobby_id)],
	]
	return _call_first_steam_peer_method(peer_object, steam_join_method_names, argument_sets)


func _call_first_steam_peer_method(peer_object: Object, method_names: Array[String], argument_sets: Array) -> int:
	if peer_object == null:
		return ERR_UNAVAILABLE
	var saw_method := false
	var last_error := ERR_UNAVAILABLE
	for method_name in method_names:
		if not peer_object.has_method(method_name):
			continue
		saw_method = true
		for args_value in argument_sets:
			var args: Array = args_value if args_value is Array else []
			if not _method_accepts_arg_count(peer_object, method_name, args.size()):
				continue
			var result: Variant = peer_object.callv(method_name, args)
			var err := _steam_call_result_to_error(result)
			if err == OK:
				return OK
			last_error = err
	return last_error if saw_method else ERR_UNAVAILABLE


func _method_accepts_arg_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		var info: Dictionary = method_info
		if String(info.get("name", "")) != method_name:
			continue
		var args_value: Variant = info.get("args", [])
		var args_count := (args_value as Array).size() if args_value is Array else 0
		var defaults_value: Variant = info.get("default_args", [])
		var default_count := (defaults_value as Array).size() if defaults_value is Array else int(defaults_value)
		var required_count := maxi(args_count - default_count, 0)
		return arg_count >= required_count and arg_count <= args_count
	return true


func _steam_call_result_to_error(result: Variant) -> int:
	if result == null:
		return OK
	if result is bool:
		return OK if bool(result) else ERR_CANT_CONNECT
	if result is int:
		return int(result)
	if result is Dictionary:
		var dictionary := result as Dictionary
		if dictionary.has("status") and int(dictionary.get("status", OK)) != OK:
			return int(dictionary.get("status", OK))
	return OK


func _connect_steam_signals() -> void:
	var lobby_created := Callable(self, "_on_steam_lobby_created")
	var lobby_joined := Callable(self, "_on_steam_lobby_joined")
	var steam := _steam_singleton()
	if steam != null:
		_connect_object_signal(steam, &"lobby_created", lobby_created)
		_connect_object_signal(steam, &"lobby_joined", lobby_joined)
	if _steam_peer_object != null:
		_connect_object_signal(_steam_peer_object, &"lobby_created", lobby_created)
		_connect_object_signal(_steam_peer_object, &"lobby_joined", lobby_joined)


func _connect_object_signal(source: Object, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_steam_lobby_created(_connect: int = 0, lobby_id: int = 0) -> void:
	if lobby_id > 0:
		_steam_lobby_id = lobby_id
		host_address = str(lobby_id)
		_publish_steam_lobby_metadata()
	_publish_status()


func _on_steam_lobby_joined(lobby_id: int = 0, _permissions: int = 0, _locked: bool = false, _response: int = 0) -> void:
	if lobby_id > 0:
		_steam_lobby_id = lobby_id
		host_address = str(lobby_id)
	_publish_status()


func _refresh_steam_lobby_state() -> void:
	if _steam_peer_object != null:
		for method_name in steam_lobby_id_methods:
			if not _steam_peer_object.has_method(method_name):
				continue
			if not _method_accepts_arg_count(_steam_peer_object, method_name, 0):
				continue
			var value: Variant = _steam_peer_object.callv(method_name, [])
			var id := _int_from_variant(value, 0)
			if id > 0:
				_steam_lobby_id = id
				host_address = str(id)
				break
	if mode == SessionMode.STEAM_HOST:
		_publish_steam_lobby_metadata()


func _publish_steam_lobby_metadata() -> void:
	if _steam_lobby_id <= 0:
		return
	var steam := _steam_singleton()
	if steam == null:
		return
	var metadata := {
		steam_lobby_name_key: steam_lobby_name,
		steam_lobby_protocol_key: str(NETWORK_PROTOCOL_VERSION),
		steam_lobby_mod_key: _local_mod_signature(),
		steam_lobby_scene_key: String(_run_config.get("scene_path", RUN_SCENE_PATH)),
	}
	for key in metadata.keys():
		_set_steam_lobby_data(steam, String(key), String(metadata[key]))


func _set_steam_lobby_data(steam: Object, key: String, value: String) -> void:
	for method_name in ["setLobbyData", "set_lobby_data"]:
		if steam.has_method(method_name) and _method_accepts_arg_count(steam, method_name, 3):
			steam.callv(method_name, [_steam_lobby_id, key, value])
			return
		if steam.has_method(method_name) and _method_accepts_arg_count(steam, method_name, 2):
			steam.callv(method_name, [key, value])
			return


func _pump_steam_callbacks() -> void:
	var steam := _steam_singleton()
	if steam == null:
		return
	for method_name in ["run_callbacks", "runCallbacks"]:
		if steam.has_method(method_name) and _method_accepts_arg_count(steam, method_name, 0):
			steam.callv(method_name, [])
			return


func _steam_singleton() -> Object:
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null


func _steam_lobby_text() -> String:
	if _steam_lobby_id > 0:
		return str(_steam_lobby_id)
	if mode == SessionMode.STEAM_HOST or mode == SessionMode.STEAM_CLIENT:
		return steam_lobby_id_pending_text
	return ""


func _steam_error_text(err: int) -> String:
	if err == ERR_UNAVAILABLE:
		return "SteamMultiplayerPeer host/join method unavailable"
	if err == ERR_CANT_CONNECT:
		return "Steam lobby connection rejected"
	return error_string(err)


func configure_arena_players(level_root: Node) -> void:
	if level_root == null:
		return
	local_peer_id = _effective_local_peer_id()

	var records := _sorted_peer_records()
	if records.is_empty():
		_reset_roster()
		records = _sorted_peer_records()

	var existing_player := _first_scene_player(level_root)
	if existing_player != null:
		_base_spawn_position = existing_player.global_position

	_player_nodes_by_peer.clear()
	var used_ids := {}
	for index in range(records.size()):
		var record: Dictionary = records[index]
		var peer_id := int(record.get("peer_id", 1))
		var player := _ensure_player_for_peer(level_root, peer_id, existing_player if index == 0 else null)
		if player == null:
			continue
		used_ids[player.get_instance_id()] = true
		_configure_player_node(player, record, index)
		if multiplayer.is_server():
			_session_ready_ack[peer_id] = true

	_fill_scene_players(level_root, _player_scan_buffer)
	for player_2d in _player_scan_buffer:
		if player_2d == null or used_ids.has(player_2d.get_instance_id()):
			continue
		var peer_value: Variant = player_2d.get("network_peer_id")
		var peer_id := int(peer_value) if typeof(peer_value) == TYPE_INT else 0
		if peer_id > 0 and not _peer_records.has(peer_id) and not player_2d.is_queued_for_deletion():
			player_2d.queue_free()

	_configure_sync_foundation(level_root)
	_publish_status()


func refresh_runtime_multiplayer_bindings(level_root: Node) -> void:
	if level_root == null:
		return
	_fill_scene_players(level_root, _player_scan_buffer)
	for player in _player_scan_buffer:
		if player != null:
			_connect_player_network_signals(player)
	_configure_sync_foundation(level_root)


func submit_player_state(player: Node) -> void:
	if not is_network_active() or player == null:
		return
	if not bool(player.get("network_is_local")):
		return
	var peer_id := int(player.get("network_peer_id"))
	if peer_id != _effective_local_peer_id():
		return
	if not player.has_method("export_network_state"):
		return
	var state: Dictionary = player.call("export_network_state")
	if multiplayer.is_server():
		_rpc_peer_state.rpc(peer_id, state)
	else:
		_rpc_submit_client_state.rpc_id(1, state)


func broadcast_projectile_spawn(projectile: Node, direction: Vector2, owner: Node) -> void:
	if not is_network_active() or projectile == null or owner == null:
		return
	if not bool(owner.get("network_is_local")):
		return
	var owner_peer_id := int(owner.get("network_peer_id"))
	if owner_peer_id != _effective_local_peer_id():
		return
	projectile.set_meta(&"network_owner_peer_id", owner_peer_id)
	projectile.set_meta(&"network_local_projectile", true)
	var path := projectile.scene_file_path
	if path.is_empty():
		path = PROJECTILE_FALLBACK_SCENE_PATH
	var projectile_2d := projectile as Node2D
	if projectile_2d == null:
		return
	var data := {
		"owner_peer_id": owner_peer_id,
		"scene_path": path,
		"position": projectile_2d.global_position,
		"rotation": projectile_2d.global_rotation,
		"direction": direction,
		"weapon_payload": _sanitize_projectile_payload(projectile),
	}
	if multiplayer.is_server():
		_rpc_remote_projectile_spawn.rpc(data)
	else:
		_rpc_client_projectile_spawn.rpc_id(1, data)


func broadcast_vector_event(data: Dictionary, owner: Node) -> void:
	if not is_network_active() or owner == null:
		return
	if not bool(owner.get("network_is_local")):
		return
	var owner_peer_id := int(owner.get("network_peer_id"))
	var event_data := _sanitize_vector_event(data)
	event_data["owner_peer_id"] = owner_peer_id
	if multiplayer.is_server():
		_rpc_remote_vector_event.rpc(event_data)
	else:
		_rpc_client_vector_event.rpc_id(1, event_data)


func broadcast_weapon_field_event(data: Dictionary, owner: Node) -> void:
	if not is_network_active() or owner == null:
		return
	if not bool(owner.get("network_is_local")):
		return
	var owner_peer_id := int(owner.get("network_peer_id"))
	if owner_peer_id != _effective_local_peer_id():
		return
	var event_data := _sanitize_weapon_field_event(data)
	event_data["owner_peer_id"] = owner_peer_id
	if multiplayer.is_server():
		_rpc_remote_weapon_field_event.rpc(event_data)
	else:
		_rpc_client_weapon_field_event.rpc_id(1, event_data)


func broadcast_mod_hook_event(hook_id: StringName, entry_id: StringName, data: Dictionary, owner: Node = null) -> void:
	if not is_network_active():
		return
	var owner_peer_id := _effective_local_peer_id()
	if owner != null:
		if owner.get("network_is_local") != null and not bool(owner.get("network_is_local")):
			return
		var owner_value: Variant = owner.get("network_peer_id")
		if typeof(owner_value) == TYPE_INT:
			owner_peer_id = int(owner_value)
	var event_data := _sanitize_mod_hook_event(hook_id, entry_id, data)
	event_data["owner_peer_id"] = owner_peer_id
	if multiplayer.is_server():
		_rpc_remote_mod_hook_event.rpc(event_data)
	else:
		_rpc_client_mod_hook_event.rpc_id(1, event_data)


func broadcast_wave_state(state: Dictionary) -> void:
	if not is_network_active() or not multiplayer.is_server():
		return
	_last_wave_state = state.duplicate(true)
	_rpc_wave_state.rpc(_last_wave_state)


func get_last_wave_state() -> Dictionary:
	return _last_wave_state.duplicate(true)


func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _begin_host_run(seed_override: int = 0, scene_path: String = RUN_SCENE_PATH, mode_flags: Dictionary = {}) -> void:
	if RunProgress == null:
		_fail_session("RUN START FAILED: RunProgress missing")
		return
	if scene_path.is_empty():
		scene_path = RUN_SCENE_PATH
	var challenge_mode := bool(mode_flags.get("challenge_mode", false))
	RunProgress.begin_new_run(challenge_mode, seed_override)
	var orbiting_celestials := Settings != null and bool(Settings.auto_orbiting_celestials_enabled)
	RunProgress.arena_flags["auto_orbiting_celestials"] = orbiting_celestials
	for key in mode_flags.keys():
		RunProgress.arena_flags[String(key)] = mode_flags[key]
	RunProgress.arena_flags["retry_scene_path"] = scene_path
	RunProgress.arena_flags["title_scene_path"] = TITLE_SCENE_PATH
	_run_config = {
		"scene_path": scene_path,
		"seed": int(RunProgress.run_seed),
		"challenge_mode": challenge_mode,
		"boss_rush_mode": false,
		"phase": int(RunProgress.phase),
		"auto_orbiting_celestials": orbiting_celestials,
		"network_protocol": NETWORK_PROTOCOL_VERSION,
		"mod_signature": _local_mod_signature(),
	}
	_copy_seed_code_flags_to_config(_run_config)
	for key in mode_flags.keys():
		_run_config[String(key)] = mode_flags[key]
	_run_in_progress = true
	_last_wave_state.clear()
	_status_label = _host_status_for_scene(scene_path)
	if mode == SessionMode.STEAM_HOST:
		_refresh_steam_lobby_state()
	_rpc_begin_network_run.rpc(_run_config)
	network_run_started.emit(_run_config.duplicate(true))
	_publish_status()
	_change_to_network_run_scene(scene_path)


func _apply_run_config(config: Dictionary) -> void:
	if RunProgress == null:
		return
	RunProgress.begin_new_run(bool(config.get("challenge_mode", false)), int(config.get("seed", 0)))
	RunProgress.challenge_mode = bool(config.get("challenge_mode", false))
	RunProgress.boss_rush_mode = bool(config.get("boss_rush_mode", false))
	RunProgress.phase = int(config.get("phase", RunProgress.Phase.PHYSICS_WAVES)) as RunProgress.Phase
	RunProgress.wave_index = 0
	RunProgress.bosses_defeated = 0
	RunProgress.run_finished = false
	RunProgress.arena_flags["auto_orbiting_celestials"] = bool(config.get("auto_orbiting_celestials", true))
	RunProgress.arena_flags["retry_scene_path"] = String(config.get("scene_path", RUN_SCENE_PATH))
	RunProgress.arena_flags["title_scene_path"] = TITLE_SCENE_PATH
	for key in ["campaign_mode", "king_of_hill_mode", "network_mode_id", "mod_gamemode_id", "mod_campaign_id", "seed_code_id", "seed_code_label", "seed_code_profile", "seed_code_description", "seed_code_run_law", "seed_code_run_law_name", "seed_code_effects"]:
		if config.has(key):
			RunProgress.arena_flags[key] = config[key]
	RunProgress.clear_anchor()


func _copy_seed_code_flags_to_config(config: Dictionary) -> void:
	if RunProgress == null:
		return
	for key in ["seed_code_id", "seed_code_label", "seed_code_profile", "seed_code_description", "seed_code_run_law", "seed_code_run_law_name", "seed_code_effects"]:
		if RunProgress.arena_flags.has(key):
			config[key] = RunProgress.arena_flags[key]


func _change_to_network_run_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		scene_path = RUN_SCENE_PATH
	if scene_path == RUN_SCENE_PATH:
		get_tree().change_scene_to_file(RUN_LOADING_SCENE_PATH)
		return
	get_tree().change_scene_to_file(scene_path)


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_upsert_peer_record(peer_id, "PEER %d" % peer_id)
	_publish_roster()
	_publish_roster_to_clients()
	_sync_players_to_current_scene()


func _on_peer_disconnected(peer_id: int) -> void:
	_peer_records.erase(peer_id)
	_remove_player_for_peer(peer_id)
	_publish_roster()
	if multiplayer.is_server():
		_publish_roster_to_clients()
	_sync_players_to_current_scene()


func _on_connected_to_server() -> void:
	local_peer_id = _effective_local_peer_id()
	_status_label = "CONNECTED TO STEAM HOST" if mode == SessionMode.STEAM_CLIENT else "CONNECTED TO LAN HOST"
	_upsert_peer_record(local_peer_id, local_player_name)
	_rpc_register_player.rpc_id(1, _local_profile())
	_publish_status()


func _on_connection_failed() -> void:
	_fail_session("JOIN FAILED: connection refused or timed out")
	leave_session()


func _on_server_disconnected() -> void:
	_fail_session("HOST DISCONNECTED")
	leave_session()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_player(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var compatibility_error := _profile_compatibility_error(profile)
	if not compatibility_error.is_empty():
		_rpc_session_rejected.rpc_id(peer_id, compatibility_error)
		_peer_records.erase(peer_id)
		_publish_roster()
		return
	_upsert_peer_record(peer_id, String(profile.get("player_name", "PEER %d" % peer_id)))
	_publish_roster()
	_publish_roster_to_clients()
	_sync_players_to_current_scene()
	if _run_in_progress:
		_rpc_begin_network_run.rpc_id(peer_id, _run_config)
		if not _last_wave_state.is_empty():
			_rpc_wave_state.rpc_id(peer_id, _last_wave_state)


@rpc("authority", "call_remote", "reliable")
func _rpc_roster_snapshot(roster: Array) -> void:
	_peer_records.clear()
	for value in roster:
		if value is Dictionary:
			var record: Dictionary = value
			_peer_records[int(record.get("peer_id", 1))] = record.duplicate(true)
	local_peer_id = _effective_local_peer_id()
	_publish_roster()
	_sync_players_to_current_scene()


@rpc("authority", "call_remote", "reliable")
func _rpc_begin_network_run(config: Dictionary) -> void:
	var compatibility_error := _run_config_compatibility_error(config)
	if not compatibility_error.is_empty():
		_fail_session(compatibility_error)
		leave_session()
		return
	_run_config = config.duplicate(true)
	_run_in_progress = true
	_status_label = "RUN CLIENT"
	_apply_run_config(_run_config)
	network_run_started.emit(_run_config.duplicate(true))
	_rpc_client_run_ready.rpc_id(1, _effective_local_peer_id(), get_multiplayer_readiness_snapshot())
	_publish_status()
	call_deferred("_change_to_network_run_scene", String(_run_config.get("scene_path", RUN_SCENE_PATH)))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_run_ready(peer_id: int, readiness: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var effective_peer := peer_id if peer_id > 0 else sender
	_session_ready_ack[effective_peer] = readiness.duplicate(true)
	_publish_status()


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_submit_client_state(state: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_apply_peer_state(sender, state)
	_rpc_peer_state.rpc(sender, state)


@rpc("authority", "call_remote", "unreliable")
func _rpc_peer_state(peer_id: int, state: Dictionary) -> void:
	_apply_peer_state(peer_id, state)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_projectile_spawn(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_spawn_projectile_from_network(data)
	_rpc_remote_projectile_spawn.rpc(data)


@rpc("authority", "call_remote", "reliable")
func _rpc_remote_projectile_spawn(data: Dictionary) -> void:
	if int(data.get("owner_peer_id", 0)) == _effective_local_peer_id():
		return
	_spawn_projectile_from_network(data)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_vector_event(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_apply_remote_vector_event(data)
	_rpc_remote_vector_event.rpc(data)


@rpc("authority", "call_remote", "reliable")
func _rpc_remote_vector_event(data: Dictionary) -> void:
	if int(data.get("owner_peer_id", 0)) == _effective_local_peer_id():
		return
	_apply_remote_vector_event(data)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_weapon_field_event(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sanitized := _sanitize_weapon_field_event(data)
	sanitized["owner_peer_id"] = multiplayer.get_remote_sender_id()
	_emit_network_weapon_field(sanitized)
	_rpc_remote_weapon_field_event.rpc(sanitized)


@rpc("authority", "call_remote", "reliable")
func _rpc_remote_weapon_field_event(data: Dictionary) -> void:
	if int(data.get("owner_peer_id", 0)) == _effective_local_peer_id():
		return
	_emit_network_weapon_field(_sanitize_weapon_field_event(data))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_mod_hook_event(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sanitized := _sanitize_mod_hook_event(
		StringName(str(data.get("hook_id", ""))),
		StringName(str(data.get("entry_id", ""))),
		data
	)
	sanitized["owner_peer_id"] = multiplayer.get_remote_sender_id()
	_emit_network_mod_hook(sanitized)
	_rpc_remote_mod_hook_event.rpc(sanitized)


@rpc("authority", "call_remote", "reliable")
func _rpc_remote_mod_hook_event(data: Dictionary) -> void:
	if _int_from_variant(data.get("owner_peer_id", 0), 0) == _effective_local_peer_id():
		return
	var sanitized := _sanitize_mod_hook_event(
		StringName(str(data.get("hook_id", ""))),
		StringName(str(data.get("entry_id", ""))),
		data
	)
	sanitized["owner_peer_id"] = _int_from_variant(data.get("owner_peer_id", 0), 0)
	_emit_network_mod_hook(sanitized)


@rpc("authority", "call_remote", "reliable")
func _rpc_wave_state(state: Dictionary) -> void:
	_last_wave_state = state.duplicate(true)
	network_wave_state_received.emit(_last_wave_state.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func _rpc_session_rejected(message: String) -> void:
	_fail_session(message)
	leave_session()


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_heartbeat_ping(sent_msec: int, nonce: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_rpc_heartbeat_pong.rpc_id(sender, sent_msec, nonce)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_heartbeat_pong(sent_msec: int, nonce: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_peer_ping_ms[sender] = maxi(Time.get_ticks_msec() - sent_msec, 0)
	_heartbeat_nonce = maxi(_heartbeat_nonce, nonce)
	_publish_status()


func _average_peer_ping_ms() -> int:
	if _peer_ping_ms.is_empty():
		return 0
	var total := 0
	for value in _peer_ping_ms.values():
		total += int(value)
	return int(round(float(total) / float(maxi(_peer_ping_ms.size(), 1))))


func _connection_quality_label() -> String:
	if not is_network_active():
		return "offline"
	var average := _average_peer_ping_ms()
	if average <= 0:
		return "local"
	if average < 80:
		return "stable"
	if average < 160:
		return "watch"
	return "high-latency"


func _host_status_for_scene(scene_path: String) -> String:
	match scene_path:
		CAMPAIGN_SCENE_PATH:
			return "CAMPAIGN HOSTING"
		KING_OF_THE_HILL_SCENE_PATH:
			return "KOTH HOSTING"
	return "RUN HOSTING"


func _network_mode_flags_from_config(config: Dictionary) -> Dictionary:
	var flags: Dictionary = {}
	for key in ["challenge_mode", "campaign_mode", "king_of_hill_mode", "network_mode_id", "mod_gamemode_id", "mod_campaign_id"]:
		if config.has(key):
			flags[key] = config[key]
	return flags


func _publish_roster_to_clients() -> void:
	if not multiplayer.is_server():
		return
	_rpc_roster_snapshot.rpc(_roster_array())


func _sync_players_to_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var configured_scene := String(_run_config.get("scene_path", RUN_SCENE_PATH))
	var is_network_arena := (
		scene.scene_file_path == RUN_SCENE_PATH
		or scene.scene_file_path == configured_scene
		or scene.name == "TheAbyss"
		or scene.is_in_group("campaign_mode")
		or scene.is_in_group("king_of_the_hill_mode")
	)
	if not is_network_arena:
		return
	configure_arena_players(scene)
	refresh_runtime_multiplayer_bindings(scene)


func _apply_peer_state(peer_id: int, state: Dictionary) -> void:
	if peer_id == _effective_local_peer_id():
		return
	var player := _player_nodes_by_peer.get(peer_id, null) as Node
	if player == null or not is_instance_valid(player):
		_sync_players_to_current_scene()
		player = _player_nodes_by_peer.get(peer_id, null) as Node
	if player != null and player.has_method("apply_network_state"):
		player.call("apply_network_state", state)


func _spawn_projectile_from_network(data: Dictionary) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var path := String(data.get("scene_path", PROJECTILE_FALLBACK_SCENE_PATH))
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var projectile := scene.instantiate()
	projectile.set_meta(&"network_spawned", true)
	projectile.set_meta(&"network_owner_peer_id", int(data.get("owner_peer_id", 0)))
	var payload_value: Variant = data.get("weapon_payload", {})
	if payload_value is Dictionary:
		var payload: Dictionary = payload_value
		_apply_network_projectile_payload(projectile, payload)
	root.add_child(projectile)
	var projectile_2d := projectile as Node2D
	if projectile_2d != null:
		projectile_2d.global_position = _vector2_from_variant(data.get("position", Vector2.ZERO))
		projectile_2d.global_rotation = float(data.get("rotation", 0.0))
	var direction := _vector2_from_variant(data.get("direction", Vector2.RIGHT))
	if projectile.has_method("launch"):
		projectile.call_deferred("launch", direction)
	elif projectile is RigidBody2D:
		(projectile as RigidBody2D).call_deferred("apply_central_impulse", direction * 900.0)


func _apply_remote_vector_event(data: Dictionary) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var coop := root.find_child("CoopComboDirector", true, false)
	if coop != null and coop.has_method("register_remote_vector_event"):
		var peer_id := int(data.get("owner_peer_id", 0))
		coop.call("register_remote_vector_event", StringName("peer_%d" % peer_id), data.duplicate(true))


func _ensure_player_for_peer(level_root: Node, peer_id: int, existing_player: Node2D = null) -> Node2D:
	var found := _find_player_by_peer(level_root, peer_id)
	if found != null:
		return found
	if existing_player != null:
		return existing_player
	var player := PLAYER_SCENE.instantiate() as Node2D
	if player == null:
		return null
	player.name = "PlayerPeer%d" % peer_id
	level_root.add_child(player)
	return player


func _configure_player_node(player: Node2D, record: Dictionary, index: int) -> void:
	var peer_id := int(record.get("peer_id", 1))
	player.name = "PlayerPeer%d" % peer_id
	if not player.is_in_group("Player"):
		player.add_to_group("Player")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(player, &"Player")
	if not bool(player.get_meta(&"network_configured", false)):
		player.global_position = _spawn_position_for_index(index)
		player.set_meta(&"network_configured", true)
	_player_nodes_by_peer[peer_id] = player
	if player.has_method("configure_network_peer"):
		player.call(
			"configure_network_peer",
			peer_id,
			peer_id == _effective_local_peer_id(),
			String(record.get("player_name", "PEER %d" % peer_id)),
			_color_from_record(record, peer_id)
		)
	_connect_player_network_signals(player)


func _connect_player_network_signals(player: Node) -> void:
	if player == null or not bool(player.get("network_is_local")):
		return
	var projectile_callable := Callable(self, "_on_local_projectile_spawned").bind(player)
	if player.has_signal("momentum_projectile_spawned") and not player.is_connected("momentum_projectile_spawned", projectile_callable):
		player.connect("momentum_projectile_spawned", projectile_callable)
	var vector_callable := Callable(self, "_on_local_vector_event").bind(player)
	if player.has_signal("slingshot_mastery_scored") and not player.is_connected("slingshot_mastery_scored", vector_callable):
		player.connect("slingshot_mastery_scored", vector_callable)


func _on_local_projectile_spawned(projectile: Node, direction: Vector2, player: Node) -> void:
	broadcast_projectile_spawn(projectile, direction, player)


func _on_local_vector_event(data: Dictionary, player: Node) -> void:
	broadcast_vector_event(data, player)


func _first_scene_player(level_root: Node) -> Node2D:
	var direct := level_root.get_node_or_null("Player") as Node2D
	if direct != null:
		return direct
	_fill_scene_players(level_root, _player_scan_buffer)
	for player in _player_scan_buffer:
		if player != null and player.get_parent() == level_root:
			return player
	return null


func _find_player_by_peer(level_root: Node, peer_id: int) -> Node2D:
	_fill_scene_players(level_root, _player_scan_buffer)
	for player in _player_scan_buffer:
		if player == null:
			continue
		var value: Variant = player.get("network_peer_id")
		if typeof(value) == TYPE_INT and int(value) == peer_id:
			return player
	return null


func _fill_scene_players(level_root: Node, out_players: Array[Node2D]) -> void:
	out_players.clear()
	if level_root == null:
		return
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(&"Player", out_players)
	else:
		for node in level_root.get_tree().get_nodes_in_group("Player"):
			var player := node as Node2D
			if player != null and is_instance_valid(player) and not player.is_queued_for_deletion():
				out_players.append(player)
	for index in range(out_players.size() - 1, -1, -1):
		var player := out_players[index]
		if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
			out_players.remove_at(index)
			continue
		if player != level_root and not level_root.is_ancestor_of(player):
			out_players.remove_at(index)


func _remove_player_for_peer(peer_id: int) -> void:
	var player := _player_nodes_by_peer.get(peer_id, null) as Node
	if player != null and is_instance_valid(player) and not player.is_queued_for_deletion():
		player.queue_free()
	_player_nodes_by_peer.erase(peer_id)


func _spawn_position_for_index(index: int) -> Vector2:
	if index <= 0:
		return _base_spawn_position
	var angle := TAU * float(index - 1) / float(maxi(_sorted_peer_records().size() - 1, 1))
	return _base_spawn_position + Vector2.RIGHT.rotated(angle) * 155.0


func _configure_sync_foundation(level_root: Node) -> void:
	var sync := level_root.find_child("MultiplayerSyncFoundation", true, false)
	if sync == null:
		return
	if sync.get("local_player_count") != null:
		sync.set("local_player_count", 1)
	if sync.has_method("set_remote_peer_count"):
		sync.call("set_remote_peer_count", maxi(_sorted_peer_records().size() - 1, 0))


func _reset_roster() -> void:
	_peer_records.clear()
	_upsert_peer_record(_effective_local_peer_id(), local_player_name)


func _upsert_peer_record(peer_id: int, player_name: String) -> void:
	var clean_name := _normalize_player_name(player_name)
	var existing: Dictionary = _peer_records.get(peer_id, {})
	_peer_records[peer_id] = {
		"peer_id": peer_id,
		"player_name": clean_name,
		"color": existing.get("color", _color_for_peer(peer_id)),
	}


func _local_profile() -> Dictionary:
	return {
		"peer_id": _effective_local_peer_id(),
		"player_name": local_player_name,
		"color": _color_for_peer(_effective_local_peer_id()),
		"network_protocol": NETWORK_PROTOCOL_VERSION,
		"mod_signature": _local_mod_signature(),
	}


func _publish_roster() -> void:
	peer_roster_changed.emit(_roster_array())
	_publish_status()


func _publish_status() -> void:
	session_status_changed.emit(get_status_snapshot())


func _fail_session(message: String) -> void:
	_last_error = message
	_status_label = message
	session_error.emit(message)
	_publish_status()


func _roster_array() -> Array:
	var records := _sorted_peer_records()
	var output: Array = []
	for record in records:
		output.append(record.duplicate(true))
	return output


func _sorted_peer_records() -> Array:
	var records: Array = []
	for record in _peer_records.values():
		if record is Dictionary:
			records.append(record)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("peer_id", 0)) < int(b.get("peer_id", 0))
	)
	return records


func _effective_local_peer_id() -> int:
	if is_network_active():
		var id := multiplayer.get_unique_id()
		if id > 0:
			return id
	return 1


func _mode_label() -> String:
	match mode:
		SessionMode.LAN_HOST:
			return "LAN HOST"
		SessionMode.LAN_CLIENT:
			return "LAN CLIENT"
		SessionMode.STEAM_HOST:
			return "STEAM HOST"
		SessionMode.STEAM_CLIENT:
			return "STEAM CLIENT"
		_:
			return "OFFLINE"


func _normalize_player_name(player_name: String) -> String:
	var clean := player_name.strip_edges()
	if clean.is_empty():
		return "VECTOR"
	if clean.length() > 18:
		clean = clean.substr(0, 18)
	return clean


func _color_for_peer(peer_id: int) -> Color:
	var index := absi(peer_id - 1) % PLAYER_COLORS.size()
	return PLAYER_COLORS[index]


func _color_from_record(record: Dictionary, peer_id: int) -> Color:
	var value: Variant = record.get("color", _color_for_peer(peer_id))
	if value is Color:
		return value
	return _color_for_peer(peer_id)


func _profile_compatibility_error(profile: Dictionary) -> String:
	var protocol := int(profile.get("network_protocol", 0))
	if protocol != NETWORK_PROTOCOL_VERSION:
		return "JOIN FAILED: network protocol mismatch"
	var remote_signature := String(profile.get("mod_signature", ""))
	var local_signature := _local_mod_signature()
	if not remote_signature.is_empty() and remote_signature != local_signature:
		return "JOIN FAILED: gameplay mod signature mismatch"
	return ""


func _run_config_compatibility_error(config: Dictionary) -> String:
	var protocol := int(config.get("network_protocol", 0))
	if protocol != NETWORK_PROTOCOL_VERSION:
		return "JOIN FAILED: host protocol mismatch"
	var remote_signature := String(config.get("mod_signature", ""))
	var local_signature := _local_mod_signature()
	if not remote_signature.is_empty() and remote_signature != local_signature:
		return "JOIN FAILED: host gameplay mod signature mismatch"
	return ""


func _sanitize_projectile_payload(projectile: Node) -> Dictionary:
	var source: Dictionary = {}
	if projectile != null and projectile.has_method("get_weapon_payload"):
		var value: Variant = projectile.call("get_weapon_payload")
		if value is Dictionary:
			source = value
	elif projectile != null and projectile.has_meta(&"weapon_payload"):
		var meta_value: Variant = projectile.get_meta(&"weapon_payload")
		if meta_value is Dictionary:
			source = meta_value

	var sanitized: Dictionary = {}
	for key in PROJECTILE_PAYLOAD_KEYS:
		var value: Variant = source.get(key, null)
		if value == null and projectile != null:
			value = projectile.get(key)
		if _is_projectile_payload_value_safe(value):
			sanitized[key] = value
	return sanitized


func _apply_network_projectile_payload(projectile: Node, payload: Dictionary) -> void:
	if projectile == null:
		return
	var sanitized: Dictionary = {}
	for key in PROJECTILE_PAYLOAD_KEYS:
		var value: Variant = payload.get(key, null)
		if _is_projectile_payload_value_safe(value):
			sanitized[key] = value
	if projectile.has_method("apply_weapon_payload"):
		projectile.call("apply_weapon_payload", sanitized)
		return
	projectile.set_meta(&"weapon_payload", sanitized.duplicate(true))
	for key in sanitized.keys():
		var property_name := String(key)
		if projectile.get(property_name) != null:
			projectile.set(property_name, sanitized[key])


func _is_projectile_payload_value_safe(value: Variant) -> bool:
	return (
		value is bool
		or value is int
		or value is float
		or value is String
		or value is StringName
		or value is Vector2
		or value is Color
	)


func _local_mod_signature() -> String:
	var registry := _find_mod_registry()
	if registry != null and registry.has_method("get_compatibility_signature"):
		return String(registry.call("get_compatibility_signature"))
	var tokens: Array[String] = []
	for root in _fallback_mod_scan_roots():
		_collect_mod_signature_tokens(root, tokens, 0)
	tokens.sort()
	var packed := PackedStringArray()
	var seen_tokens := {}
	for token in tokens:
		if seen_tokens.has(token):
			continue
		seen_tokens[token] = true
		packed.append(token)
	return ("mods:%s" % "|".join(packed)).sha256_text().substr(0, 16)


func _find_mod_registry() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var current := tree.current_scene
	if current != null:
		var registry := current.find_child("ModContentRegistry", true, false)
		if registry != null and is_instance_valid(registry) and not registry.is_queued_for_deletion():
			return registry
	for node in tree.get_nodes_in_group("mod_content_registry"):
		var registry_node := node as Node
		if registry_node != null and is_instance_valid(registry_node) and not registry_node.is_queued_for_deletion():
			return registry_node
	return null


func _fallback_mod_scan_roots() -> Array[String]:
	var roots: Array[String] = []
	for root in MOD_SCAN_ROOTS:
		_append_unique_mod_root(roots, root)
	var executable_root := _export_executable_base_dir()
	if not executable_root.is_empty():
		for root_name in MOD_EXTERNAL_ROOT_NAMES:
			_append_unique_mod_root(roots, _join_mod_path(executable_root, root_name))
	return roots


func _append_unique_mod_root(roots: Array[String], root_path: String) -> void:
	var clean := root_path.strip_edges().replace("\\", "/")
	if clean.is_empty():
		return
	var key := _mod_root_key(clean)
	for existing in roots:
		if _mod_root_key(existing) == key:
			return
	roots.append(clean)


func _mod_root_key(path: String) -> String:
	var clean := path.strip_edges().replace("\\", "/")
	var os_name := OS.get_name().to_lower()
	return clean.to_lower() if os_name == "windows" or os_name == "macos" else clean


func _export_executable_base_dir() -> String:
	if OS.has_feature("editor"):
		return ""
	var executable_path := OS.get_executable_path().strip_edges().replace("\\", "/")
	if executable_path.is_empty():
		return ""
	return executable_path.get_base_dir()


func _join_mod_path(base_path: String, child_path: String) -> String:
	var clean_base := base_path.strip_edges().replace("\\", "/").trim_suffix("/")
	var clean_child := child_path.strip_edges().replace("\\", "/").trim_prefix("/")
	if clean_base.is_empty():
		return clean_child
	if clean_child.is_empty():
		return clean_base
	return "%s/%s" % [clean_base, clean_child]


func _collect_mod_signature_tokens(root_path: String, tokens: Array[String], depth: int) -> void:
	if depth > MOD_SCAN_DEPTH_LIMIT:
		return
	var dir := DirAccess.open(root_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var child_path := "%s/%s" % [root_path.trim_suffix("/"), entry]
		if dir.current_is_dir():
			_collect_mod_signature_tokens(child_path, tokens, depth + 1)
		elif MOD_MANIFEST_FILE_NAMES.has(entry):
			_append_manifest_signature_token(child_path, tokens)
		entry = dir.get_next()
	dir.list_dir_end()


func _append_manifest_signature_token(path: String, tokens: Array[String]) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		tokens.append("failed:%s" % path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		tokens.append("invalid:%s:%s" % [path, text.sha256_text().substr(0, 8)])
		return
	var manifest := parsed as Dictionary
	for token in _manifest_gameplay_signature_tokens(manifest):
		tokens.append(token)


func _sanitize_vector_event(data: Dictionary) -> Dictionary:
	return {
		"score": clampf(float(data.get("score", 0.0)), 0.0, 1.0),
		"grade": String(data.get("grade", "vector")),
		"position": _vector2_from_variant(data.get("position", Vector2.ZERO)),
		"gravity": _vector2_from_variant(data.get("gravity", Vector2.ZERO)),
		"impulse": _vector2_from_variant(data.get("impulse", Vector2.ZERO)),
		"tangent": _vector2_from_variant(data.get("tangent", Vector2.RIGHT)),
		"radial_dir": _vector2_from_variant(data.get("radial_dir", Vector2.RIGHT)),
		"speed_before": float(data.get("speed_before", 0.0)),
		"speed_after": float(data.get("speed_after", 0.0)),
		"time": float(data.get("time", Time.get_ticks_msec() / 1000.0)),
	}


func _sanitize_weapon_field_event(data: Dictionary) -> Dictionary:
	return {
		"weapon_id": String(data.get("weapon_id", "")),
		"origin": _vector2_from_variant(data.get("origin", data.get("position", Vector2.ZERO))),
		"position": _vector2_from_variant(data.get("position", data.get("origin", Vector2.ZERO))),
		"direction": _vector2_from_variant(data.get("direction", Vector2.RIGHT)),
		"radius": clampf(float(data.get("radius", 0.0)), 0.0, 2000.0),
		"damage": clampf(float(data.get("damage", 0.0)), 0.0, 10000.0),
		"force": clampf(float(data.get("force", 0.0)), -5000.0, 5000.0),
		"owner_peer_id": _int_from_variant(data.get("owner_peer_id", 0), 0),
		"time": float(data.get("time", Time.get_ticks_msec() / 1000.0)),
	}


func _sanitize_mod_hook_event(hook_id: StringName, entry_id: StringName, data: Dictionary) -> Dictionary:
	return {
		"hook_id": String(hook_id),
		"entry_id": String(entry_id),
		"position": _vector2_from_variant(data.get("position", data.get("origin", Vector2.ZERO))),
		"origin": _vector2_from_variant(data.get("origin", data.get("position", Vector2.ZERO))),
		"weapon_id": String(data.get("weapon_id", "")),
		"grade": String(data.get("grade", "")),
		"score": clampf(float(data.get("score", 0.0)), 0.0, 1.0),
		"wave": maxi(_int_from_variant(data.get("wave", 0), 0), 0),
		"zone_type": _int_from_variant(data.get("zone_type", data.get("resonance_type", -1)), -1),
		"zone_type_name": String(data.get("zone_type_name", data.get("resonance_type_name", ""))),
		"scar_type": _int_from_variant(data.get("scar_type", -1), -1),
		"scar_type_name": String(data.get("scar_type_name", "")),
		"combo_id": String(data.get("combo_id", "")),
		"time": float(data.get("time", Time.get_ticks_msec() / 1000.0)),
	}


func _int_from_variant(value: Variant, fallback: int = 0) -> int:
	if value is int or value is float:
		return int(value)
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return int(float(text))
	return fallback


func _emit_network_mod_hook(data: Dictionary) -> void:
	var hook_id := StringName(str(data.get("hook_id", "")))
	var entry_id := StringName(str(data.get("entry_id", "")))
	if String(hook_id).is_empty() or String(entry_id).is_empty():
		return
	network_mod_hook_received.emit(hook_id, entry_id, data.duplicate(true))


func _emit_network_weapon_field(data: Dictionary) -> void:
	var weapon_id := String(data.get("weapon_id", ""))
	if weapon_id.is_empty():
		return
	network_weapon_field_received.emit(data.duplicate(true))


func _manifest_gameplay_signature_tokens(manifest: Dictionary) -> Array[String]:
	var manifest_id := str(manifest.get("id", "")).strip_edges()
	if manifest_id.is_empty():
		return []
	var content_tokens: Array[String] = []
	for bucket in GAMEPLAY_MOD_BUCKETS:
		var entries := _manifest_bucket_entries_for_signature(manifest, bucket)
		for value in entries:
			if not (value is Dictionary):
				continue
			var entry: Dictionary = value
			var network_category := str(entry.get("network_category", _default_signature_network_category(bucket))).strip_edges()
			if network_category == "local_visual" or LOCAL_ONLY_MOD_BUCKETS.has(bucket):
				continue
			var entry_id := str(entry.get("id", "")).strip_edges()
			if entry_id.is_empty():
				continue
			var signature_entry := _filtered_mod_signature_entry(entry)
			content_tokens.append("%s:%s/%s:%s" % [
				bucket,
				manifest_id,
				entry_id,
				_stable_mod_value_text(signature_entry),
			])
	if content_tokens.is_empty():
		return []
	content_tokens.sort()
	var tokens: Array[String] = [
		"manifest:%s:%s:%d" % [
			manifest_id,
			str(manifest.get("version", "1")).strip_edges(),
			int(manifest.get("schema_version", 1)),
		],
	]
	for token in content_tokens:
		tokens.append(token)
	return tokens


func _manifest_bucket_entries_for_signature(manifest: Dictionary, bucket: String) -> Array:
	var entries := []
	var root_value: Variant = manifest.get(bucket, [])
	if root_value is Array:
		for value in root_value:
			entries.append(value)
	var content_value: Variant = manifest.get("content", {})
	if content_value is Dictionary:
		var nested_value: Variant = (content_value as Dictionary).get(bucket, [])
		if nested_value is Array:
			for value in nested_value:
				entries.append(value)
	return entries


func _filtered_mod_signature_entry(entry: Dictionary) -> Dictionary:
	var filtered := entry.duplicate(true)
	for field in ["display_name", "description", "author", "icon", "thumbnail", "preview", "creator_note", "note"]:
		filtered.erase(field)
	return filtered


func _default_signature_network_category(bucket: String) -> String:
	if LOCAL_ONLY_MOD_BUCKETS.has(bucket):
		return "local_visual"
	if HOOKABLE_MOD_BUCKETS.has(bucket) or bucket == "arenas" or bucket == "waves" or bucket == "rules" or bucket == "arena_events":
		return "deterministic_seed"
	if bucket == "weapons":
		return "reliable_event"
	return "exported_state"


func _stable_mod_value_text(value: Variant) -> String:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys := dictionary.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return str(a) < str(b)
		)
		var parts := PackedStringArray()
		for key in keys:
			parts.append("%s=%s" % [str(key), _stable_mod_value_text(dictionary[key])])
		return "{%s}" % "|".join(parts)
	if value is Array:
		var array_value := value as Array
		var parts := PackedStringArray()
		for item in array_value:
			parts.append(_stable_mod_value_text(item))
		return "[%s]" % ",".join(parts)
	if value is Color:
		var color: Color = value
		return "color(%.4f,%.4f,%.4f,%.4f)" % [color.r, color.g, color.b, color.a]
	if value is Vector2:
		var vector: Vector2 = value
		return "vec2(%.3f,%.3f)" % [vector.x, vector.y]
	return str(value)


func _vector2_from_variant(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
