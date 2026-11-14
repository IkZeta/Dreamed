class_name Sprites
extends RefCounted
## Sprites del juego (generados con tools/make_sprites.py). Cada uno se dibuja en su
## rectángulo de SpriteRects, en las mismas coordenadas que el dibujo original.
## The game's sprites (generated with tools/make_sprites.py). Each is drawn in its
## SpriteRects rectangle, in the same coordinates as the original drawing.

static var _cache := {}
static var _white := {}


## Pixel art: siempre sin suavizado / Pixel art: always without smoothing
static func tex(sprite: String) -> Texture2D:
	if not _cache.has(sprite):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load("res://assets/sprites/%s.png" % sprite)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_cache[sprite] = ct
	return _cache[sprite]


## Silueta blanca del sprite, para el destello de daño (se hace la primera vez que hace falta)
## The sprite's white silhouette, for the damage flash (made the first time it's needed)
static func white_tex(sprite: String) -> Texture2D:
	if not _white.has(sprite):
		var img: Image = (load("res://assets/sprites/%s.png" % sprite) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var solid := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		solid.fill(Color.WHITE)
		var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		out.blit_rect_mask(solid, img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		var ct := CanvasTexture.new()
		ct.diffuse_texture = ImageTexture.create_from_image(out)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_white[sprite] = ct
	return _white[sprite]


## Dibuja el sprite con la transformación actual del CanvasItem. Si el color pasa de 1 (el de
## flash_color), encima va su silueta blanca: el destello de daño.
## Draws the sprite with the CanvasItem's current transform. If the colour goes above 1 (flash_color's),
## its white silhouette goes on top: the damage flash.
static func draw(ci: CanvasItem, sprite: String, modulate := Color.WHITE, offset := Vector2.ZERO) -> void:
	var r: Rect2 = SpriteRects.RECTS[sprite]
	r.position += offset
	var f := clampf(minf(modulate.r, minf(modulate.g, modulate.b)) - 1.0, 0.0, 1.0)
	if f <= 0.01:
		ci.draw_texture_rect(tex(sprite), r, false, modulate)
		return
	ci.draw_texture_rect(tex(sprite), r, false, Color(minf(modulate.r, 1.0), minf(modulate.g, 1.0), minf(modulate.b, 1.0), modulate.a))
	ci.draw_texture_rect(white_tex(sprite), r, false, Color(1, 1, 1, f * modulate.a))


## Dibuja solo la parte de arriba del sprite, colocada entre top_y y bottom_y (para el edredón)
## Draws only the top part of the sprite, placed between top_y and bottom_y (for the quilt)
static func draw_top(ci: CanvasItem, sprite: String, top_y: float, bottom_y: float, modulate := Color.WHITE) -> void:
	var r: Rect2 = SpriteRects.RECTS[sprite]
	var h := clampf(bottom_y - top_y, 0.0, r.size.y)
	if h <= 0.0:
		return
	var t := tex(sprite)
	var src_h := t.get_height() * h / r.size.y
	ci.draw_texture_rect_region(t, Rect2(r.position.x, top_y, r.size.x, h), Rect2(0, 0, t.get_width(), src_h), modulate)


## Color para el destello de daño: por encima de 1 (el renderizador lo recortaría), así que draw()
## lo reconoce y pone encima la silueta blanca. Con destello 1 el blanco es total.
## Damage-flash colour: above 1 (the renderer would clamp it), so draw() recognises it and lays the
## white silhouette on top. At flash 1 the white is total.
static func flash_color(flash: float, alpha := 1.0) -> Color:
	var k := 1.0 + 1.6 * flash
	return Color(k, k, k, alpha)
