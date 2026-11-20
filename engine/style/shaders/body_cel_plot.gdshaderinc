instance uniform vec4 tl_plot = vec4(0.0);
instance uniform vec4 tl_clip = vec4(0.0);

// Both the colour and the back-face ink must follow the pack onto its plot.
// Clipped figures collapse in both the camera and the shadow pass.
mat4 figure_plot(vec3 origin, inout vec3 point) {
	float radius = length(origin.xz);
	float raise = 0.0;
	if (tl_clip.x > 0.0) {
		if (radius > tl_clip.x) {
			point = vec3(0.0);
		} else if (tl_clip.z > 0.0) {
			raise = (tl_clip.y-origin.y)*smoothstep(tl_clip.x-tl_clip.z,tl_clip.x,radius);
		}
	}
	float c = cos(tl_plot.w), s = sin(tl_plot.w);
	return mat4(vec4(c,0,-s,0),vec4(0,1,0,0),vec4(s,0,c,0),vec4(tl_plot.xyz+vec3(0,raise,0),1));
}
