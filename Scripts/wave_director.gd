extends Node2D

# Coherent arcade loop for Orbital Drift. The director stages the modular
# enemies, hazards, HUD feedback, and boss fights into readable waves.
signal boss_wave
signal regular_wave
signal wave_cleared(wave: int)
signal boss_defeated_anchor(boss_scene_path: String)

const BASE_ENEMY_SCENE = preload("res://Nodes/base_enemy.tscn")
const BASE_SHOOTER_SCENE = preload("res://Nodes/base_shooter_enemy.tscn")
const LEECH_SCENE = preload("res://Nodes/leech_parasite.tscn")
const ORBITER_DRONE_SCENE = preload("res://Nodes/orbiter_drone.tscn")
const GRAVITY_LEECH_SCENE = preload("res://Nodes/gravity_leech.tscn")
const SEEKER_FRAGMENT_SCENE = preload("res://Nodes/seeker_fragment.tscn")
const SHIELD_BREAKER_SCENE = preload("res://Nodes/shield_breaker_unit.tscn")
const CHAOS_WISP_SCENE = preload("res://Nodes/chaos_wisp.tscn")
const SPLITTER_SCENE = preload("res://Nodes/splitting_asteroid_bot.tscn")
const HARASSER_SCENE = preload("res://Nodes/gravity_harasser.tscn")
const SNIPER_SCENE = preload("res://Nodes/sniper_turret.tscn")
const SHIELDER_SCENE = preload("res://Nodes/shielder_support.tscn")
const NEBULA_SCENE = preload("res://Nodes/nebula_cloud.tscn")
const UNSTABLE_MOON_SCENE = preload("res://Nodes/unstable_moon.tscn")
const WORMHOLE_PAIR_SCENE = preload("res://Nodes/wormhole_pair.tscn")
const GRAVITY_WARDEN_SCENE = preload("res://Nodes/gravity_warden_boss.tscn")
const ACCRETION_CORE_SCENE = preload("res://Nodes/accretion_core_boss.tscn")
const NULL_SERAPH_SCENE = preload("res://Nodes/null_vector_seraph_boss.tscn")
const MAGNETAR_TWINS_SCENE = preload("res://Nodes/magnetar_twins_boss.tscn")
const RIFT_WEAVER_SCENE = preload("res://Nodes/rift_weaver_boss.tscn")
const POLYMORPH_BOSS_SCENE = preload("res://Nodes/ParametricEquationEnemies/polymorph_boss.tscn")
const CENTRIFUGE_MARSHAL_SCENE = preload("res://Nodes/centrifuge_marshal_boss.tscn")
const PARAMETRIC_1_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_1.tscn")
const PARAMETRIC_2_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_2.tscn")
const PARAMETRIC_3_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_3.tscn")
const PARAMETRIC_4_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_4.tscn")
const PARAMETRIC_5_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_5.tscn")
const GRAVIMETRIC_ECHO_DRONE_SCENE = preload("res://Nodes/gravimetric_echo_drone.tscn")
const EVENT_HORIZON_WARDEN_ENEMY_SCENE = preload("res://Nodes/event_horizon_warden.tscn")
const PHASE_SLIP_SWARM_SCENE = preload("res://Nodes/phase_slip_swarm.tscn")
const ORBITAL_NULL_HARVESTER_SCENE = preload("res://Nodes/orbital_null_harvester.tscn")
const RESONANCE_PARALYTIC_CONSTRUCT_SCENE = preload("res://Nodes/resonance_paralytic_construct.tscn")

@export var first_wave_delay = 2.0
@export var rest_between_waves = 4.0
@export var spawn_delay = 0.48
@export var min_spawn_radius = 760.0
@export var max_spawn_radius = 1220.0
@export var boss_every_waves = 5
@export var max_regular_enemies = 10
@export var recovery_wave_interval: int = 4
@export var recovery_spawn_multiplier: float = 0.55
@export var recovery_rest_bonus: float = 2.5
@export var early_wave_fire_rate_bonus: float = 1.38

