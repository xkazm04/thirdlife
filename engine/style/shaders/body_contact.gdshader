shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;
// The contact shade under a figure (K7, hockey port): thirdjam's M_SkaterContact, an unlit plane that multiplies what
// lies under it (BLEND_Modulate): 1 at its rim, `darkest` at its middle.
//   d = (UV - 0.5) * 2;  x = saturate((1 - |d|) / max(1 - flat, 0.05));  a = x * x * (3 - 2 * x);  colour = lerp(1, darkest, a)
// (Game/Plugins/JamAssets/Content/Skaters/M_SkaterContact.uasset, exported as text). `flat_k` widens the dark middle.
#include "res://style/shaders/body_cel_plot.gdshaderinc"
uniform float darkest = 0.45;      // Darkest
uniform float flat_k = 0.0;        // Flat

void vertex() {
	mat4 plot = figure_plot(MODEL_MATRIX[3].xyz, VERTEX);
	MODELVIEW_MATRIX = VIEW_MATRIX * plot * MODEL_MATRIX;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(plot) * MODEL_NORMAL_MATRIX;
}

void fragment() {
	vec2 d = (UV - vec2(0.5)) * 2.0;
	float x = clamp((1.0 - length(d)) / max(1.0 - flat_k, 0.05), 0.0, 1.0);
	float a = x * x * (3.0 - 2.0 * x);
	ALBEDO = vec3(mix(1.0, darkest, a));
}
