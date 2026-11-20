shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, skip_vertex_transform, cull_disabled, fog_disabled;

// A narrow aperture for the miniature landscape. Only mix immediate neighbours
// on the same distant surface. A pine tip or crane wire keeps its silhouette.
uniform sampler2D scene : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depths : hint_depth_texture, filter_nearest, repeat_disable;
uniform float start_m = 105.0;
uniform float transition_m = 190.0;
uniform float strength = 0.2;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float eye_depth(float z, mat4 inv) {
	return -(inv[2][2]*z + inv[3][2]) / (inv[2][3]*z + inv[3][3]);
}

void fragment() {
	float z = textureLod(depths, SCREEN_UV, 0.0).r;
	float depth = eye_depth(z, INV_PROJECTION_MATRIX);
	if (z <= 0.0 || depth <= start_m) { discard; }
	vec3 total = vec3(0.0);
	float count = 0.0;
	const vec2 offsets[4] = { vec2(1,0), vec2(-1,0), vec2(0,1), vec2(0,-1) };
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offsets[i]/VIEWPORT_SIZE;
		float nz = textureLod(depths, uv, 0.0).r;
		float gap = abs(eye_depth(nz, INV_PROJECTION_MATRIX) - depth);
		float weight = nz > 0.0 ? 1.0-smoothstep(0.01*depth, 0.04*depth, gap) : 0.0;
		total += weight*textureLod(scene, uv, 0.0).rgb;
		count += weight;
	}
	ALBEDO = total/max(count, 0.0001);
	ALPHA = 0.25*count*strength*smoothstep(start_m, start_m+transition_m, depth);
}
