shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// One palette lookup per vertex. The press marks travel with the baked pieces,
// even where two bones share a sleeve. UV.x is the sculptor's worn-edge mask.
uniform sampler2D pal_lut : filter_nearest, repeat_disable;
global uniform vec4 g_sun_dir;
global uniform vec4 g_bounce;
global uniform vec4 g_amb_sky;
instance uniform vec4 tl_plot = vec4(0.0);
instance uniform vec4 tl_clip = vec4(0.0);
varying vec3 clay;
varying vec3 paint;
varying flat float finish;

void vertex() {
	clay = CUSTOM0.xyz;
	paint = texelFetch(pal_lut, ivec2(int(CUSTOM0.w + 0.5), 0), 0).rgb * COLOR.rgb;
	finish = UV.y;
	// Like the other moving kit pieces, draw a non-stage pack at its plot
	// (and in its shadow pass). The whole figure follows the rim height.
	float radius = length(MODEL_MATRIX[3].xz);
	float raise = 0.0;
	if (tl_clip.x > 0.0) {
		if (radius > tl_clip.x) {
			VERTEX = vec3(0.0);
		} else if (tl_clip.z > 0.0) {
			raise = (tl_clip.y - MODEL_MATRIX[3].y) * smoothstep(tl_clip.x-tl_clip.z, tl_clip.x, radius);
		}
	}
	if (any(notEqual(tl_plot, vec4(0.0))) || raise != 0.0) {
		float c = cos(tl_plot.w), s = sin(tl_plot.w);
		mat4 plot = mat4(vec4(c,0,-s,0), vec4(0,1,0,0), vec4(s,0,c,0), vec4(tl_plot.xyz,1));
		plot[3].y += raise;
		MODELVIEW_MATRIX = VIEW_MATRIX * plot * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(plot) * MODEL_NORMAL_MATRIX;
	}
}

