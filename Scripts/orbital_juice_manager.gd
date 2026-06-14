extends Node2D

# Modular installer for contributor ideas.
# This node keeps the original player/enemy scripts intact and adds optional
# systems as child nodes or showcase scenes once the main level is ready.

const HUD_SCENE = preload("res://Nodes/orbital_hud.tscn")
const GAMEPLAY_TEACHING_SCENE = preload("res://Nodes/gameplay_teaching_director.tscn")
const MECHANIC_AUDIO_SCENE = preload("res://Nodes/mechanic_audio_director.tscn")
const ENEMY_READABILITY_SCENE = preload("res://Nodes/enemy_readability_director.tscn")
const PERFORMANCE_BUDGET_SCENE = preload("res://Nodes/performance_budget_director.tscn")
const PARTICLE_FOCUS_CULLER_SCENE = preload("res://Nodes/particle_focus_culler.tscn")
const THRUSTER_TRAILS_SCENE = preload("res://Nodes/player_thruster_trails.tscn")
const ENGINE_HUM_SCENE = preload("res://Nodes/player_engine_hum.tscn")
const CAMERA_SHAKE_SCENE = preload("res://Nodes/player_damage_camera_shake.tscn")
const SPARK_WATCHER_SCENE = preload("res://Nodes/projectile_spark_watcher.tscn")
const DEBUG_BALANCE_OVERLAY_SCENE = preload("res://Nodes/debug_balance_overlay.tscn")
const GRAVITY_HEAT_MAP_OVERLAY_SCENE = preload("res://Nodes/gravity_heat_map_overlay.tscn")
const MOMENTUM_COMBAT_SCENE = preload("res://Nodes/momentum_combat_component.tscn")
const GRAVITY_RESONANCE_SCENE = preload("res://Nodes/gravity_resonance_manager.tscn")
const ORBITAL_VFX_DIRECTOR_SCENE = preload("res://Nodes/orbital_vfx_director.tscn")
const JUICE_COORDINATOR_SCENE = preload("res://Nodes/juice_coordinator.tscn")
const TIME_DILATION_SCENE = preload("res://Nodes/time_dilation_manager.tscn")
const VISUAL_ESCALATION_SCENE = preload("res://Nodes/visual_escalation_director.tscn")
const ARENA_DESTABILIZATION_SCENE = preload("res://Nodes/arena_destabilization_manager.tscn")
const ARENA_INSTABILITY_DIRECTOR_SCENE = preload("res://Nodes/arena_instability_director.tscn")
const GRAVITY_SCAR_MANAGER_SCENE = preload("res://Nodes/gravity_scar_manager.tscn")
const EVENT_HORIZON_DIRECTOR_SCENE = preload("res://Nodes/event_horizon_director.tscn")
const PHYSICS_AWARE_ENEMY_DIRECTOR_SCENE = preload("res://Nodes/physics_aware_enemy_director.tscn")
const STRESS_TEST_DIRECTOR_SCENE = preload("res://Nodes/stress_test_director.tscn")
const SECRET_BOSS_DIRECTOR_SCENE = preload("res://Nodes/secret_boss_director.tscn")
const RUN_VARIATION_DIRECTOR_SCENE = preload("res://Nodes/run_variation_director.tscn")
const MULTIPLAYER_SYNC_FOUNDATION_SCENE = preload("res://Nodes/multiplayer_sync_foundation.tscn")
const MOD_CONTENT_REGISTRY_SCENE = preload("res://Nodes/mod_content_registry.tscn")
const MOD_HOOK_DIRECTOR_SCENE = preload("res://Nodes/mod_hook_director.tscn")
const RUN_SCORE_TRACKER_SCENE = preload("res://Nodes/run_score_tracker.tscn")
const PHYSICS_DROP_SYSTEM_SCENE = preload("res://Nodes/physics_drop_system.tscn")
const ARENA_RULE_DIRECTOR_SCENE = preload("res://Nodes/arena_rule_director.tscn")
const LATE_GAME_INSTABILITY_DIRECTOR_SCENE = preload("res://Nodes/late_game_instability_director.tscn")
const COOP_COMBO_DIRECTOR_SCENE = preload("res://Nodes/coop_combo_director.tscn")
const ADAPTIVE_MUSIC_STATE_DIRECTOR_SCENE = preload("res://Nodes/adaptive_music_state_director.tscn")
const RUN_TRANSITION_DIRECTOR_SCENE = preload("res://Nodes/run_transition_director.tscn")
const DEATH_FAIRNESS_DIRECTOR_SCENE = preload("res://Nodes/death_fairness_director.tscn")
const FAIR_PACING_DIRECTOR_SCENE = preload("res://Nodes/fair_pacing_director.tscn")
const RECOVERY_OPPORTUNITY_DIRECTOR_SCENE = preload("res://Nodes/recovery_opportunity_director.tscn")
const RUN_STORY_ARC_DIRECTOR_SCENE = preload("res://Nodes/run_story_arc_director.tscn")
const WEAPON_SYSTEM_SCENE = preload("res://Nodes/weapon_system.tscn")
const SKILL_SIGNATURE_DIRECTOR_SCENE = preload("res://Nodes/skill_signature_director.tscn")
const SPACETIME_SWIM_DIRECTOR_SCENE = preload("res://Nodes/spacetime_swim_director.tscn")
const SPACETIME_TEAR_DIRECTOR_SCENE = preload("res://Nodes/spacetime_tear_director.tscn")
const VECTOR_ANOMALY_DIRECTOR_SCENE = preload("res://Nodes/vector_anomaly_director.tscn")
const CELESTIAL_BODY_DIRECTOR_SCENE = preload("res://Nodes/celestial_body_director.tscn")
const REALITY_COLLAPSE_DIRECTOR_SCENE = preload("res://Nodes/reality_collapse_director.tscn")

