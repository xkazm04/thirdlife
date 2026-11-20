extends CompositorEffect
## Short temporal resolve for the moving meadow. Keep the foreground at native
## resolution. In the distance, use motion vectors to gather the last view of
## the same surface. No projection jitter or full-frame temporal AA is needed.

const CONTEXT := &"diorama_horizon"
const SLOTS := [&"history_a", &"history_b"]
const USAGE := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
const COMPUTE := """
#version 450
layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0, rgba16f) uniform image2D scene;
layout(set = 0, binding = 1) uniform sampler2D motion;
layout(set = 0, binding = 2) uniform sampler2D depth;
layout(set = 0, binding = 3) uniform sampler2D previous;
layout(set = 0, binding = 4, rgba16f) writeonly uniform image2D next_frame;
layout(push_constant, std430) uniform Params {
	vec4 inverse_z; // z and w rows of the inverse projection, for a device depth
	vec4 history_params; // x = trust in the previous view
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(scene);
	if (any(greaterThanEqual(pixel, size))) return;
	vec4 current = imageLoad(scene, pixel);
	float z = texelFetch(depth, pixel, 0).r;
	float metres = -(params.inverse_z.x*z + params.inverse_z.y) / (params.inverse_z.z*z + params.inverse_z.w);
	float influence = params.history_params.x * (z == 0.0 ? 1.0 : smoothstep(24.0, 44.0, metres));
	float moving = 0.0;
	vec3 resolved = current.rgb;
	if (influence > 0.0) {
		vec2 shift = texelFetch(motion, pixel, 0).xy * vec2(size);
		vec2 last = vec2(pixel) + shift;
		if (all(lessThan(abs(shift), vec2(24))) && all(greaterThanEqual(last, vec2(0))) && all(lessThan(last, vec2(size - 1)))) {
			ivec2 origin = ivec2(floor(last + 0.5));
			vec2 f = last - vec2(origin);
			// Keep a stationary edge native. A moving ray covers part of the neighbouring
			// texels. These separable weights keep the centroid at the reprojected point.
			moving = smoothstep(0.04, 0.44, length(shift));
			vec2 width = vec2(0.29) + 0.23*f*f;
			vec2 low = mix(max(-f, vec2(0)), width - 0.5*f, moving);
			vec2 high = mix(max(f, vec2(0)), width + 0.5*f, moving);
			vec2 weights[3] = { low, 1.0-low-high, high };
			vec3 total = vec3(0);
			float support = 0.0;
			for (int y = -1; y <= 1; y++) {
				for (int x = -1; x <= 1; x++) {
					float w = weights[x+1].x * weights[y+1].y;
					if (w <= 0.0) continue;
					vec4 h = texelFetch(previous, clamp(origin + ivec2(x, y), ivec2(0), size-1), 0);
					float gap = abs(h.a - z) / max(max(h.a, z), 0.00001);
					w *= 1.0 - smoothstep(0.025, 0.12, gap);
					total += w*h.rgb;
					support += w;
				}
			}
			vec3 history = total / max(support, 0.00001);
			const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
			float change = abs(dot(history-current.rgb, luma)) / max(0.08, dot(history+current.rgb, luma));
			influence *= (1.0-smoothstep(0.26, 0.72, change)) * smoothstep(0.15, 0.80, support);
			resolved = mix(current.rgb, history, influence * mix(0.74, 0.88, moving));
		}
	}
	// The history carries at most 58% of the older colour at rest and 84% in motion.
	// Store current device depth so newly uncovered surfaces can reject it.
	imageStore(next_frame, pixel, vec4(mix(current.rgb, resolved, mix(0.78, 0.95, moving)), z));
	imageStore(scene, pixel, vec4(resolved, current.a));
}
"""

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	needs_motion_vectors = true


func _prepare() -> void:
	_rd = RenderingServer.get_rendering_device()
	var source := RDShaderSource.new()
	source.source_compute = COMPUTE
	var spirv := _rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():
		push_error("Diorama horizon resolve: " + spirv.compile_error_compute)
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if _shader.is_valid():
		_pipeline = _rd.compute_pipeline_create(_shader)
		_sampler = _rd.sampler_create(RDSamplerState.new())


func _binding(slot: int, texture: RID, sampled: bool) -> RDUniform:
	var u := RDUniform.new()
	u.binding = slot
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE if sampled else RenderingDevice.UNIFORM_TYPE_IMAGE
	if sampled:
		u.add_id(_sampler)
	u.add_id(texture)
	return u


func _render_callback(_kind: int, render_data: RenderData) -> void:
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var camera := render_data.get_render_scene_data()
	var projection := camera.get_cam_projection()
	if buffers.get_view_count() != 1 or buffers.get_use_taa() or buffers.get_scaling_3d_mode() == Viewport.SCALING_3D_MODE_FSR2 or projection.is_orthogonal():
		if buffers.has_texture(CONTEXT, SLOTS[0]):
			buffers.clear_context(CONTEXT)
		return
	if _rd == null:
		_prepare()
	if not _pipeline.is_valid():
		return
	var size := buffers.get_internal_size()
	var allocated := buffers.has_texture(CONTEXT, SLOTS[0])
	if not allocated:
		for slot: StringName in SLOTS:
			buffers.create_texture(CONTEXT, slot, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, USAGE,
				RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true, false)
	var slot := 1 - int(buffers.get_meta(&"_dio_history_slot", 1))
	var pose := camera.get_cam_transform()
	var last_pose: Transform3D = buffers.get_meta(&"_dio_last_pose", pose)
	var reuse := allocated and int(buffers.get_meta(&"_dio_history_owner", 0)) == get_instance_id()
	reuse = reuse and pose.basis.z.dot(last_pose.basis.z) > 0.985
	reuse = reuse and is_equal_approx(projection.y.y, float(buffers.get_meta(&"_dio_last_scale", projection.y.y)))
	# Far felt moves by fractions of a pixel on foot. During fast flight the
	# passing terrain needs its current native samples, including below the horizon.
	var travel := pose.origin.distance_to(last_pose.origin)
	var trust := 1.0 - smoothstep(0.15, 0.40, travel) if reuse else 0.0
	var uniforms: Array[RDUniform] = [
		_binding(0, buffers.get_color_layer(0), false),
		_binding(1, buffers.get_velocity_layer(0), true),
		_binding(2, buffers.get_depth_layer(0), true),
		_binding(3, buffers.get_texture(CONTEXT, SLOTS[1-slot]), true),
		_binding(4, buffers.get_texture(CONTEXT, SLOTS[slot]), false)]
	var bindings := UniformSetCacheRD.get_cache(_shader, 0, uniforms)
	var inv := projection.inverse()
	var params := PackedFloat32Array([inv.z.z, inv.w.z, inv.z.w, inv.w.w, trust, 0, 0, 0]).to_byte_array()
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _pipeline)
	_rd.compute_list_bind_uniform_set(list, bindings, 0)
	_rd.compute_list_set_push_constant(list, params, params.size())
	_rd.compute_list_dispatch(list, ceili(size.x/8.0), ceili(size.y/8.0), 1)
	_rd.compute_list_end()
	buffers.set_meta(&"_dio_history_slot", slot)
	buffers.set_meta(&"_dio_history_owner", get_instance_id())
	buffers.set_meta(&"_dio_last_pose", pose)
	buffers.set_meta(&"_dio_last_scale", projection.y.y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		if _sampler.is_valid():
			RenderingServer.call_on_render_thread(_rd.free_rid.bind(_sampler))
		if _shader.is_valid():
			RenderingServer.call_on_render_thread(_rd.free_rid.bind(_shader))
