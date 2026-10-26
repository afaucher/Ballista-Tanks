// The sun at the cube's centre: unshaded, bright enough to bloom.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.86, 0.52);
uniform float energy = 4.0;

void fragment() {
	ALBEDO = color * energy;
}
