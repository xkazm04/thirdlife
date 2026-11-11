shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
global uniform vec4 g_haze;
global uniform vec4 g_sun;
uniform vec4 albedo : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform float base_a = 0.10;
uniform float fres_a = 0.5;
varying vec3 wpos;
// N5b: the plot of the pack this instance belongs to, relative to the stage pack: xyz = offset (m), w = yaw (rad).
// Set once per GeometryInstance3D by the world's draw layer (kernel/world/draw/draw.gd); all zero = drawn where it is
// simulated (a single pack, or the stage pack), and then the engine's own model-view matrix is left untouched.
instance uniform vec4 tl_plot = vec4(0.0);
mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (any(notEqual(tl_plot, vec4(0.0)))) {   // N5b: draw this pack at its plot (world space; shadow pass included)
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
	}
}
void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float streak = smoothstep(0.92, 0.97, sin((wpos.x + wpos.z * 0.6) * 0.55 + wpos.y * 0.9));
	vec3 c = mix(albedo.rgb, g_haze.rgb * 1.4, fr * 0.7) + g_sun.rgb * streak * 0.35;
	ALBEDO = c;
	ALPHA = clamp(base_a + fr * fres_a + streak * 0.18, 0.0, 0.85);
}
