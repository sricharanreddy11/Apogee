shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity = 0.0;
void fragment() {
	float edge = sin(UV.x * 3.14159265) * sin(UV.y * 3.14159265);
	vec2 ripple = vec2(sin(UV.y * 28.0 - TIME * 19.0), cos(UV.x * 17.0 + TIME * 11.0));
	vec3 scene = texture(screen_texture, SCREEN_UV + ripple * SCREEN_PIXEL_SIZE * edge * intensity * 2.0).rgb;
	COLOR = vec4(scene, edge * intensity * 0.4);
}
