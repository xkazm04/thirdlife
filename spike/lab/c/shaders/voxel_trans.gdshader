shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_always;
#include "res://shaders/voxel_common.gdshaderinc"

void vertex() {
	v_lpos = VERTEX;
	v_lnor = NORMAL;
	v_mat = CUSTOM0.r * 255.0;
	v_ao = CUSTOM0.g;
}

void fragment() {
	int m = int(floor(v_mat + 0.5));
	vec3 cellp = (v_lpos - v_lnor * 0.5 * vs) / vs;
	vec3 cell = floor(cellp + vec3(0.001));
	vec3 f = cellp - cell;
	float h = hash13(cell + vec3(float(m) * 7.13, float(m) * 3.71, float(m) * 1.37));
	int si = int(floor(h * ramp_n));
	vec3 col = texelFetch(pal, ivec2(si, m - 1), 0).rgb;
	vec4 pr = texelFetch(props, ivec2(0, m - 1), 0);
	vec3 an = abs(v_lnor);
	vec2 inp = an.x > 0.5 ? f.yz : (an.y > 0.5 ? f.xz : f.xy);
	vec2 ed = min(inp, 1.0 - inp);
	float e = min(ed.x, ed.y);
	float fw = max(fwidth(v_lpos.x), max(fwidth(v_lpos.y), fwidth(v_lpos.z))) / vs;
	float fade = 1.0 - smoothstep(0.12, 0.45, fw);
	float edge = 1.0 - smoothstep(0.0, bevel, e);
	ALBEDO = col * (1.0 - edge * edge_amt * 0.5 * fade);
	ALPHA = pr.a + edge * 0.10 * fade;
	ROUGHNESS = pr.r;
	METALLIC = pr.g;
	SPECULAR = 0.7;
	EMISSION = col * pr.b * 8.0;
}
