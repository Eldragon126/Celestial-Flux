extends SceneTree

const SCRIPTS := [
	"res://Scripts/run_progress.gd",
	"res://Scripts/run_director.gd",
	"res://Scripts/rupture_director.gd",
	"res://Scripts/music_finale_director.gd",
	"res://Scripts/credits_sequence.gd",
	"res://Scripts/player_visual_state.gd",
	"res://Scripts/wave_director.gd",
	"res://Scripts/pause_menu.gd",
	"res://Scripts/powerup_inventory.gd",
	"res://Scripts/vector_anomaly_director.gd",
	"res://Scripts/vector_runtime_registry.gd",
	"res://Scripts/orbital_vfx_director.gd",
	"res://Scripts/production_simulation_runner.gd",
	"res://Scripts/gravimetric_echo_drone.gd",
	"res://Scripts/event_horizon_warden.gd",
	"res://Scripts/phase_slip_swarm.gd",
	"res://Scripts/orbital_null_harvester.gd",
	"res://Scripts/resonance_paralytic_construct.gd",
	"res://Scripts/black_hole.gd",
	"res://Scripts/weapon_system.gd",
]

func _init() -> void:
	var failed := 0
	for path in SCRIPTS:
		var s: Variant = load(path)
		if s == null:
			push_error("FAIL load: %s" % path)
			failed += 1
		else:
			print("OK: ", path)
	print("failed=", failed)
	quit(failed)
