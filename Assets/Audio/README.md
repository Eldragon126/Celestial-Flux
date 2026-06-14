# Vector Anomaly Audio Manifest

Update `vector_anomaly_audio_manifest.json` to swap soundtrack and mechanic SFX without editing GDScript.

- `music.waves`: maps regular wave numbers to audio resources.
- `music.boss_waves`: maps boss wave numbers to audio resources.
- `music.wave_playlist`: fallback playlist for unmapped regular waves.
- `music.intermission_playlist`: fallback intermission playlist.
- `sfx`: named mechanic cue overrides consumed by `MechanicAudioDirector`.

Keep paths as Godot resource paths such as `res://Assets/Songs/My Track.mp3`.
