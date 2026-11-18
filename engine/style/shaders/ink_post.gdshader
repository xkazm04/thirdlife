shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, skip_vertex_transform, cull_disabled, fog_disabled;
// Full-screen ink pass (adapted from gtai ink_post): brush contours on silhouettes (depth edges) and pen lines on
// creases (normal edges). Lane B changes: line colour is mixed toward the haze colour with distance, interior lines
// fade out, silhouettes fade last, so far hills dissolve into atmosphere instead of turning into black wire.
// N1 (look pass) changes:
//   - width follows distance: `near_px` up close (bold, like the concept), `outer_px` from `bold_far` on, thinner still
//     past `thin_far`; the width noise is damped by `even`, so a contour keeps one weight along its length
//   - the edge is smoothed: two rings of taps (radius w and the inner radius); a pixel that only the outermost taps
//     reach gets a part tone, so the line has a soft flank instead of a one-pixel stair
//   - thin members keep their colour: when the object under the pixel is narrower than the line (both opposite taps
//     see the background), the contour shrinks to a hairline on its lower right side, and no crease line is drawn
//     on it. Lattices, fences and scaffolds stay coloured bars with one dark side instead of black wire.
//   - the inner (crease) line has its own distance rule: full to `fade_near`, gone at `fade_far`, never on thin members
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
uniform float near_px = 0.0;     // N1: outline width (px at 1080) nearer than bold_near; 0 = outer_px everywhere
uniform float bold_near = 5.0;   // N1: metres
uniform float bold_far = 45.0;   // N1: metres; from here on the outline is outer_px wide
uniform float even = 0.6;        // N1: 0 = the old 25 % width noise, 1 = one weight
uniform float thin_keep = 1.0;   // N1: 0 = thin members get the full contour (old), 1 = hairline on one side only
uniform float hair_alpha = 0.8;  // N1: darkness of that hairline
uniform float inner_near = 0.0;  // N1: the crease line is full to here (m) ...
uniform float inner_far = 0.0;   // N1: ... and gone here; 0 = use fade_near / fade_far as before
uniform float ao_k = 0.0;         // N1: drawn contact shade, 0 = off (the engine's SSAO does not reach the toon shader)
uniform float ao_radius = 0.7;    // N1: metres
uniform float ao_far = 120.0;     // N1: metres; gone by here
uniform vec3 ao_color : source_color = vec3(0.16, 0.12, 0.30);
uniform float body_k = 1.0;       // walker-feel: outline width on a body (a rig: toon writes roughness 0.5 there) as a share of the width
uniform float thin_rings = 0.0;   // walker-feel (L1): 1 = a member is also thin when both opposite taps of the half-width ring or of the inner
                                  // ring see the background. With the wide ring alone the taps of a lattice (a mesh fence, a scaffold) land on the
                                  // next bar from one frame to the next, and the pixel flips between "thin: keeps its colour" and the full contour.
uniform float thin_tone = 0.0;    // walker-feel (L1): far thin members are toned evenly by this much ink in place of the one-sided hairline
uniform float thin_tone_near = 15.0;   // metres: the hairline up to here ...
uniform float thin_tone_far = 45.0;    // ... the even tone from here on (0 tone = the hairline at every distance, as before)
uniform float body_dbg = 0.0;     // > 0.5: paint what the pass takes for a body (review only)

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1,0)), f.x), mix(h21(i + vec2(0,1)), h21(i + vec2(1,1)), f.x), f.y); }
float lin_depth(vec2 uv, mat4 inv) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}
vec3 view_pos(vec2 uv, mat4 inv) {
	vec4 v = inv * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	return v.xyz / v.w;
}

