// Launch and boost pads: glowing chevrons running along the pad's local -Z (the way it sends
// you), in object space so they work on any face. Period in metres.
shader_type spatial;

uniform vec3 color : source_color = vec3(1.0, 0.7, 0.15);
uniform float energy = 3.0;
uniform float period = 2.5;
uniform float speed = 1.2;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float v = fract((-lpos.z + abs(lpos.x)) / period - TIME * speed);
	float chev = smoothstep(0.0, 0.06, v) * (1.0 - smoothstep(0.4, 0.46, v));
	ALBEDO = color * 0.55;
	ROUGHNESS = 0.35;
	EMISSION = color * energy * mix(0.2, 1.0, chev);
}
