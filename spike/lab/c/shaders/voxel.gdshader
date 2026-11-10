shader_type spatial;
render_mode cull_back;
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
	vec3 fw3 = fwidth(v_lpos) / vs;
	float fw = max(fw3.x, max(fw3.y, fw3.z));
	float fade = 1.0 - smoothstep(0.12, 0.45, fw);
	// sub-voxel 4x4 texel noise (minecraft-ish)
	vec2 sub = floor(inp * 4.0);
	float tn = hash13(vec3(cell.x + sub.x * 0.37, cell.y + sub.y * 0.41, cell.z + 17.0 * an.y + 5.0 * an.z)) - 0.5;
	col *= 1.0 + tn * tex_amt * 2.0 * fade;
	// edge darkening on voxel borders (reads as the voxel grid)
	vec2 ed = min(inp, 1.0 - inp);
	float e = min(ed.x, ed.y);
	float edge = 1.0 - smoothstep(0.0, bevel, e);
	col *= 1.0 - edge * edge_amt * fade;
	// vertex ao
	float ao = mix(1.0 - ao_strength, 1.0, v_ao * v_ao * (3.0 - 2.0 * v_ao));
	// dissolve (site_advance)
	float emit_add = 0.0;
	if (reveal < 1.0 || inv) {
		float hh = hash13(cell * 1.7 + vec3(3.1, 9.2, 4.4));
		float key = 0.72 * hh + 0.28 * clamp(v_lpos.y / reveal_h, 0.0, 1.0);
		if (inv ? (key <= reveal) : (key > reveal)) discard;
		emit_add = smoothstep(reveal - 0.10, reveal, key);
	}
	col = mix(col, tint_col * col, tint_mix);
	ALBEDO = col;
	ROUGHNESS = pr.r;
	METALLIC = pr.g;
	AO = ao;
	AO_LIGHT_AFFECT = 0.45;
	EMISSION = col * pr.b * 8.0 + reveal_col * emit_add * 2.5;
}
