shader_type canvas_item;

// Atmospheric turbulence: gentle UV distortion driven by a single uniform.
// Used on planet/moon sprites - stars and nebulae/galaxies do not use this
// shader (see observation_effects_spec.md "按天体类型分派").
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float w = turbulence * 0.005;
	uv.x += (sin(uv.y * 42.0 + TIME * 3.3) + 0.6 * sin(uv.y * 11.0 - TIME * 1.9)) * w;
	uv.y += cos(uv.x * 31.0 + TIME * 2.4) * w * 0.7;
	vec4 c = texture(TEXTURE, uv);
	COLOR = c * COLOR;
}
