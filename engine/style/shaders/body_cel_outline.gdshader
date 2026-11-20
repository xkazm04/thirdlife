shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
#include "res://style/shaders/body_cel_plot.gdshaderinc"

uniform vec3 ink : source_color = vec3(.117,.058,.102);

void vertex() {
	mat4 plot = figure_plot(MODEL_MATRIX[3].xyz,VERTEX);
	mat4 mv = VIEW_MATRIX * plot * MODEL_MATRIX;
	vec4 pos = mv * vec4(VERTEX,1.0);
	vec3 n = normalize(mat3(VIEW_MATRIX) * mat3(plot) * MODEL_NORMAL_MATRIX * NORMAL);
	// Three pixels on the bigger play poses. Cap world width on the far
	// side of the rink so a skate, a thumb or a buckle keeps its colour.
	float clip_w = (PROJECTION_MATRIX*pos).w;
	float metres_per_pixel = 2.0*max(clip_w,.01)/(1080.0*PROJECTION_MATRIX[1][1]);
	float width = min(2.35*metres_per_pixel,.011);
	pos.xyz += n*width;
	// Keep neighbouring ink behind the painted surface at shallow joins.
	pos.z -= width*.46;
	POSITION = PROJECTION_MATRIX * pos;
	if (IN_SHADOW_PASS || (tl_clip.x > 0.0 && length(MODEL_MATRIX[3].xz) > tl_clip.x)) {
		POSITION = vec4(0.0,0.0,0.0,1.0);
	}
}

void fragment() {
	ALBEDO = ink;
	ROUGHNESS = .5;
}
