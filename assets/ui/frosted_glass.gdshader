shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 tint : source_color = vec4(0.025, 0.065, 0.105, 0.78);
uniform float blur_radius = 4.0;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Explicit taps also work on the Compatibility renderer without mipmap blur.
	vec2 pixel = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 blurred = texture(screen_texture, SCREEN_UV).rgb * 0.20;
	blurred += texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)).rgb * 0.12;
	blurred += texture(screen_texture, SCREEN_UV - vec2(pixel.x, 0.0)).rgb * 0.12;
	blurred += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)).rgb * 0.12;
	blurred += texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y)).rgb * 0.12;
	blurred += texture(screen_texture, SCREEN_UV + pixel).rgb * 0.08;
	blurred += texture(screen_texture, SCREEN_UV - pixel).rgb * 0.08;
	blurred += texture(screen_texture, SCREEN_UV + vec2(pixel.x, -pixel.y)).rgb * 0.08;
	blurred += texture(screen_texture, SCREEN_UV + vec2(-pixel.x, pixel.y)).rgb * 0.08;
	float scan = sin(FRAGCOORD.y * 1.7) * 0.008;
	float flicker = (1.0 - reveal) * (0.035 + 0.035 * sin(TIME * 97.0));
	vec3 glass = mix(blurred, tint.rgb, tint.a) + scan + flicker;
	float edge = step(UV.x, 0.003) + step(0.997, UV.x) + step(UV.y, 0.018);
	glass += vec3(0.17, 0.48, 0.57) * min(edge, 1.0) * 0.35;
	COLOR = vec4(glass, 1.0) * COLOR;
}