var _player: Node2D = null
var _level_root: Node = null
var _wave = 0
var _wave_running = false
var _spawning = false
var _boss: Node = null
var _active_enemies: Array[Node] = []
var _active_hazards: Array[Node] = []
var _rng = RandomNumberGenerator.new()

var _canvas: CanvasLayer
var _banner_label: Label
var _status_label: Label
var _boss_panel: PanelContainer
var _boss_label: Label
var _boss_bar: ProgressBar
var _waves_halted: bool = false
var _last_boss_scene_path: String = ""

func _ready() -> void:
	_rng.randomize()
	_level_root = get_tree().current_scene
	_build_ui()
	call_deferred("_start_director")
	$WaveMusic.play()
	$BossWaveMusic.stream_paused = true
	$"WaveMusic/Volume Intro".play("Volume Intro")

func _process(_delta: float) -> void:
	_cleanup_tracking()
	_update_status()

	if not _wave_running or _spawning:
		return

	if _boss != null:
		if not is_instance_valid(_boss):
			_boss = null
			_complete_wave()
		else:
			_update_boss_bar()
		return

	if _active_enemies.is_empty():
		_complete_wave()

func _start_director() -> void:
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if _player == null:
		_banner_label.text = "NO PLAYER SIGNAL"
		return

	_spawn_battlefield_features()
	_refresh_player_planet_cache()
	_banner_label.text = "WAVE SYSTEM ONLINE"
	await get_tree().create_timer(first_wave_delay).timeout
	_begin_next_wave()

func halt_waves() -> void:
	_waves_halted = true
	_wave_running = false
	_spawning = false

func restore_wave_index(wave: int) -> void:
	_wave = maxi(wave, 0)
	if _wave > 0:
		_banner_label.text = "ANCHOR WAVE %d" % _wave

func get_current_wave() -> int:
	return _wave

func register_secret_boss(boss: Node, display_name: String) -> void:
	if boss == null or not is_instance_valid(boss):
		return

	_boss = boss
	_last_boss_scene_path = ""
	_wave_running = true
	_spawning = false
	if not _active_enemies.has(boss):
		_active_enemies.append(boss)

	_boss_panel.visible = true
	_boss_label.text = display_name
	_banner_label.text = "SECRET BOSS: %s" % display_name

	$BossWaveMusic.play()
	$WaveMusic.stream_paused = true
	$"BossWaveMusic/Volume Intro".play("Volume Intro")

	var health_callable := Callable(self, "_on_boss_health_changed")
	if boss.has_signal("boss_health_changed") and not boss.is_connected("boss_health_changed", health_callable):
		boss.connect("boss_health_changed", health_callable)

	var defeat_callable := Callable(self, "_on_secret_boss_defeated")
	if boss.has_signal("boss_defeated") and not boss.is_connected("boss_defeated", defeat_callable):
		boss.connect("boss_defeated", defeat_callable)

func register_external_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	if not enemy.is_in_group("wave_enemy"):
		enemy.add_to_group("wave_enemy")
	if not _active_enemies.has(enemy):
		_active_enemies.append(enemy)

func _begin_next_wave() -> void:
	if _waves_halted or not _waves_enabled():
		_banner_label.text = "BOSS RUSH CLEARED" if RunProgress and RunProgress.boss_rush_mode and RunProgress.run_finished else "WAVE DIRECTOR STANDBY"
		return
	if _player == null or not is_instance_valid(_player):
		return

	_wave += 1
	if RunProgress:
		RunProgress.sync_phase_from_wave(_wave)
	_wave_running = true
	_spawning = true
	_boss = null
	_boss_panel.visible = false

	if _is_boss_wave():
		await _spawn_boss_wave()
	else:
		await _spawn_regular_wave()

	_spawning = false

