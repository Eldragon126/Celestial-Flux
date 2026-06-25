extends Node2D
class_name CampaignModeDirector

signal campaign_wave_started(wave: int)
signal campaign_wave_cleared(wave: int)
signal campaign_currency_changed(credits: int)
signal campaign_over(reason: String)
signal escort_added(escort: Node)
signal alien_encounter_started(faction_id: StringName, planet: Node)
signal campaign_directive_changed(directive_id: StringName, label: String)
signal campaign_reputation_changed(reputation: float)
signal campaign_hijack_captured(invader: Node, escort: Node)

const GAME_OVER_SCENE := "res://Nodes/game_over_scene.tscn"
const TITLE_SCENE := "res://Nodes/title_screen.tscn"
const CAMPAIGN_DOCK_SCENE := preload("res://Nodes/campaign_dock_scene.tscn")
const ESCORT_SPAWN_SENTINEL := Vector2(1000000000.0, 1000000000.0)
const MOTHERSHIP_FACTION_FRIENDLY := 0
const MOTHERSHIP_FACTION_TRADER := 1
const MOTHERSHIP_FACTION_NEUTRAL := 2
const MOTHERSHIP_FACTION_HOSTILE := 3
const INVADER_PROFILE_RAIDER := 0
const INVADER_PROFILE_SKIRMISHER := 1
const INVADER_PROFILE_INTERCEPTOR := 2
const INVADER_PROFILE_BOMBER := 3
const INVADER_PROFILE_GUARD := 4

@export_group("Scene References")
@export var player_path: NodePath = ^"Player"
@export var home_planet_path: NodePath = ^"HomePlanet"
@export var hud_status_label_path: NodePath = ^"CampaignUI/HUD/Rows/StatusLabel"
@export var hud_wave_label_path: NodePath = ^"CampaignUI/HUD/Rows/WaveLabel"
@export var hud_credits_label_path: NodePath = ^"CampaignUI/HUD/Rows/CreditsLabel"
@export var hud_home_planet_label_path: NodePath = ^"CampaignUI/HUD/Rows/HomePlanetLabel"
@export var hud_escort_label_path: NodePath = ^"CampaignUI/HUD/Rows/EscortLabel"
@export var upgrade_panel_path: NodePath = ^"CampaignUI/UpgradePanel"
@export var alien_panel_path: NodePath = ^"CampaignUI/AlienPanel"
@export var alien_label_path: NodePath = ^"CampaignUI/AlienPanel/Rows/AlienLabel"

@export_group("Editable Packed Scenes")
@export var invader_scene: PackedScene = preload("res://Nodes/campaign_invader.tscn")
@export var escort_scene: PackedScene = preload("res://Nodes/campaign_escort_ship.tscn")
@export var planet_scene: PackedScene = preload("res://Nodes/planet_1.tscn")
@export var turret_scene: PackedScene = preload("res://Nodes/campaign_planet_turret.tscn")
@export var mothership_scene: PackedScene = preload("res://Nodes/campaign_mothership.tscn")

@export_group("Campaign Loop")
@export var retry_scene_path: String = "res://Nodes/campaign_mode.tscn"
@export var campaign_name: String = "Home Planet Campaign"
@export var home_planet_display_name: String = "HOME PLANET"
@export var final_wave: int = 12
@export var start_credits: int = 45
@export var base_wave_reward: int = 18
@export var invader_base_count: int = 7
@export var invader_count_per_wave: int = 2
@export var wave_spawn_radius: float = 2100.0
@export var rest_between_waves: float = 8.0
@export var initial_escort_count: int = 2
@export var max_escorts: int = 7
@export var status_override_duration: float = 2.4
@export var route_progress_goal: float = 12.0
@export var route_progress_per_wave: float = 1.0
@export var interwave_home_planet_repair_per_second: float = 14.0

@export_group("Campaign Operations")
@export var wave_directive_cycle: Array[String] = ["breach", "intercept", "salvage", "hijack", "escort", "freehold"]
@export var standard_directive_label: String = "STANDARD RAID"
@export var breach_directive_label: String = "BREACH VECTOR"
@export var intercept_directive_label: String = "INTERCEPT SWARM"
@export var salvage_directive_label: String = "SALVAGE WINDOW"
@export var hijack_directive_label: String = "CAPTURE WINDOW"
@export var escort_directive_label: String = "ESCORT RENDEZVOUS"
@export var freehold_directive_label: String = "FREEHOLD PRESSURE"
@export var directive_count_bonus: int = 1
@export var breach_wave_count_bonus: int = 3
@export_range(0.0, 1.0, 0.01) var breach_target_home_planet_bias: float = 0.86
@export_range(0.0, 1.0, 0.01) var intercept_player_target_bias: float = 0.76
@export var salvage_reward_multiplier: float = 1.45
@export var salvage_invader_health_multiplier: float = 0.86
@export var escort_directive_free_escort: bool = true
@export var freehold_directive_wake_fraction: float = 0.5

@export_group("King Of The Hill")
@export var king_of_hill_mode: bool = false
@export var hill_capture_goal: float = 90.0
@export var hill_radius: float = 520.0
@export var contested_radius: float = 780.0

@export_group("Alien Planets")
@export var encounter_planet_count: int = 4
@export var encounter_planet_min_radius: float = 1250.0
@export var encounter_planet_max_radius: float = 3400.0
@export var hostile_planet_ratio: float = 0.45
@export var alien_encounter_interval: int = 3
@export var barter_cost: int = 28
@export var barter_escort_bonus: int = 1

@export_group("Energy Currency Upgrades")
@export var escort_base_cost: int = 36
@export var escort_cost_step: int = 14
@export var speed_upgrade_cost: int = 34
@export var damage_upgrade_cost: int = 38
@export var armor_upgrade_cost: int = 42
@export var slingshot_upgrade_cost: int = 44
@export var hijack_cost: int = 48
@export var speed_upgrade_amount: float = 85.0
@export var damage_upgrade_amount: float = 0.16
@export var slingshot_factor_bonus: float = 0.06
@export var slingshot_impulse_bonus: float = 52.0

@export_group("Battle-Ship Build Panel")
@export var show_upgrade_panel_between_waves: bool = true
@export var show_upgrade_panel_near_home_planet: bool = true
@export var show_upgrade_panel_during_waves: bool = false
@export var upgrade_panel_home_planet_radius: float = 760.0
@export var upgrade_panel_button_min_width: float = 286.0
@export var upgrade_panel_button_min_height: float = 40.0

@export_group("Hijack Capture")
@export var hijack_wave_auto_arm: bool = true
@export var hijack_wave_cost_discount: float = 0.72
@export var hijack_capture_duration: float = 5.2
@export var hijack_disable_health_ratio: float = 0.26
@export var hijack_capture_reward_bonus: int = 10

@export_group("Home Planet Defense Pulse")
@export var home_planet_defense_pulse_enabled: bool = true
@export var home_planet_defense_pulse_on_breach: bool = true
@export var home_planet_defense_pulse_cooldown: float = 10.0
@export var home_planet_defense_pulse_health_threshold: float = 0.66
@export var home_planet_defense_pulse_radius: float = 780.0
@export var home_planet_defense_pulse_impulse: float = 680.0
@export var home_planet_defense_pulse_damage: float = 18.0

@export_group("Freehold Reputation")
@export var starting_freehold_reputation: float = 0.0
@export var reputation_min: float = -100.0
@export var reputation_max: float = 100.0
@export var reputation_trade_discount_per_25: float = 0.06
@export var barter_reputation_gain: float = 8.0
@export var fight_reputation_loss: float = 10.0
@export var turret_defeat_reputation_loss: float = 4.0
@export var hostile_mothership_reputation_gain: float = 5.0
@export var neutral_mothership_loss: float = 14.0

@export_group("Mothership Docking")
@export var mothership_count: int = 2
@export var mothership_spawn_min_radius: float = 2800.0
@export var mothership_spawn_max_radius: float = 5400.0
@export var mothership_spawn_angle_jitter: float = 0.09
@export var mothership_spawn_radial_stagger: float = 520.0
@export var mothership_hostile_ratio: float = 0.25
@export var mothership_trader_ratio: float = 0.5
@export var dock_scene: PackedScene = CAMPAIGN_DOCK_SCENE
@export var friendly_trade_discount: float = 0.86
@export var trader_trade_discount: float = 1.0
@export var neutral_trade_markup: float = 1.18
@export var dock_music_time_scale: float = 0.0
@export var trade_panel_path: NodePath = ^"CampaignUI/TradePanel"
@export var dock_prompt_path: NodePath = ^"CampaignUI/DockPromptLabel"

@export_group("Campaign Visual Polish")
@export var hud_panel_bg_color: Color = Color(0.006, 0.018, 0.032, 0.9)
@export var hud_panel_border_color: Color = Color(0.22, 0.94, 1.0, 0.46)
@export var upgrade_panel_bg_color: Color = Color(0.012, 0.018, 0.036, 0.9)
@export var upgrade_panel_border_color: Color = Color(0.2, 0.95, 1.0, 0.44)
@export var alien_panel_bg_color: Color = Color(0.018, 0.016, 0.03, 0.88)
@export var alien_panel_border_color: Color = Color(1.0, 0.74, 0.32, 0.44)
@export var trade_panel_bg_color: Color = Color(0.01, 0.018, 0.034, 0.94)
@export var trade_panel_border_color: Color = Color(0.36, 1.0, 0.78, 0.58)
@export var campaign_primary_text_color: Color = Color(0.54, 1.0, 0.9, 1.0)
@export var campaign_secondary_text_color: Color = Color(0.72, 0.9, 1.0, 0.92)
@export var campaign_warning_text_color: Color = Color(1.0, 0.58, 0.24, 1.0)
@export var campaign_button_bg_color: Color = Color(0.014, 0.06, 0.08, 0.92)
@export var campaign_button_hover_color: Color = Color(0.02, 0.12, 0.14, 0.96)
@export var campaign_button_pressed_color: Color = Color(0.42, 1.0, 0.82, 0.95)
@export var campaign_button_border_color: Color = Color(0.25, 1.0, 0.86, 0.42)
@export var campaign_button_hover_border_color: Color = Color(0.6, 1.0, 0.9, 0.76)
@export var campaign_button_pressed_border_color: Color = Color(1.0, 0.94, 0.38, 0.85)

