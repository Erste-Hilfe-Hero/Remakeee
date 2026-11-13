shader_type canvas_item;
// Spiral warp of Era III (docs/ERA_FEEL_TEXT.md): arms of ink wind in around the Wayfarer and
// grow until they close. progress 0 = clear, 1 = all ink.

uniform vec2 center = vec2(90.0, 160.0);
uniform vec2 size_px = vec2(180.0, 320.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float arms = 2.0;
uniform float turns = 1.5;
uniform vec4 ink : source_color = vec4(0.118, 0.102, 0.086, 1.0);

void fragment() {
	vec2 d = floor(UV * size_px) - center;
	float far = length(max(center, size_px - center));
	float r = clamp(length(d) / far, 0.0, 1.0);
	float a = atan(d.y, d.x) / 6.2831853 + 0.5;
	// Where along one arm's width this pixel sits; the arms turn as they grow.
	float s = fract(a * arms + r * turns * arms - progress * turns);
	// The rim fills first, the middle last.
	float fill = progress * 1.35 - (1.0 - r) * 0.35;
	COLOR = s < fill ? ink : vec4(0.0);
}
