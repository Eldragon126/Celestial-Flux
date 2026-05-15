extends Node2D

## Planet Spawner for ORBITRON: VECTORFALL
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

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	randomize()
	spawn_planets()

# ============================================================
# MAIN SPAWNING
# ============================================================

func spawn_planets() -> void:
	var player := get_tree().get_first_node_in_group(player_group)

	if player == null:
		push_error("PlanetSpawner: No player found in group '%s'" % player_group)
		return

	for i in planets_to_spawn:
		var success := try_spawn_planet(player.global_position)

		if !success:
			print("Failed to place planet #%s" % i)

# ============================================================
# SPAWN SINGLE PLANET
# ============================================================

func try_spawn_planet(center_position: Vector2) -> bool:

	for attempt in max_spawn_attempts_per_planet:

		# --------------------------------------------
		# Random orbit ring around player
		# --------------------------------------------

		var angle := randf_range(0.0, TAU)
		var distance := randf_range(min_spawn_radius, max_spawn_radius)

		var spawn_position := center_position + Vector2.RIGHT.rotated(angle) * distance

		# --------------------------------------------
		# Random planet size
		# --------------------------------------------

		var diameter := randf_range(min_planet_diameter, max_planet_diameter)
		var radius := diameter * 0.5

		# --------------------------------------------
		# Validate location
		# --------------------------------------------

		if is_position_valid(spawn_position, radius):

			var planet := planet_scene.instantiate()

			planet.global_position = spawn_position

			# ----------------------------------------
			# Scale planet based on desired diameter
			# Assumes base planet texture/scene ≈ 100px
			# ----------------------------------------

			var scale_factor := diameter / 100.0
			planet.scale = Vector2.ONE * scale_factor

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

	# ------------------------------------------------
	# Check scene objects in collision groups
	# ------------------------------------------------

	for group_name in collision_groups:

		var nodes := get_tree().get_nodes_in_group(group_name)

		for node in nodes:

			if node == self:
				continue

			if !(node is Node2D):
				continue

			var other_pos = node.global_position

			# Approximate object size
			var other_radius := 100.0

			# Try to estimate radius from scale
			if node is Node2D:
				other_radius *= max(node.scale.x, node.scale.y)

			var min_distance := radius + other_radius + padding

			if pos.distance_to(other_pos) < min_distance:
				return false

	return true
