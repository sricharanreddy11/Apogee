shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

varying float opacity;

void vertex() {
	opacity = COLOR.a;
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec2 position = UV / pixel;
	float cycle = mod(TIME, 1.25);
	float burst = 1.0 - step(0.24, cycle);

	// Short bursts shift only a few horizontal bands at a time.
	float band = floor(position.y / 4.0);
	float noise = fract(sin(band * 43.17 + floor(TIME * 18.0)) * 4375.85);
	float shift = burst * step(0.62, noise) * (noise - 0.8) * 28.0;
	vec2 sample_uv = (floor(vec2(position.x + shift, position.y)) + 0.5) * pixel;

	float mark = texture(TEXTURE, sample_uv).a;
	float ghost = texture(TEXTURE, sample_uv + vec2(3.0 * pixel.x, 0.0)).a;
	float glow = 0.25 * (
		texture(TEXTURE, sample_uv + vec2(2.0, 0.0) * pixel).a +
		texture(TEXTURE, sample_uv - vec2(2.0, 0.0) * pixel).a +
		texture(TEXTURE, sample_uv + vec2(0.0, 2.0) * pixel).a +
		texture(TEXTURE, sample_uv - vec2(0.0, 2.0) * pixel).a
	);
	float scanline = 1.0 - 0.18 * step(0.55, fract(position.y * 0.5));
	float sweep = 1.0 - smoothstep(0.0, 9.0, abs(position.y - mod(TIME * 31.0, 110.0) + 11.0));

	vec3 phosphor = vec3(0.79, 0.88, 1.0);
	float halo = max(glow * 0.5, ghost * (0.12 + burst * 0.18));
	vec3 halo_color = vec3(0.25, 0.58, 0.72);
	vec3 face = phosphor * scanline * (0.93 + 0.07 * sweep);
	COLOR = vec4(mix(halo_color * halo, face, mark), mix(halo, 1.0, mark)) * opacity;
}
