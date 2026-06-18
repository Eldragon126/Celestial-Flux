# VECTOR ANOMALY Modding Guide

The modding foundation is a safe, data-driven catalog inspired by tModLoader, Garry's Mod, Terraria packs, shader packs, custom-level ecosystems, and large "Calamity-style" expansions, but tuned for VECTOR ANOMALY's physics identity. Mods can declare arenas, levels, waves, enemies, bosses, boss rules, weapons, gravity profiles, shader packs, UI skins, audio, law weaves, anomaly recipes, challenge cards, palettes, and creator metadata without executing arbitrary scripts by default.

The design goal is unusual flexibility without runtime chaos: mod packs describe content, conditions, effects, and network categories; game directors opt into those entries through typed registry APIs.

## Where Mods Live

`ModContentRegistry` scans export-safe roots:

- `res://Mods` for bundled development/build packs
- `user://mods` for the per-platform writable mod folder
- `mods` and `Mods` beside the exported executable on desktop builds
- Any explicitly configured `additional_mod_roots`

The user mod folder is created automatically. Each root is scanned recursively, so a mod can live directly in the root or inside nested author/collection folders.

Preferred manifest name:

- `vector_anomaly_mod.json`

Legacy alias still accepted:

- `mod.json`

The reference pack lives at:

- `res://Mods/example_vector_laws/vector_anomaly_mod.json`

Asset paths inside manifests can use `res://`, `user://`, or manifest-relative paths such as `assets/sfx/mirror_hit.ogg`. Relative paths are resolved against the manifest folder at runtime, which keeps the same mod folder portable between Windows, macOS, Linux, and desktop portable builds.

## Safety Boundary

The registry discovers, validates, normalizes, and indexes manifests. It does not instantiate scenes, execute scripts, grant permissions, or mutate gameplay by itself.

Script-like buckets (`script_packs`, `tools`, and `npc_behaviors`) are cataloged but locked unless `allow_script_pack_registration` is explicitly enabled. Hookable buckets are data-only. Their `effects` are declarative requests such as `create_resonance_zone` or `offer_weapon`; a trusted game director must choose to consume them.

This gives the game a huge future mod surface without turning early mod loading into arbitrary code execution.

## Supported Content Buckets

The registry supports root-level arrays and nested `content` arrays for these buckets:

- `arenas`, `levels`, `level_packs`, `maps`, `campaigns`
- `biomes`, `mission_packs`, `wave_tables`
- `waves`, `upgrades`, `rules`, `powerups`, `weapons`
- `enemies`, `enemy_packs`, `enemy_behaviors`, `bosses`, `boss_packs`, `boss_rules`
- `projectile_profiles`, `gravity_source_profiles`, `planet_packs`, `status_effects`, `mechanics`
- `arena_events`, `celestial_bodies`, `physics_drops`
- `materials`, `shader_packs`, `shader_overrides`, `texture_packs`, `prefabs`, `entities`, `gamemodes`
- `total_conversions`, `expansion_packs`, `calamity_mods`, `npc_behaviors`
- `sfx`, `music`, `soundtrack_packs`, `hud_badges`, `ui_skins`, `localization`, `accessibility_profiles`, `tools`, `creator_tools`
- `law_weaves`, `anomaly_recipes`, `challenge_cards`
- `mod_palettes`, `creator_notes`
- `script_packs`, `workshop_tags`

Every entry needs a stable local `id`. The registry stores it as a namespaced `qualified_id` like `example_vector_laws/mirror_seed`, while `get_entry(bucket, local_id)` still works for simple lookups.

## Manifest Shape

```json
{
  "id": "example_vector_laws",
  "display_name": "Example Vector Laws",
  "author": "Vector Anomaly Team",
  "version": 1,
  "schema_version": 4,
  "description": "A safe sample content pack.",
  "tags": ["sample", "physics"],
  "dependencies": [
    { "id": "another_mod", "required": false, "min_version": "1.2.0" }
  ],
  "arenas": [],
  "waves": [],
  "upgrades": [],
  "rules": [],
  "content": {
    "weapons": [],
    "law_weaves": [],
    "anomaly_recipes": [],
    "challenge_cards": [],
    "mod_palettes": [],
    "creator_notes": []
  }
}
```

## Schema 4 Pack Graph And Creator Options

Schema 4 makes large mod collections deterministic and configurable without widening the script safety boundary.

- `dependencies` accept `min_version`, `max_version`, and `required`. Required version mismatches block the dependent pack; optional mismatches stay visible as diagnostics.
- `load_after` and `load_before` build a stable topological load order. Cycles are reported and fall back to discovery order for the unresolved members.
- `conflicts` explicitly names incompatible packs and may include a creator-facing `reason`. When both are installed, the later pack in resolved load order is blocked.
- `options` declares typed `bool`, `int`, `float`, `string`, `choice`, or `color` settings. Values persist in `user://mod_state.json`, appear in the Mods screen, and can be read with `get_mod_option()`.
- Options declare a `network_category`. Non-local option values participate in the gameplay compatibility signature, while presentation-only choices remain LAN-signature exempt.

