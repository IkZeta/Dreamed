shader_type canvas_item;
// Pulso de pantalla de la partida: aberración cromática hacia los bordes y un fogonazo de color
// que entra desde los bordes. Los dos valen 0 casi siempre y se disparan con los golpes gordos.
// The run's screen pulse: chromatic aberration towards the edges and a colour flash creeping in
// from the edges. Both are 0 almost always and fire with the big hits.

uniform float aberr = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	vec4 c = texture(TEXTURE, UV);
	if (aberr > 0.0001) {
		vec2 off = d * aberr * r * 2.0;
		c.r = texture(TEXTURE, UV + off).r;
		c.b = texture(TEXTURE, UV - off).b;
	}
	if (flash > 0.001) {
		float edge = smoothstep(0.2, 0.75, r);
		c.rgb = mix(c.rgb, flash_col.rgb, clamp(flash * (0.2 + 0.8 * edge) * flash_col.a, 0.0, 1.0));
	}
	COLOR = c;
}
