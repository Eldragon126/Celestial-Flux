extends SceneTree

const SCRIPTS := [
	"res://Scripts/gravity_scar_manager.gd",
	"res://Scripts/event_horizon_director.gd",
	"res://Scripts/orbital_trajectory_predictor.gd",
]

func _init() -> void:
	var failed := 0
	for path in SCRIPTS:
		var script_value: Variant = load(path)
		if script_value == null:
			push_error("FAIL load: %s" % path)
			failed += 1
		else:
			print("OK: ", path)
	print("failed=", failed)
	quit(failed)
