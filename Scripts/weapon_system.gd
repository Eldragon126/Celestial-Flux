extends Node2D
class_name WeaponSystem

signal weapon_changed(weapon_id: StringName, display_name: String, weapon_data: Dictionary)
signal weapon_fired(weapon_id: StringName, weapon_data: Dictionary)
signal weapon_energy_failed(weapon_id: StringName, required_energy: float, available_energy: float)
signal weapon_pool_changed(unlocked_count: int, total_count: int, newly_unlocked: Array[String])

const PROJECTILE_SCENE := preload("res://Nodes/projectile.tscn")
const WEAPON_IDS: Array[StringName] = [
	&"vector_bolt",
	&"harmonic_needle",
	&"relativistic_rail",
	&"barycentric_splitter",
	&"gravity_lance",
	&"temporal_splinter",
	&"inversion_disc",
	&"vacuum_collapse_seed",
	&"polarity_javelin",
	&"singularity_pin",
	&"tidal_mortar",
	&"mass_driver",
	&"positron_beam",
	&"gravity_wave_beam",
	&"chronal_refraction_beam",
	&"event_horizon_shard",
]
const WEAPON_NAMES := {
	&"vector_bolt": "Vector Bolt",
	&"relativistic_rail": "Relativistic Rail",
	&"barycentric_splitter": "Barycentric Splitter",
	&"vacuum_collapse_seed": "Vacuum Collapse Seed",
	&"temporal_splinter": "Temporal Splinter",
	&"inversion_disc": "Inversion Disc",
	&"harmonic_needle": "Harmonic Needle",
	&"shear_comet": "Shear Comet",
	&"singularity_pin": "Singularity Pin",
	&"event_horizon_shard": "Event Horizon Shard",
	&"gravity_lance": "Gravity Lance",
	&"orbit_saw": "Orbit Saw",
	&"tidal_mortar": "Tidal Mortar",
	&"chronal_mirror_shot": "Chronal Mirror Shot",
	&"polarity_javelin": "Polarity Javelin",
	&"lensing_flak": "Lensing Flak",
	&"rift_anchor": "Rift Anchor",
	&"apex_vector_spear": "Apex Vector Spear",
	&"phase_suture": "Phase Suture",
	&"null_rebounder": "Null Rebounder",
	&"graviton_bloom": "Graviton Bloom",
	&"causal_anchor": "Causal Anchor",
	&"vector_prism": "Vector Prism",
	&"mass_driver": "Mass Driver",
	&"tidal_skein": "Tidal Skein",
	&"scar_carver": "Scar Carver",
	&"chronal_needleloom": "Chronal Needleloom",
	&"singularity_kite": "Singularity Kite",
	&"inertia_maul": "Inertia Maul",
	&"harmonic_bloom": "Harmonic Bloom",
	&"singularity_bell": "Singularity Bell",
	&"gravity_loom": "Gravity Loom",
	&"orbital_lasso": "Orbital Lasso",
	&"kinetic_ram": "Kinetic Ram",
	&"temporal_bloom": "Temporal Bloom",
	&"phase_guillotine": "Phase Guillotine",
	&"event_horizon_veil": "Event Horizon Veil",
	&"mass_siphon": "Mass Siphon",
	&"inversion_chime": "Inversion Chime",
	&"resonance_anvil": "Resonance Anvil",
	&"positron_beam": "Positron Beam",
	&"gravity_wave_beam": "Gravity Wave Beam",
	&"chronal_refraction_beam": "Chronal Refraction Beam",
}
const WEAPON_UNLOCK_WAVES := {
	&"vector_bolt": 0,
	&"harmonic_needle": 0,
	&"relativistic_rail": 2,
	&"barycentric_splitter": 3,
	&"gravity_lance": 4,
	&"temporal_splinter": 5,
	&"orbit_saw": 4,
	&"inversion_disc": 6,
	&"lensing_flak": 6,
	&"chronal_mirror_shot": 6,
	&"vacuum_collapse_seed": 8,
	&"shear_comet": 8,
	&"polarity_javelin": 9,
	&"vector_prism": 8,
	&"singularity_pin": 10,
	&"tidal_skein": 10,
	&"phase_suture": 10,
	&"gravity_loom": 10,
	&"positron_beam": 14,
	&"tidal_mortar": 12,
	&"scar_carver": 12,
	&"mass_driver": 16,
	&"null_rebounder": 15,
	&"temporal_bloom": 15,
	&"orbital_lasso": 15,
	&"mass_siphon": 15,
	&"chronal_needleloom": 18,
	&"singularity_kite": 18,
	&"inversion_chime": 18,
	&"event_horizon_veil": 18,
	&"gravity_wave_beam": 18,
	&"rift_anchor": 22,
	&"graviton_bloom": 22,
	&"kinetic_ram": 22,
	&"phase_guillotine": 22,
	&"singularity_bell": 22,
	&"causal_anchor": 26,
	&"inertia_maul": 26,
	&"harmonic_bloom": 26,
	&"resonance_anvil": 26,
	&"chronal_refraction_beam": 22,
	&"event_horizon_shard": 28,
	&"apex_vector_spear": 30,
}
const EXTRA_WEAPON_DEFINITIONS := {
	&"gravity_lance": {
		"display_name": "Gravity Lance",
		"fire_mode": &"projectile",
		"energy_per_shot": 10.0,
		"fire_interval": 0.31,
		"speed": 1260.0,
		"damage_min": 30.0,
		"damage_max": 42.0,
		"gravity_constant": 135.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "piercing compression lance",
		"color": Color(0.46, 0.86, 1.0, 1.0),
		"trail_color": Color(0.08, 0.58, 1.0, 0.9),
		"visual_scale": 0.9,
		"payload": {
			"weapon_axis_impulse": 300.0,
			"weapon_pierce_count": 2,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.COMPRESSION,
			"weapon_resonance_radius": 150.0,
			"weapon_resonance_intensity": 0.42,
			"weapon_field_radius": 145.0,
			"weapon_field_force": -340.0,
			"weapon_field_damage": 9.0,
			"weapon_field_max_targets": 10,
			"weapon_scar_type": GravityScarManager.ScarType.CURVATURE,
			"weapon_scar_radius": 150.0,
			"weapon_scar_intensity": 0.34,
			"weapon_scar_duration": 18.0,
		},
	},
	&"orbit_saw": {
		"display_name": "Orbit Saw",
		"fire_mode": &"projectile",
		"energy_per_shot": 13.0,
		"fire_interval": 0.48,
		"speed": 780.0,
		"damage_min": 18.0,
		"damage_max": 27.0,
		"gravity_constant": 310.0,
		"shot_count": 3,
		"pattern": &"braid",
		"spread_radians": 0.16,
		"role": "braided harmonic cutters",
		"color": Color(0.82, 1.0, 0.36, 1.0),
		"trail_color": Color(0.38, 1.0, 0.54, 0.9),
		"visual_scale": 0.78,
		"payload": {
			"weapon_curve_force": 520.0,
			"weapon_curve_frequency": 10.8,
			"weapon_tangent_impulse": 240.0,
			"weapon_pierce_count": 1,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
			"weapon_resonance_radius": 135.0,
			"weapon_resonance_intensity": 0.43,
			"weapon_field_radius": 155.0,
			"weapon_field_force": 230.0,
			"weapon_field_max_targets": 12,
		},
	},
	&"tidal_mortar": {
		"display_name": "Tidal Mortar",
		"fire_mode": &"projectile",
		"energy_per_shot": 22.0,
		"fire_interval": 0.82,
		"speed": 560.0,
		"damage_min": 34.0,
		"damage_max": 49.0,
		"gravity_constant": 360.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "slow compression blast",
		"color": Color(0.12, 0.82, 1.0, 1.0),
		"trail_color": Color(0.0, 0.48, 1.0, 0.9),
		"visual_scale": 1.36,
		"payload": {
			"vacuum_collapse_stacks": 1,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.COMPRESSION,
			"weapon_resonance_radius": 270.0,
			"weapon_resonance_intensity": 0.58,
			"weapon_field_radius": 310.0,
			"weapon_field_force": -720.0,
			"weapon_field_damage": 18.0,
			"weapon_field_slow_multiplier": 0.78,
			"weapon_field_slow_duration": 0.28,
			"weapon_field_max_targets": 24,
			"weapon_planet_damage": 64.0,
			"weapon_scar_type": GravityScarManager.ScarType.CURVATURE,
			"weapon_scar_radius": 275.0,
			"weapon_scar_intensity": 0.52,
			"weapon_scar_duration": 28.0,
		},
	},
	&"chronal_mirror_shot": {
		"display_name": "Chronal Mirror Shot",
		"fire_mode": &"projectile",
		"energy_per_shot": 12.0,
		"fire_interval": 0.46,
		"speed": 880.0,
		"damage_min": 17.0,
		"damage_max": 25.0,
		"gravity_constant": 175.0,
		"shot_count": 2,
		"pattern": &"parallel",
		"spread_radians": 0.1,
		"role": "paired time desync shots",
		"color": Color(0.66, 0.58, 1.0, 1.0),
		"trail_color": Color(0.78, 0.36, 1.0, 0.88),
		"visual_scale": 0.74,
		"payload": {
			"weapon_temporal_slow_multiplier": 0.5,
			"weapon_temporal_slow_duration": 0.5,
			"weapon_pierce_count": 1,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
			"weapon_resonance_radius": 145.0,
			"weapon_resonance_intensity": 0.46,
			"weapon_curve_force": 240.0,
			"weapon_curve_frequency": 8.8,
			"weapon_field_radius": 175.0,
			"weapon_field_slow_multiplier": 0.62,
			"weapon_field_slow_duration": 0.34,
			"weapon_field_max_targets": 14,
			"weapon_scar_type": GravityScarManager.ScarType.TEMPORAL_RIP,
			"weapon_scar_radius": 145.0,
			"weapon_scar_intensity": 0.36,
			"weapon_scar_duration": 20.0,
		},
	},
	&"polarity_javelin": {
		"display_name": "Polarity Javelin",
		"fire_mode": &"projectile",
		"energy_per_shot": 15.0,
		"fire_interval": 0.52,
		"speed": 1120.0,
		"damage_min": 28.0,
		"damage_max": 40.0,
		"gravity_constant": 245.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "inversion spear",
		"color": Color(1.0, 0.5, 0.18, 1.0),
		"trail_color": Color(1.0, 0.24, 0.08, 0.9),
		"visual_scale": 1.04,
		"payload": {
			"weapon_radial_impulse": 520.0,
			"weapon_axis_impulse": 130.0,
			"weapon_pierce_count": 1,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.INVERSION,
			"weapon_resonance_radius": 240.0,
			"weapon_resonance_intensity": 0.56,
			"weapon_field_radius": 255.0,
			"weapon_field_force": 540.0,
			"weapon_field_damage": 12.0,
			"weapon_field_max_targets": 16,
			"weapon_scar_type": GravityScarManager.ScarType.INVERSION_WAKE,
			"weapon_scar_radius": 230.0,
			"weapon_scar_intensity": 0.46,
			"weapon_scar_duration": 24.0,
		},
	},
	&"lensing_flak": {
		"display_name": "Lensing Flak",
		"fire_mode": &"projectile",
		"energy_per_shot": 16.0,
		"fire_interval": 0.58,
		"speed": 820.0,
		"damage_min": 12.0,
		"damage_max": 19.0,
		"gravity_constant": 265.0,
		"shot_count": 5,
		"pattern": &"spread",
		"spread_radians": 0.24,
		"role": "micro-lensing flak fan",
		"color": Color(0.28, 1.0, 0.9, 1.0),
		"trail_color": Color(0.0, 0.92, 1.0, 0.86),
		"visual_scale": 0.62,
		"payload": {
			"weapon_curve_force": 150.0,
			"weapon_curve_frequency": 13.0,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.SLIPSTREAM,
			"weapon_resonance_radius": 95.0,
			"weapon_resonance_intensity": 0.28,
			"weapon_field_radius": 120.0,
			"weapon_field_force": -160.0,
			"weapon_field_damage": 5.0,
			"weapon_field_max_targets": 8,
		},
	},
	&"rift_anchor": {
		"display_name": "Rift Anchor",
		"fire_mode": &"projectile",
		"energy_per_shot": 28.0,
		"fire_interval": 0.9,
		"speed": 500.0,
		"damage_min": 32.0,
		"damage_max": 48.0,
		"gravity_constant": 430.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "harmonic fracture anchor",
		"color": Color(1.0, 0.82, 0.22, 1.0),
		"trail_color": Color(1.0, 0.58, 0.12, 0.92),
		"visual_scale": 1.28,
		"payload": {
			"vacuum_collapse_stacks": 1,
			"weapon_temporal_slow_multiplier": 0.64,
			"weapon_temporal_slow_duration": 0.32,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
			"weapon_resonance_radius": 300.0,
			"weapon_resonance_intensity": 0.62,
			"weapon_field_radius": 340.0,
			"weapon_field_force": -680.0,
			"weapon_field_damage": 20.0,
			"weapon_field_slow_multiplier": 0.72,
			"weapon_field_slow_duration": 0.38,
			"weapon_field_max_targets": 24,
			"weapon_scar_type": GravityScarManager.ScarType.HARMONIC_FRACTURE,
			"weapon_scar_radius": 310.0,
			"weapon_scar_intensity": 0.58,
			"weapon_scar_duration": 32.0,
		},
	},
	&"apex_vector_spear": {
		"display_name": "Apex Vector Spear",
		"fire_mode": &"projectile",
		"energy_per_shot": 26.0,
		"fire_interval": 0.74,
		"speed": 1480.0,
		"damage_min": 44.0,
		"damage_max": 62.0,
		"gravity_constant": 110.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "high-skill vector finisher",
		"color": Color(0.92, 1.0, 0.72, 1.0),
		"trail_color": Color(0.32, 0.76, 1.0, 0.95),
		"visual_scale": 1.12,
		"payload": {
			"relativistic_rail_stacks": 1,
			"weapon_axis_impulse": 420.0,
			"weapon_tangent_impulse": 360.0,
			"weapon_pierce_count": 3,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
			"weapon_resonance_radius": 185.0,
			"weapon_resonance_intensity": 0.5,
			"weapon_field_radius": 185.0,
			"weapon_field_force": 300.0,
			"weapon_field_damage": 12.0,
			"weapon_field_max_targets": 14,
			"weapon_scar_type": GravityScarManager.ScarType.VELOCITY_SHEAR,
			"weapon_scar_radius": 190.0,
			"weapon_scar_intensity": 0.44,
			"weapon_scar_duration": 22.0,
		},
	},
	&"phase_suture": {
		"display_name": "Phase Suture",
		"fire_mode": &"projectile",
		"energy_per_shot": 14.0,
		"fire_interval": 0.44,
		"speed": 940.0,
		"damage_min": 16.0,
		"damage_max": 24.0,
		"gravity_constant": 185.0,
		"shot_count": 2,
		"pattern": &"converge",
		"spread_radians": 0.13,
		"role": "converging temporal stitch",
		"color": Color(0.56, 0.62, 1.0, 1.0),
		"trail_color": Color(0.78, 0.44, 1.0, 0.86),
		"visual_scale": 0.72,
		"payload": {
			"weapon_temporal_slow_multiplier": 0.48,
			"weapon_temporal_slow_duration": 0.46,
			"weapon_pierce_count": 1,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
			"weapon_resonance_radius": 128.0,
			"weapon_resonance_intensity": 0.38,
			"weapon_field_radius": 160.0,
			"weapon_field_slow_multiplier": 0.6,
			"weapon_field_slow_duration": 0.3,
			"weapon_field_max_targets": 12,
			"weapon_scar_type": GravityScarManager.ScarType.TEMPORAL_RIP,
			"weapon_scar_radius": 130.0,
			"weapon_scar_intensity": 0.34,
			"weapon_scar_duration": 18.0,
		},
	},
	&"null_rebounder": {
		"display_name": "Null Rebounder",
		"fire_mode": &"projectile",
		"energy_per_shot": 18.0,
		"fire_interval": 0.58,
		"speed": 760.0,
		"damage_min": 14.0,
		"damage_max": 22.0,
		"gravity_constant": 330.0,
		"shot_count": 4,
		"pattern": &"scissor",
		"spread_radians": 0.18,
		"role": "crossing inversion rebounds",
		"color": Color(1.0, 0.54, 0.22, 1.0),
		"trail_color": Color(1.0, 0.24, 0.12, 0.88),
		"visual_scale": 0.76,
		"payload": {
			"weapon_radial_impulse": 380.0,
			"weapon_tangent_impulse": 210.0,
			"weapon_curve_force": 260.0,
			"weapon_curve_frequency": 11.0,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.INVERSION,
			"weapon_resonance_radius": 155.0,
			"weapon_resonance_intensity": 0.4,
			"weapon_field_radius": 180.0,
			"weapon_field_force": 410.0,
			"weapon_field_damage": 7.0,
			"weapon_field_max_targets": 12,
			"weapon_scar_type": GravityScarManager.ScarType.INVERSION_WAKE,
			"weapon_scar_radius": 165.0,
			"weapon_scar_intensity": 0.36,
			"weapon_scar_duration": 20.0,
		},
	},
	&"graviton_bloom": {
		"display_name": "Graviton Bloom",
		"fire_mode": &"projectile",
		"energy_per_shot": 25.0,
		"fire_interval": 0.86,
		"speed": 640.0,
		"damage_min": 13.0,
		"damage_max": 20.0,
		"gravity_constant": 390.0,
		"shot_count": 6,
		"pattern": &"pinwheel",
		"spread_radians": 0.34,
		"role": "rotating compression bloom",
		"color": Color(0.2, 0.92, 1.0, 1.0),
		"trail_color": Color(0.0, 0.58, 1.0, 0.86),
		"visual_scale": 0.7,
		"payload": {
			"vacuum_collapse_stacks": 1,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.COMPRESSION,
			"weapon_resonance_radius": 150.0,
			"weapon_resonance_intensity": 0.36,
			"weapon_field_radius": 190.0,
			"weapon_field_force": -420.0,
			"weapon_field_damage": 6.0,
			"weapon_field_max_targets": 14,
			"weapon_scar_type": GravityScarManager.ScarType.CURVATURE,
			"weapon_scar_radius": 165.0,
			"weapon_scar_intensity": 0.3,
			"weapon_scar_duration": 18.0,
		},
	},
	&"causal_anchor": {
		"display_name": "Causal Anchor",
		"fire_mode": &"projectile",
		"energy_per_shot": 24.0,
		"fire_interval": 0.78,
		"speed": 520.0,
		"damage_min": 25.0,
		"damage_max": 38.0,
		"gravity_constant": 420.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "delayed time anchor",
		"color": Color(0.68, 0.44, 1.0, 1.0),
		"trail_color": Color(0.86, 0.34, 1.0, 0.9),
		"visual_scale": 1.18,
		"payload": {
			"vacuum_collapse_stacks": 1,
			"weapon_temporal_slow_multiplier": 0.42,
			"weapon_temporal_slow_duration": 0.58,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
			"weapon_resonance_radius": 260.0,
			"weapon_resonance_intensity": 0.56,
			"weapon_field_radius": 300.0,
			"weapon_field_force": -360.0,
			"weapon_field_damage": 12.0,
			"weapon_field_slow_multiplier": 0.54,
			"weapon_field_slow_duration": 0.46,
			"weapon_field_max_targets": 22,
			"weapon_scar_type": GravityScarManager.ScarType.TEMPORAL_RIP,
			"weapon_scar_radius": 270.0,
			"weapon_scar_intensity": 0.52,
			"weapon_scar_duration": 30.0,
		},
	},
	&"vector_prism": {
		"display_name": "Vector Prism",
		"fire_mode": &"projectile",
		"energy_per_shot": 15.0,
		"fire_interval": 0.5,
		"speed": 980.0,
		"damage_min": 11.0,
		"damage_max": 18.0,
		"gravity_constant": 170.0,
		"shot_count": 5,
		"pattern": &"spread",
		"spread_radians": 0.16,
		"role": "refracted slipstream fan",
		"color": Color(0.38, 1.0, 0.86, 1.0),
		"trail_color": Color(0.18, 0.86, 1.0, 0.84),
		"visual_scale": 0.62,
		"payload": {
			"weapon_curve_force": 110.0,
			"weapon_curve_frequency": 14.0,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.SLIPSTREAM,
			"weapon_resonance_radius": 105.0,
			"weapon_resonance_intensity": 0.3,
			"weapon_field_radius": 110.0,
			"weapon_field_force": 170.0,
			"weapon_field_max_targets": 8,
			"weapon_scar_type": GravityScarManager.ScarType.VELOCITY_SHEAR,
			"weapon_scar_radius": 105.0,
			"weapon_scar_intensity": 0.22,
			"weapon_scar_duration": 14.0,
		},
	},
	&"mass_driver": {
		"display_name": "Mass Driver",
		"fire_mode": &"projectile",
		"energy_per_shot": 20.0,
		"fire_interval": 0.66,
		"speed": 1540.0,
		"damage_min": 46.0,
		"damage_max": 64.0,
		"gravity_constant": 92.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "heavy velocity punch",
		"color": Color(0.56, 0.92, 1.0, 1.0),
		"trail_color": Color(0.36, 0.66, 1.0, 0.94),
		"visual_scale": 1.08,
		"payload": {
			"relativistic_rail_stacks": 1,
			"weapon_axis_impulse": 620.0,
			"weapon_pierce_count": 1,
			"weapon_planet_damage": 86.0,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.SLIPSTREAM,
			"weapon_resonance_radius": 170.0,
			"weapon_resonance_intensity": 0.42,
			"weapon_scar_type": GravityScarManager.ScarType.VELOCITY_SHEAR,
			"weapon_scar_radius": 180.0,
			"weapon_scar_intensity": 0.42,
			"weapon_scar_duration": 24.0,
		},
	},
	&"tidal_skein": {
		"display_name": "Tidal Skein",
		"fire_mode": &"projectile",
		"energy_per_shot": 17.0,
		"fire_interval": 0.54,
		"speed": 780.0,
		"damage_min": 16.0,
		"damage_max": 25.0,
		"gravity_constant": 340.0,
		"shot_count": 3,
		"pattern": &"helix",
		"spread_radians": 0.22,
		"role": "braided tide pull",
		"color": Color(0.18, 0.74, 1.0, 1.0),
		"trail_color": Color(0.04, 0.9, 1.0, 0.88),
		"visual_scale": 0.78,
		"payload": {
			"weapon_curve_force": 430.0,
			"weapon_curve_frequency": 8.0,
			"weapon_tangent_impulse": 190.0,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.SLIPSTREAM,
			"weapon_resonance_radius": 150.0,
			"weapon_resonance_intensity": 0.4,
			"weapon_field_radius": 185.0,
			"weapon_field_force": -280.0,
			"weapon_field_damage": 6.0,
			"weapon_field_max_targets": 12,
		},
	},
	&"scar_carver": {
		"display_name": "Scar Carver",
		"fire_mode": &"projectile",
		"energy_per_shot": 19.0,
		"fire_interval": 0.62,
		"speed": 1040.0,
		"damage_min": 24.0,
		"damage_max": 36.0,
		"gravity_constant": 150.0,
		"shot_count": 2,
		"pattern": &"parallel",
		"spread_radians": 0.08,
		"role": "paired velocity-shear cutters",
		"color": Color(0.94, 1.0, 0.5, 1.0),
		"trail_color": Color(0.48, 1.0, 0.62, 0.9),
		"visual_scale": 0.86,
		"payload": {
			"weapon_axis_impulse": 220.0,
			"weapon_tangent_impulse": 340.0,
			"weapon_pierce_count": 1,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
			"weapon_resonance_radius": 150.0,
			"weapon_resonance_intensity": 0.44,
			"weapon_scar_type": GravityScarManager.ScarType.VELOCITY_SHEAR,
			"weapon_scar_radius": 175.0,
			"weapon_scar_intensity": 0.48,
			"weapon_scar_duration": 26.0,
		},
	},
	&"chronal_needleloom": {
		"display_name": "Chronal Needleloom",
		"fire_mode": &"projectile",
		"energy_per_shot": 16.0,
		"fire_interval": 0.48,
		"speed": 1020.0,
		"damage_min": 12.0,
		"damage_max": 19.0,
		"gravity_constant": 155.0,
		"shot_count": 4,
		"pattern": &"braid",
		"spread_radians": 0.11,
		"role": "braided time needles",
		"color": Color(0.78, 0.5, 1.0, 1.0),
		"trail_color": Color(0.66, 0.32, 1.0, 0.86),
		"visual_scale": 0.58,
		"payload": {
			"weapon_temporal_slow_multiplier": 0.58,
			"weapon_temporal_slow_duration": 0.34,
			"weapon_pierce_count": 1,
			"weapon_curve_force": 190.0,
			"weapon_curve_frequency": 12.5,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
			"weapon_resonance_radius": 112.0,
			"weapon_resonance_intensity": 0.32,
			"weapon_field_radius": 135.0,
			"weapon_field_slow_multiplier": 0.66,
			"weapon_field_slow_duration": 0.28,
			"weapon_field_max_targets": 9,
		},
	},
	&"singularity_kite": {
		"display_name": "Singularity Kite",
		"fire_mode": &"projectile",
		"energy_per_shot": 21.0,
		"fire_interval": 0.7,
		"speed": 700.0,
		"damage_min": 27.0,
		"damage_max": 41.0,
		"gravity_constant": 460.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "curving collapse hook",
		"color": Color(1.0, 0.42, 0.16, 1.0),
		"trail_color": Color(1.0, 0.18, 0.08, 0.9),
		"visual_scale": 1.12,
		"payload": {
			"vacuum_collapse_stacks": 1,
			"weapon_curve_force": 820.0,
			"weapon_curve_side": 1.0,
			"weapon_curve_frequency": 3.6,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.COMPRESSION,
			"weapon_resonance_radius": 230.0,
			"weapon_resonance_intensity": 0.52,
			"weapon_field_radius": 285.0,
			"weapon_field_force": -720.0,
			"weapon_field_damage": 15.0,
			"weapon_field_max_targets": 18,
			"weapon_scar_type": GravityScarManager.ScarType.CURVATURE,
			"weapon_scar_radius": 240.0,
			"weapon_scar_intensity": 0.48,
			"weapon_scar_duration": 28.0,
		},
	},
	&"inertia_maul": {
		"display_name": "Inertia Maul",
		"fire_mode": &"projectile",
		"energy_per_shot": 27.0,
		"fire_interval": 0.88,
		"speed": 600.0,
		"damage_min": 52.0,
		"damage_max": 74.0,
		"gravity_constant": 260.0,
		"shot_count": 1,
		"pattern": &"single",
		"role": "slow momentum hammer",
		"color": Color(1.0, 0.78, 0.3, 1.0),
		"trail_color": Color(1.0, 0.5, 0.12, 0.9),
		"visual_scale": 1.5,
		"payload": {
			"weapon_axis_impulse": 520.0,
			"weapon_radial_impulse": 300.0,
			"weapon_tangent_impulse": 260.0,
			"weapon_planet_damage": 110.0,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.INVERSION,
			"weapon_resonance_radius": 265.0,
			"weapon_resonance_intensity": 0.58,
			"weapon_field_radius": 310.0,
			"weapon_field_force": 520.0,
			"weapon_field_damage": 18.0,
			"weapon_field_max_targets": 16,
			"weapon_scar_type": GravityScarManager.ScarType.INVERSION_WAKE,
			"weapon_scar_radius": 285.0,
			"weapon_scar_intensity": 0.54,
			"weapon_scar_duration": 30.0,
		},
	},
	&"harmonic_bloom": {
		"display_name": "Harmonic Bloom",
		"fire_mode": &"projectile",
		"energy_per_shot": 23.0,
		"fire_interval": 0.78,
		"speed": 720.0,
		"damage_min": 12.0,
		"damage_max": 20.0,
		"gravity_constant": 280.0,
		"shot_count": 6,
		"pattern": &"ring",
		"spread_radians": 0.2,
		"role": "radial harmonic orbit bloom",
		"color": Color(0.72, 1.0, 0.34, 1.0),
		"trail_color": Color(0.38, 1.0, 0.44, 0.88),
		"visual_scale": 0.66,
		"payload": {
			"weapon_curve_force": 360.0,
			"weapon_curve_frequency": 9.6,
			"weapon_tangent_impulse": 260.0,
			"weapon_resonance_zone_type": GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
			"weapon_resonance_radius": 160.0,
			"weapon_resonance_intensity": 0.42,
			"weapon_field_radius": 180.0,
			"weapon_field_force": 290.0,
			"weapon_field_max_targets": 14,
			"weapon_scar_type": GravityScarManager.ScarType.HARMONIC_FRACTURE,
			"weapon_scar_radius": 170.0,
			"weapon_scar_intensity": 0.36,
			"weapon_scar_duration": 22.0,
		},
	},
}
const FIELD_WEAPON_DEFINITIONS := {
	&"singularity_bell": {
		"display_name": "Singularity Bell",
		"fire_mode": &"field",
		"energy_per_use": 26.0,
		"fire_interval": 0.74,
		"radius": 390.0,
		"damage": 18.0,
		"force": -920.0,
		"zone_type": GravityResonanceManager.ZoneType.COMPRESSION,
		"scar_type": GravityScarManager.ScarType.CURVATURE,
		"role": "ring-collapse gravity bell",
		"color": Color(0.18, 0.82, 1.0, 1.0),
	},
	&"gravity_loom": {
		"display_name": "Gravity Loom",
		"fire_mode": &"field",
		"energy_per_use": 20.0,
		"fire_interval": 0.58,
		"radius": 330.0,
		"damage": 8.0,
		"force": 520.0,
		"zone_type": GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
		"scar_type": GravityScarManager.ScarType.HARMONIC_FRACTURE,
		"role": "weaves enemies into orbit lanes",
		"color": Color(0.66, 1.0, 0.36, 1.0),
	},
	&"orbital_lasso": {
		"display_name": "Orbital Lasso",
		"fire_mode": &"field",
		"energy_per_use": 18.0,
		"fire_interval": 0.44,
		"radius": 300.0,
		"damage": 10.0,
		"force": 760.0,
		"zone_type": GravityResonanceManager.ZoneType.SLIPSTREAM,
		"scar_type": GravityScarManager.ScarType.VELOCITY_SHEAR,
		"role": "hooks targets around an aim anchor",
		"color": Color(0.24, 1.0, 0.82, 1.0),
	},
	&"kinetic_ram": {
		"display_name": "Kinetic Ram",
		"fire_mode": &"field",
		"energy_per_use": 16.0,
		"fire_interval": 0.36,
		"radius": 260.0,
		"damage": 24.0,
		"force": 980.0,
		"zone_type": GravityResonanceManager.ZoneType.SLIPSTREAM,
		"scar_type": GravityScarManager.ScarType.VELOCITY_SHEAR,
		"role": "player-velocity shock ram",
		"color": Color(1.0, 0.72, 0.24, 1.0),
	},
	&"temporal_bloom": {
		"display_name": "Temporal Bloom",
		"fire_mode": &"field",
		"energy_per_use": 28.0,
		"fire_interval": 0.82,
		"radius": 360.0,
		"damage": 9.0,
		"force": 0.0,
		"slow": 0.44,
		"slow_duration": 0.72,
		"zone_type": GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
		"scar_type": GravityScarManager.ScarType.TEMPORAL_RIP,
		"role": "opens a readable slow-time flower",
		"color": Color(0.62, 0.68, 1.0, 1.0),
	},
	&"phase_guillotine": {
		"display_name": "Phase Guillotine",
		"fire_mode": &"field",
		"energy_per_use": 24.0,
		"fire_interval": 0.66,
		"radius": 460.0,
		"damage": 36.0,
		"force": 640.0,
		"zone_type": GravityResonanceManager.ZoneType.INVERSION,
		"scar_type": GravityScarManager.ScarType.INVERSION_WAKE,
		"role": "line-slices space along aim",
		"color": Color(1.0, 0.35, 0.62, 1.0),
	},
	&"event_horizon_veil": {
		"display_name": "Event Horizon Veil",
		"fire_mode": &"field",
		"energy_per_use": 22.0,
		"fire_interval": 0.5,
		"radius": 280.0,
		"damage": 6.0,
		"force": 860.0,
		"zone_type": GravityResonanceManager.ZoneType.INVERSION,
		"scar_type": GravityScarManager.ScarType.CURVATURE,
		"role": "projectile-bending defensive veil",
		"color": Color(0.38, 0.54, 1.0, 1.0),
	},
	&"mass_siphon": {
		"display_name": "Mass Siphon",
		"fire_mode": &"field",
		"energy_per_use": 18.0,
		"fire_interval": 0.62,
		"radius": 340.0,
		"damage": 14.0,
		"force": -640.0,
		"energy_restore": 1.8,
		"zone_type": GravityResonanceManager.ZoneType.COMPRESSION,
		"scar_type": GravityScarManager.ScarType.CURVATURE,
		"role": "pulls mass into recoverable energy",
		"color": Color(0.28, 1.0, 0.58, 1.0),
	},
	&"inversion_chime": {
		"display_name": "Inversion Chime",
		"fire_mode": &"field",
		"energy_per_use": 21.0,
		"fire_interval": 0.52,
		"radius": 350.0,
		"damage": 12.0,
		"force": 980.0,
		"zone_type": GravityResonanceManager.ZoneType.INVERSION,
		"scar_type": GravityScarManager.ScarType.INVERSION_WAKE,
		"role": "clean outward gravity inversion",
		"color": Color(1.0, 0.42, 0.16, 1.0),
	},
	&"resonance_anvil": {
		"display_name": "Resonance Anvil",
		"fire_mode": &"field",
		"energy_per_use": 30.0,
		"fire_interval": 0.9,
		"radius": 420.0,
		"damage": 30.0,
		"force": 1040.0,
		"zone_type": GravityResonanceManager.ZoneType.HARMONIC_ORBIT,
		"scar_type": GravityScarManager.ScarType.HARMONIC_FRACTURE,
		"role": "slams targets into orbital fracture",
		"color": Color(1.0, 0.9, 0.26, 1.0),
	},
}
const FIELD_WEAPON_TARGET_GROUPS: Array[StringName] = [&"enemies", &"wave_enemy", &"bosses", &"enemy_projectiles", &"Projectiles"]
const IMPACT_RING_WIDTH: float = 2.0

