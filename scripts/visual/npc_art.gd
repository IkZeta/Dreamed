class_name NpcArt
extends RefCounted
## Dibuja a los personajes del plano astral: Svinho, Stolk y Silly.
## Mismo lienzo que Kroker (200 x 300, pies en y = 288) y la misma luz suave.
## Draws the astral plane characters: Svinho, Stolk and Silly.
## Same canvas as Kroker (200 x 300, feet at y = 288) and the same soft light.

static var _ci: CanvasItem
static var _xf: Transform2D


## opts (plano astral): "kick" (Svinho chuta sin balón de toques), "lift" (Stolk levanta la barra, 0..1)
## y "lens" (Doc mira con la lupa ese punto del lienzo)
## opts (astral plane): "kick" (Svinho kicks with no keepy-uppy ball), "lift" (Stolk lifts the bar, 0..1)
## and "lens" (Doc looks at that canvas point through the magnifier)
static func draw(ci: CanvasItem, xf: Transform2D, who: String, t: float, opts := {}) -> void:
	_ci = ci
	var breath := 1.0 + sin(t * 1.6) * 0.01
	_xf = xf * Transform2D(0.0, Vector2(1.0, breath), 0.0, Vector2(0, 288.0 * (1.0 - breath)))
	_ci.draw_set_transform_matrix(_xf)
	match who:
		"svinho": _svinho(t, opts)
		"stolk": _stolk(t, opts)
		"silly": _silly(t)
		"doc": _doc(t, opts)
		"charo": _charo(t)
		"ad": _ad(t)
		"pinche": _pinche(t)
		"magnus": _magnus(t)
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Personajes en pixel art (tools/make_sprites.py) con detalles animados encima
# --- Pixel-art characters (tools/make_sprites.py) with animated details on top

## Svinho da toques: la pierna derecha sube justo cuando el balón le llega al pie
## Svinho does keepy-uppies: the right leg kicks up just as the ball reaches his foot
const SVINHO_HIP := Vector2(107, 196)
const SVINHO_TOUCH := 0.8       # segundos entre toque y toque / seconds between touches
const SVINHO_KICK := -0.4       # cuánto levanta la pierna (radianes) / how high the leg lifts (radians)


static func _svinho(t: float, opts := {}) -> void:
	var ph := fmod(t, SVINHO_TOUCH) / SVINHO_TOUCH
	var near := minf(ph, 1.0 - ph)
	var kick := clampf(1.0 - near / 0.22, 0.0, 1.0)
	kick = kick * kick * (3.0 - 2.0 * kick)
	if opts.has("kick"):
		kick = float(opts["kick"])
	# Pierna que golpea (detrás del cuerpo) / Kicking leg (behind the body)
	_ci.draw_set_transform_matrix(_xf * Transform2D(SVINHO_KICK * kick, SVINHO_HIP) * Transform2D(0.0, -SVINHO_HIP))
	Sprites.draw(_ci, "npc_svinho_leg")
	_ci.draw_set_transform_matrix(_xf)
	Sprites.draw(_ci, "npc_svinho")
	if opts.has("kick"):
		return
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
## Magnus lanza una moneda con el pulgar y la recoge; de vez en cuando le brilla la placa
## Magnus flips a coin with his thumb and catches it; now and then his nameplate gleams
const MAGNUS_HAND := Vector2(116, 166)
const MAGNUS_FLIP := 1.8   # segundos entre lanzamiento y lanzamiento / seconds between flips


static func _magnus(t: float) -> void:
	Sprites.draw(_ci, "npc_magnus")
	var ph := fmod(t, MAGNUS_FLIP) / MAGNUS_FLIP
	var air := clampf(ph / 0.6, 0.0, 1.0)
	var h := 4.0 * 52.0 * air * (1.0 - air)
	var coin := MAGNUS_HAND + Vector2(0, -6 - h)
	var spin := absf(cos(t * 14.0)) if air < 1.0 else 1.0
	_ci.draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2(maxf(spin, 0.2), 1.0), 0.0, coin))
	_ci.draw_circle(Vector2.ZERO, 5.0, Color("c9961e"))
	_ci.draw_circle(Vector2.ZERO, 3.6, Color("f2c94c"))
	_ci.draw_rect(Rect2(-1, -2, 2, 4), Color("c9961e"))
	_ci.draw_set_transform_matrix(_xf)
	# Brillo que cruza la placa / Gleam crossing the nameplate
	var g := fposmod(t, 4.0)
	if g < 0.5:
		var x := 72.0 + g / 0.5 * 54.0
		_ci.draw_rect(Rect2(x, 226, 3, 12), Color(1, 1, 1, 0.55))


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


