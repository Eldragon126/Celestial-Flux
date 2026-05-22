extends Resource
class_name PowerupDefinition

enum StackPolicy {
	STACKABLE,
	MUTUALLY_EXCLUSIVE,
	REFRESH_DURATION,
}

@export var powerup_id: StringName
@export var display_name: String = "Powerup"
@export var effect_type: StringName
@export var stack_policy: StackPolicy = StackPolicy.STACKABLE
@export var max_stacks: int = 1
@export var duration: float = 0.0
@export var amount: float = 0.0
@export var secondary_amount: float = 0.0
@export var radius: float = 0.0
@export var color: Color = Color(0.0, 0.9, 1.0, 1.0)