@export_node_path("Node2D") var player_path: NodePath = ^".."
@export var selected_weapon_index: int = 0
@export var enable_switch_hotkeys: bool = true
@export var switch_cooldown: float = 0.14

@export_group("Weapon Progression")
@export var progressive_weapon_unlocks: bool = true
@export var clip_lab_unlocks_all_weapons: bool = true
@export var mod_weapons_unlock_wave: int = 6
@export var weapon_unlock_check_interval: float = 0.42

@export_group("Beam Geometry")
@export var beam_range: float = 1180.0
@export var positron_beam_width: float = 74.0
@export var gravity_wave_width: float = 118.0
@export var chronal_beam_width: float = 96.0
@export var max_beam_hits_per_tick: int = 36

@export_group("Energy")
@export var vector_bolt_energy_per_shot: float = 0.0
@export var relativistic_rail_energy_per_shot: float = 8.0
@export var barycentric_splitter_energy_per_shot: float = 11.0
@export var vacuum_seed_energy_per_shot: float = 24.0
@export var temporal_splinter_energy_per_shot: float = 9.0
@export var inversion_disc_energy_per_shot: float = 14.0
@export var harmonic_needle_energy_per_shot: float = 7.0
@export var shear_comet_energy_per_shot: float = 12.0
@export var singularity_pin_energy_per_shot: float = 18.0
@export var event_horizon_shard_energy_per_shot: float = 30.0
@export var positron_energy_per_second: float = 34.0
@export var gravity_wave_energy_per_second: float = 22.0
@export var chronal_energy_per_second: float = 30.0
@export var minimum_beam_tick_cost: float = 2.2
@export var field_weapon_max_targets: int = 36
@export var field_weapon_visual_lifetime: float = 0.22

