shader_type spatial;
#ifdef TL_SHORE
render_mode unshaded, cull_disabled, depth_draw_always;
#else
render_mode unshaded, cull_disabled;
#endif
// Diorama night (20 Nov 2026), surfaces: the river of a model railway. Tinted resin poured into a clay bed and cured:
// nothing flows. The ripples were combed into the surface and stand still in the world; what moves is the sky and the
// low sun standing in them as the eye moves. Chosen by style `water.model` = "resin" (TLStyle._fill_special); a style
// without that key keeps water.gdshader. Same ribbon as there: UV.x along the flow, UV.y across 0..1; UV.x < -0.5 = a pond.
// Colours: style "water" (deep, shallow, sky, stripe, sky_k as before; new: sky_top, gloss, ripple, foam, bed).
// Compiled with TL_SHORE defined (style `water.shore` > 0) the resin knows how deep it stands over its bed, from the
// depth of what was drawn before it: the bed shows through the shallows, the bank gets its bright meniscus and the foam
// keeps to the shore. Such a material is drawn after the solid world (a reader of the depth texture always is), so the
// ink pass does not see the surface: with the outline on, a contour that falls on the water is covered by it.
// `water.shore` = 0 keeps the resin solid and takes the bank from the ribbon's own width (UV.y) as water.gdshader does.
#ifdef TL_SHORE
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float shore = 1.0;     // metres of resin over the bed at which the bed is no longer seen
#endif
global uniform vec4 g_haze;
global uniform vec4 g_sun;       // rgb sun colour (linear), a energy
global uniform vec4 g_sun_dir;   // xyz = direction TO the sun (world)
uniform vec3 deep : source_color = vec3(0.2, 0.4, 0.7);
uniform vec3 shallow : source_color = vec3(0.4, 0.75, 0.8);
uniform vec3 sky : source_color = vec3(1.0, 0.8, 0.6);        // what the resin mirrors near the horizon
uniform vec3 sky_top : source_color = vec3(0.45, 0.4, 0.75);  // ... and overhead
uniform vec3 stripe : source_color = vec3(0.85, 0.95, 1.0);   // dry-brushed foam
uniform vec3 bed : source_color = vec3(0.75, 0.6, 0.42);      // the clay bed that shows through at the banks
uniform float sky_k = 0.35;    // how much sky the surface takes on before the angle counts
uniform float gloss = 1.0;     // strength of the mirror and of the sun's glint
uniform float ripple = 1.0;    // height of the combed ripples
uniform float foam = 0.35;     // how much dry-brushed foam
// Diorama day: the cotton clouds stand in the resin too (0 = a plain sky, as last night), and the sun's glint is a soft
// pool instead of sparks (`glint`: 1 = last night's tight spark, 0 = only the soft pool).
uniform vec3 cloud : source_color = vec3(1.0, 0.9, 0.74);
uniform float clouds = 0.0;
uniform float glint = 1.0;
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1,0)), f.x), mix(h21(i + vec2(0,1)), h21(i + vec2(1,1)), f.x), f.y); }
varying vec3 wp;      // where the fragment is drawn (world)
varying vec3 pp;      // where it is in its pack (the ripples are anchored there)
varying float yaw;
instance uniform vec4 tl_plot = vec4(0.0);
mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}
void vertex() {
	pp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp = pp;
	yaw = 0.0;
	if (any(notEqual(tl_plot, vec4(0.0)))) {   // N5b: draw this pack at its plot (world space; shadow pass included)
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
		wp = (pm * vec4(pp, 1.0)).xyz;
		yaw = tl_plot.w;
	}
}
// gradient noise, quintic: value noise has a crease along every cell line and a mirror shows it as a grid
// (corner directions from an integer hash: a float hash of a far cell rounds differently from either side of a cell line)
vec2 gdir(ivec2 c) {
	uvec2 i = uvec2(c);
	uint h = (i.x * 1597334677u) ^ (i.y * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	float a = float((h ^ (h >> 13u)) >> 8u) * (6.2831853 / 16777216.0);
	return vec2(cos(a), sin(a));
}
float gn(vec2 p) {
	vec2 fl = floor(p); ivec2 i = ivec2(fl); vec2 f = p - fl;
	vec2 w = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(dot(gdir(i), f), dot(gdir(i + ivec2(1, 0)), f - vec2(1.0, 0.0)), w.x),
		mix(dot(gdir(i + ivec2(0, 1)), f - vec2(0.0, 1.0)), dot(gdir(i + ivec2(1, 1)), f - vec2(1.0, 1.0)), w.x), w.y);
}
// the combed surface: long ripples lying across the flow, a finer cross set; height in arbitrary units
float surf(vec2 p) {
	return gn(vec2(p.x * 0.33 + p.y * 0.15, p.y * 0.95 - p.x * 0.3)) * 0.75 + gn(vec2(p.x * 1.1 - p.y * 0.6, p.y * 1.9 + p.x * 0.4) + 7.0) * 0.22 + gn(p * 4.1 + 3.0) * 0.05;
}
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	bool pond = UV.x < -0.5;
	if (pond) { across = smoothstep(0.0, 1.0, across); }
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	// tinted resin over a clay bed: deep in the channel, the bed shows through towards the banks
#ifdef TL_SHORE
	vec4 bp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, textureLod(depth_tex, SCREEN_UV, 0.0).r, 1.0);
	float deepness = max(-bp.z / bp.w + VERTEX.z, 0.0) * max(v.y, 0.2);   // metres of resin under this point, roughly
	float bank = 1.0 - smoothstep(0.0, max(shore, 0.05), deepness);        // 1 at the waterline, 0 over the channel
	vec3 c = mix(deep, shallow, smoothstep(0.20, 0.95, bank));
	c = mix(c, bed, smoothstep(0.60, 1.0, bank) * 0.75);