func _spawn_regular_wave() -> void:
	regular_wave.emit()
	_banner_label.text = "WAVE %d" % _wave
	_seed_wave_hazards()

	var roster = _build_wave_roster()
	if recovery_wave_interval > 0 and _wave % recovery_wave_interval == 0:
		var trimmed: Array = []
		var keep_count := maxi(2, int(float(roster.size()) * recovery_spawn_multiplier))
		for i in range(mini(keep_count, roster.size())):
			trimmed.append(roster[i])
		roster = trimmed
	var delay: float = spawn_delay
	if _is_late_game_wave():
		delay = maxf(spawn_delay * 0.62, 0.22)
	for i in range(roster.size()):
		if _player == null or not is_instance_valid(_player):
			return

		var enemy = _spawn_enemy(roster[i], "Wave%dEnemy%d" % [_wave, i])
		if enemy != null:
			_active_enemies.append(enemy)

		await get_tree().create_timer(delay).timeout

func _spawn_boss_wave() -> void:
	$BossWaveMusic.play()
	$WaveMusic.stream_paused = true
	$"BossWaveMusic/Volume Intro".play("Volume Intro")
	boss_wave.emit()
	_banner_label.text = "BOSS WAVE %d" % _wave
	_seed_wave_hazards()

	var boss_scene = _choose_boss_scene()
	_last_boss_scene_path = boss_scene.resource_path
	var boss = boss_scene.instantiate()
	boss.name = "%sWave%d" % [_boss_node_prefix(boss_scene), _wave]
	var boss_health := 2100.0 + 520.0 * float(_wave / boss_every_waves)
	if RunProgress and RunProgress.boss_rush_mode:
		boss_health *= float(RunProgress.challenge_modifiers.get("boss_health_multiplier", 1.12))
	boss.set("max_health", boss_health)

	var scale_factor := 1.0 + 0.06 * float(_wave / boss_every_waves)
	if boss.get("projectile_speed") != null:
		boss.set("projectile_speed", float(boss.get("projectile_speed")) * scale_factor)
	if boss.get("contact_damage") != null:
		boss.set("contact_damage", float(boss.get("contact_damage")) * (1.0 + 0.08 * float(_wave / boss_every_waves)))
	if boss.get("move_speed") != null:
		boss.set("move_speed", float(boss.get("move_speed")) * (1.0 + 0.03 * float(_wave / boss_every_waves)))

	_level_root.add_child(boss)
	boss.global_position = _spawn_position_for_index(_wave)
	_refresh_player_planet_cache()

	_boss = boss
	_active_enemies.append(boss)
	_boss_panel.visible = true
	_boss_label.text = _boss_display_name(boss_scene)

	if boss.has_signal("boss_health_changed"):
		boss.connect("boss_health_changed", Callable(self, "_on_boss_health_changed"))
	if boss.has_signal("boss_defeated"):
		boss.connect("boss_defeated", Callable(self, "_on_boss_defeated"))

	await get_tree().create_timer(1.2).timeout

