shader_type canvas_item;

// Base configuration
uniform int lineas = 180;              
uniform float velocidad = 1.2; // Slightly slowed down for an atmospheric, less flashy feel     
uniform float ondulacion = 0.12;     
uniform float frecuencia = 4.0;   

// Cosmic Neon Blue Palette
uniform vec4 color_a : source_color = vec4(0.02, 0.15, 0.4, 0.5);  // Deep celestial blue
uniform vec4 color_b : source_color = vec4(0.01, 0.02, 0.08, 0.7); // The dark cosmic void
uniform vec4 color_neon : source_color = vec4(0.0, 0.85, 1.0, 1.0); // Electric Neon Cyan

// Spacetime distortion
uniform float gravity_strength = 0.45;
uniform vec2 gravity_center = vec2(0.5, 0.5); 
uniform float real_time; 

void fragment() {
    vec2 uv = UV;
    
    // --- 1. ELEVATED GRAVITY CURVATURE ---
    // Smooth, organic bending of space rather than harsh tracking errors
    float dist_to_center = distance(uv, gravity_center);
    vec2 pull_dir = normalize(gravity_center - uv);
    
    // Creates a breathing, undulating gravitational tide
    float gravity_pulse = sin(real_time * velocidad - dist_to_center * 10.0) * 0.5 + 0.5;
    float pull_strength = pow(1.0 - dist_to_center, 2.5) * gravity_strength * (0.6 + 0.4 * gravity_pulse);
    uv += pull_dir * pull_strength;

    // --- 2. INTERLOCKED WAVE SIMULATION ---
    float id_linea = floor(uv.y * float(lineas));
    float sentido = (mod(id_linea, 2.0) == 0.0) ? 1.0 : -1.0;
    
    // Mixing two waves at different frequencies stops the pattern from looking like a simple "sine wave"
    float wave_primary = sin(uv.y * frecuencia + real_time * velocidad);
    float wave_secondary = cos(uv.x * (frecuencia * 0.4) - real_time * (velocidad * 0.6));
    float desfaso_fluido = (wave_primary * 0.75 + wave_secondary * 0.25) * ondulacion;
    
    float movimiento_h = (real_time * velocidad * 0.15) * sentido;
    uv.x += movimiento_h + (desfaso_fluido * sentido);
    
    // --- 3. PATTERN GENERATION ---
    float patron = step(0.5, fract(uv.x * 2.0));
    
    // --- 4. COLOR MIXING & NEON HIGHLIGHTS ---
    vec3 color_final = mix(color_a.rgb, color_b.rgb, patron);
    float alpha_final = mix(color_a.a, color_b.a, patron);
    
    // Isolate the curved grid edges to apply a smooth glow
    float edge_glow = smoothstep(0.3, 1.0, sin(fract(uv.y * float(lineas)) * PI));
    
    // Dynamically blend the neon cyan into the edges based on gravitational stress
    float neon_blend = edge_glow * (0.2 + 0.8 * gravity_pulse) * (1.0 - dist_to_center);
    color_final = mix(color_final, color_neon.rgb, neon_blend * 0.7);
    alpha_final += neon_blend * color_neon.a * 0.4;
    
    // Mask out the lines cleanly
    alpha_final *= edge_glow; 
    
    // Smoothly fade to total nothingness at the very center of the anomaly
    alpha_final *= smoothstep(0.02, 0.18, dist_to_center);

    COLOR = vec4(color_final, alpha_final * COLOR.a);
}