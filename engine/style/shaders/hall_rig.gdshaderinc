// A hall's light rig evaluated in the shader (K6, hockey port; shared: whatever stands in the hall includes this file
// and is handed the same uniforms, see TLStyleArena.set_rig): up to 24 spot lights by their own numbers, summed per
// fragment, with no shadow. Each is Unreal's spot light as thirdjam's rig level has it: candela over the distance
// squared, the radius window (1 - (d / R)^4)^2, the cone's smooth edge ((cos - cos_outer) / (cos_inner - cos_outer))^2.
// A surface of albedo a shows  a * lux / PI  (+ what it emits), times `rig_exposure`, through `hall_tone`.
uniform int rig_n = 0;
uniform vec4 rig_pos[24];              // xyz = where it hangs (m, pack space), w = its radius (m)
uniform vec4 rig_dir[24];              // xyz = the way it looks, w = cos(outer cone)
uniform vec4 rig_col[24];              // rgb = its colour (linear) x candela, w = cos(inner cone)
uniform float rig_exposure = 0.0453;   // 1 / (1.2 * 2^EV100), times the tone gain
uniform float rig_wrap = 0.0;          // 0 = Lambert
// The rig's colour grade, before the film curve (Unreal's post volume: ColorGain for the whole picture, ColorGainShadows
// for what is darker than its shadows range, whose default upper end is 0.09).
uniform vec3 rig_gain = vec3(1.0);
uniform vec3 rig_gain_shadows = vec3(1.0);

// The lights `from` .. `to` - 1 alone (a rig lists the lights that cast shadows first: `rig_keys` of them).
uniform int rig_keys = 0;
vec3 rig_lux_part(vec3 p, vec3 n, int from, int to) {
	vec3 e = vec3(0.0);
	for (int i = from; i < to; i++) {
		vec3 d = p - rig_pos[i].xyz;
		float r = length(d);
		if (r >= rig_pos[i].w) { continue; }
		vec3 w = d / r;
		float cone = clamp((dot(w, rig_dir[i].xyz) - rig_dir[i].w) / max(rig_col[i].w - rig_dir[i].w, 1e-5), 0.0, 1.0);
		float win = clamp(1.0 - pow(r / rig_pos[i].w, 4.0), 0.0, 1.0);
		float ndl = clamp((dot(n, -w) + rig_wrap) / (1.0 + rig_wrap), 0.0, 1.0);
		e += rig_col[i].rgb * (cone * cone * win * win * ndl / (r * r));
	}
	return e;
}

vec3 rig_lux(vec3 p, vec3 n) {
	return rig_lux_part(p, n, 0, rig_n);
}

// The film curve the reference is shown through: Unreal's FilmToneMap (Engine/Shaders/Private/TonemapCommon.ush:176-225
// of UE 5.9) with the engine's default look, which thirdjam's rig does not override: slope 0.88, toe 0.55, shoulder
// 0.26, black clip 0, white clip 0.04. Its constants, as that source derives them:
//   ToeScale = 1 + 0 - 0.55 = 0.45, ShoulderScale = 1 + 0.04 - 0.26 = 0.78, bt = 0.18 / 0.45 - 1 = -0.6,
//   ToeMatch = log10(0.18) - 0.5 * ln((1 + bt) / (1 - bt)) * (0.45 / 0.88) = -0.390283,
//   StraightMatch = 0.45 / 0.88 - ToeMatch = 0.901647, ShoulderMatch = 0.26 / 0.88 - StraightMatch = -0.606192.
// Per channel on the colour as it is: Unreal runs it in the AP1 colour space after a glow and a red modifier, which
// are not ported; its pre-desaturation (0.96) and post-desaturation (0.93) are, on Rec. 709 luma.
vec3 hall_tone(vec3 x) {
	const float SLOPE = 0.88;
	const float TOE_SCALE = 0.45;
	const float SHOULDER_SCALE = 0.78;
	const float TOE_MATCH = -0.390283;
	const float STRAIGHT_MATCH = 0.901647;
	const float SHOULDER_MATCH = -0.606192;
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
	x = max(x, vec3(0.0)) * rig_gain;
	x *= mix(rig_gain_shadows, vec3(1.0), smoothstep(0.0, 0.09, dot(x, LUMA)));
	x = mix(vec3(dot(x, LUMA)), x, 0.96);
	vec3 lc = log(max(x, vec3(1e-10))) * 0.4342944819;       // log10
	vec3 straight = SLOPE * (lc + STRAIGHT_MATCH);
	vec3 toe = (2.0 * TOE_SCALE) / (1.0 + exp((-2.0 * SLOPE / TOE_SCALE) * (lc - TOE_MATCH)));
	vec3 shoulder = 1.04 - (2.0 * SHOULDER_SCALE) / (1.0 + exp((2.0 * SLOPE / SHOULDER_SCALE) * (lc - SHOULDER_MATCH)));
	toe = mix(straight, toe, step(lc, vec3(TOE_MATCH)));
	shoulder = mix(straight, shoulder, step(vec3(SHOULDER_MATCH), lc));
	vec3 t = 1.0 - clamp((lc - TOE_MATCH) / (SHOULDER_MATCH - TOE_MATCH), 0.0, 1.0);    // ShoulderMatch < ToeMatch: 1 - t
	t = (3.0 - 2.0 * t) * t * t;
	vec3 c = mix(toe, shoulder, t);
	c = mix(vec3(dot(c, LUMA)), c, 0.93);
	return clamp(c, 0.0, 1.0);
}
