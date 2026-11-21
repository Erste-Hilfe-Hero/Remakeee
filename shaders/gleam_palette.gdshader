shader_type canvas_item;
// Gleam form: maps the four Era I inks of a Spirling sprite onto its species' Gleam palette
// (data/gleam_palettes.json, set by GleamRules.material()).

uniform vec4 src0 : source_color = vec4(0.165, 0.118, 0.173, 1.0);
uniform vec4 src1 : source_color = vec4(0.416, 0.259, 0.337, 1.0);
uniform vec4 src2 : source_color = vec4(0.769, 0.541, 0.369, 1.0);
uniform vec4 src3 : source_color = vec4(0.949, 0.890, 0.761, 1.0);
uniform vec4 dst0 : source_color = vec4(0.165, 0.118, 0.173, 1.0);
uniform vec4 dst1 : source_color = vec4(0.416, 0.259, 0.337, 1.0);
uniform vec4 dst2 : source_color = vec4(0.769, 0.541, 0.369, 1.0);
uniform vec4 dst3 : source_color = vec4(0.949, 0.890, 0.761, 1.0);

bool same(vec3 a, vec3 b) {
	return distance(a, b) < 0.03;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (same(c.rgb, src0.rgb)) {
		c.rgb = dst0.rgb;
	} else if (same(c.rgb, src1.rgb)) {
		c.rgb = dst1.rgb;
	} else if (same(c.rgb, src2.rgb)) {
		c.rgb = dst2.rgb;
	} else if (same(c.rgb, src3.rgb)) {
		c.rgb = dst3.rgb;
	}
	COLOR = c * COLOR;
}