@export_group("Mod And Multiplayer Support")
@export var mod_manifest_id: StringName = &""
@export var mod_gamemode_id: StringName = &""
@export var mod_campaign_id: StringName = &""
@export var network_wave_broadcast_interval: float = 0.35

var energy_credits: int = 0
var wave_index: int = 0
var damage_multiplier: float = 1.0
var speed_upgrade_level: int = 0
var damage_upgrade_level: int = 0
var armor_upgrade_level: int = 0
var slingshot_upgrade_level: int = 0
var campaign_route_progress: float = 0.0
var freehold_reputation: float = 0.0

var _player: Node2D = null
var _mother_planet: Node2D = null
var _active_invaders: Array[Node] = []
var _escorts: Array[Node] = []
var _alien_turrets: Array[Node] = []
var _encounter_planets: Array[Node2D] = []
var _motherships: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _wave_running: bool = false
var _wave_rest_remaining: float = 0.0
var _pending_hijack: bool = false
var _pending_hijack_from_directive: bool = false
var _campaign_finished: bool = false
var _hill_capture: float = 0.0
var _status_override_text: String = ""
var _status_override_remaining: float = 0.0
var _active_directive: StringName = &"standard"
var _active_directive_label: String = "STANDARD RAID"
var _active_directive_summary: String = "Intercept invaders before they reach the home planet."
var _directive_reward_multiplier: float = 1.0
var _mother_defense_pulse_remaining: float = 0.0

var _status_label: Label = null
var _wave_label: Label = null
var _credits_label: Label = null
var _mother_label: Label = null
var _escort_label: Label = null
var _upgrade_panel: Control = null
var _alien_panel: Control = null
var _alien_label: Label = null
var _trade_panel: Control = null
var _trade_title_label: Label = null
var _trade_status_label: Label = null
var _dock_prompt_label: Label = null
var _active_trade_mothership: Node = null
var _dock_scene_instance: Control = null
var _dock_pre_pause_tree_paused: bool = false
var _dock_pre_pause_time_scale: float = 1.0
var _energy_component: Node = null
var _syncing_energy_currency: bool = false
var _network_broadcast_elapsed: float = 0.0
var _registry: Node = null


func _ready() -> void:
	add_to_group("campaign_mode_director")
	_seed_rng()
	_resolve_nodes()
	_polish_campaign_ui_runtime()
	_apply_mod_catalog_metadata()
	_connect_ui_buttons()
	energy_credits = int(RunProgress.arena_flags.get("campaign_energy_credits", start_credits)) if RunProgress != null else start_credits
	campaign_route_progress = float(RunProgress.arena_flags.get("campaign_route_progress", 0.0)) if RunProgress != null else 0.0
	freehold_reputation = float(RunProgress.arena_flags.get("campaign_freehold_reputation", starting_freehold_reputation)) if RunProgress != null else starting_freehold_reputation
	_configure_run_progress()
	_sync_energy_currency()
	_configure_mother_planet()
	_spawn_initial_escorts()
	_spawn_encounter_planets()
	_spawn_motherships()
	_update_ui()
	_begin_next_wave()


func _process(delta: float) -> void:
	if _campaign_finished:
		return
	_cleanup_lists()
	_refresh_player_reference()
	_status_override_remaining = maxf(_status_override_remaining - delta, 0.0)
	_mother_defense_pulse_remaining = maxf(_mother_defense_pulse_remaining - delta, 0.0)
	_apply_interwave_repair(delta)
	_update_hill_capture(delta)
	_update_docking_prompt()
	_broadcast_network_wave_state(delta)
	if _mother_destroyed():
		_end_campaign("CAMPAIGN VECTOR: the home planet collapsed. Intercept invaders earlier or buy armor before the breach wave.")
		return
	if _wave_running and _active_invaders.is_empty():
		_complete_wave()
		return
	if not _wave_running and _wave_rest_remaining > 0.0:
		_wave_rest_remaining = maxf(_wave_rest_remaining - delta, 0.0)
		if _wave_rest_remaining <= 0.0:
			_begin_next_wave()
	_update_ui()


func add_campaign_credits(amount: int, reason: StringName = &"campaign") -> void:
	if amount == 0:
		return
	energy_credits = maxi(energy_credits + amount, 0)
	if RunProgress != null:
		RunProgress.arena_flags["campaign_energy_credits"] = energy_credits
		RunProgress.arena_flags["campaign_last_credit_reason"] = String(reason)
	_sync_energy_currency()
	campaign_currency_changed.emit(energy_credits)
	_update_ui()


func get_campaign_visual_snapshot() -> Dictionary:
	return {
		"directive": String(_active_directive),
		"directive_label": _active_directive_label,
		"route_progress": campaign_route_progress,
		"route_goal": route_progress_goal,
		"pending_hijack": _pending_hijack,
		"home_planet_pulse_cooldown": _mother_defense_pulse_remaining,
		"freehold_reputation": freehold_reputation,
		"mother_pulse_cooldown": _mother_defense_pulse_remaining,
	}


func _begin_next_wave() -> void:
	if _campaign_finished:
		return
	wave_index += 1
	_select_wave_directive()
	if RunProgress != null:
		RunProgress.wave_index = wave_index
		RunProgress.arena_flags["campaign_wave"] = wave_index
	_wave_running = true
	_active_invaders.clear()
	var count := _invader_count_for_directive()
	if king_of_hill_mode:
		count += 2 + int(_hill_capture / maxf(hill_capture_goal, 1.0) * 3.0)
	for index in range(count):
		_spawn_invader(index, count)
	_apply_start_of_wave_directive()
	if _status_label != null:
		_status_label.text = _active_directive_label if not king_of_hill_mode else "HOLD THE GRAVITY WELL"
	campaign_wave_started.emit(wave_index)
	campaign_directive_changed.emit(_active_directive, _active_directive_label)
	_broadcast_campaign_state_now()


func _spawn_invader(index: int, count: int) -> void:
	if invader_scene == null:
		return
	var invader := invader_scene.instantiate()
	if invader == null:
		return
	var invader_2d := invader as Node2D
	if invader_2d == null:
		return
	var angle := TAU * float(index) / maxf(float(count), 1.0) + _rng.randf_range(-0.18, 0.18)
	var radius := wave_spawn_radius + _rng.randf_range(-180.0, 260.0)
	var anchor := _mother_planet.global_position if _mother_planet != null else Vector2.ZERO
	invader_2d.global_position = anchor + Vector2.RIGHT.rotated(angle) * radius
	if invader.has_method("configure"):
		var row := index % 3
		var column := int(float(index) / 3.0)
		var target := _target_for_invader(index)
		invader.call("configure", target, row, column, _rng.randi())
	_configure_invader_profile(invader, index)
	_tune_invader(invader, index)
	_arm_invader_for_hijack_if_needed(invader)
	add_child(invader)
	_active_invaders.append(invader)
	_connect_signal(invader, &"destroyed", Callable(self, "_on_invader_destroyed"))
	_connect_signal(invader, &"breached_target", Callable(self, "_on_invader_breached_target"))
	_connect_signal(invader, &"disabled_for_hijack", Callable(self, "_on_invader_disabled_for_hijack"))


func _tune_invader(invader: Node, index: int) -> void:
	var wave_scale := 1.0 + float(maxi(wave_index - 1, 0)) * 0.12
	for field in [&"max_health", &"thrust_power", &"max_speed", &"reward_credits", &"breach_damage"]:
		var value: Variant = invader.get(field)
		if value is float or value is int:
			var multiplier := wave_scale
			if field == &"max_speed":
				multiplier = 1.0 + float(wave_index) * 0.035
			if field == &"reward_credits":
				multiplier = 1.0 + float(index % 3) * 0.12
			var tuned_value := float(value) * multiplier
			if field == &"reward_credits":
				invader.set(field, maxi(int(round(tuned_value)), 1))
			else:
				invader.set(field, tuned_value)
	_apply_directive_invader_tuning(invader, index)


func _select_wave_directive() -> void:
	var directive := &"standard"
	if not wave_directive_cycle.is_empty():
		var raw := wave_directive_cycle[(wave_index - 1) % wave_directive_cycle.size()].strip_edges().to_lower()
		if not raw.is_empty():
			directive = StringName(raw)
	_active_directive = directive
	_directive_reward_multiplier = 1.0
	if not _pending_hijack:
		_pending_hijack_from_directive = false
	match _active_directive:
		&"breach":
			_active_directive_label = breach_directive_label
			_active_directive_summary = "Breach ships bias toward the home planet. Pulse defense and armor matter."
		&"intercept":
			_active_directive_label = intercept_directive_label
			_active_directive_summary = "Fast raiders hunt the control vector. Kite them through gravity, then counterstrike."
		&"salvage":
			_active_directive_label = salvage_directive_label
			_active_directive_summary = "Damaged raiders carry extra energy. Clear cleanly before they scatter."
			_directive_reward_multiplier = maxf(salvage_reward_multiplier, 0.1)
		&"hijack":
			_active_directive_label = hijack_directive_label
			_active_directive_summary = "Disable a marked ship to convert it into an escort."
			if hijack_wave_auto_arm and not _pending_hijack and _escorts.size() < max_escorts:
				_pending_hijack = true
				_pending_hijack_from_directive = true
		&"escort":
			_active_directive_label = escort_directive_label
			_active_directive_summary = "Escort telemetry is aligned. Survive the wave to expand the formation."
		&"freehold":
			_active_directive_label = freehold_directive_label
			_active_directive_summary = "Planet guns and freehold reputation shape the next dock prices."
		_:
			_active_directive = &"standard"
			_active_directive_label = standard_directive_label
			_active_directive_summary = "Intercept invaders before they reach the home planet."
	if RunProgress != null:
		RunProgress.arena_flags["campaign_directive"] = String(_active_directive)
		RunProgress.arena_flags["campaign_directive_label"] = _active_directive_label


