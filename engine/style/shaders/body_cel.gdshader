shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform sampler2D pal_lut : filter_nearest, repeat_disable;
global uniform vec4 g_sun;
#include "res://style/shaders/body_cel_plot.gdshaderinc"
varying vec3 pigment;
varying vec3 bind_position;
varying flat float finish;

void vertex() {
	bind_position = CUSTOM0.xyz;
	pigment = texelFetch(pal_lut,ivec2(int(CUSTOM0.w+.5),0),0).rgb * COLOR.rgb;
	finish = UV.y;
	mat4 plot = figure_plot(MODEL_MATRIX[3].xyz,VERTEX);
	MODELVIEW_MATRIX = VIEW_MATRIX * plot * MODEL_MATRIX;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(plot) * MODEL_NORMAL_MATRIX;
}

void fragment() {
	vec3 p = bind_position;
	vec3 c = pigment;
	if (abs(finish-6.0) < .1) {
		// Welt and shoulder yoke stay put through skinning. Let the narrow
		// shoulder stitch disappear as it projects below a single pixel.
		float dy = max(.0007,fwidth(p.y));
		float yoke = p.y - (1.158+.15*p.x*p.x);
		float stitch = 1.0-smoothstep(.001,.001+dy,abs(yoke));
		c *= 1.0 - .28*stitch*smoothstep(.08,.14,p.z)*clamp(.003/dy,0.0,1.0);
		c *= mix(vec3(.33,.22,.38),vec3(1),smoothstep(.878-dy,.878+dy,p.y));
	} else if (abs(finish-2.0) < .1) {
		c *= vec3(1.04,.86,.77);
	} else if (abs(finish-10.0) < .1) {
		c *= vec3(1.18,.92,.80);
	}
	if (abs(finish-6.0) < .1 || abs(finish-9.0) < .1) {
		// Concentrate the cloth dye while preserving a pack's chosen hue.
		float grey = dot(c,vec3(.2126,.7152,.0722));
		c = max(mix(vec3(grey),c,1.10),vec3(0.0));
	}
	ALBEDO = c;
	ROUGHNESS = .5; // the silhouette pass recognises moving figures by this value
}

void light() {
	float facing = dot(normalize(NORMAL),LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		// Smooth only the pixel that straddles a paint boundary. Keep cast
		// visibility separate so it cannot create extra stripes at an edge.
		float aa = clamp(fwidth(facing)*.76,.009,.12);
		float turn = smoothstep(-.07-aa,-.07+aa,facing);
		float light_face = smoothstep(.54-aa,.54+aa,facing);
		vec3 sunlit = mix(vec3(1),g_sun.rgb,.46)*g_sun.a;
		vec3 shade = vec3(.53,.36,.59);
		vec3 midtone = vec3(.86,.70,.79);
		if (finish < .1) {
			shade = vec3(.82,.63,.63);
			midtone = vec3(.99,.86,.80);
		} else if (abs(finish-2.0) < .1 || abs(finish-10.0) < .1) {
			sunlit *= vec3(1.70,1.40,1.0);
			shade *= vec3(1.0,.86,.72);
		} else if (abs(finish-6.0) < .1 || abs(finish-9.0) < .1) {
			// The violet fill brightens the red and blue plates on folded
			// cloth. It also works on alternate team colours.
			shade *= vec3(1.19,.95,1.28);
			sunlit *= vec3(.94,.92,1.06);
		}
		vec3 paint = mix(mix(shade,midtone,turn),sunlit,light_face);
		DIFFUSE_LIGHT += mix(shade,paint,smoothstep(.39,.61,ATTENUATION));
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR * (.45/PI) * ATTENUATION * smoothstep(-.04,.17,facing);
	}
}
