// Shared voxel shading: palette ramp per material, per-voxel hash variation, sub-voxel texel noise, edge bevel.
uniform sampler2D pal : filter_nearest, repeat_disable;     // RAMP_N x NMAT, linear colour
uniform sampler2D props : filter_nearest, repeat_disable;   // 1 x NMAT : rough, metal, emit/8, alpha
uniform float vs = 0.25;
uniform float edge_amt = 0.11;
uniform float tex_amt = 0.045;
uniform float ao_strength = 0.62;
uniform float bevel = 0.16;
uniform float ramp_n = 5.0;
uniform float reveal = 1.0;
uniform bool inv = false;
uniform float reveal_h = 14.0;
uniform vec3 reveal_col = vec3(0.2, 0.9, 1.0);
uniform float tint_mix = 0.0;
uniform vec3 tint_col = vec3(1.0);

varying vec3 v_lpos;
varying flat vec3 v_lnor;
varying flat float v_mat;
varying float v_ao;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}
