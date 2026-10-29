// Aspecto demoníaco de los élites: el contorno del sprite se vuelve rojo y el cuerpo se
// oscurece hacia el carmesí.
// Demonic look for elites: the sprite's outline turns red and the body darkens towards crimson.
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.13, 0.16, 1.0);
uniform float tint : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 col = c * COLOR;
	if (c.a > 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		// Borde: un vecino transparente (o el borde de la textura) / Edge: a transparent neighbour (or the texture edge)
		float n = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		bool edge = n < 0.5 || UV.x < px.x || UV.y < px.y || UV.x > 1.0 - px.x || UV.y > 1.0 - px.y;
		if (edge && px.x < 0.5) {
			col = vec4(outline_color.rgb, outline_color.a * COLOR.a);
		} else {
			col.rgb = mix(col.rgb, col.rgb * vec3(0.95, 0.3, 0.35), tint);
		}
	}
	COLOR = col;
}
