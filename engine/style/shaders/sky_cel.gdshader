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
uniform vec3 glow : source_color;
uniform vec3 disc : source_color;
uniform float sun_draw_elev = 6.0;
uniform float sun_draw_yaw = 0.0;
uniform float disc_r = 0.027;
uniform float glow_k = 0.8;
uniform float cloud_scale = 1.0;

// Centre offset as a share of the sector, base elevation, half-width and
// height in degrees. A low bank is longer than a high, billowing crown.
const vec4 BANKS[8] = {
	vec4(.52,4.2,6.0,3.2), vec4(.42,5.7,4.2,2.6), vec4(.58,3.2,7.1,3.8), vec4(.47,5.0,4.9,2.4),
	vec4(.49,4.7,5.3,3.1), vec4(.39,3.5,6.5,3.0), vec4(.56,4.5,4.6,2.8), vec4(.49,6.0,6.1,3.7)
};
const vec4 TOWERS[8] = {
	vec4(.48,11.8,8.7,6.4), vec4(.54,13.6,10.1,6.6), vec4(.40,10.2,7.4,5.8), vec4(.52,12.9,9.3,6.2),
	vec4(.60,10.3,7.0,5.5), vec4(.45,12.0,9.9,7.2), vec4(.58,15.6,6.9,5.4), vec4(.51,10.4,8.3,5.4)
};
const vec4 HIGH[8] = {
	vec4(.56,29,11.2,8.2), vec4(.42,35,8.9,6.8), vec4(.47,25,7.7,7.3), vec4(.52,31,10,8.7),
	vec4(.40,38,9.5,7.2), vec4(.58,27,9.8,6.8), vec4(.42,32,8.2,6.2), vec4(.53,25,10.5,7.1)
};

