shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, skip_vertex_transform, cull_disabled, fog_disabled;
// Full-screen ink pass (adapted from gtai ink_post): brush contours on silhouettes (depth edges) and pen lines on
// creases (normal edges). Lane B changes: line colour is mixed toward the haze colour with distance, interior lines
// fade out, silhouettes fade last, so far hills dissolve into atmosphere instead of turning into black wire.
global uniform vec4 g_haze;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec3 ink : source_color = vec3(0.17, 0.11, 0.21);
uniform float outer_px = 2.0;
uniform float inner_px = 1.0;
uniform float inner_alpha = 0.7;
uniform float fade_near = 60.0;
uniform float fade_far = 260.0;
uniform float outer_fade_far = 900.0;
uniform float fog_mix = 0.5;
uniform float wobble = 1.0;
uniform float outer_far = 1.0;   // pass 4: outline width at distance as a share of outer_px (thin parts keep their colour)
uniform float thin_near = 25.0;
uniform float thin_far = 110.0;

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1,0)), f.x), mix(h21(i + vec2(0,1)), h21(i + vec2(1,1)), f.x), f.y); }
float lin_depth(vec2 uv, mat4 inv) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	float k = VIEWPORT_SIZE.y / 1080.0;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float wn = vn(uv * VIEWPORT_SIZE / (60.0 * k));
	vec2 juv = uv + (vec2(vn(uv * VIEWPORT_SIZE / (31.0 * k)), vn(uv * VIEWPORT_SIZE / (31.0 * k) + 9.0)) - 0.5) * px * wobble * k * 2.0;
	float d0 = lin_depth(juv, INV_PROJECTION_MATRIX);
	float wo = outer_px * k * (0.75 + 0.5 * wn) * mix(1.0, outer_far, smoothstep(thin_near, thin_far, d0));
	float wi = inner_px * k * (0.8 + 0.4 * wn);
	vec3 n0 = texture(nr_tex, juv).rgb * 2.0 - 1.0;
	vec3 vdir = normalize(vec3((juv * 2.0 - 1.0) * vec2(1.0 / PROJECTION_MATRIX[0][0], 1.0 / PROJECTION_MATRIX[1][1]), -1.0));
	float graze = clamp(abs(dot(n0, -vdir)), 0.10, 1.0);
	float de = 0.0;
	float ne = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		vec2 dir = vec2(cos(a), sin(a));
		float d = lin_depth(juv + dir * px * wo, INV_PROJECTION_MATRIX);
		de = max(de, (d - d0) / max(d0, 0.001));
		vec3 n = texture(nr_tex, juv + dir * px * wi).rgb * 2.0 - 1.0;
		float dn = lin_depth(juv + dir * px * wi, INV_PROJECTION_MATRIX);
		ne = max(ne, (1.0 - dot(n, n0)) * step(dn, d0 * 1.02));
	}
	float outer = smoothstep(0.025, 0.05, de * graze);
	float inner = smoothstep(0.3, 0.6, ne) * inner_alpha;
	inner *= 1.0 - smoothstep(fade_near, fade_far, d0);
	outer *= 1.0 - smoothstep(fade_far, outer_fade_far, d0);
	float haze = 1.0 - exp(-d0 * g_haze.a * 1.4);
	ALBEDO = mix(ink, g_haze.rgb * 0.55, clamp(haze * fog_mix * 1.6, 0.0, 0.85));
	ALPHA = max(outer, inner) * 0.96;
}
