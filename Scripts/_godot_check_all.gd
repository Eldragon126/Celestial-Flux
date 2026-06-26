extends SceneTree

const SCRIPTS := [
	"res://Scripts/run_progress.gd",
	"res://Scripts/gravity_ghost_recorder.gd",
	"res://Scripts/gravity_ghost_replay_panel.gd",
	"res://Scripts/game_over_scene.gd",
	"res://Scripts/orbital_hud.gd",
	"res://Scripts/vector_hud_glyph.gd",
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
	"res://Scripts/projectile.gd",
	"res://Scripts/network_session.gd",
	"res://Scripts/mod_content_registry.gd",
	"res://Scripts/multiplayer_targeting.gd",
	"res://Scripts/coop_combo_director.gd",
	"res://Scripts/mechanic_audio_director.gd",
	"res://Scripts/campaign_mode_director.gd",
	"res://Scripts/campaign_escort_ship.gd",
	"res://Scripts/campaign_invader.gd",
	"res://Scripts/campaign_mother_planet.gd",
	"res://Scripts/campaign_mothership.gd",
	"res://Scripts/campaign_dock_scene.gd",
	"res://Scripts/OptionalGameplay/anomaly_rift_config.gd",
	"res://Scripts/OptionalGameplay/style_contract_config.gd",
	"res://Scripts/OptionalGameplay/optional_challenge_director.gd",
	"res://Scripts/OptionalGameplay/personal_gravity_flip_component.gd",
	"res://Scripts/OptionalGameplay/style_contract_tracker.gd",
	"res://Scripts/OptionalGameplay/anomaly_ghost_echo.gd",
	"res://Scripts/OptionalGameplay/anomaly_shard.gd",
	"res://Scripts/OptionalGameplay/blackbox_tape.gd",
	"res://Scripts/OptionalGameplay/anomaly_rift_portal.gd",
	"res://Scripts/OptionalGameplay/momentum_door.gd",
	"res://Scripts/OptionalGameplay/vector_tunnel.gd",
	"res://Scripts/OptionalGameplay/secret_movement_tech_detector.gd",
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
