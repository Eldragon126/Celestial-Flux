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
- `press_07_controller_deck_layout`: pause menu/controller HUD state showing controller deadzone/right-stick aim, UI scale, and readable score panel.
- `press_08_gravity_heat_map`: F10 heat map active with contours, gradient vectors, and a visible tangent route.

## Trailer Clips

- `clip_01_three_second_hook`: near-death high-speed gravity collapse, survival at the edge, title slam.
- `clip_02_mastery_arc`: clean trajectory, slingshot grade, threat conversion, score/readout payoff.
- `clip_03_midrun_resonance`: resonance zones changing the safest route instead of adding visual noise.
- `clip_04_boss_rule_mutation`: polarity/tide/null/compression/resonance behavior shown as arena pressure.
- `clip_05_rupture`: waves offline, laws cracking, controlled instability, no unreadable full-screen wash.
- `clip_06_music_finale`: music pulse, burst, and collapse beat driving readable reality pulses.
- `clip_07_black_hole_hardened`: event horizon approach, readable danger, no collision/body crash, clean death or escape.
- `clip_08_lan_coop_signal`: LAN co-op with peer nameplates, NET7 protocol readout, and co-op resonance payoff.

## Steam Page Player Discovery List

Use this as the exact list for finding screenshots and video clips for the Steam page. A good asset should be rejected if the ship, major force, danger source, or recovery route is unclear.

- Header screenshot: clean player slingshot around one gravity source, with predictor and one readable threat.
- Gameplay screenshot 1: tutorial-like early wave showing simple movement grammar.
- Gameplay screenshot 2: apex slingshot with new player aura and tangent exit visible.
- Gameplay screenshot 3: resonance field with readable `PULL`, `PUSH`, `FLOW`, `SLOW`, or `ORBIT` language.
- Gameplay screenshot 4: boss-law mutation that reads as physics pressure rather than bullet spam.
- Gameplay screenshot 5: gravity heat map toggled on for contours/gradient vectors.
- Gameplay screenshot 6: late-game reduced-flash chaos with player/threats still visible.
- Feature capsule clip: 3 seconds of near-death survival, then title/logo.
- Movement clip: smooth slingshot impulse, grade readout, recovery route.
- Boss clip: one authored boss rule changing the arena.
- Co-op clip: two players producing a co-op vector resonance payoff.
- Accessibility clip: UI scale, reduced flash, readability halos, and controller settings shown in-game.
- Steam Deck clip: controller-first play, pause navigation, and 1280x800 HUD proof after validation.

## Capture Readiness

- Brand/logo/capsule/key-art starter assets exist in `Assets/Brand/`.
- Clip Lab has number-key capture presets: `1` early clean vectors, `2` slingshot mastery, `3` mid-run resonance, `4` boss rule mutation, `5` Rupture/law-crack readability, `6` music finale staging, and `7` reduced-flash late-game accessibility.
- Clip Lab exposes `0` for reduced-flash capture toggling, `F9` for PNG stills, `F10` for JSON metadata, and `F1` to hide the capture overlay during manual video recording.
- Use the platform matrix in `Debug and Development Files/PLATFORM_SUPPORT_MATRIX.md` before claiming Linux, macOS, Steam Deck, or console availability.
- HUD edge indicators, resource bars, weapon readouts, mod status icons, and game-over glitch treatment are in-game.
- Rupture, spacetime swim, tear, time-dilation break, gravity scar, and resonance visuals are capped through production readability paths.
- Music/title/rupture/finale/credits hooks are wired; final mix/master approval remains a creative pass.
- CODEX Completion 2026-06-13: `Scripts/clip_lab_director.gd` now maps every press/trailer capture requirement to an in-game preset, stages slingshot/apex, resonance, boss-rule, Rupture, finale, and reduced-flash late-game states, and writes capture slates for normal non-headless runs.