const PLANET_ATMOSPHERE_SCENE = preload("res://Nodes/planet_atmosphere_dust.tscn")
const WAVE_DIRECTOR_SCENE = preload("res://Nodes/wave_director.tscn")
const RUN_DIRECTOR_SCENE = preload("res://Nodes/run_director.tscn")
const PLAYER_VISUAL_STATE_SCENE = preload("res://Nodes/player_visual_state.tscn")

const UNSTABLE_MOON_SCENE = preload("res://Nodes/unstable_moon.tscn")
const NEBULA_CLOUD_SCENE = preload("res://Nodes/nebula_cloud.tscn")
const WORMHOLE_PAIR_SCENE = preload("res://Nodes/wormhole_pair.tscn")

const LEECH_PARASITE_SCENE = preload("res://Nodes/leech_parasite.tscn")
const SPLITTING_ASTEROID_SCENE = preload("res://Nodes/splitting_asteroid_bot.tscn")
const GRAVITY_HARASSER_SCENE = preload("res://Nodes/gravity_harasser.tscn")
const SNIPER_TURRET_SCENE = preload("res://Nodes/sniper_turret.tscn")
const SHIELDER_SUPPORT_SCENE = preload("res://Nodes/shielder_support.tscn")
const PARAMETRIC_1_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_1.tscn")
const PARAMETRIC_2_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_2.tscn")
const PARAMETRIC_3_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_3.tscn")
const PARAMETRIC_4_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_4.tscn")
const PARAMETRIC_5_SCENE = preload("res://Nodes/ParametricEquationEnemies/parametric_enemy_5.tscn")
const CENTRIFUGE_MARSHAL_SCENE = preload("res://Nodes/centrifuge_marshal_boss.tscn")