func _invader_count_for_directive() -> int:
	var count := invader_base_count + max(0, wave_index - 1) * invader_count_per_wave + directive_count_bonus
	if _active_directive == &"breach":
		count += breach_wave_count_bonus
	elif _active_directive == &"escort":
		count += 1
	return maxi(count, 0)


func _target_for_invader(index: int) -> Node2D:
	if _active_directive == &"breach" and _rng.randf() <= breach_target_home_planet_bias:
		return _mother_planet
	if _active_directive == &"intercept" and _rng.randf() <= intercept_player_target_bias:
		return _player
	if _active_directive == &"escort" and not _escorts.is_empty() and index % 3 == 0:
		var escort := _escorts[index % _escorts.size()] as Node2D
		if escort != null and is_instance_valid(escort):
			return escort
	return _mother_planet if index % 4 != 0 else _player


func _configure_invader_profile(invader: Node, index: int) -> void:
	if invader == null:
		return
	invader.set_meta(&"campaign_directive", String(_active_directive))
	var profile := INVADER_PROFILE_RAIDER
	match _active_directive:
		&"breach":
			profile = INVADER_PROFILE_BOMBER
		&"intercept":
			profile = INVADER_PROFILE_INTERCEPTOR
		&"hijack", &"salvage":
			profile = INVADER_PROFILE_SKIRMISHER
		&"escort":
			profile = INVADER_PROFILE_GUARD if index % 4 == 0 else INVADER_PROFILE_INTERCEPTOR
		&"freehold":
			profile = INVADER_PROFILE_SKIRMISHER if index % 2 == 0 else INVADER_PROFILE_BOMBER
	var value: Variant = invader.get("behavior_profile")
	if value is int:
		invader.set("behavior_profile", profile)


func _apply_directive_invader_tuning(invader: Node, _index: int) -> void:
	match _active_directive:
		&"breach":
			_multiply_numeric_field(invader, &"breach_damage", 1.32)
			_multiply_numeric_field(invader, &"max_health", 1.12)
			_multiply_numeric_field(invader, &"attack_range", 0.92)
		&"intercept":
			_multiply_numeric_field(invader, &"max_speed", 1.18)
			_multiply_numeric_field(invader, &"thrust_power", 1.12)
			_multiply_numeric_field(invader, &"fire_interval", 0.88)
		&"salvage":
			_multiply_numeric_field(invader, &"max_health", maxf(salvage_invader_health_multiplier, 0.1))
			_multiply_numeric_field(invader, &"reward_credits", maxf(salvage_reward_multiplier, 0.1), true)
		&"hijack":
			_multiply_numeric_field(invader, &"max_health", 0.94)
			_multiply_numeric_field(invader, &"max_speed", 0.92)
		&"escort":
			_multiply_numeric_field(invader, &"attack_range", 1.1)
			_multiply_numeric_field(invader, &"breach_damage", 0.9)
		&"freehold":
			_multiply_numeric_field(invader, &"fire_interval", 0.92)
			_multiply_numeric_field(invader, &"reward_credits", 1.18, true)


func _multiply_numeric_field(target: Node, field: StringName, multiplier: float, round_to_int: bool = false) -> void:
	if target == null:
		return
	var value: Variant = target.get(field)
	if value is float or value is int:
		var tuned := float(value) * multiplier
		if round_to_int:
			target.set(field, maxi(int(round(tuned)), 1))
		else:
			target.set(field, tuned)


func _apply_start_of_wave_directive() -> void:
	if _active_directive == &"hijack" and _pending_hijack:
		_arm_hijack_targets()
	elif _pending_hijack:
		_arm_hijack_targets()
	if _active_directive == &"escort" and escort_directive_free_escort and _escorts.size() < max_escorts:
		_spawn_escort()
		_set_campaign_status("ESCORT RENDEZVOUS: FORMATION EXPANDED")
	if _active_directive == &"freehold":
		_wake_freehold_turrets()


func _arm_invader_for_hijack_if_needed(invader: Node) -> void:
	if invader == null or not _pending_hijack:
		return
	if invader.has_method("arm_hijack_capture"):
		invader.call("arm_hijack_capture", hijack_capture_duration, hijack_disable_health_ratio)


func _arm_hijack_targets() -> void:
	for invader in _active_invaders:
		_arm_invader_for_hijack_if_needed(invader)


func _clear_hijack_targets() -> void:
	for invader in _active_invaders:
		if invader != null and is_instance_valid(invader) and invader.has_method("clear_hijack_capture"):
			invader.call("clear_hijack_capture")


func _wake_freehold_turrets() -> void:
	var live_turrets: Array[Node] = []
	for turret in _alien_turrets:
		if turret != null and is_instance_valid(turret) and not turret.is_queued_for_deletion():
			live_turrets.append(turret)
	var wake_count := mini(live_turrets.size(), maxi(int(ceil(float(live_turrets.size()) * maxf(freehold_directive_wake_fraction, 0.0))), 0))
	for index in range(wake_count):
		var turret := live_turrets[index]
		if turret.has_method("set_hostile"):
			turret.call("set_hostile", true)


func _advance_campaign_route() -> void:
	campaign_route_progress = minf(campaign_route_progress + route_progress_per_wave, maxf(route_progress_goal, campaign_route_progress + route_progress_per_wave))
	if RunProgress != null:
		RunProgress.arena_flags["campaign_route_progress"] = campaign_route_progress


func _complete_wave() -> void:
	_wave_running = false
	if _pending_hijack_from_directive:
		_pending_hijack = false
		_pending_hijack_from_directive = false
		_clear_hijack_targets()
	var reward := int(round(float(base_wave_reward + wave_index * 4 + (_escorts.size() * 2)) * _directive_reward_multiplier))
	add_campaign_credits(reward, &"wave_clear")
	_advance_campaign_route()
	campaign_wave_cleared.emit(wave_index)
	_broadcast_campaign_state_now()
	if wave_index >= final_wave and not king_of_hill_mode:
		_finish_campaign()
		return
	if route_progress_goal > 0.0 and campaign_route_progress >= route_progress_goal and not king_of_hill_mode:
		_finish_campaign()
		return
	if king_of_hill_mode and _hill_capture >= hill_capture_goal:
		_finish_campaign()
		return
	if alien_encounter_interval > 0 and wave_index % alien_encounter_interval == 0:
		_start_alien_encounter()
	_wave_rest_remaining = rest_between_waves


func _finish_campaign() -> void:
	_campaign_finished = true
	if _status_label != null:
		_status_label.text = "CAMPAIGN STABILIZED"
	if RunProgress != null:
		RunProgress.arena_flags["campaign_completed"] = true
		RunProgress.arena_flags["campaign_final_credits"] = energy_credits
		RunProgress.arena_flags["campaign_route_progress"] = campaign_route_progress
		RunProgress.arena_flags["campaign_freehold_reputation"] = freehold_reputation
		RunProgress.run_finished = true
	campaign_over.emit("campaign_completed")
	_broadcast_campaign_state_now()


func _end_campaign(reason: String) -> void:
	_campaign_finished = true
	if RunProgress != null:
		RunProgress.set_last_death_message(reason)
		RunProgress.arena_flags["retry_scene_path"] = retry_scene_path
		RunProgress.arena_flags["title_scene_path"] = TITLE_SCENE
	campaign_over.emit(reason)
	get_tree().change_scene_to_file(GAME_OVER_SCENE)


func _spawn_initial_escorts() -> void:
	for index in range(maxi(initial_escort_count, 0)):
		_spawn_escort(index)


func _spawn_escort(index: int = -1, position: Vector2 = ESCORT_SPAWN_SENTINEL) -> Node:
	if escort_scene == null or _escorts.size() >= max_escorts:
		return null
	var escort := escort_scene.instantiate()
	if escort == null:
		return null
	var escort_2d := escort as Node2D
	if escort_2d == null:
		return null
	var resolved_index := _escorts.size() if index < 0 else index
	var color := Color(0.2 + float(resolved_index % 3) * 0.08, 0.92, 1.0, 0.95)
	if escort.has_method("configure"):
		escort.call("configure", resolved_index, _player, _mother_planet, color)
	if escort.get("damage_multiplier") != null:
		escort.set("damage_multiplier", damage_multiplier)
	var anchor := _player.global_position if _player != null and is_instance_valid(_player) else _mother_planet.global_position if _mother_planet != null else Vector2.ZERO
	var has_custom_position := position.distance_squared_to(ESCORT_SPAWN_SENTINEL) > 1.0
	escort_2d.global_position = position if has_custom_position else anchor + Vector2.RIGHT.rotated(TAU * float(resolved_index) / 6.0) * 180.0
	add_child(escort)
	_escorts.append(escort)
	_connect_signal(escort, &"escort_destroyed", Callable(self, "_on_escort_destroyed"))
	escort_added.emit(escort)
	return escort


