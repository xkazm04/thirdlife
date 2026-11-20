shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, skip_vertex_transform, cull_disabled, fog_disabled;

// A tipped plane through the player. The near rail can fall out of focus at
// the foot of the frame while a hand or beam at the same height stays clear.
// Godot's final optical pass also reaches glass, water and particles.
uniform sampler2D scene : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depths : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec2 subject = vec2(8.0, 0.0); // optical depth, eye-space height (m)
uniform float tilt;
uniform float near_px;
uniform float far_px;
uniform float vista_near; // outer limit of the untracked foreground, in metres
varying float slope;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
	// Keep the slice attached to the tabletop as the camera pitches down.
	// Limit the lean at steep angles so the whole figure fits in focus.
	float pitch = asin(clamp(INV_VIEW_MATRIX[2].y, -1.0, 1.0));
	slope = tan(clamp(atan(tilt) - pitch, -0.91, 0.91));
}

vec3 view_point(vec2 uv, float z, mat4 inv) {
	vec4 p = inv * vec4(uv*2.0-1.0, z, 1.0);
	return p.xyz / p.w;
}

void fragment() {
	float z = textureLod(depths, SCREEN_UV, 0.0).r;
	if (z <= 0.0) { discard; } // leave the painted cyclorama to the final optical pass
	vec3 centre = view_point(SCREEN_UV, z, INV_PROJECTION_MATRIX);
	float gap = (-centre.z - subject.x) - slope*(centre.y - subject.y);
	float clear_near = max(1.15, subject.x*0.19);
	float clear_far = max(3.4, subject.x*0.48);
	float near_blur = smoothstep(clear_near, max(clear_near+0.75, subject.x*0.73), -gap);
	float far_blur = smoothstep(clear_far, clear_far+max(19.0,subject.x*3.2), gap);
	float radius = (near_px*near_blur + far_px*far_blur)*VIEWPORT_SIZE.y/1080.0;
	if (subject.x < 0.0) {
		// A scenic camera has no target. Rack only the low foreground:
		// a close-up on the optical axis and a distant crane stay clear.
		float below = smoothstep(1.6, 4.2, -centre.y);
		float close = 1.0 - smoothstep(vista_near*0.42, vista_near, -centre.z);
		radius = near_px*0.67*below*close*VIEWPORT_SIZE.y/1080.0;
	}
	if (radius < 0.30) { discard; }

	vec2 step_uv = radius/VIEWPORT_SIZE;
	vec3 total = textureLod(scene, SCREEN_UV, 0.0).rgb;
	float sum = 1.0;
	// Deterministic aperture samples. Reject the sharp actor when gathering
	// background colour, so a red jacket never bleeds onto a distant post.
	for (int i = 0; i < 10; i++) {
		float a = float(i)*2.39996323;
		vec2 uv = SCREEN_UV + step_uv*sqrt((float(i)+0.5)/10.0)*vec2(cos(a),sin(a));
		float w = 1.0;
		if (subject.x > 0.0 && gap > clear_far) {
			vec3 tap = view_point(uv, textureLod(depths,uv,0.0).r, INV_PROJECTION_MATRIX);
			float tap_gap = (-tap.z-subject.x) - slope*(tap.y-subject.y);
			w = smoothstep(0.0, clear_far, tap_gap);
		}
		total += textureLod(scene,uv,0.0).rgb * w;
		sum += w;
	}
	ALBEDO = total/sum;
	ALPHA = smoothstep(0.30, 0.85, radius);
}
