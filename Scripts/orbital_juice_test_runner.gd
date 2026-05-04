extends SceneTree

# Headless smoke tests for the modular contributor additions. Run with:
# godot_console.exe --headless --path <project> --script res://Scripts/orbital_juice_test_runner.gd

const SCENES_TO_INSTANTIATE := [
	"res://Nodes/orbital_hud.tscn",
	"res://Nodes/player_thruster_trails.tscn",
	"res://Nodes/player_engine_hum.tscn",
	"res://Nodes/player_damage_camera_shake.tscn",
	"res://Nodes/projectile_spark_watcher.tscn",
	"res://Nodes/collision_sparks.tscn",
	"res://Nodes/planet_atmosphere_dust.tscn",
	"res://Nodes/unstable_moon.tscn",
	"res://Nodes/nebula_cloud.tscn",
	"res://Nodes/wormhole_pair.tscn",
	"res://Nodes/leech_parasite.tscn",
	"res://Nodes/splitting_asteroid_bot.tscn",
	"res://Nodes/gravity_harasser.tscn",
	"res://Nodes/sniper_turret.tscn",
	"res://Nodes/shielder_support.tscn",
	"res://Nodes/gravity_warden_boss.tscn",
	"res://Nodes/wave_director.tscn",
]

func _initialize() -> void:
	var failed := false

	for scene_path in SCENES_TO_INSTANTIATE:
		if not ResourceLoader.exists(scene_path):
			push_error("Scene path does not exist: %s" % scene_path)
			failed = true
			continue

		var packed := load(scene_path)
		if packed == null:
			push_error("Could not load %s" % scene_path)
			failed = true
			continue

	if failed:
		quit(1)
	else:
		print("Orbital juice smoke tests passed: %d scenes loaded." % SCENES_TO_INSTANTIATE.size())
		quit(0)
