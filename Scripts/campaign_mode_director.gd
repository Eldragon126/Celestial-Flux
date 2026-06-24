extends Node2D
class_name CampaignModeDirector

signal campaign_wave_started(wave: int)
signal campaign_wave_cleared(wave: int)
signal campaign_currency_changed(credits: int)
signal campaign_over(reason: String)
signal escort_added(escort: Node)
signal alien_encounter_started(faction_id: StringName, planet: Node)

const GAME_OVER_SCENE := "res://Nodes/game_over_scene.tscn"
const TITLE_SCENE := "res://Nodes/title_screen.tscn"
const ESCORT_SPAWN_SENTINEL := Vector2(1000000000.0, 1000000000.0)

@export_group("Scene References")
@export var player_path: NodePath = ^"Player"
@export var mother_planet_path: NodePath = ^"MotherPlanet"
@export var hud_status_label_path: NodePath = ^"CampaignUI/HUD/Rows/StatusLabel"
@export var hud_wave_label_path: NodePath = ^"CampaignUI/HUD/Rows/WaveLabel"
@export var hud_credits_label_path: NodePath = ^"CampaignUI/HUD/Rows/CreditsLabel"
@export var hud_mother_label_path: NodePath = ^"CampaignUI/HUD/Rows/MotherLabel"
@export var hud_escort_label_path: NodePath = ^"CampaignUI/HUD/Rows/EscortLabel"
@export var alien_panel_path: NodePath = ^"CampaignUI/AlienPanel"
@export var alien_label_path: NodePath = ^"CampaignUI/AlienPanel/Rows/AlienLabel"

@export_group("Editable Packed Scenes")
@export var invader_scene: PackedScene = preload("res://Nodes/campaign_invader.tscn")
@export var escort_scene: PackedScene = preload("res://Nodes/campaign_escort_ship.tscn")
@export var planet_scene: PackedScene = preload("res://Nodes/planet_1.tscn")
@export var turret_scene: PackedScene = preload("res://Nodes/campaign_planet_turret.tscn")

@export_group("Campaign Loop")
@export var retry_scene_path: String = "res://Nodes/campaign_mode.tscn"
@export var campaign_name: String = "Mother Planet Campaign"
@export var final_wave: int = 12
@export var start_credits: int = 45
@export var base_wave_reward: int = 18
@export var invader_base_count: int = 7
@export var invader_count_per_wave: int = 2
@export var wave_spawn_radius: float = 2100.0
@export var rest_between_waves: float = 4.0
@export var initial_escort_count: int = 2
@export var max_escorts: int = 7

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

var _player: Node2D = null
var _mother_planet: Node2D = null
var _active_invaders: Array[Node] = []
var _escorts: Array[Node] = []
var _alien_turrets: Array[Node] = []
var _encounter_planets: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _wave_running: bool = false
var _wave_rest_remaining: float = 0.0
var _pending_hijack: bool = false
var _campaign_finished: bool = false
var _hill_capture: float = 0.0

var _status_label: Label = null
var _wave_label: Label = null
var _credits_label: Label = null
var _mother_label: Label = null
var _escort_label: Label = null
var _alien_panel: Control = null
var _alien_label: Label = null
var _energy_component: Node = null
var _syncing_energy_currency: bool = false
var _network_broadcast_elapsed: float = 0.0
var _registry: Node = null


func _ready() -> void:
	add_to_group("campaign_mode_director")
	_seed_rng()
	_resolve_nodes()
	_apply_mod_catalog_metadata()
	_connect_ui_buttons()
	_configure_run_progress()
	energy_credits = int(RunProgress.arena_flags.get("campaign_energy_credits", start_credits)) if RunProgress != null else start_credits
	_sync_energy_currency()
	_configure_mother_planet()
	_spawn_initial_escorts()
	_spawn_encounter_planets()
	_update_ui()
	_begin_next_wave()


