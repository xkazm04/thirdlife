shader_type canvas_item;
// Diorama grade (night of 20 Nov), chosen by the style key `grade.shader` = "grade_diorama"; grade.gdshader is untouched.
// A photograph of a small model under a warm lamp, not a print on paper:
//   - `shadow_tint` / `light_tint`: the dark end is pulled to a warm plum and the light end to gold (a colour balance by
//     luminance, so the blue toon shade reads as a warm shadow without touching any material)
//   - `green_keep`: the warm sun turns the road orange, as on the board, but it also turns grass mustard; this keeps
//     the greens green (a hue-selective correction, the colourist's "protect the foliage")
//   - a soft shoulder and toe (`contrast`), vibrance (`sat`: muted colours gain more than saturated ones, so the jacket
//     does not clip), a round vignette
//   - `tilt`: the miniature band of a presentation camera (a crane, a review scene): the picture is sharp in a level
//     band round `tilt_y` and blurs towards the top and the bottom edge. It is set per frame by the lens node
//     (frame/tl_style_frame.gd) and is 0 for every camera of a game: a game view is never blurred here.
//   - no paper, no fibre, no print grain: `grain` is a fine photographic grain and defaults to none.
uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 shadow_tint : source_color = vec3(0.36, 0.20, 0.26);
uniform vec3 light_tint : source_color = vec3(1.0, 0.90, 0.72);
uniform float tint = 0.12;        // how far the ends are pulled
uniform float sat = 1.1;
uniform float contrast = 1.06;
uniform float vignette = 0.2;
uniform float grain = 0.0;
uniform float lift = 0.0;
uniform float gamma = 1.0;
uniform float green_keep = 0.0;   // 0..0.5: yellow-green (grass and leaves under the warm sun) is turned back towards green
uniform float tilt = 0.0;         // px of blur (at 1080) at the top and bottom edge; 0 = off
uniform float tilt_y = 0.52;      // the sharp band's centre, 0 = top
uniform float tilt_band = 0.16;   // half height of the sharp band
uniform float tilt_soft = 0.34;   // the blur grows over this much height beyond the band

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

vec3 blurred(vec2 uv, float r_px, vec2 px) {
	// 12 taps on two rings, each from a mip a little under the ring's spacing: smooth to about 14 px
	float lod = clamp(log2(max(r_px, 1.0)) - 1.0, 0.0, 4.0);
	vec3 acc = textureLod(scr, uv, lod).rgb * 2.0;
	float wsum = 2.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 2.39996 + 0.7;
		float rr = sqrt((float(i) + 0.5) / 12.0) * r_px;
		acc += textureLod(scr, uv + vec2(cos(a), sin(a)) * rr * px, lod).rgb;
		wsum += 1.0;
	}
	return acc / wsum;
}

void fragment() {
	vec3 c;
	float kpx = 1.0 / (SCREEN_PIXEL_SIZE.y * 1080.0);
	if (tilt > 0.01) {
		float off = abs(SCREEN_UV.y - tilt_y);
		float r = tilt * kpx * smoothstep(tilt_band, tilt_band + tilt_soft, off);
		c = r > 0.35 ? blurred(SCREEN_UV, r, SCREEN_PIXEL_SIZE) : textureLod(scr, SCREEN_UV, 0.0).rgb;
	} else {
		c = textureLod(scr, SCREEN_UV, 0.0).rgb;
	}
	if (green_keep > 0.0) {
		// Grass and leaves lit by an orange sun go mustard: red rises to meet green. Where green leads red (or nearly
		// does) and blue is well under both, red is taken down, so the hue returns to green and the tone gets deeper.
		// The road (red far above green), timber, the yellow sign, skin, clouds and the sky are outside that range.
		float lead = smoothstep(0.72, 1.12, c.g / max(c.r, 0.001));
		float chroma = smoothstep(0.20, 0.60, (c.g - c.b) / max(c.g, 0.001));
		c.r *= 1.0 - green_keep * lead * chroma;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// colour balance: multiply towards the tint at each end, keep the luminance
	vec3 bal = mix(shadow_tint / max(dot(shadow_tint, vec3(0.299, 0.587, 0.114)), 0.001),
		light_tint / max(dot(light_tint, vec3(0.299, 0.587, 0.114)), 0.001), smoothstep(0.10, 0.80, l));
	c = mix(c, c * bal, tint * (1.0 - 0.6 * smoothstep(0.75, 1.0, l)));
	l = dot(c, vec3(0.299, 0.587, 0.114));
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float vib = 1.0 + (sat - 1.0) * (1.0 - smoothstep(0.35, 0.85, mx - mn));
	c = mix(vec3(l), c, vib);
	// a soft S: the middle is steeper, both ends roll off
	vec3 s = c * c * (3.0 - 2.0 * c);
	c = mix(c, s, clamp((contrast - 1.0) * 4.0, -1.0, 1.0)) + lift;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	vec2 q = SCREEN_UV - 0.5;
	q.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	c *= 1.0 - vignette * smoothstep(0.32, 1.0, length(q));
	if (grain > 0.0) {
		c += (h21(floor(FRAGCOORD.xy * kpx)) - 0.5) * grain;
	}
	COLOR = vec4(c, 1.0);
}