func _build_wave_roster() -> Array:
	if _is_late_game_wave():
		return _build_late_game_roster()

	var roster: Array = []
	var count = int(min(4 + _wave, max_regular_enemies))

	for i in range(count):
		if _wave <= 1:
			roster.append(BASE_ENEMY_SCENE if i % 3 != 0 else ORBITER_DRONE_SCENE)
		elif _wave == 2:
			roster.append([BASE_ENEMY_SCENE, GRAVITY_LEECH_SCENE, ORBITER_DRONE_SCENE][i % 3])
		elif _wave == 3:
			roster.append([BASE_ENEMY_SCENE, BASE_SHOOTER_SCENE, SEEKER_FRAGMENT_SCENE, CHAOS_WISP_SCENE, PARAMETRIC_1_SCENE, PHASE_SLIP_SWARM_SCENE][i % 6])
		elif _wave == 4:
			roster.append([BASE_SHOOTER_SCENE, HARASSER_SCENE, GRAVITY_LEECH_SCENE, SHIELD_BREAKER_SCENE, CHAOS_WISP_SCENE, PARAMETRIC_2_SCENE, PHASE_SLIP_SWARM_SCENE][i % 7])
		else:
			roster.append([BASE_ENEMY_SCENE, BASE_SHOOTER_SCENE, ORBITER_DRONE_SCENE, GRAVITY_LEECH_SCENE, SEEKER_FRAGMENT_SCENE, SHIELD_BREAKER_SCENE, CHAOS_WISP_SCENE, HARASSER_SCENE, SNIPER_SCENE, PARAMETRIC_1_SCENE, PARAMETRIC_2_SCENE, PARAMETRIC_4_SCENE, PARAMETRIC_5_SCENE, PHASE_SLIP_SWARM_SCENE, GRAVIMETRIC_ECHO_DRONE_SCENE][i % 15])

	if _wave >= 3:
		roster.insert(int(min(2, roster.size())), SHIELDER_SCENE)
	if _wave >= 4:
		roster.insert(int(min(4, roster.size())), SHIELD_BREAKER_SCENE)
	if _wave >= 6:
		roster.insert(int(min(5, roster.size())), PARAMETRIC_3_SCENE)
	if _wave >= 7:
		roster.insert(int(min(6, roster.size())), ORBITAL_NULL_HARVESTER_SCENE)
	if _wave >= 8:
		roster.insert(int(min(7, roster.size())), EVENT_HORIZON_WARDEN_ENEMY_SCENE)
	if _wave >= 9:
		roster.insert(int(min(8, roster.size())), RESONANCE_PARALYTIC_CONSTRUCT_SCENE)

	return roster


func _build_late_game_roster() -> Array:
	var elite: Array = [
		CHAOS_WISP_SCENE, SHIELD_BREAKER_SCENE, SNIPER_SCENE, HARASSER_SCENE,
		PARAMETRIC_4_SCENE, PARAMETRIC_5_SCENE, SEEKER_FRAGMENT_SCENE, GRAVITY_LEECH_SCENE,
		PHASE_SLIP_SWARM_SCENE, GRAVIMETRIC_ECHO_DRONE_SCENE, ORBITAL_NULL_HARVESTER_SCENE,
		EVENT_HORIZON_WARDEN_ENEMY_SCENE, RESONANCE_PARALYTIC_CONSTRUCT_SCENE,
	]
	var roster: Array = []
	var count: int = mini(8 + int((_wave - RunProgress.LATE_GAME_START_WAVE) * 0.5), max_regular_enemies + 4)
	for i in range(count):
		roster.append(elite[i % elite.size()])
	return roster

func _spawn_enemy(scene: PackedScene, node_name: String) -> Node:
	if _level_root == null:
		return null

	var enemy = scene.instantiate()
	enemy.name = node_name
	enemy.add_to_group("wave_enemy")
	_tune_enemy_for_wave(enemy)

	_level_root.add_child(enemy)
	var enemy_2d = enemy as Node2D
	if enemy_2d != null:
		enemy_2d.global_position = _spawn_position_for_index(_active_enemies.size())

	return enemy

func _tune_enemy_for_wave(enemy: Node) -> void:
	var difficulty = 1.0 + float(max(_wave - 1, 0)) * 0.07

	if enemy.get("max_health") != null:
		enemy.set("max_health", float(enemy.get("max_health")) * difficulty)
	if enemy.get("max_speed") != null:
		enemy.set("max_speed", float(enemy.get("max_speed")) * minf(1.0 + float(_wave) * 0.025, 1.45))
	if enemy.get("fire_interval") != null:
		var fire_interval := maxf(float(enemy.get("fire_interval")) - float(_wave) * 0.045, 0.7)
		if _wave >= 2 and _wave <= 4:
			fire_interval *= early_wave_fire_rate_bonus
		enemy.set("fire_interval", fire_interval)

	var health = enemy.get_node_or_null("HealthComponent")
	if health != null:
		health.set("max_health", float(health.get("max_health")) * difficulty)

