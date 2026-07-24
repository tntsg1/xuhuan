shader_type canvas_item;
render_mode unshaded;

uniform vec3 night_tint : source_color = vec3(0.52, 0.64, 0.80);
uniform float exposure : hint_range(0.0, 1.5) = 0.68;
uniform float saturation : hint_range(0.0, 1.5) = 0.72;
uniform float alpha_floor : hint_range(0.0, 0.25) = 0.025;
uniform float edge_luma_limit : hint_range(0.05, 1.0) = 0.58;
uniform float warm_light_keep : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec4 vertex_color = COLOR;
	vec4 source = texture(TEXTURE, UV);
	float clean_alpha = smoothstep(alpha_floor, alpha_floor + 0.055, source.a);
	float source_luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 desaturated = mix(vec3(source_luma), source.rgb, saturation);
	vec3 graded = desaturated * night_tint * exposure;

	// Preserve compact amber lamps while cooling the broad daylight surfaces.
	float warm = smoothstep(0.04, 0.30, source.r - source.b)
		* smoothstep(0.12, 0.58, source_luma)
		* smoothstep(0.42, 0.88, source.a);
	graded = mix(graded, source.rgb * exposure, warm * warm_light_keep);

	// Bright RGB left in partially transparent edge pixels creates white halos.
	// Limit only those edge pixels; opaque snow, metal and lamps remain intact.
	float edge = (1.0 - smoothstep(0.40, 0.92, source.a))
		* smoothstep(edge_luma_limit, 1.0, source_luma);
	float edge_scale = min(1.0, edge_luma_limit / max(source_luma, 0.001));
	graded *= mix(1.0, edge_scale, edge * 0.88);

	COLOR = vec4(graded, clean_alpha) * vertex_color;
}
