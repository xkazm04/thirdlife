shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
// A hall's ice sheet (K6, hockey port): thirdjam's M_Ice as its clay tier runs it (ClayIceB19, ClayIceB23), lit by the
// hall's rig (hall_rig.gdshaderinc). Ported node by node; lengths are thirdjam's centimetres on its rink axes:
//   B19IceMask  scratches (two layers of the scratch map and a slot / boards / centre zone), snow along the boards,
//               the painted lines (the centre line and the blue lines 60 cm, the goal lines 12 cm, the centre circle
//               of 9 m radius 16 cm), softened by line_soft_cm;
//   B19IceBase  the body colour, the lines under the surface (line_under of the body mixed in), scratches on top
//               (scratch_lift), snow;
//   B23IceFx    the four key spots' pool on the ice, the contact shade at the board foot, the warm band along the boards;
//   B23IceBase  the body under the pools (pool_tint by pool_dim), the contact shade (contact_k);
//   B23IceEmis  the warm band (the lit boards in the ice) and one broad soft sheen a lamp (twelve lamps), by Fresnel.
// Not ported: the screen-space reflections thirdjam's rig switches on for the ice (the hall mirrored in it), the
// scratch map's normal (it only bends those reflections).
// The figures' shadow: the lights the rig lists first (`rig_keys`) are the ones that cast shadows; what they add is
// written as ALBEDO and taken away where the style's sun (TLStyleHall: straight down) is shadowed, the rest as emission.
// K7 (round 3): with key_shadows 1 each key light's own shadow map is read instead (TLStyleHallKeys), see light().
#include "hall_rig.gdshaderinc"
#include "hall_plot.gdshaderinc"
uniform sampler2D scratch : filter_linear_mipmap, repeat_enable;   // r, g = scratches, b = a slow noise
uniform float scratch_on = 0.0;
uniform float rink_hl = 4500.0;
uniform float rink_hw = 2250.0;
uniform float corner_r = 375.0;
uniform float goal_off = 400.0;
uniform float blue_frac = 0.3333;
uniform float layout_hl = 4500.0;
uniform float scratch_tile = 400.0;
uniform float scratch_amt = 0.55;
uniform float scratch_slot = 1.0;
uniform float scratch_far = 0.6;
uniform float scratch_lift = 0.28;
uniform float snow_w = 120.0;
uniform float snow_amt = 0.3;
uniform float line_soft = 3.0;
uniform float line_under = 0.15;
uniform vec3 body = vec3(0.32, 0.42, 0.97);
uniform vec3 scratch_colour = vec3(0.92, 0.94, 0.97);
uniform vec3 snow_colour = vec3(0.92, 0.93, 0.95);
uniform vec3 line_red = vec3(0.55, 0.06, 0.06);
uniform vec3 line_blue = vec3(0.08, 0.16, 0.55);
uniform vec2 pool_key_x = vec2(1125.0, 3375.0);
uniform float pool_key_z = 1300.0;
uniform float pool_inner_deg = 16.0;
uniform float pool_outer_deg = 58.0;
uniform vec3 pool_tint = vec3(0.72, 0.72, 0.74);
uniform float pool_dim = 1.0;
uniform float contact_cm = 14.0;
uniform float contact_k = 0.6;
uniform float band_cm = 400.0;
uniform float band_k = 3.6;
uniform vec3 band_colour = vec3(1.0, 0.52, 0.24);
uniform vec3 lamp_a = vec3(1125.0, 3375.0, 1300.0);
uniform vec3 lamp_b = vec3(3000.0, 1350.0, 1150.0);
uniform vec4 sheen = vec4(1.3, 0.14, 1.6, 1.0);
uniform vec3 sheen_colour = vec3(1.0, 0.55, 0.25);
uniform float spec = 1.0;
uniform float shadow_share = 1.0;      // how much of the key lights the style sun's shadow takes away
uniform float key_shadows = 0.0;       // K7 (TLStyleHallKeys): 1 = each key light's own shadow is read, not the style sun's
uniform float key_cone_cos = -1.0;     // K7: the cosine of the cone a key's shadow map covers; outside it that key's light is not shadowed
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (any(notEqual(tl_plot, vec4(0.0)))) {
		mat4 pm = tl_plot_mat();
		MODELVIEW_MATRIX = VIEW_MATRIX * pm * MODEL_MATRIX;
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(pm) * MODEL_NORMAL_MATRIX;
	}
}

