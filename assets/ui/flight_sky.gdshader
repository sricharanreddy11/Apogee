shader_type canvas_item;
render_mode unshaded;

uniform float atmosphere : hint_range(0.0, 1.0) = 0.0;
uniform float slipstream : hint_range(0.0, 1.0) = 0.0;

float hash_cell(vec2 id) {
	return fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 space = mix(vec3(0.004, 0.007, 0.014), vec3(0.012, 0.019, 0.031), UV.y);
	vec3 zenith = vec3(0.018, 0.084, 0.19);
	vec3 horizon = mix(vec3(0.32, 0.66, 0.89), vec3(0.48, 0.66, 0.92), slipstream);
	vec3 sky = mix(zenith, horizon, pow(UV.y, 1.45));
	vec2 cells = UV * vec2(120.0, 78.0);
	float random = hash_cell(floor(cells));
	vec2 center = vec2(0.32 + random * 0.35, 0.3 + fract(random * 9.1) * 0.4);
	float star = (1.0 - smoothstep(0.035, 0.18, length(fract(cells) - center)))
		* smoothstep(0.982, 0.999, random);
	space += vec3(0.67, 0.79, 0.95) * star * 0.72;
	COLOR = vec4(mix(space, sky, atmosphere), 1.0);
}
