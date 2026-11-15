shader_type canvas_item;
// Pulso de pantalla de la partida: aberración cromática hacia los bordes y un fogonazo de color
// que entra desde los bordes. Los dos valen 0 casi siempre y se disparan con los golpes gordos.
// The run's screen pulse: chromatic aberration towards the edges and a colour flash creeping in
// from the edges. Both are 0 almost always and fire with the big hits.

uniform float aberr = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);
// Luz de cada acto: las sombras tiran a un color, las luces a otro, y los bordes se oscurecen
// hacia el color de sombra (viñeta). Con todo a 0 no cambia nada.
// Each act's light: shadows lean to one colour, highlights to another, and the edges darken
// towards the shadow colour (vignette). With everything at 0 nothing changes.
uniform vec3 shade_col : source_color = vec3(0.0);
uniform vec3 light_col : source_color = vec3(1.0);
uniform float grade = 0.0;
uniform float vignette = 0.0;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	vec4 c = texture(TEXTURE, UV);
	if (aberr > 0.0001) {
		vec2 off = d * aberr * r * 2.0;
		c.r = texture(TEXTURE, UV + off).r;
		c.b = texture(TEXTURE, UV - off).b;
	}
	if (grade > 0.001) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec3 tint = mix(vec3(1.0), shade_col / max(max(shade_col.r, shade_col.g), max(shade_col.b, 0.001)), 0.5);
		vec3 toned = c.rgb * mix(tint, light_col * 1.05, smoothstep(0.1, 0.7, l));
		c.rgb = mix(c.rgb, toned, grade);
	}
	if (vignette > 0.001) {
		float v = smoothstep(0.28, 0.74, r) * vignette;
		c.rgb = mix(c.rgb, c.rgb * shade_col * 1.3, v);
	}
	if (flash > 0.001) {
		float edge = smoothstep(0.2, 0.75, r);
		c.rgb = mix(c.rgb, flash_col.rgb, clamp(flash * (0.2 + 0.8 * edge) * flash_col.a, 0.0, 1.0));
	}
	COLOR = c;
}
