shader_type canvas_item;
// Era-change sequence (docs/ERA_FEEL_UI.md): over the new era's screen, the parts the new look
// has not reached yet are shown in the old era's look (its resolution and colour levels, or
// the four Era I inks). A bright line marks where the map is being redrawn.
// style: 1 colour spreads from a point, 2 the whole screen sharpens and zooms out a little,
// 3 the map unrolls from the middle, 4 a breathing wave runs down the screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int style = 1;
uniform vec2 old_res = vec2(144.0, 256.0);
uniform float old_levels = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 0.5625;
uniform vec4 c0 : source_color = vec4(0.165, 0.118, 0.173, 1.0);
uniform vec4 c1 : source_color = vec4(0.416, 0.259, 0.337, 1.0);
uniform vec4 c2 : source_color = vec4(0.769, 0.541, 0.369, 1.0);
uniform vec4 c3 : source_color = vec4(0.949, 0.890, 0.761, 1.0);

vec3 old_look(vec2 uv) {
	vec2 cell = (floor(uv * old_res) + 0.5) / old_res;
	vec3 src = texture(screen_tex, cell).rgb;
	if (old_levels < 1.0) {
		float l = dot(src, vec3(0.299, 0.587, 0.114));
		return l < 0.25 ? c0.rgb : (l < 0.5 ? c1.rgb : (l < 0.75 ? c2.rgb : c3.rgb));
	}
	return floor(src * old_levels + 0.5) / old_levels;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Signed distance to the redraw front: below 0 is already the new look.
	float d = 1.0;
	if (style == 1) {
		vec2 p = (uv - center) * vec2(1.0, 1.0 / aspect);
		d = length(p) - progress * 2.4;
	} else if (style == 2) {
		d = progress < 1.0 ? 1.0 : -1.0;
	} else if (style == 3) {
		d = abs(uv.y - 0.5) - progress * 0.56;
	} else {
		d = uv.y - progress * 1.15 + 0.035 * sin(uv.x * 22.0 + TIME * 5.0);
	}
	vec3 col;
	if (style == 2) {
		// Lines sharpen: the old resolution steps up to the new one while the view eases out.
		vec2 z = center + (uv - center) * (1.0 - 0.05 * (1.0 - progress));
		vec2 res = mix(old_res * 0.5, old_res * 4.0, progress * progress);
		vec2 cell = (floor(z * res) + 0.5) / res;
		vec3 src = texture(screen_tex, cell).rgb;
		float lv = mix(max(old_levels, 2.0), 32.0, progress);
		col = mix(floor(src * lv + 0.5) / lv, texture(screen_tex, z).rgb, smoothstep(0.75, 1.0, progress));
		if (old_levels < 1.0 && progress < 0.4) {
			col = mix(old_look(z), col, progress / 0.4);
		}
	} else {
		col = d < 0.0 ? texture(screen_tex, uv).rgb : old_look(uv);
		float edge = 1.0 - smoothstep(0.0, 0.012, abs(d));
		col = mix(col, vec3(1.0, 1.0, 0.94), edge * 0.8);
	}
	COLOR = vec4(col, 1.0);
}
