shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
// Billboard particle, alpha blended (dust, smoke). Flat disc with a soft edge.
uniform float soft = 0.7;
void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(soft, 1.0, d);
	a *= a;
	ALBEDO = COLOR.rgb;
	ALPHA = a * COLOR.a;
}
