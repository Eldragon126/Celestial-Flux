# Vector Anomaly Seed Codes

Seed codes are entered in the title-screen seed field before starting a run. Blank starts a random run. Numbers and ordinary text still create deterministic seeds, while the named codes below force a specific showcase profile with visible anomaly behavior.

Copied run codes from the pause menu can be pasted back into the seed field. A named copied code looks like `standard:LENSSTORM:426100:0`; the name is what restores the special profile.

## Named Showcase Codes

| Code | Run law | What it does |
| --- | --- | --- |
| `LENSSTORM` | Comet Wake | Player shots shed bright micro-lensing rings. The rings curve nearby combatants and make the anomaly system obvious from the first volley. |
| `DEBRISRAIN` | Dense Stars | Extra orbital debris seeds around gravity wells throughout the run. Strong slingshots can kick off additional fragments. |
| `TIMESPLIT` | Temporal Draft | The arena periodically paints paired slow and repay zones along the player's movement vector. |
| `GHOSTORBIT` | Quiet Recovery | The orbital memory trail is longer, brighter, and exerts stronger pull along the player's previous path. |
| `COLLAPSEGARDEN` | Volatile Lattice | Projectiles carry vacuum-collapse stacks, high-grade slingshots bloom collapses, and the arena periodically plants visible collapse pulses. |
| `RAILSPLIT` | Comet Wake | Player projectiles carry relativistic rail stacks, accelerating into brighter impact lines and rail-hit anomaly bursts. |
| `CASCADECHOIR` | Dense Stars | Resonance cascades charge faster and the arena periodically seeds harmonic rings near the player. |

## General Seed Inputs

| Input | Result |
| --- | --- |
| Blank field | Random run seed with the normal seed-selected run law. |
| Number, such as `12345` | Exact deterministic seed. The seed also selects one of the five base run laws by `seed % 5`. |
| Text, such as `orbit picnic` | Deterministic hash of the text. Useful for community challenges where a memorable phrase is nicer than a number. |
| Copied numeric run code, such as `standard:12345:8` | Restores the numeric seed from the copied code. The final number is the wave when it was copied and is informational. |
| Copied named run code, such as `standard:DEBRISRAIN:426101:0` | Restores the named showcase profile and its fixed seed. |

## Base Run Laws

Numeric and arbitrary text seeds still map to these five baseline run laws:

| Law | Selection | Baseline effect |
| --- | --- | --- |
| Comet Wake | `seed % 5 == 0` | Better slingshot gravity boost and gravity charge from motion. |
| Dense Stars | `seed % 5 == 1` | Slightly denser enemy pressure and one more resonance zone. |
| Temporal Draft | `seed % 5 == 2` | Stronger near-miss time charge and faster arena events. |
| Quiet Recovery | `seed % 5 == 3` | Longer recovery pacing and shorter hazard lifetime. |
| Volatile Lattice | `seed % 5 == 4` | Faster instability growth and lower resonance strength floor. |
