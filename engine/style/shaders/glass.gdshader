shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
global uniform vec4 g_haze;
global uniform vec4 g_sun;
uniform vec4 albedo : source_color = vec4(0.7, 0.9, 1.0, 1.0);
uniform float base_a = 0.10;
uniform float fres_a = 0.5;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float streak = smoothstep(0.92, 0.97, sin((wpos.x + wpos.z * 0.6) * 0.55 + wpos.y * 0.9));
	vec3 c = mix(albedo.rgb, g_haze.rgb * 1.4, fr * 0.7) + g_sun.rgb * streak * 0.35;
	ALBEDO = c;
	ALPHA = clamp(base_a + fr * fres_a + streak * 0.18, 0.0, 0.85);
}