Example option:

```json
{
  "id": "intensity",
  "display_name": "Resonance Intensity",
  "type": "float",
  "default": 0.6,
  "min": 0.25,
  "max": 1.0,
  "step": 0.05,
  "network_category": "deterministic_seed"
}
```

Hookable entries can gate on a persisted option with the `mod_option` condition. Supported operators are `equals`, `not_equals`, `greater_than`, `greater_or_equal`, `less_than`, and `less_or_equal`.

## Hookable Content

`law_weaves`, `anomaly_recipes`, and `challenge_cards` share a normalized hook format:

```json
{
  "id": "mirror_apex_weave",
  "display_name": "Mirror Apex Weave",
  "hooks": ["slingshot_apex", "resonance_created"],
  "network_category": "deterministic_seed",
  "weight": 1.2,
  "cooldown": 5.0,
  "max_triggers": 4,
  "exclusive_group": "mirror_apex_payoff",
  "conditions": [
    { "type": "min_wave", "value": 4 },
    { "type": "slingshot_grade_at_least", "grade": "apex" }
  ],
  "effects": [
    {
      "action": "create_resonance_zone",
      "zone_type": "harmonic_orbit",
      "radius": 220.0,
      "intensity": 0.65
    },
    {
      "action": "offer_weapon",
      "weapon_id": "mirror_lance"
    }
  ]
}
```

Default hooks:

- `law_weaves`: `run_start`
- `anomaly_recipes`: `wave_start`
- `challenge_cards`: `run_start`

Supported hook names:

- `run_start`, `wave_start`, `wave_clear`
- `boss_spawned`, `boss_defeated`
- `slingshot_good`, `slingshot_great`, `slingshot_perfect`, `slingshot_apex`
- `weapon_fired`, `projectile_hit`
- `resonance_created`, `gravity_scar_created`
- `near_death`, `death`, `recovery_window_started`
- `rare_event_started`, `rupture_started`, `music_beat`
- `coop_combo_triggered`
- `level_loaded`, `arena_loaded`, `enemy_spawned`, `enemy_defeated`, `shader_pack_applied`
- `powerup_collected`, `weapon_changed`, `player_hit`, `black_hole_consumed`, `planet_fractured`
- `level_completed`, `mod_pack_enabled`, `mod_pack_disabled`

Supported condition types:

- `min_wave`, `max_wave`
- `chaos_tier_at_least`, `chaos_tier_at_most`
- `has_powerup`, `has_weapon`
- `slingshot_grade_at_least`
- `resonance_type`, `scar_type`
- `boss_active`
- `player_health_below`, `player_shield_below`
- `seed_tag`, `run_modifier`
- `multiplayer_peer_count_at_least`
- `projectile_pressure_at_least`, `enemy_count_at_least`
- `near_gravity_source`, `black_hole_active`
- `accessibility_mode`: `reduced_flash`, `full_flash`, `trackpad`, `alternate_movement`, `readability_halos`, or `no_readability_halos`

Supported effect actions:

- `spawn_arena_event`
- `create_resonance_zone`
- `create_gravity_scar`
- `grant_powerup`
- `offer_weapon`
- `spawn_celestial_body`
- `spawn_physics_drop`
- `emit_hud_badge`
- `play_sfx`
- `request_music_layer`
- `adjust_run_pressure`
- `tag_score_event`
- `start_challenge_card`
- `complete_challenge_card`
- `request_level_transition`, `offer_level`
- `spawn_enemy_profile`, `spawn_boss_profile`
- `apply_shader_pack`, `apply_texture_pack`, `apply_ui_skin`, `request_localization`
- `set_arena_law`, `set_gravity_profile`, `request_boss_rule`, `request_wave_table`
- `offer_upgrade`, `apply_status_effect`, `set_level_flag`, `queue_mod_story_event`

## Runtime Hook Activation

`ModHookDirector` is the safe runtime consumer for hookable entries. It listens to existing game signals, asks `ModContentRegistry.get_hook_entries()`, evaluates normalized conditions, and applies only whitelisted effects.

Live bounded effects:

- `create_resonance_zone`
- `create_gravity_scar`
- `grant_powerup`
- `offer_weapon`
- `emit_hud_badge`
- `play_sfx`

Recorded director requests:

- `spawn_arena_event`
- `spawn_celestial_body`
- `spawn_physics_drop`
- `request_music_layer`
- `adjust_run_pressure`
- `tag_score_event`
- `start_challenge_card`
- `complete_challenge_card`