// One profile per cloud family. Each ellipse is (x, y, radius x, radius y)
// in the cloud's local drawing. The fourth/fifth lobes make different
// shoulders, shallow saddles and tails readable from the road.
const vec4 CROWN[6] = {
	vec4(-.19,.43,.48,.64), vec4(-.43,.42,.34,.72), vec4(-.45,.25,.46,.48),
	vec4(.16,.53,.53,.74), vec4(-.31,.47,.59,.66), vec4(-.44,.39,.33,.60)
};
const vec4 RIDGE[6] = {
	vec4(.28,.32,.43,.47), vec4(-.02,.37,.39,.48), vec4(.27,.30,.40,.66),
	vec4(-.31,.28,.39,.44), vec4(.21,.37,.42,.50), vec4(-.02,.45,.32,.56)
};
const vec4 LEFT[6] = {
	vec4(-.60,.17,.39,.39), vec4(-.67,.19,.29,.38), vec4(-.68,.11,.30,.27),
	vec4(-.67,.10,.36,.24), vec4(-.70,.18,.29,.32), vec4(-.68,.16,.28,.34)
};
const vec4 RIGHT[6] = {
	vec4(.66,.16,.33,.36), vec4(.46,.16,.48,.30), vec4(.62,.29,.33,.44),
	vec4(.68,.14,.32,.42), vec4(.57,.13,.42,.27), vec4(.39,.26,.27,.41)
};
const vec4 TIP[6] = {
	vec4(.74,.08,.24,.20), vec4(.77,.07,.21,.17), vec4(-.09,.14,.28,.30),
	vec4(-.83,.06,.19,.15), vec4(.80,.06,.21,.16), vec4(.72,.12,.28,.25)
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
	float offset = row == 1 ? -2.0 : 2.0;
	float sector = mod(angles.x + offset,360.0)*count/360.0;
	int id = int(floor(sector));
	int i = id % 8;
	vec4 pin = row == 0 ? BANKS[i] : (row == 1 ? TOWERS[i] : HIGH[i]);
	vec2 size = pin.zw * cloud_scale;
	vec2 p = vec2((fract(sector)-pin.x)*(360.0/count), angles.y-pin.y)/size;
	float varied = fract((float(id)*.618 + float(row)*.42));
	p.y -= p.x*(varied-.48)*.14;
	if (abs(p.x) > 1.12 || p.y < -.20 || p.y > 1.40) { return sky_color; }
	vec2 shape = p;
	shape.x *= (id % 2 == 0) ? 1.0 : -1.0;
	int family = (id*5+row*2+2*(id/6))%6;
	vec4 top = CROWN[family], ridge = RIDGE[family], left = LEFT[family], right = RIGHT[family], tip = TIP[family];
	float arc = min(ellipse(shape,top.xy,top.zw),ellipse(shape,ridge.xy,ridge.zw));
	arc = min(arc,min(ellipse(shape,left.xy,left.zw),ellipse(shape,right.xy,right.zw)));
	arc = min(arc,ellipse(shape,tip.xy,tip.zw));
	float base = -.045 + mix(.07,.16,varied)*p.x*p.x + .045*shape.x;
	float outline = max(arc,base-p.y);
	float aa = clamp(footprint/min(size.x,size.y),.001,.18);
	float coverage = 1.0-smoothstep(-aa,aa,outline);
	// The light side belongs to this cloud as a whole, including when it
	// spans the sun bearing. Each family carries a different underside.
	float centre = radians((float(id)+pin.x)*360.0/count-offset);
	float x = p.x * (dot(key,vec2(-sin(centre),cos(centre))) > 0.0 ? -1.0 : 1.0);
	float edge = .08 - .30*x + .11*smoothstep(-.45,-.25,x);
	float cut = 0.0;
	if (family == 0 || family == 4) {
		edge += .13*smoothstep(.14,.31,x);
		cut = fold(vec2(x,p.y),vec2(-.37,.51),vec2(.16,.064),aa);
	} else if (family == 1 || family == 3) {
		edge += .21*(1.0-smoothstep(.06,.61,abs(x+.15)));
		cut = fold(vec2(x,p.y),vec2(.05,.47),vec2(.082,.049),aa);
	} else if (family == 2) {
		edge += .22*smoothstep(-.24,-.14,x)*(1.0-smoothstep(.13,.49,x));
	} else {
		edge += .10*smoothstep(-.16,.12,x);
		cut = fold(vec2(x,p.y),vec2(-.34,.36),vec2(.11,.047),aa);
		cut = max(cut,fold(vec2(x,p.y),vec2(.27,.44),vec2(.065,.042),aa));
	}
	float underside = 1.0-smoothstep(edge-aa,edge+aa,p.y);
	vec3 fill = mix(cloud,cloud_shade,max(underside,cut));
	fill *= 1.0-.17*(1.0-smoothstep(.0,aa*2.0,p.y-base))*underside;
	return mix(sky_color,fill,coverage);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 c = mix(horizon,mid,smoothstep(.008,.195,h));
	c = mix(c,upper,smoothstep(.075,.32,h));
	c = mix(c,zenith,smoothstep(.25,.88,h));
	c = mix(c,ground,smoothstep(.0,.26,-h));
	vec2 key = LIGHT0_ENABLED ? LIGHT0_DIRECTION.xz : vec2(-1.0,.6);
	key /= max(.001,length(key));
	float yaw = radians(sun_draw_yaw);
	vec2 bearing = cos(yaw)*key + sin(yaw)*vec2(-key.y,key.x);
	float el = radians(sun_draw_elev);
	vec3 sun = vec3(bearing.x*cos(el),sin(el),bearing.y*cos(el));
	float angle = acos(clamp(dot(sun,d),-1.0,1.0));
	c = mix(c,glow,glow_k*(.48*exp(-12.0*angle*angle)+.48*exp(-12.5*angle)));
	float feather = clamp(max(length(dFdx(d)),length(dFdy(d))),.00015,.002);
	c = mix(c,disc,1.0-smoothstep(disc_r-feather,disc_r+feather,angle));
	// EYEDIR is continuous at the longitude join, including its derivatives.
	float pixel = degrees(max(length(dFdx(d)),length(dFdy(d))))*.68;
	if (cloud_scale > .0 && h > .008 && h < .80) {
		vec2 angles = degrees(vec2(atan(d.z,d.x),asin(h)));
		c = cloud_at(c,angles,pixel,key,2);
		c = cloud_at(c,angles,pixel,key,1);
		c = cloud_at(c,angles,pixel,key,0);
	}
	COLOR = c;
}
