extends CharacterBody2D

signal tiny_gravity_baby_born(parent_a: Node, parent_b: Node, baby: Node)

const GRAVITY_LEECH_SCENE_PATH := "res://Nodes/gravity_leech.tscn"

@export var mass = 90000.0
@export var distortion_mass = 320000.0
@export var move_speed = 230.0
@export var max_speed = 380.0
@export var max_health = 72.0
@export var distortion_radius = 260.0
@export var shield_drain = 18.0
@export var drain_interval = 0.9
@export var gravity_refresh_interval = 0.5

@export_group("Subtle Mating")
@export var mating_enabled: bool = true
@export var mating_radius: float = 86.0
@export var mating_contact_seconds: float = 0.78
@export var mating_scan_interval: float = 0.24
@export var mating_cooldown: float = 15.0
@export var mating_population_cap: int = 10
@export var baby_maturity_seconds: float = 18.0
@export var baby_generation_limit: int = 2
@export var baby_scale: float = 0.42
@export var baby_birth_impulse: float = 115.0

var _base_mass = 0.0
var _player: Node2D = null
var _health: HealthComponent = null
var _drain_timer: Timer
var _gravity_sources: Array[Node2D] = []
var _gravity_refresh_elapsed = 0.0
var _mating_scan_elapsed = 999.0
var _mating_cooldown_remaining = 0.0
var _mating_contact_ids: Dictionary = {}
var _is_gravity_baby = false
var _generation = 0
var _maturity_elapsed = 0.0
var _birth_velocity: Vector2 = Vector2.ZERO
var _mating_query: Array[Node2D] = []

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("Objects_With_Gravity")
	add_to_group("planets")
	add_to_group("gravity_leeches")
	if RuntimeRegistry != null:
		RuntimeRegistry.register_node(self, &"enemies")
		RuntimeRegistry.register_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.register_node(self, &"planets")
		RuntimeRegistry.register_node(self, &"gravity_leeches")
	_base_mass = mass
	_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
	_build_body()
	_build_health()
	_build_timer()
	_refresh_gravity_sources()
	if _birth_velocity.length_squared() > 0.001:
		velocity = _birth_velocity

func _exit_tree() -> void:
	if RuntimeRegistry != null:
		RuntimeRegistry.unregister_node(self, &"enemies")
		RuntimeRegistry.unregister_node(self, &"Objects_With_Gravity")
		RuntimeRegistry.unregister_node(self, &"planets")
		RuntimeRegistry.unregister_node(self, &"gravity_leeches")

func _physics_process(delta: float) -> void:
	var scaled_delta = delta * CombatStatus.get_time_scale(self)
	_gravity_refresh_elapsed += delta
	_mating_cooldown_remaining = maxf(_mating_cooldown_remaining - scaled_delta, 0.0)
	if _gravity_refresh_elapsed >= gravity_refresh_interval:
		_refresh_gravity_sources()

	var target = _get_nearest_gravity_source()
	if target == null:
		target = _player

	if target != null and is_instance_valid(target):
		var desired = (target.global_position - global_position).normalized() * move_speed
		velocity = velocity.lerp(desired, clampf(scaled_delta * 2.0, 0.0, 1.0)).limit_length(max_speed)

	move_and_slide()
	_update_mating(scaled_delta)
	_update_distortion()

func configure_as_gravity_baby(parent_generation: int, inherited_velocity: Vector2) -> void:
	_is_gravity_baby = true
	_generation = parent_generation + 1
	_maturity_elapsed = 0.0
	var scale_factor := clampf(baby_scale * randf_range(0.88, 1.12), 0.24, 0.68)
	scale = Vector2.ONE * scale_factor
	mass *= 0.34
	distortion_mass *= 0.34
	move_speed *= 0.74
	max_speed *= 0.78
	max_health *= 0.38
	distortion_radius *= 0.58
	shield_drain *= 0.34
	drain_interval *= 1.28
	_birth_velocity = inherited_velocity

func take_damage(amount: float) -> void:
	if _health != null:
		_health.take_damage(amount)

func can_gravity_leech_mate() -> bool:
	return _can_mate()

func gravity_leech_generation() -> int:
	return _generation

func receive_gravity_leech_mating_cooldown(cooldown: float) -> void:
	_mating_cooldown_remaining = maxf(_mating_cooldown_remaining, cooldown)
	_mating_contact_ids.clear()

func _update_distortion() -> void:
	mass = _base_mass
	if _player == null or not is_instance_valid(_player):
		_player = MultiplayerTargeting.nearest_player(global_position, get_tree())
		return

	var distance = global_position.distance_to(_player.global_position)
	if distance <= distortion_radius:
		mass = distortion_mass
		if _player.has_method("apply_shield_disruption"):
			_player.call("apply_shield_disruption", 0.42, 0.32)

