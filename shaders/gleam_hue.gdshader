shader_type canvas_item;
// Gleam form for sprites that are not drawn in the four Era I inks (tiers II to V): turns every
// hue by "shift" (in turns) around the grey axis, so the shading and outline tones stay
// (SpriteTiers.gleam_shift(), set by GleamRules.material()).

uniform float shift = 0.5;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = shift * 6.28318530718;
	vec3 k = vec3(0.57735026919);
	c.rgb = clamp(c.rgb * cos(a) + cross(k, c.rgb) * sin(a) + k * dot(k, c.rgb) * (1.0 - cos(a)), 0.0, 1.0);
	COLOR = c * COLOR;
}
