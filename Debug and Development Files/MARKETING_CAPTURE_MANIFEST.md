# VECTOR ANOMALY Marketing Capture Manifest

Purpose: keep Steam, trailer, and press assets grounded in real gameplay state. Do not use abstract neon decoration as a substitute for readable game capture.

## Capture Rules

- Capture from a normal editor or standalone game run, not a headless run.
- Every screenshot and clip must show at least three of these: player position, gravity source, active threat, trajectory/recovery path, field rule, or readable HUD state.
- Record one full-quality pass and one reduced-flash readability pass for late-game footage.
- Keep UI scale at 1.0 for primary capture, then repeat the accessibility shot with the production accessibility settings visible.
- Use the final title/logo hook in `Scripts/title_screen.gd` and the branded assets in `Assets/Brand/`.
- In Clip Lab, press `F9` to save a clean PNG still and paired JSON metadata to `user://marketing_captures`, or `F10` to write metadata only. The overlay hides for the saved frame so the capture remains usable.

## Press Kit Screenshots

- `press_01_clean_vector_start`: wave 1-3, one gravity body, one threat, clear trajectory predictor.
- `press_02_slingshot_mastery`: great/perfect/apex slingshot, visible tangent path, recovery payoff.
- `press_03_resonance_zone`: compression or slipstream glyph active, player choosing path through the field.
- `press_04_boss_rule`: authored boss reshaping space with clear non-bullet physics pressure.
- `press_05_rupture_readability`: Rupture/law-crack effect active with player and threat still legible.
- `press_06_accessibility_late_game`: high-chaos late-game state with reduced flash enabled.

## Trailer Clips

- `clip_01_three_second_hook`: near-death high-speed gravity collapse, survival at the edge, title slam.
- `clip_02_mastery_arc`: clean trajectory, slingshot grade, threat conversion, score/readout payoff.
- `clip_03_midrun_resonance`: resonance zones changing the safest route instead of adding visual noise.
- `clip_04_boss_rule_mutation`: polarity/tide/null/compression/resonance behavior shown as arena pressure.
- `clip_05_rupture`: waves offline, laws cracking, controlled instability, no unreadable full-screen wash.
- `clip_06_music_finale`: music pulse, burst, and collapse beat driving readable reality pulses.

## Capture Readiness

- Brand/logo/capsule/key-art starter assets exist in `Assets/Brand/`.
- Clip Lab has number-key capture presets: `1` early clean vectors, `2` slingshot mastery, `3` mid-run resonance, `4` boss rule mutation, `5` Rupture/law-crack readability, `6` music finale staging, and `7` reduced-flash late-game accessibility.
- Clip Lab exposes `0` for reduced-flash capture toggling, `F9` for PNG stills, `F10` for JSON metadata, and `F1` to hide the capture overlay during manual video recording.
- HUD edge indicators, resource bars, weapon readouts, mod status icons, and game-over glitch treatment are in-game.
- Rupture, spacetime swim, tear, time-dilation break, gravity scar, and resonance visuals are capped through production readability paths.
- Music/title/rupture/finale/credits hooks are wired; final mix/master approval remains a creative pass.
- CODEX Completion 2026-06-13: `Scripts/clip_lab_director.gd` now maps every press/trailer capture requirement to an in-game preset, stages slingshot/apex, resonance, boss-rule, Rupture, finale, and reduced-flash late-game states, and writes capture slates for normal non-headless runs.
