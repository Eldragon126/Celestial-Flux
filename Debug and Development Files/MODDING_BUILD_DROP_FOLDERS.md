# Modding Build Drop Folders

This build expects data-driven mods to be copied into the Godot user data `mods` folder for the running platform. The in-game **Mods** screen shows the resolved path and can copy it to the clipboard.

## Drop Locations

- Windows: `%APPDATA%\Godot\app_userdata\Vector Anomaly\mods`
- macOS: `~/Library/Application Support/Godot/app_userdata/Vector Anomaly/mods`
- Linux: `~/.local/share/godot/app_userdata/Vector Anomaly/mods`
- Project-bundled mods for development: `res://Mods`

Each mod can be either a folder containing `mod.json` or a direct `mod.json` file in the drop folder. Gameplay-affecting entries participate in the multiplayer compatibility signature. Local-only visuals, music, SFX, HUD badges, creator notes, thumbnails, and previews are ignored so cosmetic mods do not create false multiplayer mismatches.

## Minimal Layout

```text
mods/
  example_mod/
    mod.json
    assets/
```

## Build Checklist

- Keep `id`, `version`, and `schema_version` stable for released mods.
- Put deterministic gameplay content in `weapons`, `waves`, `rules`, `arenas`, `arena_events`, or hookable buckets.
- Mark cosmetic-only entries with `network_category: "local_visual"` when applicable.
- Test both a clean install and a duplicate `res://Mods` plus `user://mods` setup; duplicate gameplay tokens are de-duplicated before hashing.