func _spawn_encounter_planets() -> void:
	if planet_scene == null:
		return
	for index in range(maxi(encounter_planet_count, 0)):
		var planet := planet_scene.instantiate() as Node2D
		if planet == null:
			continue
		planet.name = "CampaignEncounterPlanet%d" % index
		var angle := TAU * float(index) / maxf(float(encounter_planet_count), 1.0) + _rng.randf_range(-0.25, 0.25)
		var distance := _rng.randf_range(encounter_planet_min_radius, encounter_planet_max_radius)
		planet.global_position = (_mother_planet.global_position if _mother_planet != null else Vector2.ZERO) + Vector2.RIGHT.rotated(angle) * distance
		if planet.has_method("configure_deterministic"):
			planet.call("configure_deterministic", _rng.randi(), StringName("campaign_encounter_%d" % index))
		add_child(planet)
		_encounter_planets.append(planet)
		_spawn_planet_turrets(planet, index)


func _spawn_motherships() -> void:
	if mothership_scene == null or mothership_count <= 0:
		return
	var spawn_angle_offset := _rng.randf_range(0.0, TAU)
	for index in range(mothership_count):
		var mothership := mothership_scene.instantiate()
		if mothership == null:
			continue
		var mothership_2d := mothership as Node2D
		if mothership_2d == null:
			continue
		var angle := spawn_angle_offset + TAU * float(index) / maxf(float(mothership_count), 1.0) + _rng.randf_range(-mothership_spawn_angle_jitter, mothership_spawn_angle_jitter)
		var radius := _rng.randf_range(mothership_spawn_min_radius, mothership_spawn_max_radius) + float(index % 2) * mothership_spawn_radial_stagger
		var anchor := _mother_planet.global_position if _mother_planet != null else Vector2.ZERO
		mothership_2d.global_position = anchor + Vector2.RIGHT.rotated(angle) * radius
		var faction := _mothership_faction_for_index(index)
		if mothership.has_method("configure"):
			mothership.call("configure", index, faction, _mother_planet, _rng.randi())
		add_child(mothership)
		_motherships.append(mothership)
		_connect_signal(mothership, &"docking_requested", Callable(self, "_on_mothership_docking_requested"))
		_connect_signal(mothership, &"hostile_alert", Callable(self, "_on_mothership_hostile_alert"))
		_connect_signal(mothership, &"mothership_destroyed", Callable(self, "_on_mothership_destroyed"))


func _mothership_faction_for_index(index: int) -> int:
	if index == 0:
		return MOTHERSHIP_FACTION_TRADER
	if _rng.randf() < mothership_hostile_ratio:
		return MOTHERSHIP_FACTION_HOSTILE
	if _rng.randf() < mothership_trader_ratio:
		return MOTHERSHIP_FACTION_TRADER
	return MOTHERSHIP_FACTION_FRIENDLY if index % 2 == 0 else MOTHERSHIP_FACTION_NEUTRAL


func _spawn_planet_turrets(planet: Node2D, planet_index: int) -> void:
	if turret_scene == null or planet == null:
		return
	var turret_count := 2 if planet_index % 2 == 0 else 1
	for index in range(turret_count):
		var turret := turret_scene.instantiate()
		if turret == null:
			continue
		var turret_2d := turret as Node2D
		if turret_2d == null:
			continue
		var angle := TAU * float(index) / maxf(float(turret_count), 1.0) + float(planet_index) * 0.61
		var planet_radius := _node_radius(planet)
		turret_2d.global_position = planet.global_position + Vector2.RIGHT.rotated(angle) * (planet_radius + 74.0)
		turret_2d.rotation = angle
		var starts_hostile := _rng.randf() <= hostile_planet_ratio
		if turret.has_method("configure"):
			turret.call("configure", StringName("freehold_%d" % planet_index), starts_hostile)
		add_child(turret)
		_alien_turrets.append(turret)
		_connect_signal(turret, &"turret_defeated", Callable(self, "_on_planet_turret_defeated"))


func _start_alien_encounter() -> void:
	if _alien_panel != null:
		_alien_panel.visible = true
	if _alien_label != null:
		_alien_label.text = "ALIEN FREEHOLD: BARTER FOR ESCORTS OR FIGHT PLANET GUNS"
	var planet := _encounter_planets[_rng.randi_range(0, _encounter_planets.size() - 1)] if not _encounter_planets.is_empty() else null
	alien_encounter_started.emit(&"freehold", planet)


func _on_barter_button_pressed() -> void:
	if not _spend_credits(barter_cost, &"alien_barter"):
		return
	for turret in _alien_turrets:
		if turret != null and is_instance_valid(turret) and turret.has_method("set_hostile"):
			turret.call("set_hostile", false)
	for _i in range(barter_escort_bonus):
		_spawn_escort()
	_adjust_freehold_reputation(barter_reputation_gain, &"barter")
	_set_campaign_status("FREEHOLD BARTER COMPLETE // REPUTATION %.0f" % freehold_reputation)
	if _alien_panel != null:
		_alien_panel.visible = false


func _on_fight_button_pressed() -> void:
	for turret in _alien_turrets:
		if turret != null and is_instance_valid(turret) and turret.has_method("set_hostile"):
			turret.call("set_hostile", true)
	_adjust_freehold_reputation(-fight_reputation_loss, &"fight")
	_set_campaign_status("FREEHOLD HOSTILE // REPUTATION %.0f" % freehold_reputation)
	if _alien_panel != null:
		_alien_panel.visible = false


func _on_mothership_docking_requested(mothership: Node) -> void:
	if mothership == null or not is_instance_valid(mothership):
		return
	if mothership.has_method("is_hostile") and bool(mothership.call("is_hostile")):
		if _status_label != null:
			_status_label.text = "HOSTILE MOTHERSHIP REFUSES DOCKING"
		return
	_active_trade_mothership = mothership
	_open_dock_scene()


func _on_mothership_hostile_alert(mothership: Node, _target: Node2D) -> void:
	if _status_label != null and mothership != null and mothership.has_method("docking_status_text"):
		_status_label.text = str(mothership.call("docking_status_text")).to_upper()


func _on_mothership_destroyed(mothership: Node, reward: int) -> void:
	var was_hostile := mothership != null and mothership.has_method("is_hostile") and bool(mothership.call("is_hostile"))
	_motherships.erase(mothership)
	add_campaign_credits(maxi(reward, 1), &"mothership_destroyed")
	_adjust_freehold_reputation(hostile_mothership_reputation_gain if was_hostile else -neutral_mothership_loss, &"mothership_destroyed")
	if _active_trade_mothership == mothership:
		_close_dock_scene()


func _open_trade_panel() -> void:
	_open_dock_scene()


func _close_trade_panel() -> void:
	_close_dock_scene()


func _on_trade_exit_button_pressed() -> void:
	_close_dock_scene()


func _open_dock_scene() -> void:
	if _dock_scene_instance != null and is_instance_valid(_dock_scene_instance):
		if _dock_scene_instance.has_method("refresh"):
			_dock_scene_instance.call("refresh")
		return
	if dock_scene == null:
		if _trade_panel != null:
			_trade_panel.visible = true
		return
	var dock := dock_scene.instantiate() as Control
	if dock == null:
		return
	_dock_scene_instance = dock
	_dock_pre_pause_tree_paused = get_tree().paused
	_dock_pre_pause_time_scale = Engine.time_scale
	if _dock_pre_pause_time_scale < 0.05:
		_dock_pre_pause_time_scale = 1.0
	dock.process_mode = Node.PROCESS_MODE_ALWAYS
	dock.add_to_group("campaign_dock_scene")
	_dock_scene_parent().add_child(dock)
	_prepare_dock_scene_layout(dock)
	if dock.has_method("configure"):
		dock.call("configure", self, _active_trade_mothership)
	if _alien_panel != null:
		_alien_panel.visible = false
	if _trade_panel != null:
		_trade_panel.visible = false
	if _dock_prompt_label != null:
		_dock_prompt_label.visible = false
	Engine.time_scale = maxf(dock_music_time_scale, 0.0)
	get_tree().paused = true


func _dock_scene_parent() -> Node:
	var campaign_ui := get_node_or_null("CampaignUI") as CanvasLayer
	if campaign_ui != null:
		return campaign_ui
	return self


func _prepare_dock_scene_layout(dock: Control) -> void:
	if dock == null:
		return
	dock.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	dock.offset_left = 0.0
	dock.offset_top = 0.0
	dock.offset_right = 0.0
	dock.offset_bottom = 0.0


func _close_dock_scene() -> void:
	if _dock_scene_instance != null and is_instance_valid(_dock_scene_instance):
		_dock_scene_instance.queue_free()
	_dock_scene_instance = null
	_active_trade_mothership = null
	if _trade_panel != null:
		_trade_panel.visible = false
	get_tree().paused = _dock_pre_pause_tree_paused
	Engine.time_scale = maxf(_dock_pre_pause_time_scale, 0.05)


func _update_upgrade_panel() -> void:
	if _upgrade_panel == null:
		return
	var visible := _should_show_upgrade_panel()
	_upgrade_panel.visible = visible
	if not visible:
		return
	_configure_inline_upgrade_button(_upgrade_panel.find_child("BuyEscortButton", true, false) as Button, "BUY ESCORT", _trade_cost(escort_base_cost + _escorts.size() * escort_cost_step), _escorts.size() < max_escorts)
	_configure_inline_upgrade_button(_upgrade_panel.find_child("UpgradeSpeedButton", true, false) as Button, "SPEED L%d" % (speed_upgrade_level + 1), _trade_cost(speed_upgrade_cost + speed_upgrade_level * 12), true)
	_configure_inline_upgrade_button(_upgrade_panel.find_child("UpgradeDamageButton", true, false) as Button, "DAMAGE L%d" % (damage_upgrade_level + 1), _trade_cost(damage_upgrade_cost + damage_upgrade_level * 14), true)
	_configure_inline_upgrade_button(_upgrade_panel.find_child("UpgradeArmorButton", true, false) as Button, "ARMOR L%d" % (armor_upgrade_level + 1), _trade_cost(armor_upgrade_cost + armor_upgrade_level * 16), true)
	_configure_inline_upgrade_button(_upgrade_panel.find_child("UpgradeSlingshotButton", true, false) as Button, "SLINGSHOT L%d" % (slingshot_upgrade_level + 1), _trade_cost(slingshot_upgrade_cost + slingshot_upgrade_level * 16), true)
	_configure_inline_upgrade_button(_upgrade_panel.find_child("HijackButton", true, false) as Button, "HIJACK BEACON", _trade_cost(_hijack_base_cost()), not _pending_hijack and _escorts.size() < max_escorts)


