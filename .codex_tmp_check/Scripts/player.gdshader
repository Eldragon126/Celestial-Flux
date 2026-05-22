shader_type canvas_item;

// Use 'additive' blending (makes it glow and get brighter on top of things)
render_mode blend_add;

uniform vec4 engine_color : source_color = vec4(1.0, 0.5, 0.0, 1.0); // Orange
uniform float flicker_speed : hint_range(0.0, 10.0) = 5.0;

void fragment() {
    // 1. Simple sine pulse based on Time
    // Adding 1.0 and dividing by 2.0 maps it from [-1,1] to [0,1]
    float pulse = (sin(TIME * flicker_speed) + 1.0) / 2.0;
    
    // 2. Add some 'jitter' to make it feel less artificial
    float jitter = fract(sin(TIME * 78.233) * 43758.5453) * 0.2;
    
    // Combine color with pulse and jitter
    COLOR = engine_color;
    COLOR.a = (pulse + jitter) * 0.8; 
}
