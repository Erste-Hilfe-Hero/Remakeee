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
// Fixed hue turn (turns) for a cycling kind under reduced motion, which then has cycle 0.
uniform float phase = 0.0;
// Rarer kinds: a three-stop ramp (dark, mid, light) and an accent colour for the brightest
// pixels (luma above accent_from; 2.0 = off). true_colours: see gleam_palette.gdshader.
uniform vec4 ramp_mid : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float accent_from = 2.0;
uniform bool true_colours = false;
varying vec4 vertex_colour;

void vertex() {
	vertex_colour = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = shift * 6.28318530718;
	if (cycle != 0.0) {
		a += fract(TIME * cycle) * 6.28318530718;
	}
	a += phase * 6.28318530718;
	vec3 k = vec3(0.57735026919);
	c.rgb = clamp(c.rgb * cos(a) + cross(k, c.rgb) * sin(a) + k * dot(k, c.rgb) * (1.0 - cos(a)), 0.0, 1.0);
	if (ramp_mix > 0.0) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec3 ramp = l < 0.5 ? mix(ramp_dark.rgb, ramp_mid.rgb, l * 2.0) : mix(ramp_mid.rgb, ramp_light.rgb, (l - 0.5) * 2.0);
		ramp = l >= accent_from ? accent.rgb : ramp;
		c.rgb = mix(c.rgb, ramp, ramp_mix);
	}
	COLOR = c * (true_colours ? vertex_colour : COLOR);
}
