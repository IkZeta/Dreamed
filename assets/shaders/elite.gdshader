// Aspecto de los élites: contorno de 1 píxel del color de su habilidad que late, un segundo anillo
// por dentro a medio tono y el cuerpo teñido un poco hacia ese color (sin oscurecerlo).
// Elite look: a 1-pixel outline in its ability's colour that pulses, a second ring inside at half
// strength and the body tinted a little towards that colour (without darkening it).
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.13, 0.16, 1.0);
uniform vec3 tint_color = vec3(0.95, 0.3, 0.35);
uniform float tint : hint_range(0.0, 1.0) = 0.22;

float solid(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return step(0.5, texture(tex, uv).a);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 col = c * COLOR;
	if (c.a > 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n1 = min(min(solid(TEXTURE, UV + vec2(px.x, 0.0)), solid(TEXTURE, UV - vec2(px.x, 0.0))),
			min(solid(TEXTURE, UV + vec2(0.0, px.y)), solid(TEXTURE, UV - vec2(0.0, px.y))));
		float n2 = min(min(solid(TEXTURE, UV + vec2(2.0 * px.x, 0.0)), solid(TEXTURE, UV - vec2(2.0 * px.x, 0.0))),
			min(solid(TEXTURE, UV + vec2(0.0, 2.0 * px.y)), solid(TEXTURE, UV - vec2(0.0, 2.0 * px.y))));
		float pulse = 0.75 + 0.25 * sin(TIME * 5.0);
		vec3 glow = outline_color.rgb * (0.85 + 0.3 * pulse);
		if (n1 < 0.5 && px.x < 0.5) {
			col = vec4(glow, outline_color.a * COLOR.a);
		} else if (n2 < 0.5 && px.x < 0.5) {
			col.rgb = mix(col.rgb, glow, 0.45 * pulse);
		} else {
			col.rgb = mix(col.rgb, col.rgb * tint_color * 1.35, tint);
		}
	}
	COLOR = col;
}
