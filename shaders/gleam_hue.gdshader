shader_type canvas_item;
// Gleam form for sprites that are not drawn in the four Era I inks (tiers II to V): turns every
// hue by "shift" (in turns) around the grey axis, so the shading and outline tones stay
// (SpriteTiers.gleam_shift(), set by GleamRules.material()).
// Rarer Gleam kinds (data/gleam.json "tier") also pull every pixel toward a dark-to-light ramp by
// its brightness ("ramp_mix", 0 = off) and can turn the hues over time ("cycle", turns per
// second, 0 = off). With both at 0 the output is the plain hue turn of the classic Gleam.

uniform float shift = 0.5;
uniform vec4 ramp_dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 ramp_light : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ramp_mix = 0.0;
uniform float cycle = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = shift * 6.28318530718;
	if (cycle != 0.0) {
		a += fract(TIME * cycle) * 6.28318530718;
	}
	vec3 k = vec3(0.57735026919);
	c.rgb = clamp(c.rgb * cos(a) + cross(k, c.rgb) * sin(a) + k * dot(k, c.rgb) * (1.0 - cos(a)), 0.0, 1.0);
	if (ramp_mix > 0.0) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb = mix(c.rgb, mix(ramp_dark.rgb, ramp_light.rgb, l), ramp_mix);
	}
	COLOR = c * COLOR;
}
