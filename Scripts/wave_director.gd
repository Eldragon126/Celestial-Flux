extends Node2D

# Coherent arcade loop for Vector Anomaly. The director stages the modular
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
const PLANET_SCENE = preload("res://Nodes/planet_1.tscn")
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
const EXTRADIMENSIONAL_BREACHER_SCENE = preload("res://Nodes/extradimensional_breacher_boss.tscn")
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

const SONG_A_NEW_THREAD_AMBIENCE = preload("res://Assets/Songs/A New Thread Ambience.mp3")
const SONG_A_NEW_THREAD = preload("res://Assets/Songs/A New Thread.mp3")
const SONG_A_CASUAL = preload("res://Assets/Songs/ACasualSong.mp3")
const SONG_A_NEW_PLANET = preload("res://Assets/Songs/A New Planet.mp3")
const SONG_APPROACHING_ABYSS = preload("res://Assets/Songs/Approaching Abyss.mp3")
const SONG_BOOGIE_WORLD = preload("res://Assets/Songs/Boogie World.mp3")
const SONG_CONTINUUM = preload("res://Assets/Songs/Continuum.mp3")
const SONG_COSMIC_BASS = preload("res://Assets/Songs/Cosmic Bass.wav")
const SONG_COSMIC_JOURNEY_BACKGROUND = preload("res://Assets/Songs/Cosmic Journey Background.mp3")
const SONG_COSMIC_JOURNEY_EPIC = preload("res://Assets/Songs/Cosmic Journey Epic.mp3")
const SONG_CRASH_LANDING = preload("res://Assets/Songs/Crash Landing.mp3")
const SONG_DAWN_ON_A_NEW_PLANET = preload("res://Assets/Songs/Dawn on A New Planet.mp3")
const SONG_FRAGMENTS_FORGOTTEN_FUTUR = preload("res://Assets/Songs/Fragments of a Forgotten Futur.mp3")
const SONG_GRAVITY_BLOOM = preload("res://Assets/Songs/Gravity Bloom.mp3")
const SONG_GREEN_FLAME_ULTRA = preload("res://Assets/Songs/Green Flame Ultra.mp3")
const SONG_INTERESTING = preload("res://Assets/Songs/Interesting Song (1).mp3")
const SONG_NEON_STARLIGHT = preload("res://Assets/Songs/Neon Starlight.mp3")
const SONG_ORBITAL_DRIFT = preload("res://Assets/Songs/Orbital Drift.mp3")
const SONG_ORBITAL_FUN = preload("res://Assets/Songs/Orbital Fun.wav")
const SONG_OTHER_WORLDS = preload("res://Assets/Songs/oTHER wORLDS.mp3")
const SONG_QUANTUM_BREAK = preload("res://Assets/Songs/Quantum Break.mp3")
const SONG_RESONANCE = preload("res://Assets/Songs/Resonance.mp3")
const SONG_SOLAR_RAYS = preload("res://Assets/Songs/Solar Rays.mp3")
const SONG_SPINE_CHILLING_CHRISTMAS = preload("res://Assets/Songs/Spine Chilling Christmas.mp3")
const SONG_THE_4TH_DIMENSION = preload("res://Assets/Songs/The 4th Dimension.mp3")
const SONG_THE_ABYSS = preload("res://Assets/Songs/The Abyss.wav")
const SONG_THE_ABYSS_INTRO = preload("res://Assets/Songs/The Abyss Intro.wav")
const SONG_THE_ARRIVAL = preload("res://Assets/Songs/The Arrival.mp3")
const SONG_THE_LONG_DRIFT = preload("res://Assets/Songs/The Long Drift.mp3")
const SONG_THE_NEURAL_DRIFT_THRESHOLD = preload("res://Assets/Songs/The Neural Drift Threshold.mp3")
const SONG_THE_TOMB_OF_GALAXIES = preload("res://Assets/Songs/The Tomb of Galaxies.mp3")
const SONG_THE_TOWN = preload("res://Assets/Songs/The Town.mp3")
const SONG_THE_UNIVERSE_SAYS_HELLO = preload("res://Assets/Songs/The Universe Says Hello.mp3")
const SONG_THROUGH_TIME = preload("res://Assets/Songs/Through Time.mp3")
const SONG_TITLE_SCREEN_AMBIENCE = preload("res://Assets/Songs/Title Screen Ambience.mp3")
const SONG_TWANGY_SPACE = preload("res://Assets/Songs/Twangy Space.mp3")
const SONG_WHISPERS_IN_THE_VOID = preload("res://Assets/Songs/Whispers in the Void.mp3")
const SONG_ERR_INVALID_THREAD_CHANGE = preload("res://Assets/Songs/[Err -42] invalid thread change.mp3")
const SONG_ERR_RUPTURE = preload("res://Assets/Songs/[Err -502] RUPTURE.mp3")

enum MusicMode { NONE, WAVE, BOSS, INTERMISSION }

@export var first_wave_delay = 2.0
@export var rest_between_waves = 4.0
@export var spawn_delay = 0.48
@export var min_spawn_radius = 760.0
@export var max_spawn_radius = 1540.0
@export var boss_every_waves = 5
@export var max_regular_enemies = 10
@export var wave_soft_timeout: float = 145.0
@export var minimum_regular_wave_duration: float = 54.0
@export var pacing_reinforcement_interval: float = 12.0
@export var pacing_reinforcement_count: int = 2
@export var max_pacing_reinforcement_batches: int = 2
@export var external_enemies_block_wave: bool = false
@export var clear_external_enemies_on_wave_clear: bool = true
@export var recovery_wave_interval: int = 4
@export var recovery_spawn_multiplier: float = 0.55
@export var recovery_rest_bonus: float = 2.5
@export var early_wave_fire_rate_bonus: float = 1.38
@export var status_update_interval: float = 0.12
@export var energy_drop_chance: float = 0.88
@export var energy_drop_restore_amount: float = 7.0
@export var energy_drop_base_count: int = 1
@export var energy_drop_elite_bonus_wave: int = 6
@export var energy_drop_spread_radius: float = 48.0

@export_group("Music")
@export var music_enabled: bool = true
@export var wave_music_volume_db: float = -0.5
@export var boss_music_volume_db: float = 0.0
@export var intermission_music_volume_db: float = -4.0

