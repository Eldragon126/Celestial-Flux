# ORBITRON: VECTORFALL Modding Guide

This is the current data-driven modding foundation. It is intentionally conservative: manifests are discovered and registered, but the game does not execute arbitrary mod scripts or automatically spawn untrusted content.

## Where Mods Live

`ModContentRegistry` scans two roots:

- `res://Mods`
- `user://mods`

Each mod can either place `vectorfall_mod.json` directly in the root or inside its own folder.

## Manifest Shape

```json
{
  "id": "example_vector_laws",
  "display_name": "Example Vector Laws",
  "version": 1,
  "arenas": [
    {
      "id": "mirror_well",
      "display_name": "Mirror Well",
      "scene": "res://Mods/example_vector_laws/mirror_well.tscn",
      "rules": {
        "gravity_bias": "inversion"
      }
    }
  ],
  "waves": [
    {
      "id": "slipstream_intro",
      "display_name": "Slipstream Intro",
      "enemy_sets": ["base_enemy", "orbiter_drone"],
      "minimum_wave": 4
    }
  ],
  "upgrades": [
    {
      "id": "tangent_refund",
      "display_name": "Tangent Refund",
      "law": "momentum",
      "description": "Clean orbit exits refund a small burst of thrust energy."
    }
  ],
  "rules": [
    {
      "id": "soft_inversion",
      "display_name": "Soft Inversion",
      "zone_type": "inversion",
      "intensity_multiplier": 0.75
    }
  ]
}
```

## Current Supported Buckets

- `arenas`: future selectable arena definitions.
- `waves`: future wave roster/pacing definitions.
- `upgrades`: future law-upgrade definitions.
- `rules`: future physics/ruleset modifiers.

Every entry should have a stable `id`. The registry adds `manifest_id` and `content_type` to each entry after loading.

## Current Limits

- No runtime mod menu yet.
- No automatic scene spawning yet.
- No custom GDScript execution from manifests.
- No validation UI yet.
- No dependency or load-order system yet.

This keeps the first layer deterministic and easy to inspect while the game systems are still stabilizing.
