# VECTOR ANOMALY Modding Guide

The modding foundation is a safe, data-driven catalog inspired by tModLoader, Garry's Mod, Terraria packs, and custom-level ecosystems, but tuned for VECTOR ANOMALY's physics identity. Mods can declare arenas, waves, weapons, audio, UI badges, law weaves, anomaly recipes, challenge cards, palettes, and creator metadata without executing arbitrary scripts by default.

The design goal is unusual flexibility without runtime chaos: mod packs describe content, conditions, effects, and network categories; game directors opt into those entries through typed registry APIs.

## Where Mods Live

`ModContentRegistry` scans two roots:

- `res://Mods`
- `user://mods`

Each mod can place `vector_anomaly_mod.json` directly in the root or inside its own folder.

The reference pack lives at:

- `res://Mods/example_vector_laws/vector_anomaly_mod.json`

## Safety Boundary

The registry discovers, validates, normalizes, and indexes manifests. It does not instantiate scenes, execute scripts, grant permissions, or mutate gameplay by itself.

Script-like buckets (`script_packs`, `tools`, and `npc_behaviors`) are cataloged but locked unless `allow_script_pack_registration` is explicitly enabled. Hookable buckets are data-only. Their `effects` are declarative requests such as `create_resonance_zone` or `offer_weapon`; a trusted game director must choose to consume them.

This gives the game a huge future mod surface without turning early mod loading into arbitrary code execution.

## Supported Content Buckets

The registry supports root-level arrays and nested `content` arrays for these buckets:

- `arenas`, `waves`, `upgrades`, `rules`
- `powerups`, `weapons`, `enemies`, `bosses`
- `arena_events`, `celestial_bodies`, `physics_drops`
- `materials`, `prefabs`, `entities`, `gamemodes`, `npc_behaviors`
- `sfx`, `music`, `hud_badges`, `maps`, `tools`
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
  "schema_version": 2,
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

## Playable Weapon Mods

Weapon entries can now be catalog-only concepts, beams for future trusted integration, or playable projectile profiles that `WeaponSystem` registers into its weapon list.

Playable projectile entries use:

- `fire_mode`: `projectile`
- `network_category`: usually `reliable_event`
- `base_weapon_id`: any built-in projectile weapon profile
- `pattern`: `single`, `spread`, `parallel`, `braid`, `helix`, or `ring`
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

## Network Categories

Every new content type should declare how it affects multiplayer and challenges:

- `local_visual`: local UI, palette, SFX, music, or cosmetic-only content.
- `exported_state`: content whose resulting state can be exported/imported.
- `reliable_event`: explicit events such as weapon fire or authoritative one-shot activation.
- `deterministic_seed`: seed-driven law, recipe, arena, or challenge data that must match across peers.

`NetworkSession` hashes the normalized mod registry compatibility signature, including gameplay-affecting weapon and hookable entries, so mismatched gameplay mod packs can fail cleanly before co-op starts. Entries marked `local_visual` are intentionally excluded from the compatibility signature.

Hookable entries marked `local_visual` may only request local-safe effect actions: `emit_hud_badge`, `play_sfx`, or `request_music_layer`.

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
- `get_manifest(manifest_id)`
- `get_manifest_load_order()`
- `get_dependency_warnings()`
- `get_compatibility_signature()`

Useful signals:

- `registry_loaded(summary)`
- `registry_reloaded(summary)`
- `manifest_loaded(manifest_id, source_path)`
- `manifest_failed(source_path, reason)`
- `manifest_validated(manifest_id, source_path)`
- `content_registered(content_type, entry_id, manifest_id, entry)`
- `mod_hook_registered(hook_id, entry_id, manifest_id, entry)`
- `dependency_warning(manifest_id, dependency_id, reason)`
- `mod_catalog_changed(snapshot)`

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
- path fields such as `scene`, `resource`, `script`, `stream`, or `icon` are not `res://` or `user://`
- path fields contain `..`
- a `script` path appears outside trusted script buckets
- weapon fire modes, patterns, payload values, or named resonance/scar types are invalid
- hookable entries use unknown hooks, condition types, or effect actions
- hookable entries marked `local_visual` request gameplay-affecting effect actions
- hookable conditions/effects try to include a `script`
- palettes contain invalid color entries

Missing required dependencies disable the manifest and its content. Optional dependency problems appear as warnings.

## Current Runtime Status

The registry, sample manifest, pause-menu status readout, compatibility signature, and playable projectile weapon loading are code-side foundations. Hookable law weaves, recipes, and challenge cards are cataloged and indexed now; individual directors still need explicit activation paths before each effect action changes live gameplay.

That separation is intentional. It lets the game grow toward a wild modding ecosystem while keeping V1 runtime behavior deterministic, inspectable, and production-safe.
