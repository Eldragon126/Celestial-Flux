extends StaticBody2D

@export var radius: float = 60.0
@export var pulsating_gravity_field: PackedScene = preload("res://Nodes/pulsating_gravity_field.tscn")
@export var min_spawn_interval: float = 5.0
@export var max_spawn_interval: float = 10.0
@export var max_active_fields: int = 2
@export var run_lifetime_seconds: float = 42.0
@export var core_color: Color = Color(0.04, 1.0, 1.0, 0.7)
@export var outer_wave_color: Color = Color(0.24, 0.72, 1.0, 0.8)
@export var charged_color: Color = Color(1.0, 0.78, 0.18, 0.9)
@export var glyph_spoke_count: int = 10
@export var wave_ring_count: int = 5
@export var wave_spread_multiplier: float = 2.35
@export var rotation_speed: float = 0.72
@export var light_base_energy: float = 0.55
@export var light_pulse_energy: float = 1.25
@export var visual_update_interval: float = 0.05
@export var visual_focus_radius: float = 2200.0
@export var far_visual_ring_count: int = 2
@export var far_glyph_spoke_count: int = 5

@onready var timer: Timer = $Timer
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var collision_polygon: CollisionPolygon2D = get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
@onready var polygon: Polygon2D = get_node_or_null("Polygon2D") as Polygon2D
@onready var point_light: PointLight2D = get_node_or_null("PointLight2D") as PointLight2D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer

# Tracks time to animate our waves
var time_passed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _active_fields: Array[Node] = []
var _lifetime_elapsed: float = 0.0
var _has_deterministic_seed: bool = false
var _visual_elapsed: float = 999.0
var _visual_in_focus: bool = true
var _visual_player: Node2D = null

func _ready() -> void:
	add_to_group("pulsating_gravity_spawner")
	add_to_group("run_hazard")
	if not _has_deterministic_seed:
		_rng.randomize()
	_setup_collision()
	if animation_player:
		animation_player.stop()
	
	if timer:
		timer.wait_time = _next_spawn_wait()
		timer.start()

func configure_deterministic(seed: int, _key: StringName = &"") -> void:
	_rng.seed = seed
	_has_deterministic_seed = true

# --- OPTIMIZATION & VISUALS ---

func _process(delta: float) -> void:
	time_passed += delta
	_lifetime_elapsed += delta
	if run_lifetime_seconds > 0.0 and _lifetime_elapsed >= run_lifetime_seconds:
		queue_free()
		return
	_visual_elapsed += delta
	if _visual_elapsed < maxf(visual_update_interval, 0.016):
		return
	_visual_elapsed = 0.0
	_visual_in_focus = _is_visual_in_focus()
	_update_visual_nodes()
	queue_redraw()

func _setup_collision() -> void:
	# Still using the highly optimized CircleShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius
	if collision_polygon:
		collision_polygon.polygon = _circle_points(24, radius)
	if polygon:
		polygon.polygon = _circle_points(32, radius * 0.72)
		polygon.color = core_color


func _update_visual_nodes() -> void:
	var charge := _spawn_charge()
	var pulse := 0.5 + 0.5 * sin(time_passed * 5.2)
	if polygon:
		polygon.visible = _visual_in_focus
		polygon.rotation = time_passed * rotation_speed
		polygon.scale = Vector2.ONE * lerpf(0.92, 1.16, maxf(charge, pulse * 0.45))
		polygon.color = core_color.lerp(charged_color, charge * 0.72)
	if point_light:
		point_light.visible = _visual_in_focus
		if not _visual_in_focus:
			return
		point_light.energy = light_base_energy + light_pulse_energy * maxf(charge * charge, pulse * 0.22)
		point_light.texture_scale = lerpf(0.62, 1.24, maxf(charge, pulse * 0.45))