@export var attach_player_juice = true
@export var attach_gameplay_teaching = true
@export var attach_mechanic_audio = true
@export var attach_enemy_readability = true
@export var attach_performance_budget = true
@export var attach_particle_focus_culler = true
@export var attach_momentum_combat = true
@export var attach_planet_atmospheres = true
@export var attach_projectile_sparks = true
@export var attach_orbital_vfx = true
@export var enable_gravity_heat_map_overlay = true
@export var enable_debug_balance_overlay = true
@export var enable_gravity_resonance = true
@export var enable_gravity_scars = true
@export var enable_event_horizon_moments = true
@export var enable_wave_game = true
@export var enable_arena_destabilization = true
@export var enable_data_driven_arena_instability = true
@export var enable_physics_aware_enemy_ai = true
@export var enable_secret_bosses = true
@export var enable_run_variation = true
@export var enable_multiplayer_sync_foundation = true
@export var enable_mod_content_registry = true
@export var enable_mod_hook_director = true
@export var enable_run_score_tracker = true
@export var enable_physics_drop_system = true
@export var enable_arena_rule_profiles = true
@export var enable_late_game_instability = true
@export var enable_coop_combos = true
@export var enable_adaptive_music_state = true
@export var enable_run_transitions = true
@export var enable_death_fairness = true
@export var enable_fair_pacing = true
@export var enable_recovery_opportunities = true
@export var enable_run_story_arc = true
@export var enable_weapon_system = true
@export var enable_skill_signatures = true
@export var enable_spacetime_swim_effects = true
@export var enable_spacetime_tear_spawns = true
@export var enable_vector_anomaly_rules = true
@export var enable_dynamic_celestial_bodies = true
@export var enable_reality_collapse = true
@export_group("Developer Showcase")
@export var enable_stress_test_tools = false
@export var run_stress_test_on_ready = false
@export var spawn_showcase_content = false
@export var spawn_showcase_boss = false
@export var spawn_parametric_showcase_content = false
@export var showcase_alongside_wave_game = false
@export var enable_dev_hotkeys = false
@export var dev_showcase_key: int = KEY_F6
@export var dev_stress_key: int = KEY_F7
@export var dev_clear_stress_key: int = KEY_F9
@export var near_miss_time_charge_multiplier: float = 0.14
@export_group("Quality")
@export_enum("Off", "Low", "High") var resonance_visual_quality: int = 2
@export var enable_tide_particles: bool = true
@export var enable_time_afterimages: bool = true
@export var low_performance_mode: bool = false

var _installed = false
var _stress_director: Node = null

func _ready() -> void:
	add_to_group("orbital_juice_manager")
	# Defer installation so every existing level node has run its own _ready.
	call_deferred("_install_modular_additions")

func _unhandled_input(event: InputEvent) -> void:
	if not enable_dev_hotkeys:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == dev_showcase_key:
		spawn_showcase_content_now()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == dev_stress_key:
		run_stress_test_now()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == dev_clear_stress_key:
		clear_stress_test_now()
		get_viewport().set_input_as_handled()

