extends Node

# Camera add-on that listens to the player's HealthComponent and shakes the
# existing Camera2D after damage. It layers on top of player.gd camera offsets.

@export var trauma_decay = 1.8
@export var max_offset = 22.0
@export var max_roll = 0.035

var _camera: Camera2D = null
var _player: Node = null
var _last_health = 0.0
var _trauma = 0.0
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
    _camera = get_parent() as Camera2D
    _player = get_tree().get_first_node_in_group("Player")
    _rng.randomize()

    var health_component = _player.get_node_or_null("HealthComponent") if _player != null else null
    if health_component != null:
        _last_health = float(health_component.get("current_health"))
        health_component.health_changed.connect(_on_player_health_changed)

func _process(delta: float) -> void:
    if _camera == null:
        return

    if _trauma <= 0.0:
        return

    var shake_scale := Settings.screen_shake_scale if Settings != null else 1.0
    if shake_scale <= 0.001:
        _trauma = 0.0
        return

    var shake = _trauma * _trauma
    _camera.offset += Vector2(
        _rng.randf_range(-1.0, 1.0),
        _rng.randf_range(-1.0, 1.0)
    ) * max_offset * shake * shake_scale
    _camera.rotation += _rng.randf_range(-max_roll, max_roll) * shake * shake_scale
    _trauma = maxf(_trauma - trauma_decay * delta, 0.0)

func _on_player_health_changed(current_health: float, _max_health: float) -> void:
    if current_health < _last_health:
        var damage = _last_health - current_health
        _trauma = clampf(_trauma + damage / 45.0, 0.0, 1.0)

    _last_health = current_health
