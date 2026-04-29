shader_type canvas_item;

uniform vec4 shield_color : source_color = vec4(0.0, 0.7, 1.0, 1.0);
uniform float border_strength : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    // Calculate distance from the center (0.5, 0.5)
    float dist = distance(UV, vec2(0.5));
    
    // Create a pulse using the sine of time
    float pulse = (sin(TIME * pulse_speed) * 0.2) + 0.8;
    
    // Create a glow that gets stronger toward the edges
    // We use smoothstep to make the 'rim' light up
    float rim = smoothstep(0.2, 0.5, dist) * border_strength;
    
    // Apply the color and the pulse
    COLOR = shield_color;
    COLOR.a = rim * pulse;
}