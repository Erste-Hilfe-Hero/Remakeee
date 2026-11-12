shader_type canvas_item;
// Iris warp of Eras IV and V (docs/ERA_FEEL_UI.md): everything outside a circle around the
// Wayfarer turns to ink while the circle closes.

uniform vec2 center = vec2(72.0, 128.0);
uniform vec2 size_px = vec2(144.0, 256.0);
uniform float radius = 300.0;
uniform vec4 ink : source_color = vec4(0.165, 0.118, 0.173, 1.0);

void fragment() {
	vec2 p = UV * size_px;
	COLOR = distance(floor(p), center) > radius ? ink : vec4(0.0);
}
