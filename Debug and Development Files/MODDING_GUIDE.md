# VECTOR ANOMALY Modding Guide

The modding foundation is now a broad data-driven catalog inspired by tModLoader and Garry's Mod, with one important production rule: manifests are discovered and registered, but the game does not execute arbitrary mod scripts by default.

## Where Mods Live

`ModContentRegistry` scans two roots:

- `res://Mods`
- `user://mods`

Each mod can place `vector_anomaly_mod.json` directly in the root or inside its own folder.

An example manifest lives at:

- `res://Mods/example_vector_laws/vector_anomaly_mod.json`

## Supported Content Buckets

The registry supports root-level arrays and nested `content` arrays for these buckets:

- `arenas`, `waves`, `upgrades`, `rules`
- `powerups`, `weapons`, `enemies`, `bosses`
- `arena_events`, `celestial_bodies`, `physics_drops`
- `materials`, `prefabs`, `entities`, `gamemodes`, `npc_behaviors`
- `sfx`, `music`, `hud_badges`, `maps`, `tools`
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
    "enemies": [
      {
        "id": "phase_slip_swarm_variant",
        "display_name": "Phase-Slip Swarm Variant",
        "scene": "res://Nodes/phase_slip_swarm.tscn"
      }
    ],
    "sfx": [
      {
        "id": "mirror_tide_cue",
        "display_name": "Mirror Tide Cue",
        "stream": "res://Assets/Sound Effects/sfx_rare_event_distinct.mp3"
      }
    ]
  }
}
```

## Registry API

Useful calls:

- `reload_registry()`
- `get_registry_summary()`
- `get_registry_snapshot()`
- `get_content_buckets()`
- `get_entries(content_type)`
- `get_entry(content_type, entry_id)`
- `get_manifest(manifest_id)`
- `get_manifest_load_order()`
- `get_dependency_warnings()`

Useful signals:

- `registry_loaded(summary)`
- `registry_reloaded(summary)`
- `manifest_loaded(manifest_id, source_path)`
- `manifest_failed(source_path, reason)`
- `content_registered(content_type, entry_id, manifest_id, entry)`
- `dependency_warning(manifest_id, dependency_id, reason)`
- `mod_catalog_changed(snapshot)`

## Validation

The registry rejects manifests when:

- root `id` is missing
- `version` is missing
- `schema_version` is outside the supported range
- `dependencies` is not an array
- a known content bucket is not an array
- an entry is not an object
- an entry is missing `id`
- path fields such as `scene`, `resource`, `script`, `stream`, or `icon` are not `res://` or `user://`

Missing required dependencies disable the manifest and its content. Optional dependency problems appear as warnings.

## Script Safety

`script_packs`, `tools`, and `npc_behaviors` are cataloged but locked unless `allow_script_pack_registration` is enabled. This gives the project a Garry's Mod-style expansion surface without turning early mod loading into arbitrary code execution.

The pause menu Modding section shows loaded mods, content mix, disabled manifests, dependency warnings, failed manifests, and locked script-pack warnings after `RESCAN MODS`.
