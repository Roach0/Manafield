shader_type canvas_item;
render_mode blend_mix;

// --- tunables ---
uniform float drift_speed   = 0.25;            // how fast lit patches slide along
uniform float evolve_speed  = 0.12;            // how fast they morph in place
uniform vec2  drift_dir     = vec2(1.0, 0.25); // direction the "sun rake" travels
uniform float noise_scale   = 2.5;             // patch size (lower = bigger blobs)
uniform float coverage      = 0.25;            // fraction lit at once (0..1, keep low)
uniform float softness      = 0.20;            // edge softness of each shine patch
uniform float base_alpha    = 0.0;             // visibility when NOT shining
uniform float shine_alpha   = 1.0;             // visibility when fully lit
uniform float shine_lighten = 0.20;            // touch of white added to lit pixels
uniform float seed          = 0.0;             // per-tile offset (set from GDScript)

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 mod = COLOR;                 // preserve node modulate
	vec4 tex = texture(TEXTURE, UV);

	// drifting + slowly evolving noise field, in texture space
	vec2 p = UV * noise_scale + drift_dir * (TIME * drift_speed) + seed;
	float n = vnoise(p);
	n = (n + 0.5 * vnoise(p * 2.0 + TIME * evolve_speed)) / 1.5; // 2 octaves

	// only the top (coverage) of the field lights -> sparse glimmer
	float threshold = 1.0 - coverage;
	float shine = smoothstep(threshold - softness, threshold + softness, n);

	float a = mix(base_alpha, shine_alpha, shine);
	vec3  col = tex.rgb + shine * shine_lighten;

	COLOR = vec4(col, tex.a * a) * mod;
}