func _spawn_battlefield_features() -> void:
	var origin = _player.global_position
	_spawn_hazard_once(NEBULA_SCENE, "PermanentNebulaNorth", origin + Vector2(-740.0, -520.0))
	_spawn_hazard_once(NEBULA_SCENE, "PermanentNebulaSouth", origin + Vector2(920.0, 680.0))

	var wormhole = _spawn_hazard_once(WORMHOLE_PAIR_SCENE, "PermanentWormholePair", Vector2.ZERO)
	if wormhole != null and wormhole.has_method("set_endpoint_positions"):
		wormhole.set_endpoint_positions(origin + Vector2(-1280.0, 220.0), origin + Vector2(1300.0, -360.0))

func _seed_wave_hazards() -> void:
	if _wave % 2 == 0:
		_spawn_hazard(UNSTABLE_MOON_SCENE, "Wave%dUnstableMoon" % _wave, _spawn_position_for_index(_wave + 3))
	if _wave % 3 == 0:
		_spawn_hazard(NEBULA_SCENE, "Wave%dNebulaCloud" % _wave, _spawn_position_for_index(_wave + 7))

	_refresh_player_planet_cache()

func _spawn_hazard(scene: PackedScene, node_name: String, global_pos: Vector2) -> Node:
	var hazard = scene.instantiate()
	hazard.name = node_name
	_level_root.add_child(hazard)

	var hazard_2d = hazard as Node2D
	if hazard_2d != null:
		hazard_2d.global_position = global_pos

	_active_hazards.append(hazard)
	return hazard

func _spawn_hazard_once(scene: PackedScene, node_name: String, global_pos: Vector2) -> Node:
	if _level_root.has_node(node_name):
		return _level_root.get_node(node_name)

	return _spawn_hazard(scene, node_name, global_pos)

func _spawn_position_for_index(index: int) -> Vector2:
	var angle = TAU * float(index % 11) / 11.0 + _rng.randf_range(-0.22, 0.22)
	var radius = _rng.randf_range(min_spawn_radius, max_spawn_radius)
	return _player.global_position + Vector2(cos(angle), sin(angle)) * radius

func _complete_wave() -> void:
	_wave_running = false
	_banner_label.text = "WAVE %d CLEARED" % _wave
	_boss_panel.visible = false
	wave_cleared.emit(_wave)

	if _waves_halted or not _waves_enabled():
		if RunProgress and RunProgress.boss_rush_mode and RunProgress.run_finished:
			_banner_label.text = "BOSS RUSH CLEARED"
		return

	var extra_rest := 0.0
	if _is_late_game_wave() and _wave % 3 == 0:
		extra_rest = recovery_rest_bonus
	var rest = rest_between_waves + extra_rest
	if RunProgress and RunProgress.boss_rush_mode:
		rest *= float(RunProgress.challenge_modifiers.get("wave_rest_multiplier", 0.6))
	await get_tree().create_timer(rest).timeout
	_begin_next_wave()

func _cleanup_tracking() -> void:
	var kept_enemies: Array[Node] = []
	for enemy in _active_enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			kept_enemies.append(enemy)
	_active_enemies = kept_enemies

	var kept_hazards: Array[Node] = []
	for hazard in _active_hazards:
		if hazard != null and is_instance_valid(hazard) and not hazard.is_queued_for_deletion():
			kept_hazards.append(hazard)
	_active_hazards = kept_hazards

func _is_boss_wave() -> bool:
	if RunProgress and RunProgress.boss_rush_mode:
		return true
	if RunProgress and not RunProgress.challenge_mode:
		return RunProgress.is_boss_milestone_wave(_wave)
	return boss_every_waves > 0 and _wave % boss_every_waves == 0

