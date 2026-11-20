shader_type sky;

// A painted cyclorama with little tufts mounted in front of it. All marks are
// fixed to the dome. Only the radiance bake evaluates the tuft surfaces.
uniform vec3 zenith : source_color;
uniform vec3 upper : source_color;
uniform vec3 mid : source_color;
uniform vec3 horizon : source_color;
uniform vec3 ground : source_color;
uniform vec3 glow : source_color;
uniform vec3 disc : source_color;
uniform vec3 cloud : source_color;
uniform vec3 cloud_shade : source_color;
uniform float glow_k = 1.0;
uniform float disc_r = 0.024;
uniform float sun_draw_elev = 6.0;
uniform float sun_draw_yaw = 0.0;
uniform float brush = 0.12;
uniform float cloud_scale = 1.0;

// Pins on the cyclorama, in painting order. Bearing is relative to the painted
// light, followed by elevation, tuft size (degrees) and a shape seed. Leave
// a window for the sun and vary the gaps between the layers of wadding.
const vec4 PINS[27] = {
	vec4(-44, 5, 1.5, .31), vec4(6, 4, 1.7, .58), vec4(29, 6.4, 1.7, .27),
	vec4(50, 8.2, 2.3, .83), vec4(93, 4, 1.6, .40), vec4(131, 8, 1.5, .68),
	vec4(170, 4, 1.9, .19), vec4(-148, 7, 1.5, .78), vec4(-99, 6, 1.8, .35),
	vec4(-20, 13, 3.2, .13), vec4(10, 14, 4.1, .70), vec4(36, 19, 4.6, .37),
	vec4(65, 13.6, 3.8, .89), vec4(83, 10, 2.6, .21), vec4(110, 18, 4.4, .47),
	vec4(152, 13, 3.3, .76), vec4(-175, 19, 4.4, .29), vec4(-137, 14, 3.8, .52),
	vec4(-114, 21, 3.5, .92), vec4(-79, 12, 3.0, .17), vec4(-53, 21, 4.0, .63),
	vec4(-12, 41, 6.3, .82), vec4(53, 49, 5.0, .14), vec4(109, 34, 4.6, .61),
	vec4(174, 49, 6.5, .37), vec4(-126, 35, 5.0, .69), vec4(-64, 45, 6.0, .46)
};

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 z = vec2(
		mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
			mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
			mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y));
	return mix(z.x, z.y, f.z);
}

float join_wool(float a, float b, float spread) {
	float h = max(spread - abs(a - b), 0.0) / spread;
	return min(a, b) - h*h*spread*0.25;
}

// Hand-sized rolls pressed together. z faces the viewer. The outer two rolls
// hang low and the taller roll is offset differently in each cluster.
float tuft(vec3 p, float seed) {
	float crown_x = 0.94 * (seed - 0.5);
	float body = length(p * vec3(0.87, 1.25, 1.1)) - 0.79;
	float crown = length(p - vec3(crown_x, 0.31 + 0.20*seed, -0.08)) - (0.64 + 0.21*seed);
	float left = length((p - vec3(-0.85, 0.03, -0.18)) * vec3(1.0, 1.12, 1.0)) - (0.59 + 0.18*seed);
	float right = length(p - vec3(0.84, 0.08, -0.10)) - (0.78 - 0.19*seed);
	float fold = length(p - vec3(crown_x - 0.49, -0.04, 0.51)) - (0.41 + 0.18*seed);
	float cheek = length(p - vec3(0.54, -0.09, 0.46)) - (0.59 - 0.15*seed);
	float knot = length(p - vec3(-0.87, -0.16, 0.24)) - 0.42;
	return join_wool(join_wool(join_wool(body, crown, 0.23), join_wool(left, right, 0.16), 0.23),
		join_wool(join_wool(fold, cheek, 0.12), knot, 0.16), 0.15);
}

