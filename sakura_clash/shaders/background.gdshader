shader_type canvas_item;
// Arena background: sharp upscale, pond water shimmer, dim for cinematics.

uniform float darken = 0.0;
uniform vec4 darken_color : source_color = vec4(0.05, 0.02, 0.1, 1.0);
uniform vec4 water_rect = vec4(840.0, 598.0, 1500.0, 688.0);
uniform float blur_dim = 0.0;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * tex_size;
	if (px.x > water_rect.x && px.x < water_rect.z && px.y > water_rect.y && px.y < water_rect.w) {
		float ex = smoothstep(water_rect.x, water_rect.x + 50.0, px.x) * (1.0 - smoothstep(water_rect.z - 50.0, water_rect.z, px.x));
		float ey = smoothstep(water_rect.y, water_rect.y + 16.0, px.y) * (1.0 - smoothstep(water_rect.w - 8.0, water_rect.w, px.y));
		float band = floor(px.y / 4.0);
		float off = sin(TIME * 1.7 + band * 0.85) * 4.0 * ex * ey;
		px.x += floor(off / 4.0 + 0.5) * 4.0;
	}
	vec2 seam = floor(px + 0.5);
	vec2 dudv = fwidth(UV * tex_size);
	vec2 uv = seam + clamp((px - seam) / max(dudv, vec2(1e-5)), -0.5, 0.5);
	vec4 c = texture(TEXTURE, uv / tex_size);
	c.rgb = mix(c.rgb, darken_color.rgb, darken);
	c.rgb = mix(c.rgb, vec3(dot(c.rgb, vec3(0.3, 0.5, 0.2))) * vec3(0.55, 0.45, 0.7), blur_dim);
	COLOR = c;
}
