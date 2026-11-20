shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

// Transparent pigment under a polished, opaque cast. A fixed meniscus and shallow
// variations in the pour bend the reflected sky as the viewing angle changes.
uniform vec3 deep : source_color;
uniform vec3 shallow : source_color;
uniform vec3 sky : source_color;
uniform vec3 stripe : source_color;
global uniform vec4 g_sun_dir;
uniform float sky_k = 0.66;
varying vec3 wp;
varying vec3 reflected_light;
// N5b: the plot of the pack this instance belongs to, relative to the stage pack: xyz = offset (m), w = yaw (rad).
// Set once per GeometryInstance3D by the world's draw layer (kernel/world/draw/draw.gd); all zero = drawn where it is
// simulated (a single pack, or the stage pack), and then the engine's own model-view matrix is left untouched.
instance uniform vec4 tl_plot = vec4(0.0);
mat4 tl_plot_mat() {
	float cy = cos(tl_plot.w); float sy = sin(tl_plot.w);
	return mat4(vec4(cy, 0.0, -sy, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(sy, 0.0, cy, 0.0), vec4(tl_plot.xyz, 1.0));
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (any(notEqual(tl_plot, vec4(0.0)))) {   // N5b: draw this pack at its plot (world space; shadow pass included)
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
	}
}
#include "res://style/shaders/material_noise.gdshaderinc"

void fragment() {
	vec2 p = wp.xz;
	float edge = UV.y >= 0.0 && UV.y <= 1.0 && fwidth(UV.y) > 0.0 ? abs(2.0 * UV.y - 1.0) : 0.0;
	// The ribbon's U is downstream metres / 10. Short ridges turn with the banks.
	// Ponds and palette-only planes instead use metres on their own XZ plane.
	vec2 flow = UV.x >= 0.0 && fwidth(UV.x) > 0.0 ? vec2(UV.x * 10.0, UV.y * 12.0) : p;
	float sweep = material_noise(p * 0.13).x;
	vec2 warped = vec2(flow.x + 1.9 * sweep + 0.43 * sin(flow.y * 0.81), flow.y);
	vec3 roll = material_noise(warped * vec2(0.52, 0.26));
	vec2 short_uv = warped * vec2(1.25, 0.59) + roll.x * 1.3;
	float keep = 1.0 - smoothstep(0.28, 0.8, max(fwidth(short_uv.x), fwidth(short_uv.y)));
	float wave = material_noise(short_uv).x;
	float h = 0.46 * roll.x + 0.11 * wave * keep;
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 tx = cross(dy, NORMAL), ty = cross(NORMAL, dx);
	float det = dot(dx, tx);
	vec3 slope = (tx * dFdx(h) + ty * dFdy(h)) * sign(det) / max(abs(det), 0.0000001);
	vec3 n = normalize(NORMAL - slope);
	vec3 reflection = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, n);
	float fresnel = pow(1.0 - max(dot(VIEW, n), 0.0), 3.0);
	float bed = 0.10 + 0.33 * sweep + 0.50 * smoothstep(0.31, 0.98, edge);
	vec3 body = mix(deep, shallow, bed) * (0.70 + 0.55 * roll.x);
	// Sky windows and the sun cross the irregular clear coat; the blue bed is
	// visible between them even when the sky above the banks is entirely amber.
	float facing = reflection.y + (roll.x - 0.5) * 0.42;
	float sky_window = smoothstep(0.18, 0.38, facing) * (1.0 - smoothstep(0.47, 0.69, facing));
	float crest = smoothstep(0.44, 0.65, roll.x) * (0.35 + 0.65 * wave * keep);
	float sun_glint = pow(max(dot(reflection, normalize(g_sun_dir.xyz)), 0.0), 48.0);
	float sun_side = smoothstep(-0.63, 0.61, dot(reflection.xz, normalize(g_sun_dir.xz)));
	// Low clouds pick up amber over a wider angle than the solar disc. Only
	// separated facets catch them. This leaves blue water between sky and glints.
	vec2 facet_uv = flow * vec2(0.64, 0.73) + vec2(0.7 * roll.x, 0.85 * sweep);
	float facet = material_noise(facet_uv).x;
	float facet_keep = 1.0 - smoothstep(0.29, 0.94, max(fwidth(facet_uv.x), fwidth(facet_uv.y)));
	float hot_crest = smoothstep(0.60, 0.76, 0.57 * roll.x + 0.43 * facet + keep * (wave - 0.5) * 0.18);
	float amber = hot_crest * facet_keep * (1.0 - smoothstep(0.24, 0.88, abs(reflection.y - 0.12)));
	reflected_light = sky * sky_k * (0.07 + sky_window * (0.35 + fresnel) * (0.30 + crest))
			+ stripe * (2.8 * sun_glint + 0.55 * sky_window * smoothstep(0.36, 0.66, crest))
			+ stripe * vec3(1.48, 0.83, 0.39) * amber * (0.75 + 1.1 * sun_side) * (0.56 + fresnel);
	ALBEDO = body;
	EMISSION = body * 0.67 + reflected_light * 0.14;
	ROUGHNESS = 0.22;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * (0.20 + 0.58 * max(dot(NORMAL, LIGHT), 0.0)) * ATTENUATION / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		SPECULAR_LIGHT += reflected_light * ATTENUATION;
	}
}
