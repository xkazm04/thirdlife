shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
// A lamp's bulb (K6, hockey port): thirdjam's M_ClayBulb, unlit: colour * glow * mix(1 - edge_k, 1, facing * facing).
#include "hall_rig.gdshaderinc"
#include "hall_plot.gdshaderinc"
uniform vec3 bulb_colour = vec3(1.0, 0.55, 0.22);
uniform float glow = 30.0;
uniform float edge_k = 0.55;

void vertex() {
	if (any(notEqual(tl_plot, vec4(0.0)))) {
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
	}
}

void fragment() {
	float f = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	EMISSION = hall_tone(bulb_colour * (glow * mix(1.0 - edge_k, 1.0, f * f)) * rig_exposure);
}