func _install_modular_additions() -> void:
	if _installed:
		return

	_installed = true

	var level_root = get_tree().current_scene
	if NetworkSession != null:
		NetworkSession.configure_arena_players(level_root)
	var players := _get_player_nodes()
	var player := _primary_player_from_list(players)

	_add_child_scene_once(level_root, HUD_SCENE, "OrbitalHUD")
	if enable_gravity_heat_map_overlay:
		_add_child_scene_once(level_root, GRAVITY_HEAT_MAP_OVERLAY_SCENE, "GravityHeatMapOverlay")
	if attach_gameplay_teaching:
		_add_child_scene_once(level_root, GAMEPLAY_TEACHING_SCENE, "GameplayTeachingDirector")
	if attach_performance_budget:
		_add_child_scene_once(level_root, PERFORMANCE_BUDGET_SCENE, "PerformanceBudgetDirector")
	if attach_particle_focus_culler:
		_add_child_scene_once(level_root, PARTICLE_FOCUS_CULLER_SCENE, "ParticleFocusCuller")
	if enable_mod_content_registry:
		_add_child_scene_once(level_root, MOD_CONTENT_REGISTRY_SCENE, "ModContentRegistry")
	if enable_mod_hook_director:
		_add_child_scene_once(level_root, MOD_HOOK_DIRECTOR_SCENE, "ModHookDirector")
	if enable_physics_drop_system:
		_add_child_scene_once(level_root, PHYSICS_DROP_SYSTEM_SCENE, "PhysicsDropSystem")
	if enable_multiplayer_sync_foundation:
		_add_child_scene_once(level_root, MULTIPLAYER_SYNC_FOUNDATION_SCENE, "MultiplayerSyncFoundation")
	if enable_adaptive_music_state:
		_add_child_scene_once(level_root, ADAPTIVE_MUSIC_STATE_DIRECTOR_SCENE, "AdaptiveMusicStateDirector")
	if enable_run_transitions:
		_add_child_scene_once(level_root, RUN_TRANSITION_DIRECTOR_SCENE, "RunTransitionDirector")
	if enable_run_story_arc:
		_add_child_scene_once(level_root, RUN_STORY_ARC_DIRECTOR_SCENE, "RunStoryArcDirector")
	if enable_debug_balance_overlay:
		# The balance overlay is its own CanvasLayer, so telemetry can be
		# toggled or removed without changing player, enemy, or wave logic.
		_add_child_scene_once(level_root, DEBUG_BALANCE_OVERLAY_SCENE, "DebugBalanceOverlay")

	if attach_projectile_sparks:
		_add_child_scene_once(level_root, SPARK_WATCHER_SCENE, "ProjectileSparkWatcher")

	_add_child_scene_once(level_root, JUICE_COORDINATOR_SCENE, "JuiceCoordinator")

	if enable_gravity_resonance:
		# Resonance is the shared gravity telemetry layer: arena escalation,
		# projectiles, VFX, and future audio hooks can all listen here.
		_add_child_scene_once(level_root, GRAVITY_RESONANCE_SCENE, "GravityResonanceManager")

	_add_child_scene_once(level_root, TIME_DILATION_SCENE, "TimeDilationManager")
	if enable_gravity_scars:
		_add_child_scene_once(level_root, GRAVITY_SCAR_MANAGER_SCENE, "GravityScarManager")
	if enable_event_horizon_moments:
		_add_child_scene_once(level_root, EVENT_HORIZON_DIRECTOR_SCENE, "EventHorizonDirector")
	_add_child_scene_once(level_root, VISUAL_ESCALATION_SCENE, "VisualEscalationDirector")
	if enable_skill_signatures:
		_add_child_scene_once(level_root, SKILL_SIGNATURE_DIRECTOR_SCENE, "SkillSignatureDirector")
	if enable_spacetime_swim_effects:
		_add_child_scene_once(level_root, SPACETIME_SWIM_DIRECTOR_SCENE, "SpacetimeSwimDirector")
	if enable_spacetime_tear_spawns:
		_add_child_scene_once(level_root, SPACETIME_TEAR_DIRECTOR_SCENE, "SpacetimeTearDirector")
	if enable_vector_anomaly_rules:
		_add_child_scene_once(level_root, VECTOR_ANOMALY_DIRECTOR_SCENE, "VectorAnomalyDirector")
	if enable_dynamic_celestial_bodies:
		_add_child_scene_once(level_root, CELESTIAL_BODY_DIRECTOR_SCENE, "CelestialBodyDirector")
	if enable_reality_collapse:
		_add_child_scene_once(level_root, REALITY_COLLAPSE_DIRECTOR_SCENE, "RealityCollapseDirector")

	for current_player in players:
		_install_player_additions(level_root, current_player)

	if enable_coop_combos:
		_add_child_scene_once(level_root, COOP_COMBO_DIRECTOR_SCENE, "CoopComboDirector")
	if enable_death_fairness:
		_add_child_scene_once(level_root, DEATH_FAIRNESS_DIRECTOR_SCENE, "DeathFairnessDirector")

	if attach_planet_atmospheres:
		for planet in get_tree().get_nodes_in_group("planets"):
			if planet is Node and planet != null:
				_add_child_scene_once(planet, PLANET_ATMOSPHERE_SCENE, "PlanetAtmosphereDust")

	if attach_orbital_vfx:
		_add_child_scene_once(level_root, ORBITAL_VFX_DIRECTOR_SCENE, "OrbitalVFXDirector")

	if attach_mechanic_audio:
		_add_child_scene_once(level_root, MECHANIC_AUDIO_SCENE, "MechanicAudioDirector")

	if attach_enemy_readability:
		_add_child_scene_once(level_root, ENEMY_READABILITY_SCENE, "EnemyReadabilityDirector")

	if enable_stress_test_tools:
		_stress_director = _add_child_scene_once(level_root, STRESS_TEST_DIRECTOR_SCENE, "StressTestDirector")
		_configure_stress_director(run_stress_test_on_ready)

	var run_wave_game := enable_wave_game and player != null and not (spawn_showcase_content and not showcase_alongside_wave_game)
	if run_wave_game:
		_add_child_scene_once(level_root, RUN_DIRECTOR_SCENE, "RunDirector")
		_add_child_scene_once(level_root, WAVE_DIRECTOR_SCENE, "WaveDirector")
		if enable_physics_aware_enemy_ai:
			_add_child_scene_once(level_root, PHYSICS_AWARE_ENEMY_DIRECTOR_SCENE, "PhysicsAwareEnemyDirector")
		if enable_arena_destabilization:
			_add_child_scene_once(level_root, ARENA_DESTABILIZATION_SCENE, "ArenaDestabilizationManager")
		if enable_data_driven_arena_instability:
			_add_child_scene_once(level_root, ARENA_INSTABILITY_DIRECTOR_SCENE, "ArenaInstabilityDirector")
		if enable_arena_rule_profiles:
			_add_child_scene_once(level_root, ARENA_RULE_DIRECTOR_SCENE, "ArenaRuleDirector")
		if enable_late_game_instability:
			_add_child_scene_once(level_root, LATE_GAME_INSTABILITY_DIRECTOR_SCENE, "LateGameInstabilityDirector")
		if enable_fair_pacing:
			_add_child_scene_once(level_root, FAIR_PACING_DIRECTOR_SCENE, "FairPacingDirector")
		if enable_recovery_opportunities:
			_add_child_scene_once(level_root, RECOVERY_OPPORTUNITY_DIRECTOR_SCENE, "RecoveryOpportunityDirector")
		if enable_run_variation:
			_add_child_scene_once(level_root, RUN_VARIATION_DIRECTOR_SCENE, "RunVariationDirector")
		if enable_secret_bosses:
			_add_child_scene_once(level_root, SECRET_BOSS_DIRECTOR_SCENE, "SecretBossDirector")
		if enable_run_score_tracker:
			_add_child_scene_once(level_root, RUN_SCORE_TRACKER_SCENE, "RunScoreTracker")

	var player_2d := player as Node2D
	if spawn_showcase_content and player_2d != null:
		_spawn_showcase_content(level_root, player_2d.global_position)
		_refresh_player_planet_cache(player_2d)

	_apply_quality_settings(level_root)

	if run_stress_test_on_ready:
		call_deferred("run_stress_test_now")

	if NetworkSession != null:
		NetworkSession.refresh_runtime_multiplayer_bindings(level_root)