func _update_mating(delta: float) -> void:
	if not mating_enabled:
		return
	if _is_gravity_baby:
		_maturity_elapsed += delta
	if not _can_mate():
		_mating_contact_ids.clear()
		return
	_mating_scan_elapsed += delta
	if _mating_scan_elapsed < maxf(mating_scan_interval, 0.05):
		return
	var scan_delta = _mating_scan_elapsed
	_mating_scan_elapsed = 0.0
	_decay_mating_contacts(scan_delta)
	var mate := _find_mating_partner()
	if mate == null:
		return
	var mate_id := mate.get_instance_id()
	_mating_contact_ids[mate_id] = float(_mating_contact_ids.get(mate_id, 0.0)) + scan_delta
	if float(_mating_contact_ids[mate_id]) < mating_contact_seconds:
		return
	if get_instance_id() > mate_id:
		return
	_spawn_gravity_baby(mate)


func _can_mate() -> bool:
	if not is_inside_tree() or is_queued_for_deletion():
		return false
	if not mating_enabled or _mating_cooldown_remaining > 0.0:
		return false
	if _generation >= baby_generation_limit:
		return false
	if _is_gravity_baby and _maturity_elapsed < baby_maturity_seconds:
		return false
	if _gravity_leech_population() >= mating_population_cap:
		return false
	if _health != null and _health.has_method("is_dead") and bool(_health.call("is_dead")):
		return false
	return true


func _decay_mating_contacts(scan_delta: float) -> void:
	for key in _mating_contact_ids.keys():
		var remaining := maxf(float(_mating_contact_ids[key]) - scan_delta * 0.55, 0.0)
		if remaining <= 0.01:
			_mating_contact_ids.erase(key)
		else:
			_mating_contact_ids[key] = remaining


func _find_mating_partner() -> Node2D:
	var best: Node2D = null
	var best_distance := mating_radius * mating_radius
	_mating_query.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius([&"gravity_leeches"], global_position, mating_radius, mating_population_cap + 2, false, _mating_query)
	else:
		for node in get_tree().get_nodes_in_group("gravity_leeches"):
			var candidate := node as Node2D
			if candidate != null:
				_mating_query.append(candidate)
	for candidate in _mating_query:
		if candidate == null or candidate == self or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if not candidate.has_method("can_gravity_leech_mate") or not bool(candidate.call("can_gravity_leech_mate")):
			continue
		var distance := candidate.global_position.distance_squared_to(global_position)
		if distance > best_distance:
			continue
		best_distance = distance
		best = candidate
	return best


func _spawn_gravity_baby(mate: Node2D) -> void:
	if mate == null or not is_instance_valid(mate):
		return
	if _gravity_leech_population() >= mating_population_cap:
		return
	var scene := ResourceLoader.load(GRAVITY_LEECH_SCENE_PATH) as PackedScene
	if scene == null:
		return
	var baby := scene.instantiate() as Node2D
	if baby == null:
		return
	var midpoint := (global_position + mate.global_position) * 0.5
	var separation := mate.global_position - global_position
	var outward := separation.orthogonal()
	if outward.length_squared() <= 0.001:
		outward = Vector2.RIGHT.rotated(randf() * TAU)
	outward = outward.normalized()
	var inherited_velocity := (velocity + _body_velocity(mate)) * 0.5 + outward * baby_birth_impulse
	if baby.has_method("configure_as_gravity_baby"):
		var mate_generation := int(mate.call("gravity_leech_generation")) if mate.has_method("gravity_leech_generation") else 0
		baby.call("configure_as_gravity_baby", maxi(_generation, mate_generation), inherited_velocity)
	baby.name = "TinyGravityLeech"
	baby.global_position = midpoint + outward * 18.0
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	parent.add_child(baby)
	baby.global_position = midpoint + outward * 18.0
	if is_in_group("wave_enemy") or mate.is_in_group("wave_enemy"):
		baby.add_to_group("wave_enemy")
		if RuntimeRegistry != null:
			RuntimeRegistry.register_node(baby, &"wave_enemy")
		_register_baby_with_wave_director(baby)
	_mating_cooldown_remaining = mating_cooldown
	_mating_contact_ids.clear()
	if mate.has_method("receive_gravity_leech_mating_cooldown"):
		mate.call("receive_gravity_leech_mating_cooldown", mating_cooldown)
	_spawn_birth_glimmer(baby.global_position)
	tiny_gravity_baby_born.emit(self, mate, baby)


func _register_baby_with_wave_director(baby: Node) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var wave_director := root.find_child("WaveDirector", true, false)
	if wave_director != null and wave_director.has_method("register_external_enemy"):
		wave_director.call("register_external_enemy", baby)


func _spawn_birth_glimmer(position: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var ring := Line2D.new()
	ring.name = "TinyGravityBirthGlimmer"
	ring.closed = true
	ring.antialiased = true
	ring.width = 1.25
	ring.points = _circle_points(24, 18.0)
	ring.default_color = Color(0.42, 0.84, 1.0, _subtle_alpha(0.26, 0.18))
	ring.global_position = position
	ring.z_index = 22
	parent.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.7, 0.46)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.46)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(ring))


