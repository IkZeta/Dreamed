class_name Sprites
extends RefCounted
## Sprites del juego (generados con tools/make_sprites.py). Cada uno se dibuja en su
## rectángulo de SpriteRects, en las mismas coordenadas que el dibujo original.
## The game's sprites (generated with tools/make_sprites.py). Each is drawn in its
## SpriteRects rectangle, in the same coordinates as the original drawing.

static var _cache := {}


## Pixel art: siempre sin suavizado / Pixel art: always without smoothing
static func tex(sprite: String) -> Texture2D:
	if not _cache.has(sprite):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load("res://assets/sprites/%s.png" % sprite)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_cache[sprite] = ct
	return _cache[sprite]


## Dibuja el sprite con la transformación actual del CanvasItem / Draws the sprite with the CanvasItem's current transform
static func draw(ci: CanvasItem, sprite: String, modulate := Color.WHITE, offset := Vector2.ZERO) -> void:
	var r: Rect2 = SpriteRects.RECTS[sprite]
	r.position += offset
	ci.draw_texture_rect(tex(sprite), r, false, modulate)


## Color para el destello de daño: aclara la textura / Damage-flash colour: brightens the texture
static func flash_color(flash: float, alpha := 1.0) -> Color:
	var k := 1.0 + 1.6 * flash
	return Color(k, k, k, alpha)
