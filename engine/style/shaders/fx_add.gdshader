shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Billboard particle, additive (sparks, flames, glow). Colour/alpha come from the particle gradient (COLOR).
uniform float soft = 0.55;
uniform vec4 tint : source_color = vec4(1.0);
// N5b: the plot of the pack this instance belongs to, relative to the stage pack: xyz = offset (m), w = yaw (rad).
// Set once per GeometryInstance3D by the world's draw layer (kernel/world/draw/draw.gd); all zero = drawn where it is
// simulated (a single pack, or the stage pack), and then the engine's own model-view matrix is left untouched.
instance uniform vec4 tl_plot = vec4(0.0);
mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}
void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec4 at = MODEL_MATRIX[3];
	if (any(notEqual(tl_plot, vec4(0.0)))) { at = tl_plot_mat() * at; }   // N5b: the billboard stands at its pack's plot
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], at);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(soft, 1.0, d);
	ALBEDO = COLOR.rgb * tint.rgb * a * a * COLOR.a * tint.a;
	ALPHA = 1.0;
}
