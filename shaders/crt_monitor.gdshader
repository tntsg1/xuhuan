shader_type canvas_item;

// Old-school CRT monitor post-process for the Space Infrared Observatory.
// Applied as a full-screen overlay that samples the screen behind it, so every
// panel, readout and image drawn underneath inherits the phosphor look.
//
// Effects, in the order a real tube produces them:
//   1. barrel distortion (the glass is curved)
//   2. slight RGB separation toward the edges (convergence error)
//   3. horizontal scanlines + vertical aperture grille
//   4. phosphor bloom (bright pixels smear into their neighbours)
//   5. vignette + corner darkening
//   6. a slow rolling refresh bar and faint flicker

uniform float curvature : hint_range(0.0, 8.0) = 5.6;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.20;
uniform float grille_strength : hint_range(0.0, 1.0) = 0.07;
uniform float bloom_strength : hint_range(0.0, 2.0) = 0.55;
uniform float chroma_offset : hint_range(0.0, 4.0) = 0.55;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.30;
uniform float flicker_strength : hint_range(0.0, 0.5) = 0.035;
uniform float roll_strength : hint_range(0.0, 0.5) = 0.05;
uniform float brightness : hint_range(0.5, 2.0) = 1.34;
uniform vec3 phosphor_tint = vec3(0.97, 0.99, 1.00);
uniform float monochrome : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// Curve the flat screen coordinates onto a tube face.
vec2 curve_uv(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / curvature;
	uv = uv + uv * offset * offset;
	return uv * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV);

	// Outside the tube face: solid bezel black.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE;

		// Convergence error grows toward the edges of the tube.
		float edge = length(uv - vec2(0.5)) * chroma_offset;
		vec2 shift = vec2(px.x * edge, 0.0);
		float r = texture(screen_tex, uv + shift).r;
		float g = texture(screen_tex, uv).g;
		float b = texture(screen_tex, uv - shift).b;
		vec3 col = vec3(r, g, b);
		// single-phosphor tube: everything becomes one luminance channel
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(lum), monochrome);

		// Phosphor bloom: sample a small cross and keep only the bright part.
		vec3 blur = vec3(0.0);
		blur += texture(screen_tex, uv + vec2(px.x * 2.0, 0.0)).rgb;
		blur += texture(screen_tex, uv - vec2(px.x * 2.0, 0.0)).rgb;
		blur += texture(screen_tex, uv + vec2(0.0, px.y * 2.0)).rgb;
		blur += texture(screen_tex, uv - vec2(0.0, px.y * 2.0)).rgb;
		blur *= 0.25;
		col += max(blur - 0.30, vec3(0.0)) * bloom_strength;

		// Scanlines (horizontal) and aperture grille (vertical triads).
		float line = sin(uv.y / max(px.y, 0.0001) * 3.14159);
		col *= 1.0 - scanline_strength * (0.5 + 0.5 * line * line * -1.0 + 1.0) * 0.5;
		float grille = 0.5 + 0.5 * cos(uv.x / max(px.x, 0.0001) * 2.0943951);
		col *= 1.0 - grille_strength * grille;

		// Slow rolling refresh bar.
		float roll = fract(uv.y + TIME * 0.06);
		col *= 1.0 - roll_strength * smoothstep(0.97, 1.0, roll);

		// Mains flicker.
		col *= 1.0 - flicker_strength * (0.5 + 0.5 * sin(TIME * 47.0));

		// Phosphor tint + vignette.
		col *= phosphor_tint * brightness;
		vec2 v = uv * (1.0 - uv.yx);
		float vig = pow(clamp(v.x * v.y * 22.0, 0.0, 1.0), vignette_strength);
		col *= vig;

		COLOR = vec4(col, 1.0);
	}
}