@export_group("Spawn Safety")
@export var far_planet_count: int = 3
@export var far_planet_min_radius: float = 2850.0
@export var far_planet_max_radius: float = 4700.0
@export var far_planet_clearance: float = 420.0
@export var stationary_enemy_planet_clearance: float = 260.0
@export var wormhole_planet_clearance: float = 260.0
@export var spawn_position_attempts: int = 18
@export var enable_permanent_wormhole_pair: bool = false

@export_group("Interwave Galaxy Gates")
@export var enable_interwave_galaxy_gates: bool = true
@export var interwave_gate_start_wave: int = 2
@export var interwave_gate_interval: int = 2
@export var interwave_gate_near_radius: float = 520.0
@export var interwave_gate_far_min_radius: float = 3400.0
@export var interwave_gate_far_max_radius: float = 4600.0
@export var interwave_gate_planet_count: int = 2

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
var _status_elapsed: float = 999.0
var _last_status_wave: int = -1
var _last_status_threats: int = -1
var _physics_drop_system: Node = null
var _wave_elapsed: float = 0.0
var _next_pacing_reinforcement_time: float = 0.0
var _pacing_reinforcement_batches: int = 0
var _external_enemy_ids: Dictionary = {}
var _interwave_gate: Node = null
var _music_mode: int = MusicMode.NONE
var _active_music_stream: AudioStream = null
var _pause_menu: Node = null
var _music_blocked_by_pause: bool = false
var _network_forced_wave_start: bool = false
var _network_forced_wave_clear: bool = false
var _wave_music_by_wave: Dictionary = {}
var _boss_music_by_wave: Dictionary = {}
var _wave_music_tracks: Array[AudioStream] = [
	SONG_THE_ABYSS,
	SONG_ORBITAL_DRIFT,
	SONG_COSMIC_BASS,
	SONG_WHISPERS_IN_THE_VOID,
	SONG_INTERESTING,
	SONG_THE_LONG_DRIFT,
	SONG_GRAVITY_BLOOM,
	SONG_CONTINUUM,
	SONG_APPROACHING_ABYSS,
	SONG_THE_ABYSS_INTRO,
	SONG_COSMIC_JOURNEY_BACKGROUND,
	SONG_ORBITAL_FUN,
	SONG_THE_4TH_DIMENSION,
	SONG_THE_ARRIVAL,
]
var _intermission_music_tracks: Array[AudioStream] = [
	SONG_A_NEW_THREAD_AMBIENCE,
	SONG_DAWN_ON_A_NEW_PLANET,
	SONG_THE_UNIVERSE_SAYS_HELLO,
	SONG_THE_TOWN,
	SONG_TWANGY_SPACE,
	SONG_BOOGIE_WORLD,
	SONG_A_NEW_THREAD,
]

func _configure_music_maps() -> void:
	_wave_music_by_wave = {
		1: SONG_THE_ABYSS_INTRO,
		2: SONG_WHISPERS_IN_THE_VOID,
		3: SONG_COSMIC_BASS,
		4: SONG_THE_ABYSS,
		6: SONG_THE_ABYSS,
		7: SONG_THE_4TH_DIMENSION,
		8: SONG_GRAVITY_BLOOM,
		9: SONG_A_NEW_THREAD_AMBIENCE,
		11: SONG_SOLAR_RAYS,
		12: SONG_CRASH_LANDING,
		13: SONG_COSMIC_BASS,
		14: SONG_DAWN_ON_A_NEW_PLANET,
		16: SONG_THE_ABYSS,
		17: SONG_CONTINUUM,
		18: SONG_COSMIC_BASS,
		19: SONG_BOOGIE_WORLD,
		21: SONG_THE_ABYSS,
		22: SONG_COSMIC_BASS,
		23: SONG_COSMIC_BASS,
		24: SONG_APPROACHING_ABYSS,
		26: SONG_THE_ABYSS,
		27: SONG_WHISPERS_IN_THE_VOID,
		28: SONG_CONTINUUM,
		29: SONG_THE_NEURAL_DRIFT_THRESHOLD,
		31: SONG_THE_ABYSS,
		32: SONG_CONTINUUM,
		33: SONG_THROUGH_TIME,
		34: SONG_A_NEW_PLANET,
		36: SONG_FRAGMENTS_FORGOTTEN_FUTUR,
		37: SONG_THE_TOMB_OF_GALAXIES,
		38: SONG_TITLE_SCREEN_AMBIENCE,
		39: SONG_THE_ABYSS,
	}
	_boss_music_by_wave = {
		5: SONG_A_CASUAL,
		15: SONG_OTHER_WORLDS,
		20: SONG_QUANTUM_BREAK,
		25: SONG_RESONANCE,
		30: SONG_ERR_INVALID_THREAD_CHANGE,
		35: SONG_THE_ARRIVAL,
		40: SONG_COSMIC_JOURNEY_EPIC,
	}

func _ready() -> void:
	if RunProgress != null and int(RunProgress.run_seed) != 0:
		_rng.seed = int(RunProgress.run_seed) ^ 0x5A71E
	else:
		_rng.randomize()
	_level_root = get_tree().current_scene
	_configure_music_maps()
	_build_ui()
	_stop_all_music()
	_connect_network_session()
	call_deferred("_connect_pause_menu")
	call_deferred("_start_director")

func _process(delta: float) -> void:
	_cleanup_tracking()
	if _pause_menu == null or not is_instance_valid(_pause_menu):
		_connect_pause_menu()
	_update_status(delta)

	if not _wave_running or _spawning:
		return

	_wave_elapsed += delta

	if _boss != null:
		if not is_instance_valid(_boss):
			_boss = null
			_complete_wave()
		else:
			_update_boss_bar()
		return

	if wave_soft_timeout > 0.0 and _wave_elapsed >= wave_soft_timeout:
		_clear_remaining_wave_enemies()
		_complete_wave()
		return

	if _primary_enemy_count() <= 0 and (not external_enemies_block_wave or _external_enemy_count() <= 0):
		if _is_network_client() and not _network_forced_wave_clear:
			_banner_label.text = "WAVE %d CLEAR - AWAITING HOST LOCK" % _wave
			return
		if _should_extend_regular_wave_for_music():
			_try_spawn_pacing_reinforcements()
			return
		_complete_wave()