func _should_show_upgrade_panel() -> bool:
	if _dock_scene_instance != null and is_instance_valid(_dock_scene_instance):
		return false
	if show_upgrade_panel_during_waves:
		return true
	if show_upgrade_panel_between_waves and not _wave_running:
		return true
	if show_upgrade_panel_near_home_planet and _player != null and is_instance_valid(_player) and _mother_planet != null and is_instance_valid(_mother_planet):
		return _player.global_position.distance_to(_mother_planet.global_position) <= upgrade_panel_home_planet_radius
	return false


func _configure_inline_upgrade_button(button: Button, label: String, cost: int, available: bool) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(upgrade_panel_button_min_width, upgrade_panel_button_min_height)
	button.text = "%s // %d EC" % [label, cost]
	button.disabled = not available or energy_credits < cost
	_style_campaign_button(button)


func _update_trade_panel() -> void:
	if _trade_panel == null or not _trade_panel.visible:
		return
	var dock_name := "MOTHERSHIP DOCK"
	if _active_trade_mothership != null and is_instance_valid(_active_trade_mothership) and _active_trade_mothership.has_method("docking_status_text"):
		dock_name = str(_active_trade_mothership.call("docking_status_text")).to_upper()
	if _trade_title_label != null:
		_trade_title_label.text = dock_name
	if _trade_status_label != null:
		_trade_status_label.text = "ENERGY %d // ESCORTS %d/%d // DAMAGE x%.2f" % [
			energy_credits,
			_escorts.size(),
			max_escorts,
			damage_multiplier,
		]


func get_trade_snapshot(mothership: Node = null) -> Dictionary:
	var active_ship := mothership if mothership != null else _active_trade_mothership
	var dock_name := "MOTHERSHIP DOCK"
	var faction_id := MOTHERSHIP_FACTION_TRADER
	if active_ship != null and is_instance_valid(active_ship):
		var faction_value: Variant = active_ship.get("faction")
		if faction_value is int:
			faction_id = int(faction_value)
		if active_ship.has_method("docking_status_text"):
			dock_name = str(active_ship.call("docking_status_text")).to_upper()
	var costs := {
		"escort": _trade_cost(escort_base_cost + _escorts.size() * escort_cost_step, active_ship),
		"speed": _trade_cost(speed_upgrade_cost + speed_upgrade_level * 12, active_ship),
		"damage": _trade_cost(damage_upgrade_cost + damage_upgrade_level * 14, active_ship),
		"armor": _trade_cost(armor_upgrade_cost + armor_upgrade_level * 16, active_ship),
		"slingshot": _trade_cost(slingshot_upgrade_cost + slingshot_upgrade_level * 16, active_ship),
		"hijack": _trade_cost(_hijack_base_cost(), active_ship),
	}
	return {
		"dock_name": dock_name,
		"faction": faction_id,
		"credits": energy_credits,
		"wave": wave_index,
		"final_wave": final_wave,
		"escorts": _escorts.size(),
		"max_escorts": max_escorts,
		"damage_multiplier": damage_multiplier,
		"speed_level": speed_upgrade_level,
		"damage_level": damage_upgrade_level,
		"armor_level": armor_upgrade_level,
		"slingshot_level": slingshot_upgrade_level,
		"pending_hijack": _pending_hijack,
		"home_planet_health": float(_mother_planet.call("get_health_ratio")) if _mother_planet != null and _mother_planet.has_method("get_health_ratio") else 0.0,
		"mother_health": float(_mother_planet.call("get_health_ratio")) if _mother_planet != null and _mother_planet.has_method("get_health_ratio") else 0.0,
		"home_planet_name": _home_planet_name(),
		"costs": costs,
		"can_buy_escort": _escorts.size() < max_escorts,
		"trade_multiplier": _trade_multiplier(active_ship),
		"directive": String(_active_directive),
		"directive_label": _active_directive_label,
		"directive_summary": _active_directive_summary,
		"route_progress": campaign_route_progress,
		"route_goal": route_progress_goal,
		"freehold_reputation": freehold_reputation,
		"home_planet_shield": float(_mother_planet.call("get_shield_ratio")) if _mother_planet != null and _mother_planet.has_method("get_shield_ratio") else 0.0,
		"mother_shield": float(_mother_planet.call("get_shield_ratio")) if _mother_planet != null and _mother_planet.has_method("get_shield_ratio") else 0.0,
	}


func trade_buy_escort() -> bool:
	var cost := _trade_cost(escort_base_cost + _escorts.size() * escort_cost_step)
	if _escorts.size() >= max_escorts:
		_set_campaign_status("ESCORT FORMATION FULL")
		return false
	if not _spend_credits(cost, &"buy_escort"):
		return false
	_spawn_escort()
	_set_campaign_status("ESCORT ADDED TO FORMATION")
	return true


func trade_upgrade_speed() -> bool:
	var cost := _trade_cost(speed_upgrade_cost + speed_upgrade_level * 12)
	if not _spend_credits(cost, &"upgrade_speed"):
		return false
	speed_upgrade_level += 1
	if _player != null and is_instance_valid(_player):
		for field in [&"max_speed", &"dash_speed_cap", &"absolute_velocity_cap"]:
			var value: Variant = _player.get(field)
			if value is float or value is int:
				_player.set(field, float(value) + speed_upgrade_amount)
	_set_campaign_status("SPEED VECTOR UPGRADED")
	return true


func trade_upgrade_damage() -> bool:
	var cost := _trade_cost(damage_upgrade_cost + damage_upgrade_level * 14)
	if not _spend_credits(cost, &"upgrade_damage"):
		return false
	damage_upgrade_level += 1
	damage_multiplier += damage_upgrade_amount
	if _player != null and is_instance_valid(_player):
		_player.set_meta(&"campaign_damage_multiplier", damage_multiplier)
	for escort in _escorts:
		if escort != null and is_instance_valid(escort) and escort.get("damage_multiplier") != null:
			escort.set("damage_multiplier", damage_multiplier)
	_set_campaign_status("DAMAGE VECTOR UPGRADED")
	return true


func trade_upgrade_armor() -> bool:
	var cost := _trade_cost(armor_upgrade_cost + armor_upgrade_level * 16)
	if not _spend_credits(cost, &"upgrade_armor"):
		return false
	armor_upgrade_level += 1
	if _mother_planet != null and is_instance_valid(_mother_planet) and _mother_planet.has_method("upgrade_armor"):
		_mother_planet.call("upgrade_armor", 1)
	var health := _player.get_node_or_null("HealthComponent") if _player != null else null
	if health != null:
		var max_value: Variant = health.get("max_health")
		if max_value is float or max_value is int:
			health.set("max_health", float(max_value) + 18.0)
			if health.has_method("heal"):
				health.call("heal", 18.0)
	_set_campaign_status("%s ARMOR REINFORCED" % _home_planet_name())
	return true


func trade_upgrade_slingshot() -> bool:
	var cost := _trade_cost(slingshot_upgrade_cost + slingshot_upgrade_level * 16)
	if not _spend_credits(cost, &"upgrade_slingshot"):
		return false
	slingshot_upgrade_level += 1
	if _player != null and is_instance_valid(_player):
		for pair in [
			[&"slingshot_factor", slingshot_factor_bonus],
			[&"slingshot_max_impulse", slingshot_impulse_bonus],
			[&"slingshot_mastery_cap_bonus", slingshot_impulse_bonus * 0.8],
		]:
			var field := StringName(pair[0])
			var value: Variant = _player.get(field)
			if value is float or value is int:
				_player.set(field, float(value) + float(pair[1]))
	_set_campaign_status("SLINGSHOT VECTOR UPGRADED")
	return true


func trade_prepare_hijack() -> bool:
	if _pending_hijack:
		_set_campaign_status("HIJACK BEACON ALREADY ARMED")
		return false
	if _escorts.size() >= max_escorts:
		_set_campaign_status("ESCORT FORMATION FULL")
		return false
	var cost := _trade_cost(_hijack_base_cost())
	if not _spend_credits(cost, &"hijack_ship"):
		return false
	_pending_hijack = true
	_pending_hijack_from_directive = false
	_arm_hijack_targets()
	_set_campaign_status("HIJACK READY: NEXT DISABLED SHIP JOINS FORMATION")
	return true


func request_dock_scene_close() -> void:
	_close_dock_scene()


func _on_buy_escort_button_pressed() -> void:
	trade_buy_escort()


func _on_upgrade_speed_button_pressed() -> void:
	trade_upgrade_speed()


func _on_upgrade_damage_button_pressed() -> void:
	trade_upgrade_damage()


func _on_upgrade_armor_button_pressed() -> void:
	trade_upgrade_armor()


func _on_upgrade_slingshot_button_pressed() -> void:
	trade_upgrade_slingshot()


func _on_hijack_button_pressed() -> void:
	trade_prepare_hijack()


func _on_invader_destroyed(invader: CampaignInvader, reward: int, position: Vector2) -> void:
	_active_invaders.erase(invader)
	add_campaign_credits(maxi(reward, 1), &"invader_destroyed")
	if _pending_hijack and _escorts.size() < max_escorts:
		_capture_invader_as_escort(invader, position)


func _on_invader_breached_target(invader: CampaignInvader, _target: Node, _damage: float) -> void:
	_active_invaders.erase(invader)
	if home_planet_defense_pulse_on_breach and _target == _mother_planet:
		_trigger_mother_defense_pulse()


