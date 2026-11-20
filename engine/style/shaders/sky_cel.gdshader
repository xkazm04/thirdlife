shader_type sky;

// Three rings of flat, cut-paper cumulus. Each sector owns one complete
// silhouette. Longitude wraps between sectors, in clear sky. Evaluate the
// signed edges in the view itself so the cubemap cannot soften the line.
uniform vec3 zenith : source_color;
uniform vec3 upper : source_color;
uniform vec3 mid : source_color;
uniform vec3 horizon : source_color;
uniform vec3 ground : source_color;
uniform vec3 cloud : source_color;
uniform vec3 cloud_shade : source_color;
uniform vec3 cloud_ink : source_color;
uniform float cloud_line = 0.7;
uniform vec3 glow : source_color;
uniform vec3 disc : source_color;
uniform float sun_draw_elev = 6.0;
uniform float sun_draw_yaw = 0.0;
uniform float disc_r = 0.027;
uniform float disc_soft = 0.004;
uniform float glow_k = 0.8;
uniform float cloud_scale = 1.0;

// Centre offset as a share of the sector, base elevation, half-width and
// height in degrees. A low bank is longer than a high, billowing crown.
const vec4 BANKS[16] = {
	vec4(.52,4.2,6.0,3.2), vec4(.42,5.7,4.2,2.6), vec4(.58,3.2,7.1,3.8), vec4(.47,5.0,4.9,2.4),
	vec4(.49,4.7,5.3,3.1), vec4(.39,3.5,6.5,3.0), vec4(.56,4.5,4.6,2.8), vec4(.49,6.0,6.1,3.7),
	vec4(.34,8.7,5.1,4.0), vec4(.79,5.2,3.7,2.8), vec4(.57,3.1,6.9,3.6), vec4(.45,5.1,5.0,2.8),
	vec4(.53,4.4,5.6,3.3), vec4(.41,3.7,6.1,2.7), vec4(.54,4.6,4.8,3.1), vec4(.50,5.8,6.2,3.6)
};
const vec4 TOWERS[8] = {
	vec4(.48,11.8,8.7,6.4), vec4(.54,13.6,10.1,6.6), vec4(.40,10.2,7.4,5.8), vec4(.52,12.9,9.3,6.2),
	vec4(.72,8.6,6.7,5.1), vec4(.44,10.6,8.4,7.0), vec4(.69,8.0,7.5,6.3), vec4(.51,10.4,8.3,5.4)
};
const vec4 HIGH[8] = {
	vec4(.56,29,11.2,8.2), vec4(.42,35,8.9,6.8), vec4(.47,25,7.7,7.3), vec4(.52,31,10,8.7),
	vec4(.40,38,9.5,7.2), vec4(.58,27,9.8,6.8), vec4(.42,32,8.2,6.2), vec4(.53,25,10.5,7.1)
};

// One profile per cloud family. Each ellipse is (x, y, radius x, radius y)
// in the cloud's local drawing. The side lobes make different
// shoulders, shallow saddles and tails readable from the road.
const vec4 CROWN[6] = {
	vec4(-.08,.38,.62,.72), vec4(-.20,.40,.54,.70), vec4(-.27,.32,.56,.58),
	vec4(.14,.40,.56,.71), vec4(-.14,.39,.61,.65), vec4(-.31,.38,.46,.64)
};
const vec4 RIDGE[6] = {
	vec4(.33,.32,.48,.55), vec4(.19,.36,.47,.54), vec4(.27,.33,.51,.69),
	vec4(-.24,.33,.49,.54), vec4(.32,.33,.45,.51), vec4(.13,.36,.52,.62)
};
const vec4 LEFT[6] = {
	vec4(-.60,.20,.39,.42), vec4(-.67,.18,.32,.39), vec4(-.60,.15,.38,.33),
	vec4(-.62,.22,.39,.39), vec4(-.66,.19,.33,.35), vec4(-.64,.15,.34,.34)
};
const vec4 RIGHT[6] = {
	vec4(.67,.18,.32,.39), vec4(.57,.22,.41,.40), vec4(.62,.20,.36,.46),
	vec4(.65,.18,.34,.39), vec4(.58,.23,.41,.37), vec4(.57,.22,.40,.40)
};

float ellipse(vec2 p, vec2 centre, vec2 radii) {
	return (length((p-centre)/radii)-1.0) * min(radii.x,radii.y);
}

// A short sloping shadow cast by one billow on its neighbour.
float fold(vec2 p, vec2 at, vec2 half_size, float aa) {
	vec2 q = p-at;
	q.y += .67*q.x;
	q.x -= .35*q.y;
	vec2 box = abs(q)-half_size+.022;
	float distance_to_fold = length(max(box,vec2(0))) + min(max(box.x,box.y),0.0) - .022;
	return 1.0-smoothstep(-aa,aa,distance_to_fold);
}