@export_group("Projectile Cadence")
@export var vector_bolt_fire_interval: float = 0.18
@export var relativistic_rail_fire_interval: float = 0.34
@export var barycentric_splitter_fire_interval: float = 0.44
@export var vacuum_seed_fire_interval: float = 0.78
@export var temporal_splinter_fire_interval: float = 0.38
@export var inversion_disc_fire_interval: float = 0.56
@export var harmonic_needle_fire_interval: float = 0.24
@export var shear_comet_fire_interval: float = 0.42
@export var singularity_pin_fire_interval: float = 0.68
@export var event_horizon_shard_fire_interval: float = 0.92
@export var projectile_spawn_offset: float = 70.0
@export var projectile_side_offset: float = 24.0
@export var projectile_prediction_collision_radius: float = 14.0
@export var projectile_minimum_energy_buffer: float = 0.0

@export_group("Projectile Profiles")
@export var vector_bolt_speed: float = 1080.0
@export var vector_bolt_damage_min: float = 28.0
@export var vector_bolt_damage_max: float = 38.0
@export var vector_bolt_gravity: float = 200.0
@export var relativistic_rail_speed: float = 1320.0
@export var relativistic_rail_damage_min: float = 42.0
@export var relativistic_rail_damage_max: float = 56.0
@export var relativistic_rail_impulse: float = 260.0
@export var barycentric_splitter_speed: float = 860.0
@export var barycentric_splitter_damage_min: float = 18.0
@export var barycentric_splitter_damage_max: float = 26.0
@export var barycentric_splitter_curve_force: float = 560.0
@export var barycentric_splitter_axis_impulse: float = 130.0
@export var vacuum_seed_speed: float = 620.0
@export var vacuum_seed_damage_min: float = 22.0
@export var vacuum_seed_damage_max: float = 32.0
@export var vacuum_seed_collapse_stacks: int = 1
@export var vacuum_seed_resonance_radius: float = 190.0
@export var temporal_splinter_speed: float = 900.0
@export var temporal_splinter_damage_min: float = 14.0
@export var temporal_splinter_damage_max: float = 20.0
@export var inversion_disc_speed: float = 740.0
@export var inversion_disc_damage_min: float = 20.0
@export var inversion_disc_damage_max: float = 28.0
@export var harmonic_needle_speed: float = 1180.0
@export var harmonic_needle_damage_min: float = 16.0
@export var harmonic_needle_damage_max: float = 24.0
@export var shear_comet_speed: float = 980.0
@export var shear_comet_damage_min: float = 24.0
@export var shear_comet_damage_max: float = 34.0
@export var singularity_pin_speed: float = 690.0
@export var singularity_pin_damage_min: float = 26.0
@export var singularity_pin_damage_max: float = 38.0
@export var event_horizon_shard_speed: float = 520.0
@export var event_horizon_shard_damage_min: float = 38.0
@export var event_horizon_shard_damage_max: float = 52.0

@export_group("Positron Beam")
@export var positron_damage_per_second: float = 145.0
@export var positron_planet_damage_per_second: float = 92.0
@export var positron_recoil: float = 36.0
@export var positron_scar_interval: float = 0.38

@export_group("Gravity Wave Beam")
@export var gravity_wave_force_per_second: float = 980.0
@export var gravity_wave_damage_per_second: float = 34.0
@export var gravity_wave_resonance_interval: float = 0.48
@export var gravity_wave_projectile_force_multiplier: float = 1.45
@export var gravity_wave_axis_pull_per_second: float = 1220.0
@export var gravity_wave_enemy_pull_multiplier: float = 1.25
@export var gravity_wave_forward_drift: float = 0.18
@export var gravity_wave_planet_damage_per_second: float = 46.0
@export var gravity_wave_planet_displacement_per_second: float = 42.0
@export var gravity_wave_planet_fracture_interval: float = 0.72

@export_group("Chronal Refraction Beam")
@export var chronal_slow_multiplier: float = 0.46
@export var chronal_slow_duration: float = 0.52
@export var chronal_refraction_damage_per_second: float = 30.0
@export var chronal_delayed_impulse: float = 280.0
@export var chronal_delay_seconds: float = 0.36
@export var chronal_zone_interval: float = 0.42
@export var chronal_echo_count: int = 3
@export var chronal_echo_spacing: float = 0.11
@export var chronal_echo_max_per_tick: int = 10
@export var chronal_desync_lateral_impulse: float = 150.0
@export var chronal_echo_zone_interval: float = 0.16

