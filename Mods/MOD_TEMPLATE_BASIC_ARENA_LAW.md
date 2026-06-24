# Basic Arena Law Mod Template

Arena laws belong in `rules`, `arena_events`, and optionally `law_weaves`.

Minimal rule:

```json
{
  "id": "my_arena_law",
  "display_name": "My Arena Law",
  "network_category": "deterministic_seed",
  "tags": ["gravity"],
  "warning_seconds": 1.0,
  "description": "A bounded physics rule with a visible telegraph."
}
```

Use creator options for tuning:

```json
{
  "id": "law_intensity",
  "display_name": "Law Intensity",
  "type": "float",
  "default": 0.5,
  "min": 0.1,
  "max": 1.0,
  "network_category": "deterministic_seed"
}
```

Keep all multiplayer-affecting law values deterministic.
