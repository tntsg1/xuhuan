shader_type canvas_item;

// Circular occluder drawn above target, stars and clouds. Decorative rings
// now come exclusively from the supplied transparent scope overlay; this
// shader only prevents drifting content from escaping the optical field.

void fragment() {
	float r = length((UV - vec2(0.5)) * 900.0);
	float outside_alpha = smoothstep(216.0, 219.0, r);
	COLOR = vec4(0.004, 0.006, 0.014, outside_alpha);
}