void fragment() {
	float k = VIEWPORT_SIZE.y / 1080.0;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float wn = vn(uv * VIEWPORT_SIZE / (60.0 * k));
	vec2 juv = uv + (vec2(vn(uv * VIEWPORT_SIZE / (31.0 * k)), vn(uv * VIEWPORT_SIZE / (31.0 * k) + 9.0)) - 0.5) * px * wobble * k * 2.0;
	// the contour is drawn INSIDE a silhouette: at 8.5 m a figure's arm is 15 px wide and a 4.8 px line on each side leaves a
	// dark blob. A body (roughness 0.5 in the buffer) gets a thinner line; the wobble of its line is damped too, since a
	// line that wobbles on the screen boils on a limb that moves through it.
	float body = 1.0 - smoothstep(0.6, 0.8, texture(nr_tex, uv).a);
	juv = mix(juv, uv, body * 0.7);
	float d0 = lin_depth(juv, INV_PROJECTION_MATRIX);
	float noise = mix(0.75 + 0.5 * wn, 1.0, even);
	float base_px = near_px > 0.0 ? mix(near_px, outer_px, smoothstep(bold_near, bold_far, d0)) : outer_px;
	float wo = base_px * k * noise * mix(1.0, outer_far, smoothstep(thin_near, thin_far, d0)) * mix(1.0, body_k, body);
	float wi = inner_px * k * mix(0.8 + 0.4 * wn, 1.0, even);
	vec3 n0 = texture(nr_tex, juv).rgb * 2.0 - 1.0;
	vec3 vdir = normalize(vec3((juv * 2.0 - 1.0) * vec2(1.0 / PROJECTION_MATRIX[0][0], 1.0 / PROJECTION_MATRIX[1][1]), -1.0));
	float graze = clamp(abs(dot(n0, -vdir)), 0.10, 1.0);
	float inv_d = graze / max(d0, 0.001);
	float cnt = 0.0;      // taps of the wide ring that look past a silhouette (0..8)
	float thin = 0.0;     // the object is narrower than the line across some axis
	float thin_b = 0.0;   // ... narrower than the inner ring: a wire
	float core = 0.0;     // the inner ring looks past a silhouette: the solid part of the line
	float hair = 0.0;     // the inner ring, lower right side only: the hairline of a thin member
	float ne = 0.0;
	for (int i = 0; i < 4; i++) {
		float a = float(i) * 0.7853982;
		vec2 dir = vec2(cos(a), sin(a));
		float ep = smoothstep(0.025, 0.05, (lin_depth(juv + dir * px * wo, INV_PROJECTION_MATRIX) - d0) * inv_d);
		float em = smoothstep(0.025, 0.05, (lin_depth(juv - dir * px * wo, INV_PROJECTION_MATRIX) - d0) * inv_d);
		cnt += ep + em;
		thin = max(thin, ep * em);
		if (thin_rings > 0.5) {
			float hp = smoothstep(0.025, 0.05, (lin_depth(juv + dir * px * wo * 0.5, INV_PROJECTION_MATRIX) - d0) * inv_d);
			float hm = smoothstep(0.025, 0.05, (lin_depth(juv - dir * px * wo * 0.5, INV_PROJECTION_MATRIX) - d0) * inv_d);
			thin = max(thin, hp * hm);
		}
		float dbp = lin_depth(juv + dir * px * wi, INV_PROJECTION_MATRIX);
		float dbm = lin_depth(juv - dir * px * wi, INV_PROJECTION_MATRIX);
		float fp = smoothstep(0.025, 0.05, (dbp - d0) * inv_d);
		float fm = smoothstep(0.025, 0.05, (dbm - d0) * inv_d);
		core = max(core, max(fp, fm));
		thin_b = max(thin_b, fp * fm);
		thin = max(thin, fp * fm * thin_rings);
		if (i < 3) { hair = max(hair, fp); }
		vec3 np = texture(nr_tex, juv + dir * px * wi).rgb * 2.0 - 1.0;
		vec3 nm = texture(nr_tex, juv - dir * px * wi).rgb * 2.0 - 1.0;
		ne = max(ne, (1.0 - dot(np, n0)) * step(dbp, d0 * 1.02));
		ne = max(ne, (1.0 - dot(nm, n0)) * step(dbm, d0 * 1.02));
	}
	// full weight where the core ring or three wide taps reach the edge; one wide tap = the soft flank
	float outer = max(core, smoothstep(0.0, 2.6, cnt));
	float tk = thin * thin_keep;
	float flat_k = thin_tone > 0.0 ? smoothstep(thin_tone_near, thin_tone_far, d0) : 0.0;
	outer = mix(outer, mix(hair * hair_alpha * (1.0 - 0.45 * thin_b), thin_tone, flat_k), tk);
	float inner = smoothstep(0.3, 0.6, ne) * inner_alpha * (1.0 - tk);
	inner *= inner_far > 0.0 ? 1.0 - smoothstep(inner_near, inner_far, d0) : 1.0 - smoothstep(fade_near, fade_far, d0);
	outer *= 1.0 - smoothstep(fade_far, outer_fade_far, d0);
	float haze = 1.0 - exp(-d0 * g_haze.a * 1.4);
	vec3 inkc = mix(ink, g_haze.rgb * 0.55, clamp(haze * fog_mix * 1.6, 0.0, 0.85));
	float line = max(outer, inner) * 0.96;
	// contact shade: eight taps on two rings of `ao_radius` metres around the point; a tap counts when it rises above
	// the surface's own plane and is close. A flat cool wash, not a gradient: it is quantised to two steps.
	float aoa = 0.0;
	if (ao_k > 0.0 && d0 < ao_far) {
		vec3 p0 = view_pos(juv, INV_PROJECTION_MATRIX);
		vec2 ruv = ao_radius * 0.5 * vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]) / max(d0, 0.5);
		float rot = 0.39;      // a fixed pattern: a per-pixel turn showed as speckle on flat grass
		float occ = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = rot + float(i) * 0.7853982;
			vec3 v = view_pos(juv + vec2(cos(a), sin(a)) * ruv * ((i & 1) == 0 ? 1.0 : 0.5), INV_PROJECTION_MATRIX) - p0;
			float l = length(v) + 0.0001;
			occ += max(dot(n0, v / l) - 0.15, 0.0) * (1.0 - smoothstep(ao_radius * 0.7, ao_radius * 1.8, l));
		}
		occ = clamp(occ / 8.0 * 2.6, 0.0, 1.0);
		aoa = (smoothstep(0.10, 0.20, occ) * 0.55 + smoothstep(0.34, 0.46, occ) * 0.45) * ao_k * (1.0 - smoothstep(ao_far * 0.5, ao_far, d0));
	}
	float total = line + aoa * (1.0 - line);
	ALBEDO = mix(ao_color, inkc, line / max(total, 0.0001));
	ALPHA = total;
	if (body_dbg > 0.5) { ALBEDO = vec3(body, texture(nr_tex, uv).a, 0.0); ALPHA = 0.8; }
}
