shader_type canvas_item;
// Wayfarer look (Ali, 7 Nov): recolours the tamer sheet's hair, skin and coat pixels.
// Hair and coat share one sheet colour; the row inside each 16 px frame tells them apart.

uniform vec4 src_skin : source_color = vec4(0.949, 0.890, 0.761, 1.0);
uniform vec4 src_cloth : source_color = vec4(0.416, 0.259, 0.337, 1.0);
uniform vec4 skin : source_color = vec4(0.949, 0.890, 0.761, 1.0);
uniform vec4 hair : source_color = vec4(0.416, 0.259, 0.337, 1.0);
uniform vec4 coat : source_color = vec4(0.416, 0.259, 0.337, 1.0);
// Rows 0..hair_rows-1 of a frame are hair, the rest is the coat.
uniform float hair_rows = 3.0;

bool same(vec3 a, vec3 b) {
	return distance(a, b) < 0.02;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float row = mod(floor(UV.y / TEXTURE_PIXEL_SIZE.y), 16.0);
	if (same(c.rgb, src_skin.rgb)) {
		c.rgb = skin.rgb;
	} else if (same(c.rgb, src_cloth.rgb)) {
		c.rgb = row < hair_rows ? hair.rgb : coat.rgb;
	}
	COLOR = c * COLOR;
}
