# SYSTEM SPECIFICATION: POLAR RESONANCE FIELDS
## Project: VECTOR ANOMALY (Godot 4.4 / GDScript 2.0)
## Module: Audio-Reactive Polar Coordinate System Matrix

---

## 1. NODE TREE LAYOUT
This structure uses light programmatic composition over standard physics bodies. It samples entity coordinates directly rather than relying on heavy scene scans or non-circular native area matrices.

PolarResonanceField (Node2D)                <-- Master processing script (Math & Polar Conversion)
├── EdgeVisualizer (Line2D)                 <-- Draws the sharp, closed vector perimeter
└── TelemetrySpokes (Line2D or Node2D)      <-- Draws faint structural lines from center to boundary

---

## 2. ENGINEERING ROADMAP

### PHASE A: CARTESIAN-TO-POLAR TRANSFORMATION & BOUNDARY
1. [ ] **Calculate Relative Position:** Compute local offset vector (`target.global_position - global_position`).
2. [ ] **Extract Current Radius ($r$):** Calculate the length of the local offset vector.
3. [ ] **Extract Angle ($\theta$):** Compute the polar angle using `atan2(y, x)` (returns range between $-\pi$ and $\pi$).
4. [ ] **Implement Shape Evaluators:** Create a script interface that takes $\theta$ and outputs the matching boundary radius $r_{\text{bound}}$:
   - **Accretion Rose:** $r = R_0 + A \cos(k\theta)$
   - **Limacon:** $r = b + a \cos(\theta)$
5. [ ] **Containment Flag:** Write a function checking if $r < r_{\text{bound}}$ to confirm an entity is inside the field.

### PHASE B: PROCEDURAL LINE REGISTRY & RENDERING
1. [ ] **Coordinate Loop:** Build a step loop iterating from $0$ to $2\pi$ (e.g., 64 or 128 interpolation increments).
2. [ ] **Convert Back to Cartesian:** For every increment, convert back to Cartesian space using:
   - $x = r_{\text{bound}} \cos(\theta)$
   - $y = r_{\text{bound}} \sin(\theta)$
3. [ ] **Populate Line2D:** Load these calculated positions into the `EdgeVisualizer.points` array.
4. [ ] **Clamping Alpha:** Multiply line transparency by the global accessibility scalar `Settings.flash_alpha()`.

### PHASE C: VECTOR FIELD INJECTION & VELOCITY MODIFIERS
1. [ ] **Derive Radial Component:** Calculate the unit direction pushing outward from the origin (`local_pos.normalized()`).
2. [ ] **Derive Perpendicular Tangent:** Rotate the radial vector 90 degrees to find the clean orbital path:
   - `Vector2(-radial.y, radial.x)`
3. [ ] **Apply Kinetic Forces:** Access entities flagged inside the boundary. Modify their physics loops by injecting a velocity boost along the **tangent vector** (orbital tracking) or reducing velocity along the **radial vector** (gravity compression).

### PHASE D: REACTION ENGINE (3BLUE1BROWN FOURIER ADAPTATION)
1. [ ] **Audio Bus Setup:** Create an audio bus named `"Music"` in the mixer and attach an `AudioEffectSpectrumAnalyzer`.
2. [ ] **Sample Frequencies:** Create a process function that pulls real-time magnitude data from specific audio frequency ranges.
3. [ ] **Link to Math:** Replace your static variables ($A$ for amplitude, $k$ for lobes) with these smoothed audio magnitude values.
4. [ ] **Dynamic Redraw:** Call `queue_redraw()` or rebuild the loop points every frame so the field physically warps its collision boundaries directly to the track's rhythm.

---

## 3. CORE MATHEMATICAL FORMULAS FOR REFERENCE

### Coordinates
$$r = \sqrt{x^2 + y^2}$$
$$\theta = \tan^{-1}\left(\frac{y}{x}\right)$$

### Vector Re-Conversion
$$x = r \cdot \cos(\theta)$$
$$y = r \cdot \sin(\theta)$$

### Orbital Tangent Generation
$$\vec{T} = \begin{pmatrix} -y_{\text{radial}} \\ x_{\text{radial}} \end{pmatrix}$$