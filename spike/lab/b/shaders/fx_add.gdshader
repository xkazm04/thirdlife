shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Billboard particle, additive (sparks, flames, glow). Colour/alpha come from the particle gradient (COLOR).
uniform float soft = 0.55;
uniform vec4 tint : source_color = vec4(1.0);
void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(soft, 1.0, d);
	ALBEDO = COLOR.rgb * tint.rgb * a * a * COLOR.a * tint.a;
	ALPHA = 1.0;
}
