shader_type canvas_item;

// Full-colour curved optical glass. This samples only the observation region
// behind the overlay; mission panels, labels and reticles are drawn above it.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 region_uv_size = vec2(0.615234375, 0.729166667);
uniform float curvature : hint_range(0.0, 0.15) = 0.035;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.14;
uniform float chroma_px : hint_range(0.0, 1.5) = 0.18;
uniform float glass_highlight : hint_range(0.0, 0.25) = 0.055;
uniform float circular_lens : hint_range(0.0, 1.0) = 0.0;

vec2 curved_uv(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	float r2 = dot(p, p);
	p *= 1.0 + curvature * r2;
	return p * 0.5 + 0.5;
}

void fragment() {
	vec2 warped = curved_uv(UV);
	vec2 sample_uv = SCREEN_UV + (warped - UV) * region_uv_size;
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);

	if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
		COLOR = vec4(0.002, 0.004, 0.010, 1.0);
	} else {
		float edge = mix(max(abs(p.x), abs(p.y)), radius, circular_lens);
		float edge_amount = smoothstep(0.52, 1.0, edge);
		vec2 chroma_shift = vec2(SCREEN_PIXEL_SIZE.x * chroma_px * edge_amount, 0.0);

		// Preserve the scene's actual colour. The tiny channel separation reads
		// as imperfect optics at the rim, not as a CRT or monochrome filter.
		float red = texture(screen_tex, sample_uv + chroma_shift).r;
		float green = texture(screen_tex, sample_uv).g;
		float blue = texture(screen_tex, sample_uv - chroma_shift).b;
		vec3 colour = vec3(red, green, blue);
		colour *= 1.0 - vignette_strength * edge_amount;

		// A restrained cold reflection near the upper-left edge gives the glass
		// volume without covering stars or turning the view into a bright blob.
		float reflection = exp(-18.0 * dot(p - vec2(-0.34, -0.38), p - vec2(-0.34, -0.38)));
		reflection *= smoothstep(0.15, 0.72, edge);
		colour += vec3(0.28, 0.52, 0.72) * reflection * glass_highlight;

		COLOR = vec4(colour, 1.0);
	}
}
