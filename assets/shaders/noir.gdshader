// Último sueño (noir retrofuturista): todo en blanco y negro con más contraste, salvo el rojo,
// que se queda; grano de película, rayas de proyector y viñeta.
// Last dream (retro-futurist noir): everything in black and white with more contrast, except red,
// which stays; film grain, projector scratches and a vignette.
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 1.0;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	g = clamp((g - 0.5) * 1.3 + 0.52, 0.0, 1.0);
	vec3 grey = vec3(g) * vec3(1.0, 0.98, 0.94);
	// El rojo se queda (y algo del naranja) / Red stays (and a little orange)
	float red = smoothstep(0.12, 0.32, c.r - max(c.g, c.b));
	vec3 col = mix(grey, c.rgb, clamp(red * 1.15, 0.0, 1.0));
	// Grano que cambia cada fotograma / Grain that changes every frame
	float n = rnd(floor(UV * vec2(480.0, 270.0)) + floor(TIME * 24.0));
	col += (n - 0.5) * 0.07;
	// Rayas verticales de proyector, de vez en cuando / Vertical projector scratches, now and then
	float sx = rnd(vec2(floor(TIME * 6.0), 3.0));
	if (abs(UV.x - sx) < 0.0012 && rnd(vec2(floor(TIME * 6.0), 7.0)) > 0.6) {
		col += 0.12;
	}
	// Viñeta / Vignette
	float v = smoothstep(0.95, 0.3, distance(UV, vec2(0.5)));
	col *= mix(0.45, 1.0, v);
	COLOR = vec4(mix(c.rgb, col, amount), c.a);
}