vec3 pinned_tuft(vec3 base, vec3 d, vec3 sun, vec2 bearing, vec4 pin) {
	float yaw = radians(pin.x);
	float pitch = radians(pin.y);
	vec2 axis = cos(yaw)*bearing + sin(yaw)*vec2(-bearing.y,bearing.x);
	vec3 front = vec3(axis.x*cos(pitch),sin(pitch),axis.y*cos(pitch));
	float z = dot(d,front);
	float size = radians(pin.z)*cloud_scale;
	if (z < cos(size*2.55)) { return base; }
	// A local tangent frame for each puff. A direction on either side of the
	// back of the dome hits the very same surface. There is no azimuth UV seam.
	vec3 right = vec3(-axis.y,0.0,axis.x);
	vec3 up = vec3(-axis.x*sin(pitch),cos(pitch),-axis.y*sin(pitch));
	float seed = pin.w;
	float x = dot(d,right) / (size*z*mix(1.06,1.19,seed));
	float y = dot(d,up) / (size*z*mix(0.74,0.98,seed));
	if (abs(x) > 2.12 || y < -1.26 || y > 1.72) {
		return base;
	}
	x *= seed > 0.5 ? 1.0 : -1.0;
	y += x * (seed-0.5)*0.18;
	float side = dot(sun,right) * (seed > 0.5 ? 1.0 : -1.0);
	// A tuft stands slightly proud of the painted cloth. Its broad, displaced
	// shadow is most visible at the bottom on the side away from the light.
	float mounted = 1.0 - smoothstep(-0.13, 0.33, tuft(vec3(x + side*0.13, y + 0.23, -0.08), seed));
	base *= mix(vec3(1.0), vec3(0.64, 0.53, 0.69), mounted*0.62);
	vec3 wool = vec3(x, y, seed*31.0);
	float nap = noise3(wool*5.2) - 0.5;
	float fibre = noise3(wool*19.0) - 0.5;
	vec2 uv = vec2(x, y) + vec2(nap, noise3(wool*4.7 + 2.1)-0.5)*0.17;
	uv += vec2(fibre, noise3(wool*22.0 + 1.6)-0.5)*0.039;
	vec3 p = vec3(uv, 1.30);
	float closest = 2.0;
	for (int i = 0; i < 16; i++) {
		float s = tuft(p, seed);
		closest = min(closest, s);
		if (s < 0.007 || p.z < -0.42) { break; }
		p.z -= max(0.012, s*0.89);
	}
	float edge = 1.0 - 0.6*smoothstep(0.003, 0.057, closest)
		- 0.4*smoothstep(0.012, 0.13 + 0.025*fibre, closest);
	if (edge <= 0.0) { return base; }
	vec2 e = vec2(0.022, 0.0);
	float s0 = tuft(p, seed);
	vec3 n = normalize(vec3(tuft(p+e.xyy, seed), tuft(p+e.yxy, seed), tuft(p+e.yyx, seed)) - s0);
	// Tiny compressed folds wrap the 3D surface, including the front of a roll.
	// Sample in object space so light catches them from the same side as the sun.
	vec3 curl = (p + vec3(seed, seed*7.0, seed*19.0))*5.7;
	float grain = noise3(curl);
	vec2 ds = vec2(0.12, 0.0);
	vec3 grad = vec3(noise3(curl+ds.xyy), noise3(curl+ds.yxy), noise3(curl+ds.yyx)) - grain;
	n = normalize(n - (grad - n*dot(grad,n))*2.6);
	float backlight = smoothstep(-0.3, 0.97, dot(sun,d));
	vec3 lamp = normalize(vec3(side*1.56, 0.78, mix(0.28,-0.30,backlight)));
	float fluff = nap*0.11 + fibre*0.085 + (noise3(wool*47.0)-0.5)*0.045;
	float diffuse = smoothstep(-0.33, 1.02, dot(n,lamp) + fluff);
	float bounce = smoothstep(-0.6, 1.1, y);
	float seam = clamp(tuft(p + lamp*0.41, seed)/0.41, 0.0, 1.0);
	vec3 shade = mix(cloud_shade, cloud, 0.045 + 0.12*bounce);
	vec3 key_light = mix(cloud, glow, 0.27*backlight);
	// Preserve the front folds when the viewer has the key at their back.
	vec3 lit = mix(shade, key_light*mix(1.28,1.52,backlight), diffuse * (0.55+0.45*seam));
	lit *= 1.0 + fluff*0.91 + (grain-0.5)*0.12;
	// The nap scatters a little sunset light right around the silhouette.
	lit += glow * (0.04 + 0.16*max(0.0,dot(d,sun))) * (1.0-clamp(n.z,0.0,1.0)) * (0.25+0.75*diffuse);
	return mix(base, lit, edge);
}

vec3 paint(vec3 d, vec3 sun, vec3 key) {
	float h = d.y;
	float align_sun = max(dot(d, sun), 0.0);
	// Long, broken strokes in the wet ground colour. The coordinates are the
	// continuous direction of the ray, including across north and the poles.
	vec3 stroke = vec3(d.x*14.0, h*60.0 + d.z*6.0 - d.x*15.0, d.z*14.0);
	float broad = noise3(stroke*0.43) - 0.5;
	float bristle = noise3(stroke*2.2 + broad*2.0) - 0.5;
	float t = h + (broad*0.8+bristle*0.18)*brush;
	vec3 col = mix(horizon, mid, smoothstep(-0.04, 0.21, t));
	col = mix(col, upper, smoothstep(0.04, 0.39, t));
	col = mix(col, zenith, smoothstep(0.38, 0.94, t));
	col = mix(col, ground, smoothstep(0.0, 0.28, -h));
	col *= 1.0 + brush*(1.5*broad + 1.2*bristle + (noise3(stroke*6.1)-0.5)*0.7);
	float aureole = (pow(align_sun, 6.0)*0.24 + pow(align_sun, 32.0)*0.47 + pow(align_sun, 240.0)*0.36)*glow_k;
	col = mix(col, glow*1.40, min(aureole, 0.94));
	float sun_angle = acos(clamp(dot(d, sun), -1.0, 1.0));
	col += glow * (0.34*exp(-sun_angle*25.0) + 0.10*exp(-sun_angle*9.5));
	col = mix(col, disc*3.25, (1.0-smoothstep(disc_r*0.73, disc_r*1.24, sun_angle)));
	if (cloud_scale > 0.0 && h > 0.0 && h < 0.91) {
		vec2 bearing = normalize(sun.xz);
		for (int i = 0; i < 27; i++) {
			col = pinned_tuft(col,d,key,bearing,PINS[i]);
		}
	}
	return col;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		// The disc is painted on the backing. The studio key rakes across
		// the real timber, and lights each raised tuft from that same side.
		vec3 key = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0,0.3,-0.954);
		vec2 bearing = key.xz;
		bearing = length(bearing) > 0.001 ? normalize(bearing) : vec2(0.0,-1.0);
		float turn = radians(sun_draw_yaw);
		bearing = cos(turn)*bearing + sin(turn)*vec2(-bearing.y,bearing.x);
		float el = radians(sun_draw_elev);
		COLOR = paint(EYEDIR, vec3(bearing.x*cos(el), sin(el), bearing.y*cos(el)),key);
	} else {
		COLOR = textureLod(RADIANCE, EYEDIR, 0.0).rgb;
	}
}
