# VECTOR ANOMALY
## The Commercial Separation Blueprint (Million-Dollar Revision)

---

# Core Truth (Reframed for Money)

Most arena roguelikes fail commercially for one reason:

They are fun to play, but not impossible to describe in 5 seconds.

VECTOR ANOMALY must be:

> a physics collapse simulator where survival is a skill expression of gravity manipulation

More importantly:

> a game that looks unfakeable in motion

If someone cannot explain it instantly but cannot forget it after seeing it once, it wins.

---

# The Market Hook (Optimized for Conversion)

## Elevator Pitch (Steam Page Ready)

A physics roguelike where you don’t just dodge bullets, you survive collapsing gravity, unstable spacetime, and orbital combat that rewrites itself mid-fight.

---

## Secondary Hook (Streamer Hook)

“I didn’t lose because I died. I lost because physics changed.”

---

# The Real Money Layer

The product is not mechanics.

The product is:

> watchable impossibility

Indie games win when they are:

- instantly visually confusing
- clearly skill-based underneath
- endlessly clip-worthy

---

# THE FOUR PILLARS

---

# 1. MOVEMENT = READABLE GENIUS

Movement must behave like:

- chaos at low skill
- intention at mid skill
- impossibility at high skill

## Design Rule

Every movement system must generate clips.

---

# 2. PHYSICS = SPECTACLE FIRST

Physics is not simulation accuracy.

Physics is:

> controlled visual collapse

## Required Feel

- gravity visibly warps space
- orbit paths break and reform
- time dilation is physically visible
- enemies drift in non-Euclidean motion

---

# 3. VISUAL IDENTITY = ALGORITHMIC COLLAPSE

The game must look:

> like a GPU hallucinating a dying universe

## Visual Progression

Early:
- sterile monochrome vectors

Mid:
- cyan + violet instability

Late:
- neon fractures + red gravity warnings

---

# 4. EMOTIONAL LOOP = NEAR MISS ADDICTION

Core emotional state:

> I should have died but didn’t

The game must constantly generate:

- last-frame escapes
- accidental genius plays
- physics-assisted survival

---

# VIRAL MECHANICS (CORE MONEY DRIVERS)

---

## 1. Gravity Ghost Replay System

After death:

- replay last 10–20 seconds
- show survival trajectory
- highlight “impossible saves”

Purpose:
> players generate their own marketing clips

---

## 2. “WHAT JUST HAPPENED?” EVENTS

- gravity inversion storms
- orbit collapse pulses
- spacetime fractures

Rule:

Events must be confusing in real-time but understandable after.

---

## 3. RESONANCE COMBO SYSTEM

- matching frequencies create chain reactions
- chain reactions escalate visuals
- escalation increases score and spectacle

Purpose:
> streamer dopamine + clip escalation ladder

---

## 4. EVENT HORIZON MODE

Late-game collapse state:

- UI distortion
- orbit instability maxed
- music warping
- visual tearing

Purpose:
> automatic trailer generator inside gameplay

---

# WHAT TO REMOVE

Do NOT build:

- weapon spam systems
- RPG stat inflation
- filler upgrades
- HP sponge enemies
- non-clip-generating mechanics

Rule:

If it does not create a shareable moment, it is debt.

---

# STEAM PAGE STRATEGY

## Screenshot Rule

Every screenshot must trigger:

“How is that movement possible?”

## Trailer Structure

1. calm baseline physics
2. first gravity distortion
3. escalating instability chain
4. event horizon collapse
5. impossible survival moment
6. title slam

---

# PRICING STRATEGY

Recommended:

$9.99 – $14.99

Reason:

You are selling intensity, not content hours.

---

# VIRAL LOOP DESIGN

Core loop:

PLAY → CHAOS MOMENT → CLIP → SHARE → WISHLIST

Every system must feed this loop.

---

# DEVELOPMENT PRIORITY

## Phase 1
Movement feel + gravity interaction clarity

## Phase 2
Physics instability systems

## Phase 3
Replay + event horizon systems

## Phase 4
Polish density + visual clarity

---

# FINAL VISION

VECTOR ANOMALY is not a shooter.

It is a:

> survivable visual paradox generator

Players do not just play to win.

They play to experience impossible moments that become understandable only after survival.

That gap between confusion and mastery is the engine that makes the game shareable, watchable, and commercially viable.

---

# Production Separation Update

Vector Anomaly now separates hot simulation state from scene-tree discovery through `RuntimeRegistry`.

- Combat systems ask the registry for cached projectile/enemy/gravity lists.
- Gravity systems request capped nearest sources instead of sorting all sources locally.
- VFX systems read cached projectile pressure and reuse pooled burst/ring nodes.
- Mod manifests use `vector_anomaly_mod.json`, keeping public naming aligned with the commercial identity.

The separation rule is now explicit: gameplay may create physics dread, but production systems must keep discovery, pooling, save anchoring, UI, and data-driven content isolated from each other.

## Production Boundary Update

Late-wave spectacle now has explicit technical boundaries:

- `RuntimeRegistry` owns hot discovery and reuses scratch buffers for nearest gravity and target-radius queries.
- Dynamic gravity debris and tide-pocket gravity sources register with the cache at group-entry time and unregister on exit.
- `OrbitalVFXDirector` owns pooled particle bursts; gameplay systems emit events instead of duplicating particles.
- `PowerupInventory` owns pooled law/powerup rings and reusable target buffers for upgrade effects.
- `production_simulation_runner.gd` owns headless stress validation and reports frame/projectile/VFX budgets without becoming part of gameplay state.

The commercial rule remains unchanged: the player should see impossible physics, while the code keeps discovery, pooling, validation, UI, saves, and content manifests separated into inspectable systems.
