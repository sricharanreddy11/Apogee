shader_type canvas_item;
render_mode unshaded;

uniform sampler2D orbit_screen : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 curved = p * (1.0 + 0.023 * dot(p, p));
	vec2 glass_uv = curved * 0.5 + 0.5;
	vec2 span = SCREEN_PIXEL_SIZE / max(vec2(abs(dFdx(UV.x)), abs(dFdy(UV.y))), vec2(0.00001));
	vec2 read_at = SCREEN_UV + (glass_uv - UV) * span;
	vec3 signal = texture(orbit_screen, read_at).rgb;
	vec3 bleed = texture(orbit_screen, read_at + SCREEN_PIXEL_SIZE * vec2(2.0, 0.0)).rgb
		+ texture(orbit_screen, read_at - SCREEN_PIXEL_SIZE * vec2(2.0, 0.0)).rgb;
	float brightness = pow(max(dot(signal + bleed * 0.12, vec3(0.28, 0.57, 0.15)) - 0.035, 0.0), 0.82);
	float amber = smoothstep(0.12, 0.46, signal.r - signal.b);
	vec3 phosphor = mix(vec3(0.22, 0.99, 0.71), vec3(1.0, 0.80, 0.44), amber);
	float line = 0.91 + 0.09 * cos(FRAGCOORD.y * 2.45);
	float sweep = exp(-abs(UV.y - fract(TIME * 0.16)) * 52.0) * 0.045;
	vec2 glass_size_px = span / SCREEN_PIXEL_SIZE;
	float grid_step = max(glass_size_px.y / 8.0, 16.0);
	vec2 grid_uv = (glass_uv - 0.5) * glass_size_px / grid_step;
	vec2 grid_distance = abs(fract(grid_uv + 0.5) - 0.5);
	vec2 grid_width = max(fwidth(grid_uv), vec2(0.0001));
	vec2 ruled = 1.0 - smoothstep(grid_width * 0.15, grid_width * 0.95, grid_distance);
	float grid = max(ruled.x, ruled.y) * (1.0 - smoothstep(0.05, 0.32, brightness));
	float edge = 1.0 - 0.52 * smoothstep(0.44, 1.38, length(p));
	float glass = 1.0 - smoothstep(0.985, 1.02, max(abs(curved.x), abs(curved.y)));
	vec3 screen = vec3(0.006, 0.021, 0.019) + vec3(0.012, 0.045, 0.034) * grid;
	COLOR = vec4((screen + phosphor * (brightness * line + sweep)) * edge * glass, 1.0);
}
