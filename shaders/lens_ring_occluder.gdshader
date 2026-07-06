shader_type canvas_item;

// Ring occluder drawn ABOVE all in-lens content (target sprite, stars,
// clouds): transparent inside the 436px scope circle, repaints the barrel
// rings + view background outside it. This is what actually clips drifting
// targets to the eyepiece - without it a drifted sprite draws over the
// golden frame. Positioned as a 900x900 rect centered on the lens; mask
// math uses the rect's own UV (never FRAGCOORD).

void fragment() {
	float r = length((UV - vec2(0.5)) * 900.0);
	vec4 c;
	if (r < 215.0) {
		c = vec4(0.0);
	} else if (r < 218.0) {
		c = vec4(0.06, 0.08, 0.15, 1.0);   // inner circle border
	} else if (r < 246.0) {
		c = vec4(0.012, 0.018, 0.052, 1.0); // dark blue ring fill
	} else if (r < 252.0) {
		c = vec4(0.31, 0.23, 0.15, 1.0);    // bronze border
	} else if (r < 262.0) {
		c = vec4(0.05, 0.036, 0.026, 1.0);  // warm dark ring fill
	} else if (r < 270.0) {
		c = vec4(0.95, 0.76, 0.42, 1.0);    // golden barrel edge
	} else {
		c = vec4(0.004, 0.006, 0.014, 1.0); // view background
	}
	// Soften the inner cut so the circle edge doesn't alias.
	c.a *= smoothstep(213.0, 216.0, r);
	COLOR = c;
}