func _process(delta: float) -> void:
	if _campaign_finished:
		return
	_cleanup_lists()
	_refresh_player_reference()
	_update_hill_capture(delta)
	_broadcast_network_wave_state(delta)
	if _mother_destroyed():
		_end_campaign("CAMPAIGN VECTOR: the mother planet collapsed. Intercept invaders earlier or buy armor before the breach wave.")
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


func _begin_next_wave() -> void:
	if _campaign_finished:
		return
	wave_index += 1
	if RunProgress != null:
		RunProgress.wave_index = wave_index
		RunProgress.arena_flags["campaign_wave"] = wave_index
	_wave_running = true
	_active_invaders.clear()
	var count = invader_base_count + max(0, wave_index - 1) * invader_count_per_wave
	if king_of_hill_mode:
		count += 2 + int(_hill_capture / maxf(hill_capture_goal, 1.0) * 3.0)
	for index in range(count):
		_spawn_invader(index, count)
	if _status_label != null:
		_status_label.text = "DEFEND THE MOTHER VECTOR" if not king_of_hill_mode else "HOLD THE GRAVITY WELL"
	campaign_wave_started.emit(wave_index)
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
		var target := _mother_planet if index % 4 != 0 else _player
		invader.call("configure", target, row, column, _rng.randi())
	_tune_invader(invader, index)
	add_child(invader)
	_active_invaders.append(invader)
	_connect_signal(invader, &"destroyed", Callable(self, "_on_invader_destroyed"))
	_connect_signal(invader, &"breached_target", Callable(self, "_on_invader_breached_target"))


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


func _complete_wave() -> void:
	_wave_running = false
	var reward := base_wave_reward + wave_index * 4 + (_escorts.size() * 2)
	add_campaign_credits(reward, &"wave_clear")
	campaign_wave_cleared.emit(wave_index)
	_broadcast_campaign_state_now()
	if wave_index >= final_wave and not king_of_hill_mode:
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
	if _alien_panel != null:
		_alien_panel.visible = false


func _on_fight_button_pressed() -> void:
	for turret in _alien_turrets:
		if turret != null and is_instance_valid(turret) and turret.has_method("set_hostile"):
			turret.call("set_hostile", true)
	if _alien_panel != null:
		_alien_panel.visible = false


func _on_buy_escort_button_pressed() -> void:
	var cost := escort_base_cost + _escorts.size() * escort_cost_step
	if _spend_credits(cost, &"buy_escort"):
		_spawn_escort()


func _on_upgrade_speed_button_pressed() -> void:
	if not _spend_credits(speed_upgrade_cost + speed_upgrade_level * 12, &"upgrade_speed"):
		return
	speed_upgrade_level += 1
	if _player != null and is_instance_valid(_player):
		for field in [&"max_speed", &"dash_speed_cap", &"absolute_velocity_cap"]:
			var value: Variant = _player.get(field)
			if value is float or value is int:
				_player.set(field, float(value) + speed_upgrade_amount)


func _on_upgrade_damage_button_pressed() -> void:
	if not _spend_credits(damage_upgrade_cost + damage_upgrade_level * 14, &"upgrade_damage"):
		return
	damage_upgrade_level += 1
	damage_multiplier += damage_upgrade_amount
	if _player != null and is_instance_valid(_player):
		_player.set_meta(&"campaign_damage_multiplier", damage_multiplier)
	for escort in _escorts:
		if escort != null and is_instance_valid(escort) and escort.get("damage_multiplier") != null:
			escort.set("damage_multiplier", damage_multiplier)


func _on_upgrade_armor_button_pressed() -> void:
	if not _spend_credits(armor_upgrade_cost + armor_upgrade_level * 16, &"upgrade_armor"):
		return
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


func _on_upgrade_slingshot_button_pressed() -> void:
	if not _spend_credits(slingshot_upgrade_cost + slingshot_upgrade_level * 16, &"upgrade_slingshot"):
		return
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


func _on_hijack_button_pressed() -> void:
	if _spend_credits(hijack_cost, &"hijack_ship"):
		_pending_hijack = true
		if _status_label != null:
			_status_label.text = "HIJACK READY: NEXT DISABLED SHIP JOINS FORMATION"


