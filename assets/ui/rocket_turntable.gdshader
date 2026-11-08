shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV) * COLOR;
	float sweep = sin(TIME * 0.3);
	float lighting = 0.76 + 0.22 * cos((UV.x - 0.5) * 3.14 - sweep);
	float rim = pow(max(0.0, 1.0 - abs(UV.x - (0.18 + sweep * 0.13)) * 7.0), 4.0);
	sprite.rgb = sprite.rgb * lighting + vec3(0.25, 0.65, 0.75) * rim * 0.22;
	COLOR = sprite;
}
