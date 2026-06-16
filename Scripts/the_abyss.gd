extends Node2D

## Planet Spawner for Vector Anomaly
## Creates planets around the player while avoiding overlaps.
## Tiny procedural cosmos machine

@export var planet_scene: PackedScene = preload("res://Nodes/planet_1.tscn")

# ============================================================
# SPAWN SETTINGS
# ============================================================

@export var player_group: StringName = &"Player"

@export var planets_to_spawn: int = 30

@export var min_spawn_radius: float = 900.0
@export var max_spawn_radius: float = 3500.0

@export var min_planet_diameter: float = 100.0
@export var max_planet_diameter: float = 300.0

@export var max_spawn_attempts_per_planet: int = 40

## Extra empty space between planets
@export var padding: float = 40.0

## What objects should block spawning?
## Add big hazards, arenas, structures, etc.
@export var collision_groups: Array[StringName] = [
	&"Objects_With_Gravity",
	&"Environment",
	&"Enemies"
]

# ============================================================
# INTERNAL
# ============================================================

var spawned_planets: Array = []
var _rng := RandomNumberGenerator.new()
var _spawn_blockers: Array[Dictionary] = []

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	if NetworkSession != null:
		NetworkSession.configure_arena_players(self)
	_seed_rng()
	spawn_planets()

# ============================================================
# MAIN SPAWNING
# ============================================================

func spawn_planets() -> void:
	var player := _planet_spawn_anchor()

	if player == null:
		push_error("PlanetSpawner: No player found in group '%s'" % player_group)
		return

	spawned_planets.clear()
	_rebuild_spawn_blockers()
	for i in range(planets_to_spawn):
		var success := try_spawn_planet(player.global_position, i)

		if !success:
			continue

# ============================================================
# SPAWN SINGLE PLANET
# ============================================================

func try_spawn_planet(center_position: Vector2, planet_index: int) -> bool:

	for attempt in range(max_spawn_attempts_per_planet):

		# --------------------------------------------
		# Random orbit ring around player
		# --------------------------------------------

		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(min_spawn_radius, max_spawn_radius)

		var spawn_position := center_position + Vector2.RIGHT.rotated(angle) * distance

		# --------------------------------------------
		# Random planet size
		# --------------------------------------------

		var diameter := _rng.randf_range(min_planet_diameter, max_planet_diameter)
		var radius := diameter * 0.5

		# --------------------------------------------
		# Validate location
		# --------------------------------------------

		if is_position_valid(spawn_position, radius):

			var planet := planet_scene.instantiate()
			planet.name = "SeedPlanet%d" % planet_index

			planet.global_position = spawn_position
			if planet.has_method("configure_deterministic"):
				planet.call(
					"configure_deterministic",
					_planet_seed_for_index(planet_index),
					StringName("abyss_planet_%d" % planet_index)
				)

			# ----------------------------------------
			# Scale planet based on desired diameter
			# Assumes base planet texture/scene ≈ 100px
			# ----------------------------------------

			var scale_factor := diameter / 100.0
			planet.scale = Vector2.ONE * scale_factor
			if planet.get("base_radius") != null:
				planet.set("base_radius", radius)
			if planet.get("base_mass") != null:
				planet.set("base_mass", 300000.0 * maxf(radius / 150.0, 0.25))

			add_child(planet)

			# Store lightweight collision info
			spawned_planets.append({
				"position": spawn_position,
				"radius": radius
			})

			return true

	return false

# ============================================================
# VALIDATION
# ============================================================

func is_position_valid(pos: Vector2, radius: float) -> bool:

	# ------------------------------------------------
	# Check already spawned planets
	# ------------------------------------------------

	for data in spawned_planets:

		var other_pos: Vector2 = data.position
		var other_radius: float = data.radius

		var min_distance := radius + other_radius + padding

		if pos.distance_to(other_pos) < min_distance:
			return false

	for blocker in _spawn_blockers:
		var other_pos: Vector2 = blocker.position
		var other_radius: float = blocker.radius
		var min_distance := radius + other_radius + padding
		if pos.distance_to(other_pos) < min_distance:
			return false

	return true


func _rebuild_spawn_blockers() -> void:
	_spawn_blockers.clear()
	var seen: Dictionary = {}
	for group_name in collision_groups:
		var nodes := get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			if node == self or node == null or not is_instance_valid(node):
				continue
			var node_2d := node as Node2D
			if node_2d == null or node_2d.is_queued_for_deletion():
				continue
			var id := node_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_spawn_blockers.append({
				"position": node_2d.global_position,
				"radius": _estimated_spawn_blocker_radius(node_2d),
			})


func _estimated_spawn_blocker_radius(node: Node2D) -> float:
	var radius_value: Variant = node.get("radius")
	if radius_value is float or radius_value is int:
		return maxf(float(radius_value), 24.0)
	var base_radius_value: Variant = node.get("base_radius")
	if base_radius_value is float or base_radius_value is int:
		return maxf(float(base_radius_value), 24.0)
	var collision := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return maxf((collision.shape as CircleShape2D).radius * maxf(node.scale.x, node.scale.y), 24.0)
	return 100.0 * maxf(node.scale.x, node.scale.y)


func _seed_rng() -> void:
	if RunProgress != null and int(RunProgress.run_seed) != 0:
		_rng.seed = int(RunProgress.run_seed) ^ 0xA8B155
	else:
		_rng.randomize()


func _planet_spawn_anchor() -> Node2D:
	if NetworkSession != null and NetworkSession.has_method("is_network_active") and bool(NetworkSession.call("is_network_active")):
		for node in get_tree().get_nodes_in_group(player_group):
			var player := node as Node2D
			if player == null or not is_instance_valid(player):
				continue
			var peer_value: Variant = player.get("network_peer_id")
			if typeof(peer_value) == TYPE_INT and int(peer_value) == 1:
				return player
	return get_tree().get_first_node_in_group(player_group) as Node2D


func _planet_seed_for_index(index: int) -> int:
	var run_seed := int(RunProgress.run_seed if RunProgress != null else 0)
	return maxi(absi(int(hash("%d:abyss_planet:%d" % [run_seed, index]))), 1)