func _is_late_game_wave() -> bool:
	return RunProgress and _wave >= RunProgress.LATE_GAME_START_WAVE and _wave <= RunProgress.LATE_GAME_END_WAVE

func _waves_enabled() -> bool:
	if RunProgress == null:
		return true
	return RunProgress.waves_enabled()

func _refresh_player_planet_cache() -> void:
	if _player != null and _player.has_method("_refresh_gravity_sources"):
		_player.call("_refresh_gravity_sources", true)
	elif _player != null and _player.get("planets") != null:
		_player.set("planets", get_tree().get_nodes_in_group("planets"))

func _choose_boss_scene() -> PackedScene:
	if RunProgress and RunProgress.boss_rush_mode:
		var index = max(_wave - 1, 0) % RunProgress.BOSS_SCENE_PATHS.size()
		return _boss_scene_from_path(RunProgress.BOSS_SCENE_PATHS[index])
	if RunProgress and not RunProgress.challenge_mode:
		return _boss_scene_from_path(RunProgress.get_scheduled_boss_scene_path(_wave))

	var boss_number = max(0, int(float(_wave) / float(max(1, boss_every_waves))) - 1)
	var boss_index = boss_number % 7
	if boss_index == 1:
		return ACCRETION_CORE_SCENE
	if boss_index == 2:
		return NULL_SERAPH_SCENE
	if boss_index == 3:
		return MAGNETAR_TWINS_SCENE
	if boss_index == 4:
		return RIFT_WEAVER_SCENE
	if boss_index == 5:
		return POLYMORPH_BOSS_SCENE
	if boss_index == 6:
		return CENTRIFUGE_MARSHAL_SCENE
	return GRAVITY_WARDEN_SCENE

func _boss_scene_from_path(path: String) -> PackedScene:
	match path:
		"res://Nodes/accretion_core_boss.tscn":
			return ACCRETION_CORE_SCENE
		"res://Nodes/null_vector_seraph_boss.tscn":
			return NULL_SERAPH_SCENE
		"res://Nodes/magnetar_twins_boss.tscn":
			return MAGNETAR_TWINS_SCENE
		"res://Nodes/rift_weaver_boss.tscn":
			return RIFT_WEAVER_SCENE
		"res://Nodes/ParametricEquationEnemies/polymorph_boss.tscn":
			return POLYMORPH_BOSS_SCENE
		"res://Nodes/centrifuge_marshal_boss.tscn":
			return CENTRIFUGE_MARSHAL_SCENE
		_:
			return GRAVITY_WARDEN_SCENE

func _boss_display_name(scene: PackedScene) -> String:
	if scene == ACCRETION_CORE_SCENE:
		return "THE ACCRETION CORE"
	if scene == NULL_SERAPH_SCENE:
		return "NULL VECTOR SERAPH"
	if scene == MAGNETAR_TWINS_SCENE:
		return "MAGNETAR TWINS"
	if scene == RIFT_WEAVER_SCENE:
		return "TIDAL RIFT WEAVER"
	if scene == POLYMORPH_BOSS_SCENE:
		return "THE POLYMORPH"
	if scene == CENTRIFUGE_MARSHAL_SCENE:
		return "CENTRIFUGE MARSHAL"
	return "GRAVITY WARDEN"

func _boss_node_prefix(scene: PackedScene) -> String:
	if scene == ACCRETION_CORE_SCENE:
		return "AccretionCore"
	if scene == NULL_SERAPH_SCENE:
		return "NullVectorSeraph"
	if scene == MAGNETAR_TWINS_SCENE:
		return "MagnetarTwins"
	if scene == RIFT_WEAVER_SCENE:
		return "RiftWeaver"
	if scene == POLYMORPH_BOSS_SCENE:
		return "Polymorph"
	if scene == CENTRIFUGE_MARSHAL_SCENE:
		return "CentrifugeMarshal"
	return "GravityWarden"

