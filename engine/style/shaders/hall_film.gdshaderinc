// Unreal 5.9's film pipeline, whole (K7, hockey port, round 3): what thirdjam's picture goes through between the scene's
// linear colour and the screen. hall_rig.gdshaderinc's `hall_tone` is the same curve per channel on sRGB primaries;
// this is the rest of it, which is what gives a saturated blue its hue in the game (red as high as green):
//   PostProcessCombineLUTs.usf:372-403  to ACEScg (AP1); bright saturated colours expanded (ExpandGamut 1); the post
//     volume's gain, and its shadows' gain under a luma of 0.09 (ColorCorrectAll; its saturation and contrast are left
//     to the screen grade, where the hall has them);
//   PostProcessCombineLUTs.usf:160-190  blue correction 0.6, the film curve, blue correction back, to sRGB;
//   TonemapCommon.ush FilmToneMap      the glow and the red modifier in AP0, pre-desaturation 0.96, the curve per
//     channel in AP1 (slope 0.88, toe 0.55, shoulder 0.26, black clip 0, white clip 0.04), post-desaturation 0.93.
// The matrices are Unreal's (ACES/ACESCommon.ush), multiplied out by tools/look_tone_check.py's own tables.
// Include after hall_rig.gdshaderinc (it reads rig_gain and rig_gain_shadows). A neutral grey comes out as from hall_tone.
const mat3 FILM_SRGB_2_AP1 = mat3(vec3(0.6130974024, 0.0701937225, 0.0206155929), vec3(0.3395231461, 0.9163538791, 0.1095697729), vec3(0.0473794514, 0.0134523986, 0.8698146341));
const mat3 FILM_AP1_2_SRGB = mat3(vec3(1.7050509926, -0.1302564175, -0.0240033568), vec3(-0.6217921205, 1.1408047365, -0.1289689761), vec3(-0.0832588722, -0.0105483190, 1.1529723328));
const mat3 FILM_EXPAND = mat3(vec3(1.3704123718, -0.0834334917, -0.0257933209), vec3(-0.3292921877, 1.0970927480, -0.0986257988), vec3(-0.0636831194, -0.0108613795, 1.2036949526));
const mat3 FILM_BLUE = mat3(vec3(0.9386393778, 0.0000000000, -0.0000000000), vec3(0.0000000001, 0.8307941330, 0.0000000000), vec3(0.0613606221, 0.1692058671, 1.0000000001));
const mat3 FILM_BLUE_INV = mat3(vec3(1.0653748755, -0.0000003456, 0.0000000198), vec3(0.0000014467, 1.2036635245, 0.0000000212), vec3(-0.0653710053, -0.2036677199, 0.9999996001));
const mat3 FILM_AP1_2_AP0 = mat3(vec3(0.6954522414, 0.0447945634, -0.0055258826), vec3(0.1406786965, 0.8596711185, 0.0040252103), vec3(0.1638690622, 0.0955343182, 1.0015006723));
const mat3 FILM_AP0_2_AP1 = mat3(vec3(1.4514393161, -0.0765537734, 0.0083161484), vec3(-0.2365107469, 1.1762296998, -0.0060324498), vec3(-0.2149285693, -0.0996759264, 0.9977163014));
const vec3 FILM_Y = vec3(0.2722287168, 0.6740817658, 0.0536895174);       // AP1_RGB2Y