Recorded requests are stored in `RunProgress.arena_flags["mod_hook_events"]` for trusted directors, score systems, menus, and future editor tooling. They are not arbitrary scene/script execution.

Player-triggered hook effects such as `slingshot_apex`, `weapon_fired`, `projectile_hit`, and `coop_combo_triggered` use `NetworkSession.broadcast_mod_hook_event()` so peers replay the same registry entry by id when LAN multiplayer is active. The payload is intentionally narrow: hook id, entry id, owner peer, position, wave, grade, weapon id, and typed resonance/scar context. Projectile impacts are owner-gated so replicated remote projectiles do not double-apply gameplay hooks on peers.

## Playable Weapon Mods

Weapon entries can now be catalog-only concepts, beams for future trusted integration, or playable projectile profiles that `WeaponSystem` registers into its weapon list.

Playable projectile entries use:

- `fire_mode`: `projectile`
- `network_category`: usually `reliable_event`
- `base_weapon_id`: any built-in projectile weapon profile
- `pattern`: `single`, `spread`, `parallel`, `braid`, `helix`, `ring`, `converge`, `scissor`, or `pinwheel`
- `shot_count`: clamped to `1-6`
- `spread_radians`: clamped to `0.0-0.75`
- `payload`: safe overrides for projectile speed, damage, gravity fields, resonance/scar type, pierce, curve force, planet damage, and other approved weapon fields

Example:

```json
{
  "id": "mirror_lance",
  "display_name": "Mirror Lance",
  "fire_mode": "projectile",
  "network_category": "reliable_event",
  "base_weapon_id": "gravity_lance",
  "pattern": "parallel",
  "shot_count": 2,
  "spread_radians": 0.08,
  "payload": {
    "resonance_zone_type": "compression",
    "field_radius": 170.0,
    "field_force": -390.0,
    "axis_impulse": 340.0
  }
}
```

`WeaponSystem` reads normalized playable entries through `get_playable_weapon_entries()`. Cataloged entries remain visible to UI/tooling but are not selectable as live weapons.

Current built-in projectile catalog includes the original vector/rail/splitter/collapse/time/inversion/harmonic/shear/singularity/event-horizon set plus Gravity Lance, Orbit Saw, Tidal Mortar, Chronal Mirror Shot, Polarity Javelin, Lensing Flak, Rift Anchor, Apex Vector Spear, Phase Suture, Null Rebounder, Graviton Bloom, Causal Anchor, Vector Prism, Mass Driver, Tidal Skein, Scar Carver, Chronal Needleloom, Singularity Kite, Inertia Maul, and Harmonic Bloom.

## Network Categories

Every new content type should declare how it affects multiplayer and challenges:

- `local_visual`: local UI, palette, SFX, music, or cosmetic-only content.
- `exported_state`: content whose resulting state can be exported/imported.
- `reliable_event`: explicit events such as weapon fire or authoritative one-shot activation.
- `deterministic_seed`: seed-driven law, recipe, arena, or challenge data that must match across peers.

`NetworkSession` hashes the normalized mod registry compatibility signature, including gameplay-affecting weapon and hookable entries, so mismatched gameplay mod packs can fail cleanly before co-op starts. Entries marked `local_visual` are intentionally excluded from the compatibility signature. The title-screen/pre-run fallback also filters manifest hashes to gameplay-affecting entries, so local palettes, music, creator notes, and HUD cosmetics do not falsely block a LAN join.

Hookable entries marked `local_visual` may only request local-safe effect actions: `emit_hud_badge`, `play_sfx`, `request_music_layer`, `apply_shader_pack`, or `apply_texture_pack`.

## Larger Creator Surfaces

The registry now exposes first-class creator surfaces for large mods:

- Custom levels and campaigns: `levels`, `level_packs`, `maps`, `campaigns`
- Biomes and mission structure: `biomes`, `mission_packs`, `wave_tables`
- Enemy and boss libraries: `enemies`, `enemy_packs`, `enemy_behaviors`, `bosses`, `boss_packs`, `boss_rules`, `entities`, `prefabs`
- Physics and combat profiles: `projectile_profiles`, `gravity_source_profiles`, `planet_packs`, `status_effects`, `mechanics`
- Minecraft-style visual packs: `shader_packs`, `shader_overrides`, `texture_packs`, `ui_skins`, local-only by default
- Audio and language packs: `soundtrack_packs`, `localization`, `accessibility_profiles`
- Calamity-style expansions: `total_conversions`, `expansion_packs`, `calamity_mods`
- Tooling surfaces: `tools`, `creator_tools`, and locked `script_packs`

These entries are cataloged and compatibility-tagged now, while trusted directors and editor tools can consume them incrementally. The default boundary is still safe and deterministic: no arbitrary scripts run unless trusted script pack registration is explicitly enabled.

