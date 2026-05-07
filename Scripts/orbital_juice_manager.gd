extends Node2D

# Modular installer for contributor ideas.
# This node keeps the original player/enemy scripts intact and adds optional
# systems as child nodes or showcase scenes once the main level is ready.

const HUD_SCENE = preload("res://Nodes/orbital_hud.tscn")
const THRUSTER_TRAILS_SCENE = preload("res://Nodes/player_thruster_trails.tscn")
const ENGINE_HUM_SCENE = preload("res://Nodes/player_engine_hum.tscn")
const CAMERA_SHAKE_SCENE = preload("res://Nodes/player_damage_camera_shake.tscn")
const SPARK_WATCHER_SCENE = preload("res://Nodes/projectile_spark_watcher.tscn")

const PLANET_ATMOSPHERE_SCENE = preload("res://Nodes/planet_atmosphere_dust.tscn")
const WAVE_DIRECTOR_SCENE = preload("res://Nodes/wave_director.tscn")

const UNSTABLE_MOON_SCENE = preload("res://Nodes/unstable_moon.tscn")
const NEBULA_CLOUD_SCENE = preload("res://Nodes/nebula_cloud.tscn")
const WORMHOLE_PAIR_SCENE = preload("res://Nodes/wormhole_pair.tscn")

const LEECH_PARASITE_SCENE = preload("res://Nodes/leech_parasite.tscn")
const SPLITTING_ASTEROID_SCENE = preload("res://Nodes/splitting_asteroid_bot.tscn")
const GRAVITY_HARASSER_SCENE = preload("res://Nodes/gravity_harasser.tscn")
const SNIPER_TURRET_SCENE = preload("res://Nodes/sniper_turret.tscn")
const SHIELDER_SUPPORT_SCENE = preload("res://Nodes/shielder_support.tscn")

@export var attach_player_juice = true
@export var attach_planet_atmospheres = true
@export var attach_projectile_sparks = true
@export var enable_wave_game = true
@export var spawn_showcase_content = false

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

	if attach_projectile_sparks:
		_add_child_scene_once(level_root, SPARK_WATCHER_SCENE, "ProjectileSparkWatcher")
		
		

	if player != null and attach_player_juice:
		_add_child_scene_once(player, THRUSTER_TRAILS_SCENE, "PlayerThrusterTrails")
		_add_child_scene_once(player, ENGINE_HUM_SCENE, "PlayerEngineHum")

		var camera = player.get_node_or_null("Camera2D")
		if camera != null:
			_add_child_scene_once(camera, CAMERA_SHAKE_SCENE, "DamageCameraShake")

	if attach_planet_atmospheres:
		for planet in get_tree().get_nodes_in_group("planets"):
			if planet is Node and planet != null:
				_add_child_scene_once(planet, PLANET_ATMOSPHERE_SCENE, "PlanetAtmosphereDust")

	if enable_wave_game and player != null:
		_add_child_scene_once(level_root, WAVE_DIRECTOR_SCENE, "WaveDirector")
	elif spawn_showcase_content and player != null:
		_spawn_showcase_content(level_root, player.global_position)
		_refresh_player_planet_cache(player)

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
