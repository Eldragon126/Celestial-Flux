# VECTOR ANOMALY — SIMILARITY BLUEPRINT
## What MUST Feel Familiar (Even While Everything Evolves)

---

## Core Identity Anchor

Vector Anomaly should remain emotionally and mechanically recognizable to players familiar with:
Nova Drift-inspired roguelike arena survival games.

The goal is not imitation.
The goal is **legibility through familiarity**.

Players should always subconsciously understand:
- “I know how this *kind* of game breathes”
even while consciously thinking:
- “I’ve never seen it behave like THIS before.”

---

## 1. Core Gameplay Loop Similarities

These systems SHOULD remain structurally familiar:

- Wave-based arena survival loop
- Run-based progression (death resets run state)
- Incremental build evolution through upgrades
- Increasing difficulty over time through pressure scaling
- Player skill = primary survival determinant

**Why this matters:**
Players need a stable cognitive anchor so physics complexity feels expressive, not confusing.

---

## 2. Upgrade Philosophy (Familiar Shape, New Substance)

Upgrade systems should feel structurally similar to:

- Choice between multiple upgrade paths
- Synergy stacking over time
- Build identity emerging mid-run
- Compounding effects rather than flat stats

**Important constraint:**
Even if effects are physics-based (gravity, orbit, time), the *decision rhythm* must feel familiar:
> “Pick 1 of 3, build toward identity”

---

## 3. Combat Readability

Despite physics complexity, combat should preserve:

- Clear enemy intent signaling
- Predictable attack patterns (even if physics-altered)
- Strong visual contrast between threat types
- Immediate feedback on damage, force, and movement impact

**Core similarity goal:**
The player should never feel lost in physics noise.

---

## 4. Arena Progression Structure

Maintain familiar escalation patterns:

- Early waves = readable, slow learning phase
- Mid waves = build expression begins to matter
- Late waves = systemic overload / mastery check

Even if the *rules change*, the **pacing grammar stays consistent**.

---

## 5. Movement as Primary Skill

Like comparable arena roguelikes, movement remains:

- The main defensive tool
- The main survival skill
- The core expressive mechanic

Difference is NOT removal of movement skill,
but **augmentation with gravitational strategy**

---

## 6. Risk vs Reward Clarity

Players should always understand:

- What is dangerous
- What is beneficial
- What creates escalation risk

Even if systems are complex, the *risk language* must stay familiar:
- bigger effects = higher chaos
- stronger builds = more instability
- survival = controlled risk management

---

## 7. Build Identity Emergence

Like genre peers, builds should:

- Become recognizable within 2–3 upgrades
- Develop a clear “fantasy identity”
- Feel distinct even under chaos conditions

Examples of expected readability:
- “Orbit control build”
- “Singularity chaos build”
- “Time fracture precision build”

---

## 8. Failure Feel (Critical Similarity)

Death should feel:

- Fast to understand
- Fair in retrospect
- Linked to decision-making or positioning

Not random.
Not opaque.
Not narratively explained.

Players should say:
> “I understand exactly how I died.”

---

## DESIGN PHILOSOPHY SUMMARY

Vector Anomaly should feel like:

A familiar roguelike arena shooter structure  
wrapped around an unfamiliar physics reality engine.

The structure is the handshake.  
The physics is the shockwave.

---

## Production Familiarity Guardrails

The current architecture preserves genre readability while scaling the unusual physics layer:

- Wave pacing, boss anchors, death flow, and run anchors stay familiar.
- Gravity, projectiles, enemies, bosses, and debris are cached through `RuntimeRegistry` so late-wave spectacle does not turn into frame instability.
- Upgrade effects remain behavioral: micro-lensing, vacuum collapse, orbital debris, chronal refraction, relativistic rail, Barycentric Tether, Frame-Dragging Anchor, and Apex Vector create new movement/combat decisions rather than flat stat inflation.
- VFX communicates state through pooled rings, pooled burst particles, HUD arrows, local time-pocket signals, and resonance colors.
- Failure readouts remain immediate and diagnostic instead of lore-heavy.
- The headless production simulation runner validates stress budgets so the familiar wave/run structure does not collapse into unreadable performance failure.
- Resonance, momentum, boss pressure fields, enemy readability, death diagnostics, adaptive music, stress reporting, and sync scaffolding use capped cached queries so readability does not degrade as physics density rises.
- Opening and credit labels use Vector Anomaly terms, keeping the player's first and final textual beats aligned with the commercial identity.

## 2026-06-02 Readability Corrections

- Boss difficulty now escalates through authored pressure rather than flat pacing drift: players still recognize boss anchors, but each anchor demands stronger movement mastery.
- Gravity Wave Beam now behaves like a familiar beam weapon with an unfamiliar physics payload: damage remains legible while enemy drift reveals the gravity manipulation.
- Slingshot mastery no longer floods the screen on routine success. Great/apex timing gets the big feedback, making high-skill motion easier to understand and easier to clip.
- Player-adjacent colored telemetry rings are disabled by default. Core state stays in compact HUD readouts so the player's body language remains readable.
- Death is immediate to understand: no post-death shooting, no false comeback, no delayed surprise transition.
- Tutorial prompts now teach the genre handshake first: thrust, tangent, speed, distance, time precision, and beam field control.

## 2026-06-03 Feel And Readability Corrections

- Drag ON now has its own identity as Precision control: braking, tangent cleanup, recovery routing, and short energy recovery inside gravity windows. Drag OFF remains the Momentum style.
- Gravity Wave Beam produces clearer results by moving hostile bodies, bending projectiles, shifting destructible planets, and applying planet fracture pressure.
- Chronal Refraction Beam now reads as time manipulation through capped echo traces, delayed desync impulses, and short echo zones.
- Vector Bolts are larger, faster, and sharper while the predictor uses the same constants/source filters. Baseline bullets no longer orbit the player from self-gravity; intentional Orbital Tether captures are tagged.
- The title screen now exposes a playable tutorial scene so players can practice thrust, drag, slingshots, bolts, Gravity Wave, and Chronal Beam without waiting for a run to teach them.
- Purple/pink temporal overload is capped through reduced flash/radius budgets, lower VFX burst counts, glitch cooldowns, local slow budgets, and a safe global time-scale floor.

## 2026-06-05 Multiplayer And Trajectory Milestone

- LAN host/join support now gives the familiar co-op shape players expect: one player hosts, others join by IP/port, each player controls one ship, and the host owns run start/restart.
- Multiplayer preserves the genre handshake by keeping solo rules intact. Remote players are readable proxies, enemies target valid players through roster-aware helpers, and shared vector events create co-op payoff without changing basic movement grammar.
- Peer nameplates and player colors add immediate co-op legibility without adding menu clutter or hiding the arena.
- Steam support should feel like the same co-op experience with a different transport. Add Steam lobbies/peers behind `NetworkSession`; do not fork gameplay rules for Steam.
- The orbital trajectory predictor is restored as a readable future-path affordance: orange danger, cyan path, glow, and fade. It supports the familiar “where am I going?” player need while selling the unfamiliar gravity-collapse spectacle.
- Continued functionality depends on tests and contracts: two-instance LAN smoke validation, late-join reconciliation, disconnect UX, version/mod handshake, and explicit network categories for new abilities.

## 2026-06-02 Launch Matrix Completion

- Barycentric Tether uses a familiar crowd-control shape while changing the substance: enemies are linked by an artificial center of mass and forced into binary orbital motion.
- Frame-Dragging Anchor uses a familiar aura-field shape while changing the substance: hostile bodies and projectiles are rotationally dragged around the player instead of simply slowed or damaged.
- Settings now persist across launches, so readability options behave like a finished game menu rather than temporary debug switches.