static func _stolk(t: float, opts := {}) -> void:
	if opts.has("lift"):
		_stolk_lift(float(opts["lift"]))
		return
	Sprites.draw(_ci, "npc_stolk")
	# Aura roja que late / Pulsing red aura
	_ci.draw_arc(Vector2(100, 150), 90 + sin(t * 3.0) * 4.0, 0, TAU, 48, Color("ff7a8a", 0.12), 3.0, true)


## Stolk levanta la barra por encima de la cabeza con los dos brazos
## Stolk presses the bar over his head with both arms
static func _stolk_lift(up: float) -> void:
	Sprites.draw(_ci, "npc_stolk_lift")
	var hy := lerpf(104.0, 6.0, up)
	var ink := Color("3a1018")
	for side in [-1.0, 1.0]:
		var sh := Vector2(100.0 + 40.0 * side, 112.0)
		var hand := Vector2(100.0 + 54.0 * side, hy)
		var elbow := (sh + hand) / 2.0 + Vector2(side * (6.0 + (1.0 - up) * 26.0), (1.0 - up) * 12.0)
		var col := Color("a8323f") if side < 0.0 else Color("6e1f2a")
		_ci.draw_line(sh, elbow, ink, 22.0)
		_ci.draw_line(elbow, hand, ink, 19.0)
		_ci.draw_circle(elbow, 10.5, ink)
		_ci.draw_line(sh, elbow, col, 17.0)
		_ci.draw_line(elbow, hand, col, 14.0)
		_ci.draw_circle(elbow, 8.0, col)
	# Barra con sus discos / Bar with its plates
	_ci.draw_rect(Rect2(8, hy - 3, 184, 6), Color("c9cce0"))
	for x in [8.0, 176.0]:
		_ci.draw_rect(Rect2(x, hy - 22, 16, 44), Color("2b2945"))
		_ci.draw_rect(Rect2(x + 3, hy - 18, 10, 36), Color("d8434f"))
	for side in [-1.0, 1.0]:
		_ci.draw_circle(Vector2(100.0 + 54.0 * side, hy), 9.0, Color("c9957e"))
		_ci.draw_circle(Vector2(100.0 + 54.0 * side - 1.0, hy - 1.0), 7.0, Color("f0c4aa"))


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

static func _doc(t: float, opts := {}) -> void:
	if opts.has("lens"):
		Sprites.draw(_ci, "npc_doc_free")
		_doc_lens(Vector2(opts["lens"]))
	else:
		Sprites.draw(_ci, "npc_doc")
	# Espejo frontal que brilla / Glowing head mirror
	var glint := 0.6 + 0.4 * sin(t * 2.0)
	_ci.draw_rect(Rect2(96, 36, 4, 4), Color(1, 1, 1, glint))


## Brazo derecho de Doc con la lupa apuntando a "lens" (en el lienzo) / Doc's right arm with the magnifier aimed at "lens" (on the canvas)
static func _doc_lens(lens: Vector2) -> void:
	var sh := Vector2(136, 112)
	var hand := lens - Vector2(26, -20)
	var reach := 104.0
	if hand.distance_to(sh) > reach:
		hand = sh + (hand - sh).normalized() * reach
	var mid := (sh + hand) / 2.0
	var bend := sqrt(maxf(0.0, 52.0 * 52.0 - pow(sh.distance_to(hand) / 2.0, 2.0)))
	var elbow := mid + (hand - sh).normalized().orthogonal() * -bend
	if elbow.y < mid.y:
		elbow = mid + (hand - sh).normalized().orthogonal() * bend
	var ink := Color("5a5878")
	_ci.draw_line(sh, elbow, ink, 19.0)
	_ci.draw_line(elbow, hand, ink, 17.0)
	_ci.draw_circle(elbow, 9.5, ink)
	_ci.draw_line(sh, elbow, Color("dcdaee"), 15.0)
	_ci.draw_line(elbow, hand, Color("c9c6e0"), 13.0)
	_ci.draw_circle(elbow, 7.5, Color("d4d2ea"))
	# Lupa / Magnifier
	var lc := hand + Vector2(26, -20)
	_ci.draw_line(hand, lc + (hand - lc).normalized() * 16.0, Color("4a2e22"), 7.0)
	_ci.draw_circle(hand, 7.0, Color("e8c4a8"))
	_ci.draw_circle(lc, 16.0, Color("dfe6ff", 0.3))
	_ci.draw_arc(lc, 16.0, 0, TAU, 24, Color("8f8fb8"), 5.0)
	_ci.draw_arc(lc, 10.0, -2.4, -1.4, 6, Color(1, 1, 1, 0.8), 3.0)


# --- Utilidades / Helpers -----------------------------------------------------

static func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
