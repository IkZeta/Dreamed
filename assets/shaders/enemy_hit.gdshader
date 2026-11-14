// Destello de golpe: la silueta se pone blanca del todo y se apaga. Todos comparten el mismo
// material (el motor los sigue dibujando por lotes) y cada uno lleva su destello en un parámetro
// por instancia: set_instance_shader_parameter("flash", 0..1).
// Solo blanquea lo que lleva textura (los sprites), no las sombras ni los círculos y líneas que se
// dibujan a mano: esos usan la textura blanca de 1 × 1, y se reconocen por su tamaño de píxel.
// Hit flash: the silhouette turns fully white and fades. Everyone shares the same material (the
// engine keeps batching them) and each carries its own flash in a per-instance parameter:
// set_instance_shader_parameter("flash", 0..1).
// It only whitens what has a texture (the sprites), not the shadows or the circles and lines drawn
// by hand: those use the 1 × 1 white texture, recognised by its pixel size.
shader_type canvas_item;

instance uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (flash > 0.0 && TEXTURE_PIXEL_SIZE.x < 0.5) {
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
	}
}
