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
uniform float sun_draw_elev = 0.0;   // N1: degrees above the horizon at which the sun is PAINTED (0 = where the light is).
                                     // The light stands higher than a sunset sun so that venues are lit, not shadowed.

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1 + 3.7) * 0.3 + vn(p * 4.3 + 8.1) * 0.15; }

// P3: clouds are drawn puffs, not streaks. Each unit cell of the cloud plane holds up to two round puffs (a squashed circle
// with a flat-ish base); the field f is > 0 inside the union. Shading is three flat tones from the field's slope towards the
// sun (lit rim / body / shade underside) and a thin dark line along the shade-side contour, like the concept's clouds.
uniform float cloud_puff = 1.0;      // puff size multiplier
uniform float cloud_line = 0.5;      // strength of the drawn contour on the shade side (0 = none)
uniform vec3 cloud_ink : source_color = vec3(0.36, 0.2, 0.45);

float puffs(vec2 p) {
	vec2 c0 = floor(p);
	float f = -1.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = c0 + vec2(float(i), float(j));
			float r1 = h21(c + 3.7);
			float r2 = h21(c + 11.3);
			float r3 = h21(c + 23.9);
			float on = step(1.0 - cloud_cover * 0.9, r1);           // this cell holds a cloud
			vec2 ctr = c + vec2(0.3 + 0.4 * r2, 0.3 + 0.35 * r3);
			float R = (0.17 + 0.12 * h21(c + 5.1)) * cloud_puff;
			// a clump: the heart, two flanks, two bumps on top
			float g = 1.0 - length(p - ctr) / R;
			g = max(g, 1.0 - length(p - ctr - vec2(-0.62 * R, -0.08 * R)) / (R * 0.72));
			g = max(g, 1.0 - length(p - ctr - vec2(0.66 * R, -0.04 * R)) / (R * 0.66));
			g = max(g, 1.0 - length(p - ctr - vec2(-0.22 * R, 0.5 * R)) / (R * 0.62));
			g = max(g, 1.0 - length(p - ctr - vec2((r2 - 0.3) * 0.9 * R, 0.42 * R)) / (R * 0.55 * (0.6 + r3)));
			// flat base: the clump is cut off a little under its heart
			g = min(g, (p.y - (ctr.y - 0.5 * R)) * 7.0);
			f = max(f, on * g);
		}
	}
	return f;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	float t = max(h, 0.0);
	vec3 col = mix(horizon, mid, smoothstep(0.0, 0.2, t));
	col = mix(col, upper, smoothstep(0.10, 0.42, t));
	col = mix(col, zenith, smoothstep(0.36, 0.85, t));
	col = mix(col, ground, smoothstep(0.0, -0.25, h));
	vec3 L = LIGHT0_DIRECTION;
	if (sun_draw_elev > 0.0 && length(L.xz) > 0.001) {
		vec2 hz = normalize(L.xz);
		float el = radians(sun_draw_elev);
		L = vec3(hz.x * cos(el), sin(el), hz.y * cos(el));
	}
	float sd = clamp(dot(d, L), -1.0, 1.0);
	float g1 = pow(max(sd, 0.0), 6.0) * 0.28 + pow(max(sd, 0.0), 40.0) * 0.55;
	col = mix(col, glow, clamp(g1 * glow_k, 0.0, 1.0));
	// clouds: drawn clumps painted on the dome (azimuth, elevation), so they stand upright with bumpy tops and flat bases
	// at any distance; three flat tones from the field's slope towards the sun, and a contour on the shade side
	if (h > 0.012) {
		float az = atan(d.z, d.x);
		float azs = atan(L.z, L.x);
		vec2 uv = vec2(az * 2.1 * cloud_scale, asin(clamp(h, 0.0, 1.0)) * 2.4 * cloud_scale - cloud_high * 4.0);
		uv.x += TIME * 0.01;
		float sx = sign(sin(azs - az));
		vec2 tw = vec2(sx * 0.07, 0.085);
		float f0 = puffs(uv);
		float f1 = puffs(uv + tw);
		float inside = smoothstep(0.0, 0.03, f0);
		float slope = f1 - f0;                       // < 0: stepping towards the light leaves the cloud: a lit rim
		float lit = 1.0 - smoothstep(-0.12, -0.03, slope);
		float shade = smoothstep(0.03, 0.12, slope);
		float low = smoothstep(0.0, 0.45, f0);       // the heart of a puff keeps the body tone
		vec3 body = mix(cloud, cloud_shade, 0.12);
		vec3 cc = mix(body, cloud * 1.06 + glow * 0.10, lit * (1.0 - low * 0.5));
		cc = mix(cc, cloud_shade, shade * (1.0 - low * 0.35) * 0.95);
		cc = mix(cc, glow, pow(max(sd, 0.0), 3.0) * 0.4);
		float edge = (1.0 - smoothstep(0.03, 0.075, f0)) * inside * (1.0 - lit);
		cc = mix(cc, cloud_ink, edge * cloud_line);
		float fade = smoothstep(0.012, 0.09, h) * (1.0 - smoothstep(0.75, 1.0, h) * 0.7);
		col = mix(col, cc, inside * fade);
	}
	float ang = acos(sd);
	float dk = 1.0 - smoothstep(disc_r - disc_soft, disc_r + disc_soft, ang);
	col = mix(col, disc * 1.6, dk * step(0.0001, disc_r));
	COLOR = col;
}
