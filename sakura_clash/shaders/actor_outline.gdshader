shader_type canvas_item;
// Post-process for the low-res actor layer (1:1 texels):
//  * 1px dark silhouette outline around every actor
//  * warm rim light on edges facing the sunset (right / top)
//  * cool sky rim on the left edges

uniform vec4 outline_color : source_color = vec4(0.07, 0.03, 0.11, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.7, 0.45, 1.0);
uniform vec4 rim2_color : source_color = vec4(0.62, 0.5, 1.0, 1.0);
uniform float rim_strength = 0.55;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	float ar = texture(TEXTURE, UV + vec2(ps.x, 0.0)).a;
	float al = texture(TEXTURE, UV - vec2(ps.x, 0.0)).a;
	float au = texture(TEXTURE, UV - vec2(0.0, ps.y)).a;
	float ad = texture(TEXTURE, UV + vec2(0.0, ps.y)).a;
	if (c.a < 0.5) {
		float m = max(max(ar, al), max(au, ad));
		COLOR = m > 0.5 ? outline_color : vec4(0.0);
	} else {
		vec3 col = c.rgb;
		float warm = clamp((1.0 - ar) + (1.0 - au) * 0.45, 0.0, 1.0);
		float cool = (1.0 - al) * 0.6;
		col = mix(col, col * 0.45 + rim_color.rgb * 0.75, warm * rim_strength);
		col = mix(col, col * 0.6 + rim2_color.rgb * 0.45, cool * rim_strength);
		COLOR = vec4(col, 1.0);
	}
}
