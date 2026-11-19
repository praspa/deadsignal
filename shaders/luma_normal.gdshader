// Derives a normal map from the texture's brightness, so 2D lights pick out
// grout lines, grates, rivets and wall ribs on baked (procedural) art.
shader_type canvas_item;

uniform float strength = 3.0;
// optional palette remap (per location, e.g. the ship's silver-blue): brightness
// is mapped onto a dark -> light ramp and blended in by `remap`
uniform float remap = 0.0;
uniform vec3 remap_dark = vec3(0.0);
uniform vec3 remap_light = vec3(1.0);
uniform float remap_gain = 3.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 w = vec3(0.333);
	float dx = dot(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb, w) - dot(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb, w);
	float dy = dot(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb, w) - dot(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb, w);
	NORMAL = normalize(vec3(dx * strength, -dy * strength, 1.0));
	// COLOR already holds texture * modulate
	if (remap > 0.0) {
		float l = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		vec3 r = mix(remap_dark, remap_light, clamp(l * remap_gain, 0.0, 1.0));
		COLOR.rgb = mix(COLOR.rgb, r, remap);
	}
}
