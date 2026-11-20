shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, skip_vertex_transform, cull_disabled, fog_disabled;

// A small soft foot shadow on the receiving surface, applied before glass
// and effects. The palette shader supplies its own ambient illumination.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normals : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec3 ao_color : source_color;
uniform float ao_radius = 0.66;
uniform float ao_k = 0.65;
uniform float ao_far = 64.0;
global uniform vec4 g_sun_dir;
uniform bool tabletop = false;
uniform float tabletop_reach = 3.6;
uniform float tabletop_opacity = 0.47;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 view_point(vec2 uv, mat4 inv) {
	vec4 p = inv * vec4(uv*2.0-1.0, textureLod(depth_tex,uv,0.0).r, 1.0);
	return p.xyz/p.w;
}

// Seen from above, the depth image is a height field of the pieces on the
// table. Estimate how much of a broad lamp they hide. Sample densely at the
// receiver, where a blade or a post makes its tightest contact.
float table_ray(vec3 p, vec3 dir, mat4 proj, mat4 inv, float phase) {
	vec4 start = proj * vec4(p, 1.0);
	vec4 end = proj * vec4(p + tabletop_reach*dir, 1.0);
	float shade = 0.0;
	for (int i = 0; i < 12; i++) {
		float u = (float(i) + 0.45 + phase)/12.0;
		float t = u*(0.46 + 0.54*u);
		vec4 clip = mix(start, end, t);
		vec2 uv = clip.xy/clip.w*0.5 + 0.5;
		if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { break; }
		float z = textureLod(depth_tex, uv, 0.0).r;
		float eye_z = (inv[2][2]*z + inv[3][2])/(inv[2][3]*z + inv[3][3]);
		float reach = t*tabletop_reach;
		float rise = eye_z - (p.z + dir.z*reach);
		float blocked = smoothstep(0.035 - 0.17*reach, 0.13 + 0.45*reach, rise);
		shade = max(shade, blocked*(1.0 - smoothstep(0.12, 1.0, t)));
	}
	return shade;
}

void fragment() {
	vec3 p = view_point(SCREEN_UV, INV_PROJECTION_MATRIX);
	float depth = -p.z;
	float shadow = 0.0;
	if (tabletop) {
		// A higher, wider source on the key side of the table gives the
		// projected cast its shape. The sunset still lights the paint.
		vec3 level = vec3(g_sun_dir.x, 0.0, g_sun_dir.z);
		level /= max(0.0001, length(level));
		vec3 lamp = level + vec3(0.0, 1.33, 0.0);
		vec3 side = cross(vec3(0.0, 1.0, 0.0), level);
		for (int j = 0; j < 3; j++) {
			vec3 dir = mat3(VIEW_MATRIX)*normalize(lamp + side*((float(j)-1.0)*0.29));
			shadow += table_ray(p, dir, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, fract(float(j)*0.382)-0.4);
		}
		shadow *= tabletop_opacity/3.0;
	} else if (depth < ao_far) {
		vec3 n = normalize(textureLod(normals,SCREEN_UV,0.0).xyz*2.0-1.0);
		vec2 radius_uv = ao_radius*0.5 * vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]) / max(depth, 0.1);
		// Fixed pairs on three rings. Centres on the same plane contribute zero.
		// The close ring tucks under a boot, the outer two ease the edge into grass.
		for (int i = 0; i < 12; i++) {
			float angle = float(i)*2.39996323;
			float radius = 0.21 + 0.36*float(i%3);
			vec2 uv = SCREEN_UV + vec2(cos(angle),sin(angle))*radius_uv*radius;
			vec3 delta = view_point(uv, INV_PROJECTION_MATRIX)-p;
			float dist = length(delta);
			float above = max(dot(n,delta)-0.008, 0.0)/max(dist,0.001);
			shadow += smoothstep(0.08,0.82,above) * (1.0-smoothstep(ao_radius*0.33,ao_radius*1.32,dist));
		}
		shadow = (1.0-exp(-shadow*0.32)) * ao_k * (1.0-smoothstep(ao_far*0.6,ao_far,depth));
	}
	ALBEDO = ao_color;
	ALPHA = shadow;
}