func _on_invader_disabled_for_hijack(invader: CampaignInvader, position: Vector2) -> void:
	if not _pending_hijack:
		return
	_capture_invader_as_escort(invader, position)


func _on_planet_turret_defeated(turret: CampaignPlanetTurret, reward: int) -> void:
	_alien_turrets.erase(turret)
	add_campaign_credits(reward, &"planet_turret_defeated")
	_adjust_freehold_reputation(-turret_defeat_reputation_loss, &"planet_turret_defeated")


func _on_escort_destroyed(escort: CampaignEscortShip) -> void:
	_escorts.erase(escort)


func _capture_invader_as_escort(invader: Node, position: Vector2) -> void:
	if _escorts.size() >= max_escorts:
		_set_campaign_status("HIJACK FAILED: ESCORT FORMATION FULL")
		return
	_pending_hijack = false
	_pending_hijack_from_directive = false
	_active_invaders.erase(invader)
	_clear_hijack_targets()
	add_campaign_credits(maxi(hijack_capture_reward_bonus, 0), &"hijack_capture")
	var escort := _spawn_escort(-1, position)
	if invader != null and is_instance_valid(invader) and invader.has_method("complete_hijack_capture"):
		invader.call("complete_hijack_capture")
	elif invader != null and is_instance_valid(invader):
		invader.queue_free()
	if escort != null:
		campaign_hijack_captured.emit(invader, escort)
	_set_campaign_status("HIJACK COMPLETE: DISABLED SHIP JOINED FORMATION")


func _spend_credits(cost: int, reason: StringName) -> bool:
	if energy_credits < cost:
		_set_campaign_status("NEED %d ENERGY CREDITS" % cost)
		return false
	add_campaign_credits(-cost, reason)
	return true


func _trade_cost(base_cost: int, mothership: Node = null) -> int:
	return maxi(int(round(float(base_cost) * _trade_multiplier(mothership))), 1)


func _hijack_base_cost() -> int:
	var discount := hijack_wave_cost_discount if _active_directive == &"hijack" else 1.0
	return maxi(int(round(float(hijack_cost) * maxf(discount, 0.1))), 1)


func _trade_multiplier(mothership: Node = null) -> float:
	var active_ship := mothership if mothership != null else _active_trade_mothership
	var base_multiplier := 1.0
	if active_ship == null or not is_instance_valid(active_ship):
		base_multiplier = 1.0
	else:
		var faction_value: Variant = active_ship.get("faction")
		var faction_id := int(faction_value) if faction_value is int else MOTHERSHIP_FACTION_TRADER
		match faction_id:
			MOTHERSHIP_FACTION_FRIENDLY:
				base_multiplier = maxf(friendly_trade_discount, 0.1)
			MOTHERSHIP_FACTION_NEUTRAL:
				base_multiplier = maxf(neutral_trade_markup, 0.1)
			_:
				base_multiplier = maxf(trader_trade_discount, 0.1)
	var reputation_adjust := clampf(freehold_reputation / 25.0, -4.0, 4.0) * reputation_trade_discount_per_25
	return maxf(base_multiplier - reputation_adjust, 0.35)


func _set_campaign_status(text: String) -> void:
	_status_override_text = text
	_status_override_remaining = maxf(status_override_duration, 0.1)
	if _status_label != null:
		_status_label.text = text


func _campaign_status_text() -> String:
	if _status_override_remaining > 0.0 and not _status_override_text.is_empty():
		return _status_override_text
	if _dock_scene_instance != null and is_instance_valid(_dock_scene_instance):
		return "MOTHERSHIP DOCKED // SIMULATION HELD"
	if king_of_hill_mode:
		return "HOLD THE GRAVITY WELL // CLEAR CONTESTING INVADERS"
	if _wave_running:
		return "%s // %s" % [_active_directive_label, _active_directive_summary]
	if _wave_rest_remaining > 0.0:
		return "WAVE CLEAR // %.1fs TO NEXT RAID // BUILD, DOCK, OR REPAIR" % _wave_rest_remaining
	return "DEFEND THE %s // DOCK WITH GOLD OR GREEN CARRIERS" % _home_planet_name()


func _sync_energy_currency() -> void:
	if _energy_component == null and _player != null:
		_energy_component = _player.get_node_or_null("EnergyComponent")
	if _energy_component != null and _energy_component.has_method("set_currency"):
		_syncing_energy_currency = true
		_energy_component.call("set_currency", energy_credits)
		_syncing_energy_currency = false


func _on_energy_component_currency_changed(current_currency: int) -> void:
	if _syncing_energy_currency:
		return
	energy_credits = maxi(current_currency, 0)
	if RunProgress != null:
		RunProgress.arena_flags["campaign_energy_credits"] = energy_credits
		RunProgress.arena_flags["campaign_last_credit_reason"] = "energy_component"
	campaign_currency_changed.emit(energy_credits)
	_update_ui()


func _update_hill_capture(delta: float) -> void:
	if not king_of_hill_mode or _mother_planet == null:
		return
	var player_inside := _any_live_player_inside_hill()
	var contested := false
	for invader in _active_invaders:
		var invader_2d := invader as Node2D
		if invader_2d != null and is_instance_valid(invader_2d):
			if invader_2d.global_position.distance_to(_mother_planet.global_position) <= contested_radius:
				contested = true
				break
	if player_inside and not contested:
		_hill_capture = minf(_hill_capture + delta, hill_capture_goal)
	elif contested:
		_hill_capture = maxf(_hill_capture - delta * 0.65, 0.0)


func _apply_interwave_repair(delta: float) -> void:
	if _wave_running or _wave_rest_remaining <= 0.0 or interwave_home_planet_repair_per_second <= 0.0:
		return
	if _mother_planet != null and is_instance_valid(_mother_planet) and _mother_planet.has_method("repair"):
		_mother_planet.call("repair", interwave_home_planet_repair_per_second * delta)


func _trigger_mother_defense_pulse() -> void:
	if not home_planet_defense_pulse_enabled or _mother_planet == null or not is_instance_valid(_mother_planet):
		return
	if _mother_defense_pulse_remaining > 0.0:
		return
	var health_ratio := float(_mother_planet.call("get_health_ratio")) if _mother_planet.has_method("get_health_ratio") else 1.0
	if health_ratio > home_planet_defense_pulse_health_threshold and _active_directive != &"breach":
		return
	_mother_defense_pulse_remaining = maxf(home_planet_defense_pulse_cooldown, 0.1)
	if _mother_planet.has_method("release_defense_pulse_visual"):
		_mother_planet.call("release_defense_pulse_visual")
	var center := _mother_planet.global_position
	for invader in _active_invaders.duplicate():
		var invader_2d := invader as Node2D
		if invader_2d == null or not is_instance_valid(invader_2d) or invader_2d.is_queued_for_deletion():
			continue
		var offset := invader_2d.global_position - center
		var distance := offset.length()
		if distance <= 0.001 or distance > home_planet_defense_pulse_radius:
			continue
		var falloff := 1.0 - distance / maxf(home_planet_defense_pulse_radius, 1.0)
		var direction := offset / distance
		var velocity_value: Variant = invader.get("velocity")
		if velocity_value is Vector2:
			var current_velocity: Vector2 = velocity_value
			invader.set("velocity", current_velocity + direction * home_planet_defense_pulse_impulse * falloff)
		if invader.has_method("take_damage"):
			invader.call("take_damage", home_planet_defense_pulse_damage * falloff)
	_set_campaign_status("%s DEFENSE PULSE" % _home_planet_name())


func _adjust_freehold_reputation(delta: float, reason: StringName) -> void:
	if absf(delta) <= 0.001:
		return
	freehold_reputation = clampf(freehold_reputation + delta, reputation_min, reputation_max)
	if RunProgress != null:
		RunProgress.arena_flags["campaign_freehold_reputation"] = freehold_reputation
		RunProgress.arena_flags["campaign_reputation_reason"] = String(reason)
	campaign_reputation_changed.emit(freehold_reputation)


func _configure_mother_planet() -> void:
	if _mother_planet == null:
		return
	_mother_planet.add_to_group("campaign_mother_planet")
	_mother_planet.add_to_group("player_allies")
	_connect_signal(_mother_planet, &"mother_planet_destroyed", Callable(self, "_on_mother_planet_destroyed"))
	_connect_signal(_mother_planet, &"health_changed", Callable(self, "_on_mother_planet_health_changed"))
	_connect_signal(_mother_planet, &"shield_changed", Callable(self, "_on_mother_planet_shield_changed"))


func _on_mother_planet_destroyed() -> void:
	_end_campaign("CAMPAIGN VECTOR: the home planet shield failed under invader pressure.")


func _on_mother_planet_health_changed(_current_health: float, _max_health: float) -> void:
	_update_ui()


func _on_mother_planet_shield_changed(_current_shield: float, _max_shield: float) -> void:
	_update_ui()


func _mother_destroyed() -> bool:
	if _mother_planet == null or not is_instance_valid(_mother_planet):
		return true
	if _mother_planet.has_method("get_health_ratio"):
		return float(_mother_planet.call("get_health_ratio")) <= 0.0
	return false


func _configure_run_progress() -> void:
	if RunProgress == null:
		return
	RunProgress.arena_flags["retry_scene_path"] = retry_scene_path
	RunProgress.arena_flags["title_scene_path"] = TITLE_SCENE
	RunProgress.arena_flags["campaign_mode"] = true
	RunProgress.arena_flags["campaign_name"] = campaign_name
	RunProgress.arena_flags["king_of_hill_mode"] = king_of_hill_mode
	RunProgress.arena_flags["campaign_route_goal"] = route_progress_goal
	RunProgress.arena_flags["campaign_freehold_reputation"] = freehold_reputation
	if not String(mod_manifest_id).is_empty():
		RunProgress.arena_flags["campaign_mod_manifest_id"] = String(mod_manifest_id)
	if not String(mod_gamemode_id).is_empty():
		RunProgress.arena_flags["mod_gamemode_id"] = String(mod_gamemode_id)
	if not String(mod_campaign_id).is_empty():
		RunProgress.arena_flags["mod_campaign_id"] = String(mod_campaign_id)