func _add_child_scene_once(parent: Node, scene: PackedScene, child_name: String) -> Node:
	if parent == null:
		return null
	if parent.has_node(child_name):
		return parent.get_node(child_name)

	var child = scene.instantiate()
	child.name = child_name
	parent.add_child(child)
	return child


func _get_player_nodes() -> Array[Node]:
	var players: Array[Node] = []
	for node in get_tree().get_nodes_in_group("Player"):
		var player := node as Node
		if player != null and is_instance_valid(player) and not player.is_queued_for_deletion():
			players.append(player)
	players.sort_custom(func(a: Node, b: Node) -> bool:
		return _player_peer_id(a) < _player_peer_id(b)
	)
	return players


func _primary_player_from_list(players: Array[Node]) -> Node:
	for player in players:
		if _is_local_player_node(player):
			return player
	return players[0] if not players.is_empty() else null


func _install_player_additions(level_root: Node, player: Node) -> void:
	if player == null:
		return
	var is_local_player := _is_local_player_node(player)
	if attach_player_juice:
		_add_child_scene_once(player, THRUSTER_TRAILS_SCENE, "PlayerThrusterTrails")
		_add_child_scene_once(player, ENGINE_HUM_SCENE, "PlayerEngineHum")
		_add_child_scene_once(player, PLAYER_VISUAL_STATE_SCENE, "PlayerVisualState")

	if is_local_player and attach_momentum_combat:
		# Momentum combat stays local-input-owned; remote vector events arrive
		# through NetworkSession and CoopComboDirector.
		_add_child_scene_once(player, MOMENTUM_COMBAT_SCENE, "MomentumCombatComponent")
		_connect_momentum_to_time_dilation(level_root, player)

	if is_local_player and enable_weapon_system:
		_add_child_scene_once(player, WEAPON_SYSTEM_SCENE, "WeaponSystem")

	var camera = player.get_node_or_null("Camera2D")
	if is_local_player and attach_player_juice and camera != null:
		_add_child_scene_once(camera, CAMERA_SHAKE_SCENE, "DamageCameraShake")


