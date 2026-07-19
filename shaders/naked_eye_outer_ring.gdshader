shader_type canvas_item;

// Preserve the outer observation boundary and its cardinal ornaments while
// removing the two inner rings from the shared naked-eye source artwork.
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float radius = length(UV - vec2(0.5));
	if (radius < 0.385) {
		discard;
	}
	COLOR = color;
}