@export_group("Visuals")
@export var vector_bolt_color: Color = Color(0.34, 1.0, 0.86, 1.0)
@export var relativistic_rail_color: Color = Color(0.42, 0.9, 1.0, 1.0)
@export var barycentric_splitter_color: Color = Color(0.56, 1.0, 0.58, 1.0)
@export var vacuum_seed_color: Color = Color(1.0, 0.38, 0.2, 1.0)
@export var temporal_splinter_color: Color = Color(0.74, 0.36, 1.0, 1.0)
@export var inversion_disc_color: Color = Color(1.0, 0.46, 0.78, 1.0)
@export var harmonic_needle_color: Color = Color(0.62, 1.0, 0.72, 1.0)
@export var shear_comet_color: Color = Color(0.28, 0.94, 1.0, 1.0)
@export var singularity_pin_color: Color = Color(1.0, 0.32, 0.12, 1.0)
@export var event_horizon_shard_color: Color = Color(1.0, 0.16, 0.1, 1.0)
@export var positron_color: Color = Color(1.0, 0.72, 0.28, 1.0)
@export var gravity_wave_color: Color = Color(0.3, 0.72, 1.0, 1.0)
@export var chronal_color: Color = Color(0.74, 0.36, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var projectile_core_alpha_cap: float = 0.62
@export_range(0.0, 0.42, 0.01) var beam_alpha_cap: float = 0.34
@export var beam_impact_radius_cap: float = 96.0
@export var beam_pulse_speed: float = 10.0

@onready var _beam_root: Node2D = get_node_or_null("BeamRoot") as Node2D
@onready var _beam_glow: Line2D = get_node_or_null("BeamRoot/BeamGlow") as Line2D
@onready var _beam_core: Line2D = get_node_or_null("BeamRoot/BeamCore") as Line2D
@onready var _impact_ring: Line2D = get_node_or_null("BeamRoot/ImpactRing") as Line2D

var _player: Node2D = null
var _energy_component: Node = null
var _powerup_inventory: Node = null
var _pause_menu: Node = null
var _query_shape := RectangleShape2D.new()
var _query_params := PhysicsShapeQueryParameters2D.new()
var _field_target_buffer: Array[Node2D] = []
var _field_visual_root: Node2D = null
var _active_weapon_id: StringName = &"vector_bolt"
var _weapon_ids: Array[StringName] = []
var _weapon_catalog: Dictionary = {}
var _mod_registry: Node = null
var _beam_active := false
var _beam_heat := 0.0
var _last_switch_time := -999.0
var _last_projectile_fire_time := -999.0
var _projectile_pattern_index := 0
var _last_positron_scar_time := -999.0
var _last_wave_resonance_time := -999.0
var _last_wave_planet_fracture_time := -999.0
var _last_chronal_zone_time := -999.0
var _last_chronal_echo_zone_time := -999.0
var _chronal_phantoms_this_tick: int = 0
var _chronal_async_generation: int = 0
var _beam_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _chronal_trace_pool: Array[Line2D] = []
var _progression_unlock_token: String = ""
var _last_unlocked_weapon_count: int = 0
var _weapon_unlock_check_elapsed: float = 999.0
var _total_weapon_catalog_count: int = 0
var _cached_progression_wave: int = 0


func _ready() -> void:
	add_to_group("weapon_system")
	_resolve_player()
	call_deferred("_resolve_pause_menu")
	_configure_query()
	_ensure_visual_nodes()
	_cached_progression_wave = _sample_weapon_progression_wave()
	_initialize_weapon_catalog()
	_progression_unlock_token = _current_weapon_unlock_token()
	_last_unlocked_weapon_count = _weapon_ids.size()
	_connect_network_session()
	select_weapon(selected_weapon_index)
	set_process_unhandled_input(true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_update_weapon_progression(delta)

	if _is_gameplay_blocked() or _is_player_dead():
		_end_beam()
		return

	if not _is_beam_weapon(_active_weapon_id):
		_end_beam()
		return

	if Input.is_action_pressed("shoot"):
		_fire_selected_beam(delta)
	else:
		_end_beam()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_switch_hotkeys or _is_gameplay_blocked() or _is_player_dead():
		return

	if _input_pressed(event, &"weapon_next", KEY_TAB):
		select_next_weapon()
		get_viewport().set_input_as_handled()
	elif _input_pressed(event, &"weapon_previous", KEY_BACKTAB):
		select_previous_weapon()
		get_viewport().set_input_as_handled()


func try_primary_fire() -> bool:
	if _is_player_dead():
		return false
	if _is_beam_weapon(_active_weapon_id):
		return true
	if _is_field_weapon(_active_weapon_id):
		return _fire_field_weapon()
	if _is_projectile_weapon(_active_weapon_id):
		_fire_projectile_weapon()
		return true
	return false


func force_cease_fire() -> void:
	_end_beam()


func get_current_fire_interval() -> float:
	if _is_beam_weapon(_active_weapon_id):
		return 0.03
	if _is_field_weapon(_active_weapon_id):
		return _field_fire_interval(_active_weapon_id)
	return _projectile_fire_interval(_active_weapon_id)


func is_current_weapon_projectile() -> bool:
	return _is_projectile_weapon(_active_weapon_id)


func get_projectile_prediction_state() -> Dictionary:
	return _projectile_prediction_state(_active_weapon_id)


func select_next_weapon() -> void:
	select_weapon(selected_weapon_index + 1)


func select_previous_weapon() -> void:
	select_weapon(selected_weapon_index - 1)


func select_weapon(index: int) -> void:
	if _weapon_ids.is_empty():
		_initialize_weapon_catalog()
	if _weapon_ids.is_empty():
		return
	var now := _now_seconds()
	if now - _last_switch_time < switch_cooldown:
		return
	_last_switch_time = now

	selected_weapon_index = posmod(index, _weapon_ids.size())
	_active_weapon_id = _weapon_ids[selected_weapon_index]
	_end_beam()
	_sync_projectile_predictor()
	weapon_changed.emit(_active_weapon_id, _display_name(_active_weapon_id), get_weapon_debug_state())


func select_weapon_by_id(weapon_id: StringName) -> void:
	var index := _weapon_ids.find(weapon_id)
	if index >= 0:
		select_weapon(index)


func get_weapon_debug_state() -> Dictionary:
	var energy := _current_energy()
	var max_energy := _max_energy()
	var cost := _energy_cost_for_weapon(_active_weapon_id)
	var is_beam := _is_beam_weapon(_active_weapon_id)
	var is_field := _is_field_weapon(_active_weapon_id)
	var is_projectile := _is_projectile_weapon(_active_weapon_id)
	var interval := get_current_fire_interval()
	var cooldown_remaining := maxf(interval - (_now_seconds() - _last_projectile_fire_time), 0.0) if is_projectile or is_field else 0.0
	var field_cost := _field_energy_cost(_active_weapon_id)
	var total_weapons := _total_weapon_count()
	var next_unlock_wave := _next_weapon_unlock_wave()
	return {
		"weapon_id": _active_weapon_id,
		"display_name": _display_name(_active_weapon_id),
		"index": selected_weapon_index,
		"count": _weapon_ids.size(),
		"unlocked_count": _weapon_ids.size(),
		"total_weapon_count": total_weapons,
		"progression_wave": _current_weapon_progression_wave(),
		"unlock_wave": _weapon_unlock_wave(_active_weapon_id),
		"next_unlock_wave": next_unlock_wave,
		"next_unlock_names": _next_weapon_unlock_names(next_unlock_wave),
		"progression_active": progressive_weapon_unlocks and not _all_weapons_unlocked_for_context(),
		"clip_lab_all_weapons": _is_clip_lab_context() and _all_weapons_unlocked_for_context(),
		"fire_mode": &"beam" if is_beam else (&"field" if is_field else &"projectile"),
		"is_projectile": is_projectile,
		"is_field": is_field,
		"beam_active": _beam_active,
		"cooldown_remaining": cooldown_remaining,
		"cooldown_percent": 1.0 - clampf(cooldown_remaining / maxf(interval, 0.001), 0.0, 1.0),
		"fire_interval": interval,
		"energy": energy,
		"max_energy": max_energy,
		"energy_percent": energy / maxf(max_energy, 1.0),
		"cost_per_second": cost,
		"cost_per_shot": _projectile_energy_cost(_active_weapon_id),
		"cost_per_use": field_cost,
		"ready": cooldown_remaining <= 0.001 and energy >= _minimum_energy_for_weapon(_active_weapon_id),
		"role": _weapon_role(_active_weapon_id),
		"play_hint": _weapon_play_hint(_active_weapon_id),
		"color": _weapon_color(_active_weapon_id),
		"prediction": _projectile_prediction_state(_active_weapon_id),
	}


func _initialize_weapon_catalog() -> void:
	var previous_weapon := _active_weapon_id
	_weapon_ids.clear()
	_weapon_catalog.clear()

	for weapon_id in WEAPON_IDS:
		if _weapon_available_in_current_context(weapon_id):
			_register_builtin_weapon(weapon_id)

	_bind_mod_registry()
	_register_mod_weapons()
	_total_weapon_catalog_count = maxi(WEAPON_IDS.size() + _playable_mod_weapon_count(), _weapon_ids.size())

	if _weapon_ids.is_empty():
		_weapon_ids.append(&"vector_bolt")
	if _weapon_ids.has(previous_weapon):
		_active_weapon_id = previous_weapon
	else:
		_active_weapon_id = _weapon_ids[0]
	selected_weapon_index = maxi(_weapon_ids.find(_active_weapon_id), 0)


func _register_builtin_weapon(weapon_id: StringName) -> void:
	var entry := {
		"id": weapon_id,
		"qualified_id": String(weapon_id),
		"display_name": _builtin_display_name(weapon_id),
		"fire_mode": &"beam" if _is_builtin_beam_weapon(weapon_id) else &"projectile",
		"builtin": true,
		"base_weapon_id": weapon_id,
		"payload": {},
	}
	if EXTRA_WEAPON_DEFINITIONS.has(weapon_id):
		var definition: Dictionary = EXTRA_WEAPON_DEFINITIONS[weapon_id]
		entry.merge(definition.duplicate(true), true)
		entry["builtin"] = true
		entry["base_weapon_id"] = weapon_id
	if FIELD_WEAPON_DEFINITIONS.has(weapon_id):
		var field_definition: Dictionary = FIELD_WEAPON_DEFINITIONS[weapon_id]
		entry.merge(field_definition.duplicate(true), true)
		entry["builtin"] = true
		entry["base_weapon_id"] = weapon_id
	_register_weapon_entry(weapon_id, entry)


func _bind_mod_registry() -> void:
	var root := get_tree().current_scene
	_mod_registry = root.find_child("ModContentRegistry", true, false) if root != null else null
	if _mod_registry == null:
		return
	var loaded_callable := Callable(self, "_on_mod_registry_loaded")
	if _mod_registry.has_signal("mod_catalog_changed") and not _mod_registry.is_connected("mod_catalog_changed", loaded_callable):
		_mod_registry.connect("mod_catalog_changed", loaded_callable)
	elif _mod_registry.has_signal("registry_reloaded") and not _mod_registry.is_connected("registry_reloaded", loaded_callable):
		_mod_registry.connect("registry_reloaded", loaded_callable)


func _register_mod_weapons() -> void:
	if _mod_registry == null or not is_instance_valid(_mod_registry):
		return
	if not _mod_registry.has_method("get_playable_weapon_entries"):
		return
	var entries_value: Variant = _mod_registry.call("get_playable_weapon_entries")
	if not (entries_value is Array):
		return
	for value in entries_value:
		if not (value is Dictionary):
			continue
		var entry := (value as Dictionary).duplicate(true)
		var weapon_id := StringName(str(entry.get("qualified_id", entry.get("id", ""))))
		if String(weapon_id).is_empty():
			continue
		if _weapon_catalog.has(String(weapon_id)):
			continue
		var unlock_wave := int(entry.get("unlock_wave", mod_weapons_unlock_wave))
		if not _all_weapons_unlocked_for_context() and _current_weapon_progression_wave() < unlock_wave:
			continue
		entry["builtin"] = false
		entry["fire_mode"] = StringName(str(entry.get("fire_mode", "projectile")))
		entry["base_weapon_id"] = StringName(str(entry.get("base_weapon_id", "vector_bolt")))
		_register_weapon_entry(weapon_id, entry)


func _register_weapon_entry(weapon_id: StringName, entry: Dictionary) -> void:
	var key := String(weapon_id)
	_weapon_catalog[key] = entry
	if not _weapon_ids.has(weapon_id):
		_weapon_ids.append(weapon_id)


func _on_mod_registry_loaded(_summary: Dictionary) -> void:
	_cached_progression_wave = _sample_weapon_progression_wave()
	_initialize_weapon_catalog()
	_progression_unlock_token = _current_weapon_unlock_token()
	_last_unlocked_weapon_count = _weapon_ids.size()
	_sync_projectile_predictor()
	weapon_changed.emit(_active_weapon_id, _display_name(_active_weapon_id), get_weapon_debug_state())


func unlock_all_weapons_for_showcase() -> void:
	progressive_weapon_unlocks = false
	_progression_unlock_token = ""
	_initialize_weapon_catalog()
	_progression_unlock_token = _current_weapon_unlock_token()
	_last_unlocked_weapon_count = _weapon_ids.size()
	_sync_projectile_predictor()
	weapon_changed.emit(_active_weapon_id, _display_name(_active_weapon_id), get_weapon_debug_state())


func refresh_weapon_catalog() -> void:
	_progression_unlock_token = ""
	_update_weapon_progression(weapon_unlock_check_interval, true)


func _update_weapon_progression(delta: float, force: bool = false) -> void:
	_weapon_unlock_check_elapsed += delta
	if not force and _weapon_unlock_check_elapsed < maxf(weapon_unlock_check_interval, 0.08):
		return
	_weapon_unlock_check_elapsed = 0.0
	var sampled_wave := _sample_weapon_progression_wave()
	var token := "all" if _all_weapons_unlocked_for_context() else "wave:%d" % sampled_wave
	if not force and token == _progression_unlock_token:
		return

	var previous_ids := _weapon_ids.duplicate()
	_progression_unlock_token = token
	_cached_progression_wave = sampled_wave
	_initialize_weapon_catalog()
	_sync_projectile_predictor()
	var newly_unlocked := _new_weapon_names(previous_ids, _weapon_ids)
	_last_unlocked_weapon_count = _weapon_ids.size()
	if not newly_unlocked.is_empty():
		weapon_pool_changed.emit(_weapon_ids.size(), _total_weapon_count(), newly_unlocked)
	weapon_changed.emit(_active_weapon_id, _display_name(_active_weapon_id), get_weapon_debug_state())


func _weapon_available_in_current_context(weapon_id: StringName) -> bool:
	if _all_weapons_unlocked_for_context():
		return true
	return _current_weapon_progression_wave() >= _weapon_unlock_wave(weapon_id)


func _all_weapons_unlocked_for_context() -> bool:
	if not progressive_weapon_unlocks:
		return true
	return clip_lab_unlocks_all_weapons and _is_clip_lab_context()


func _is_clip_lab_context() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var scene := tree.current_scene
	if scene != null and (scene.name == "ClipLabScene" or scene.is_in_group("clip_lab_scene")):
		return true
	return tree.get_first_node_in_group("clip_lab_scene") != null


func _current_weapon_progression_wave() -> int:
	if _all_weapons_unlocked_for_context():
		return 9999
	return _cached_progression_wave


func _sample_weapon_progression_wave() -> int:
	if _all_weapons_unlocked_for_context():
		return 9999
	var wave := 0
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	var wave_director := scene.find_child("WaveDirector", true, false) if scene != null else null
	if wave_director != null and wave_director.has_method("get_current_wave"):
		wave = maxi(wave, int(wave_director.call("get_current_wave")))
	elif wave_director != null:
		var wave_value: Variant = wave_director.get("_wave")
		if wave_value is int or wave_value is float:
			wave = maxi(wave, int(wave_value))
	if RunProgress != null:
		wave = maxi(wave, int(RunProgress.wave_index))
	return wave


func _current_weapon_unlock_token() -> String:
	if _all_weapons_unlocked_for_context():
		return "all"
	return "wave:%d" % _current_weapon_progression_wave()


func _weapon_unlock_wave(weapon_id: StringName) -> int:
	return int(WEAPON_UNLOCK_WAVES.get(weapon_id, 0))


func _total_weapon_count() -> int:
	return maxi(_total_weapon_catalog_count, _weapon_ids.size())


func _playable_mod_weapon_count() -> int:
	if _mod_registry == null or not is_instance_valid(_mod_registry) or not _mod_registry.has_method("get_playable_weapon_entries"):
		return 0
	var entries_value: Variant = _mod_registry.call("get_playable_weapon_entries")
	if entries_value is Array:
		return (entries_value as Array).size()
	return 0


func _next_weapon_unlock_wave() -> int:
	if _all_weapons_unlocked_for_context():
		return -1
	var current_wave := _current_weapon_progression_wave()
	var next_wave := 999999
	for weapon_id in WEAPON_IDS:
		var unlock_wave := _weapon_unlock_wave(weapon_id)
		if unlock_wave > current_wave and unlock_wave < next_wave:
			next_wave = unlock_wave
	return -1 if next_wave == 999999 else next_wave


func _next_weapon_unlock_names(next_wave: int = -2) -> Array[String]:
	var names: Array[String] = []
	var target_wave := next_wave
	if target_wave == -2:
		target_wave = _next_weapon_unlock_wave()
	if target_wave < 0:
		return names
	for weapon_id in WEAPON_IDS:
		if _weapon_unlock_wave(weapon_id) == target_wave:
			names.append(_builtin_display_name(weapon_id))
	return names


func _new_weapon_names(previous_ids: Array, current_ids: Array[StringName]) -> Array[String]:
	var previous_lookup := {}
	for value in previous_ids:
		previous_lookup[String(value)] = true
	var names: Array[String] = []
	for weapon_id in current_ids:
		if not previous_lookup.has(String(weapon_id)):
			names.append(_display_name(weapon_id))
	return names


func _fire_selected_beam(delta: float) -> void:
	_resolve_player()
	if _player == null or not is_instance_valid(_player) or _is_player_dead():
		_end_beam()
		return

	var tick_cost := maxf(_energy_cost_for_weapon(_active_weapon_id) * delta, minimum_beam_tick_cost)
	if not _spend_energy(tick_cost):
		weapon_energy_failed.emit(_active_weapon_id, tick_cost, _current_energy())
		_end_beam()
		return

	var origin := _player.global_position + _aim_direction() * 74.0
	var direction := _aim_direction()
	var width := _beam_width_for_weapon(_active_weapon_id)
	var hits := _collect_beam_hits(origin, direction, width)

	if _active_weapon_id == &"positron_beam":
		_apply_positron_beam(origin, direction, hits, delta)
	elif _active_weapon_id == &"gravity_wave_beam":
		_apply_gravity_wave_beam(origin, direction, hits, delta)
	else:
		_apply_chronal_refraction_beam(origin, direction, hits, delta)

	_update_beam_visual(origin, direction, width, hits)
	weapon_fired.emit(_active_weapon_id, {
		"origin": origin,
		"direction": direction,
		"hits": hits.size(),
		"energy_spent": tick_cost,
		"fire_mode": &"beam",
	})


func _fire_projectile_weapon() -> bool:
	_resolve_player()
	if _player == null or not is_instance_valid(_player) or _is_player_dead():
		return false
	if _is_gameplay_blocked():
		return false

	var now := _now_seconds()
	var interval := _projectile_fire_interval(_active_weapon_id)
	if now - _last_projectile_fire_time < interval:
		return false

	var shot_cost := _projectile_energy_cost(_active_weapon_id)
	if shot_cost > 0.0 and not _spend_energy(shot_cost):
		weapon_energy_failed.emit(_active_weapon_id, shot_cost, _current_energy())
		return false

	var direction := _aim_direction()
	var origin := _player.global_position + direction * projectile_spawn_offset
	var spawned := _spawn_projectile_pattern(_active_weapon_id, origin, direction)
	if spawned <= 0:
		if shot_cost > 0.0:
			_restore_energy(shot_cost)
		return false

	_last_projectile_fire_time = now
	_play_projectile_sound(spawned)
	_apply_projectile_recoil(direction)
	if _powerup_inventory != null and is_instance_valid(_powerup_inventory) and _powerup_inventory.has_method("trigger_player_action"):
		_powerup_inventory.call("trigger_player_action")

	weapon_fired.emit(_active_weapon_id, {
		"origin": origin,
		"direction": direction,
		"projectiles": spawned,
		"energy_spent": shot_cost,
		"fire_mode": &"projectile",
	})
	return true


func _fire_field_weapon() -> bool:
	_resolve_player()
	if _player == null or not is_instance_valid(_player) or _is_player_dead():
		return false
	if _is_gameplay_blocked():
		return false

	var now := _now_seconds()
	var interval := _field_fire_interval(_active_weapon_id)
	if now - _last_projectile_fire_time < interval:
		return false

	var use_cost := _field_energy_cost(_active_weapon_id)
	if use_cost > 0.0 and not _spend_energy(use_cost):
		weapon_energy_failed.emit(_active_weapon_id, use_cost, _current_energy())
		return false

	var direction := _aim_direction()
	var origin := _player.global_position + direction * 82.0
	var entry := _field_weapon_entry(_active_weapon_id)
	var hits := _apply_field_weapon_effect(_active_weapon_id, entry, origin, direction, true)
	_last_projectile_fire_time = now

	if _powerup_inventory != null and is_instance_valid(_powerup_inventory) and _powerup_inventory.has_method("trigger_player_action"):
		_powerup_inventory.call("trigger_player_action")

	_broadcast_field_weapon(_active_weapon_id, origin, direction, entry)
	weapon_fired.emit(_active_weapon_id, {
		"origin": origin,
		"direction": direction,
		"targets": hits,
		"energy_spent": use_cost,
		"fire_mode": &"field",
	})
	return true


func _apply_field_weapon_effect(
	weapon_id: StringName,
	entry: Dictionary,
	origin: Vector2,
	direction: Vector2,
	spawn_visual: bool
) -> int:
	var radius := maxf(float(entry.get("radius", 280.0)), 40.0)
	var damage := maxf(float(entry.get("damage", 0.0)), 0.0)
	var force := float(entry.get("force", 0.0))
	var anchor := origin + direction * radius * 0.58
	if weapon_id == &"kinetic_ram":
		anchor = origin + direction * radius
	if weapon_id == &"phase_guillotine":
		anchor = origin + direction * radius * 0.72

	var targets := _collect_field_targets(origin, radius)
	var hits := 0
	for target in targets:
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if _is_player_owned(target):
			continue
		if not _target_in_field_shape(weapon_id, target, origin, direction, radius):
			continue
		_apply_field_target_impulse(weapon_id, entry, target, origin, direction, anchor, force)
		_apply_field_target_damage(weapon_id, target, damage)
		var slow := float(entry.get("slow", 1.0))
		if slow < 0.999:
			CombatStatus.apply_local_time_scale(target, clampf(slow, 0.2, 1.0), maxf(float(entry.get("slow_duration", 0.35)), 0.05))
		if weapon_id == &"mass_siphon":
			_restore_energy(maxf(float(entry.get("energy_restore", 0.0)), 0.0))
		hits += 1

	_stamp_field_zone(weapon_id, entry, origin, direction, radius)
	if spawn_visual:
		_spawn_field_weapon_visual(weapon_id, origin, direction, radius, _weapon_color(weapon_id))
	return hits


func _apply_field_target_impulse(
	weapon_id: StringName,
	entry: Dictionary,
	target: Node2D,
	origin: Vector2,
	direction: Vector2,
	anchor: Vector2,
	force: float
) -> void:
	var impulse := Vector2.ZERO
	match weapon_id:
		&"singularity_bell", &"mass_siphon":
			impulse = (origin - target.global_position).normalized() * absf(force)
		&"gravity_loom":
			var radial := target.global_position - origin
			if radial.length_squared() <= 0.001:
				radial = direction
			impulse = radial.normalized().orthogonal() * absf(force)
		&"orbital_lasso":
			impulse = (anchor - target.global_position).normalized() * absf(force)
			target.set_meta(&"orbital_lasso_anchor", anchor)
		&"kinetic_ram":
			var player_velocity := _body_velocity(_player)
			var ram_dir := player_velocity.normalized() if player_velocity.length_squared() > 1.0 else direction
			impulse = ram_dir * absf(force)
			if _player != null:
				CombatStatus.add_velocity(_player, -ram_dir * 70.0)
		&"phase_guillotine":
			var lateral := direction.orthogonal()
			var side := signf((target.global_position - origin).dot(lateral))
			side = 1.0 if absf(side) < 0.001 else side
			impulse = direction * absf(force) * 0.42 + lateral * side * absf(force) * 0.58
		&"event_horizon_veil", &"inversion_chime":
			impulse = (target.global_position - origin).normalized() * absf(force)
		&"resonance_anvil":
			var source := _nearest_gravity_source_for_position(target.global_position)
			if source != null:
				impulse = (source.global_position - target.global_position).normalized() * absf(force)
				target.set_meta(&"resonance_anvil_target", source.global_position)
			else:
				impulse = direction * absf(force)
		_:
			impulse = direction * force
	if impulse.length_squared() > 0.001:
		var multiplier := 1.35 if target.is_in_group("enemy_projectiles") or target.is_in_group("Projectiles") else 1.0
		CombatStatus.add_velocity(target, impulse * multiplier)
	target.set_meta(&"field_weapon_pressure", String(weapon_id))


func _target_in_field_shape(weapon_id: StringName, target: Node2D, origin: Vector2, direction: Vector2, radius: float) -> bool:
	if weapon_id != &"phase_guillotine" and weapon_id != &"kinetic_ram":
		return true
	var offset := target.global_position - origin
	var along := offset.dot(direction)
	if along < -24.0 or along > radius * 1.24:
		return false
	var lateral := absf(offset.dot(direction.orthogonal()))
	var width := 86.0 if weapon_id == &"phase_guillotine" else 130.0
	return lateral <= width


func _apply_field_target_damage(weapon_id: StringName, target: Node, damage: float) -> void:
	if damage <= 0.0 or target == null or not is_instance_valid(target):
		return
	if target.has_method("take_damage") and _is_hostile_target(target):
		_stamp_player_weapon_hit(target, weapon_id, damage)
		target.call("take_damage", damage)


func _collect_field_targets(center: Vector2, radius: float) -> Array[Node2D]:
	_field_target_buffer.clear()
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_targets_in_radius(
			FIELD_WEAPON_TARGET_GROUPS,
			center,
			radius,
			field_weapon_max_targets,
			false,
			_field_target_buffer
		)
		return _field_target_buffer
	var seen := {}
	var radius_squared := radius * radius
	for group_name in FIELD_WEAPON_TARGET_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			if _field_target_buffer.size() >= field_weapon_max_targets:
				return _field_target_buffer
			var body := node as Node2D
			if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var id := body.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			if body.global_position.distance_squared_to(center) <= radius_squared:
				_field_target_buffer.append(body)
	return _field_target_buffer


func _stamp_field_zone(weapon_id: StringName, entry: Dictionary, origin: Vector2, direction: Vector2, radius: float) -> void:
	var zone_type := int(entry.get("zone_type", GravityResonanceManager.ZoneType.COMPRESSION))
	var scar_type := int(entry.get("scar_type", GravityScarManager.ScarType.CURVATURE))
	var zone_position := origin
	if weapon_id == &"phase_guillotine" or weapon_id == &"kinetic_ram":
		zone_position = origin + direction * radius * 0.5
	var resonance := _get_resonance_manager()
	if resonance != null and resonance.has_method("create_manual_resonance_zone"):
		resonance.call(
			"create_manual_resonance_zone",
			zone_position,
			radius * 0.72,
			zone_type,
			0.42,
			0.62
		)
	var scars := _get_gravity_scar_manager()
	if scars != null and scars.has_method("create_gravity_scar"):
		scars.call(
			"create_gravity_scar",
			zone_position,
			radius * 0.66,
			scar_type,
			0.36,
			14.0,
			weapon_id
		)


func _spawn_field_weapon_visual(weapon_id: StringName, origin: Vector2, direction: Vector2, radius: float, color: Color) -> void:
	_ensure_field_visual_root()
	if _field_visual_root == null:
		return
	var line := Line2D.new()
	line.name = "FieldWeaponPulse_%s" % String(weapon_id)
	line.top_level = true
	line.antialiased = true
	line.z_index = 36
	line.width = 3.0
	line.default_color = Color(color.r, color.g, color.b, _visual_alpha(0.34))
	if weapon_id == &"phase_guillotine" or weapon_id == &"kinetic_ram":
		line.global_position = origin
		line.points = PackedVector2Array([Vector2.ZERO, direction * radius])
	else:
		line.closed = true
		line.points = _circle_points(48, radius)
		line.global_position = origin
	_field_visual_root.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "scale", Vector2.ONE * 1.18, field_weapon_visual_lifetime)
	tween.parallel().tween_property(line, "modulate:a", 0.0, field_weapon_visual_lifetime)
	tween.finished.connect(line.queue_free)


func _spawn_projectile_pattern(weapon_id: StringName, origin: Vector2, direction: Vector2) -> int:
	var count := _projectile_count_for_weapon(weapon_id)
	var spawned := 0
	for shot_index in range(count):
		var shot_direction := _projectile_direction_for_index(weapon_id, direction, shot_index, count)
		var side_offset := _projectile_side_offset_for_index(weapon_id, shot_direction, shot_index, count)
		if _spawn_configured_projectile(weapon_id, origin + side_offset, shot_direction, shot_index, count):
			spawned += 1
	_projectile_pattern_index += 1
	return spawned


func _spawn_configured_projectile(
	weapon_id: StringName,
	origin: Vector2,
	direction: Vector2,
	shot_index: int,
	shot_count: int
) -> bool:
	var projectile := PROJECTILE_SCENE.instantiate() as RigidBody2D
	if projectile == null:
		return false

	projectile.global_position = origin
	projectile.global_rotation = direction.angle()
	_apply_projectile_payload(projectile, _projectile_payload(weapon_id, shot_index, shot_count))

	var momentum_component := _player.get_node_or_null("MomentumCombatComponent")
	if momentum_component != null and momentum_component.has_method("prepare_projectile"):
		momentum_component.call("prepare_projectile", projectile, direction)
		_refresh_payload_from_projectile(projectile)

	if _player.has_signal("momentum_projectile_spawned"):
		_player.emit_signal("momentum_projectile_spawned", projectile, direction)

	var root := get_tree().current_scene
	if root == null:
		return false
	root.call_deferred("add_child", projectile)

	if projectile.has_method("launch"):
		projectile.call_deferred("launch", direction)
	else:
		projectile.call_deferred("apply_central_impulse", direction * _projectile_speed_for_weapon(weapon_id))
	return true


func _apply_positron_beam(origin: Vector2, direction: Vector2, hits: Array[Node], delta: float) -> void:
	var damage := positron_damage_per_second * delta
	var planet_damage := positron_planet_damage_per_second * delta
	var damaged_planet := false

	for target in hits:
		if target == null or not is_instance_valid(target):
			continue

		if _is_destructible_planet(target):
			target.call("apply_spacetime_damage", planet_damage, target.global_position, &"positron_beam")
			damaged_planet = true
			continue

		if target.has_method("take_damage") and _is_hostile_target(target):
			_stamp_player_weapon_hit(target, &"positron_beam", damage)
			target.call("take_damage", damage)

	if positron_recoil > 0.0:
		CombatStatus.add_velocity(_player, -direction * positron_recoil * delta)

	if damaged_planet:
		_stamp_positron_scar(origin + direction * beam_range * 0.55)


func _apply_gravity_wave_beam(origin: Vector2, direction: Vector2, hits: Array[Node], delta: float) -> void:
	var force := gravity_wave_force_per_second * delta
	var axis_pull := gravity_wave_axis_pull_per_second * delta
	var damage := gravity_wave_damage_per_second * delta

	for target in hits:
		if target == null or not is_instance_valid(target):
			continue

		var target_2d := target as Node2D
		if target_2d == null:
			continue

		var offset := target_2d.global_position - origin
		var along_distance := offset.dot(direction)
		var along := clampf(along_distance / maxf(beam_range, 1.0), 0.0, 1.0)
		var axis_point := origin + direction * clampf(along_distance, 0.0, beam_range)
		var to_axis := axis_point - target_2d.global_position
		var axis_dir := to_axis.normalized()
		if axis_dir == Vector2.ZERO:
			axis_dir = direction.orthogonal()
		var warp_dir := (axis_dir + direction * gravity_wave_forward_drift).normalized()
		var hostile_multiplier := gravity_wave_enemy_pull_multiplier if _is_hostile_target(target_2d) else 1.0
		var projectile_multiplier := gravity_wave_projectile_force_multiplier if target_2d.is_in_group("enemy_projectiles") else 1.0
		var falloff := lerpf(1.0, 0.48, along)

		if _is_destructible_planet(target_2d):
			_apply_gravity_wave_to_planet(target_2d, warp_dir, falloff, delta)
			continue

		CombatStatus.add_velocity(target_2d, warp_dir * (force + axis_pull) * hostile_multiplier * projectile_multiplier * falloff)
		target_2d.set_meta(&"gravity_wave_beam_pressure", clampf(1.0 - along * 0.42, 0.0, 1.0))

		if target.has_method("take_damage") and _is_hostile_target(target):
			_stamp_player_weapon_hit(target, &"gravity_wave_beam", damage)
			target.call("take_damage", damage)

	_stamp_gravity_wave_resonance(origin, direction)


func _apply_chronal_refraction_beam(origin: Vector2, direction: Vector2, hits: Array[Node], delta: float) -> void:
	_chronal_phantoms_this_tick = 0
	var generation := _chronal_async_generation
	var stacks := maxi(_powerup_stack_count(&"chronal_refraction_beam"), 1)
	var slow := clampf(chronal_slow_multiplier - 0.035 * float(stacks - 1), 0.25, 0.86)
	var duration := chronal_slow_duration * (1.0 + 0.12 * float(stacks - 1))
	var damage := chronal_refraction_damage_per_second * delta * (1.0 + 0.18 * float(stacks - 1))
	var impulse := direction * chronal_delayed_impulse * (1.0 + 0.14 * float(stacks - 1))

	for target in hits:
		var target_2d := target as Node2D
		if target_2d == null or not is_instance_valid(target_2d):
			continue
		if target_2d.is_in_group("Player"):
			continue

		var body_velocity := _body_velocity(target_2d)
		var lateral := direction.orthogonal()
		if lateral.dot(body_velocity) < 0.0:
			lateral = -lateral
		var desync_impulse := lateral * chronal_desync_lateral_impulse * (1.0 + 0.08 * float(stacks - 1))

		CombatStatus.apply_local_time_scale(target_2d, slow, duration)
		target_2d.set_meta(&"chronal_refraction_delay", chronal_delay_seconds)
		target_2d.set_meta(&"chronal_phantom_position", target_2d.global_position - body_velocity * chronal_delay_seconds)
		target_2d.set_meta(&"chronal_desync_impulse", desync_impulse)

		if target_2d.has_method("take_damage") and _is_hostile_target(target_2d):
			_stamp_player_weapon_hit(target_2d, &"chronal_refraction_beam", damage)
			target_2d.call("take_damage", damage)

		_spawn_chronal_echoes(target_2d, body_velocity)
		_apply_delayed_chronal_chain(target_2d, impulse + desync_impulse, damage * 0.9, chronal_delay_seconds, generation)

	_stamp_chronal_refraction_zone(origin, direction, stacks)


func _stamp_positron_scar(position: Vector2) -> void:
	var now := _now_seconds()
	if now - _last_positron_scar_time < positron_scar_interval:
		return
	_last_positron_scar_time = now

	var scars := _get_gravity_scar_manager()
	if scars == null or not scars.has_method("create_gravity_scar"):
		return
	scars.call(
		"create_gravity_scar",
		position,
		260.0,
		GravityScarManager.ScarType.TEMPORAL_RIP,
		0.46,
		30.0,
		&"positron_beam"
	)


func _stamp_gravity_wave_resonance(origin: Vector2, direction: Vector2) -> void:
	var now := _now_seconds()
	if now - _last_wave_resonance_time < gravity_wave_resonance_interval:
		return
	_last_wave_resonance_time = now

	var resonance := _get_resonance_manager()
	if resonance == null or not resonance.has_method("create_manual_resonance_zone"):
		return
	resonance.call(
		"create_manual_resonance_zone",
		origin + direction * beam_range * 0.42,
		260.0,
		GravityResonanceManager.ZoneType.COMPRESSION,
		0.48,
		1.0
	)


func _apply_gravity_wave_to_planet(target: Node2D, warp_dir: Vector2, falloff: float, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var displacement := warp_dir * gravity_wave_planet_displacement_per_second * falloff * delta
	target.global_position += displacement
	target.set_meta(&"gravity_wave_beam_pressure", falloff)
	target.set_meta(&"gravity_wave_displacement", displacement)

	var now := _now_seconds()
	if now - _last_wave_planet_fracture_time < gravity_wave_planet_fracture_interval:
		return
	_last_wave_planet_fracture_time = now

	if target.has_method("apply_spacetime_damage"):
		target.call(
			"apply_spacetime_damage",
			gravity_wave_planet_damage_per_second * falloff * maxf(delta, 0.016),
			target.global_position,
			&"gravity_wave_beam"
		)


func _stamp_chronal_refraction_zone(origin: Vector2, direction: Vector2, stacks: int) -> void:
	var now := _now_seconds()
	if now - _last_chronal_zone_time < chronal_zone_interval:
		return
	_last_chronal_zone_time = now

	var resonance := _get_resonance_manager()
	if resonance != null and resonance.has_method("create_manual_resonance_zone"):
		resonance.call(
			"create_manual_resonance_zone",
			origin + direction * beam_range * 0.38,
			230.0 + 28.0 * float(stacks - 1),
			GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
			0.54 + 0.06 * float(stacks - 1),
			1.35
		)

	var anomaly := _get_anomaly_director()
	if anomaly != null and anomaly.has_method("record_chronal_refraction"):
		anomaly.call(
			"record_chronal_refraction",
			origin + direction * beam_range * 0.38,
			direction,
			0.54 + 0.08 * float(stacks - 1),
			260.0 + 32.0 * float(stacks - 1)
		)


func _apply_delayed_chronal_chain(target: Node2D, impulse: Vector2, damage: float, delay: float, generation: int) -> void:
	await get_tree().create_timer(maxf(delay, 0.02)).timeout
	if generation != _chronal_async_generation:
		return
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	CombatStatus.add_velocity(target, impulse)
	CombatStatus.apply_local_time_scale(target, 0.72, 0.22)
	if target.has_method("take_damage") and _is_hostile_target(target):
		_stamp_player_weapon_hit(target, &"chronal_refraction_beam", damage)
		target.call("take_damage", damage)
	_stamp_chronal_echo_zone(target.global_position)


func _spawn_chronal_echoes(target: Node2D, body_velocity: Vector2) -> void:
	for echo_index in range(maxi(chronal_echo_count, 1)):
		if _chronal_phantoms_this_tick >= chronal_echo_max_per_tick:
			return
		var echo_delay := chronal_delay_seconds + chronal_echo_spacing * float(echo_index)
		var phantom_position := target.global_position - body_velocity * echo_delay
		_spawn_chronal_phantom(target, phantom_position, echo_index)
		_chronal_phantoms_this_tick += 1


func _spawn_chronal_phantom(target: Node2D, phantom_position: Vector2, echo_index: int) -> void:
	var root := get_tree().current_scene
	if root == null or target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var line := _acquire_chronal_trace(root)
	line.antialiased = true
	line.width = maxf(1.2, 2.6 - float(echo_index) * 0.35)
	line.default_color = Color(chronal_color.r, chronal_color.g, chronal_color.b, _visual_alpha(0.38 - float(echo_index) * 0.055))
	line.points = PackedVector2Array([phantom_position, target.global_position])
	line.top_level = true
	line.z_index = 34
	line.modulate = Color.WHITE
	line.visible = true
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.38 + float(echo_index) * 0.05)
	tween.tween_callback(Callable(self, "_release_chronal_trace").bind(line))


func _acquire_chronal_trace(root: Node) -> Line2D:
	for line in _chronal_trace_pool:
		if line != null and is_instance_valid(line) and not line.visible:
			if line.get_parent() == null:
				root.add_child(line)
			elif line.get_parent() != root:
				line.reparent(root)
			return line
	var line := Line2D.new()
	line.name = "ChronalPhantomTrace"
	_chronal_trace_pool.append(line)
	root.add_child(line)
	return line


func _release_chronal_trace(line: Line2D) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.visible = false
	line.modulate = Color.WHITE


func _stamp_chronal_echo_zone(position: Vector2) -> void:
	var now := _now_seconds()
	if now - _last_chronal_echo_zone_time < chronal_echo_zone_interval:
		return
	_last_chronal_echo_zone_time = now
	var resonance := _get_resonance_manager()
	if resonance == null or not resonance.has_method("create_manual_resonance_zone"):
		return
	resonance.call(
		"create_manual_resonance_zone",
		position,
		150.0,
		GravityResonanceManager.ZoneType.TEMPORAL_SCAR,
		0.38,
		0.62
	)


func _projectile_payload(weapon_id: StringName, shot_index: int, shot_count: int) -> Dictionary:
	var color := _weapon_color(weapon_id)
	var payload := {
		"weapon_id": weapon_id,
		"display_name": _display_name(weapon_id),
		"initial_speed": _projectile_speed_for_weapon(weapon_id),
		"damage_min": _projectile_damage_min_for_weapon(weapon_id),
		"damage_max": _projectile_damage_max_for_weapon(weapon_id),
		"gravity_constant": _projectile_gravity_for_weapon(weapon_id),
		"gravity_pull_radius": 2000.0,
		"player_gravity_deadzone_radius": 520.0,
		"windowkill_visual_scale": _projectile_visual_scale_for_weapon(weapon_id),
		"vector_core_color": _safe_projectile_core_color(color),
		"vector_trail_fade_color": _projectile_trail_color_for_weapon(weapon_id),
		"weapon_axis_impulse": 0.0,
		"weapon_temporal_slow_multiplier": 1.0,
		"weapon_temporal_slow_duration": 0.0,
		"weapon_pierce_count": 0,
		"weapon_resonance_zone_type": -1,
		"weapon_resonance_radius": 0.0,
		"weapon_resonance_intensity": 0.0,
		"weapon_curve_force": 0.0,
		"weapon_curve_side": _projectile_side_for_index(shot_index, shot_count),
		"weapon_curve_frequency": 7.0,
		"weapon_planet_damage": 0.0,
		"weapon_radial_impulse": 0.0,
		"weapon_tangent_impulse": 0.0,
		"weapon_field_radius": 0.0,
		"weapon_field_force": 0.0,
		"weapon_field_damage": 0.0,
		"weapon_field_slow_multiplier": 1.0,
		"weapon_field_slow_duration": 0.0,
		"weapon_field_max_targets": 18,
		"weapon_scar_type": -1,
		"weapon_scar_radius": 0.0,
		"weapon_scar_intensity": 0.0,
		"weapon_scar_duration": 0.0,
		"phase_offset": float(_projectile_pattern_index * 3 + shot_index) * 0.73,
		"relativistic_rail_stacks": 0,
		"vacuum_collapse_stacks": 0,
	}

	match weapon_id:
		&"relativistic_rail":
			payload["weapon_axis_impulse"] = relativistic_rail_impulse
			payload["weapon_pierce_count"] = 1
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.SLIPSTREAM
			payload["weapon_resonance_radius"] = 145.0
			payload["weapon_resonance_intensity"] = 0.34
			payload["relativistic_rail_stacks"] = 1
			payload["gravity_pull_radius"] = 1500.0
			payload["player_gravity_deadzone_radius"] = 620.0
		&"barycentric_splitter":
			payload["weapon_curve_force"] = barycentric_splitter_curve_force
			payload["weapon_axis_impulse"] = barycentric_splitter_axis_impulse
			payload["weapon_temporal_slow_multiplier"] = 0.82
			payload["weapon_temporal_slow_duration"] = 0.16
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.HARMONIC_ORBIT
			payload["weapon_resonance_radius"] = 132.0
			payload["weapon_resonance_intensity"] = 0.31
		&"vacuum_collapse_seed":
			payload["vacuum_collapse_stacks"] = vacuum_seed_collapse_stacks
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.COMPRESSION
			payload["weapon_resonance_radius"] = vacuum_seed_resonance_radius
			payload["weapon_resonance_intensity"] = 0.46
			payload["weapon_planet_damage"] = 34.0
			payload["gravity_pull_radius"] = 1700.0
			payload["player_gravity_deadzone_radius"] = 760.0
		&"temporal_splinter":
			payload["weapon_temporal_slow_multiplier"] = 0.55
			payload["weapon_temporal_slow_duration"] = 0.42
			payload["weapon_pierce_count"] = 1
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.TEMPORAL_SCAR
			payload["weapon_resonance_radius"] = 118.0
			payload["weapon_resonance_intensity"] = 0.34
			payload["weapon_curve_force"] = 180.0
			payload["weapon_curve_frequency"] = 9.5
			payload["weapon_field_radius"] = 165.0
			payload["weapon_field_slow_multiplier"] = 0.68
			payload["weapon_field_slow_duration"] = 0.28
			payload["weapon_field_max_targets"] = 10
			payload["weapon_scar_type"] = GravityScarManager.ScarType.TEMPORAL_RIP
			payload["weapon_scar_radius"] = 120.0
			payload["weapon_scar_intensity"] = 0.24
			payload["weapon_scar_duration"] = 16.0
		&"inversion_disc":
			payload["weapon_radial_impulse"] = 210.0
			payload["weapon_tangent_impulse"] = 160.0
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.INVERSION
			payload["weapon_resonance_radius"] = 210.0
			payload["weapon_resonance_intensity"] = 0.46
			payload["weapon_field_radius"] = 230.0
			payload["weapon_field_force"] = 360.0
			payload["weapon_field_damage"] = 8.0
			payload["weapon_field_slow_multiplier"] = 0.9
			payload["weapon_field_slow_duration"] = 0.18
			payload["weapon_scar_type"] = GravityScarManager.ScarType.INVERSION_WAKE
			payload["weapon_scar_radius"] = 190.0
			payload["weapon_scar_intensity"] = 0.36
			payload["weapon_scar_duration"] = 22.0
			payload["gravity_pull_radius"] = 2100.0
		&"harmonic_needle":
			payload["weapon_axis_impulse"] = 95.0
			payload["weapon_tangent_impulse"] = 150.0
			payload["weapon_pierce_count"] = 2
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.HARMONIC_ORBIT
			payload["weapon_resonance_radius"] = 118.0
			payload["weapon_resonance_intensity"] = 0.38
			payload["weapon_curve_force"] = 120.0
			payload["weapon_curve_frequency"] = 12.0
			payload["weapon_field_radius"] = 120.0
			payload["weapon_field_force"] = 180.0
			payload["weapon_field_max_targets"] = 8
		&"shear_comet":
			payload["weapon_axis_impulse"] = 180.0
			payload["weapon_tangent_impulse"] = 280.0
			payload["weapon_curve_force"] = 740.0
			payload["weapon_curve_side"] = -1.0 if _projectile_pattern_index % 2 == 0 else 1.0
			payload["weapon_curve_frequency"] = 4.4
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.SLIPSTREAM
			payload["weapon_resonance_radius"] = 190.0
			payload["weapon_resonance_intensity"] = 0.44
			payload["weapon_field_radius"] = 190.0
			payload["weapon_field_force"] = 260.0
			payload["weapon_field_max_targets"] = 12
			payload["weapon_scar_type"] = GravityScarManager.ScarType.VELOCITY_SHEAR
			payload["weapon_scar_radius"] = 175.0
			payload["weapon_scar_intensity"] = 0.32
			payload["weapon_scar_duration"] = 18.0
		&"singularity_pin":
			payload["vacuum_collapse_stacks"] = 1
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.COMPRESSION
			payload["weapon_resonance_radius"] = 220.0
			payload["weapon_resonance_intensity"] = 0.52
			payload["weapon_field_radius"] = 260.0
			payload["weapon_field_force"] = -620.0
			payload["weapon_field_damage"] = 14.0
			payload["weapon_planet_damage"] = 42.0
			payload["gravity_pull_radius"] = 1800.0
			payload["player_gravity_deadzone_radius"] = 700.0
			payload["weapon_scar_type"] = GravityScarManager.ScarType.CURVATURE
			payload["weapon_scar_radius"] = 230.0
			payload["weapon_scar_intensity"] = 0.44
			payload["weapon_scar_duration"] = 28.0
		&"event_horizon_shard":
			payload["vacuum_collapse_stacks"] = 2
			payload["weapon_temporal_slow_multiplier"] = 0.58
			payload["weapon_temporal_slow_duration"] = 0.46
			payload["weapon_resonance_zone_type"] = GravityResonanceManager.ZoneType.COMPRESSION
			payload["weapon_resonance_radius"] = 285.0
			payload["weapon_resonance_intensity"] = 0.68
			payload["weapon_field_radius"] = 360.0
			payload["weapon_field_force"] = -880.0
			payload["weapon_field_damage"] = 22.0
			payload["weapon_field_slow_multiplier"] = 0.62
			payload["weapon_field_slow_duration"] = 0.42
			payload["weapon_field_max_targets"] = 28
			payload["weapon_planet_damage"] = 72.0
			payload["gravity_pull_radius"] = 1900.0
			payload["player_gravity_deadzone_radius"] = 820.0
			payload["weapon_scar_type"] = GravityScarManager.ScarType.HARMONIC_FRACTURE
			payload["weapon_scar_radius"] = 320.0
			payload["weapon_scar_intensity"] = 0.62
			payload["weapon_scar_duration"] = 34.0
		_:
			pass
	_apply_catalog_payload_overrides(payload, weapon_id)
	_apply_signature_payload_modifiers(payload, weapon_id, shot_index, shot_count)
	return payload


func _apply_catalog_payload_overrides(payload: Dictionary, weapon_id: StringName) -> void:
	var entry := _weapon_entry(weapon_id)
	if entry.is_empty():
		return
	var payload_value: Variant = entry.get("payload", {})
	if payload_value is Dictionary:
		var overrides: Dictionary = payload_value
		for key in overrides.keys():
			payload[key] = overrides[key]
	payload["weapon_id"] = weapon_id
	payload["display_name"] = _display_name(weapon_id)
	if entry.has("color"):
		var color := _color_from_variant(entry.get("color"), _weapon_color(weapon_id))
		payload["vector_core_color"] = _safe_projectile_core_color(color)
	if entry.has("trail_color"):
		payload["vector_trail_fade_color"] = _color_from_variant(entry.get("trail_color"), _projectile_trail_color_for_weapon(weapon_id))


func _apply_signature_payload_modifiers(payload: Dictionary, weapon_id: StringName, shot_index: int, shot_count: int) -> void:
	var alternating_side := -1.0 if (_projectile_pattern_index + shot_index) % 2 == 0 else 1.0
	var shot_ratio := float(shot_index) / maxf(float(maxi(shot_count - 1, 1)), 1.0)
	match weapon_id:
		&"lensing_flak":
			payload["weapon_curve_side"] = _projectile_side_for_index(shot_index, shot_count) if shot_count > 1 else alternating_side
			payload["weapon_curve_frequency"] = 10.5 + float(shot_index) * 1.1
			payload["weapon_field_force"] = -140.0 + shot_ratio * 120.0
			_tint_projectile_payload(payload, Color(0.24, 1.0, 0.92, 1.0), 0.18 + shot_ratio * 0.12)
		&"vector_prism":
			var prism_tints: Array[Color] = [
				Color(0.28, 1.0, 0.92, 1.0),
				Color(0.42, 0.78, 1.0, 1.0),
				Color(0.82, 0.58, 1.0, 1.0),
				Color(0.52, 1.0, 0.54, 1.0),
				Color(1.0, 0.88, 0.34, 1.0),
			]
			_tint_projectile_payload(payload, prism_tints[shot_index % prism_tints.size()], 0.32)
			payload["weapon_curve_side"] = _projectile_side_for_index(shot_index, shot_count)
			payload["weapon_field_force"] = 130.0 + absf(float(shot_index) - float(shot_count - 1) * 0.5) * 38.0
		&"graviton_bloom":
			payload["weapon_field_force"] = -360.0 - 42.0 * float(shot_index % 3)
			payload["weapon_resonance_intensity"] = 0.32 + 0.04 * float(shot_index % 3)
			payload["phase_offset"] = float(_projectile_pattern_index) * 0.9 + shot_ratio * TAU
			_tint_projectile_payload(payload, Color(0.18, 0.86, 1.0, 1.0), 0.18)
		&"harmonic_bloom":
			payload["weapon_tangent_impulse"] = 220.0 + 34.0 * float(shot_index % 2)
			payload["weapon_curve_side"] = alternating_side
			payload["weapon_resonance_intensity"] = 0.36 + shot_ratio * 0.16
			payload["phase_offset"] = float(shot_index) * TAU / maxf(float(shot_count), 1.0)
			_tint_projectile_payload(payload, Color(0.72, 1.0, 0.34, 1.0), 0.2 + shot_ratio * 0.12)
		&"chronal_needleloom":
			payload["weapon_temporal_slow_duration"] = 0.24 + 0.08 * float(shot_index + 1)
			payload["weapon_curve_side"] = alternating_side
			payload["phase_offset"] = float(_projectile_pattern_index + shot_index) * 1.04
			_tint_projectile_payload(payload, Color(0.84, 0.52, 1.0, 1.0), 0.2)
		&"null_rebounder":
			payload["weapon_radial_impulse"] = 280.0 + 70.0 * float(shot_index % 2)
			payload["weapon_tangent_impulse"] = 170.0 * alternating_side
			payload["weapon_curve_side"] = -alternating_side
			_tint_projectile_payload(payload, Color(1.0, 0.48, 0.18, 1.0), 0.22)
		&"tidal_skein":
			payload["weapon_curve_side"] = sin(float(_projectile_pattern_index + shot_index) * 0.75)
			var tidal_side := float(payload.get("weapon_curve_side", 0.0))
			payload["weapon_field_force"] = -220.0 - 80.0 * absf(tidal_side)
			payload["phase_offset"] = float(_projectile_pattern_index) * 0.82 + float(shot_index) * 1.7
			_tint_projectile_payload(payload, Color(0.1, 0.82, 1.0, 1.0), 0.16)
		&"scar_carver":
			payload["weapon_tangent_impulse"] = 300.0 * alternating_side
			payload["weapon_scar_duration"] = 30.0 if shot_index == 0 else 18.0
			payload["weapon_scar_intensity"] = 0.54 if shot_index == 0 else 0.38
		&"singularity_kite":
			payload["weapon_curve_side"] = alternating_side
			payload["weapon_curve_force"] = 760.0 + 80.0 * clampf(float(_projectile_pattern_index % 4) / 3.0, 0.0, 1.0)
			payload["weapon_field_force"] = -700.0 - 80.0 * float(_projectile_pattern_index % 2)
		&"phase_suture":
			payload["weapon_curve_side"] = -_projectile_side_for_index(shot_index, shot_count)
			payload["weapon_temporal_slow_duration"] = 0.52 if shot_index == 0 else 0.34
			payload["weapon_field_slow_duration"] = 0.38 if shot_index == 0 else 0.22
		&"apex_vector_spear":
			var flow_intensity := _player_flow_intensity()
			if flow_intensity > 0.0:
				payload["weapon_axis_impulse"] = float(payload.get("weapon_axis_impulse", 0.0)) + 260.0 * flow_intensity
				payload["weapon_tangent_impulse"] = float(payload.get("weapon_tangent_impulse", 0.0)) + 190.0 * flow_intensity
				payload["damage_min"] = float(payload.get("damage_min", 0.0)) * (1.0 + 0.18 * flow_intensity)
				payload["damage_max"] = float(payload.get("damage_max", 0.0)) * (1.0 + 0.24 * flow_intensity)
				payload["weapon_resonance_intensity"] = float(payload.get("weapon_resonance_intensity", 0.0)) + 0.18 * flow_intensity
				_tint_projectile_payload(payload, Color(0.96, 1.0, 0.62, 1.0), 0.24 + flow_intensity * 0.24)
		&"mass_driver":
			payload["relativistic_rail_stacks"] = maxi(int(payload.get("relativistic_rail_stacks", 0)), 2)
			payload["weapon_planet_damage"] = maxf(float(payload.get("weapon_planet_damage", 0.0)), 124.0)
			payload["weapon_axis_impulse"] = maxf(float(payload.get("weapon_axis_impulse", 0.0)), 760.0)
		&"inertia_maul":
			payload["weapon_temporal_slow_multiplier"] = 0.72
			payload["weapon_temporal_slow_duration"] = 0.22
			payload["weapon_field_slow_multiplier"] = 0.74
			payload["weapon_field_slow_duration"] = 0.32
			payload["gravity_pull_radius"] = 2400.0
		_:
			pass


func _tint_projectile_payload(payload: Dictionary, tint: Color, amount: float) -> void:
	var core := _color_from_variant(payload.get("vector_core_color", tint), tint)
	var trail := _color_from_variant(payload.get("vector_trail_fade_color", tint), tint)
	var weight := clampf(amount, 0.0, 1.0)
	payload["vector_core_color"] = _safe_projectile_core_color(core.lerp(tint, weight))
	payload["vector_trail_fade_color"] = trail.lerp(Color(tint.r, tint.g, tint.b, trail.a), weight)


func _player_flow_intensity() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	if not bool(_player.get_meta(&"momentum_flow_active", false)):
		return 0.0
	return clampf(float(_player.get_meta(&"momentum_flow_intensity", 0.0)), 0.0, 1.0)


func _apply_projectile_payload(projectile: Node, payload: Dictionary) -> void:
	if projectile == null:
		return
	if projectile.has_method("apply_weapon_payload"):
		projectile.call("apply_weapon_payload", payload)
		return

	projectile.set_meta(&"weapon_payload", payload.duplicate(true))
	for key in payload.keys():
		var property_name := String(key)
		if projectile.get(property_name) != null:
			projectile.set(property_name, payload[key])


func _refresh_payload_from_projectile(projectile: Node) -> void:
	if projectile == null or not projectile.has_meta(&"weapon_payload"):
		return
	var payload_value: Variant = projectile.get_meta(&"weapon_payload")
	if typeof(payload_value) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = payload_value
	for property_name in [
		"initial_speed",
		"damage_min",
		"damage_max",
		"gravity_constant",
		"gravity_pull_radius",
		"player_gravity_deadzone_radius",
	]:
		var value: Variant = projectile.get(property_name)
		if value != null:
			payload[property_name] = value
	projectile.set_meta(&"weapon_payload", payload.duplicate(true))


func _projectile_prediction_state(weapon_id: StringName) -> Dictionary:
	if not _is_projectile_weapon(weapon_id):
		return {"is_projectile": false}
	var color := _weapon_color(weapon_id)
	var shot_count := _projectile_count_for_weapon(weapon_id)
	var payload := _projectile_payload(weapon_id, 0, shot_count)
	return {
		"is_projectile": true,
		"weapon_id": weapon_id,
		"display_name": _display_name(weapon_id),
		"initial_speed": _projectile_speed_for_weapon(weapon_id),
		"gravity_constant": _projectile_gravity_for_weapon(weapon_id),
		"gravity_pull_radius": float(payload.get("gravity_pull_radius", 2000.0)),
		"player_gravity_deadzone_radius": float(payload.get("player_gravity_deadzone_radius", 520.0)),
		"spawn_offset": projectile_spawn_offset,
		"collision_radius": projectile_prediction_collision_radius * _projectile_visual_scale_for_weapon(weapon_id),
		"prediction_color": Color(color.r, color.g, color.b, 0.62),
		"danger_color": _projectile_trail_color_for_weapon(weapon_id),
		"tracks": _projectile_prediction_tracks(weapon_id, shot_count),
	}


func _projectile_prediction_tracks(weapon_id: StringName, shot_count: int = -1) -> Array:
	var tracks: Array = []
	if shot_count <= 0:
		shot_count = _projectile_count_for_weapon(weapon_id)
	var base_direction := Vector2.RIGHT
	var visual_scale := _projectile_visual_scale_for_weapon(weapon_id)
	var fallback_color := _weapon_color(weapon_id)
	var fallback_trail := _projectile_trail_color_for_weapon(weapon_id)
	for shot_index in range(shot_count):
		var shot_direction := _projectile_direction_for_index(weapon_id, base_direction, shot_index, shot_count)
		if shot_direction.length_squared() <= 0.001:
			shot_direction = base_direction
		var side_offset := _projectile_side_offset_for_index(weapon_id, shot_direction, shot_index, shot_count)
		var payload := _projectile_payload(weapon_id, shot_index, shot_count)
		var core_color := _color_from_variant(payload.get("vector_core_color", fallback_color), fallback_color)
		var trail_color := _color_from_variant(payload.get("vector_trail_fade_color", fallback_trail), fallback_trail)
		var alpha := 0.72 if shot_index == 0 else 0.52
		tracks.append({
			"shot_index": shot_index,
			"shot_count": shot_count,
			"direction_offset": shot_direction.angle(),
			"spawn_offset": projectile_spawn_offset,
			"spawn_offset_vector": Vector2(projectile_spawn_offset, 0.0) + side_offset,
			"projectile_speed": float(payload.get("initial_speed", _projectile_speed_for_weapon(weapon_id))),
			"gravity_constant": float(payload.get("gravity_constant", _projectile_gravity_for_weapon(weapon_id))),
			"gravity_radius": float(payload.get("gravity_pull_radius", 2000.0)),
			"player_gravity_deadzone_radius": float(payload.get("player_gravity_deadzone_radius", 520.0)),
			"collision_radius": projectile_prediction_collision_radius * visual_scale,
			"projectile_mass": 0.25,
			"prediction_color": Color(core_color.r, core_color.g, core_color.b, alpha),
			"danger_color": trail_color,
			"ghost_color": Color(core_color.r, core_color.g, core_color.b, 0.20 if shot_index == 0 else 0.14),
			"weapon_curve_force": float(payload.get("weapon_curve_force", 0.0)),
			"weapon_curve_side": float(payload.get("weapon_curve_side", 0.0)),
			"weapon_curve_frequency": float(payload.get("weapon_curve_frequency", 7.0)),
			"phase_offset": float(payload.get("phase_offset", 0.0)),
			"relativistic_rail_stacks": int(payload.get("relativistic_rail_stacks", 0)),
			"relativistic_rail_acceleration": 640.0,
			"relativistic_rail_speed_cap": 2850.0,
			"line_width_scale": 1.0 if shot_index == 0 else 0.86,
		})
	return tracks


func _projectile_count_for_weapon(weapon_id: StringName) -> int:
	var entry := _weapon_entry(weapon_id)
	if entry.has("shot_count"):
		return clampi(int(entry.get("shot_count", 1)), 1, 6)
	if weapon_id == &"barycentric_splitter":
		return 2
	if weapon_id == &"temporal_splinter":
		return 3
	if weapon_id == &"harmonic_needle":
		return 2
	return 1


func _projectile_direction_for_index(
	weapon_id: StringName,
	direction: Vector2,
	shot_index: int,
	shot_count: int
) -> Vector2:
	var entry := _weapon_entry(weapon_id)
	if entry.has("pattern"):
		return _catalog_projectile_direction(entry, direction, shot_index, shot_count)
	if weapon_id == &"temporal_splinter" and shot_count > 1:
		var spread := (float(shot_index) - float(shot_count - 1) * 0.5) * 0.13
		return direction.rotated(spread).normalized()
	if weapon_id == &"harmonic_needle" and shot_count > 1:
		var spread := -0.035 if shot_index == 0 else 0.035
		return direction.rotated(spread).normalized()
	if weapon_id == &"barycentric_splitter" and shot_count > 1:
		var spread := -0.08 if shot_index == 0 else 0.08
		return direction.rotated(spread).normalized()
	if weapon_id == &"shear_comet":
		var drift := -0.1 if _projectile_pattern_index % 2 == 0 else 0.1
		return direction.rotated(drift).normalized()
	if weapon_id == &"inversion_disc":
		var drift := 0.04 if _projectile_pattern_index % 2 == 0 else -0.04
		return direction.rotated(drift).normalized()
	return direction


func _catalog_projectile_direction(
	entry: Dictionary,
	direction: Vector2,
	shot_index: int,
	shot_count: int
) -> Vector2:
	if shot_count <= 1:
		return direction
	var pattern := StringName(str(entry.get("pattern", &"single")))
	var spread := float(entry.get("spread_radians", 0.12))
	var middle := float(shot_count - 1) * 0.5
	var offset := float(shot_index) - middle
	match pattern:
		&"parallel":
			return direction
		&"spread":
			return direction.rotated(offset * spread).normalized()
		&"braid":
			var parity := -1.0 if (_projectile_pattern_index + shot_index) % 2 == 0 else 1.0
			return direction.rotated(offset * spread + parity * spread * 0.34).normalized()
		&"converge":
			var side := _projectile_side_for_index(shot_index, shot_count)
			if absf(side) <= 0.001:
				return direction
			return direction.rotated(-signf(side) * spread).normalized()
		&"scissor":
			return direction.rotated(offset * spread * 0.82).normalized()
		&"helix":
			var phase := float(_projectile_pattern_index) * 0.82 + float(shot_index) * TAU / float(shot_count)
			return direction.rotated(offset * spread * 0.58 + sin(phase) * spread * 0.22).normalized()
		&"pinwheel":
			var phase := sin(float(_projectile_pattern_index) * 0.55) * spread * 0.22
			return direction.rotated(offset * spread * 0.86 + phase).normalized()
		&"ring":
			return direction.rotated(offset * spread).normalized()
		_:
			return direction


func _projectile_side_offset_for_index(
	weapon_id: StringName,
	direction: Vector2,
	shot_index: int,
	shot_count: int
) -> Vector2:
	if shot_count <= 1:
		return Vector2.ZERO
	return direction.orthogonal() * _projectile_side_for_index(shot_index, shot_count) * projectile_side_offset


func _projectile_side_for_index(shot_index: int, shot_count: int) -> float:
	if shot_count <= 1:
		return 0.0
	if shot_count == 2:
		return -1.0 if shot_index == 0 else 1.0
	return float(shot_index) - float(shot_count - 1) * 0.5


func _projectile_fire_interval(weapon_id: StringName) -> float:
	var catalog_value := _catalog_float_or_base(weapon_id, "fire_interval", -1.0)
	if catalog_value >= 0.0:
		return maxf(catalog_value, 0.05)
	match weapon_id:
		&"relativistic_rail":
			return maxf(relativistic_rail_fire_interval, 0.05)
		&"barycentric_splitter":
			return maxf(barycentric_splitter_fire_interval, 0.05)
		&"vacuum_collapse_seed":
			return maxf(vacuum_seed_fire_interval, 0.05)
		&"temporal_splinter":
			return maxf(temporal_splinter_fire_interval, 0.05)
		&"inversion_disc":
			return maxf(inversion_disc_fire_interval, 0.05)
		&"harmonic_needle":
			return maxf(harmonic_needle_fire_interval, 0.05)
		&"shear_comet":
			return maxf(shear_comet_fire_interval, 0.05)
		&"singularity_pin":
			return maxf(singularity_pin_fire_interval, 0.05)
		&"event_horizon_shard":
			return maxf(event_horizon_shard_fire_interval, 0.05)
	return maxf(vector_bolt_fire_interval, 0.05)


func _projectile_energy_cost(weapon_id: StringName) -> float:
	var catalog_value := _catalog_float_or_base(weapon_id, "energy_per_shot", -1.0)
	if catalog_value >= 0.0:
		return catalog_value
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_energy_per_shot
		&"barycentric_splitter":
			return barycentric_splitter_energy_per_shot
		&"vacuum_collapse_seed":
			return vacuum_seed_energy_per_shot
		&"temporal_splinter":
			return temporal_splinter_energy_per_shot
		&"inversion_disc":
			return inversion_disc_energy_per_shot
		&"harmonic_needle":
			return harmonic_needle_energy_per_shot
		&"shear_comet":
			return shear_comet_energy_per_shot
		&"singularity_pin":
			return singularity_pin_energy_per_shot
		&"event_horizon_shard":
			return event_horizon_shard_energy_per_shot
	return vector_bolt_energy_per_shot


func _field_energy_cost(weapon_id: StringName) -> float:
	var entry := _field_weapon_entry(weapon_id)
	if entry.has("energy_per_use"):
		return maxf(float(entry.get("energy_per_use", 0.0)), 0.0)
	return 0.0


func _field_fire_interval(weapon_id: StringName) -> float:
	var entry := _field_weapon_entry(weapon_id)
	if entry.has("fire_interval"):
		return maxf(float(entry.get("fire_interval", 0.2)), 0.05)
	return 0.35


func _projectile_speed_for_weapon(weapon_id: StringName) -> float:
	var catalog_value := _catalog_float_or_base(weapon_id, "speed", -1.0)
	if catalog_value >= 0.0:
		return catalog_value
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_speed
		&"barycentric_splitter":
			return barycentric_splitter_speed
		&"vacuum_collapse_seed":
			return vacuum_seed_speed
		&"temporal_splinter":
			return temporal_splinter_speed
		&"inversion_disc":
			return inversion_disc_speed
		&"harmonic_needle":
			return harmonic_needle_speed
		&"shear_comet":
			return shear_comet_speed
		&"singularity_pin":
			return singularity_pin_speed
		&"event_horizon_shard":
			return event_horizon_shard_speed
	return vector_bolt_speed


func _projectile_damage_min_for_weapon(weapon_id: StringName) -> float:
	var catalog_value := _catalog_float_or_base(weapon_id, "damage_min", -1.0)
	if catalog_value >= 0.0:
		return catalog_value
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_damage_min
		&"barycentric_splitter":
			return barycentric_splitter_damage_min
		&"vacuum_collapse_seed":
			return vacuum_seed_damage_min
		&"temporal_splinter":
			return temporal_splinter_damage_min
		&"inversion_disc":
			return inversion_disc_damage_min
		&"harmonic_needle":
			return harmonic_needle_damage_min
		&"shear_comet":
			return shear_comet_damage_min
		&"singularity_pin":
			return singularity_pin_damage_min
		&"event_horizon_shard":
			return event_horizon_shard_damage_min
	return vector_bolt_damage_min


func _projectile_damage_max_for_weapon(weapon_id: StringName) -> float:
	var catalog_value := _catalog_float_or_base(weapon_id, "damage_max", -1.0)
	if catalog_value >= 0.0:
		return catalog_value
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_damage_max
		&"barycentric_splitter":
			return barycentric_splitter_damage_max
		&"vacuum_collapse_seed":
			return vacuum_seed_damage_max
		&"temporal_splinter":
			return temporal_splinter_damage_max
		&"inversion_disc":
			return inversion_disc_damage_max
		&"harmonic_needle":
			return harmonic_needle_damage_max
		&"shear_comet":
			return shear_comet_damage_max
		&"singularity_pin":
			return singularity_pin_damage_max
		&"event_horizon_shard":
			return event_horizon_shard_damage_max
	return vector_bolt_damage_max


func _projectile_gravity_for_weapon(weapon_id: StringName) -> float:
	var catalog_value := _catalog_float_or_base(weapon_id, "gravity_constant", -1.0)
	if catalog_value >= 0.0:
		return catalog_value
	match weapon_id:
		&"relativistic_rail":
			return vector_bolt_gravity * 0.62
		&"barycentric_splitter":
			return vector_bolt_gravity * 1.22
		&"vacuum_collapse_seed":
			return vector_bolt_gravity * 0.84
		&"temporal_splinter":
			return vector_bolt_gravity * 0.92
		&"inversion_disc":
			return vector_bolt_gravity * 1.46
		&"harmonic_needle":
			return vector_bolt_gravity * 0.74
		&"shear_comet":
			return vector_bolt_gravity * 1.08
		&"singularity_pin":
			return vector_bolt_gravity * 1.34
		&"event_horizon_shard":
			return vector_bolt_gravity * 1.18
	return vector_bolt_gravity


func _projectile_visual_scale_for_weapon(weapon_id: StringName) -> float:
	var catalog_value := _catalog_float_or_base(weapon_id, "visual_scale", -1.0)
	if catalog_value >= 0.0:
		return catalog_value
	match weapon_id:
		&"relativistic_rail":
			return 1.28
		&"barycentric_splitter":
			return 0.92
		&"vacuum_collapse_seed":
			return 1.18
		&"temporal_splinter":
			return 0.72
		&"inversion_disc":
			return 1.34
		&"harmonic_needle":
			return 0.68
		&"shear_comet":
			return 1.06
		&"singularity_pin":
			return 1.16
		&"event_horizon_shard":
			return 1.42
	return 1.18


func _projectile_trail_color_for_weapon(weapon_id: StringName) -> Color:
	var entry := _weapon_entry(weapon_id)
	if entry.has("trail_color"):
		return _color_from_variant(entry.get("trail_color"), Color(1.0, 0.35, 0.1, 0.95))
	var payload_value: Variant = entry.get("payload", {})
	if payload_value is Dictionary and (payload_value as Dictionary).has("vector_trail_fade_color"):
		return _color_from_variant((payload_value as Dictionary).get("vector_trail_fade_color"), Color(1.0, 0.35, 0.1, 0.95))
	var base_weapon := _catalog_base_weapon_id(weapon_id)
	if base_weapon != weapon_id:
		return _projectile_trail_color_for_weapon(base_weapon)
	match weapon_id:
		&"relativistic_rail":
			return Color(0.24, 0.55, 1.0, 0.9)
		&"barycentric_splitter":
			return Color(0.18, 1.0, 0.62, 0.86)
		&"vacuum_collapse_seed":
			return Color(1.0, 0.18, 0.08, 0.88)
		&"temporal_splinter":
			return Color(0.74, 0.36, 1.0, 0.82)
		&"inversion_disc":
			return Color(1.0, 0.3, 0.72, 0.86)
		&"harmonic_needle":
			return Color(0.56, 1.0, 0.58, 0.86)
		&"shear_comet":
			return Color(0.16, 0.86, 1.0, 0.9)
		&"singularity_pin":
			return Color(1.0, 0.24, 0.08, 0.9)
		&"event_horizon_shard":
			return Color(1.0, 0.12, 0.08, 0.95)
	return Color(1.0, 0.35, 0.1, 0.95)


func _minimum_energy_for_weapon(weapon_id: StringName) -> float:
	if _is_beam_weapon(weapon_id):
		return minimum_beam_tick_cost
	if _is_field_weapon(weapon_id):
		return _field_energy_cost(weapon_id)
	return maxf(_projectile_energy_cost(weapon_id), projectile_minimum_energy_buffer)


func _weapon_role(weapon_id: StringName) -> String:
	var entry := _weapon_entry(weapon_id)
	if entry.has("role"):
		return String(entry.get("role", "catalog vector profile"))
	var base_weapon := _catalog_base_weapon_id(weapon_id)
	if base_weapon != weapon_id:
		return _weapon_role(base_weapon)
	match weapon_id:
		&"relativistic_rail":
			return "velocity pierce"
		&"barycentric_splitter":
			return "linked orbit pressure"
		&"vacuum_collapse_seed":
			return "delayed compression"
		&"temporal_splinter":
			return "multi-shot local time fractures"
		&"inversion_disc":
			return "radial inversion shove"
		&"harmonic_needle":
			return "piercing orbit stitch"
		&"shear_comet":
			return "curved velocity shear"
		&"singularity_pin":
			return "pinned inward collapse"
		&"event_horizon_shard":
			return "heavy collapse anchor"
		&"positron_beam":
			return "direct fracture beam"
		&"gravity_wave_beam":
			return "field control beam"
		&"chronal_refraction_beam":
			return "local time shear"
	return "baseline vector shot"


func _weapon_play_hint(weapon_id: StringName) -> String:
	var entry := _weapon_entry(weapon_id)
	if entry.has("play_hint"):
		return String(entry.get("play_hint", ""))
	var base_weapon := _catalog_base_weapon_id(weapon_id)
	if base_weapon != weapon_id:
		return _weapon_play_hint(base_weapon)
	match weapon_id:
		&"vector_bolt":
			return "steady aim, cheap chain fuel"
		&"relativistic_rail":
			return "line up lanes after a slingshot"
		&"barycentric_splitter":
			return "tag clusters, then orbit the linked pack"
		&"vacuum_collapse_seed":
			return "plant it where enemies will drift next"
		&"temporal_splinter":
			return "slow pursuers before grazing a gravity edge"
		&"inversion_disc":
			return "push threats into fields and hazards"
		&"harmonic_needle":
			return "thread pierces through orbiting targets"
		&"shear_comet":
			return "curve shots across your travel tangent"
		&"singularity_pin":
			return "hold enemies in a collapse pocket"
		&"event_horizon_shard":
			return "commit to a heavy late-run collapse"
		&"positron_beam":
			return "burn priority targets in a clear lane"
		&"gravity_wave_beam":
			return "bend crowds into safer movement arcs"
		&"chronal_refraction_beam":
			return "desync fast enemies before escape"
	return "surf gravity, keep the chain alive"


func _play_projectile_sound(spawned: int) -> void:
	var sound := _player.get_node_or_null("BulletBlastSoundEffect") as AudioStreamPlayer
	if sound == null:
		return
	sound.pitch_scale = clampf(0.92 + float(spawned - 1) * 0.06, 0.7, 1.35)
	sound.play()


func _apply_projectile_recoil(direction: Vector2) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var recoil_value: Variant = _player.get("recoil_instability")
	if not (typeof(recoil_value) == TYPE_FLOAT or typeof(recoil_value) == TYPE_INT):
		return
	var recoil := float(recoil_value)
	if recoil <= 0.0:
		return
	CombatStatus.add_velocity(_player, -direction.rotated(randf_range(-0.22, 0.22)) * recoil)


func _restore_energy(amount: float) -> void:
	if amount <= 0.0 or _energy_component == null:
		return
	if _energy_component.has_method("restore"):
		_energy_component.call("restore", amount)


func _stamp_player_weapon_hit(target: Node, weapon_id: StringName, damage: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.set_meta(&"last_player_weapon_hit_time", _now_seconds())
	target.set_meta(&"last_player_weapon_id", String(weapon_id))
	target.set_meta(&"last_player_weapon_hit_damage", damage)


func _collect_beam_hits(origin: Vector2, direction: Vector2, width: float) -> Array[Node]:
	_query_shape.size = Vector2(beam_range, width)
	_query_params.transform = Transform2D(direction.angle(), origin + direction * beam_range * 0.5)

	var exclude: Array[RID] = []
	var collision_object := _player as CollisionObject2D
	if collision_object != null:
		exclude.append(collision_object.get_rid())
	_query_params.exclude = exclude

	var results := get_world_2d().direct_space_state.intersect_shape(_query_params, max_beam_hits_per_tick)
	var hits: Array[Node] = []
	var seen := {}

	for result in results:
		var collider_value: Variant = result.get("collider")
		if collider_value == null or not is_instance_valid(collider_value):
			continue
		var collider := collider_value as Node
		if collider == null or collider.is_queued_for_deletion():
			continue
		if _is_player_owned(collider):
			continue
		var id := collider.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		hits.append(collider)

	return hits


func _update_beam_visual(origin: Vector2, direction: Vector2, width: float, hits: Array[Node]) -> void:
	_ensure_visual_nodes()
	if _beam_root == null or _beam_core == null or _beam_glow == null:
		return

	var pulse := 0.72 + 0.28 * sin(_now_seconds() * beam_pulse_speed)
	var color := _weapon_color(_active_weapon_id)
	var safe_alpha := _visual_alpha(beam_alpha_cap)
	var visual_range := _visual_range_from_hits(origin, direction, hits)
	_beam_points[1] = Vector2(visual_range, 0.0)

	_beam_root.visible = true
	_beam_root.global_position = origin
	_beam_root.rotation = direction.angle()

	_beam_glow.points = _beam_points
	_beam_glow.width = width * 0.78
	_beam_glow.default_color = Color(color.r, color.g, color.b, safe_alpha * 0.24 * pulse)

	_beam_core.points = _beam_points
	_beam_core.width = maxf(width * 0.18, 6.0)
	_beam_core.default_color = Color(color.r, color.g, color.b, safe_alpha * pulse)

	if _impact_ring != null:
		var ring_radius := _impact_radius(maxf(width * 0.18, 12.0))
		_impact_ring.position = Vector2(visual_range, 0.0)
		_impact_ring.scale = Vector2.ONE * ring_radius
		_impact_ring.width = IMPACT_RING_WIDTH / maxf(ring_radius, 1.0)
		_impact_ring.default_color = Color(color.r, color.g, color.b, safe_alpha * 0.64)
		_impact_ring.rotation += get_physics_process_delta_time() * 3.2

	_beam_active = true
	_beam_heat = minf(_beam_heat + get_physics_process_delta_time() * 3.0, 1.0)


func _visual_range_from_hits(origin: Vector2, direction: Vector2, hits: Array[Node]) -> float:
	var best := beam_range
	for target in hits:
		var target_2d := target as Node2D
		if target_2d == null:
			continue
		if _is_destructible_planet(target):
			var along := (target_2d.global_position - origin).dot(direction)
			best = minf(best, clampf(along, beam_range * 0.18, beam_range))
	return best


func _end_beam() -> void:
	if _beam_active:
		_chronal_async_generation += 1
	_beam_active = false
	_beam_heat = maxf(_beam_heat - get_physics_process_delta_time() * 4.0, 0.0) if is_inside_tree() else 0.0
	if _beam_root != null:
		_beam_root.visible = false


func _sync_projectile_predictor() -> void:
	_resolve_player()
	if _player == null or not is_instance_valid(_player):
		return
	var predictor := _player.get_node_or_null("ProjectileAimPredictor") as Node
	if predictor == null:
		return
	var state := _projectile_prediction_state(_active_weapon_id)
	var should_show := bool(state.get("is_projectile", false)) and _is_local_player()
	var predictor_item := predictor as CanvasItem
	if predictor_item != null:
		predictor_item.visible = should_show
	if not bool(state.get("is_projectile", false)):
		return
	_set_if_present(predictor, "projectile_speed", state.get("initial_speed", vector_bolt_speed))
	_set_if_present(predictor, "gravity_constant", state.get("gravity_constant", vector_bolt_gravity))
	_set_if_present(predictor, "gravity_radius", state.get("gravity_pull_radius", 2000.0))
	_set_if_present(predictor, "player_gravity_deadzone_radius", state.get("player_gravity_deadzone_radius", 520.0))
	_set_if_present(predictor, "spawn_offset", state.get("spawn_offset", projectile_spawn_offset))
	_set_if_present(predictor, "collision_radius", state.get("collision_radius", projectile_prediction_collision_radius))
	_set_if_present(predictor, "prediction_color", state.get("prediction_color", vector_bolt_color))
	_set_if_present(predictor, "danger_color", state.get("danger_color", _projectile_trail_color_for_weapon(_active_weapon_id)))
	_set_if_present(predictor, "prediction_tracks", state.get("tracks", []))


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_parent() as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as Node2D
	_energy_component = _player.get_node_or_null("EnergyComponent") if _player != null else null
	_powerup_inventory = _player.get_node_or_null("PowerupInventory") if _player != null else null


func _configure_query() -> void:
	_query_params.shape = _query_shape
	_query_params.collide_with_areas = true
	_query_params.collide_with_bodies = true


func _ensure_visual_nodes() -> void:
	if _beam_root == null:
		_beam_root = Node2D.new()
		_beam_root.name = "BeamRoot"
		_beam_root.top_level = true
		_beam_root.z_index = 35
		add_child(_beam_root)
	if _beam_glow == null:
		_beam_glow = Line2D.new()
		_beam_glow.name = "BeamGlow"
		_beam_glow.antialiased = true
		_beam_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_beam_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
		_beam_root.add_child(_beam_glow)
	if _beam_core == null:
		_beam_core = Line2D.new()
		_beam_core.name = "BeamCore"
		_beam_core.antialiased = true
		_beam_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_beam_core.end_cap_mode = Line2D.LINE_CAP_ROUND
		_beam_root.add_child(_beam_core)
	if _impact_ring == null:
		_impact_ring = Line2D.new()
		_impact_ring.name = "ImpactRing"
		_impact_ring.closed = true
		_impact_ring.antialiased = true
		_impact_ring.width = IMPACT_RING_WIDTH
		_beam_root.add_child(_impact_ring)
	if _impact_ring.points.size() < 3:
		_impact_ring.points = _circle_points(28, 1.0)
	_beam_root.visible = false


func _ensure_field_visual_root() -> void:
	if _field_visual_root != null and is_instance_valid(_field_visual_root):
		return
	_field_visual_root = Node2D.new()
	_field_visual_root.name = "FieldWeaponVisuals"
	_field_visual_root.top_level = true
	_field_visual_root.z_index = 36
	add_child(_field_visual_root)


func _input_pressed(event: InputEvent, action_name: StringName, fallback_key: Key) -> bool:
	if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == fallback_key


func _is_beam_weapon(weapon_id: StringName) -> bool:
	var entry := _weapon_entry(weapon_id)
	if not entry.is_empty():
		return StringName(str(entry.get("fire_mode", &"projectile"))) == &"beam"
	return _is_builtin_beam_weapon(weapon_id)


func _is_field_weapon(weapon_id: StringName) -> bool:
	var entry := _weapon_entry(weapon_id)
	if not entry.is_empty():
		return StringName(str(entry.get("fire_mode", &"projectile"))) == &"field"
	return FIELD_WEAPON_DEFINITIONS.has(weapon_id)


func _is_projectile_weapon(weapon_id: StringName) -> bool:
	var entry := _weapon_entry(weapon_id)
	if not entry.is_empty():
		return StringName(str(entry.get("fire_mode", &"projectile"))) == &"projectile"
	return (
		weapon_id == &"vector_bolt"
		or weapon_id == &"relativistic_rail"
		or weapon_id == &"barycentric_splitter"
		or weapon_id == &"vacuum_collapse_seed"
		or weapon_id == &"temporal_splinter"
		or weapon_id == &"inversion_disc"
		or weapon_id == &"harmonic_needle"
		or weapon_id == &"shear_comet"
		or weapon_id == &"singularity_pin"
		or weapon_id == &"event_horizon_shard"
		or EXTRA_WEAPON_DEFINITIONS.has(weapon_id)
	)


func _is_hostile_target(target: Node) -> bool:
	return target.is_in_group("enemies") or target.is_in_group("wave_enemy") or target.is_in_group("bosses")


func _is_destructible_planet(target: Node) -> bool:
	return (
		target.is_in_group("planets")
		and not _is_hostile_target(target)
		and target.has_method("apply_spacetime_damage")
	)


func _is_player_owned(target: Node) -> bool:
	if target == _player:
		return true
	if _player != null and _player.is_ancestor_of(target):
		return true
	return target.is_in_group("Player") or target.is_in_group("player_projectiles")


func _is_player_dead() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("is_death_in_progress"):
		return bool(_player.call("is_death_in_progress"))
	if _player.has_method("is_dead"):
		return bool(_player.call("is_dead"))
	if _player.has_meta(&"death_in_progress"):
		return bool(_player.get_meta(&"death_in_progress"))
	return false


func _is_local_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return true
	var value: Variant = _player.get("network_is_local")
	return bool(value) if typeof(value) == TYPE_BOOL else true


func _aim_direction() -> Vector2:
	if _player == null:
		return Vector2.RIGHT
	var direction := -_player.transform.x.normalized()
	return direction if direction.length_squared() > 0.001 else Vector2.RIGHT


func _spend_energy(amount: float) -> bool:
	_resolve_player()
	if _energy_component == null:
		return false
	if _energy_component.has_method("has_energy") and not bool(_energy_component.call("has_energy", amount)):
		return false
	if _energy_component.has_method("spend"):
		_energy_component.call("spend", amount)
		return true
	return false


func _current_energy() -> float:
	_resolve_player()
	if _energy_component == null:
		return 0.0
	var value: Variant = _energy_component.get("current_energy")
	return float(value) if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT else 0.0


func _max_energy() -> float:
	_resolve_player()
	if _energy_component == null:
		return 1.0
	var value: Variant = _energy_component.get("max_energy")
	return float(value) if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT else 1.0


func _energy_cost_for_weapon(weapon_id: StringName) -> float:
	match weapon_id:
		&"positron_beam":
			return positron_energy_per_second
		&"gravity_wave_beam":
			return gravity_wave_energy_per_second
		&"chronal_refraction_beam":
			return chronal_energy_per_second
	return 0.0


func _beam_width_for_weapon(weapon_id: StringName) -> float:
	if weapon_id == &"positron_beam":
		return positron_beam_width
	if weapon_id == &"chronal_refraction_beam":
		return chronal_beam_width
	return gravity_wave_width


func _weapon_color(weapon_id: StringName) -> Color:
	var entry := _weapon_entry(weapon_id)
	if entry.has("color"):
		return _color_from_variant(entry.get("color"), vector_bolt_color)
	var payload_value: Variant = entry.get("payload", {})
	if payload_value is Dictionary and (payload_value as Dictionary).has("vector_core_color"):
		return _color_from_variant((payload_value as Dictionary).get("vector_core_color"), vector_bolt_color)
	var base_weapon := _catalog_base_weapon_id(weapon_id)
	if base_weapon != weapon_id:
		return _weapon_color(base_weapon)
	match weapon_id:
		&"relativistic_rail":
			return relativistic_rail_color
		&"barycentric_splitter":
			return barycentric_splitter_color
		&"vacuum_collapse_seed":
			return vacuum_seed_color
		&"temporal_splinter":
			return temporal_splinter_color
		&"inversion_disc":
			return inversion_disc_color
		&"harmonic_needle":
			return harmonic_needle_color
		&"shear_comet":
			return shear_comet_color
		&"singularity_pin":
			return singularity_pin_color
		&"event_horizon_shard":
			return event_horizon_shard_color
		&"positron_beam":
			return positron_color
		&"gravity_wave_beam":
			return gravity_wave_color
		&"chronal_refraction_beam":
			return chronal_color
	return vector_bolt_color


func _display_name(weapon_id: StringName) -> String:
	var entry := _weapon_entry(weapon_id)
	if entry.has("display_name"):
		return String(entry.get("display_name", _builtin_display_name(weapon_id)))
	return _builtin_display_name(weapon_id)


func _builtin_display_name(weapon_id: StringName) -> String:
	return String(WEAPON_NAMES.get(weapon_id, "Vector Bolt"))


func _weapon_entry(weapon_id: StringName) -> Dictionary:
	var entry_value: Variant = _weapon_catalog.get(String(weapon_id), {})
	if entry_value is Dictionary:
		return entry_value as Dictionary
	return {}


func _field_weapon_entry(weapon_id: StringName) -> Dictionary:
	var entry := _weapon_entry(weapon_id)
	if not entry.is_empty() and StringName(str(entry.get("fire_mode", &"projectile"))) == &"field":
		return entry
	var definition_value: Variant = FIELD_WEAPON_DEFINITIONS.get(weapon_id, {})
	if definition_value is Dictionary:
		return (definition_value as Dictionary).duplicate(true)
	return {}


func _catalog_base_weapon_id(weapon_id: StringName) -> StringName:
	var entry := _weapon_entry(weapon_id)
	if entry.is_empty() or bool(entry.get("builtin", false)):
		return weapon_id
	var base_value: Variant = entry.get("base_weapon_id", &"vector_bolt")
	var base_weapon := StringName(str(base_value))
	if String(base_weapon).is_empty() or base_weapon == weapon_id:
		return &"vector_bolt"
	return base_weapon


func _catalog_float_or_base(weapon_id: StringName, field: String, fallback: float) -> float:
	var entry := _weapon_entry(weapon_id)
	if not entry.is_empty():
		if entry.has(field):
			var value: Variant = entry.get(field)
			if value is float or value is int:
				return float(value)
		var payload_value: Variant = entry.get("payload", {})
		if payload_value is Dictionary:
			var payload: Dictionary = payload_value
			var payload_field := _payload_field_for_profile_field(field)
			if payload.has(payload_field):
				var payload_value_for_field: Variant = payload.get(payload_field)
				if payload_value_for_field is float or payload_value_for_field is int:
					return float(payload_value_for_field)
	var base_weapon := _catalog_base_weapon_id(weapon_id)
	if base_weapon != weapon_id:
		match field:
			"energy_per_shot":
				return _projectile_energy_cost(base_weapon)
			"fire_interval":
				return _projectile_fire_interval(base_weapon)
			"speed":
				return _projectile_speed_for_weapon(base_weapon)
			"damage_min":
				return _projectile_damage_min_for_weapon(base_weapon)
			"damage_max":
				return _projectile_damage_max_for_weapon(base_weapon)
			"gravity_constant":
				return _projectile_gravity_for_weapon(base_weapon)
			"visual_scale":
				return _projectile_visual_scale_for_weapon(base_weapon)
	return fallback


func _payload_field_for_profile_field(field: String) -> String:
	match field:
		"speed":
			return "initial_speed"
		"energy_per_shot", "fire_interval", "visual_scale":
			return field
	return field


func _is_builtin_beam_weapon(weapon_id: StringName) -> bool:
	return weapon_id == &"positron_beam" or weapon_id == &"gravity_wave_beam" or weapon_id == &"chronal_refraction_beam"


func _safe_projectile_core_color(color: Color) -> Color:
	var adjusted := color
	if Settings != null and Settings.has_method("apply_readability_color"):
		adjusted = Settings.apply_readability_color(adjusted)
	var alpha := minf(adjusted.a, projectile_core_alpha_cap)
	if Settings != null and Settings.has_method("world_visual_alpha"):
		alpha = Settings.world_visual_alpha(alpha, projectile_core_alpha_cap)
	elif Settings != null and Settings.has_method("flash_alpha"):
		alpha = minf(Settings.flash_alpha(alpha), projectile_core_alpha_cap)
	return Color(adjusted.r, adjusted.g, adjusted.b, alpha)


func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String:
		var text := str(value).strip_edges()
		if text.begins_with("#") and (text.length() == 7 or text.length() == 9):
			return Color.html(text)
	if value is Array:
		var values := value as Array
		if values.size() >= 3:
			return Color(
				clampf(float(values[0]), 0.0, 1.0),
				clampf(float(values[1]), 0.0, 1.0),
				clampf(float(values[2]), 0.0, 1.0),
				clampf(float(values[3]), 0.0, 1.0) if values.size() >= 4 else fallback.a
			)
	return fallback


func _vector2_from_variant(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector3:
		return Vector2(value.x, value.y)
	if value is Array:
		var values := value as Array
		if values.size() >= 2:
			return Vector2(float(values[0]), float(values[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO


func _get_resonance_manager() -> Node:
	var root := get_tree().current_scene
	return root.find_child("GravityResonanceManager", true, false) if root != null else null


func _get_gravity_scar_manager() -> Node:
	var root := get_tree().current_scene
	return root.find_child("GravityScarManager", true, false) if root != null else null


func _get_anomaly_director() -> Node:
	var root := get_tree().current_scene
	return root.find_child("VectorAnomalyDirector", true, false) if root != null else null


func _nearest_gravity_source_for_position(position: Vector2) -> Node2D:
	var buffer: Array[Node2D] = []
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_nearest_gravity_sources(position, buffer, 1, 0.0, _player)
		return buffer[0] if not buffer.is_empty() else null
	var best: Node2D = null
	var best_distance := INF
	for group_name in [&"Objects_With_Gravity", &"planets"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var source := node as Node2D
			if source == null or not is_instance_valid(source) or source == _player or source.is_queued_for_deletion():
				continue
			var distance := source.global_position.distance_squared_to(position)
			if distance < best_distance:
				best_distance = distance
				best = source
	return best


func _powerup_stack_count(powerup_id: StringName) -> int:
	_resolve_player()
	if _powerup_inventory != null and is_instance_valid(_powerup_inventory) and _powerup_inventory.has_method("get_stack_count"):
		return int(_powerup_inventory.call("get_stack_count", powerup_id))
	return 0


func _body_velocity(body: Node) -> Vector2:
	if body == null or not is_instance_valid(body):
		return Vector2.ZERO
	var velocity_value: Variant = body.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	var linear_velocity_value: Variant = body.get("linear_velocity")
	if linear_velocity_value is Vector2:
		return linear_velocity_value
	return Vector2.ZERO


func _is_gameplay_blocked() -> bool:
	if _pause_menu != null and is_instance_valid(_pause_menu) and _pause_menu.has_method("is_gameplay_blocked"):
		return bool(_pause_menu.call("is_gameplay_blocked"))
	return get_tree().paused


func _resolve_pause_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_pause_menu = tree.get_first_node_in_group("PauseMenu")


func _connect_network_session() -> void:
	if NetworkSession == null or not NetworkSession.has_signal("network_weapon_field_received"):
		return
	var callable := Callable(self, "_on_network_weapon_field_received")
	if not NetworkSession.is_connected("network_weapon_field_received", callable):
		NetworkSession.connect("network_weapon_field_received", callable)


func _broadcast_field_weapon(weapon_id: StringName, origin: Vector2, direction: Vector2, entry: Dictionary) -> void:
	if NetworkSession == null or not NetworkSession.has_method("broadcast_weapon_field_event"):
		return
	if _player == null or not is_instance_valid(_player) or not _is_local_player():
		return
	NetworkSession.call("broadcast_weapon_field_event", {
		"weapon_id": String(weapon_id),
		"origin": origin,
		"direction": direction,
		"radius": float(entry.get("radius", 280.0)),
		"damage": float(entry.get("damage", 0.0)),
		"force": float(entry.get("force", 0.0)),
		"time": _now_seconds(),
	}, _player)


func _on_network_weapon_field_received(data: Dictionary) -> void:
	if not _is_local_player():
		return
	if _player != null and is_instance_valid(_player):
		var owner_value: Variant = _player.get("network_peer_id")
		if (owner_value is int or owner_value is float) and int(owner_value) == int(data.get("owner_peer_id", 0)):
			return
	var weapon_id := StringName(str(data.get("weapon_id", "")))
	if not _is_field_weapon(weapon_id):
		return
	var entry := _field_weapon_entry(weapon_id)
	var origin := _vector2_from_variant(data.get("origin", data.get("position", Vector2.ZERO)))
	var direction := _vector2_from_variant(data.get("direction", Vector2.RIGHT)).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_apply_field_weapon_effect(weapon_id, entry, origin, direction, true)


func _visual_alpha(alpha: float) -> float:
	if Settings != null and Settings.has_method("world_visual_alpha"):
		return Settings.world_visual_alpha(alpha, beam_alpha_cap)
	if Settings != null and Settings.has_method("flash_alpha"):
		return minf(Settings.flash_alpha(alpha), beam_alpha_cap)
	return minf(alpha, beam_alpha_cap)


func _impact_radius(radius: float) -> float:
	if Settings != null and Settings.has_method("world_effect_radius"):
		return Settings.world_effect_radius(radius, beam_impact_radius_cap)
	return minf(radius, beam_impact_radius_cap)


func _set_if_present(target: Object, property_name: String, value: Variant) -> void:
	if target == null:
		return
	if target.get(property_name) != null:
		target.set(property_name, value)


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
