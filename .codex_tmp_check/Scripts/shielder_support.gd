extends CharacterBody2D

# Enemy variant: orbits a shooter and spends its own shield health to undo
# incoming damage on that host until the support is destroyed.

@export var orbit_radius = 150.0
@export var orbit_speed = 1.35
@export var follow_strength = 4.8
@export var shield_pool = 90.0
@export var max_health = 38.0

var _host: Node2D = null
var _host_health: HealthComponent = null
var _host_last_health = 0.0
var _protecting = false
var _orbit_angle = 0.0
var _health: HealthComponent = null
var _shield_polygon: Polygon2D

func _ready() -> void:
    add_to_group("enemies")
    _build_body()
    _build_health()
    call_deferred("_find_and_bind_host")

func _physics_process(delta: float) -> void:
    if _host == null or not is_instance_valid(_host):
        _find_and_bind_host()
        return

    _orbit_angle += orbit_speed * delta
    var target = _host.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
    velocity = (target - global_position) * follow_strength
    move_and_slide()

func take_damage(amount: float) -> void:
    if _health != null:
        _health.take_damage(amount)

func _build_body() -> void:
    _shield_polygon = get_node_or_null("SupportShieldHexPolygon") as Polygon2D
    if _shield_polygon == null:
        _shield_polygon = Polygon2D.new()
        _shield_polygon.name = "SupportShieldHexPolygon"
        _shield_polygon.z_index = -1
        _shield_polygon.color = Color(0.0, 0.82, 1.0, 0.28)
        add_child(_shield_polygon)
    if _shield_polygon.polygon.is_empty():
        _shield_polygon.polygon = _hex_points(62.0)

    var core := get_node_or_null("SupportCorePolygon") as Polygon2D
    if core == null:
        core = Polygon2D.new()
        core.name = "SupportCorePolygon"
        core.color = Color(0.12, 0.72, 1.0, 1.0)
        add_child(core)
    if core.polygon.is_empty():
        core.polygon = PackedVector2Array([
            Vector2(0.0, -24.0),
            Vector2(24.0, 0.0),
            Vector2(0.0, 24.0),
            Vector2(-24.0, 0.0),
        ])

    if not has_node("CollisionPolygon2D"):
        var collision = CollisionPolygon2D.new()
        collision.name = "CollisionPolygon2D"
        collision.polygon = _shield_polygon.polygon
        add_child(collision)

    var particles := get_node_or_null("ShieldOrbitParticles") as GPUParticles2D
    if particles == null:
        particles = GPUParticles2D.new()
        particles.name = "ShieldOrbitParticles"
        particles.z_index = -2
        particles.amount = 90
        particles.lifetime = 1.4
        particles.randomness = 0.5
        add_child(particles)
    if particles.process_material == null:
        particles.process_material = _make_shield_material()

func _build_health() -> void:
    _health = get_node_or_null("HealthComponent") as HealthComponent
    if _health == null:
        _health = HealthComponent.new()
        _health.name = "HealthComponent"
        add_child(_health)
    _health.max_health = max_health
    if not _health.died.is_connected(_on_died):
        _health.died.connect(_on_died)

func _find_and_bind_host() -> void:
    var next_host = _find_best_shooter_host(get_tree().current_scene)
    if next_host == null:
        return

    _host = next_host
    _host_health = _host.get_node_or_null("HealthComponent")
    if _host_health != null:
        _host_last_health = float(_host_health.get("current_health"))
        if not _host_health.health_changed.is_connected(_on_host_health_changed):
            _host_health.health_changed.connect(_on_host_health_changed)

func _on_host_health_changed(current_health: float, _max_health: float) -> void:
    if _protecting:
        _host_last_health = current_health
        return

    if current_health >= _host_last_health or shield_pool <= 0.0 or _host_health == null:
        _host_last_health = current_health
        return

    var incoming_damage = _host_last_health - current_health
    var blocked = minf(incoming_damage, shield_pool)
    shield_pool -= blocked

    if blocked > 0.0:
        _protecting = true
        _host_health.heal(blocked)
        _protecting = false
        _pulse_shield()

    _host_last_health = float(_host_health.get("current_health"))

    if shield_pool <= 0.0:
        _break_shield()

func _pulse_shield() -> void:
    if _shield_polygon == null:
        return

    var tween = create_tween()
    tween.tween_property(_shield_polygon, "scale", Vector2(1.18, 1.18), 0.08)
    tween.parallel().tween_property(_shield_polygon, "color:a", 0.62, 0.08)
    tween.tween_property(_shield_polygon, "scale", Vector2.ONE, 0.22)
    tween.parallel().tween_property(_shield_polygon, "color:a", 0.28, 0.22)

func _break_shield() -> void:
    if _shield_polygon != null:
        _shield_polygon.color = Color(0.0, 0.82, 1.0, 0.08)
    queue_free()

func _on_died() -> void:
    _break_shield()

func _find_best_shooter_host(root: Node) -> Node2D:
    var candidates: Array[Node2D] = []
    _collect_shooter_hosts(root, candidates)

    var best_host: Node2D = null
    var best_score = INF

    for candidate in candidates:
        var distance = global_position.distance_to(candidate.global_position)
        var wave_bonus = 0.0 if candidate.is_in_group("wave_enemy") else 100000.0
        var score = distance + wave_bonus

        if score < best_score:
            best_score = score
            best_host = candidate

    return best_host

func _collect_shooter_hosts(root: Node, candidates: Array[Node2D]) -> void:
    if root == null:
        return

    if root is Node2D and root != self and (root.name.begins_with("BaseShooterEnemy") or root.scene_file_path.ends_with("base_shooter_enemy.tscn")):
        candidates.append(root)

    for child in root.get_children():
        _collect_shooter_hosts(child, candidates)

func _make_shield_material() -> ParticleProcessMaterial:
    var material = ParticleProcessMaterial.new()
    material.particle_flag_disable_z = true
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    material.emission_sphere_radius = 66.0
    material.spread = 180.0
    material.initial_velocity_min = 10.0
    material.initial_velocity_max = 55.0
    material.orbit_velocity_min = 0.35
    material.orbit_velocity_max = 1.1
    material.gravity = Vector3.ZERO
    material.scale_min = 1.2
    material.scale_max = 4.0
    material.color = Color(0.0, 0.88, 1.0, 0.74)
    return material

func _hex_points(radius: float) -> PackedVector2Array:
    var points = PackedVector2Array()
    for i in range(6):
        var angle = TAU * float(i) / 6.0
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points
