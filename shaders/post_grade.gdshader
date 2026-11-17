// Full-screen grade for the grim look: edge chromatic aberration, desaturation,
// crushed blacks, sickly green shadows / rusty highlights, animated film grain.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float grain = 0.055;
uniform float aberration = 2.2;      // pixels of channel split at the corners
uniform float saturation = 0.72;
uniform float black_crush = 0.03;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float edge = dot(d, d) * 4.0;
	vec2 off = normalize(d + 1e-5) * edge * aberration * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;
	c.r = texture(screen_tex, uv + off).r;
	c.b = texture(screen_tex, uv - off).b;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = max(c - black_crush, 0.0) / (1.0 - black_crush);
	c = pow(c, vec3(1.04));
	vec3 shadow_tint = vec3(0.9, 1.0, 0.84);
	vec3 high_tint = vec3(1.07, 0.97, 0.84);
	c *= mix(shadow_tint, high_tint, smoothstep(0.08, 0.6, l));
	float n = fract(sin(dot(FRAGCOORD.xy + fract(TIME * 7.13) * vec2(97.3, 41.7), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