vec3 cloud_at(vec3 sky_color, vec2 angles, float footprint, vec2 key, int row) {
	float count = row == 0 ? 16.0 : (row == 1 ? 12.0 : 8.0);
	float offset = row == 1 ? -5.5 : 2.0;
	float sector = mod(angles.x + offset,360.0)*count/360.0;
	int id = int(floor(sector));
	int i = id % 8;
	vec4 pin = row == 0 ? BANKS[id] : (row == 1 ? TOWERS[i] : HIGH[i]);
	vec2 size = pin.zw * cloud_scale;
	vec2 p = vec2((fract(sector)-pin.x)*(360.0/count), angles.y-pin.y)/size;
	float varied = fract((float(id)*.618 + float(row)*.42));
	p.y -= p.x*(varied-.48)*.14;
	if (abs(p.x) > 1.12 || p.y < -.20 || p.y > 1.40) { return sky_color; }
	vec2 shape = p;
	shape.x *= (id % 2 == 0) ? 1.0 : -1.0;
	int family = (id*5+row*2+2*(id/6))%6;
	vec4 top = CROWN[family], ridge = RIDGE[family], left = LEFT[family], right = RIGHT[family];
	float arc = min(ellipse(shape,top.xy,top.zw),ellipse(shape,ridge.xy,ridge.zw));
	arc = min(arc,min(ellipse(shape,left.xy,left.zw),ellipse(shape,right.xy,right.zw)));
	float base = -.045 + mix(.045,.095,varied)*p.x*p.x + .020*shape.x;
	float outline = max(arc,base-p.y);
	float aa = clamp(footprint/min(size.x,size.y),.001,.18);
	float coverage = 1.0-smoothstep(-aa,aa,outline);
	// The light side belongs to this cloud as a whole, including when it
	// spans the sun bearing. Each family carries a different underside.
	float centre = radians((float(id)+pin.x)*360.0/count-offset);
	// A low, curved shelf crosses the base. Each billow casts one slanted
	// facet onto the shelf or onto its smaller neighbour.
	float x = p.x * (dot(key,vec2(-sin(centre),cos(centre))) > 0.0 ? -1.0 : 1.0);
	float joint = -.38 + .23*varied;
	float slope = mix(.28,.38,varied);
	float edge = .115 - slope*x - .085*x*x;
	edge += .13*smoothstep(joint-.055,joint+.04,x);
	edge += .10*smoothstep(.20+joint*.20,.31+joint*.20,x);
	float underside = 1.0-smoothstep(edge-aa,edge+aa,p.y);
	vec2 lit = vec2(x,p.y);
	// Clip the left end of the facet to the rising crown, so it meets
	// the shoulder at a different height on each silhouette.
	float cheek = fold(lit,vec2(joint-.20,.44+.09*varied),
			vec2(.20+.07*varied,.06+.030*varied),aa);
	float face = ellipse(shape,top.xy,top.zw);
	cheek *= 1.0-smoothstep(-aa,aa,face);
	float facet = max(underside,cheek);
	if ((family == 0 || family == 3 || family == 5) && row != 0) {
		facet = max(facet,fold(lit,vec2(joint+.40,.43+.12*varied),vec2(.075,.041),aa));
	}
	if (family == 1 || family == 4) {
		facet = max(facet,fold(lit,vec2(joint+.18,.28),vec2(.105,.055),aa));
	}
	// The sunward bank picks up a little reflected peach. Both cel fills
	// stay uniform across their own cloud.
	float facing = dot(key,vec2(cos(centre),sin(centre)));
	float reflected = .10*smoothstep(.80,1.0,facing) + .08*smoothstep(.992,1.0,facing);
	vec3 shade = mix(cloud_shade,horizon,reflected);
	vec3 fill = mix(cloud,shade,facet);
	float rim = 1.0-smoothstep(.0,max(aa,.036-.019*x*x),p.y-base);
	fill = mix(fill,cloud_ink,rim*cloud_line*.95);
	return mix(sky_color,fill,coverage);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	// Interpolate the peach, rose and violet pigments through the lower sky.
	// Ease the last few degrees into the upper wash above the road view.
	float elevation = (h+.005)/.33;
	float shoulder = clamp((elevation-.85)/.30,0.0,1.0);
	float t = clamp(elevation-.15*shoulder*shoulder,0.0,1.0);
	vec3 c = mix(mix(horizon,mid,t),mix(mid,upper,t),t);
	c = mix(c,zenith,smoothstep(.23,.88,h));
	c = mix(c,ground,smoothstep(.0,.26,-h));
	vec2 key = LIGHT0_ENABLED ? LIGHT0_DIRECTION.xz : vec2(-1.0,.6);
	key /= max(.001,length(key));
	float yaw = radians(sun_draw_yaw);
	vec2 bearing = cos(yaw)*key + sin(yaw)*vec2(-key.y,key.x);
	float el = radians(sun_draw_elev);
	vec3 sun = vec3(bearing.x*cos(el),sin(el),bearing.y*cos(el));
	float angle = acos(clamp(dot(sun,d),-1.0,1.0));
	// The broad peach field carries a smaller, yellow aureole immediately
	// around the pale disc. Both follow its bearing across the sky join.
	c = mix(c,glow,glow_k*(.40*exp(-12.0*angle*angle)+.60*exp(-75.0*angle*angle)));
	float feather = clamp(max(length(dFdx(d)),length(dFdy(d))),.00015,.002);
	float rim = max(feather,disc_soft);
	c = mix(c,disc,1.0-smoothstep(disc_r-rim,disc_r+rim,angle));
	// EYEDIR is continuous at the longitude join, including its derivatives.
	float pixel = degrees(max(length(dFdx(d)),length(dFdy(d))))*.68;
	if (cloud_scale > .0 && h > .008 && h < .80) {
		vec2 angles = degrees(vec2(atan(d.z,d.x),asin(h)));
		c = cloud_at(c,angles,pixel,bearing,2);
		c = cloud_at(c,angles,pixel,bearing,1);
		c = cloud_at(c,angles,pixel,bearing,0);
	}
	COLOR = c;
}
