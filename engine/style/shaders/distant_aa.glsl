#[compute]
#version 450
// Reproject distant paint at native resolution. The history alpha holds eye
// depth in metres. The second dispatch publishes RGB after all neighbour reads.
layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D scene;
layout(set = 0, binding = 1) uniform sampler2D depths;
layout(set = 0, binding = 2) uniform sampler2D motion;
layout(set = 0, binding = 3) uniform sampler2D history;
layout(rgba16f, set = 0, binding = 4) uniform image2D next_frame;
layout(push_constant, std430) uniform Params {
	vec4 projection; // zw from columns 2 and 3 of the device projection
	float weight;
	float publish;
	vec2 padding;
} params;

// Separable cubic reconstruction. Pair the two central samples on each axis
// with hardware interpolation and omit the four low-weight corner taps.
vec3 previous_color(vec2 uv, vec2 size) {
	vec2 pixel = uv * size - 0.5;
	vec2 f = fract(pixel);
	vec2 left = -0.5 * f * (1.0 - f) * (1.0 - f);
	vec2 right = -0.5 * (1.0 - f) * f * f;
	vec2 middle = 1.0 - left - right;
	vec2 centre = floor(pixel) + 0.5;
	vec2 mid = centre + f * (0.5 + f * (2.0 - 1.5 * f)) / middle;
	vec3 sum = textureLod(history, mid / size, 0.0).rgb * middle.x * middle.y;
	sum += textureLod(history, vec2(centre.x - 1.0, mid.y) / size, 0.0).rgb * left.x * middle.y;
	sum += textureLod(history, vec2(centre.x + 2.0, mid.y) / size, 0.0).rgb * right.x * middle.y;
	sum += textureLod(history, vec2(mid.x, centre.y - 1.0) / size, 0.0).rgb * middle.x * left.y;
	sum += textureLod(history, vec2(mid.x, centre.y + 2.0) / size, 0.0).rgb * middle.x * right.y;
	return sum / (1.0 - (left.x + right.x) * (left.y + right.y));
}

float eye_depth(float device_z) {
	vec4 p = params.projection;
	return (p.z - device_z * p.w) / (p.x - device_z * p.y);
}

// Protect the near side of a multisampled edge, including its partially
// covered pixels. Resolved MSAA depth and motion both diminish with partial
// coverage, so sample them together from the foreground side of the edge.
ivec2 nearest_surface(ivec2 xy, ivec2 last, float centre_z, out float edge_depth) {
	const ivec2 taps[4] = {ivec2(-1,0), ivec2(1,0), ivec2(0,-1), ivec2(0,1)};
	float nearest_z = centre_z;
	ivec2 nearest = xy;
	for (int i = 0; i < 4; i++) {
		ivec2 q = clamp(xy + taps[i], ivec2(0), last);
		float z = texelFetch(depths, q, 0).r;
		if (z > nearest_z) {
			nearest_z = z;
			nearest = q;
		}
	}
	edge_depth = nearest_z > 0.0 ? eye_depth(nearest_z) : 0.0;
	return nearest;
}

float depth_agreement(vec2 previous_pixel, float depth, float speed, ivec2 last) {
	float old_depth = texelFetch(history, ivec2(previous_pixel), 0).a;
	float mismatch = abs(old_depth - depth) / depth;
	if (mismatch > 0.03 && speed < 4.0) {
		// At a silhouette the old reconstruction footprint contains both
		// surfaces. Nearest-depth rejection alone drops a thin blade every
		// time its centre sample changes coverage.
		ivec2 corner = ivec2(floor(previous_pixel - 0.5));
		for (int i = 0; i < 4; i++) {
			ivec2 q = clamp(corner + ivec2(i & 1, i >> 1), ivec2(0), last);
			float tap = texelFetch(history, q, 0).a;
			mismatch = min(mismatch, abs(tap - depth) / depth);
		}
		// A subpixel crossing can uncover all four samples. The current
		// colour neighbourhood still bounds its contribution below.
		mismatch *= smoothstep(0.35, 2.0, speed);
	}
	return 1.0 - smoothstep(0.03, 0.12, mismatch);
}

void main() {
	ivec2 xy = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(scene);
	if (any(greaterThanEqual(xy, size))) return;
	vec4 current = imageLoad(scene, xy);
	if (params.publish > 0.5) {
		imageStore(scene, xy, vec4(imageLoad(next_frame, xy).rgb, current.a));
		return;
	}

	float z = texelFetch(depths, xy, 0).r;
	float depth = z > 0.0 ? min(eye_depth(z), 65504.0) : 65504.0;
	ivec2 last = size - 1;
	float edge_depth = depth;
	ivec2 motion_xy = xy;
	if (depth > 8.0 && params.weight > 0.0) {
		ivec2 nearest = nearest_surface(xy, last, z, edge_depth);
		if (z == 0.0 && nearest != xy) {
			// The first covered neighbour can itself be only a quarter sample.
			ivec2 inside = clamp(nearest + (nearest - xy), ivec2(0), last);
			float inside_z = texelFetch(depths, inside, 0).r;
			if (inside_z > texelFetch(depths, nearest, 0).r) {
				nearest = inside;
				edge_depth = eye_depth(inside_z);
			}
		}
		if (z == 0.0 || edge_depth < depth * 0.92) motion_xy = nearest;
	}
	float weight = params.weight * smoothstep(8.0, 24.0, edge_depth);
	if (weight > 0.0) {
		vec2 velocity = texelFetch(motion, motion_xy, 0).xy;
		vec2 old_uv = (vec2(xy) + 0.5) / vec2(size) + velocity;
		float speed = length(velocity * vec2(size));
		weight *= smoothstep(0.004, 0.06, speed) * (1.0 - smoothstep(4.0, 16.0, speed));
		if (weight > 0.0 && all(greaterThanEqual(old_uv, vec2(0.0))) && all(lessThan(old_uv, vec2(1.0)))) {
			weight *= depth_agreement(old_uv * vec2(size), depth, speed, last);
			if (weight > 0.0) {
				// A newly revealed flat face must recover its own paint immediately.
				vec3 a = imageLoad(scene, min(xy + ivec2(1, 0), last)).rgb;
				vec3 b = imageLoad(scene, max(xy - ivec2(1, 0), ivec2(0))).rgb;
				vec3 c = imageLoad(scene, min(xy + ivec2(0, 1), last)).rgb;
				vec3 d = imageLoad(scene, max(xy - ivec2(0, 1), ivec2(0))).rgb;
				vec3 low = min(current.rgb, min(min(a,b), min(c,d)));
				vec3 high = max(current.rgb, max(max(a,b), max(c,d)));
				current.rgb = mix(current.rgb, clamp(previous_color(old_uv, vec2(size)), low, high), weight);
			}
		}
	}
	imageStore(next_frame, xy, vec4(current.rgb, depth));
}