func _draw() -> void:
	if not _visual_in_focus:
		return
	var charge := _spawn_charge()
	var pulse := 0.5 + 0.5 * sin(time_passed * 4.6)
	draw_circle(Vector2.ZERO, radius * 0.92, Color(core_color.r, core_color.g, core_color.b, 0.22 + 0.2 * pulse))
	draw_circle(Vector2.ZERO, radius * 0.38, Color(1.0, 1.0, 1.0, 0.24 + 0.2 * charge))
	
	_draw_rotating_glyphs(charge, pulse)
	
	var wave_spread: float = radius * wave_spread_multiplier
	var ring_count := maxi(far_visual_ring_count if not _visual_in_focus else wave_ring_count, 1)
	var arc_segments := 16 if not _visual_in_focus else 20
	for i in range(ring_count):
		var phase = fmod(time_passed * 0.42 + (float(i) / float(ring_count)), 1.0)
		var current_radius = radius + phase * wave_spread
		var wave_alpha = pow(1.0 - phase, 1.55)
		var wave_color = outer_wave_color.lerp(charged_color, charge * 0.55)
		wave_color.a *= wave_alpha
		var arc_offset := time_passed * rotation_speed * (1.0 if i % 2 == 0 else -0.72)
		for arc_index in range(3):
			var start = arc_offset + TAU * float(arc_index) / 3.0 + phase * 0.4
			var end = start + TAU * 0.22
			draw_arc(Vector2.ZERO, current_radius, start, end, arc_segments, wave_color, lerpf(1.8, 4.2, wave_alpha), true)
	if charge > 0.05:
		var warning := Color(charged_color.r, charged_color.g, charged_color.b, charge * charge * 0.72)
		draw_arc(Vector2.ZERO, radius * lerpf(1.05, 1.75, charge), 0.0, TAU, 36, warning, 3.8, true)


func _draw_rotating_glyphs(charge: float, pulse: float) -> void:
	var count := maxi(far_glyph_spoke_count if not _visual_in_focus else glyph_spoke_count, 3)
	var spin := time_passed * rotation_speed
	for i in range(count):
		var angle := spin + TAU * float(i) / float(count)
		var dir := Vector2(cos(angle), sin(angle))
		var side := dir.orthogonal()
		var inner := radius * lerpf(0.34, 0.48, pulse)
		var outer := radius * lerpf(1.02, 1.32, charge)
		var color := core_color.lerp(charged_color, charge)
		color.a = lerpf(0.32, 0.78, maxf(charge, pulse * 0.6))
		draw_line(dir * inner, dir * outer, color, lerpf(1.4, 3.2, charge), true)
		draw_line(dir * outer, dir * outer - dir * 12.0 + side * 7.0, color, 1.3, true)
		draw_line(dir * outer, dir * outer - dir * 12.0 - side * 7.0, color, 1.3, true)
		if i % 2 == 0:
			draw_circle(dir * radius * 0.78, lerpf(2.6, 5.8, charge), Color(1.0, 1.0, 1.0, 0.16 + 0.24 * pulse))

# --- LOGIC ---

func _on_timer_timeout() -> void:
	_prune_fields()
	if pulsating_gravity_field:
		if max_active_fields <= 0 or _active_fields.size() < max_active_fields:
			var inst = pulsating_gravity_field.instantiate()
			inst.global_position = global_position
			if inst.has_method("configure_deterministic"):
				inst.call("configure_deterministic", _rng.randi(), &"pulsating_field")
			_active_fields.append(inst)
			inst.tree_exited.connect(Callable(self, "_on_field_tree_exited").bind(inst), CONNECT_ONE_SHOT)
			get_tree().current_scene.call_deferred("add_child", inst)
	
	timer.wait_time = _next_spawn_wait()
	timer.start()


func _next_spawn_wait() -> float:
	return _rng.randf_range(min_spawn_interval, maxf(min_spawn_interval, max_spawn_interval))


func _spawn_charge() -> float:
	if timer == null or timer.wait_time <= 0.0 or timer.is_stopped():
		return 0.0
	return clampf(1.0 - timer.time_left / maxf(timer.wait_time, 0.001), 0.0, 1.0)


func _prune_fields() -> void:
	for index in range(_active_fields.size() - 1, -1, -1):
		var field := _active_fields[index]
		if field == null or not is_instance_valid(field) or field.is_queued_for_deletion():
			_active_fields.remove_at(index)


func _on_field_tree_exited(field: Node) -> void:
	_active_fields.erase(field)


func _is_visual_in_focus() -> bool:
	if visual_focus_radius <= 0.0:
		return true
	if _visual_player == null or not is_instance_valid(_visual_player):
		_visual_player = MultiplayerTargeting.local_player(get_tree())
	if _visual_player == null or not is_instance_valid(_visual_player):
		return true
	return global_position.distance_squared_to(_visual_player.global_position) <= visual_focus_radius * visual_focus_radius


func _circle_points(count: int, circle_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(count, 8)):
		var angle := TAU * float(i) / float(maxi(count, 8))
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points