func _queue_free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()


func _gravity_leech_population() -> int:
	if RuntimeRegistry != null:
		return RuntimeRegistry.get_count(&"gravity_leeches")
	var count := 0
	for node in get_tree().get_nodes_in_group("gravity_leeches"):
		var leech := node as Node
		if leech != null and is_instance_valid(leech) and not leech.is_queued_for_deletion():
			count += 1
	return count


func _body_velocity(body: Node) -> Vector2:
	if body == null or not is_instance_valid(body):
		return Vector2.ZERO
	var value: Variant = body.get("velocity")
	if value is Vector2:
		return value
	return Vector2.ZERO


func _subtle_alpha(alpha: float, cap: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, cap)
	return minf(alpha, cap)

func _build_body() -> void:
	var core := get_node_or_null("GravityLeechPolygon") as Polygon2D
	if core == null:
		core = Polygon2D.new()
		core.name = "GravityLeechPolygon"
		core.color = Color(0.16, 0.46, 1.0, 1.0)
		add_child(core)
	if core.polygon.is_empty():
		core.polygon = PackedVector2Array([
			Vector2(38.0, 0.0),
			Vector2(10.0, 24.0),
			Vector2(-30.0, 16.0),
			Vector2(-42.0, 0.0),
			Vector2(-30.0, -16.0),
			Vector2(10.0, -24.0),
		])

	var field := get_node_or_null("DistortionFieldPolygon") as Polygon2D
	if field == null:
		field = Polygon2D.new()
		field.name = "DistortionFieldPolygon"
		field.z_index = -1
		field.color = Color(0.16, 0.46, 1.0, 0.12)
		add_child(field)
	if field.polygon.is_empty():
		field.polygon = _circle_points(28, 72.0)

	if not has_node("CollisionPolygon2D"):
		var collision = CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = core.polygon
		add_child(collision)

	var drain_area := get_node_or_null("DrainArea") as Area2D
	if drain_area == null:
		drain_area = Area2D.new()
		drain_area.name = "DrainArea"
		add_child(drain_area)
	drain_area.monitoring = true
	if not drain_area.body_entered.is_connected(_on_drain_area_body_entered):
		drain_area.body_entered.connect(_on_drain_area_body_entered)
	if not drain_area.body_exited.is_connected(_on_drain_area_body_exited):
		drain_area.body_exited.connect(_on_drain_area_body_exited)

	var drain_shape := drain_area.get_node_or_null("DrainShape") as CollisionShape2D
	if drain_shape == null:
		drain_shape = CollisionShape2D.new()
		drain_shape.name = "DrainShape"
		drain_area.add_child(drain_shape)
	if drain_shape.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = 52.0
		drain_shape.shape = circle

func _build_health() -> void:
	_health = get_node_or_null("HealthComponent") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "HealthComponent"
		add_child(_health)
	_health.max_health = max_health
	if not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)

func _build_timer() -> void:
	_drain_timer = Timer.new()
	_drain_timer.name = "ShieldDrainTimer"
	_drain_timer.wait_time = drain_interval
	_drain_timer.timeout.connect(_drain_player_shield)
	add_child(_drain_timer)

func _drain_player_shield() -> void:
	if _player == null or not is_instance_valid(_player):
		_drain_timer.stop()
		return

	var overflow = CombatStatus.damage_shield_only(_player, shield_drain)
	if overflow >= shield_drain and _player.has_method("take_damage"):
		_player.take_damage(8.0)

func _get_nearest_gravity_source() -> Node2D:
	var best: Node2D = null
	var best_distance = INF
	for source in _gravity_sources:
		if not is_instance_valid(source):
			continue
		var distance = global_position.distance_squared_to(source.global_position)
		if distance < best_distance:
			best_distance = distance
			best = source
	return best

func _refresh_gravity_sources() -> void:
	_gravity_refresh_elapsed = 0.0
	_gravity_sources.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(global_position, _gravity_sources, 4, 0.0, self)
		return
	var seen = {}
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for source in get_tree().get_nodes_in_group(group_name):
			if source == null or not is_instance_valid(source):
				continue
			var source_2d = source as Node2D
			if source_2d == null or source_2d == self or source_2d.is_queued_for_deletion():
				continue
			var id = source_2d.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_gravity_sources.append(source_2d)
	if _gravity_sources.size() > 4:
		_gravity_sources.resize(4)

func _on_drain_area_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player = body as Node2D
		_drain_timer.start()
		_drain_player_shield()

func _on_drain_area_body_exited(body: Node) -> void:
	if body == _player:
		_drain_timer.stop()

func _on_died() -> void:
	PowerupLibrary.try_spawn_drop(get_parent(), global_position, 0.12)
	queue_free()

func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