func _primary_enemy_count() -> int:
	var count := 0
	for enemy in _active_enemies:
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if _is_external_wave_enemy(enemy):
			continue
		count += 1
	return count

func _external_enemy_count() -> int:
	var count := 0
	for enemy_id in _external_enemy_ids.keys():
		var id := int(enemy_id)
		if not is_instance_id_valid(id):
			continue
		var enemy_value := instance_from_id(id)
		if enemy_value == null or not is_instance_valid(enemy_value):
			continue
		var enemy := enemy_value as Node
		if enemy != null and not enemy.is_queued_for_deletion():
			count += 1
	return count

func _is_external_wave_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	return bool(enemy.get_meta(&"external_wave_enemy", false))

func _clear_external_wave_enemies() -> void:
	for enemy_id in _external_enemy_ids.keys():
		var id := int(enemy_id)
		if not is_instance_id_valid(id):
			continue
		var enemy_value := instance_from_id(id)
		if enemy_value == null or not is_instance_valid(enemy_value):
			continue
		var enemy := enemy_value as Node
		if enemy != null and not enemy.is_queued_for_deletion():
			enemy.queue_free()
	_external_enemy_ids.clear()

func _start_director() -> void:
	_player = get_tree().get_first_node_in_group("Player") as Node2D
	if _player == null:
		_banner_label.text = "NO PLAYER SIGNAL"
		return

	_spawn_battlefield_features()
	_refresh_player_planet_cache()
	_banner_label.text = "WAVE SYSTEM ONLINE"
	if _is_network_client():
		_banner_label.text = "WAITING FOR HOST WAVE LOCK"
		return
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
	_track_enemy_rewards(boss)

	_boss_panel.visible = true
	_boss_label.text = display_name
	_banner_label.text = "SECRET BOSS: %s" % display_name

	_play_secret_boss_music(display_name)

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
	enemy.set_meta(&"external_wave_enemy", true)
	_external_enemy_ids[enemy.get_instance_id()] = true
	if external_enemies_block_wave and not _active_enemies.has(enemy):
		_active_enemies.append(enemy)
	_track_enemy_rewards(enemy)

func _begin_next_wave() -> void:
	if _is_network_client() and not _network_forced_wave_start:
		_banner_label.text = "WAITING FOR HOST WAVE LOCK"
		return
	if _waves_halted or not _waves_enabled():
		_banner_label.text = "BOSS RUSH CLEARED" if RunProgress and RunProgress.boss_rush_mode and RunProgress.run_finished else "WAVE DIRECTOR STANDBY"
		return
	if _player == null or not is_instance_valid(_player):
		return

	_wave += 1
	_wave_elapsed = 0.0
	_next_pacing_reinforcement_time = pacing_reinforcement_interval
	_pacing_reinforcement_batches = 0
	_clear_interwave_galaxy_gate()
	if RunProgress:
		RunProgress.sync_phase_from_wave(_wave)
	_wave_running = true
	_spawning = true
	_boss = null
	_boss_panel.visible = false

	_broadcast_wave_state(&"begin")
	if _is_boss_wave():
		await _spawn_boss_wave()
	else:
		await _spawn_regular_wave()

	_spawning = false

func _spawn_regular_wave() -> void:
	regular_wave.emit()
	_banner_label.text = "WAVE %d" % _wave
	_play_wave_music_for_wave(_wave)
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
	boss_wave.emit()
	_banner_label.text = "BOSS WAVE %d" % _wave
	_seed_wave_hazards()

	var boss_scene = _choose_boss_scene()
	_play_boss_music_for_wave(_wave, boss_scene)
	_last_boss_scene_path = boss_scene.resource_path
	var boss = boss_scene.instantiate()
	boss.name = "%sWave%d" % [_boss_node_prefix(boss_scene), _wave]
	var boss_health := _boss_health_for_scene(boss_scene)
	boss.set("max_health", boss_health)

	var scale_factor := 1.08 + 0.08 * float(_wave / boss_every_waves)
	if boss.get("projectile_speed") != null:
		boss.set("projectile_speed", float(boss.get("projectile_speed")) * scale_factor)
	if boss.get("contact_damage") != null:
		boss.set("contact_damage", float(boss.get("contact_damage")) * (1.08 + 0.1 * float(_wave / boss_every_waves)))
	if boss.get("move_speed") != null:
		boss.set("move_speed", float(boss.get("move_speed")) * (1.06 + 0.04 * float(_wave / boss_every_waves)))

	_level_root.add_child(boss)
	boss.global_position = _spawn_position_for_index(_wave)
	_apply_boss_pressure_tuning(boss, boss_scene, boss_health)
	_refresh_player_planet_cache()

	_boss = boss
	_active_enemies.append(boss)
	_track_enemy_rewards(boss)
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
		var avoid_planets := _enemy_requires_planet_clearance(enemy, scene)
		enemy_2d.global_position = _spawn_position_for_index(
			_stable_index_from_text(node_name),
			avoid_planets,
			stationary_enemy_planet_clearance
		)
	_track_enemy_rewards(enemy)

	return enemy

func _tune_enemy_for_wave(enemy: Node) -> void:
	var difficulty = 1.0 + float(max(_wave - 1, 0)) * 0.085

	if enemy.get("max_health") != null:
		enemy.set("max_health", float(enemy.get("max_health")) * difficulty)
	if enemy.get("max_speed") != null:
		enemy.set("max_speed", float(enemy.get("max_speed")) * minf(1.0 + float(_wave) * 0.025, 1.45))
	if enemy.get("fire_interval") != null:
		var fire_interval := maxf(float(enemy.get("fire_interval")) - float(_wave) * 0.045, 0.62)
		if _wave >= 2 and _wave <= 4:
			fire_interval *= early_wave_fire_rate_bonus
		enemy.set("fire_interval", fire_interval)
	if enemy.get("contact_damage") != null:
		enemy.set("contact_damage", float(enemy.get("contact_damage")) * minf(1.0 + float(_wave) * 0.04, 1.6))

	var health = enemy.get_node_or_null("HealthComponent")
	if health != null:
		health.set("max_health", float(health.get("max_health")) * difficulty)

