shader_type canvas_item;
// Era IV and V overworld view (docs/ERA_FEEL_UI.md): the map is seen at a slight tilt, so rows
// near the bottom of the screen come closer and widen while the top stays as it is - the 2.5D
// feel of the dual-screen handheld era. tilt 0 is the flat top-down view.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float tilt = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float near = uv.y * uv.y;
	float scale = 1.0 - tilt * near;
	vec2 s = vec2(0.5 + (uv.x - 0.5) * scale, uv.y - tilt * 0.25 * near);
	COLOR = vec4(texture(screen_tex, s).rgb, 1.0);
}
