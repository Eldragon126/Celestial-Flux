# Basic Relic Mod Template

Relics are declared as `upgrades` plus optional hookable entries.

Minimal upgrade:

```json
{
  "id": "my_relic",
  "display_name": "My Relic",
  "network_category": "deterministic_seed",
  "rarity": "rare",
  "tags": ["slingshot"],
  "description": "What the relic changes and how the player reads it."
}
```

Hookable behavior should request bounded effects:

```json
{
  "id": "my_relic_hook",
  "display_name": "My Relic Hook",
  "hooks": ["slingshot_perfect"],
  "network_category": "deterministic_seed",
  "cooldown": 6.0,
  "effects": [
    {"action": "emit_hud_badge", "content_id": "my_relic_badge"}
  ]
}
```

Do not silently apply unavoidable damage. Give the player a clear cause and response window.
