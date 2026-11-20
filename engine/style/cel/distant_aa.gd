extends CompositorEffect
## Native-resolution history for the distant cel contours. WorldEnvironment owns
## the effect, and the viewport owns the two images through RenderSceneBuffersRD.
const BUFFER := &"tl_cel_distant_aa"
const A := &"history_a"
const B := &"history_b"
const KERNEL := preload("res://style/shaders/distant_aa.glsl")

var strength := 0.0
var owner_id := 0
var device: RenderingDevice
var shader: RID
var pipeline: RID
var nearest: RID
var linear: RID
var used_buffers: Dictionary[int,WeakRef] = {}


func _init() -> void:
	owner_id = get_instance_id()
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	needs_motion_vectors = true


func _prepare() -> void:
	device = RenderingServer.get_rendering_device()
	shader = device.shader_create_from_spirv(KERNEL.get_spirv())
	if not shader.is_valid():
		return
	pipeline = device.compute_pipeline_create(shader)
	var sampling := RDSamplerState.new()
	nearest = device.sampler_create(sampling)
	sampling.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampling.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear = device.sampler_create(sampling)


func _uniform(binding: int, texture: RID, sampler: RID = RID()) -> RDUniform:
	var u := RDUniform.new()
	u.binding = binding
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	if sampler.is_valid():
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u.add_id(sampler)
	u.add_id(texture)
	return u


func _render_callback(_type: int, data: RenderData) -> void:
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0 or size != buffers.get_target_size() or buffers.get_use_taa() \
			or buffers.get_scaling_3d_mode() in [RenderingServer.VIEWPORT_SCALING_3D_MODE_FSR2,RenderingServer.VIEWPORT_SCALING_3D_MODE_METALFX_TEMPORAL]:
		if buffers.get_meta(BUFFER,{}).get("owner",0) == owner_id:
			buffers.clear_context(BUFFER)
			buffers.remove_meta(BUFFER)
		return
	if device == null:
		_prepare()
	if not pipeline.is_valid():
		return
	var scene := data.get_render_scene_data()
	var pose := scene.get_cam_transform()
	var projection := scene.get_cam_projection()
	var last: Dictionary = buffers.get_meta(BUFFER,{})
	if not used_buffers.has(buffers.get_instance_id()):
		for id: int in used_buffers.keys():
			if used_buffers[id].get_ref() == null:
				used_buffers.erase(id)
		used_buffers[buffers.get_instance_id()] = weakref(buffers)
	var allocated := buffers.has_texture(BUFFER,A)
	if not allocated:
		var usage := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		for key: StringName in [A,B]:
			buffers.create_texture(BUFFER,key,RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,usage,
					RenderingDevice.TEXTURE_SAMPLES_1,size,buffers.get_view_count(),1,false,false)
	# RenderSceneBuffersRD is per viewport. A cut, changed sampling mode or lens,
	# resize or new effect starts with the current image in both eyes.
	var history_weight := 0.0
	if allocated and last.get("owner",0) == owner_id:
		var prior: Transform3D = last.pose
		var travel := pose.origin.distance_to(prior.origin)
		if travel < 2.0 and pose.basis.z.dot(prior.basis.z) > 0.97 and projection == last.projection:
			# During fast translation, distant edges can have very small screen
			# velocities even as the view uncovers a new strip of terrain.
			history_weight = strength * lerpf(1.0,0.45,smoothstep(0.12,0.65,travel))
	var previous: StringName = last.get("output",A)
	var output := B if previous == A else A
	buffers.set_meta(BUFFER,{"owner":owner_id,"pose":pose,"projection":projection,"output":output})
	var constants := PackedFloat32Array([projection.z.z,projection.z.w,projection.w.z,projection.w.w,
			history_weight,0.0,0.0,0.0])
	for view in buffers.get_view_count():
		var uniforms: Array[RDUniform] = [
			_uniform(0,buffers.get_color_layer(view)), _uniform(1,buffers.get_depth_layer(view),nearest),
			_uniform(2,buffers.get_velocity_layer(view),nearest),
			_uniform(3,buffers.get_texture_slice(BUFFER,previous,view,0,1,1),linear),
			_uniform(4,buffers.get_texture_slice(BUFFER,output,view,0,1,1))]
		var set_id := UniformSetCacheRD.get_cache(shader,0,uniforms)
		var list := device.compute_list_begin()
		device.compute_list_bind_compute_pipeline(list,pipeline)
		device.compute_list_bind_uniform_set(list,set_id,0)
		for stage in 2:
			constants[5] = float(stage)
			device.compute_list_set_push_constant(list,constants.to_byte_array(),32)
			device.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1)
			if stage == 0:
				device.compute_list_add_barrier(list)
		device.compute_list_end()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(device):
		RenderingServer.call_on_render_thread(_release_history.bind(used_buffers.values(),owner_id))
		for id: RID in [shader,nearest,linear]:
			if id.is_valid():
				device.free_rid(id)


static func _release_history(references: Array[WeakRef], retired_id: int) -> void:
	for reference in references:
		var buffers := reference.get_ref() as RenderSceneBuffersRD
		if buffers != null and buffers.get_meta(BUFFER,{}).get("owner",0) == retired_id:
			buffers.clear_context(BUFFER)
			buffers.remove_meta(BUFFER)
