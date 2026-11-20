shader_type canvas_item;
// Painterly grade: split-tone, saturation, contrast, vignette, a little print grain. Data: style.json "grade".
uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 shadows : source_color = vec3(0.2, 0.15, 0.4);
uniform vec3 highlights : source_color = vec3(1.0, 0.85, 0.65);
uniform float split = 0.15;
uniform float sat = 1.1;
uniform float contrast = 1.05;
uniform float vignette = 0.25;
uniform float grain = 0.02;
uniform float lift = 0.02;
uniform float gamma = 1.0;
uniform float paper = 0.03;   // gouache-on-paper: blotchy pigment + fibre grain
#ifdef TL_PRINT_CURVE
uniform float print_contrast = 0.0;
uniform sampler2D grade_patch : hint_screen_texture, repeat_disable, filter_linear_mipmap;
#endif

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

void fragment() {
	vec3 c = textureLod(scr, SCREEN_UV, 0.0).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
#ifdef TL_PRINT_CURVE
	float paper_value = dot(textureLod(grade_patch, SCREEN_UV, 2.5).rgb, vec3(0.299, 0.587, 0.114));
	float illumination_offset = clamp(paper_value - l, -0.085, 0.085);
#endif
	vec3 tone = mix(shadows, highlights, smoothstep(0.12, 0.85, l));
	c += (tone - vec3(0.5)) * split * (0.35 + 0.65 * (1.0 - abs(l * 2.0 - 1.0)));
	l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c = (c - 0.5) * contrast + 0.5 + lift;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
#ifdef TL_PRINT_CURVE
	// Separate cast shade from the lit felt, with less gain on the black boots
	// and on the brightest cloud fibres. Scale RGB together to keep the dyes.
	// Let the surrounding patch drive exposure so single bright fibres keep their shape.
	float value = dot(c, vec3(0.299, 0.587, 0.114));
	value += mix(0.68, 1.0, smoothstep(0.34, 0.59, value)) * contrast * illumination_offset;
	float shade = smoothstep(0.07, 0.43, value) * (1.0 - smoothstep(0.31, 0.62, value));
	float lit = smoothstep(0.44, 0.64, value) * (1.0 - smoothstep(0.70, 0.94, value));
	c *= 1.0 + print_contrast * (0.39 * lit - shade);
#endif
	vec2 q = SCREEN_UV - 0.5;
	q.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	c *= 1.0 - vignette * smoothstep(0.30, 0.95, length(q));
	vec2 pp = FRAGCOORD.xy * SCREEN_PIXEL_SIZE.y * 1080.0;
	vec2 pi = floor(pp / 46.0); vec2 pf = fract(pp / 46.0); pf = pf * pf * (3.0 - 2.0 * pf);
	float blot = mix(mix(h21(pi), h21(pi + vec2(1, 0)), pf.x), mix(h21(pi + vec2(0, 1)), h21(pi + vec2(1, 1)), pf.x), pf.y);
	float fibre = h21(floor(vec2(pp.x / 2.0, pp.y / 9.0))) * 0.5 + h21(floor(vec2(pp.x / 11.0, pp.y / 2.0))) * 0.5;
	c *= 1.0 + (blot - 0.5) * paper * 1.6 + (fibre - 0.5) * paper;
	float k = 1.0 / (SCREEN_PIXEL_SIZE.y * 1080.0);
	vec2 gp = floor(FRAGCOORD.xy * k / 1.5);
	c += (h21(gp) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
