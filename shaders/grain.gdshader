shader_type canvas_item;

// Quality "grain" overlay: replaces the old white-dot noise dots with a
// shimmering per-pixel grain masked to the scope circle. intensity is
// driven by the current quality tier and smoothly chased by the caller.
// Mask uses the rect's own UV (the ColorRect is exactly the 436x436 box
// around the scope circle) - FRAGCOORD-based masking proved unreliable.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + floor(TIME * 24.0)) * 43758.5453);
}

void fragment() {
	float d = distance(UV, vec2(0.5));
	float mask = 1.0 - smoothstep(0.481, 0.5, d);
	float g = rnd(floor(UV * 436.0)) - 0.5;
	COLOR = vec4(vec3(0.55, 0.62, 0.75), abs(g) * intensity * mask);
}
