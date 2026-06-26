extends Resource
class_name AnomalyRiftConfig

enum RiftRule {
	NO_THRUST,
	ONE_DASH,
	INVERTED_ORBIT,
	PERSONAL_GRAVITY_FLIP,
	TIME_SCAR,
	BLACKBOX_REPLAY,
	CUSTOM,
}

@export var rift_id: StringName = &"no_thrust_rift"
@export var display_name: String = "NO-THRUST RIFT"
@export_multiline var description: String = "Slingshot through gravity wells without normal thrust."
@export_multiline var instruction_text: String = "THRUST LOCKED // READ THE FIELD"
@export var rule: RiftRule = RiftRule.NO_THRUST
@export var duration_seconds: float = 42.0
@export var clear_radius: float = 78.0
@export var failure_radius: float = 0.0
@export var reward_shards: int = 1
@export var blackbox_unlock_id: StringName = &""

@export_group("Movement Rules")
@export var disable_normal_thrust: bool = false
@export var one_dash_only: bool = false
@export var inverted_orbit_for_player: bool = false
@export var enable_personal_gravity_flip: bool = false
@export_enum("Polarity", "Orbit", "Anchor", "Axis") var gravity_flip_mode: int = 0
@export var time_scar_trail_enabled: bool = false
@export var ghost_echo_required: bool = false

@export_group("Arena Layout")
@export var player_spawn: Vector2 = Vector2.ZERO
@export var exit_position: Vector2 = Vector2(1280.0, 0.0)
@export var gravity_well_positions: PackedVector2Array = PackedVector2Array([Vector2(-420.0, -180.0), Vector2(180.0, 260.0), Vector2(760.0, -180.0)])
@export var shard_positions: PackedVector2Array = PackedVector2Array([Vector2(620.0, -42.0)])
@export var door_positions: PackedVector2Array = PackedVector2Array([Vector2(980.0, 0.0)])
@export var tunnel_positions: PackedVector2Array = PackedVector2Array([])
@export var tape_positions: PackedVector2Array = PackedVector2Array([])

@export_group("Thresholds")
@export var required_speed: float = 780.0
@export var required_orbit_seconds: float = 1.2
@export var required_slingshot_score: float = 0.78
@export var retry_delay: float = 0.22


func get_summary() -> Dictionary:
	return {
		"id": String(rift_id),
		"name": display_name,
		"description": description,
		"duration": duration_seconds,
		"reward_shards": reward_shards,
		"blackbox_unlock": String(blackbox_unlock_id),
		"rule": rule,
	}


func apply_rule_defaults() -> void:
	disable_normal_thrust = rule == RiftRule.NO_THRUST
	one_dash_only = rule == RiftRule.ONE_DASH
	inverted_orbit_for_player = rule == RiftRule.INVERTED_ORBIT
	enable_personal_gravity_flip = rule == RiftRule.PERSONAL_GRAVITY_FLIP
	time_scar_trail_enabled = rule == RiftRule.TIME_SCAR
