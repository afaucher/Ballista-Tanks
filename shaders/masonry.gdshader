// Masonry: staggered blocks with mortar and bevels, triplanar in world space so it reads the same
// on floors, walls and ceilings (any face of the cube can be "down"). Block sizes are in metres.
// Look.stone() and Look.road() are this shader with different uniforms.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.6, 0.61, 0.64);
uniform vec3 mortar_color : source_color = vec3(0.38, 0.38, 0.4);
uniform vec2 block_size = vec2(2.0, 1.0);   // length along a course, course height (m)
uniform float mortar_width = 0.07;          // m
uniform float bevel = 0.22;                 // m from the mortar line to the flat face
uniform float bump = 0.06;                  // bevel depth (m) for the lighting
uniform float variation = 0.12;             // per-block brightness spread
uniform float warmth = 0.0;                 // per-block warm/cool tint spread
uniform float dome = 0.0;                   // 1 rounds each block into a cobble
uniform float roughness = 0.85;
uniform float sharpness = 6.0;              // triplanar blend falloff

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// One plane of blocks: x = distance to the nearest mortar line (m), y/z = per-block hashes,
// w = cobble dome height 0..1.
vec4 blocks(vec2 p) {
	float row = floor(p.y / block_size.y);
	// Staggered by a random amount per course, so it reads as laid stone rather than tiles.
	float off = (0.25 + 0.5 * hash12(vec2(row, 7.31))) * block_size.x;
	float col = floor((p.x + off) / block_size.x);
	vec2 local = vec2(p.x + off - col * block_size.x, p.y - row * block_size.y);
	vec2 d2 = min(local, block_size - local);
	vec2 c = (local / block_size) * 2.0 - 1.0;
	float domed = 1.0 - clamp(dot(c * c, vec2(0.6)), 0.0, 1.0);
	return vec4(min(d2.x, d2.y), hash12(vec2(col, row)), hash12(vec2(row * 1.7, col)), domed);
}

// Colour (rgb) and height (a) for one plane.
vec4 shade(vec4 b, vec2 p) {
	float half_m = mortar_width * 0.5;
	// Fade the mortar and bevels out where a pixel covers more than a line (no moire far away).
	float fw = length(fwidth(p));
	float detail = 1.0 - smoothstep(mortar_width * 0.6, mortar_width * 2.5, fw);
	float mortar = (1.0 - smoothstep(half_m, half_m + 0.025 + fw * 0.5, b.x)) * mix(0.35, 1.0, detail);
	float edge = mix(1.0, smoothstep(half_m, half_m + bevel, b.x), detail);
	vec3 c = base_color * (1.0 + (b.y - 0.5) * 2.0 * variation);
	c *= mix(vec3(1.0), vec3(1.07, 1.0, 0.9), b.z * warmth);
	c *= 1.0 + (hash12(floor(p * 5.0)) - 0.5) * 0.05;   // fine speckle
	float h = mix(edge, edge * mix(0.55, 1.0, b.w), dome);
	c *= mix(0.8, 1.0, h);
	c = mix(c, mortar_color, mortar);
	return vec4(c, h * (1.0 - mortar));
}

void fragment() {
	vec3 w = pow(abs(wnrm), vec3(sharpness));
	w /= (w.x + w.y + w.z);
	// Offsets keep the three planes' mortar lines from meeting on the same edges.
	vec2 px = wpos.zy + vec2(0.31, 0.0);
	vec2 py = wpos.xz + vec2(0.0, 0.47);
	vec2 pz = wpos.xy;
	vec4 sx = shade(blocks(px), px);
	vec4 sy = shade(blocks(py), py);
	vec4 sz = shade(blocks(pz), pz);
	vec4 s = sx * w.x + sy * w.y + sz * w.z;
	ALBEDO = s.rgb;
	ROUGHNESS = roughness;
	AO = mix(0.65, 1.0, s.a);
	AO_LIGHT_AFFECT = 0.4;

	// Bevels as a derivative bump: works in view space whatever way the surface faces.
	float height = s.a * bump;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(height);
	float dhdy = dFdy(height);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	if (abs(det) > 1e-9) {
		vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
	}
}