func _on_boss_health_changed(current_health: float, max_health: float) -> void:
	_boss_bar.max_value = maxf(max_health, 1.0)
	_boss_bar.value = clampf(current_health, 0.0, _boss_bar.max_value)

func _on_boss_defeated() -> void:
	if not _last_boss_scene_path.is_empty():
		boss_defeated_anchor.emit(_last_boss_scene_path)
	_clear_remaining_wave_enemies()
	_boss = null
	_complete_wave()
	$WaveMusic.play()
	$BossWaveMusic.stream_paused = true
	$"WaveMusic/Volume Intro".play("Volume Intro")

func _on_secret_boss_defeated() -> void:
	_clear_remaining_wave_enemies()
	_boss = null
	_complete_wave()
	$WaveMusic.play()
	$BossWaveMusic.stream_paused = true
	$"WaveMusic/Volume Intro".play("Volume Intro")

func _update_boss_bar() -> void:
	if _boss != null and _boss.has_method("get_health_ratio"):
		_boss_bar.value = _boss_bar.max_value * float(_boss.call("get_health_ratio"))

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "WaveDirectorCanvas"
	_canvas.layer = 55
	add_child(_canvas)

	var banner_panel = PanelContainer.new()
	banner_panel.name = "WaveBannerPanel"
	banner_panel.anchor_left = 0.5
	banner_panel.anchor_right = 0.5
	banner_panel.offset_left = -245.0
	banner_panel.offset_right = 245.0
	banner_panel.offset_top = 20.0
	banner_panel.offset_bottom = 64.0
	banner_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.015, 0.018, 0.032, 0.72), Color(0.0, 0.88, 1.0, 0.42)))
	_canvas.add_child(banner_panel)

	_banner_label = Label.new()
	_banner_label.name = "WaveBannerLabel"
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.text = "INITIALIZING WAVES"
	banner_panel.add_child(_banner_label)

	_status_label = Label.new()
	_status_label.name = "WaveStatusLabel"
	_status_label.offset_left = 18.0
	_status_label.offset_top = 200.0
	_status_label.offset_right = 278.0
	_status_label.offset_bottom = 226.0
	_status_label.text = "Wave 0 | Threats 0"
	_canvas.add_child(_status_label)

	_boss_panel = PanelContainer.new()
	_boss_panel.name = "BossPanel"
	_boss_panel.anchor_left = 0.5
	_boss_panel.anchor_right = 0.5
	_boss_panel.anchor_top = 1.0
	_boss_panel.anchor_bottom = 1.0
	_boss_panel.offset_left = -330.0
	_boss_panel.offset_right = 330.0
	_boss_panel.offset_top = -92.0
	_boss_panel.offset_bottom = -28.0
	_boss_panel.visible = false
	_boss_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.01, 0.025, 0.76), Color(1.0, 0.18, 0.08, 0.55)))
	_canvas.add_child(_boss_panel)

	var boss_rows = VBoxContainer.new()
	boss_rows.name = "BossRows"
	boss_rows.add_theme_constant_override("separation", 6)
	_boss_panel.add_child(boss_rows)

	_boss_label = Label.new()
	_boss_label.name = "BossNameLabel"
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.text = "BOSS"
	boss_rows.add_child(_boss_label)

	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossHealthBar"
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 100.0
	_boss_bar.value = 100.0
	_boss_bar.custom_minimum_size = Vector2(600.0, 16.0)
	boss_rows.add_child(_boss_bar)

func _make_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _update_status() -> void:
	_status_label.text = "Wave %d | Threats %d" % [_wave, _active_enemies.size()]

func _clear_remaining_wave_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("wave_enemy"):
		if enemy != _boss and enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()

func _on_wave_music_finished() -> void:
	$WaveMusic.play()

func _on_boss_wave_music_finished() -> void:
	$BossWaveMusic.play()
