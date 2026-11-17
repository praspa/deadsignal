// Derives a normal map from the texture's brightness, so 2D lights pick out
// grout lines, grates, rivets and wall ribs on baked (procedural) art.
shader_type canvas_item;

uniform float strength = 3.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 w = vec3(0.333);
	float dx = dot(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb, w) - dot(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb, w);
	float dy = dot(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb, w) - dot(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb, w);
	NORMAL = normalize(vec3(dx * strength, -dy * strength, 1.0));
	// COLOR already holds texture * modulate; leave it untouched
}
