shader_type canvas_item;
// Gleam form: maps the four Era I inks of a Spirling sprite onto its species' Gleam palette
// (data/gleam_palettes.json, set by GleamRules.material()). "cycle" (turns per second, 0 = off)
// turns the hues over time for the shimmering Opaline kind; at 0 the output is the plain swap.

uniform vec4 src0 : source_color = vec4(0.165, 0.118, 0.173, 1.0);
uniform vec4 src1 : source_color = vec4(0.416, 0.259, 0.337, 1.0);
uniform vec4 src2 : source_color = vec4(0.769, 0.541, 0.369, 1.0);
uniform vec4 src3 : source_color = vec4(0.949, 0.890, 0.761, 1.0);
uniform vec4 dst0 : source_color = vec4(0.165, 0.118, 0.173, 1.0);
uniform vec4 dst1 : source_color = vec4(0.416, 0.259, 0.337, 1.0);
uniform vec4 dst2 : source_color = vec4(0.769, 0.541, 0.369, 1.0);
uniform vec4 dst3 : source_color = vec4(0.949, 0.890, 0.761, 1.0);
uniform float cycle = 0.0;

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
	if (cycle != 0.0) {
		float a = fract(TIME * cycle) * 6.28318530718;
		vec3 k = vec3(0.57735026919);
		c.rgb = clamp(c.rgb * cos(a) + cross(k, c.rgb) * sin(a) + k * dot(k, c.rgb) * (1.0 - cos(a)), 0.0, 1.0);
	}
	COLOR = c * COLOR;
}