float hash3(vec3 p) {
	p = fract(p * vec3(.1031, .11369, .13787));
	p += dot(p, p.yxz + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
		mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
		mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

// An oval fingertip pressed into the piece, with an off-centre whorl and
// broken, tapering ridges. Fade before the ridge cycle falls below two pixels.
float impression(vec2 p, vec2 size, float phase) {
	vec2 q = p / size;
	q.y += .18 * sin(2.4 * q.x + phase) + .08 * q.x * q.x;
	// Only part of the fingertip touched the surface. Its centre is beyond
	// the contact patch, leaving a few arches that lift away at each end.
	float r = length(vec2(.82*q.x + .59 + .12 * sin(q.y * 2.3), q.y+.81));
	float cycle = 6.2 * r + .18 * sin(3.0 * q.x - q.y);
	float ridge = cos(6.28318 * cycle);
	float resolved = 1.0 - smoothstep(.17, .5, fwidth(cycle));
	float patch = 1.0 - smoothstep(.28, 1.12, length(q));
	patch *= smoothstep(-.68,.18,q.y + .57*q.x + .15*sin(phase + 4.0*q.x));
	return ridge * patch * resolved;
}

void fragment() {
	vec3 p = clay;
	vec2 sheet = vec2(p.x + .37 * p.z, p.y + .12 * p.z);
	float hair = float(abs(finish - 2.0) < .1);
	float jacket = float(abs(finish - 6.0) < .1);
	float denim = float(abs(finish - 8.0) < .1);
	float sleeve = float(abs(finish - 9.0) < .1);
	float boot = float(abs(finish - 10.0) < .1);
	float enamel = max(max(jacket,sleeve), float(abs(finish - 1.0) < .1));
	float glossy = float(abs(finish - 4.0) < .1);
	float helmet = float(abs(finish - 5.0) < .1);
	float cloud = noise3(p * 13.0 + vec3(5, 3, 9));
	float grain = noise3(p * 92.0);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float fine = 1.0 - smoothstep(.002, .014, footprint);
	float print_h = hair * impression(sheet - vec2(-.075, 1.775), vec2(.137,.087), .3) * smoothstep(.03,.16,p.z)
		+ jacket * impression(vec2(sheet.x,sheet.y-.27*sheet.x) - vec2(-.091, 1.10), vec2(.142,.066), 1.7)
		+ sleeve * impression(sheet - vec2(-.29, 1.24), vec2(.085,.094), 2.9)
		+ boot * impression(sheet - vec2(.16, .17), vec2(.085,.057), 1.3);
	// Shallow gouges fan out through the back of the sculpted hair. The
	// individual arcs lose depth as the modelling tool lifts at their ends.
	float fan = atan(p.x, p.z + .025) * 7.0 + 15.0*(p.y-1.72) + 1.3*sin(8.0*p.y+5.0*p.x);
	float cuts = pow(max(0.0, cos(fan)), 9.0);
	cuts *= smoothstep(.04,.17,p.z) * smoothstep(1.58,1.72,p.y) * (1.0-smoothstep(1.92,2.02,p.y)) * hair;
	// Three or four strokes of a blunt tool curl out from the left nape.
	float comb = 29.0 * (p.y - 1.70 - .44*p.x + 2.6*(p.x+.10)*(p.x+.10));
	float rake = pow(max(0.0,cos(6.28318*comb)), 4.0) * (1.0-smoothstep(.2,.52,fwidth(comb)));
	vec2 nape = (p.xy - vec2(-.156,1.72)) / vec2(.181,.102);
	cuts += .18*rake*(1.0-smoothstep(.28,1.12,length(nape))) * hair * smoothstep(.07,.20,p.z);
	// A seam pressed into the back yoke; ends wrap around the armholes.
	float yoke_line = p.y - 1.253 - 1.06 * p.x*p.x - .010*p.x;
	float yoke = jacket * smoothstep(.04,.13,p.z) * (1.0-smoothstep(.001,.006+footprint,abs(yoke_line)));
	// Two denim patches pressed into the seat. The lower corners taper
	// and the upper edge catches a little of the unbleached undercoat.
	vec2 seat = (vec2(abs(p.x),p.y) - vec2(.127,.797)) / vec2(.079,.066);
	seat.y += .19*seat.x;
	float pocket_edge = max(abs(seat.x) + .18*max(-seat.y,0.0) - 1.0,
		max(seat.y-.88, -.87+.41*min(1.0,abs(seat.x))-seat.y));
	float pocket = denim * smoothstep(.070,.13,p.z) * (1.0-smoothstep(-.06,.06+footprint*12.0,pocket_edge));
	float stitch = pocket * smoothstep(-.19,-.015,pocket_edge);
	// Four shallow chevrons pressed into each sole show when the heel lifts.
	float tread_pos = p.z + .35*abs(abs(p.x)-.153);
	float tread = (1.0-smoothstep(.002,.007+footprint,abs(fract(tread_pos/.066+.5)-.5)*.066));
	tread *= float(abs(finish-7.0) < .1) * (1.0-smoothstep(.002,.014,p.y))
		* smoothstep(-.19,-.13,p.z) * (1.0-smoothstep(.056,.088,p.z));
	// Exposed pale bisque only along a painted lip. Two scales leave flakes
	// with torn edges and small satellites, not dots on the entire coat.
	float flakes = .66 * noise3(p * 31.0 + vec3(2, 6, 4)) + .34 * grain;
	// Larger patches of handling wear on the coat's right hip, the outer
	// elbow and the opposite knee. Let intact pigment break across each rub.
	vec2 hip = (p.xy - vec2(.168,.925)) / vec2(.085,.045);
	hip.y -= .50 * hip.x;
	vec2 elbow = (p.xy - vec2(-.337,1.131)) / vec2(.075,.092);
	elbow.x += .32 * elbow.y;
	vec2 shin = (p.xy - vec2(-.164,.440)) / vec2(.070,.100);
	shin.x -= .39 * shin.y;
	float rub = max(jacket * (1.0-smoothstep(.24,1.3,length(hip))),
		max(sleeve * (1.0-smoothstep(.18,1.2,length(elbow))), denim * (1.0-smoothstep(.18,1.25,length(shin)))));
	rub *= smoothstep(-.04,.09,p.z) * (.73 + .54 * cloud);
	float threshold = .81 - .18 * UV.x;
	threshold += jacket * .087 * (.5 + .5 * sin(21.0*p.x + 13.0*p.z + .6));
	float aa = max(.018, fwidth(flakes));
	float chip = smoothstep(threshold - aa, threshold + aa, flakes) * smoothstep(.12, .68, UV.x);
	chip = max(chip, smoothstep(.77-aa,.77+aa,flakes+.40*rub) * smoothstep(.08,.75,rub));
	// The raised welt takes the abrasion on a boot. Its upper stays polished.
	float welt = boot * (1.0-smoothstep(.003,.016+footprint,abs(p.y - .077 - .004*sin(32.0*p.x))));
	chip = max(chip, welt * smoothstep(.52-aa,.68+aa,flakes));
	chip *= 1.0 - .56*smoothstep(.53,.75,grain)*fine;
	// A flake removes the painted skin. Its rim and the lip of a thumb
	// impression catch light as the figure turns.
	float height = (.008 * cloud + fine * .00055 * grain + .00135 * print_h
		- .0055*cuts - .003*yoke - .002*tread - .0017*chip + .0023*pocket) * (1.0 - .82 * glossy);
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 bx = cross(dy, NORMAL), by = cross(NORMAL, dx);
	float det = dot(dx, bx);
	NORMAL = normalize(NORMAL - (dFdx(height) * bx + dFdy(height) * by)
		* sign(det) / max(abs(det), 0.00000000001));
	vec3 bisque = mix(vec3(.52, .277, .123), vec3(.83,.60,.34), grain);
	vec3 pigment = paint * (1.0 + (cloud - .5) * .24 + (grain - .5) * .05 * fine);
	// Scuffed indigo first exposes the lighter blue wash underneath.
	bisque = mix(bisque, mix(paint,vec3(.44,.49,.48),.36), denim);
	bisque = mix(bisque, mix(paint,vec3(.39,.21,.095),.55),boot);
	pigment *= 1.0 + .028*print_h;
	pigment *= mix(vec3(1),vec3(.90,1.04,1.03),hair);
	float leather = boot*smoothstep(.012,.085,paint.r-paint.b);
	pigment *= mix(vec3(1),vec3(1.65,1.53,.87),leather);
	pigment *= 1.0 + .52*welt*(.62+.38*cloud);
	pigment *= mix(vec3(1),vec3(.96,1.29,1.01),denim);
	pigment *= 1.0 - .12*cuts - .17*yoke - .27*tread - .23*stitch + .09*pocket;
	// Local contact beneath the standing collar and where the jacket laps the jeans.
	pigment *= 1.0 - .29*jacket*smoothstep(1.304,1.397,p.y) - .27*denim*smoothstep(.77,.90,p.y);
	if (finish < .5 && p.z < -.1) {
		vec2 cheek = (vec2(abs(p.x),p.y) - vec2(.165,1.668)) / vec2(.080,.047);
		pigment *= mix(vec3(1), vec3(1.09,.78,.72), exp(-dot(cheek,cheek)*1.7));
	}
	if (helmet > .5) {
		float stripe = abs(p.x + .004 * sin(14.0 * p.z));
		float w = max(.001,fwidth(stripe));
		pigment = mix(vec3(.95,.89,.77), pigment, smoothstep(.033-w,.033+w,stripe));
		vec2 vent = vec2((abs(p.x)-.142)/.012, (abs(p.z-.015)-.084)/.044);
		float v = length(vent);
		pigment *= 1.0 - .64 * (1.0-smoothstep(.8,1.1+fwidth(v),v)) * smoothstep(1.93,1.96,p.y);
	}
	ALBEDO = mix(pigment, bisque, chip * .86);
	// Broad reflections from the sky and lit ground sit across the rough
	// paint; low planes retain the warm cast of the floor.
	vec3 n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 open_sky = normalize(vec3(-g_sun_dir.x,.66,-g_sun_dir.z));
	float sky = max(0.0,dot(n,open_sky));
	vec3 reflection = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
	float sheen = pow(max(dot(reflection,open_sky),0.0), 2.8);
	vec3 bounce = mix(vec3(1), g_bounce.rgb, .48);
	vec3 floor_dir = normalize(vec3(-g_sun_dir.x,-.62,-g_sun_dir.z));
	float floor_light = smoothstep(-.25,.95,dot(n,floor_dir)) * g_bounce.a;
	EMISSION = g_amb_sky.a * (ALBEDO * (vec3(.045) + 2.4*bounce*sky*sky)
		+ sheen * bounce * (.045 + .12*hair + .080*enamel + .11*boot + .09*helmet))
		+ .48*floor_light*g_bounce.rgb*ALBEDO;
	ROUGHNESS = clamp(.54 - enamel * .11 - boot * .17 - hair * .065 - glossy * .25 - helmet * .18 + .07 * (1.0 - cloud) + chip * .16, .22, .83);
	SPECULAR = .39 + .08 * enamel + .12 * glossy;
}