#else
	float bank = smoothstep(0.30, 0.92, across);
	vec3 c = mix(deep, shallow, bank);
	c = mix(c, bed, smoothstep(0.80, 1.0, across) * 0.45);
#endif
	// ripples: three taps of the height field, in the pack's own ground plane
	vec2 q = pp.xz;
	float px = length(fwidth(q));
	float keep_r = 1.0 - smoothstep(0.05, 0.35, px);
	float e = 0.06;
	float h0 = surf(q);
	vec2 g = vec2(surf(q + vec2(e, 0.0)) - h0, surf(q + vec2(0.0, e)) - h0) / e;
	g *= 0.30 * ripple * keep_r;
	float cy = cos(yaw); float sy = sin(yaw);
	g = vec2(cy * g.x + sy * g.y, -sy * g.x + cy * g.y);
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	vec3 r = reflect(-v, n);
	// the mirror: sky by the reflected ray, more of it at a grazing angle
	vec3 skyc = mix(mix(sky, sky_top, smoothstep(0.05, 0.75, r.y)), shallow, 0.2);
	if (clouds > 0.0) {
		// where the mirrored ray meets the cloud layer: soft cream shapes that slide over the resin as the eye moves
		// (the shapes are placed by the flat mirror and only nudged by the ripples: a ripple must not shred a cloud)
		vec3 r0 = reflect(-v, vec3(0.0, 1.0, 0.0));
		vec2 cq = (r0.xz + g * 0.35) / max(r0.y, 0.14) * 0.42 + wp.xz * 0.006;
		float cl = gn(cq) * 0.7 + gn(cq * 2.3 + 5.0) * 0.3;
		skyc = mix(skyc, cloud, smoothstep(0.03, 0.20, cl) * clouds * smoothstep(0.0, 0.12, r.y));
	}
	float fr = 0.03 + 0.97 * pow(1.0 - ndv, 5.0);
	// never more than half a mirror: at a grazing angle (the far reach, the view from the air) a full mirror of a
	// sunset sky turns the river into a pink road; the tint of the resin has to stay in the picture
	float mirror = clamp(sky_k + fr * 0.46 * gloss, 0.0, 0.52);
#ifdef TL_SHORE
	mirror *= 1.0 - 0.7 * smoothstep(0.45, 1.0, bank);   // a film of resin on the clay of the bank shows the clay
#endif
	c = mix(c, skyc, mirror);
	// the sun standing in the ripples: a tight glint in a soft glow
	vec3 sd = normalize(g_sun_dir.xyz);
	float rs = max(dot(r, sd), 0.0);
	vec3 sunc = g_sun.rgb * g_sun.a;
	c += sunc * (pow(rs, 520.0) * 2.4 * glint + pow(rs, 150.0) * 0.45 * (1.0 - glint) + pow(rs, 36.0) * (0.22 - 0.08 * (1.0 - glint))) * gloss;
	// dry-brushed foam: short strokes that lie still, more of them where the water meets the bank
	float fn = vn(vec2(pp.x * 1.3 + pp.z * 0.6, pp.z * 3.4 - pp.x * 0.9));
#ifdef TL_SHORE
	float fo = smoothstep(0.66, 0.72, fn) * smoothstep(0.30, 0.80, bank) * (1.0 - smoothstep(0.90, 1.0, bank));
	c = mix(c, stripe, fo * foam);
	// the meniscus: resin creeps up the bank and catches the light in a thin bright line
	c += skyc * smoothstep(0.965, 0.995, bank) * 0.16 * gloss;
#else
	float fo = smoothstep(0.70, 0.76, fn) * smoothstep(0.50, 0.92, across) * (1.0 - smoothstep(0.97, 1.0, across));
	c = mix(c, stripe, fo * foam);
	// the meniscus: resin creeps up the bank and catches the light in a thin bright line
	c += skyc * smoothstep(0.955, 0.985, across) * (1.0 - smoothstep(0.985, 1.0, across)) * 0.35 * gloss;
#endif
	ALBEDO = c;
}
