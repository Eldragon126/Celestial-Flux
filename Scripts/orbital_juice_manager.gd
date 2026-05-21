extends Node2D

# Modular installer for contributor ideas.
# This node keeps the original player/enemy scripts intact and adds optional
# systems as child nodes or showcase scenes once the main level is ready.

const HUD_SCENE = preload("res://Nodes/orbital_hud.tscn")
const GAMEPLAY_TEACHING_SCENE = preload("res://Nodes/gameplay_teaching_director.tscn")
const MECHANIC_AUDIO_SCENE = preload("res://Nodes/mechanic_audio_director.tscn")
const ENEMY_READABILITY_SCENE = preload("res://Nodes/enemy_readability_director.tscn")
const PERFORMANCE_BUDGET_SCENE = preload("res://Nodes/performance_budget_director.tscn")
const THRUSTER_TRAILS_SCENE = preload("res://Nodes/player_thruster_trails.tscn")
const ENGINE_HUM_SCENE = preload("res://Nodes/player_engine_hum.tscn")
const CAMERA_SHAKE_SCENE = preload("res://Nodes/player_damage_camera_shake.tscn")
const SPARK_WATCHER_SCENE = preload("res://Nodes/projectile_spark_watcher.tscn")
const DEBUG_BALANCE_OVERLAY_SCENE = preload("res://Nodes/debug_balance_overlay.tscn")
const MOMENTUM_COMBAT_SCENE = preload("res://Nodes/momentum_combat_component.tscn")
const GRAVITY_RESONANCE_SCENE = preload("res://Nodes/gravity_resonance_manager.tscn")
const ORBITAL_VFX_DIRECTOR_SCENE = preload("res://Nodes/orbital_vfx_director.tscn")
const ARENA_DESTABILIZATION_SCENE = preload("res://Nodes/arena_destabilization_manager.tscn")
const PHYSICS_AWARE_ENEMY_DIRECTOR_SCENE = preload("res://Nodes/physics_aware_enemy_director.tscn")
const STRESS_TEST_DIRECTOR_SCENE = preload("res://Nodes/stress_test_director.tscn")

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

@export var attach_player_juice = true
@export var attach_gameplay_teaching = true
@export var attach_mechanic_audio = true
@export var attach_enemy_readability = true
@export var attach_performance_budget = true
@export var attach_momentum_combat = true
@export var attach_planet_atmospheres = true
@export var attach_projectile_sparks = true
@export var attach_orbital_vfx = true
@export var enable_debug_balance_overlay = true
@export var enable_gravity_resonance = true
@export var enable_wave_game = true
@export var enable_arena_destabilization = true
@export var enable_physics_aware_enemy_ai = true
@export var enable_stress_test_tools = false
@export var spawn_showcase_content = false
@export var spawn_parametric_showcase_content = false
@export var near_miss_time_charge_multiplier: float = 0.14
@export_group("Quality")
@export_enum("Off", "Low", "High") var resonance_visual_quality: int = 2
@export var enable_tide_particles: bool = true
@export var enable_time_afterimages: bool = true
@export var low_performance_mode: bool = false

var _installed = false

func _ready() -> void:
	# Defer installation so every existing level node has run its own _ready.
	call_deferred("_install_modular_additions")

func _install_modular_additions() -> void:
	if _installed:
		return

	_installed = true

	var level_root = get_tree().current_scene
	var player = get_tree().get_first_node_in_group("Player")

	_add_child_scene_once(level_root, HUD_SCENE, "OrbitalHUD")
	if attach_gameplay_teaching:
		_add_child_scene_once(level_root, GAMEPLAY_TEACHING_SCENE, "GameplayTeachingDirector")
	if attach_performance_budget:
		_add_child_scene_once(level_root, PERFORMANCE_BUDGET_SCENE, "PerformanceBudgetDirector")
	if enable_debug_balance_overlay:
		# The balance overlay is its own CanvasLayer, so telemetry can be
		# toggled or removed without changing player, enemy, or wave logic.
		_add_child_scene_once(level_root, DEBUG_BALANCE_OVERLAY_SCENE, "DebugBalanceOverlay")

	if attach_projectile_sparks:
		_add_child_scene_once(level_root, SPARK_WATCHER_SCENE, "ProjectileSparkWatcher")

	if enable_gravity_resonance:
		# Resonance is the shared gravity telemetry layer: arena escalation,
		# projectiles, VFX, and future audio hooks can all listen here.
		_add_child_scene_once(level_root, GRAVITY_RESONANCE_SCENE, "GravityResonanceManager")

	if player != null:
		if attach_player_juice:
			_add_child_scene_once(player, THRUSTER_TRAILS_SCENE, "PlayerThrusterTrails")
			_add_child_scene_once(player, ENGINE_HUM_SCENE, "PlayerEngineHum")
			_add_child_scene_once(player, PLAYER_VISUAL_STATE_SCENE, "PlayerVisualState")

		if attach_momentum_combat:
			# Momentum combat stays as a player add-on: it rewards slingshots,
			# near-misses, and kinetic impacts without rewriting player.gd.
			_add_child_scene_once(player, MOMENTUM_COMBAT_SCENE, "MomentumCombatComponent")
			_connect_momentum_to_time_dilation(level_root, player)

		var camera = player.get_node_or_null("Camera2D")
		if attach_player_juice and camera != null:
			_add_child_scene_once(camera, CAMERA_SHAKE_SCENE, "DamageCameraShake")

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
		_add_child_scene_once(level_root, STRESS_TEST_DIRECTOR_SCENE, "StressTestDirector")

	if enable_wave_game and player != null:
		_add_child_scene_once(level_root, RUN_DIRECTOR_SCENE, "RunDirector")
		_add_child_scene_once(level_root, WAVE_DIRECTOR_SCENE, "WaveDirector")
		if enable_physics_aware_enemy_ai:
			# Enemy AI director adds gravity-aware steering nudges while each
			# enemy keeps ownership of its core script and attack behavior.
			_add_child_scene_once(level_root, PHYSICS_AWARE_ENEMY_DIRECTOR_SCENE, "PhysicsAwareEnemyDirector")
		if enable_arena_destabilization:
			# Arena destabilization escalates the battlefield through additive
			# hazards and emits chaos signals for later audio/VFX integration.
			_add_child_scene_once(level_root, ARENA_DESTABILIZATION_SCENE, "ArenaDestabilizationManager")
	elif spawn_showcase_content and player != null:
		_spawn_showcase_content(level_root, player.global_position)
		_refresh_player_planet_cache(player)

	_apply_quality_settings(level_root)

func _add_child_scene_once(parent: Node, scene: PackedScene, child_name: String) -> Node:
	if parent == null:
		return null
	if parent.has_node(child_name):
		return parent.get_node(child_name)

	var child = scene.instantiate()
	child.name = child_name
	parent.add_child(child)
	return child

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

	var budget := level_root.find_child("PerformanceBudgetDirector", true, false)
	if budget != null:
		if budget.get("quality_tier") != null:
			budget.set("quality_tier", 0 if low_performance_mode else resonance_visual_quality)
		if budget.has_method("apply_budgets"):
			budget.call("apply_budgets")
