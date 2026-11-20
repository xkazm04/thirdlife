shader_type sky;
// Diorama backdrop (night of 20 Nov): a painted sunset board behind the table, and cotton puffs hung in front of it.
// Chosen by the style key `sky.shader` = "sky_diorama"; sky.gdshader (the classic sky) is untouched.
//   - the board: the same banded gradient keys as the classic sky, a wide warm wash on the sun's side, and short
//     horizontal brush strokes. The strokes are noise of the view DIRECTION (3D), so they are fixed to the backdrop,
//     never crawl, and have no seam.
//   - the puffs: each cloud is a clump of round balls with a flattened base. A ball is a height field (a hemisphere),
//     so every pixel of a cloud has a normal: it is lit by the sun as seen from that part of the sky, warmed from below
//     by the horizon, and darkened in the seams between balls. The edge is frayed by fine noise: cotton, not a decal.
//   - no seam: the clouds live in (azimuth, elevation) cells with a WHOLE number of columns round the horizon, and a
//     cloud's place is hashed from its column modulo that number. (The classic sky has 25.07 columns: the cut at az = pi.)
//   - nothing moves unless `cloud_drift` > 0 (columns per second): a backdrop is painted once.
uniform vec3 zenith : source_color = vec3(0.1, 0.1, 0.4);
uniform vec3 upper : source_color = vec3(0.3, 0.2, 0.6);
uniform vec3 mid : source_color = vec3(0.8, 0.4, 0.6);
uniform vec3 horizon : source_color = vec3(1.0, 0.7, 0.5);
uniform vec3 ground : source_color = vec3(0.9, 0.6, 0.5);
uniform vec3 glow : source_color = vec3(1.0, 0.8, 0.5);
uniform vec3 disc : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 cloud : source_color = vec3(1.0, 0.95, 0.86);
uniform vec3 cloud_shade : source_color = vec3(0.86, 0.6, 0.62);
uniform vec3 cloud_under : source_color = vec3(1.0, 0.66, 0.42);   // the horizon's light on the undersides
uniform float glow_k = 0.8;
uniform float glow_wide = 0.5;       // the warm wash over the whole sun side of the board (0 = only the classic glow)
uniform float disc_r = 0.03;
uniform float disc_soft = 0.004;
uniform float cloud_cover = 0.5;     // share of cells that hold a cloud
uniform float cloud_scale = 2.0;     // 12 columns round the horizon and rows 15 degrees high, divided by this
uniform float cloud_high = 0.25;     // radians: the lowest row starts here
uniform float cloud_rows = 3.0;      // rows of cells above that: the puffs hang in a band over the horizon, not up the dome
uniform float cloud_puff = 1.0;      // puff size multiplier
uniform float cloud_fluff = 0.6;     // 0 = clay balls with a clean edge, 1 = frayed cotton
uniform float cloud_under_k = 0.55;
uniform float cloud_drift = 0.0;
uniform float brush = 0.05;          // strength of the painted strokes on the board
uniform float sun_draw_elev = 0.0;   // degrees above the horizon at which the sun is PAINTED (0 = where the light is)

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float h31(vec3 p) { p = fract(p * vec3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
float vn3(vec3 p) { vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z); }


// One ball of a clump at `c` (radians, in the cloud's own flat frame), radius r. Keeps the two highest fields.
void ball(vec2 q, vec2 c, float r, inout vec4 best, inout float second) {
	vec2 o = q - c;
	if (o.y < 0.0) { o.y *= 1.75; }                    // a flattened base
	float z2 = r * r - dot(o, o);
	if (z2 <= 0.0) { return; }
	float z = sqrt(z2);
	if (z > best.z) { second = best.z; best = vec4(o, z, r); }
	else if (z > second) { second = z; }
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	float t = max(h, 0.0);
	vec3 L = LIGHT0_DIRECTION;
	if (sun_draw_elev > 0.0 && length(L.xz) > 0.001) {
		vec2 hz = normalize(L.xz);
		float el = radians(sun_draw_elev);
		L = vec3(hz.x * cos(el), sin(el), hz.y * cos(el));
	}
	float sd = clamp(dot(d, L), -1.0, 1.0);
	// the board: the banded gradient, then the sun side washed warm (wide), then the glow round the sun
	vec3 col = mix(horizon, mid, smoothstep(0.0, 0.2, t));
	col = mix(col, upper, smoothstep(0.10, 0.42, t));
	col = mix(col, zenith, smoothstep(0.36, 0.85, t));
	float side = 0.5 + 0.5 * dot(normalize(d.xz + vec2(0.0001)), normalize(L.xz + vec2(0.0001)));
	float wash = side * side * (1.0 - smoothstep(0.05, 0.62, t)) * glow_wide;
	col = mix(col, mix(horizon, glow, 0.3), clamp(wash, 0.0, 1.0));
	float g1 = pow(max(sd, 0.0), 6.0) * 0.28 + pow(max(sd, 0.0), 40.0) * 0.55;
	col = mix(col, glow, clamp(g1 * glow_k, 0.0, 1.0));
	col = mix(col, ground, smoothstep(0.0, -0.25, h));
	// brush strokes: long in the horizontal, short in the vertical, two sizes; value only, a little warmer where lighter
	if (brush > 0.0) {
		float s1 = vn3(d * vec3(9.0, 46.0, 9.0) + 3.1);
		float s2 = vn3(d * vec3(23.0, 120.0, 23.0) + vec3(s1 * 2.0, 0.0, 7.7));
		float s3 = vn3(d * vec3(5.0, 11.0, 5.0) + 11.0);
		float st = (s1 - 0.5) * 0.9 + (s2 - 0.5) * 0.7 + (s3 - 0.5) * 0.6;
		col *= 1.0 + st * brush * vec3(1.15, 1.0, 0.85);
	}
	// cotton puffs
	if (h > 0.02) {
		float cols = max(3.0, floor(12.0 * cloud_scale + 0.5));
		float cw = TAU / cols;                       // a column, radians of azimuth
		float rh = radians(15.0) / max(cloud_scale, 0.2);
		float az = atan(d.z, d.x) + cloud_drift * TIME * cw;
		float el = asin(clamp(h, 0.0, 1.0));
		float u = az / cw;
		float v = (el - cloud_high) / rh;
		vec2 c0 = floor(vec2(u, v));
		// fine noise that frays the edge: of the view direction, so it has no seam and stays put on the backdrop
		vec3 nd = vec3(d.x, d.y * 1.4, d.z) + vec3(cloud_drift * TIME * 0.05, 0.0, 0.0);
		float f1 = vn3(nd * 34.0);
		float f2 = vn3(nd * 85.0 + 4.2);
		vec2 fray = (vec2(f1, vn3(nd * 34.0 + 17.0)) - 0.5) * 0.026 + (vec2(f2, vn3(nd * 85.0 + 31.0)) - 0.5) * 0.012;
		vec4 best = vec4(0.0);
		float second = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 c = c0 + vec2(float(i), float(j));
				if (c.y < 0.0 || c.y >= cloud_rows) { continue; }
				vec2 id = vec2(mod(c.x, cols), c.y);
				float r1 = h21(id + 3.7);
				if (r1 > cloud_cover) { continue; }
				float r2 = h21(id + 11.3);
				float r3 = h21(id + 23.9);
				float r4 = h21(id + 5.1);
				// the cloud's centre in (azimuth, elevation), kept inside its cell so that the 3 x 3 search finds all of it
				float caz = (c.x + 0.2 + 0.6 * r2) * cw;
				float cel = cloud_high + (c.y + 0.25 + 0.5 * r3) * rh;
				// the cloud's flat frame: radians across (shrunk by the cosine of its height, so it keeps its shape) and up
				float da = az - caz;
				da -= TAU * floor(da / TAU + 0.5);
				vec2 q = vec2(da * cos(cel), el - cel) + fray * cloud_fluff;
				float R = (0.026 + 0.040 * r4 * r4 + 0.012 * r1 / max(cloud_cover, 0.05)) * cloud_puff;
				if (abs(q.x) > R * 3.2 || abs(q.y) > R * 2.4) { continue; }
				ball(q, vec2(0.0), R, best, second);
				ball(q, vec2(-0.95 * R, -0.16 * R), R * 0.70, best, second);
				ball(q, vec2(1.02 * R, -0.12 * R), R * 0.64, best, second);
				ball(q, vec2(-0.42 * R, 0.52 * R), R * 0.62, best, second);
				ball(q, vec2((r2 - 0.25) * 1.2 * R, 0.46 * R), R * (0.46 + 0.3 * r3), best, second);
				ball(q, vec2(-1.75 * R * step(0.45, r3), -0.30 * R), R * 0.44, best, second);
				ball(q, vec2(1.72 * R * step(0.4, r4), -0.28 * R), R * 0.40, best, second);
			}
		}
		if (best.z > 0.0) {
			vec3 n = normalize(vec3(best.xy, best.z));
			// the sun as this part of the sky sees it: right, up, towards the eye. A puff against the sun is still
			// lit from its top and its edge (cotton lets light through), so the eye term never drops under a floor.
			vec3 rt = normalize(vec3(-d.z, 0.0, d.x));
			vec3 upv = cross(rt, d);
			if (upv.y < 0.0) { upv = -upv; }
			vec3 ll = normalize(vec3(dot(L, rt), dot(L, upv) + 0.55, max(dot(L, -d), 0.0) + 0.5));
			float lit = dot(n, ll) * 0.5 + 0.5;
			float tex = (f2 - 0.5) * 0.5 + (f1 - 0.5) * 0.5;                 // cotton fibre
			vec3 cc = mix(cloud_shade, cloud, smoothstep(0.30, 0.78, lit + tex * 0.16 * cloud_fluff));
			float under = smoothstep(0.05, -0.75, n.y) * cloud_under_k;
			cc = mix(cc, cloud_under, under * (0.55 + 0.45 * side));
			float seam = smoothstep(0.0, 0.5, (best.z - second) / best.w);    // the fold between two balls
			cc = mix(mix(cc, cloud_shade, 0.42), cc, seam);
			cc = mix(cc, glow * 1.05, pow(max(sd, 0.0), 3.0) * 0.30);
			cc *= 1.0 + tex * 0.10 * cloud_fluff;
			float rim = best.z / best.w;
			float a = smoothstep(0.02, mix(0.10, 0.42, cloud_fluff), rim + tex * 0.22 * cloud_fluff);
			float fade = smoothstep(0.02, 0.10, h) * (1.0 - smoothstep(0.80, 1.0, h) * 0.6);
			col = mix(col, cc, a * fade);
		}
	}
	float ang = acos(sd);
	float dk = 1.0 - smoothstep(disc_r - disc_soft, disc_r + disc_soft, ang);
	col = mix(col, disc * 1.6, dk * step(0.0001, disc_r));
	COLOR = col;
}
