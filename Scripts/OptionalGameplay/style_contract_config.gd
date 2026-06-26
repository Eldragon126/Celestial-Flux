extends Resource
class_name StyleContractConfig

enum ContractType {
	NONE,
	NO_DASH,
	PERFECT_ORBIT,
	PACIFIST,
	GLASS,
	SPEED,
	NO_THRUST,
	CLEAN_VECTOR,
}

@export var contract_id: StringName = &"no_dash"
@export var display_name: String = "NO DASH CONTRACT"
@export_multiline var description: String = "Clear without using dash or planet boost."
@export var contract_type: ContractType = ContractType.NO_DASH
@export var bonus_shards: int = 1
@export var failure_fails_rift: bool = false
@export var time_limit_seconds: float = 30.0
@export var required_orbit_chain: int = 1
@export var allow_one_warning: bool = false


func get_summary() -> Dictionary:
	return {
		"id": String(contract_id),
		"name": display_name,
		"description": description,
		"type": contract_type,
		"bonus_shards": bonus_shards,
		"failure_fails_rift": failure_fails_rift,
	}
