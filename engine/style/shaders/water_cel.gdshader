shader_type spatial;
#ifdef TL_SHORE
render_mode unshaded, cull_disabled, depth_draw_always;
#else
render_mode unshaded, cull_disabled;
#endif
// Crisp cel (day of 20 Nov 2026), surfaces: the river as a cel painter draws it. Flat blue in two tones (the channel,
// the shallows), cut with a wobbly edge; light streaks that lie along the flow and drift with it; a few large flat
// shapes where the sky stands in the water; one foam line where the water meets the land.
// Chosen by style `water.model` = "cel" (TLStyle, dio/style_dio.gd `water`); a style without that key keeps
// water.gdshader. The same ribbon as there: UV.x along the flow (10 m per unit), UV.y across 0..1; UV.x < -0.5 = a pond.
// Colours: style "water": deep, shallow, sky, stripe (as before); new: foam, streak (0..1 how many), flow (m/s),
// shore (m of water over the bed at which the shallows end; > 0 compiles TL_SHORE).
// With TL_SHORE the water knows how deep it stands over its bed, from the depth of what was drawn before it: the
// waterline is where the land really meets it (and round every rock and pier that stands in it), not where the ribbon
// ends. Such a material is drawn after the solid world; TLStyle gives it a render priority below the ink pass, so the
// drawn contours of whatever stands before the water are laid over it, not covered by it.
#ifdef TL_SHORE
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float shore = 0.6;
#endif
global uniform vec4 g_haze;
uniform vec3 deep : source_color = vec3(0.2, 0.4, 0.7);
uniform vec3 shallow : source_color = vec3(0.4, 0.75, 0.8);
uniform vec3 sky : source_color = vec3(1.0, 0.8, 0.6);
uniform vec3 stripe : source_color = vec3(0.85, 0.95, 1.0);
uniform vec3 foam : source_color = vec3(1.0, 1.0, 1.0);
uniform float sky_k = 0.35;    // how strong the flat shapes of sky are
uniform float streak = 0.5;    // how many light streaks (0 none .. 1 every cell)
uniform float flow = 0.35;     // metres a second the streaks drift along the ribbon
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1,0)), f.x), mix(h21(i + vec2(0,1)), h21(i + vec2(1,1)), f.x), f.y); }
varying vec3 wp;      // where the fragment is drawn (world)
varying vec3 pp;      // where it is in its pack
instance uniform vec4 tl_plot = vec4(0.0);
mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}
void vertex() {
	pp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp = pp;
	if (any(notEqual(tl_plot, vec4(0.0)))) {   // N5b: draw this pack at its plot (world space; shadow pass included)
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
		wp = (pm * vec4(pp, 1.0)).xyz;
	}
}
// One layer of drawn streaks in the plane p (x = metres along the flow, y = metres across): a lens in some cells.
// `cell` = the size of a cell (m), `aa` = the size of a pixel in p. Returns 0..1.
float streaks(vec2 p, vec2 cell, float amount, vec2 aa, float seed) {
	vec2 q = p / cell;
	vec2 c = floor(q);
	float on = step(h21(c + seed), amount);
	vec2 j = vec2(h21(c + seed + 3.1), h21(c + seed + 7.7));
	vec2 d = (q - c - vec2(0.5, 0.25 + 0.5 * j.y)) * cell;
	float half_l = cell.x * (0.22 + 0.24 * j.x);
	float half_w = cell.y * (0.07 + 0.07 * h21(c + seed + 5.3));
	float t = clamp(abs(d.x) / half_l, 0.0, 1.0);
	float w = half_w * (1.0 - t * t);
	float s = 1.0 - smoothstep(w - aa.y * 0.6, w + aa.y * 0.6, abs(d.y));
	// a streak thinner than a pixel is not drawn: far off the river is its flat colour, and nothing shimmers
	return s * on * step(abs(d.x), half_l) * (1.0 - smoothstep(0.5, 1.4, aa.y / half_w));
}
void fragment() {
	bool pond = UV.x < -0.5;
	float across = abs(UV.y * 2.0 - 1.0);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	vec2 q = pp.xz;
	float px = max(length(dFdx(q)), length(dFdy(q)));
	float wob = (vn(q * 0.45) - 0.5) * 0.5 + (vn(q * 1.7 + 4.0) - 0.5) * 0.2 * (1.0 - smoothstep(0.15, 0.5, px));
#ifdef TL_SHORE
	vec4 bp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, textureLod(depth_tex, SCREEN_UV, 0.0).r, 1.0);
	float deepness = max(-bp.z / bp.w + VERTEX.z, 0.0) * max(v.y, 0.2);   // metres of water under this point, roughly
	float dz = deepness / max(shore, 0.05) + wob * 0.35;                    // 0 at the waterline, 1 where the shallows end
	float dfw = fwidth(dz) * 0.75 + 0.002;
	float shal = 1.0 - smoothstep(1.0 - dfw, 1.0 + dfw, dz);
	float line_w = 0.16;
	float edge = 1.0 - smoothstep(line_w - dfw, line_w + dfw, deepness / max(shore, 0.05));
#else
	if (pond) { across = smoothstep(0.0, 1.0, across); }
	float dz = (0.95 - across) / 0.35 + wob * 0.35;
	float dfw = fwidth(dz) * 0.75 + 0.002;
	float shal = 1.0 - smoothstep(1.0 - dfw, 1.0 + dfw, dz);
	float edge = 0.0;
#endif
	vec3 c = mix(deep, shallow, shal);
	// where the sky stands in the water: a few large flat shapes, drifting slowly
	float sn = vn(q * 0.07 + vec2(TIME * 0.010, 3.0)) * 0.65 + vn(q * 0.21 + vec2(7.0, -TIME * 0.016)) * 0.35;
	float sfw = fwidth(sn) * 0.75 + 0.002;
	float grazing = 1.0 - clamp(v.y, 0.0, 1.0);
	c = mix(c, sky, smoothstep(0.66 - sfw, 0.66 + sfw, sn) * sky_k * (0.35 + 0.65 * grazing) * (1.0 - shal * 0.6));
	// light streaks along the flow, two layers at two speeds; a pond has short still ones in the world's plane
	vec2 p = pond ? vec2(q.x + q.y * 0.3, q.y) : vec2(UV.x * 10.0, (UV.y - 0.5) * 30.0);
	vec2 aa = pond ? vec2(px) : vec2(length(vec2(dFdx(p.x), dFdy(p.x))), length(vec2(dFdx(p.y), dFdy(p.y))));
	float drift = pond ? 0.0 : TIME * flow;
	float st = streaks(p - vec2(drift, 0.0), vec2(9.0, 1.7), streak, aa, 0.0);
	st = max(st, streaks(p - vec2(drift * 0.6, 0.4), vec2(14.0, 2.6), streak * 0.7, aa, 21.0));
	c = mix(c, stripe, st * 0.8 * (1.0 - shal * 0.5));
	// the foam line at the waterline
	c = mix(c, foam, edge);
	ALBEDO = c;
}
