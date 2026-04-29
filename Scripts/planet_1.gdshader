shader_type canvas_item;

uniform vec4 planet_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 flare_color : source_color = vec4(1.0, 1.0, 1.0, 0.3); // Semi-transparent white
uniform float flare_size : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    // 1. Calculate distance from center
    float dist = distance(UV, vec2(0.5));
    
    // 2. Cut into a perfect circle (keeps it 'shapey')
    //if (dist > 0.5) {
    //    discard;
    //}

    // 3. Create a simple 'crescent' flare
    // This shifts the circle math to create a highlight on one side
    float flare = smoothstep(0.5, 0.5 - flare_size, distance(UV, vec2(0.35, 0.35)));
    
    // 4. Mix the base color with the flare
    vec3 final_color = mix(planet_color.rgb, flare_color.rgb, flare * flare_color.a);
    
    COLOR = vec4(final_color, 1.0);
}