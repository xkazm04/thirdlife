shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Drawing coordinates in socket metres. All strokes share the same nib: a dark
// enamel keyline, turquoise body, and a warm ivory point. No clock in the shader.
uniform float phase : hint_range(0.0, 1.0);
uniform float spread : hint_range(0.0, 1.0);
uniform vec4 ink : source_color;
uniform vec4 enamel : source_color;
uniform vec4 gold : source_color;
uniform vec4 ivory : source_color;
instance uniform vec4 tl_plot = vec4(0.0);
instance uniform vec4 tl_clip = vec4(0.0);

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	if (tl_clip.x > 0.0 && length(origin.xz) > tl_clip.x) { VERTEX = vec3(0.0); }
	if (any(notEqual(tl_plot, vec4(0.0)))) {
		float c = cos(tl_plot.w), s = sin(tl_plot.w);
		mat4 plot = mat4(vec4(c,0,-s,0), vec4(0,1,0,0), vec4(s,0,c,0), vec4(tl_plot.xyz,1));
		MODELVIEW_MATRIX = VIEW_MATRIX * plot * MODEL_MATRIX;
	}
}

// A concave four-point glint with unequal points (a pen-cut star).
float glint(vec2 p, float size) {
	vec2 q = abs(p) / vec2(0.78, 1.0);
	return max(q.x, q.y) * 0.23 + min(q.x, q.y) - size * 0.23;
}

float plume(float x, float row) {
	return (0.10 + 0.48 * sin(x * 1.55 - 0.32) + 0.12 * x
		- row * (0.18 + 0.18 * sin(x * 2.0))) * mix(0.72, 1.0, spread);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(5.4, -2.8);
	float t = phase;
	float pen = 2.33 * smoothstep(0.09, 0.75, t);
	float tail = 2.65 * smoothstep(0.40, 0.97, t);
	float open = smoothstep(0.0, 0.24, t) * (1.0 - smoothstep(0.40, 0.78, t));
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.7 + 0.001;
	float span = mix(0.43, 1.0, spread);
	float x = abs(p.x) / span;

	// A split seal winds around the central star. Swept gaps leave four
	// independent strokes and disclose the figure through the middle.
	float rad = length(p);
	float a = atan(p.y, p.x + 0.00001);
	float seal = max(abs(rad - 0.49 * open) - 0.025 * open,
		(0.18 - abs(sin(a * 2.0 + t * 4.2))) * 0.22);
	float inner = max(abs(rad - 0.355 * open) - 0.013 * open,
		(0.64 - abs(cos(a * 2.0 - t * 5.0))) * 0.17);
	float line = min(seal, inner);
	float jewel = glint(p, open * 0.305);
	for (int i = 0; i < 4; i++) {
		float angle = float(i) * 1.570796 + 0.38 + t * 0.9;
		vec2 v = vec2(cos(angle), sin(angle));
		vec2 d = p - v * (0.53 * open);
		float lozenge = abs(dot(d,v)) * 0.45 + abs(dot(d,vec2(-v.y,v.x))) - 0.038 * open;
		jewel = min(jewel, lozenge);
	}
	if (open < 0.015) { line = 2.0; jewel = 2.0; }

	// Two quill strokes race from each shoulder. The shorter echo breaks
	// into three dashes; stars ride the writing tips and wink out in place.
	for (int i = 0; i < 2; i++) {
		float row = float(i);
		float end = max(0.0, pen - 0.22 * row);
		float start = max(0.20 + 0.14 * row, tail);
		float w = 0.034 - row * 0.012;
		float ribbon = max(abs(p.y - plume(x, row)) - w, max(start - x, x - end));
		if (i == 1) { ribbon = max(ribbon, (0.15 - fract(x * 1.8)) * 0.26); }
		line = min(line, ribbon);
		float flare = smoothstep(0.08, 0.32, t) * (1.0 - smoothstep(0.72, 0.99, t));
		vec2 tip = vec2(end, plume(end, row));
		if (flare > 0.005) {
			jewel = min(jewel, glint(vec2((x - tip.x) * span,p.y - tip.y), flare * (0.22 - row * 0.11)));
		}
	}
	// Six tiny sparks lift off the nibs in pairs, each on its own beat.
	for (int i = 0; i < 3; i++) {
		float n = float(i);
		float u = clamp((t - (0.23 + 0.11 * n)) / 0.43, 0.0, 1.0);
		float size = sin(u * 3.141593) * (0.105 + 0.024 * n);
		float sx = 0.61 + 0.52 * n + 0.28 * u;
		float sy = plume(sx, 0.0) + (0.15 + 0.41 * u) * (i == 1 ? -1.0 : 1.0);
		if (size > 0.002) { jewel = min(jewel, glint(vec2((x - sx) * span,p.y - sy), size)); }
	}
	float d = min(line, jewel);
	float key = 0.015 * smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.88, 1.0, t));
	float cover = 1.0 - smoothstep(key - aa, key + aa, d);
	if (cover < 0.01) { discard; }
	vec3 fill = mix(enamel.rgb * 1.2, ivory.rgb * 1.7, 1.0 - smoothstep(-0.032,-0.016,line));
	vec3 facet = mix(gold.rgb, ivory.rgb * 2.2, 1.0 - smoothstep(-0.017,-0.001,jewel));
	fill = mix(fill, facet, 1.0 - smoothstep(-aa,aa,jewel));
	ALBEDO = mix(ink.rgb, fill, 1.0 - smoothstep(-aa,aa,d));
	ALPHA = cover;
}
