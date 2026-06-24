# Vector Anomaly Modding

Vector Anomaly mods are safe data contracts. A mod folder contains `vector_anomaly_mod.json` plus optional assets and notes. The runtime registry validates the manifest, indexes content, and exposes entries to trusted game directors.

## Folder Shape

```text
Mods/my_mod/
  vector_anomaly_mod.json
  README.md
  assets/
```

Bundled examples live in `Mods/official_examples/`. User mods can live in `user://mods` or an export-adjacent `mods` folder.

## What To Declare

Use stable lowercase IDs and schema version 4. Gameplay-affecting entries should use `network_category: "deterministic_seed"` so LAN peers agree on the same rules. Presentation-only entries can use `local_visual`.

Useful buckets:
- `rules`, `arena_events`, `law_weaves`
- `enemies`, `enemy_packs`, `wave_tables`
- `gamemodes`, `campaigns`, `mission_packs`
- `boss_rules`, `boss_packs`
- `upgrades`, `powerups`, `mechanics`
- `creator_notes`, `hud_badges`, `mod_palettes`

## Testing

Open the in-game Anomaly Workshop, press Rescan, and check:
- The manifest loads.
- Content counts increase in the expected buckets.
- Gameplay signature changes only for gameplay-affecting mods.
- Disabling the mod removes it from active registry content.

## Safety Rules

Do not use arbitrary scripts for public data mods unless the project later exposes a trusted script-pack path. Prefer declarative hooks and let trusted directors consume them.

Every dangerous mechanic needs a warning, a response window, and a cap. The design goal is readable chaos, not random soup.

## Official Examples

- Cosmic Lawbreaker Pack: arena laws.
- Anomaly Bestiary: enemy catalog entries.
- Collapsing Microverse Mode: custom game-mode shape.
- Boss Heresy Kit: boss mutation rules.
- Relic Singularity Forge: relic/passive metadata and hooks.
