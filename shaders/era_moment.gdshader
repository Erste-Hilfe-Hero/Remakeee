shader_type canvas_item;
// Era-change scene (EraChangeScene, docs/ERA_LOOK_TITLE.md). TEXTURE is the new era's title
// scene; this shows it the way the old era could draw it and lets the new look in step by step.
// palette_p: where the new colours have reached (each change has its own front):
//   style 1 ink runs into colour from three drops, 2 a scan line climbs down,
//   3 the picture unrolls from the middle like two screens opening, 4 light sweeps across.
// detail_p: resolution and colour depth step up from the old era's to the new era's
//   (style 1 has no new resolution: its tiles get their own colours one by one).

uniform float palette_p : hint_range(0.0, 1.0) = 0.0;
uniform float detail_p : hint_range(0.0, 1.0) = 0.0;
uniform int style = 1;
uniform vec2 old_res = vec2(144.0, 148.0);
uniform vec2 new_res = vec2(144.0, 148.0);
// Colour levels per channel of the old era (0 = the four inks) and before the detail step.
uniform float old_levels = 0.0;
uniform float mid_levels = 2.0;
uniform float steps = 4.0;
uniform vec4 c0 : source_color = vec4(0.165, 0.118, 0.173, 1.0);
uniform vec4 c1 : source_color = vec4(0.416, 0.259, 0.337, 1.0);
uniform vec4 c2 : source_color = vec4(0.769, 0.541, 0.369, 1.0);
uniform vec4 c3 : source_color = vec4(0.949, 0.890, 0.761, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 old_look(vec3 src) {
	if (old_levels < 1.0) {
		float l = dot(src, vec3(0.299, 0.587, 0.114));
		return l < 0.25 ? c0.rgb : (l < 0.5 ? c1.rgb : (l < 0.75 ? c2.rgb : c3.rgb));
	}
	return floor(src * old_levels + 0.5) / old_levels;
}

float front(vec2 uv, float aspect) {
	if (style == 1) {
		float d = 9.0;
		for (int i = 0; i < 3; i++) {
			vec2 c = vec2(0.22 + 0.3 * float(i), 0.3 + 0.22 * float((i * 2) % 3));
			vec2 p = (uv - c) * vec2(aspect, 1.0);
			float wob = 0.05 * sin(atan(p.y, p.x) * 5.0 + float(i) * 2.0);
			d = min(d, length(p) - (palette_p * 1.15 - 0.08 * float(i)) + wob);
		}
		return d;
	}
	if (style == 2) {
		return uv.y - palette_p * 1.04;
	}
	if (style == 3) {
		return abs(uv.y - 0.5) - palette_p * 0.54;
	}
	return (uv.x * 0.7 + uv.y * 0.3) - palette_p * 1.1 + 0.02 * sin(uv.y * 30.0);
}

void fragment() {
	float aspect = new_res.x / new_res.y;
	float stepped = floor(detail_p * steps + 0.001) / steps;
	vec2 res = mix(old_res, new_res, stepped);
	vec2 uv = detail_p >= 1.0 ? UV : (floor(UV * res) + 0.5) / res;
	vec3 src = texture(TEXTURE, uv).rgb;
	float d = front(uv, aspect);
	vec3 col = old_look(src);
	if (d < 0.0) {
		float full = step(1.0, detail_p);
		if (style == 1) {
			// Tile by tile: each 16 px tile gets its own colours when its turn comes.
			vec2 tile = floor(UV * new_res / 16.0);
			full = step(hash(tile), detail_p * 1.02 - 0.01);
		}
		float lv = mix(mid_levels, 32.0, stepped);
		col = mix(floor(src * lv + 0.5) / lv, src, full);
	} else if (d < 0.025) {
		col = mix(col, vec3(1.0, 1.0, 0.94), 0.75);
	}
	COLOR = vec4(col, 1.0);
}