## Registry API

Useful calls:

- `reload_registry()`
- `get_registry_summary()`
- `get_registry_snapshot()`
- `get_modding_capabilities()`
- `get_content_buckets()`
- `get_entries(content_type)`
- `get_entries_with_tag(content_type, tag)`
- `get_entry(content_type, entry_id)`
- `get_hook_entries(hook_id)`
- `get_playable_weapon_entries()`
- `get_level_entries()`
- `get_enemy_pack_entries()`
- `get_shader_pack_entries()`
- `get_total_conversion_entries()`
- `get_entries_for_creator_surface(surface)`
- `get_manifest(manifest_id)`
- `get_manifest_load_order()`
- `get_dependency_warnings()`
- `get_conflict_warnings()`
- `get_manifest_options(manifest_id)`
- `get_mod_option(manifest_id, option_id, fallback)`
- `set_mod_option(manifest_id, option_id, value)`
- `reset_manifest_options(manifest_id)`
- `get_entries_by_network_category(network_category)`
- `get_compatibility_signature()`
- `get_scan_roots()`
- `get_mod_install_paths()`
- `resolve_mod_path(path, context)`
- `resolve_entry_path(entry, field)`

Useful signals:

- `registry_loaded(summary)`
- `registry_reloaded(summary)`
- `manifest_loaded(manifest_id, source_path)`
- `manifest_failed(source_path, reason)`
- `manifest_validated(manifest_id, source_path)`
- `content_registered(content_type, entry_id, manifest_id, entry)`
- `mod_hook_registered(hook_id, entry_id, manifest_id, entry)`
- `dependency_warning(manifest_id, dependency_id, reason)`
- `manifest_conflict(manifest_id, conflicting_id, reason)`
- `mod_option_changed(manifest_id, option_id, value)`
- `mod_catalog_changed(snapshot)`
- `ModHookDirector.mod_hook_triggered(hook_id, entry_id, data)`
- `ModHookDirector.mod_effect_applied(action, entry_id, data)`
- `ModHookDirector.mod_weapon_offered(weapon_id, entry, data)`

## Validation

The registry rejects manifests when:

- root `id` is missing or unsafe
- `version` is missing
- `schema_version` is outside the supported range
- `dependencies` is not an array
- `content` is not an object
- a known content bucket is not an array
- an entry is not an object
- an entry is missing `id`
- path fields such as `scene`, `resource`, `script`, `stream`, or `icon` are not `res://`, `user://`, or manifest-relative
- path fields contain `..`, unsupported URI schemes, or absolute filesystem paths
- a `script` path appears outside trusted script buckets
- weapon fire modes, patterns, payload values, or named resonance/scar types are invalid
- hookable entries use unknown hooks, condition types, or effect actions
- hookable entries marked `local_visual` request gameplay-affecting effect actions
- hookable conditions/effects try to include a `script`
- palettes contain invalid color entries

Missing required dependencies disable the manifest and its content. Optional dependency problems appear as warnings.

## Current Runtime Status

The registry, schema 4 pack graph, persisted creator options, sample manifest, mod-manager controls, scan-root readout, compatibility signature, playable projectile weapon loading, safe hook activation, and LAN hook replay are code-side foundations now. Hookable law weaves, recipes, and challenge cards can apply bounded live effects through `ModHookDirector`, while higher-level requests are recorded for trusted directors instead of spawning arbitrary scenes.

Export portability is now part of the contract: the runtime scans `user://mods`, optional executable-adjacent folders, bundled `res://Mods`, and nested mod directories; accepts `vector_anomaly_mod.json` plus the legacy `mod.json`; resolves manifest-relative asset paths without baking local machine paths into multiplayer compatibility hashes; and lets mod SFX load from exported external folders when the file type is supported by Godot's runtime audio streams.

That separation is intentional. It lets the game grow toward a wild modding ecosystem while keeping V1 runtime behavior deterministic, inspectable, multiplayer-aware, and production-safe.

## Creator Lab And Diagnostics

The dedicated static creator site lives at `website/modding/index.html`. It includes a browser-local schema 4 workbench with draft persistence, JSON import/export, live contract diagnostics, dependency/conflict authoring, typed option templates, searchable creator surfaces, hook grammar, install guidance, and a persistent release checklist.

`ModContentRegistry` now also exposes:

- `validate_manifest_text(json_text, source_path)`
- `validate_manifest_file(source_path)`
- `export_creator_report(report_path)`

The in-game Mods screen has an **Export Creator Report** action. The report contains loaded/failed/disabled manifests, dependency warnings, resolved install paths, registry capabilities, and the gameplay compatibility signature. Its resolved path is copied to the clipboard so creators can attach one deterministic diagnostic artifact to bug reports.
