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
#ifdef TL_CEL_GRADE
uniform float plum_density = 0.0;
uniform float edge_contrast = 0.0;
#endif

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

void fragment() {
	vec3 c = textureLod(scr, SCREEN_UV, 0.0).rgb;
#ifdef TL_CEL_GRADE
	if (edge_contrast > 0.0) {
		vec2 uv = SCREEN_UV;
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 lft = textureLod(scr,uv-vec2(px.x,0),0.0).rgb;
		vec3 rgt = textureLod(scr,uv+vec2(px.x,0),0.0).rgb;
		vec3 top = textureLod(scr,uv-vec2(0,px.y),0.0).rgb;
		vec3 bot = textureLod(scr,uv+vec2(0,px.y),0.0).rgb;
		vec3 lo = min(min(lft,rgt),min(top,bot));
		vec3 hi = max(max(lft,rgt),max(top,bot));
		// Tighten the transition inside an existing edge. Bound every
		// channel by the original five texels to avoid a new halo colour.
		vec3 delta = c-.25*(lft+rgt+top+bot);
		c = clamp(c+edge_contrast*delta,min(c,lo),max(c,hi));
	}
#endif
	float l = dot(c, vec3(0.299, 0.587, 0.114));
#ifdef TL_CEL_GRADE
	// Print a plum separation into the darker, low-chroma half tones.
	// Black lines stay black. Saturated cloth carries its own shadow ink.
	float chroma = max(max(c.r,c.g),c.b)-min(min(c.r,c.g),c.b);
	float halftone = smoothstep(.055,.23,l)*(1.0-smoothstep(.44,.63,l));
	float wash = plum_density*halftone*(1.0-smoothstep(.24,.55,chroma));
	c *= mix(vec3(1.0),vec3(.92,.71,1.17),wash);
	l = dot(c,vec3(.299,.587,.114));
#endif
	vec3 tone = mix(shadows, highlights, smoothstep(0.12, 0.85, l));
	c += (tone - vec3(0.5)) * split * (0.35 + 0.65 * (1.0 - abs(l * 2.0 - 1.0)));
	l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c = (c - 0.5) * contrast + 0.5 + lift;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	vec2 q = SCREEN_UV - 0.5;
	q.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	c *= 1.0 - vignette * smoothstep(0.30, 0.95, length(q));
#ifdef TL_CEL_GRADE
	if (paper > 0.0 || grain > 0.0) {
#endif
	vec2 pp = FRAGCOORD.xy * SCREEN_PIXEL_SIZE.y * 1080.0;
	vec2 pi = floor(pp / 46.0); vec2 pf = fract(pp / 46.0); pf = pf * pf * (3.0 - 2.0 * pf);
	float blot = mix(mix(h21(pi), h21(pi + vec2(1, 0)), pf.x), mix(h21(pi + vec2(0, 1)), h21(pi + vec2(1, 1)), pf.x), pf.y);
	float fibre = h21(floor(vec2(pp.x / 2.0, pp.y / 9.0))) * 0.5 + h21(floor(vec2(pp.x / 11.0, pp.y / 2.0))) * 0.5;
	c *= 1.0 + (blot - 0.5) * paper * 1.6 + (fibre - 0.5) * paper;
	float k = 1.0 / (SCREEN_PIXEL_SIZE.y * 1080.0);
	vec2 gp = floor(FRAGCOORD.xy * k / 1.5);
	c += (h21(gp) - 0.5) * grain;
#ifdef TL_CEL_GRADE
	}
#endif
	COLOR = vec4(c, 1.0);
}
