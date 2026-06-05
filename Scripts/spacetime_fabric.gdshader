shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float real_time = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float crack_density : hint_range(2.0, 16.0) = 7.0;
uniform float line_width : hint_range(0.001, 0.04) = 0.006;
uniform float red_bias : hint_range(0.0, 1.0) = 0.18;
uniform float triangle_alpha : hint_range(0.0, 1.0) = 0.46;
uniform vec4 cyan_color : source_color = vec4(0.0, 0.86, 1.0, 1.0);
uniform vec4 red_color : source_color = vec4(1.0, 0.12, 0.06, 1.0);
uniform vec4 amber_color : source_color = vec4(1.0, 0.62, 0.12, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 uv = UV;
	vec2 drift = vec2(real_time * 0.018, -real_time * 0.012);
	vec2 grid = uv * crack_density + drift;
	vec2 cell = floor(grid);
	vec2 f = fract(grid);

	float h0 = hash21(cell);
	float h1 = hash21(cell + vec2(17.0, 3.0));
	float h2 = hash21(cell + vec2(2.0, 29.0));
	vec2 a = vec2(0.08 + 0.16 * h0, 0.12 + 0.14 * h1);
	vec2 b = vec2(0.82 + 0.12 * h1, 0.18 + 0.22 * h2);
	vec2 c = vec2(0.28 + 0.44 * h2, 0.78 + 0.16 * h0);

	float d = min(segment_distance(f, a, b), min(segment_distance(f, b, c), segment_distance(f, c, a)));
	float line = 1.0 - smoothstep(line_width, line_width * 2.9, d);
	float node_a = 1.0 - smoothstep(0.018, 0.052, length(f - a));
	float node_b = 1.0 - smoothstep(0.018, 0.052, length(f - b));
	float node_c = 1.0 - smoothstep(0.018, 0.052, length(f - c));
	float node_glow = max(node_a, max(node_b, node_c)) * 0.75;

	float left_red = 1.0 - smoothstep(0.0, 0.34, uv.x);
	float right_red = 1.0 - smoothstep(0.0, 0.34, 1.0 - uv.x);
	float lower_red = 1.0 - smoothstep(0.0, 0.26, 1.0 - uv.y);
	float red_mix = clamp(max(left_red, right_red) + lower_red * 0.45 + red_bias * 0.42, 0.0, 1.0);
	float amber_mix = smoothstep(0.78, 1.0, h1) * (1.0 - red_mix) * 0.72;

	vec3 color = mix(cyan_color.rgb, red_color.rgb, red_mix);
	color = mix(color, amber_color.rgb, amber_mix);

	float flicker = 0.72 + 0.28 * sin(real_time * 5.0 + h0 * 12.0);
	float fabric = clamp(line * triangle_alpha + node_glow, 0.0, 1.0) * flicker;
	COLOR = vec4(color * (0.74 + fabric * 0.88), COLOR.a * intensity * fabric);
}
