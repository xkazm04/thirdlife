shader_type sky;
// Painterly gradient sky: banded gradient, sun glow + disc, flat-lit cloud streaks. All colours are data (style.json "sky").
uniform vec3 zenith : source_color = vec3(0.1, 0.1, 0.4);
uniform vec3 upper : source_color = vec3(0.3, 0.2, 0.6);
uniform vec3 mid : source_color = vec3(0.8, 0.4, 0.6);
uniform vec3 horizon : source_color = vec3(1.0, 0.7, 0.5);
uniform vec3 ground : source_color = vec3(0.9, 0.6, 0.5);
uniform vec3 glow : source_color = vec3(1.0, 0.8, 0.5);
uniform vec3 disc : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 cloud : source_color = vec3(1.0, 0.6, 0.5);
uniform vec3 cloud_shade : source_color = vec3(0.7, 0.3, 0.6);
uniform float glow_k = 0.8;
uniform float disc_r = 0.03;
uniform float disc_soft = 0.004;
uniform float cloud_cover = 0.5;
uniform float cloud_scale = 2.0;
uniform float cloud_high = 0.25;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1 + 3.7) * 0.3 + vn(p * 4.3 + 8.1) * 0.15; }

float cmask(vec2 uv) {
	vec2 wv = vec2(fbm(uv * 1.9 + 3.1), fbm(uv * 1.9 + 11.7)) - 0.5;
	float n = fbm(uv + wv * 0.9) * 0.75 + vn(uv * 6.0 + wv * 3.0) * 0.25;
	return smoothstep(1.0 - cloud_cover - 0.04, 1.0 - cloud_cover + 0.04, n);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	float t = max(h, 0.0);
	vec3 col = mix(horizon, mid, smoothstep(0.0, 0.16, t));
	col = mix(col, upper, smoothstep(0.10, 0.42, t));
	col = mix(col, zenith, smoothstep(0.38, 0.95, t));
	col = mix(col, ground, smoothstep(0.0, -0.25, h));
	vec3 L = LIGHT0_DIRECTION;
	float sd = clamp(dot(d, L), -1.0, 1.0);
	float g1 = pow(max(sd, 0.0), 6.0) * 0.45 + pow(max(sd, 0.0), 40.0) * 0.55;
	col = mix(col, glow, clamp(g1 * glow_k, 0.0, 1.0));
	// clouds: streaks stretched along the horizon, painted as flat shapes with a sun-facing lit edge
	if (h > 0.01) {
		vec2 uv = d.xz / (h + cloud_high) * cloud_scale;
		uv.x *= 0.62;
		uv += vec2(TIME * 0.004, 0.0);
		float m = cmask(uv);
		vec2 toward = normalize(L.xz + vec2(0.0001)) * 0.07;
		float m2 = cmask(uv + vec2(toward.x * 0.62, toward.y) * 1.6);
		float m3 = cmask(uv + vec2(0.0, -0.10));
		vec3 cc = mix(cloud_shade, cloud * 1.15, clamp(1.0 - m2 * 0.9, 0.0, 1.0));
		cc = mix(cc, cloud_shade * 0.85, m3 * (1.0 - m2) * 0.0 + (1.0 - m3) * m2 * 0.35);
		cc = mix(cc, glow, pow(max(sd, 0.0), 3.0) * 0.5);
		float fade = smoothstep(0.01, 0.10, h) * (1.0 - smoothstep(0.75, 1.0, h) * 0.6);
		col = mix(col, cc, m * fade * 0.92);
	}
	float ang = acos(sd);
	float dk = 1.0 - smoothstep(disc_r - disc_soft, disc_r + disc_soft, ang);
	col = mix(col, disc * 1.6, dk * step(0.0001, disc_r));
	COLOR = col;
}