func _is_local_player_node(player: Node) -> bool:
	if player == null:
		return true
	var value: Variant = player.get("network_is_local")
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return true


func _player_peer_id(player: Node) -> int:
	if player == null:
		return 1
	var value: Variant = player.get("network_peer_id")
	if typeof(value) == TYPE_INT:
		return int(value)
	return 1

func spawn_showcase_content_now() -> void:
	var level_root := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("Player")
	if level_root == null or player == null:
		return
	_spawn_showcase_content(level_root, player.global_position)
	_refresh_player_planet_cache(player)


func run_stress_test_now() -> Dictionary:
	var level_root := get_tree().current_scene
	if level_root == null:
		return {"ok": false}
	if _stress_director == null or not is_instance_valid(_stress_director):
		_stress_director = _add_child_scene_once(level_root, STRESS_TEST_DIRECTOR_SCENE, "StressTestDirector")
	_configure_stress_director_enabled()
	if _stress_director != null and _stress_director.has_method("run_extreme_arena_stress"):
		_stress_director.call("run_extreme_arena_stress")
	if _stress_director != null and _stress_director.has_method("validate_performance_budgets"):
		return _stress_director.call("validate_performance_budgets")
	return {"ok": true}


func clear_stress_test_now() -> void:
	if _stress_director != null and is_instance_valid(_stress_director) and _stress_director.has_method("clear_stress_test"):
		_stress_director.call("clear_stress_test")


func get_juice_debug_state() -> Dictionary:
	var stress_state := {}
	if _stress_director != null and _stress_director.has_method("get_stress_debug_state"):
		stress_state = _stress_director.call("get_stress_debug_state")
	return {
		"showcase_enabled": spawn_showcase_content,
		"stress_tools_enabled": enable_stress_test_tools,
		"stress": stress_state,
	}


func _configure_stress_director_enabled() -> void:
	if _stress_director == null:
		return
	if _stress_director.get("enabled") != null:
		_stress_director.set("enabled", true)


func _configure_stress_director(run_on_ready: bool) -> void:
	_configure_stress_director_enabled()
	if _stress_director.get("run_on_ready") != null:
		_stress_director.set("run_on_ready", run_on_ready)


func _spawn_showcase_content(level_root: Node, origin: Vector2) -> void:
	# The positions are intentionally spread around the starting player area so
	# contributors can immediately see and tune each idea in the main scene.
	_spawn_node_once(level_root, NEBULA_CLOUD_SCENE, "ShowcaseNebulaCloud", origin + Vector2(-720.0, -320.0))
	_spawn_node_once(level_root, UNSTABLE_MOON_SCENE, "ShowcaseUnstableMoon", origin + Vector2(820.0, -430.0))

	var wormhole = _spawn_node_once(level_root, WORMHOLE_PAIR_SCENE, "ShowcaseWormholePair", Vector2.ZERO)
	if wormhole != null and wormhole.has_method("set_endpoint_positions"):
		wormhole.set_endpoint_positions(origin + Vector2(1180.0, 240.0), origin + Vector2(-1280.0, 620.0))

	_spawn_node_once(level_root, LEECH_PARASITE_SCENE, "ShowcaseLeechParasite", origin + Vector2(-520.0, 430.0))
	_spawn_node_once(level_root, SPLITTING_ASTEROID_SCENE, "ShowcaseSplittingAsteroidBot", origin + Vector2(540.0, 520.0))
	_spawn_node_once(level_root, GRAVITY_HARASSER_SCENE, "ShowcaseGravityHarasser", origin + Vector2(-960.0, 180.0))
	_spawn_node_once(level_root, SNIPER_TURRET_SCENE, "ShowcaseSniperTurret", origin + Vector2(1450.0, -660.0))
	_spawn_node_once(level_root, SHIELDER_SUPPORT_SCENE, "ShowcaseShielderSupport", origin + Vector2(-1060.0, 350.0))

	if spawn_showcase_boss:
		_spawn_node_once(level_root, CENTRIFUGE_MARSHAL_SCENE, "ShowcaseCentrifugeMarshal", origin + Vector2(0.0, -920.0))

	if spawn_parametric_showcase_content:
		_spawn_node_once(level_root, PARAMETRIC_1_SCENE, "ShowcaseParametricDrifter", origin + Vector2(-720.0, 780.0))
		_spawn_node_once(level_root, PARAMETRIC_2_SCENE, "ShowcaseParametricVector", origin + Vector2(-360.0, 920.0))
		_spawn_node_once(level_root, PARAMETRIC_3_SCENE, "ShowcaseParametricPulseMine", origin + Vector2(0.0, 1040.0))
		_spawn_node_once(level_root, PARAMETRIC_4_SCENE, "ShowcaseParametricDuelist", origin + Vector2(360.0, 920.0))
		_spawn_node_once(level_root, PARAMETRIC_5_SCENE, "ShowcaseParametricArchitect", origin + Vector2(720.0, 780.0))

