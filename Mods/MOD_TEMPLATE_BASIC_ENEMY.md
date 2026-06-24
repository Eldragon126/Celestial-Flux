# Basic Enemy Mod Template

1. Create `Mods/my_enemy_pack/vector_anomaly_mod.json`.
2. Add `schema_version: 4`, a stable `id`, and `network_category: "deterministic_seed"` on gameplay entries.
3. Add enemies under `content.enemies`.
4. Group them with `content.enemy_packs`.
5. Add a `wave_tables` entry so trusted directors can opt into spawning them.

Minimal entry:

```json
{
  "id": "my_orbit_enemy",
  "display_name": "My Orbit Enemy",
  "network_category": "deterministic_seed",
  "tags": ["orbital-ai"],
  "health": 60,
  "description": "Readable movement concept and attack warning."
}
```

Keep health, speed, cooldowns, warning time, and gravity response as data fields modders can tune.
