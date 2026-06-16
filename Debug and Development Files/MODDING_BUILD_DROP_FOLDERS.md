# Modding Build Drop Folders

This build expects data-driven mods to be copied into the Godot user data `mods` folder for the running platform, or into a `mods`/`Mods` folder beside a desktop export. The in-game **Mods** screen shows the resolved paths and can copy them to the clipboard.

## Drop Locations

- Windows: `%APPDATA%\Godot\app_userdata\Vector Anomaly\mods`
- macOS: `~/Library/Application Support/Godot/app_userdata/Vector Anomaly/mods`
- Linux: `~/.local/share/godot/app_userdata/Vector Anomaly/mods`
- Portable desktop export: `<folder next to the game executable>/mods`
- Project-bundled mods for development: `res://Mods`

Each mod can be either a folder containing `vector_anomaly_mod.json` or a direct `vector_anomaly_mod.json` file in the drop folder. The legacy `mod.json` name is still accepted. Roots are scanned recursively, so `mods/author/mod_name/vector_anomaly_mod.json` works.

Gameplay-affecting entries participate in the multiplayer compatibility signature. Local-only visuals, music, SFX, HUD badges, creator notes, thumbnails, and previews are ignored so cosmetic mods do not create false multiplayer mismatches.

## Minimal Layout

```text
mods/
  example_mod/
    vector_anomaly_mod.json
    assets/
```

Use manifest-relative asset paths for portable mods:

```json
{
  "id": "example_mod",
  "version": "1.0.0",
  "schema_version": 3,
  "content": {
    "sfx": [
      { "id": "mirror_ping", "stream": "assets/mirror_ping.ogg", "network_category": "local_visual" }
    ]
  }
}
```

## Build Checklist

- Keep `id`, `version`, and `schema_version` stable for released mods.
- Prefer manifest-relative paths over machine-specific absolute paths.
- Put deterministic gameplay content in `weapons`, `waves`, `wave_tables`, `rules`, `arenas`, `levels`, `boss_rules`, `enemy_packs`, `mechanics`, `calamity_mods`, `arena_events`, or hookable buckets.
- Mark cosmetic-only entries with `network_category: "local_visual"` when applicable. Shader packs, shader overrides, UI skins, texture packs, soundtrack packs, localization, HUD badges, palettes, and creator notes should usually stay local-only.
- Test both a clean install and a duplicate `res://Mods` plus `user://mods` setup; duplicate gameplay tokens are de-duplicated before hashing.