func _resolve_nodes() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_refresh_player_reference()
	_mother_planet = get_node_or_null(home_planet_path) as Node2D
	if _mother_planet == null:
		_mother_planet = get_node_or_null(^"HomePlanet") as Node2D
	if _mother_planet == null:
		_mother_planet = get_node_or_null(^"MotherPlanet") as Node2D
	_status_label = get_node_or_null(hud_status_label_path) as Label
	_wave_label = get_node_or_null(hud_wave_label_path) as Label
	_credits_label = get_node_or_null(hud_credits_label_path) as Label
	_mother_label = get_node_or_null(hud_home_planet_label_path) as Label
	if _mother_label == null:
		_mother_label = get_node_or_null(^"CampaignUI/HUD/Rows/HomePlanetLabel") as Label
	if _mother_label == null:
		_mother_label = get_node_or_null(^"CampaignUI/HUD/Rows/MotherLabel") as Label
	_escort_label = get_node_or_null(hud_escort_label_path) as Label
	_upgrade_panel = get_node_or_null(upgrade_panel_path) as Control
	_alien_panel = get_node_or_null(alien_panel_path) as Control
	_alien_label = get_node_or_null(alien_label_path) as Label
	_trade_panel = get_node_or_null(trade_panel_path) as Control
	_dock_prompt_label = get_node_or_null(dock_prompt_path) as Label
	if _alien_panel != null:
		_alien_panel.visible = false
	_energy_component = _player.get_node_or_null("EnergyComponent") if _player != null else null
	if _energy_component != null and _energy_component.has_signal(&"energy_currency_changed"):
		var callable := Callable(self, "_on_energy_component_currency_changed")
		if not _energy_component.is_connected(&"energy_currency_changed", callable):
			_energy_component.connect(&"energy_currency_changed", callable)


func _home_planet_name() -> String:
	var display_name := home_planet_display_name.strip_edges().to_upper()
	return display_name if not display_name.is_empty() else "HOME PLANET"


func _polish_campaign_ui_runtime() -> void:
	var campaign_ui := get_node_or_null("CampaignUI") as CanvasLayer
	if campaign_ui == null:
		campaign_ui = CanvasLayer.new()
		campaign_ui.name = "CampaignUI"
		add_child(campaign_ui)
	var hud_panel := campaign_ui.get_node_or_null("HUD") as Control
	if hud_panel != null:
		_style_campaign_panel(hud_panel, hud_panel_bg_color, hud_panel_border_color, 2)
		_style_campaign_label_tree(hud_panel, campaign_secondary_text_color)
		if _status_label != null:
			_style_campaign_label(_status_label, campaign_primary_text_color, 18, true)
	var upgrade_panel := campaign_ui.get_node_or_null("UpgradePanel") as Control
	_upgrade_panel = upgrade_panel
	if upgrade_panel != null:
		upgrade_panel.visible = false
		_style_campaign_panel(upgrade_panel, upgrade_panel_bg_color, upgrade_panel_border_color, 2)
		_style_campaign_label_tree(upgrade_panel, campaign_primary_text_color)
		_style_campaign_button_tree(upgrade_panel)
	if _alien_panel != null:
		_alien_panel.anchor_left = 0.5
		_alien_panel.anchor_right = 0.5
		_alien_panel.anchor_top = 1.0
		_alien_panel.anchor_bottom = 1.0
		_alien_panel.offset_left = -290.0
		_alien_panel.offset_right = 290.0
		_alien_panel.offset_top = -184.0
		_alien_panel.offset_bottom = -28.0
		_style_campaign_panel(_alien_panel, alien_panel_bg_color, alien_panel_border_color, 2)
		_style_campaign_label_tree(_alien_panel, campaign_warning_text_color)
		_style_campaign_button_tree(_alien_panel)
	if _trade_panel == null:
		_trade_panel = _build_trade_panel(campaign_ui)
	else:
		_style_campaign_panel(_trade_panel, trade_panel_bg_color, trade_panel_border_color, 2)
		_style_campaign_label_tree(_trade_panel, campaign_secondary_text_color)
		_style_campaign_button_tree(_trade_panel)
	_trade_title_label = _trade_panel.find_child("TradeTitleLabel", true, false) as Label
	_trade_status_label = _trade_panel.find_child("TradeStatusLabel", true, false) as Label
	_trade_panel.visible = false
	if _dock_prompt_label == null:
		_dock_prompt_label = Label.new()
		_dock_prompt_label.name = "DockPromptLabel"
		_dock_prompt_label.anchor_left = 0.5
		_dock_prompt_label.anchor_right = 0.5
		_dock_prompt_label.anchor_top = 1.0
		_dock_prompt_label.anchor_bottom = 1.0
		_dock_prompt_label.offset_left = -280.0
		_dock_prompt_label.offset_right = 280.0
		_dock_prompt_label.offset_top = -80.0
		_dock_prompt_label.offset_bottom = -38.0
		_dock_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dock_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_dock_prompt_label.add_theme_font_size_override("font_size", 18)
		_dock_prompt_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
		_dock_prompt_label.add_theme_constant_override("outline_size", 5)
		campaign_ui.add_child(_dock_prompt_label)
	_style_campaign_label(_dock_prompt_label, campaign_primary_text_color, 18, true)
	_dock_prompt_label.visible = false


func _build_trade_panel(parent: Node) -> Control:
	var panel := PanelContainer.new()
	panel.name = "TradePanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -440.0
	panel.offset_right = -22.0
	panel.offset_top = -230.0
	panel.offset_bottom = 230.0
	_style_campaign_panel(panel, trade_panel_bg_color, trade_panel_border_color, 2)
	parent.add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 9)
	panel.add_child(rows)

	var title := _make_campaign_label("MOTHERSHIP DOCK", 22, campaign_primary_text_color, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "TradeTitleLabel"
	rows.add_child(title)
	var status := _make_campaign_label("Energy-credit market online.", 14, campaign_secondary_text_color, HORIZONTAL_ALIGNMENT_CENTER)
	status.name = "TradeStatusLabel"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(360.0, 48.0)
	rows.add_child(status)

	rows.add_child(_make_campaign_button("BuyEscortButton", "BUY ESCORT"))
	rows.add_child(_make_campaign_button("UpgradeSpeedButton", "UPGRADE SPEED"))
	rows.add_child(_make_campaign_button("UpgradeDamageButton", "UPGRADE DAMAGE"))
	rows.add_child(_make_campaign_button("UpgradeArmorButton", "REPAIR + ARMOR"))
	rows.add_child(_make_campaign_button("UpgradeSlingshotButton", "UPGRADE SLINGSHOT"))
	rows.add_child(_make_campaign_button("HijackButton", "HIJACK BEACON"))
	rows.add_child(_make_campaign_button("TradeExitButton", "UNDOCK"))
	return panel


func _make_campaign_label(text: String, size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	label.horizontal_alignment = alignment
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _make_campaign_button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(360.0, 38.0)
	button.add_theme_font_size_override("font_size", 15)
	_style_campaign_button(button)
	return button


func _style_campaign_panel(panel: Control, bg: Color, border: Color, width: int = 1) -> void:
	var panel_container := panel as PanelContainer
	if panel_container == null:
		return
	panel_container.add_theme_stylebox_override("panel", _campaign_style(bg, border, width))


func _style_campaign_label(label: Label, color: Color, size: int = 0, strong_outline: bool = false) -> void:
	label.modulate = color
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9 if strong_outline else 0.72))
	label.add_theme_constant_override("outline_size", 5 if strong_outline else 3)


func _style_campaign_label_tree(root: Control, color: Color) -> void:
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null:
			_style_campaign_label(label, color)


func _style_campaign_button(button: Button) -> void:
	button.add_theme_color_override("font_color", campaign_primary_text_color)
	button.add_theme_color_override("font_hover_color", Color(0.9, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.02, 0.08, 0.09, 1.0))
	button.add_theme_stylebox_override("normal", _campaign_style(campaign_button_bg_color, campaign_button_border_color))
	button.add_theme_stylebox_override("hover", _campaign_style(campaign_button_hover_color, campaign_button_hover_border_color))
	button.add_theme_stylebox_override("pressed", _campaign_style(campaign_button_pressed_color, campaign_button_pressed_border_color))


func _style_campaign_button_tree(root: Control) -> void:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null:
			_style_campaign_button(button)


func _campaign_style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _refresh_player_reference() -> void:
	if get_tree() == null:
		return
	var local_player := MultiplayerTargeting.local_player(get_tree())
	if local_player != null and is_instance_valid(local_player):
		_player = local_player