func _track_enemy_rewards(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var health: Node = enemy.get_node_or_null("HealthComponent")
	if health == null or not is_instance_valid(health):
		return
	if not health.has_signal(&"died"):
		return
	var callback: Callable = Callable(self, "_on_wave_enemy_died").bind(enemy)
	if health.is_connected(&"died", callback):
		return
	health.connect(&"died", callback, CONNECT_ONE_SHOT)

func _on_wave_enemy_died(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_2d: Node2D = enemy as Node2D
	if enemy_2d == null:
		return
	var parent: Node = enemy.get_parent()
	if parent == null:
		parent = _level_root
	if parent == null:
		return
	var drop_count: int = _energy_drop_count_for_enemy(enemy)
	PowerupLibrary.try_spawn_energy_droplets(
		parent,
		enemy_2d.global_position,
		drop_count,
		energy_drop_chance,
		energy_drop_spread_radius,
		energy_drop_restore_amount
	)
	var drop_system := _get_physics_drop_system()
	if drop_system != null and drop_system.has_method("try_spawn_for_enemy"):
		drop_system.call("try_spawn_for_enemy", enemy, enemy_2d.global_position, _is_boss_enemy(enemy))

func _energy_drop_count_for_enemy(enemy: Node) -> int:
	var count: int = maxi(energy_drop_base_count, 0)
	if _wave >= energy_drop_elite_bonus_wave:
		count += 1
	if _is_boss_enemy(enemy):
		count += 4
	return mini(count, 8)


func _is_boss_enemy(enemy: Node) -> bool:
	return enemy != null and (enemy.is_in_group("bosses") or enemy.is_in_group("boss") or enemy.has_signal("boss_defeated"))


func _get_physics_drop_system() -> Node:
	if _physics_drop_system != null and is_instance_valid(_physics_drop_system):
		return _physics_drop_system
	if _level_root != null:
		_physics_drop_system = _level_root.find_child("PhysicsDropSystem", true, false)
	return _physics_drop_system

func _spawn_battlefield_features() -> void:
	var origin := _spawn_center()
	_spawn_far_planet_field(origin)
	_spawn_hazard_once(NEBULA_SCENE, "PermanentNebulaNorth", origin + Vector2(-740.0, -520.0))
	_spawn_hazard_once(NEBULA_SCENE, "PermanentNebulaSouth", origin + Vector2(920.0, 680.0))

	if enable_permanent_wormhole_pair:
		var wormhole = _spawn_hazard_once(WORMHOLE_PAIR_SCENE, "PermanentWormholePair", Vector2.ZERO)
		if wormhole != null and wormhole.has_method("set_endpoint_positions"):
			var entry_position := _safe_orbital_position(origin, 1240.0, 1460.0, 17, wormhole_planet_clearance)
			var exit_position := _safe_orbital_position(origin, 1300.0, 1560.0, 29, wormhole_planet_clearance)
			wormhole.set_endpoint_positions(entry_position, exit_position)

func _spawn_interwave_galaxy_gate(_rest_duration: float) -> void:
	_clear_interwave_galaxy_gate()
	if not enable_interwave_galaxy_gates:
		return
	if _level_root == null or _player == null or not is_instance_valid(_player):
		return
	if _wave < interwave_gate_start_wave:
		return
	if interwave_gate_interval > 0 and _wave % interwave_gate_interval != 0:
		return

	var origin := _spawn_center()
	var entry_position := _safe_orbital_position(
		origin,
		interwave_gate_near_radius * 0.82,
		interwave_gate_near_radius * 1.18,
		_wave * 19 + 5,
		wormhole_planet_clearance
	)
	var exit_position := _safe_orbital_position(
		origin,
		interwave_gate_far_min_radius,
		interwave_gate_far_max_radius,
		_wave * 31 + 11,
		wormhole_planet_clearance + 180.0
	)

	var gate := WORMHOLE_PAIR_SCENE.instantiate()
	gate.name = "InterwaveGalaxyGate%d" % _wave
	gate.set_meta(&"interwave_only", true)
	_level_root.add_child(gate)
	if gate.has_method("set_endpoint_positions"):
		gate.call("set_endpoint_positions", entry_position, exit_position)
	_interwave_gate = gate
	_active_hazards.append(gate)
	_seed_galaxy_arrival_field(exit_position)
	_refresh_player_planet_cache()
	_banner_label.text = "WAVE %d CLEARED - GALAXY GATE OPEN" % _wave


func _clear_interwave_galaxy_gate() -> void:
	if _interwave_gate == null:
		return
	if is_instance_valid(_interwave_gate) and not _interwave_gate.is_queued_for_deletion():
		_interwave_gate.queue_free()
	_interwave_gate = null


func _seed_galaxy_arrival_field(center: Vector2) -> void:
	_spawn_hazard_once(
		NEBULA_SCENE,
		"Galaxy%dArrivalNebula" % _wave,
		center + Vector2(420.0, -360.0).rotated(float(_wave) * 0.37)
	)
	for i in range(maxi(interwave_gate_planet_count, 0)):
		var position := _safe_orbital_position(
			center,
			620.0 + float(i) * 260.0,
			980.0 + float(i) * 360.0,
			_wave * 43 + i * 13,
			far_planet_clearance
		)
		_spawn_hazard_once(PLANET_SCENE, "Galaxy%dPlanet%d" % [_wave, i], position)

func _seed_wave_hazards() -> void:
	if _wave % 2 == 0:
		_spawn_hazard(UNSTABLE_MOON_SCENE, "Wave%dUnstableMoon" % _wave, _spawn_position_for_index(_wave + 3))
	if _wave % 3 == 0:
		_spawn_hazard(NEBULA_SCENE, "Wave%dNebulaCloud" % _wave, _spawn_position_for_index(_wave + 7))
	if _wave == 19:
		_spawn_hazard(NEBULA_SCENE, "Wave19BoogieNebula", _spawn_position_for_index(_wave + 11))
		_spawn_hazard(UNSTABLE_MOON_SCENE, "Wave19BoogieMoon", _spawn_position_for_index(_wave + 13))

	_refresh_player_planet_cache()

func _spawn_hazard(scene: PackedScene, node_name: String, global_pos: Vector2) -> Node:
	var hazard = scene.instantiate()
	hazard.name = node_name
	var hazard_2d = hazard as Node2D
	if hazard_2d != null:
		hazard_2d.global_position = global_pos
	if hazard.has_method("configure_deterministic"):
		hazard.call("configure_deterministic", _seed_for_key(node_name), StringName(node_name))

	_level_root.add_child(hazard)

	_active_hazards.append(hazard)
	return hazard

func _spawn_hazard_once(scene: PackedScene, node_name: String, global_pos: Vector2) -> Node:
	if _level_root.has_node(node_name):
		return _level_root.get_node(node_name)

	return _spawn_hazard(scene, node_name, global_pos)

func _spawn_position_for_index(index: int, avoid_planets: bool = false, clearance: float = 0.0) -> Vector2:
	var center := _spawn_center()
	var fallback := center
	for attempt in range(maxi(spawn_position_attempts, 1)):
		var key := "spawn:%d:%d:%d" % [_wave, index, attempt]
		var angle := TAU * float((index + attempt * 3) % 17) / 17.0 + _seeded_range(key + ":angle", -0.24, 0.24)
		var radius := _seeded_range(key + ":radius", min_spawn_radius, max_spawn_radius)
		var candidate := center + Vector2(cos(angle), sin(angle)) * radius
		if attempt == 0:
			fallback = candidate
		if not avoid_planets or _is_position_clear_of_planets(candidate, clearance):
			return candidate
	return _push_position_out_of_planets(fallback, clearance)


func _spawn_far_planet_field(origin: Vector2) -> void:
	for i in range(maxi(far_planet_count, 0)):
		var planet := _spawn_hazard_once(
			PLANET_SCENE,
			"FarOrbitPlanet%d" % i,
			_safe_orbital_position(origin, far_planet_min_radius, far_planet_max_radius, 41 + i * 13, far_planet_clearance)
		)
		if planet == null:
			continue


func _safe_orbital_position(center: Vector2, min_radius: float, max_radius: float, index: int, clearance: float) -> Vector2:
	var fallback := center + Vector2.RIGHT.rotated(TAU * float(index % 19) / 19.0) * min_radius
	for attempt in range(maxi(spawn_position_attempts, 1)):
		var key := "orbit:%d:%d:%d" % [_wave, index, attempt]
		var angle := TAU * float((index + attempt * 5) % 23) / 23.0 + _seeded_range(key + ":angle", -0.18, 0.18)
		var radius := _seeded_range(key + ":radius", min_radius, max_radius)
		var candidate := center + Vector2.RIGHT.rotated(angle) * radius
		if attempt == 0:
			fallback = candidate
		if _is_position_clear_of_planets(candidate, clearance):
			return candidate
	return _push_position_out_of_planets(fallback, clearance)


func _spawn_center() -> Vector2:
	if _is_network_active():
		var host_player := _player_for_peer(1)
		if host_player != null:
			return host_player.global_position
	return _player.global_position if _player != null and is_instance_valid(_player) else Vector2.ZERO


func _player_for_peer(peer_id: int) -> Node2D:
	for node in get_tree().get_nodes_in_group("Player"):
		var player_node := node as Node2D
		if player_node == null or not is_instance_valid(player_node):
			continue
		var peer_value: Variant = player_node.get("network_peer_id")
		if typeof(peer_value) == TYPE_INT and int(peer_value) == peer_id:
			return player_node
	return null


func _stable_index_from_text(text: String) -> int:
	return absi(int(hash("%d:%s" % [_wave, text]))) % 100000


func _seed_for_key(key: String) -> int:
	var base_seed := int(RunProgress.run_seed if RunProgress != null else 0)
	return maxi(absi(int(hash("%d:%s" % [base_seed, key]))), 1)


func _seeded_unit(key: String) -> float:
	return float(_seed_for_key(key) % 1000000) / 1000000.0


func _seeded_range(key: String, min_value: float, max_value: float) -> float:
	return lerpf(min_value, max_value, _seeded_unit(key))


func _enemy_requires_planet_clearance(enemy: Node, scene: PackedScene) -> bool:
	if enemy is StaticBody2D:
		return true
	if scene == SNIPER_SCENE:
		return true
	if enemy.get("stationary") != null and bool(enemy.get("stationary")):
		return true
	return false


func _is_position_clear_of_planets(position: Vector2, clearance: float) -> bool:
	for node in get_tree().get_nodes_in_group("planets"):
		var planet := node as Node2D
		if planet == null or not is_instance_valid(planet) or planet.is_queued_for_deletion():
			continue
		var radius := _node_radius(planet) + clearance
		if position.distance_squared_to(planet.global_position) < radius * radius:
			return false
	return true


func _push_position_out_of_planets(position: Vector2, clearance: float) -> Vector2:
	var adjusted := position
	for _attempt in range(4):
		var moved := false
		for node in get_tree().get_nodes_in_group("planets"):
			var planet := node as Node2D
			if planet == null or not is_instance_valid(planet) or planet.is_queued_for_deletion():
				continue
			var offset := adjusted - planet.global_position
			var distance := offset.length()
			var radius := _node_radius(planet) + clearance
			if distance >= radius:
				continue
			if distance <= 0.001:
				offset = Vector2.RIGHT.rotated(_seeded_range("push:%d:%d" % [_wave, _attempt], 0.0, TAU))
			adjusted = planet.global_position + offset.normalized() * radius
			moved = true
		if not moved:
			return adjusted
	return adjusted


func _node_radius(node: Node2D) -> float:
	var radius_value: Variant = node.get("radius")
	if radius_value is float or radius_value is int:
		return float(radius_value) * maxf(node.scale.x, node.scale.y)
	var collision := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return (collision.shape as CircleShape2D).radius * maxf(node.scale.x, node.scale.y)
	return 96.0 * maxf(node.scale.x, node.scale.y)


func _should_extend_regular_wave_for_music() -> bool:
	if _is_boss_wave():
		return false
	if minimum_regular_wave_duration <= 0.0:
		return false
	if _wave_elapsed >= minimum_regular_wave_duration:
		return false
	return _pacing_reinforcement_batches < max_pacing_reinforcement_batches


func _try_spawn_pacing_reinforcements() -> void:
	if _spawning or _level_root == null:
		return
	if _wave_elapsed < _next_pacing_reinforcement_time:
		return
	_next_pacing_reinforcement_time = _wave_elapsed + maxf(pacing_reinforcement_interval, 4.0)
	_pacing_reinforcement_batches += 1
	var roster := _build_wave_roster()
	if roster.is_empty():
		return
	var count := maxi(pacing_reinforcement_count, 1)
	for i in range(count):
		var scene_value: Variant = roster[(_pacing_reinforcement_batches + i) % roster.size()]
		var scene := scene_value as PackedScene
		if scene == null:
			continue
		var enemy := _spawn_enemy(scene, "Wave%dPacingReinforcement%d_%d" % [_wave, _pacing_reinforcement_batches, i])
		if enemy != null:
			_active_enemies.append(enemy)
	_banner_label.text = "WAVE %d VECTOR PRESSURE HOLD" % _wave


func _complete_wave(network_forced: bool = false) -> void:
	if _is_network_client() and not network_forced:
		_wave_running = false
		_spawning = false
		_banner_label.text = "WAVE %d CLEAR - AWAITING HOST LOCK" % _wave
		return
	_wave_running = false
	_wave_elapsed = 0.0
	if clear_external_enemies_on_wave_clear:
		_clear_external_wave_enemies()
	_banner_label.text = "WAVE %d CLEARED" % _wave
	_boss_panel.visible = false
	wave_cleared.emit(_wave)
	_play_intermission_music_for_wave(_wave)
	_broadcast_wave_state(&"cleared")

	if _is_network_client():
		return

	if _waves_halted or not _waves_enabled():
		if RunProgress and RunProgress.boss_rush_mode and RunProgress.run_finished:
			_banner_label.text = "BOSS RUSH CLEARED"
		_stop_all_music()
		return

	var extra_rest := 0.0
	if _is_late_game_wave() and _wave % 3 == 0:
		extra_rest = recovery_rest_bonus
	var rest = rest_between_waves + extra_rest
	if RunProgress and RunProgress.boss_rush_mode:
		rest *= float(RunProgress.challenge_modifiers.get("wave_rest_multiplier", 0.6))
	_spawn_interwave_galaxy_gate(rest)
	await get_tree().create_timer(rest).timeout
	_clear_interwave_galaxy_gate()
	_begin_next_wave()

func _cleanup_tracking() -> void:
	for index in range(_active_enemies.size() - 1, -1, -1):
		var enemy := _active_enemies[index]
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			_active_enemies.remove_at(index)

	for hazard_index in range(_active_hazards.size() - 1, -1, -1):
		var hazard := _active_hazards[hazard_index]
		if hazard == null or not is_instance_valid(hazard) or hazard.is_queued_for_deletion():
			_active_hazards.remove_at(hazard_index)

	var stale_external_ids: Array = []
	for enemy_id in _external_enemy_ids.keys():
		var id := int(enemy_id)
		if not is_instance_id_valid(id):
			stale_external_ids.append(enemy_id)
			continue
		var enemy_value := instance_from_id(id)
		if enemy_value == null or not is_instance_valid(enemy_value):
			stale_external_ids.append(enemy_id)
			continue
		var enemy := enemy_value as Node
		if enemy == null or enemy.is_queued_for_deletion():
			stale_external_ids.append(enemy_id)
	for enemy_id in stale_external_ids:
		_external_enemy_ids.erase(enemy_id)

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
	var boss_index = boss_number % 8
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
	if boss_index == 7:
		return EXTRADIMENSIONAL_BREACHER_SCENE
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
		"res://Nodes/extradimensional_breacher_boss.tscn":
			return EXTRADIMENSIONAL_BREACHER_SCENE
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
	if scene == EXTRADIMENSIONAL_BREACHER_SCENE:
		return "THE EXTRADIMENSIONAL BREACHER"
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
	if scene == EXTRADIMENSIONAL_BREACHER_SCENE:
		return "ExtradimensionalBreacher"
	return "GravityWarden"

func _boss_pressure_index(scene: PackedScene) -> int:
	if scene == ACCRETION_CORE_SCENE:
		return 1
	if scene == NULL_SERAPH_SCENE:
		return 2
	if scene == MAGNETAR_TWINS_SCENE:
		return 3
	if scene == RIFT_WEAVER_SCENE:
		return 4
	if scene == POLYMORPH_BOSS_SCENE:
		return 5
	if scene == CENTRIFUGE_MARSHAL_SCENE:
		return 6
	if scene == EXTRADIMENSIONAL_BREACHER_SCENE:
		return 7
	return 0

func _boss_health_for_scene(scene: PackedScene) -> float:
	var boss_index := _boss_pressure_index(scene)
	var base_health := 2900.0 + float(boss_index) * 360.0
	if scene == POLYMORPH_BOSS_SCENE:
		base_health = 4700.0
	elif scene == CENTRIFUGE_MARSHAL_SCENE:
		base_health = 5100.0
	elif scene == EXTRADIMENSIONAL_BREACHER_SCENE:
		base_health = 6800.0
	var wave_pressure := 1.0 + 0.055 * float(maxi(_wave - boss_every_waves, 0))
	var health := base_health * wave_pressure
	if RunProgress and RunProgress.boss_rush_mode:
		health *= float(RunProgress.challenge_modifiers.get("boss_health_multiplier", 1.18))
	return health

func _apply_boss_pressure_tuning(boss: Node, scene: PackedScene, boss_health: float) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var pressure := 1.08 + 0.08 * float(_boss_pressure_index(scene)) + 0.018 * float(_wave)
	if RunProgress and RunProgress.boss_rush_mode:
		pressure *= 1.08

	if boss.get("pressure_scale") != null:
		boss.set("pressure_scale", pressure)
	_scale_node_float(boss, &"projectile_speed", 1.0 + pressure * 0.08)
	_scale_node_float(boss, &"bullet_speed", 1.0 + pressure * 0.08)
	_scale_node_float(boss, &"move_speed", 1.0 + pressure * 0.035)
	_scale_node_float(boss, &"max_speed", 1.0 + pressure * 0.03)
	_scale_node_float(boss, &"engine_force", 1.0 + pressure * 0.08)
	_scale_node_float(boss, &"gravity_strength", 1.0 + pressure * 0.1)
	_scale_node_float(boss, &"lane_force", 1.0 + pressure * 0.08)
	_scale_node_float(boss, &"contact_damage", 1.0 + pressure * 0.06)
	_scale_node_float(boss, &"summon_interval", 0.82)
	_scale_node_float(boss, &"fire_interval", 0.74)
	_scale_node_float(boss, &"attack_interval", 0.72)

	var health_component := boss.get_node_or_null("HealthComponent") as HealthComponent
	if health_component != null:
		health_component.max_health = maxf(health_component.max_health, boss_health)
		health_component.current_health = health_component.max_health
		if health_component.has_signal("health_changed"):
			health_component.health_changed.emit(health_component.current_health, health_component.max_health)

	_scale_timer_wait(_timer_from_property(boss, &"attack_timer"), 0.72)
	_scale_timer_wait(_timer_from_property(boss, &"fire_timer"), 0.74)
	_scale_timer_wait(_timer_from_property(boss, &"summon_timer"), 0.82)
	_scale_timer_wait(boss.get_node_or_null("AttackPatternTimer") as Timer, 0.72)
	_scale_timer_wait(boss.get_node_or_null("BossFireTimer") as Timer, 0.74)
	_scale_timer_wait(boss.get_node_or_null("BossSummonTimer") as Timer, 0.82)

func _scale_node_float(node: Node, property_name: StringName, multiplier: float) -> void:
	var value: Variant = node.get(property_name)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return
	node.set(property_name, float(value) * multiplier)

func _timer_from_property(node: Node, property_name: StringName) -> Timer:
	var value: Variant = node.get(property_name)
	if value == null or not is_instance_valid(value):
		return null
	var timer := value as Timer
	if timer == null or timer.is_queued_for_deletion():
		return null
	return timer

func _scale_timer_wait(timer: Timer, multiplier: float) -> void:
	if timer == null or not is_instance_valid(timer) or timer.is_queued_for_deletion():
		return
	timer.wait_time = maxf(timer.wait_time * multiplier, 0.28)

func _on_boss_health_changed(current_health: float, max_health: float) -> void:
	_boss_bar.max_value = maxf(max_health, 1.0)
	_boss_bar.value = clampf(current_health, 0.0, _boss_bar.max_value)

func _on_boss_defeated() -> void:
	if not _last_boss_scene_path.is_empty():
		boss_defeated_anchor.emit(_last_boss_scene_path)
	_clear_remaining_wave_enemies()
	_boss = null
	_complete_wave()

func _on_secret_boss_defeated() -> void:
	_clear_remaining_wave_enemies()
	_boss = null
	_complete_wave()

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
	_banner_label.add_theme_font_size_override("font_size", 16)
	_banner_label.modulate = Color(0.74, 1.0, 0.96, 1.0)
	banner_panel.add_child(_banner_label)

	_status_label = Label.new()
	_status_label.name = "WaveStatusLabel"
	_status_label.anchor_left = 0.5
	_status_label.anchor_right = 0.5
	_status_label.offset_left = -150.0
	_status_label.offset_top = 68.0
	_status_label.offset_right = 150.0
	_status_label.offset_bottom = 92.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = "Wave 0 | Threats 0"
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.modulate = Color(0.56, 0.86, 0.9, 0.92)
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
	_boss_label.add_theme_font_size_override("font_size", 14)
	_boss_label.modulate = Color(1.0, 0.76, 0.56, 1.0)
	boss_rows.add_child(_boss_label)

	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossHealthBar"
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 100.0
	_boss_bar.value = 100.0
	_boss_bar.custom_minimum_size = Vector2(600.0, 16.0)
	_style_wave_progress_bar(_boss_bar, Color(1.0, 0.18, 0.08, 0.94))
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

func _style_wave_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.012, 0.018, 0.88)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

func _update_status(delta: float) -> void:
	if _status_label == null:
		return
	_status_elapsed += delta
	var threat_count := _primary_enemy_count()
	if external_enemies_block_wave:
		threat_count += _external_enemy_count()
	if (
		_status_elapsed < maxf(status_update_interval, 0.05)
		and _last_status_wave == _wave
		and _last_status_threats == threat_count
	):
		return
	_status_elapsed = 0.0
	_last_status_wave = _wave
	_last_status_threats = threat_count
	_status_label.text = "Wave %d | Threats %d" % [_wave, threat_count]

func _clear_remaining_wave_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("wave_enemy"):
		if enemy != _boss and enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	_external_enemy_ids.clear()


func _connect_network_session() -> void:
	if NetworkSession == null or not NetworkSession.has_signal("network_wave_state_received"):
		return
	var callable := Callable(self, "_on_network_wave_state_received")
	if not NetworkSession.is_connected("network_wave_state_received", callable):
		NetworkSession.connect("network_wave_state_received", callable)
	if _is_network_client() and NetworkSession.has_method("get_last_wave_state"):
		var state_value: Variant = NetworkSession.call("get_last_wave_state")
		if typeof(state_value) == TYPE_DICTIONARY:
			var state: Dictionary = state_value
			if not state.is_empty():
				call_deferred("_on_network_wave_state_received", state)


func _broadcast_wave_state(event: StringName) -> void:
	if not _is_network_host():
		return
	if NetworkSession == null or not NetworkSession.has_method("broadcast_wave_state"):
		return
	NetworkSession.call("broadcast_wave_state", {
		"event": String(event),
		"wave": _wave,
		"seed": int(RunProgress.run_seed if RunProgress != null else 0),
		"boss_wave": _is_boss_wave(),
		"wave_running": _wave_running,
		"phase": int(RunProgress.phase if RunProgress != null else 0),
	})


func _on_network_wave_state_received(state: Dictionary) -> void:
	if not _is_network_client():
		return
	var seed := int(state.get("seed", 0))
	if RunProgress != null and seed != 0:
		RunProgress.run_seed = seed
	var state_wave := int(state.get("wave", _wave))
	var event := StringName(state.get("event", &""))
	if event == &"begin":
		if _wave_running and state_wave == _wave:
			return
		_clear_remaining_wave_enemies()
		_wave = maxi(state_wave - 1, 0)
		_network_forced_wave_start = true
		_begin_next_wave()
		_network_forced_wave_start = false
	elif event == &"cleared":
		if state_wave < _wave:
			return
		_wave = state_wave
		_network_forced_wave_clear = true
		_complete_wave(true)
		_network_forced_wave_clear = false


func _is_network_active() -> bool:
	return NetworkSession != null and NetworkSession.has_method("is_network_active") and bool(NetworkSession.call("is_network_active"))


func _is_network_host() -> bool:
	return _is_network_active() and multiplayer.is_server()


func _is_network_client() -> bool:
	return _is_network_active() and not multiplayer.is_server()


func _connect_pause_menu() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		return
	_pause_menu = get_tree().get_first_node_in_group("PauseMenu")
	if _pause_menu == null:
		var root := get_tree().current_scene
		if root != null:
			_pause_menu = root.find_child("PauseMenu", true, false)
	if _pause_menu == null or not _pause_menu.has_signal("pause_state_changed"):
		return
	var callable := Callable(self, "_on_pause_state_changed")
	if not _pause_menu.is_connected("pause_state_changed", callable):
		_pause_menu.connect("pause_state_changed", callable)

func _on_pause_state_changed(blocked: bool) -> void:
	_music_blocked_by_pause = blocked
	if blocked:
		$WaveMusic.stream_paused = true
		$BossWaveMusic.stream_paused = true
		return
	_resume_current_music_mode()

func _play_wave_music_for_wave(wave: int) -> void:
	var stream := _music_for_regular_wave(wave)
	if stream == null:
		return
	_set_music_mode(MusicMode.WAVE, stream, wave_music_volume_db)

func _play_intermission_music_for_wave(_wave_number: int) -> void:
	_stop_all_music()

func _play_boss_music_for_wave(wave: int, scene: PackedScene) -> void:
	var stream: AudioStream = _boss_music_by_wave.get(wave, null)
	if stream == null:
		stream = _boss_music_for_scene(scene)
	_set_music_mode(MusicMode.BOSS, stream, boss_music_volume_db)

func _play_secret_boss_music(display_name: String) -> void:
	var hash = abs(display_name.hash())
	var stream := SONG_GREEN_FLAME_ULTRA if hash % 2 == 0 else SONG_SPINE_CHILLING_CHRISTMAS
	_set_music_mode(MusicMode.BOSS, stream, boss_music_volume_db)

func _music_for_regular_wave(wave: int) -> AudioStream:
	var mapped: AudioStream = _wave_music_by_wave.get(wave, null)
	if mapped != null:
		return mapped
	if _wave_music_tracks.is_empty():
		return null
	var index := wrapi(maxi(wave - 1, 0), 0, _wave_music_tracks.size())
	return _wave_music_tracks[index]

func _boss_music_for_scene(scene: PackedScene) -> AudioStream:
	if scene == ACCRETION_CORE_SCENE:
		return SONG_COSMIC_JOURNEY_EPIC
	if scene == NULL_SERAPH_SCENE:
		return SONG_ERR_INVALID_THREAD_CHANGE
	if scene == MAGNETAR_TWINS_SCENE:
		return SONG_GREEN_FLAME_ULTRA
	if scene == RIFT_WEAVER_SCENE:
		return SONG_QUANTUM_BREAK
	if scene == POLYMORPH_BOSS_SCENE:
		return SONG_ERR_RUPTURE
	if scene == CENTRIFUGE_MARSHAL_SCENE:
		return SONG_NEON_STARLIGHT
	if scene == EXTRADIMENSIONAL_BREACHER_SCENE:
		return SONG_THE_NEURAL_DRIFT_THRESHOLD
	return SONG_RESONANCE

func _set_music_mode(mode: int, stream: AudioStream, volume_db: float) -> void:
	if not music_enabled or stream == null:
		_stop_all_music()
		return
	_music_mode = mode
	_active_music_stream = stream
	var active_player := _music_player_for_mode(mode)
	var inactive_player := $WaveMusic if active_player == $BossWaveMusic else $BossWaveMusic
	inactive_player.stop()
	inactive_player.stream_paused = false
	if active_player.stream != stream:
		active_player.stop()
		active_player.stream = stream
	active_player.volume_db = volume_db
	if _music_blocked_by_pause:
		active_player.stream_paused = true
		return
	active_player.stream_paused = false
	active_player.play()
	_play_music_intro_for_player(active_player)

func _resume_current_music_mode() -> void:
	if not music_enabled or _active_music_stream == null or _music_mode == MusicMode.NONE:
		_stop_all_music()
		return
	var active_player := _music_player_for_mode(_music_mode)
	var inactive_player := $WaveMusic if active_player == $BossWaveMusic else $BossWaveMusic
	inactive_player.stop()
	inactive_player.stream_paused = false
	if active_player.stream != _active_music_stream:
		active_player.stream = _active_music_stream
	if active_player.playing:
		active_player.stream_paused = false
	else:
		active_player.stream_paused = false
		active_player.play()
		_play_music_intro_for_player(active_player)

func _music_player_for_mode(mode: int) -> AudioStreamPlayer:
	return $BossWaveMusic if mode == MusicMode.BOSS else $WaveMusic

func _play_music_intro_for_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	var intro := player.get_node_or_null("Volume Intro") as AnimationPlayer
	if intro != null and intro.has_animation("Volume Intro"):
		intro.stop()
		intro.play("Volume Intro")

func _stop_all_music() -> void:
	_music_mode = MusicMode.NONE
	_active_music_stream = null
	$WaveMusic.stop()
	$WaveMusic.stream_paused = false
	$BossWaveMusic.stop()
	$BossWaveMusic.stream_paused = false

func _on_wave_music_finished() -> void:
	if _music_blocked_by_pause:
		return
	if _music_mode == MusicMode.WAVE or _music_mode == MusicMode.INTERMISSION:
		$WaveMusic.play()

func _on_boss_wave_music_finished() -> void:
	if _music_blocked_by_pause:
		return
	if _music_mode == MusicMode.BOSS:
		$BossWaveMusic.play()
