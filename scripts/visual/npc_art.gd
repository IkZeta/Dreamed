class_name NpcArt
extends RefCounted
## Dibuja a los personajes del plano astral: Svinho, Stolk y Silly.
## Mismo lienzo que Kroker (200 x 300, pies en y = 288) y la misma luz suave.
## Draws the astral plane characters: Svinho, Stolk and Silly.
## Same canvas as Kroker (200 x 300, feet at y = 288) and the same soft light.

static var _ci: CanvasItem
static var _xf: Transform2D


static func draw(ci: CanvasItem, xf: Transform2D, who: String, t: float) -> void:
	_ci = ci
	var breath := 1.0 + sin(t * 1.6) * 0.01
	_xf = xf * Transform2D(0.0, Vector2(1.0, breath), 0.0, Vector2(0, 288.0 * (1.0 - breath)))
	_ci.draw_set_transform_matrix(_xf)
	match who:
		"svinho": _svinho(t)
		"stolk": _stolk(t)
		"silly": _silly(t)
		"doc": _doc(t)
		"charo": _charo(t)
		"ad": _ad(t)
		"pinche": _pinche(t)
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Personajes en pixel art (tools/make_sprites.py) con detalles animados encima
# --- Pixel-art characters (tools/make_sprites.py) with animated details on top

## Svinho da toques: la pierna derecha sube justo cuando el balón le llega al pie
## Svinho does keepy-uppies: the right leg kicks up just as the ball reaches his foot
const SVINHO_HIP := Vector2(107, 196)
const SVINHO_TOUCH := 0.8       # segundos entre toque y toque / seconds between touches
const SVINHO_KICK := -0.4       # cuánto levanta la pierna (radianes) / how high the leg lifts (radians)


static func _svinho(t: float) -> void:
	var ph := fmod(t, SVINHO_TOUCH) / SVINHO_TOUCH
	var near := minf(ph, 1.0 - ph)
	var kick := clampf(1.0 - near / 0.22, 0.0, 1.0)
	kick = kick * kick * (3.0 - 2.0 * kick)
	# Pierna que golpea (detrás del cuerpo) / Kicking leg (behind the body)
	_ci.draw_set_transform_matrix(_xf * Transform2D(SVINHO_KICK * kick, SVINHO_HIP) * Transform2D(0.0, -SVINHO_HIP))
	Sprites.draw(_ci, "npc_svinho_leg")
	_ci.draw_set_transform_matrix(_xf)
	Sprites.draw(_ci, "npc_svinho")
	# El balón sube hasta el pecho y vuelve al pie / The ball rises to chest height and drops back to the foot
	var foot := SVINHO_HIP + Vector2(13, 74).rotated(SVINHO_KICK)
	var height := 4.0 * 95.0 * ph * (1.0 - ph)
	var ball := foot + Vector2(-4.0 - sin(ph * PI) * 4.0, -12.0 - height)
	var shadow_k := 1.0 - height / 120.0
	_ci.draw_colored_polygon(_ellipse(Vector2(ball.x, 286), Vector2(11.0 * shadow_k + 2.0, 3)), Color(0, 0, 0, 0.22 * shadow_k + 0.05))
	_ci.draw_set_transform_matrix(_xf * Transform2D(t * 6.0, ball))
	Sprites.draw(_ci, "npc_ball")
	_ci.draw_set_transform_matrix(_xf)


## Mr. Ad, robot anunciante medio roto: en la pantalla de la barriga van pasando anuncios
## Mr. Ad, a half-broken advertising robot: adverts scroll across the screen in his belly
const AD_SCREEN := Rect2(75, 118, 50, 34)
const AD_PANEL := 50.0
const AD_PANELS := 6
const AD_HOLD := 1.3      # segundos que se queda cada anuncio / seconds each advert stays
const AD_SLIDE := 0.35    # segundos que tarda en pasar al siguiente / seconds to slide to the next


static func _ad(t: float) -> void:
	Sprites.draw(_ci, "npc_ad")
	var step := AD_HOLD + AD_SLIDE
	var n := int(t / step)
	var k := clampf((fmod(t, step) - AD_HOLD) / AD_SLIDE, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var u := fmod((n + k) * AD_PANEL, AD_PANEL * AD_PANELS)
	_strip_window(u, AD_SCREEN)
	_ci.draw_rect(Rect2(AD_SCREEN.position, Vector2(AD_SCREEN.size.x, 3)), Color(1, 1, 1, 0.12))
	# Es un robot medio roto: interferencias, grieta, chispas, antena y un ojo que falla
	# He's a half-broken robot: interference, a crack, sparks, the antenna and a failing eye
	if fmod(t, 3.7) < 0.18:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(t * 30.0)
		for i in 9:
			var y := AD_SCREEN.position.y + rng.randf() * AD_SCREEN.size.y
			_ci.draw_rect(Rect2(AD_SCREEN.position.x, y, AD_SCREEN.size.x, rng.randf_range(1.5, 4.0)), Color(0.8, 0.85, 1.0, rng.randf_range(0.2, 0.6)))
	_ci.draw_polyline(PackedVector2Array([Vector2(119, 118), Vector2(116, 123), Vector2(117, 127), Vector2(112, 133), Vector2(110, 140), Vector2(106, 144)]), Color("e8ecff", 0.85), 1.6)
	_ci.draw_line(Vector2(116, 123), Vector2(121, 128), Color("e8ecff", 0.7), 1.2)
	if fmod(t, 4.1) < 0.14 or (fmod(t, 4.1) > 0.25 and fmod(t, 4.1) < 0.32):
		_ci.draw_rect(Rect2(105, 54, 14, 17), Color(0.1, 0.06, 0.12, 0.85))
	var bulb := fmod(t, 1.4) < 0.7
	_ci.draw_circle(Vector2(73, 19), 3.5, Color("ff5a6e") if bulb else Color("5a1e2a"))
	if bulb:
		_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(63, 9, 20, 20), false, Color("ff5a6e", 0.35))
	var spark := fmod(t, 2.3)
	if spark < 0.16:
		var c := Vector2(90, 108) if fmod(t, 4.6) < 2.3 else Vector2(110, 106)
		for i in 4:
			var ang := i * 1.6 + spark * 20.0
			_ci.draw_line(c, c + Vector2(cos(ang), sin(ang)) * (4.0 + i), Color("ffe36a", 1.0 - spark * 5.0), 1.4)


