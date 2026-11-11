shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Holographic blueprint: faint fresnel-weighted fill, emissive edge lines (profile edges + cross bars read from the
// mesh UV: x = 0..1 along the part, y = 0..1 around its section), scanline pulse. `build` (instance uniform) is the
// hologram -> built dissolve front: the same value drives toon.gdshader (dissolve=1), so one number converts a rib.
uniform vec3 holo : source_color = vec3(0.2, 0.9, 1.0);
uniform vec3 edge : source_color = vec3(0.8, 1.0, 1.0);
uniform float alpha = 0.1;
uniform float edge_k = 1.6;
uniform float scan = 0.3;
uniform float grid_u = 30.0;
uniform float segs_v = 4.0;
uniform float dissolve = 1.0;
instance uniform float build = 0.0;
varying vec3 wpos;
varying vec2 uvv;
float hash31(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x), mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x), mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}
// N5b: the plot of the pack this instance belongs to, relative to the stage pack: xyz = offset (m), w = yaw (rad).
// Set once per GeometryInstance3D by the world's draw layer (kernel/world/draw/draw.gd); all zero = drawn where it is
// simulated (a single pack, or the stage pack), and then the engine's own model-view matrix is left untouched.
instance uniform vec4 tl_plot = vec4(0.0);
mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; uvv = UV;
	if (any(notEqual(tl_plot, vec4(0.0)))) {   // N5b: draw this pack at its plot (world space; shadow pass included)
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
	}
}
float edge_line(float x, float n) { float f = abs(fract(x * n + 0.5) - 0.5); float aa = fwidth(x * n) * 1.4 + 0.002; return 1.0 - smoothstep(0.04, 0.04 + aa, f); }
void fragment() {
	float fr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float front = 0.0;
	if (dissolve > 0.5) {
		float h = 1.0 - abs(uvv.x * 2.0 - 1.0);
		float bn = vnoise(wpos * 1.1) * 0.14;
		float thr = build * 1.3 - 0.06;
		float d = h + bn - thr;
		if (d < 0.0) { discard; }
		front = 1.0 - smoothstep(0.0, 0.07, d);
	}
	float lv = edge_line(uvv.y, segs_v);
	float lu = edge_line(uvv.x, grid_u) * 0.55;
	float lines = max(lv, lu);
	if (uvv.y > 1.5) { lines = 0.14; }
	float sc = 0.5 + 0.5 * sin(wpos.y * 2.2 - TIME * 1.8);
	vec3 c = holo * (alpha * (0.5 + fr)) + edge * lines * edge_k * (1.0 + scan * sc) + edge * front * 1.2;
	ALBEDO = c;
	ALPHA = 1.0;
}
