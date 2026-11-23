// The plot of the pack an instance belongs to, for the hall shaders (K6). Kept apart from hall_rig.gdshaderinc so that a
// shader with a plot rule of its own (a figure) can include the rig alone.
// N5b: the plot of the pack this instance belongs to (kernel/world/draw): all zero = drawn where it is simulated.
instance uniform vec4 tl_plot = vec4(0.0);
mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}