func _connect_ui_buttons() -> void:
	_connect_button(^"CampaignUI/UpgradePanel/Rows/BuyEscortButton", Callable(self, "_on_buy_escort_button_pressed"))
	_connect_button(^"CampaignUI/UpgradePanel/Rows/UpgradeSpeedButton", Callable(self, "_on_upgrade_speed_button_pressed"))
	_connect_button(^"CampaignUI/UpgradePanel/Rows/UpgradeDamageButton", Callable(self, "_on_upgrade_damage_button_pressed"))
	_connect_button(^"CampaignUI/UpgradePanel/Rows/UpgradeArmorButton", Callable(self, "_on_upgrade_armor_button_pressed"))
	_connect_button(^"CampaignUI/UpgradePanel/Rows/UpgradeSlingshotButton", Callable(self, "_on_upgrade_slingshot_button_pressed"))
	_connect_button(^"CampaignUI/UpgradePanel/Rows/HijackButton", Callable(self, "_on_hijack_button_pressed"))
	_connect_button(^"CampaignUI/AlienPanel/Rows/BarterButton", Callable(self, "_on_barter_button_pressed"))
	_connect_button(^"CampaignUI/AlienPanel/Rows/FightButton", Callable(self, "_on_fight_button_pressed"))
	_connect_button(^"CampaignUI/TradePanel/Rows/BuyEscortButton", Callable(self, "_on_buy_escort_button_pressed"))
	_connect_button(^"CampaignUI/TradePanel/Rows/UpgradeSpeedButton", Callable(self, "_on_upgrade_speed_button_pressed"))
	_connect_button(^"CampaignUI/TradePanel/Rows/UpgradeDamageButton", Callable(self, "_on_upgrade_damage_button_pressed"))
	_connect_button(^"CampaignUI/TradePanel/Rows/UpgradeArmorButton", Callable(self, "_on_upgrade_armor_button_pressed"))
	_connect_button(^"CampaignUI/TradePanel/Rows/UpgradeSlingshotButton", Callable(self, "_on_upgrade_slingshot_button_pressed"))
	_connect_button(^"CampaignUI/TradePanel/Rows/HijackButton", Callable(self, "_on_hijack_button_pressed"))
	_connect_button(^"CampaignUI/TradePanel/Rows/TradeExitButton", Callable(self, "_on_trade_exit_button_pressed"))


func _connect_button(path: NodePath, callback: Callable) -> void:
	var button := get_node_or_null(path) as Button
	if button != null and not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _connect_signal(source: Node, signal_name: StringName, callable: Callable) -> void:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _update_ui() -> void:
	if _status_label != null:
		_status_label.text = _campaign_status_text()
	if _wave_label != null:
		var route := " // ROUTE %d%%" % int(round(campaign_route_progress / maxf(route_progress_goal, 1.0) * 100.0)) if route_progress_goal > 0.0 else ""
		_wave_label.text = "WAVE %d/%d // %s%s" % [wave_index, final_wave, _active_directive_label, route]
	if _credits_label != null:
		_credits_label.text = "ENERGY CREDITS %d // FREEHOLD %.0f" % [energy_credits, freehold_reputation]
	if _mother_label != null:
		var ratio := float(_mother_planet.call("get_health_ratio")) if _mother_planet != null and _mother_planet.has_method("get_health_ratio") else 0.0
		var shield_ratio := float(_mother_planet.call("get_shield_ratio")) if _mother_planet != null and _mother_planet.has_method("get_shield_ratio") else 0.0
		var hill := " // HILL %d%%" % int(round(_hill_capture / maxf(hill_capture_goal, 1.0) * 100.0)) if king_of_hill_mode else ""
		_mother_label.text = "%s %d%% // SHIELD %d%%%s" % [_home_planet_name(), int(round(ratio * 100.0)), int(round(shield_ratio * 100.0)), hill]
	if _escort_label != null:
		var hijack := " // HIJACK ARMED" if _pending_hijack else ""
		_escort_label.text = "ESCORTS %d/%d // DMG x%.2f%s" % [_escorts.size(), max_escorts, damage_multiplier, hijack]
	_update_upgrade_panel()
	_update_trade_panel()


func _update_docking_prompt() -> void:
	if _dock_prompt_label == null or _player == null or not is_instance_valid(_player):
		return
	if _trade_panel != null and _trade_panel.visible:
		_dock_prompt_label.visible = false
		return
	var nearest := _nearest_dockable_mothership()
	if nearest == null:
		_dock_prompt_label.visible = false
		return
	var ship_2d := nearest as Node2D
	if ship_2d == null:
		_dock_prompt_label.visible = false
		return
	var distance := _player.global_position.distance_to(ship_2d.global_position)
	var radius := float(nearest.get("docking_radius")) if nearest.get("docking_radius") != null else 260.0
	_dock_prompt_label.visible = distance <= radius * 1.32
	if _dock_prompt_label.visible:
		var status := str(nearest.call("docking_status_text")) if nearest.has_method("docking_status_text") else "MOTHERSHIP DOCK"
		_dock_prompt_label.text = "DOCK NEARBY: %s // CONFIRM TO HOLD SIMULATION" % status.to_upper()


func _nearest_dockable_mothership() -> Node:
	var best: Node = null
	var best_distance := INF
	for node in _motherships:
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_method("is_hostile") and bool(node.call("is_hostile")):
			continue
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		var distance := node_2d.global_position.distance_squared_to(_player.global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best


func _any_live_player_inside_hill() -> bool:
	if _mother_planet == null or not is_instance_valid(_mother_planet):
		return false
	for player in MultiplayerTargeting.live_players(get_tree()):
		if player.global_position.distance_to(_mother_planet.global_position) <= hill_radius:
			return true
	return false


func _broadcast_network_wave_state(delta: float) -> void:
	if NetworkSession == null or not NetworkSession.has_method("is_network_active") or not bool(NetworkSession.call("is_network_active")):
		return
	_network_broadcast_elapsed += delta
	if _network_broadcast_elapsed < maxf(network_wave_broadcast_interval, 0.1):
		return
	_network_broadcast_elapsed = 0.0
	_broadcast_campaign_state_now()


func _broadcast_campaign_state_now() -> void:
	if NetworkSession == null or not NetworkSession.has_method("broadcast_wave_state"):
		return
	if NetworkSession.has_method("is_network_active") and not bool(NetworkSession.call("is_network_active")):
		return
	NetworkSession.call("broadcast_wave_state", {
		"mode": "king_of_the_hill" if king_of_hill_mode else "campaign",
		"wave": wave_index,
		"active_invaders": _active_invaders.size(),
		"escorts": _escorts.size(),
		"energy_credits": energy_credits,
		"home_planet_health": float(_mother_planet.call("get_health_ratio")) if _mother_planet != null and _mother_planet.has_method("get_health_ratio") else 0.0,
		"home_planet_shield": float(_mother_planet.call("get_shield_ratio")) if _mother_planet != null and _mother_planet.has_method("get_shield_ratio") else 0.0,
		"mother_health": float(_mother_planet.call("get_health_ratio")) if _mother_planet != null and _mother_planet.has_method("get_health_ratio") else 0.0,
		"mother_shield": float(_mother_planet.call("get_shield_ratio")) if _mother_planet != null and _mother_planet.has_method("get_shield_ratio") else 0.0,
		"hill_capture": _hill_capture,
		"campaign_directive": String(_active_directive),
		"route_progress": campaign_route_progress,
		"route_goal": route_progress_goal,
		"freehold_reputation": freehold_reputation,
		"pending_hijack": _pending_hijack,
		"mod_manifest_id": String(mod_manifest_id),
		"mod_gamemode_id": String(mod_gamemode_id),
		"mod_campaign_id": String(mod_campaign_id),
	})


func _apply_mod_catalog_metadata() -> void:
	_registry = _find_mod_registry()
	_apply_mod_entry("gamemodes", mod_gamemode_id)
	_apply_mod_entry("campaigns", mod_campaign_id)


func _apply_mod_entry(bucket: String, entry_id: StringName) -> void:
	if _registry == null or String(entry_id).is_empty() or not _registry.has_method("get_entry"):
		return
	var value: Variant = _registry.call("get_entry", bucket, entry_id)
	if not (value is Dictionary):
		return
	var entry: Dictionary = value
	var display_name := str(entry.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		campaign_name = display_name
	if entry.has("recommended_days"):
		final_wave = max(final_wave, int(entry.get("recommended_days", final_wave)))
	if entry.has("recommended_waves"):
		final_wave = max(final_wave, int(entry.get("recommended_waves", final_wave)))
	if entry.has("starting_energy_credits"):
		start_credits = maxi(int(entry.get("starting_energy_credits", start_credits)), 0)
	if entry.has("hostile_planet_ratio"):
		hostile_planet_ratio = clampf(float(entry.get("hostile_planet_ratio", hostile_planet_ratio)), 0.0, 1.0)
	if RunProgress != null:
		RunProgress.arena_flags["campaign_mod_entry_%s" % bucket] = String(entry_id)
		RunProgress.arena_flags["campaign_mod_entry_%s_name" % bucket] = display_name


func _find_mod_registry() -> Node:
	for node in get_tree().get_nodes_in_group("mod_content_registry"):
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			return node
	var registry := ModContentRegistry.new()
	registry.name = "ModContentRegistry"
	add_child(registry)
	if registry.has_method("reload_registry"):
		registry.call("reload_registry")
	return registry


func _cleanup_lists() -> void:
	for index in range(_active_invaders.size() - 1, -1, -1):
		var node := _active_invaders[index]
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			_active_invaders.remove_at(index)
	for index in range(_escorts.size() - 1, -1, -1):
		var node := _escorts[index]
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			_escorts.remove_at(index)
	for index in range(_alien_turrets.size() - 1, -1, -1):
		var node := _alien_turrets[index]
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			_alien_turrets.remove_at(index)
	for index in range(_motherships.size() - 1, -1, -1):
		var node := _motherships[index]
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			_motherships.remove_at(index)


func _seed_rng() -> void:
	if RunProgress != null and int(RunProgress.run_seed) != 0:
		_rng.seed = int(RunProgress.run_seed) ^ 0xC411A16
	else:
		_rng.randomize()


func _node_radius(node: Node2D) -> float:
	var radius_value: Variant = node.get("radius")
	if radius_value is float or radius_value is int:
		return maxf(float(radius_value), 32.0)
	var base_radius_value: Variant = node.get("base_radius")
	if base_radius_value is float or base_radius_value is int:
		return maxf(float(base_radius_value), 32.0)
	return 120.0
