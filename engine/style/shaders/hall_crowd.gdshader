shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
// A hall's crowd and small clay parts (K6, hockey port): thirdjam's M_ClayCrowd.
//   AR2CrowdBase: colour = pow(vertex colour, 2.2) * tint * a per-instance value chosen by the vertex alpha (the part:
//     1.0 coat -> the instance's coat value; 0.8 hat, 0.6 scarf, 0.4 mittens -> its accent value; skin and the rest 1),
//     muted towards its own grey by `sat`;
//   AR2CrowdFill: a dim fill of its own colour, stronger on faces that look up: colour * fill_colour * fill_k *
//     mix(fill_low, 1, t * t), t = up * 0.5 + 0.5.
// Per-instance data (MultiMesh custom data): x = cheer weight, y = coat, z = accent, w = end * (4 + delay + 2 * pose).
// The cheering pose (CUSTOM0 / CUSTOM1: the offset to pose A / B) rises with `cheer_plus` / `cheer_minus` (thirdjam's
// MPC_Crowd scalars, 0 at rest), held back by wave_k * the instance's delay, times its weight and pose_k:
//   rise = smoothstep(0, 1, clamp(cheer * (1 + wave_k) - delay * wave_k)) * weight * pose_k, offset = pose * rise,
//   plus a hop straight up of bounce_cm * |sin(2 pi (2.2 t + frac(coat * 7.13)))| * rise (the graph's nodes, in order).
#include "hall_rig.gdshaderinc"
#include "hall_plot.gdshaderinc"
uniform vec3 tint = vec3(1.0);
uniform float sat = 0.8;
uniform float fill_k = 1.0;
uniform float fill_low = 0.45;
uniform vec3 fill_colour = vec3(1.0, 0.62, 0.36);
uniform float instanced = 0.0;         // 1 = a fan (reads the per-instance data)
uniform float pose_k = 1.0;
uniform float wave_k = 2.5;
uniform float bounce_cm = 15.0;
uniform float cheer_plus = 0.0;
uniform float cheer_minus = 0.0;
uniform float cheer_time = 0.0;        // seconds of game time (frames / 60), for the bounce
varying vec3 wpos;
varying vec3 wnrm;
varying float value_coat;
varying float value_accent;

void vertex() {
	value_coat = mix(1.0, INSTANCE_CUSTOM.y, instanced);
	value_accent = mix(1.0, INSTANCE_CUSTOM.z, instanced);
	if (instanced > 0.5) {
		float m = abs(INSTANCE_CUSTOM.w) - 4.0;
		float pose = step(2.0, m);
		float delay = m - 2.0 * pose;
		float cheer = INSTANCE_CUSTOM.w > 0.0 ? cheer_plus : cheer_minus;
		float rise = smoothstep(0.0, 1.0, clamp(cheer * (1.0 + wave_k) - delay * wave_k, 0.0, 1.0)) * INSTANCE_CUSTOM.x * pose_k;
		if (rise > 0.0) {
			vec3 off = mix(CUSTOM0.xyz, CUSTOM1.xyz, pose);
			float hop = abs(sin(6.2831853 * (cheer_time * 2.2 + fract(INSTANCE_CUSTOM.y * 7.13)))) * bounce_cm * 0.01;   // Unreal's Sine has period 1
			VERTEX += off * rise + vec3(0.0, hop * rise, 0.0);
		}
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	if (any(notEqual(tl_plot, vec4(0.0)))) {
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
	}
}

void fragment() {
	vec3 n = normalize(wnrm);
	float part = COLOR.a;
	float value = part > 0.9 ? value_coat : (part > 0.3 ? value_accent : 1.0);
	vec3 c = pow(clamp(COLOR.rgb, vec3(0.0), vec3(1.0)), vec3(2.2)) * tint * value;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(l), c, sat);
	float t = clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 em = c * fill_colour * (fill_k * mix(fill_low, 1.0, t * t));
	vec3 lit = c * rig_lux(wpos, n) / PI;
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	EMISSION = hall_tone((lit + em) * rig_exposure);
}
