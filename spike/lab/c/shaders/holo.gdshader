shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Holographic blueprint: cyan voxel-grid edges + faint fill + scan pulse. `amount` fades it (site_advance).
uniform vec3 holo_col = vec3(0.22, 0.91, 1.0);
uniform float edge_gain = 2.4;
uniform float fill = 0.10;
uniform float scan = 0.35;
uniform float amount = 1.0;
uniform float vs = 0.1;
uniform float cell_mult = 1.0;
uniform float time_s = 0.0;
varying vec3 v_lpos;
varying flat vec3 v_lnor;
varying vec3 v_wpos;

void vertex() {
	v_lpos = VERTEX;
	v_lnor = NORMAL;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float cs = vs * cell_mult;
	vec3 cellp = (v_lpos - v_lnor * 0.5 * vs) / cs;
	vec3 f = fract(cellp + vec3(0.001));
	vec3 an = abs(v_lnor);
	vec2 inp = an.x > 0.5 ? f.yz : (an.y > 0.5 ? f.xz : f.xy);
	vec2 ed = min(inp, 1.0 - inp);
	float e = min(ed.x, ed.y);
	float fw = max(fwidth(v_lpos.x), max(fwidth(v_lpos.y), fwidth(v_lpos.z))) / cs;
	float line = 1.0 - smoothstep(0.0, 0.06 + fw, e);
	float pulse = 0.65 + 0.35 * sin(v_wpos.x * 0.35 + v_wpos.y * 0.5 - time_s * 2.2);
	float sweep = scan * smoothstep(0.92, 1.0, sin(v_wpos.y * 0.45 - time_s * 1.6) * 0.5 + 0.5);
	float vis = fill + line * edge_gain * pulse + sweep;
	ALBEDO = holo_col * vis * amount;
	ALPHA = clamp(vis * amount, 0.0, 1.0);
}
