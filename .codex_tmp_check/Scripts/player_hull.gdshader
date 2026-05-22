shader_type canvas_item;

uniform vec4 hull_color : source_color = vec4(0.12, 0.72, 1.0, 0.92);
uniform vec4 rim_color : source_color = vec4(0.55, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.85;
uniform float pulse_speed : hint_range(0.0, 12.0) = 2.4;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec4 base = hull_color;
	float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
	float rim = smoothstep(0.35, 0.0, abs(UV.x - 0.5) + abs(UV.y - 0.5) * 0.6);
	vec3 rim_mix = mix(base.rgb, rim_color.rgb, rim * rim_strength);
	COLOR = vec4(mix(rim_mix, rim_color.rgb, pulse * pulse_amount), base.a);
}
