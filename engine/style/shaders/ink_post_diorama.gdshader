shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, skip_vertex_transform, cull_disabled, fog_disabled;
// Diorama post pass (night of 20 Nov), chosen by the style key `ink.shader` = "ink_post_diorama". It takes the place of
// the ink pass (ink_post.gdshader, untouched): a handmade model has no drawn contour. What holds the pieces together
// instead is shade where they meet:
//   - contact: a tight, dark shade within `contact_radius` metres of where something stands on something else (boots
//     on the road, a post in the grass, a cone on the floor, the collar on the jacket)
//   - occlusion: a wide, soft shade within `ao_radius` metres (under a platform, between scaffold bays, in a corner)
//   - seam: a soft dark line in a concave crease and a faint one where one piece ends in front of another, so two
//     pieces of the same colour still read as two pieces. No line on thin members and none in the distance.
// The shade is a smooth gradient (the classic contact wash is two flat steps) laid over the picture in `ao_color`.
// The engine's SSAO cannot do this: the toon material is `ambient_light_disabled` and writes its own light.
// The tap spiral is turned per pixel by a fixed screen pattern (interleaved gradient noise): with one fixed spiral a
// thin post throws a sharp copy of itself on the ground for every tap that crosses it; turned, the copies melt into
// one soft shade. The pattern does not change from frame to frame, and flat ground gets no shade at all (the plane
// test), so nothing boils.
global uniform vec4 g_haze;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec3 ao_color : source_color = vec3(0.20, 0.10, 0.14);
uniform float ao_k = 0.5;            // strength of the wide shade (0 = off)
uniform float ao_radius = 1.2;       // metres
uniform float contact_k = 0.7;       // strength of the tight shade (0 = off)
uniform float contact_radius = 0.3;  // metres
uniform float ao_gain = 9.0;         // how fast the wide shade fills (the response is 1 - exp(-gain x filled share))
uniform float contact_gain = 12.0;   // the same for the tight shade
uniform float ao_far = 160.0;        // metres; gone by here
uniform float ao_max = 0.72;         // the darkest the shade gets (share of ao_color)
uniform float seam_k = 0.35;         // the soft crease line (0 = off)
uniform float seam_px = 1.6;         // its half width, px at 1080
uniform float edge_k = 0.18;         // the faint line where a piece ends in front of another (0 = off)
uniform float seam_near = 30.0;      // metres: lines are full to here ...
uniform float seam_far = 110.0;      // ... and gone here
uniform float ao_debug = 0.0;        // > 0.5: paint the shade alone, black on white (review only)

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

vec3 view_pos(vec2 uv, mat4 inv) {
	vec4 v = inv * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	return v.xyz / v.w;
}

// 16 taps on a spiral of `radius` metres round p0: a tap shades when it rises above the surface's own plane and is
// near; taps close to the point count more. The result is small in practice (a first response
// curve made for values near 0.3 left the shade almost invisible), which is why fragment() applies a gain.
float ring(vec2 uv, vec3 p0, vec3 n0, float radius, float turn, mat4 inv, vec2 proj) {
	vec2 ruv = radius * 0.5 * proj / max(-p0.z, 0.3);
	float occ = 0.0;
	float wsum = 0.0;
	for (int i = 0; i < 16; i++) {
		float a = turn + float(i) * 2.39996;                  // the golden angle: no two taps on one ray
		float rr = sqrt((float(i) + 0.5) / 16.0);
		vec3 v = view_pos(uv + vec2(cos(a), sin(a)) * ruv * rr, inv) - p0;
		float l = length(v) + 0.0001;
		float w = 1.25 - rr * 0.5;
		occ += w * max(dot(n0, v / l) - 0.12, 0.0) * (1.0 - smoothstep(radius * 0.6, radius * 1.6, l));
		wsum += w;
	}
	return occ / wsum;
}

void fragment() {
	float k = VIEWPORT_SIZE.y / 1080.0;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 p0 = view_pos(uv, INV_PROJECTION_MATRIX);
	float d0 = -p0.z;
	float total = 0.0;
	if (d0 < ao_far) {
		vec3 n0 = texture(nr_tex, uv).rgb * 2.0 - 1.0;
		vec2 proj = vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]);
		float fade = 1.0 - smoothstep(ao_far * 0.45, ao_far, d0);
		float shade = 0.0;
		float turn = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) * 6.2831853;
		if (contact_k > 0.0) {
			float c = ring(uv, p0, n0, contact_radius, 0.4 + turn, INV_PROJECTION_MATRIX, proj);
			shade = (1.0 - exp(-c * contact_gain)) * contact_k;
		}
		if (ao_k > 0.0) {
			float w = ring(uv, p0, n0, ao_radius, 1.9 + turn, INV_PROJECTION_MATRIX, proj);
			shade = shade + (1.0 - exp(-w * ao_gain)) * ao_k * (1.0 - shade * 0.6);
		}
		total = min(shade, 1.0) * ao_max * fade;
		// seams: four taps across the pixel at the line's half width
		float line_fade = 1.0 - smoothstep(seam_near, seam_far, d0);
		if ((seam_k > 0.0 || edge_k > 0.0) && line_fade > 0.0) {
			vec3 vdir = normalize(p0);
			float graze = clamp(abs(dot(n0, -vdir)), 0.10, 1.0);
			float inv_d = graze / max(d0, 0.001);
			float w = seam_px * k;
			float crease = 0.0;
			float cnt = 0.0;
			float thin = 0.0;
			for (int i = 0; i < 4; i++) {
				float a = float(i) * 0.7853982;
				vec2 off = vec2(cos(a), sin(a)) * px * w;
				vec3 pp = view_pos(uv + off, INV_PROJECTION_MATRIX);
				vec3 pm = view_pos(uv - off, INV_PROJECTION_MATRIX);
				float ep = smoothstep(0.03, 0.08, (-pp.z - d0) * inv_d);
				float em = smoothstep(0.03, 0.08, (-pm.z - d0) * inv_d);
				cnt += ep + em;
				thin = max(thin, ep * em);
				vec3 np = texture(nr_tex, uv + off).rgb * 2.0 - 1.0;
				vec3 nm = texture(nr_tex, uv - off).rgb * 2.0 - 1.0;
				// a concave crease only: the two sides lean towards each other
				float cp = (1.0 - dot(np, n0)) * step(-pp.z, d0 * 1.02) * step(0.0, dot(np, p0 - pp));
				float cm = (1.0 - dot(nm, n0)) * step(-pm.z, d0 * 1.02) * step(0.0, dot(nm, p0 - pm));
				crease = max(crease, max(cp, cm));
			}
			float seam = smoothstep(0.25, 0.9, crease) * seam_k;
			float edge = smoothstep(0.0, 3.0, cnt) * edge_k * (1.0 - thin);
			total = max(total, max(seam, edge) * line_fade);
		}
	}
	float haze = 1.0 - exp(-d0 * g_haze.a * 1.4);
	ALBEDO = mix(ao_color, g_haze.rgb * 0.5, clamp(haze, 0.0, 0.7));
	ALPHA = total;
	if (ao_debug > 0.5) { ALBEDO = vec3(1.0 - total); ALPHA = 1.0; }
}
