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
- Upgrade effects remain behavioral: micro-lensing, vacuum collapse, orbital debris, chronal refraction, relativistic rail, and Apex Vector create new movement/combat decisions rather than flat stat inflation.
- VFX communicates state through pooled rings, pooled burst particles, HUD arrows, local time-pocket signals, and resonance colors.
- Failure readouts remain immediate and diagnostic instead of lore-heavy.
- The headless production simulation runner validates stress budgets so the familiar wave/run structure does not collapse into unreadable performance failure.
- Resonance, momentum, boss pressure fields, enemy readability, death diagnostics, adaptive music, stress reporting, and sync scaffolding use capped cached queries so readability does not degrade as physics density rises.
- Opening and credit labels use Vector Anomaly terms, keeping the player's first and final textual beats aligned with the commercial identity.
