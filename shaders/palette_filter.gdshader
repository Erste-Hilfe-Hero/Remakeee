shader_type canvas_item;
// Retro filter: maps the screen's luminance onto a fixed 4-colour palette (Era I "Mono").
// Placeholder art can use any colours; this keeps the era look consistent.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 c0 : source_color = vec4(0.106, 0.165, 0.106, 1.0);
uniform vec4 c1 : source_color = vec4(0.243, 0.353, 0.227, 1.0);
uniform vec4 c2 : source_color = vec4(0.541, 0.659, 0.420, 1.0);
uniform vec4 c3 : source_color = vec4(0.831, 0.890, 0.710, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 src = texture(screen_tex, SCREEN_UV);
	float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	vec4 mapped = l < 0.25 ? c0 : (l < 0.5 ? c1 : (l < 0.75 ? c2 : c3));
	COLOR = vec4(mix(src.rgb, mapped.rgb, strength), 1.0);
}