float film_curve(float x) {
	const float SLOPE = 0.88;
	const float TOE_SCALE = 0.45;
	const float SHOULDER_SCALE = 0.78;
	const float TOE_MATCH = -0.390283;
	const float STRAIGHT_MATCH = 0.901647;
	const float SHOULDER_MATCH = -0.606192;
	float lc = log(max(x, 1e-10)) * 0.4342944819;
	float straight = SLOPE * (lc + STRAIGHT_MATCH);
	float toe = lc < TOE_MATCH ? (2.0 * TOE_SCALE) / (1.0 + exp((-2.0 * SLOPE / TOE_SCALE) * (lc - TOE_MATCH))) : straight;
	float shoulder = lc > SHOULDER_MATCH ? 1.04 - (2.0 * SHOULDER_SCALE) / (1.0 + exp((2.0 * SLOPE / SHOULDER_SCALE) * (lc - SHOULDER_MATCH))) : straight;
	float t = 1.0 - clamp((lc - TOE_MATCH) / (SHOULDER_MATCH - TOE_MATCH), 0.0, 1.0);
	t = (3.0 - 2.0 * t) * t * t;
	return mix(toe, shoulder, t);
}

// FilmToneMap: AP1 in, AP1 out
vec3 film_tone_map(vec3 ap1) {
	vec3 ap0 = FILM_AP1_2_AP0 * ap1;
	float mn = min(min(ap0.r, ap0.g), ap0.b);
	float mx = max(max(ap0.r, ap0.g), ap0.b);
	float sat = (max(mx, 1e-10) - max(mn, 1e-10)) / max(mx, 1e-2);
	// the "glow" module (gain 0.05, mid 0.08)
	float yc = (ap0.b + ap0.g + ap0.r + 1.75 * sqrt(max(ap0.b * (ap0.b - ap0.g) + ap0.g * (ap0.g - ap0.r) + ap0.r * (ap0.r - ap0.b), 0.0))) / 3.0;
	float sx = (sat - 0.4) / 0.2;
	float st = max(1.0 - abs(0.5 * sx), 0.0);
	float gain_in = 0.05 * 0.5 * (1.0 + sign(sx) * (1.0 - st * st));
	float glow = yc <= 2.0 / 3.0 * 0.08 ? gain_in : (yc >= 0.16 ? 0.0 : gain_in * (0.08 / yc - 0.5));
	ap0 *= 1.0 + glow;
	// the red modifier (scale 0.82, pivot 0.03, hue 0, width 135 degrees)
	float hue = (ap0.r == ap0.g && ap0.g == ap0.b) ? 0.0 : degrees(atan(sqrt(3.0) * (ap0.g - ap0.b), 2.0 * ap0.r - ap0.g - ap0.b));
	float hw = smoothstep(0.0, 1.0, 1.0 - abs(2.0 * hue / 135.0));       // atan gives -180..180: the centred hue already
	ap0.r += hw * hw * sat * (0.03 - ap0.r) * (1.0 - 0.82);
	vec3 w = max(FILM_AP0_2_AP1 * ap0, vec3(0.0));
	w = mix(vec3(dot(w, FILM_Y)), w, 0.96);
	vec3 c = vec3(film_curve(w.r), film_curve(w.g), film_curve(w.b));
	return max(mix(vec3(dot(c, FILM_Y)), c, 0.93), vec3(0.0));
}

// Scene-linear sRGB, already exposed, to the screen's linear sRGB.
vec3 hall_film(vec3 x) {
	vec3 ap1 = FILM_SRGB_2_AP1 * max(x, vec3(0.0));
	float luma = dot(ap1, FILM_Y);
	vec3 chroma = ap1 / max(luma, 1e-10) - vec3(1.0);
	float expand = (1.0 - exp2(-4.0 * dot(chroma, chroma))) * (1.0 - exp2(-4.0 * luma * luma));
	ap1 = mix(ap1, FILM_EXPAND * ap1, expand);
	float shadows = 1.0 - smoothstep(0.0, 0.09, dot(ap1, FILM_Y));
	ap1 *= rig_gain * mix(vec3(1.0), rig_gain_shadows, shadows);
	ap1 = mix(ap1, FILM_BLUE * ap1, 0.6);
	ap1 = film_tone_map(ap1);
	ap1 = mix(ap1, FILM_BLUE_INV * ap1, 0.6);
	return clamp(FILM_AP1_2_SRGB * ap1, vec3(0.0), vec3(1.0));
}
