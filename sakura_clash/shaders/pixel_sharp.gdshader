shader_type canvas_item;
// Sharp bilinear upscale: crisp pixel-art edges at any (non-integer) zoom
// without uneven pixel widths. Requires linear filtering on the texture.

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * tex_size;
	vec2 seam = floor(px + 0.5);
	vec2 dudv = fwidth(px);
	vec2 uv = seam + clamp((px - seam) / max(dudv, vec2(1e-5)), -0.5, 0.5);
	COLOR = texture(TEXTURE, uv / tex_size);
}