func _on_invader_destroyed(invader: CampaignInvader, reward: int, position: Vector2) -> void:
	_active_invaders.erase(invader)
	add_campaign_credits(maxi(reward, 1), &"invader_destroyed")
	if _pending_hijack and _escorts.size() < max_escorts:
		_pending_hijack = false
		_spawn_escort(-1, position)


func _on_invader_breached_target(invader: CampaignInvader, _target: Node, _damage: float) -> void:
	_active_invaders.erase(invader)


func _on_planet_turret_defeated(turret: CampaignPlanetTurret, reward: int) -> void:
	_alien_turrets.erase(turret)
	add_campaign_credits(reward, &"planet_turret_defeated")


func _on_escort_destroyed(escort: CampaignEscortShip) -> void:
	_escorts.erase(escort)


func _spend_credits(cost: int, reason: StringName) -> bool:
	if energy_credits < cost:
		if _status_label != null:
			_status_label.text = "NEED %d ENERGY CREDITS" % cost
		return false
	add_campaign_credits(-cost, reason)
	return true


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


func _configure_mother_planet() -> void:
	if _mother_planet == null:
		return
	_mother_planet.add_to_group("campaign_mother_planet")
	_mother_planet.add_to_group("player_allies")
	_connect_signal(_mother_planet, &"mother_planet_destroyed", Callable(self, "_on_mother_planet_destroyed"))


func _on_mother_planet_destroyed() -> void:
	_end_campaign("CAMPAIGN VECTOR: the mother planet shield failed under invader pressure.")


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
	if not String(mod_manifest_id).is_empty():
		RunProgress.arena_flags["campaign_mod_manifest_id"] = String(mod_manifest_id)
	if not String(mod_gamemode_id).is_empty():
		RunProgress.arena_flags["mod_gamemode_id"] = String(mod_gamemode_id)
	if not String(mod_campaign_id).is_empty():
		RunProgress.arena_flags["mod_campaign_id"] = String(mod_campaign_id)


func _resolve_nodes() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_refresh_player_reference()
	_mother_planet = get_node_or_null(mother_planet_path) as Node2D
	_status_label = get_node_or_null(hud_status_label_path) as Label
	_wave_label = get_node_or_null(hud_wave_label_path) as Label
	_credits_label = get_node_or_null(hud_credits_label_path) as Label
	_mother_label = get_node_or_null(hud_mother_label_path) as Label
	_escort_label = get_node_or_null(hud_escort_label_path) as Label
	_alien_panel = get_node_or_null(alien_panel_path) as Control
	_alien_label = get_node_or_null(alien_label_path) as Label
	if _alien_panel != null:
		_alien_panel.visible = false
	_energy_component = _player.get_node_or_null("EnergyComponent") if _player != null else null
	if _energy_component != null and _energy_component.has_signal(&"energy_currency_changed"):
		var callable := Callable(self, "_on_energy_component_currency_changed")
		if not _energy_component.is_connected(&"energy_currency_changed", callable):
			_energy_component.connect(&"energy_currency_changed", callable)


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
	if _wave_label != null:
		_wave_label.text = "WAVE %d/%d" % [wave_index, final_wave]
	if _credits_label != null:
		_credits_label.text = "ENERGY CREDITS %d" % energy_credits
	if _mother_label != null:
		var ratio := float(_mother_planet.call("get_health_ratio")) if _mother_planet != null and _mother_planet.has_method("get_health_ratio") else 0.0
		var hill := " // HILL %d%%" % int(round(_hill_capture / maxf(hill_capture_goal, 1.0) * 100.0)) if king_of_hill_mode else ""
		_mother_label.text = "MOTHER VECTOR %d%%%s" % [int(round(ratio * 100.0)), hill]
	if _escort_label != null:
		_escort_label.text = "ESCORTS %d/%d // DMG x%.2f" % [_escorts.size(), max_escorts, damage_multiplier]


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
		"mother_health": float(_mother_planet.call("get_health_ratio")) if _mother_planet != null and _mother_planet.has_method("get_health_ratio") else 0.0,
		"hill_capture": _hill_capture,
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