## Dibuja un trozo de la tira de anuncios (desde u, en unidades) dentro de la pantalla, dando la vuelta al final
## Draws a piece of the ad strip (from u, in units) inside the screen, wrapping round at the end
static func _strip_window(u: float, screen: Rect2) -> void:
	var tex := Sprites.tex("ad_strip")
	var r: Rect2 = SpriteRects.RECTS["ad_strip"]
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var total := AD_PANEL * AD_PANELS
	var to_tx := func(x: float) -> float: return (x - r.position.x) / r.size.x * tw
	var sy := (0.0 - r.position.y) / r.size.y * th
	var sh := screen.size.y / r.size.y * th
	var first := minf(screen.size.x, total - u)
	_ci.draw_texture_rect_region(tex, Rect2(screen.position, Vector2(first, screen.size.y)),
		Rect2(to_tx.call(u), sy, to_tx.call(u + first) - to_tx.call(u), sh))
	if first < screen.size.x:
		var rest := screen.size.x - first
		_ci.draw_texture_rect_region(tex, Rect2(screen.position + Vector2(first, 0), Vector2(rest, screen.size.y)),
			Rect2(to_tx.call(0.0), sy, to_tx.call(rest) - to_tx.call(0.0), sh))


## El Pinche: la llama del soplete baila y el cuchillo destella
## The Kitchen Boy: the blowtorch flame dances and the knife glints
static func _pinche(t: float) -> void:
	Sprites.draw(_ci, "npc_pinche")
	var tip := Vector2(166, 131)
	var flick := 1.0 + 0.25 * sin(t * 23.0) + 0.15 * sin(t * 37.0)
	_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(tip - Vector2(22, 22), Vector2(44, 44)), false, Color("ff9a3a", 0.35))
	var pts := PackedVector2Array([tip + Vector2(0, -5), tip + Vector2(22 * flick, -1), tip + Vector2(0, 5)])
	_ci.draw_colored_polygon(pts, Color("ff9a3a", 0.9))
	var inner := PackedVector2Array([tip + Vector2(0, -2.5), tip + Vector2(12 * flick, 0), tip + Vector2(0, 2.5)])
	_ci.draw_colored_polygon(inner, Color("8fd8ff", 0.95))
	var glint := fposmod(t, 3.2)
	if glint < 0.3:
		_ci.draw_rect(Rect2(64, 150 + glint * 80.0, 3, 3), Color(1, 1, 1, 0.9))


## La Kioskera Charo; sus gafas brillan de vez en cuando / Kiosk lady Charo; her glasses glint now and then
static func _charo(t: float) -> void:
	Sprites.draw(_ci, "npc_charo")
	var glint := fposmod(t, 4.0)
	if glint < 0.25:
		_ci.draw_rect(Rect2(86 + glint * 40.0, 75, 3, 3), Color(1, 1, 1, 0.8))


static func _stolk(t: float) -> void:
	Sprites.draw(_ci, "npc_stolk")
	# Aura roja que late / Pulsing red aura
	_ci.draw_arc(Vector2(100, 150), 90 + sin(t * 3.0) * 4.0, 0, TAU, 48, Color("ff7a8a", 0.12), 3.0, true)


static func _silly(t: float) -> void:
	# El portátil le ilumina la cara / The laptop lights up her face
	_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(40, 60, 120, 140), false, Color("5ff2ff", 0.16))
	Sprites.draw(_ci, "npc_silly")
	# Código que corre por la pantalla / Code running down the screen
	_ci.draw_rect(Rect2(72, 121, 56, 24), Color("5ff2ff", 0.08 + 0.05 * sin(t * 5.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 6.0)
	for row in 5:
		var y := 123.0 + row * 4.5
		var x := 74.0 + rng.randf_range(0, 6)
		while x < 124.0:
			var w := minf(rng.randf_range(3, 10), 126.0 - x)
			_ci.draw_rect(Rect2(x, y, w, 2.2), Color("7dffb0", rng.randf_range(0.45, 0.9)))
			x += w + rng.randf_range(2, 6)
	# Cursor que parpadea / Blinking cursor
	if fmod(t, 1.0) < 0.5:
		_ci.draw_rect(Rect2(118, 141, 4, 3), Color("5ff2ff", 0.9))

static func _doc(t: float) -> void:
	Sprites.draw(_ci, "npc_doc")
	# Espejo frontal que brilla / Glowing head mirror
	var glint := 0.6 + 0.4 * sin(t * 2.0)
	_ci.draw_rect(Rect2(97, 37, 6, 6), Color(1, 1, 1, glint))


# --- Utilidades / Helpers -----------------------------------------------------

static func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