func _spawn_node_once(parent: Node, scene: PackedScene, node_name: String, global_pos: Vector2) -> Node:
	if parent == null:
		return null
	if parent.has_node(node_name):
		return parent.get_node(node_name)

	var node = scene.instantiate()
	node.name = node_name
	parent.add_child(node)

	if node is Node2D:
		node.global_position = global_pos

	return node

func _refresh_player_planet_cache(player: Node) -> void:
	# The player caches the planets group in _ready, so newly spawned gravity
	# hazards are pushed into that cache without editing player.gd.
	if player != null and player.get("planets") != null:
		player.set("planets", get_tree().get_nodes_in_group("planets"))

func _connect_momentum_to_time_dilation(level_root: Node, player: Node) -> void:
	if level_root == null or player == null:
		return

	var momentum := player.get_node_or_null("MomentumCombatComponent")
	var time_manager := level_root.find_child("TimeDilationManager", true, false)
	if momentum == null or time_manager == null:
		return
	if not momentum.has_signal("near_miss_velocity_gained") or not time_manager.has_method("add_near_miss_charge"):
		return

	var callable := Callable(self, "_on_momentum_near_miss_velocity_gained").bind(time_manager)
	if not momentum.is_connected("near_miss_velocity_gained", callable):
		momentum.connect("near_miss_velocity_gained", callable)

func _on_momentum_near_miss_velocity_gained(_target: Node, amount: float, time_manager: Node) -> void:
	if time_manager == null or not is_instance_valid(time_manager):
		return

	var base_charge_value: Variant = time_manager.get("near_miss_charge_amount")
	var base_charge_is_number := typeof(base_charge_value) == TYPE_FLOAT or typeof(base_charge_value) == TYPE_INT
	var base_charge := float(base_charge_value) if base_charge_is_number else 15.0
	var charge := maxf(base_charge * 0.65, amount * near_miss_time_charge_multiplier)
	time_manager.call("add_near_miss_charge", charge)

