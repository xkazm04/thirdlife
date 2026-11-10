shader_type spatial;
render_mode unshaded, cull_disabled;
// River: ribbon UV (x along flow, y across 0..1). Flat colour ramp shallow -> deep, flowing light stripes, sky
// reflection by fresnel. Colours: style.json "water".
global uniform vec4 g_haze;
uniform vec3 deep : source_color = vec3(0.2, 0.4, 0.7);
uniform vec3 shallow : source_color = vec3(0.4, 0.75, 0.8);
uniform vec3 sky : source_color = vec3(1.0, 0.8, 0.6);
uniform vec3 stripe : source_color = vec3(0.85, 0.95, 1.0);
uniform float sky_k = 0.35;   // how much sky colour the water takes on, before fresnel
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1,0)), f.x), mix(h21(i + vec2(0,1)), h21(i + vec2(1,1)), f.x), f.y); }
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	vec3 c = mix(deep, shallow, smoothstep(0.35, 0.95, across));
	float n = vn(vec2(UV.x * 5.0 - TIME * 0.25, UV.y * 9.0));
	if (UV.x < -0.5) {   // still water (a `pond` prop with a water key): slow glints in world space, deep in the middle
		n = vn(vec2(wp.x * 0.16 - TIME * 0.06, wp.z * 0.55 + TIME * 0.03));
		across = smoothstep(0.0, 1.0, across);
	}
	float s = smoothstep(0.62, 0.66, n) * (1.0 - smoothstep(0.7, 0.95, across) * 0.5);
	c = mix(c, stripe, s * 0.55);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	c = mix(c, sky, sky_k + fr * 0.3);
	ALBEDO = c;
}
