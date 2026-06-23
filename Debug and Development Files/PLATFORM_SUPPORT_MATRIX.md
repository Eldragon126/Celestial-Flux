# VECTOR ANOMALY Platform Support Matrix

Date: 2026-06-23
Build target: v1.0.4.7
Status: code-side platform pass complete; manual exported-build validation still required.

## Current Runtime Support

| Platform | Status | Notes |
| --- | --- | --- |
| Windows | Primary playtest target | Public Windows playtest link is the current configured download surface. |
| Linux | Godot export-ready path | Requires normal Linux export and controller smoke test. |
| macOS | Godot export-ready path | Requires notarization/signing decisions and macOS controller smoke test. |
| Steam Deck | PC handheld target | Input layer now supports controller auto-detect, right-stick aim, deadzone tuning, and reduced-flash/readability settings. Validate both native Linux and Proton paths. |
| Xbox | Partner SDK required | Gameplay/input architecture is compatible with controller-first play, but console export cannot be completed without platform approval and SDK access. |
| PlayStation | Partner SDK required | Same status as Xbox: controller-first path is code-ready, platform export is external. |
| Nintendo Switch | Partner SDK required | Requires Nintendo SDK access, performance certification work, and handheld readability testing. |
| Nintendo Switch 2 | Partner SDK required | Treat as a separate certification target once official export requirements are known. |

## Code-Side Support Added In v1.0.4.7

- Runtime input actions are ensured for keyboard, left-stick movement, right-stick aim, D-pad heat-map toggle, and alternate/back movement.
- Input type auto-detect switches between controller and mouse/keyboard based on live input events.
- Controller deadzone and right-stick aim are persisted in `Settings` and exposed in the pause menu.
- Player controller aim now chooses the first connected joypad instead of assuming device `0` only.
- Multiplayer status surfaces protocol, quality, peer count, and readability budgets for LAN smoke tests.
- HUD scale now resizes the HUD root to the inverse viewport so top-right score panels remain visible at high UI scale.

## Manual Validation Checklist

- Windows: keyboard/mouse, Xbox controller, PlayStation controller over USB/Bluetooth, UI scale 0.75/1.0/1.35.
- Linux: native build launch, controller detection, fullscreen/windowed, LAN host/client.
- macOS: signed build launch, controller detection, fullscreen/windowed, LAN host/client.
- Steam Deck: gamepad template, right-stick aim, D-pad heat map, pause menu navigation, 1280x800 HUD layout.
- Console candidates: run a certification gap review for save paths, controller glyphs, safe area, suspension/resume, and platform networking before any public commitment.

## Public Messaging Rule

Only advertise Windows as playable until exported builds are captured and reviewed. It is accurate to say "Windows playtest available; Linux, macOS, and Steam Deck validation are next; console targets require partner SDKs."