void fragment() {
	vec2 p = vec2(wpos.x, wpos.z) * 100.0;
	// B19IceMask
	vec2 hq = abs(p) - vec2(rink_hl - corner_r, rink_hw - corner_r);
	float din = -(length(max(hq, vec2(0.0))) + min(max(hq.x, hq.y), 0.0) - corner_r);
	float ax = abs(p.x);
	float goal_x = rink_hl - goal_off;
	float sx = (ax - (goal_x - 650.0)) / 900.0;
	float sy = p.y / 750.0;
	float slot = exp(-(sx * sx + sy * sy));
	float cc = exp(-dot(p, p) / (700.0 * 700.0));
	float boards = 1.0 - smoothstep(0.0, 500.0, din);
	float zone = clamp(slot + 0.6 * boards + 0.5 * cc, 0.0, 1.0);
	float fw = max(fwidth(p.x), fwidth(p.y));
	float mk_s = 0.0;
	float mk_snow = 0.0;
	if (scratch_on > 0.5) {
		float tile = max(scratch_tile, 50.0);
		vec2 uv1 = p / tile;
		vec2 r2 = vec2(p.x * 0.9205 - p.y * 0.3907, p.x * 0.3907 + p.y * 0.9205);
		vec2 uv2 = r2 / (tile * 2.37) + vec2(0.31, 0.77);
		vec4 a = texture(scratch, uv1);
		vec4 b = texture(scratch, uv2);
		float u = texture(scratch, p / (tile * 9.3) + vec2(0.13, 0.41)).b;
		float dens = mix(0.35, 1.25, u);
		float sa = max(a.r, b.r * 0.85) * dens;
		float sb = texture(scratch, uv1 * 1.73 + vec2(0.5, 0.2)).g * mix(0.15, 1.0, zone) * scratch_slot * 1.4;
		float far = clamp((fw - 0.6) / 4.0, 0.0, 1.0);
		mk_s = clamp((sa + sb) * scratch_amt, 0.0, 1.0) * mix(1.0, scratch_far, far);
		float n = texture(scratch, p / 137.0).b;
		float sw = snow_w * (0.55 + 0.9 * n);
		float snow = (1.0 - smoothstep(0.0, sw, din)) * step(0.0, din);
		mk_snow = clamp(snow * (0.55 + 0.6 * n) + 0.35 * b.g * snow, 0.0, 1.0) * snow_amt;
	}
	float inside = step(abs(p.y), rink_hw);
	float blue_x = rink_hl * blue_frac;
	float sf = max(line_soft, fw);
	float red = max(1.0 - smoothstep(30.0 - sf, 30.0 + sf, ax), 1.0 - smoothstep(6.0 - sf, 6.0 + sf, abs(ax - goal_x))) * inside;
	float blue = max(1.0 - smoothstep(30.0 - sf, 30.0 + sf, abs(ax - blue_x)), 1.0 - smoothstep(8.0 - sf, 8.0 + sf, abs(length(p) - 900.0))) * inside;
	// B19IceBase
	vec3 c = body;
	c = mix(c, mix(line_blue, body, line_under), blue);
	c = mix(c, mix(line_red, body, line_under), red);
	c = mix(c, scratch_colour, clamp(mk_s * scratch_lift, 0.0, 1.0));
	c = mix(c, snow_colour, mk_snow);
	// B23IceFx
	float s = max(rink_hl, 1.0) / max(layout_hl, 1.0);
	float h = pool_key_z * s;
	float ci = cos(radians(pool_inner_deg));
	float co = cos(radians(pool_outer_deg));
	float pool = 0.0;
	for (int i = 0; i < 4; i++) {
		float kx = (i == 0) ? -pool_key_x.y : ((i == 1) ? -pool_key_x.x : ((i == 2) ? pool_key_x.x : pool_key_x.y));
		vec2 d = p - vec2(kx * s, 0.0);
		float cq = h / sqrt(dot(d, d) + h * h);
		float f = clamp((cq - co) / max(ci - co, 1e-3), 0.0, 1.0);
		pool += cq * cq * cq * f * f;
	}
	pool = clamp(pool, 0.0, 1.0);
	float dd = max(din, 0.0);
	float contact = exp(-dd / max(contact_cm * s, 0.5)) * step(0.0, din);
	float band = exp(-dd / max(band_cm * s, 1.0)) * step(0.0, din);
	// B23IceBase
	c *= mix(vec3(1.0), pool_tint, pool * pool_dim);
	c *= 1.0 - contact_k * contact;
	// B23IceEmis (its `In`, the bulb strings' reflection, is switched off in the shipped instance: BulbReflB22 0)
	vec3 v = normalize(wpos - CAMERA_POSITION_WORLD);
	float cosv = clamp(-v.y, 0.0, 1.0);
	float f0 = 0.08 * spec;
	float fr = f0 + (1.0 - f0) * pow(1.0 - cosv, 5.0);
	vec3 em = band_colour * (band_k * band * fr * (1.0 - mk_snow * 0.7));
	if (sheen.x > 0.0) {
		vec3 rm = reflect(v, vec3(0.0, 1.0, 0.0));
		vec3 uv = normalize(vec3(0.0, 1.0, 0.0) - rm * rm.y);
		vec3 sv = cross(rm, uv);
		float sh = 0.0;
		float ss = max(sheen.y, 0.01);
		float su = ss * max(sheen.z, 0.1);
		for (int i = 0; i < 12; i++) {
			int col = i - (i / 4) * 4;
			float lx = (col == 0) ? -lamp_a.y : ((col == 1) ? -lamp_a.x : ((col == 2) ? lamp_a.x : lamp_a.y));
			float ly = (i < 4) ? 0.0 : ((i < 8) ? -lamp_b.y : lamp_b.y);
			float lz = (i < 4) ? lamp_a.z : lamp_b.z;
			vec3 d = vec3(lx, lz, ly) * (s * 0.01) - wpos;       // metres, our axes
			float tb = dot(d, rm);
			if (tb <= 0.01) { continue; }
			float pu = dot(d, uv) / tb;
			float ps = dot(d, sv) / tb;
			sh += exp(-0.5 * (pu * pu / (su * su) + ps * ps / (ss * ss)));
		}
		em += sheen_colour * min(sheen.x * sh * fr, sheen.w) * (1.0 - mk_snow);
	}
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 keys = rig_lux_part(wpos, up, 0, rig_keys);
	vec3 rest = rig_lux_part(wpos, up, rig_keys, rig_n);
	vec3 total = hall_tone((c * (keys + rest) / PI + em) * rig_exposure);
	vec3 shaded = hall_tone((c * (keys * (1.0 - shadow_share) + rest) / PI + em) * rig_exposure);
	ALBEDO = max(total - shaded, vec3(0.0));
	ROUGHNESS = 1.0;
	EMISSION = shaded;
	// K7 begin (round 4): a key's shadow map covers a cone narrower than its light (finer texels where its light counts);
	// outside that cone the key's share is given back here, unshadowed, and light() leaves it out
	if (key_shadows > 0.5 && rig_keys > 0) {
		float sum = 0.0;
		float open_share = 0.0;
		for (int i = 0; i < rig_keys; i++) {
			float e = dot(rig_lux_part(wpos, up, i, i + 1), vec3(0.2126, 0.7152, 0.0722));
			sum += e;
			open_share += dot(normalize(wpos - rig_pos[i].xyz), rig_dir[i].xyz) <= key_cone_cos ? e : 0.0;
		}
		EMISSION += ALBEDO * open_share / max(sum, 1e-6);
	}
	// K7 end
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		if (key_shadows < 0.5) {       // K7: this condition
			DIFFUSE_LIGHT += vec3(ATTENUATION);
		}
	}
	// K7 begin (TLStyleHallKeys): a key light of the rig as a real spot light; its ATTENUATION is its shadow alone. Which
	// key it is: the one this light's direction points at. Its shadow counts by that key's share of the keys' light here.
	else if (key_shadows > 0.5 && rig_keys > 0) {
		vec3 to_light = normalize(mat3(INV_VIEW_MATRIX) * LIGHT);
		vec3 up = vec3(0.0, 1.0, 0.0);
		float best_d = -2.0;
		float sum = 0.0;
		float mine = 0.0;
		for (int i = 0; i < rig_keys; i++) {
			float d = dot(to_light, normalize(rig_pos[i].xyz - wpos));
			float e = dot(rig_lux_part(wpos, up, i, i + 1), vec3(0.2126, 0.7152, 0.0722));
			sum += e;
			if (d > best_d) {
				best_d = d;
				mine = dot(normalize(wpos - rig_pos[i].xyz), rig_dir[i].xyz) <= key_cone_cos ? 0.0 : e;       // round 4: see fragment()
			}
		}
		DIFFUSE_LIGHT += vec3(clamp(ATTENUATION, 0.0, 1.0) * mine / max(sum, 1e-6));
	}
	// K7 end
}