func _apply_quality_settings(level_root: Node) -> void:
	if level_root == null:
		return

	var resonance := level_root.find_child("GravityResonanceManager", true, false)
	if resonance != null:
		if resonance.get("resonance_visual_quality") != null:
			resonance.set("resonance_visual_quality", resonance_visual_quality)
		if resonance.get("max_visual_particles_per_zone") != null and low_performance_mode:
			resonance.set("max_visual_particles_per_zone", 16)

	var arena := level_root.find_child("ArenaDestabilizationManager", true, false)
	if arena != null:
		if arena.get("low_performance_mode") != null:
			arena.set("low_performance_mode", low_performance_mode)
		if arena.get("enable_tide_particles") != null:
			arena.set("enable_tide_particles", enable_tide_particles)
		if arena.get("particle_scale") != null and low_performance_mode:
			arena.set("particle_scale", 0.45)

	var time_manager := level_root.find_child("TimeDilationManager", true, false)
	if time_manager != null and time_manager.get("enable_afterimages") != null:
		time_manager.set("enable_afterimages", enable_time_afterimages and not low_performance_mode)

	var vfx := level_root.find_child("OrbitalVFXDirector", true, false)
	if vfx != null:
		if vfx.get("visual_quality") != null:
			vfx.set("visual_quality", resonance_visual_quality)
		if vfx.get("low_performance_mode") != null:
			vfx.set("low_performance_mode", low_performance_mode)
		if vfx.get("max_particles_per_burst") != null and low_performance_mode:
			vfx.set("max_particles_per_burst", 34)
		if vfx.get("max_active_bursts") != null and low_performance_mode:
			vfx.set("max_active_bursts", 8)

	var scars := level_root.find_child("GravityScarManager", true, false)
	if scars != null:
		if scars.get("visual_quality") != null:
			scars.set("visual_quality", resonance_visual_quality)
		if scars.get("max_active_scars") != null and low_performance_mode:
			scars.set("max_active_scars", 5)
		if scars.get("max_particles_per_scar") != null and low_performance_mode:
			scars.set("max_particles_per_scar", 12)
		if scars.get("max_body_targets_per_tick") != null and low_performance_mode:
			scars.set("max_body_targets_per_tick", 24)
		if scars.get("max_projectile_targets_per_tick") != null and low_performance_mode:
			scars.set("max_projectile_targets_per_tick", 28)

	var horizon := level_root.find_child("EventHorizonDirector", true, false)
	if horizon != null:
		if horizon.get("screen_warp_enabled") != null and low_performance_mode:
			horizon.set("screen_warp_enabled", false)
		if horizon.get("max_targets_per_tick") != null and low_performance_mode:
			horizon.set("max_targets_per_tick", 36)

	var signatures := level_root.find_child("SkillSignatureDirector", true, false)
	if signatures != null and low_performance_mode:
		if signatures.get("max_active_signatures") != null:
			signatures.set("max_active_signatures", 5)
		if signatures.get("ring_segments") != null:
			signatures.set("ring_segments", 28)

	var swim := level_root.find_child("SpacetimeSwimDirector", true, false)
	if swim != null and low_performance_mode:
		if swim.get("max_swim_ribbons") != null:
			swim.set("max_swim_ribbons", 6)
		if swim.get("max_glitch_slices") != null:
			swim.set("max_glitch_slices", 6)
		if swim.get("overlay_alpha_cap") != null:
			swim.set("overlay_alpha_cap", 0.08)

	var tears := level_root.find_child("SpacetimeTearDirector", true, false)
	if tears != null and low_performance_mode:
		if tears.get("max_active_tears") != null:
			tears.set("max_active_tears", 2)
		if tears.get("max_alive_tear_enemies") != null:
			tears.set("max_alive_tear_enemies", 5)
		if tears.get("ring_segments") != null:
			tears.set("ring_segments", 28)

	var anomaly := level_root.find_child("VectorAnomalyDirector", true, false)
	if anomaly != null and low_performance_mode:
		if anomaly.get("max_active_micro_lenses") != null:
			anomaly.set("max_active_micro_lenses", 3)
		if anomaly.get("max_targets_per_tick") != null:
			anomaly.set("max_targets_per_tick", 30)
		if anomaly.get("max_seeded_debris") != null:
			anomaly.set("max_seeded_debris", 5)
		if anomaly.get("memory_max_points") != null:
			anomaly.set("memory_max_points", 48)

	var budget := level_root.find_child("PerformanceBudgetDirector", true, false)
	if budget != null:
		if budget.get("quality_tier") != null:
			budget.set("quality_tier", 0 if low_performance_mode else resonance_visual_quality)
		if budget.has_method("apply_budgets"):
			budget.call("apply_budgets")

	var juice_coord := level_root.find_child("JuiceCoordinator", true, false)
	if juice_coord != null:
		if juice_coord.get("low_performance_mode") != null:
			juice_coord.set("low_performance_mode", low_performance_mode)
		if juice_coord.get("disable_mastery_line2d") != null:
			juice_coord.set("disable_mastery_line2d", low_performance_mode)
