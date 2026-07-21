# VECTOR ANOMALY — Player Controls

Reference for default bindings in **Project → Input Map** plus a few runtime additions from game settings. On **keyboard and mouse**, the ship **aims at the cursor**; thrust fires along the ship’s nose. On **controller**, aim comes from the **right stick** when enabled in the pause menu (otherwise the left stick can steer facing when pushed far enough).

Gamepad labels below use **Xbox** names first, then **PlayStation** in parentheses where they differ.

---

## Flight

| Action | What it does | Keyboard & mouse | Gamepad |
|--------|----------------|------------------|---------|
| **Thrust** | Accelerate along the ship vector (uses energy) | **W**, **↑** | **A** (Cross) — bottom face button |
| **Rotate counter-clockwise** | Turn ship left (controller); on keyboard, **A** / **←** also strafe-turn when **alternate movement** is enabled | **A**, **←** | D-pad **left**, left stick **left** |
| **Rotate clockwise** | Turn ship right (controller); on keyboard, **D** / **→** also strafe-turn when **alternate movement** is enabled | **D**, **→** | D-pad **right**, left stick **right** |

**Movement tips**

- **Double-tap release** on thrust (quickly let go twice within ~0.35 s) triggers a **dash / boost** when available.
- Optional **alternate movement** (pause menu): **S** or **↓** can act as reverse thrust; **A** / **D** (or arrows) add **strafe turn assist** while that mode is on.
- Optional **player auto-orbit** (pause menu): tangent assistance near gravity wells; thrust and aim behavior otherwise unchanged.

---

## Combat & abilities

| Action | What it does | Keyboard & mouse | Gamepad |
|--------|----------------|------------------|---------|
| **Shoot** | Fire weapons (hold for repeated fire where the weapon allows) | **Left mouse**, **K**, **E**, **Enter**, **Z** | **Right trigger** (RT / R2) — axis 5 + |
| **Toggle** | Toggle **drag mode** on release (preserve speed vs. tighter control) | **Space**, **X**, **Q** | **Left trigger** (LT / L2) — axis 4 + |
| **Time dilation** | Hold to deepen a **local slow field** around the ship (limited capacity; see HUD) | **C** | **L3** (left stick click) — button 7 |

---

## Pause, menus, and confirm

| Action | What it does | Keyboard & mouse | Gamepad |
|--------|----------------|------------------|---------|
| **Menu** | Open or close **pause** (release to toggle in gameplay) | **Esc**, **Enter** | **Y** (Triangle) — button 3; **LB** (L1) — button 9 |
| **Confirm** | Accept in UI, skip some sequences, interact (e.g. docking when in range) | **Left mouse**, **Enter**, **Z** | **B** (Circle) — button 1 |

In menus, use **arrow keys** / **WASD** and **Enter** or **Esc** as usual for focus and back (Godot **ui_*** actions).

---

## Overlays and telemetry

| Key / input | What it does |
|-------------|----------------|
| **F10** | Toggle **gravity heat map** — contour overlay for gravity strength, gradients, and readable routes near strong sources. |
| **D-pad up** | Also toggles the gravity heat map when using a controller (added at runtime alongside **F10**). |
| **F3** | Toggle **balance telemetry** — live debug panel (wave/combat/gravity/time-dilation stats). On by default in the main campaign; disabled in some demo/lab scenes. |

---

## Binding notes

- Several keys are shared on purpose (**Enter**, **Z**, and **left mouse** appear on more than one action). Use the action that matches what you are doing (combat vs. menu vs. confirm).
- **Controller deadzone** and **right-stick aim** are adjustable in the **pause menu** under accessibility / input options.
- Rebindings: change actions in the Godot **Input Map** for the project, or use in-game pause options where exposed (e.g. controller tuning).

For how these controls fit into slingshots, resonance, bosses, and progression, see [HOW_TO_PLAY.md](HOW_TO_PLAY.md).
