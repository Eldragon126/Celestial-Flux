# Basic Mode Mod Template

Custom modes should declare scene flow and mode-specific content separately.

Minimal mode:

```json
{
  "id": "my_mode",
  "display_name": "My Mode",
  "network_category": "deterministic_seed",
  "scene": "res://Nodes/campaign_mode.tscn",
  "tags": ["custom-mode"],
  "description": "What makes this mode different."
}
```

Add companion entries:
- `campaigns` for progression.
- `wave_tables` for enemy pacing.
- `arena_events` for hazards.
- `creator_notes` for teaching users how to copy the mode.

Scene paths must be `res://`, `user://`, or manifest-relative. Do not use absolute filesystem paths.
