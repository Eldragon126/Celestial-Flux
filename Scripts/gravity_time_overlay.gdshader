shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform vec2 gravity_center = vec2(0.5, 0.5);
uniform float radius = 0.28;
uniform float strength = 0.0;

uniform float distortion_strength = 0.18;
uniform float swirl_strength = 3.5;
uniform float chromatic_aberration = 0.006;

uniform float ring_density = 46.0;
uniform float ring_speed = 3.0;
uniform float ring_alpha = 0.35;

uniform float dark_core = 0.45;
uniform float core_alpha = 0.55;

uniform vec4 core_color : source_color = vec4(0.15, 0.85, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.75, 0.15, 1.0, 1.0);

vec2 rotate_vec(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);

	vec2 from_center = uv - gravity_center;
	float dist = length(from_center * aspect);

	float feather = radius * 0.22;
	float field = 1.0 - smoothstep(radius, radius + feather, dist);
	float inner_core = 1.0 - smoothstep(0.0, radius * 0.22, dist);
	float falloff = pow(field, 1.65) * strength;

	vec2 dir = normalize(from_center + vec2(0.00001));
	float ring_wave = sin(dist * ring_density - TIME * ring_speed);
	float rings = smoothstep(0.55, 1.0, ring_wave) * field * (1.0 - inner_core);

	float swirl_angle = falloff * swirl_strength * (1.0 - clamp(dist / radius, 0.0, 1.0));
	swirl_angle *= sin(TIME * 0.75 + dist * 10.0);
	vec2 swirled = rotate_vec(from_center, swirl_angle);

	float sink = distortion_strength * falloff * (1.0 + rings * 0.35);
	vec2 warped_uv = gravity_center + swirled * (1.0 - sink);
	warped_uv += dir * sin(dist * ring_density - TIME * ring_speed) * 0.004 * falloff;

	float chroma = chromatic_aberration * falloff * (0.5 + rings);
	vec2 chroma_offset = dir * chroma;

	vec4 col;
	col.r = texture(screen_texture, warped_uv + chroma_offset).r;
	col.g = texture(screen_texture, warped_uv).g;
	col.b = texture(screen_texture, warped_uv - chroma_offset).b;
	col.a = 1.0;

	vec3 edge_glow = edge_color.rgb * rings * ring_alpha * strength;
	vec3 core_glow = core_color.rgb * inner_core * core_alpha * strength;

	col.rgb += edge_glow + core_glow;
	col.rgb -= inner_core * dark_core * strength;
	col.rgb = mix(col.rgb, col.rgb * vec3(0.82, 0.95, 1.15), field * strength * 0.22);

	COLOR = col;
}
