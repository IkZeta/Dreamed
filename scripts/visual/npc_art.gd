class_name NpcArt
extends RefCounted
## Dibuja a los personajes del plano astral: Svinho, Stolk y Silly.
## Mismo lienzo que Kroker (200 x 300, pies en y = 288) y la misma luz suave.
## Draws the astral plane characters: Svinho, Stolk and Silly.
## Same canvas as Kroker (200 x 300, feet at y = 288) and the same soft light.

static var _ci: CanvasItem
static var _xf: Transform2D


## opts (plano astral): "kick" (Svinho chuta sin balón de toques; con "back", de espaldas), "lift" (Stolk levanta la barra, 0..1)
## y "lens" (Doc mira con la lupa ese punto del lienzo)
## opts (astral plane): "kick" (Svinho kicks with no keepy-uppy ball; with "back", from behind), "lift" (Stolk lifts the bar, 0..1)
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
		"pinche": _pinche(t, opts)
		"magnus": _magnus(t)
		"superk": _superk(t, opts)
		"lilkey": _lilkey(t, opts)
		"lynx": _lynx(t, opts)
		"luna": _luna(t, opts)
		"cat": _cat(t, opts)
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
	# De espaldas (plano astral): la pierna sale hacia delante, hacia la portería, así que se
	# acorta y sube un poco / From behind (astral plane): the leg swings forward, towards the
	# goal, so it gets shorter and lifts a little
	if opts.get("back", false):
		var hip := SVINHO_HIP + Vector2(2, 0)
		_ci.draw_set_transform_matrix(_xf * Transform2D(0.12 * kick, Vector2(1.0, 1.0 - 0.38 * kick), 0.0, hip) * Transform2D(0.0, -hip))
		Sprites.draw(_ci, "npc_svinho_back_leg")
		_ci.draw_set_transform_matrix(_xf * Transform2D(-0.03 * kick, Vector2(0, 288)) * Transform2D(0.0, Vector2(0, -288)))
		Sprites.draw(_ci, "npc_svinho_back")
		_ci.draw_set_transform_matrix(_xf)
		return
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


static func _pinche(t: float, opts := {}) -> void:
	# Plano astral: con el extintor, sin soplete / Astral plane: with the extinguisher, no blowtorch
	if opts.get("ext", false):
		Sprites.draw(_ci, "npc_pinche_ext")
		return
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
		_limb(sh, elbow, 22.0, ink)
		_limb(elbow, hand, 19.0, ink)
		_limb(sh, elbow, 17.0, col)
		_limb(elbow, hand, 14.0, col)
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
	_limb(sh, elbow, 20.0, ink)
	_limb(elbow, hand, 18.0, ink)
	_limb(sh, elbow, 15.0, Color("dcdaee"))
	_limb(elbow, hand, 13.0, Color("c9c6e0"))
	# Lupa / Magnifier
	var lc := hand + Vector2(26, -20)
	_limb(hand, lc + (hand - lc).normalized() * 20.0, 7.0, Color("4a2e22"))
	_ci.draw_circle(hand, 8.0, Color("c2a092"))
	_ci.draw_circle(hand + Vector2(-1, -1), 6.5, Color("e8c4a8"))
	_ci.draw_circle(lc, 21.0, Color("8f8fb8"))
	_ci.draw_circle(lc, 16.0, Color("dfe6ff", 0.45))
	_ci.draw_arc(lc, 11.0, -2.4, -1.4, 6, Color(1, 1, 1, 0.9), 4.0)


## Brazo macizo de "a" a "b" (un cuadrilátero con las puntas redondas) / Solid arm from "a" to "b" (a quad with round ends)
static func _limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var n := (b - a).normalized().orthogonal() * w / 2.0
	_ci.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), col)
	_ci.draw_circle(a, w / 2.0, col)
	_ci.draw_circle(b, w / 2.0, col)


# --- Utilidades / Helpers -----------------------------------------------------

static func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## SuperK flota un poco sobre el suelo y la capa ondea; con "fly", va volando hacia la derecha
## SuperK hovers a little off the ground and his cape ripples; with "fly", he flies to the right
static func _superk(t: float, opts := {}) -> void:
	if opts.get("fly", false):
		var wob := sin(t * 14.0) * 1.5
		_ci.draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2(0, -150 + wob)))
		Sprites.draw(_ci, "npc_superk_fly")
		_ci.draw_set_transform_matrix(_xf)
		return
	var hover := -6.0 - sin(t * 2.0) * 4.0 if opts.get("hover", false) else 0.0
	_ci.draw_colored_polygon(_ellipse(Vector2(100, 286), Vector2(34 - hover * 0.6, 6)), Color(0, 0, 0, 0.15))
	var flap := sin(t * 3.1) * 0.025
	_ci.draw_set_transform_matrix(_xf * Transform2D(flap, Vector2(100, 100 + hover)) * Transform2D(0.0, Vector2(-100, -100)))
	Sprites.draw(_ci, "npc_superk")
	_ci.draw_set_transform_matrix(_xf)


## Lil Key canta con el micro y baila: se balancea, sube y baja, y el brazo libre señala arriba
## al ritmo. "dance" (0..1) es lo fuerte que baila / Lil Key sings into the mic and dances: he
## sways, bounces and points his free arm up to the beat. "dance" (0..1) is how hard he dances
static func _lilkey(t: float, opts := {}) -> void:
	var d: float = opts.get("dance", 0.5)
	var beat := t * 4.2
	var bounce := -absf(sin(beat)) * 8.0 * d
	var sway := sin(beat * 0.5) * 0.06 * d
	_ci.draw_set_transform_matrix(_xf * Transform2D(sway, Vector2(100, 288 + bounce)) * Transform2D(0.0, Vector2(-100, -288)))
	Sprites.draw(_ci, "npc_lilkey")
	var shoulder := Vector2(62, 110)
	var arm := PI - 0.25 + sin(beat) * 0.35 * d
	_ci.draw_set_transform_matrix(_xf * Transform2D(sway, Vector2(100, 288 + bounce)) * Transform2D(0.0, Vector2(-100, -288))
		* Transform2D(arm, shoulder) * Transform2D(0.0, -shoulder))
	Sprites.draw(_ci, "npc_lilkey_arm")
	_ci.draw_set_transform_matrix(_xf)
	# Notas musicales que salen del micro / Music notes coming out of the mic
	for i in 3:
		var ph := fposmod(t * 0.7 + i / 3.0, 1.0)
		var p := Vector2(130 + ph * 40.0 + sin(ph * 9.0 + i) * 6.0, 76 - ph * 70.0)
		var col := Color(["ff6a8a", "8fe0ff", "f6d993"][i], (1.0 - ph) * 0.9)
		_ci.draw_circle(p, 4.0, col)
		_ci.draw_line(p + Vector2(3.5, 0), p + Vector2(3.5, -13), col, 2.0)
		_ci.draw_line(p + Vector2(3.5, -13), p + Vector2(9, -10), col, 2.0)


## Luna, la astronauta: con la gravedad baja flota un palmo y se mece despacio; el casco de pecera
## (cristal con brillo), la antena con su lucecita y unas chispas de la mochila cohete de vez en cuando
## Luna, the astronaut: with low gravity she floats a hand's breadth and sways slowly; the fishbowl
## helmet (glass with a glint), the antenna with its little light and the odd spark from the rocket pack
static func _luna(t: float, opts := {}) -> void:
	# Flota: sube y baja despacio, con un leve vaivén / She floats: rising and sinking slowly, swaying a little
	var lift := 10.0 + sin(t * 1.3) * 6.0
	var sway := sin(t * 0.9) * 0.05
	var sh := PackedVector2Array()
	for i in 18:
		var ang := TAU * i / 18.0
		sh.append(Vector2(100 + cos(ang) * (34.0 - lift * 0.8), 288 + sin(ang) * 6.0))
	_ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.16))
	var body := _xf * Transform2D(sway, Vector2(100, 288 - lift)) * Transform2D(0.0, Vector2(-100, -288))
	_ci.draw_set_transform_matrix(body)
	# Llamitas de las botellas-propulsor / Little flames from the bottle thrusters
	for x: float in [64.0, 136.0]:
		var f := 9.0 + sin(t * 23.0 + x) * 2.5 + sin(t * 37.0) * 1.5
		_ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 186), Vector2(x + 5, 186), Vector2(x, 186 + f * 1.6)]), Color(1.0, 0.55, 0.3, 0.75))
		_ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 186), Vector2(x + 3, 186), Vector2(x, 186 + f)]), Color(1.0, 0.92, 0.6, 0.95))
		for i in 3:
			var ph := fposmod(t * 1.8 + i * 0.33 + x * 0.01, 1.0)
			_ci.draw_circle(Vector2(x + sin(ph * 8.0 + i) * 4.0, 194 + ph * 30.0), 2.2 * (1.0 - ph), Color(1.0, 0.8 - 0.4 * ph, 0.4, 0.7 * (1.0 - ph)))
	# Cable de seguridad que flota en espiral / Safety tether floating in a coil
	var cord := PackedVector2Array()
	for i in 26:
		var f := i / 25.0
		var base := Vector2(80, 182).lerp(Vector2(38, 214), f)
		cord.append(base + Vector2(cos(f * 18.0 + t * 2.0), sin(f * 18.0 + t * 2.0)) * 4.0 * f + Vector2(0, sin(t * 1.1 + f * 3.0) * 6.0 * f))
	_ci.draw_polyline(cord, Color("1e1f48"), 3.4)
	_ci.draw_polyline(cord, Color("ff8a5c"), 1.6)
	_ci.draw_circle(cord[cord.size() - 1], 3.0, Color("9aa0c0"))
	Sprites.draw(_ci, "npc_luna")
	# Brazo que saluda de vez en cuando / Arm waving now and then
	var wp := fposmod(t, 8.0)
	var wave_k := clampf(minf(wp - 5.0, 7.6 - wp) * 2.5, 0.0, 1.0) if not opts.has("wave") else float(opts["wave"])
	var shoulder := Vector2(132, 106)
	var arm := lerpf(0.08 + sin(t * 1.2) * 0.04, -2.5 + sin(t * 9.0) * 0.3, wave_k)
	_ci.draw_set_transform_matrix(body * Transform2D(arm, shoulder) * Transform2D(0.0, -shoulder))
	Sprites.draw(_ci, "npc_luna_arm")
	_ci.draw_set_transform_matrix(body)
	# Casco de pecera: cristal, reflejos y burbujitas que suben / Fishbowl helmet: glass, glints and rising bubbles
	var hc := Vector2(100, 55)
	var hr := 43.0
	_ci.draw_circle(hc, hr, Color(0.72, 0.86, 1.0, 0.13))
	for i in 5:
		var ph := fposmod(t * 0.35 + i * 0.21, 1.0)
		var bp := hc + Vector2(sin(i * 2.3 + t) * 22.0, 30.0 - ph * 64.0)
		_ci.draw_arc(bp, 1.6 + i % 2, 0.0, TAU, 8, Color(1, 1, 1, 0.5 * sin(ph * PI)), 1.0)
	_ci.draw_arc(hc, hr, 0.0, TAU, 48, Color("1e1f48"), 3.4)
	_ci.draw_arc(hc, hr - 1.0, 0.0, TAU, 48, Color(0.85, 0.94, 1.0, 0.8), 1.6)
	_ci.draw_arc(hc, hr - 7.0, -2.75, -1.75, 14, Color(1, 1, 1, 0.8), 4.0)
	_ci.draw_arc(hc, hr - 7.0, -1.6, -1.4, 4, Color(1, 1, 1, 0.8), 4.0)
	_ci.draw_arc(hc, hr - 5.0, 0.35, 0.95, 10, Color(0.75, 0.9, 1.0, 0.45), 2.0)
	# Un brillo que cruza el cristal / A glint sweeping across the glass
	var g := fposmod(t * 0.25, 1.0)
	if g < 0.3:
		var gx := lerpf(-hr, hr, g / 0.3)
		_ci.draw_line(hc + Vector2(gx - 6, -sqrt(maxf(0.0, hr * hr - gx * gx)) * 0.8), hc + Vector2(gx + 6, sqrt(maxf(0.0, hr * hr - gx * gx)) * 0.8), Color(1, 1, 1, 0.22), 5.0)
	# Antena con estrella que parpadea / Antenna with a blinking star
	var root := hc + Vector2(28, -32)
	var tip := root + Vector2(12 + sin(t * 2.0) * 2.0, -20)
	_ci.draw_line(root, tip, Color("1e1f48"), 3.4)
	_ci.draw_line(root, tip, Color("cdc5d6"), 1.6)
	var on := fmod(t, 1.4) < 0.7
	DreamBackground.draw_star(_ci, tip, 6.0 if on else 4.5, Color("f6d993") if on else Color("b8a060"))
	if on:
		_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(tip - Vector2(14, 14), Vector2(28, 28)), false, Color("f6d993", 0.35))
	_ci.draw_set_transform_matrix(_xf)


## D. Lynx con su café (el humo sube despacio, haciendo eses) y el megáfono, que levanta para
## gritar "¡Acción!" cuando "shout" (0..1). Cuando no grita, mira a lo lejos, muy quieto.
## D. Lynx with his coffee (the steam rises slowly, curling) and the megaphone, which he raises to
## shout "Action!" when "shout" (0..1). When he isn't shouting, he gazes into the distance, very still.
static func _lynx(t: float, opts := {}) -> void:
	var shout: float = opts.get("shout", 0.0)
	Sprites.draw(_ci, "npc_lynx")
	# Humo del café / Coffee steam
	for i in 3:
		var ph := fposmod(t * 0.35 + i / 3.0, 1.0)
		var p := Vector2(61 + sin(ph * 8.0 + i) * 4.0, 156 - ph * 36.0)
		_ci.draw_circle(p, 2.5 + ph * 2.0, Color(1, 1, 1, 0.35 * (1.0 - ph)))
	var shoulder := Vector2(135, 110)
	var arm := lerpf(0.0, -2.4, shout) + sin(t * 1.1) * 0.03
	_ci.draw_set_transform_matrix(_xf * Transform2D(arm, shoulder) * Transform2D(0.0, -shoulder))
	Sprites.draw(_ci, "npc_lynx_arm")
	_ci.draw_set_transform_matrix(_xf)
	# Ondas del megáfono al gritar / Megaphone waves when shouting
	if shout > 0.6:
		var tip := shoulder + Vector2(0, 100).rotated(arm)
		for i in 3:
			var k := fposmod(t * 3.0 + i / 3.0, 1.0)
			_ci.draw_arc(tip, 8.0 + k * 24.0, arm + PI * 0.5 - 0.6, arm + PI * 0.5 + 0.6, 8, Color(1, 1, 1, 0.7 * (1.0 - k)), 2.0)


# --- El Gato Siniestro / The Sinister Cat ------------------------------------------------

const CAT_AURA := Color("4fd6c0")
const CAT_EYE := Color("d4f25a")
const CAT_TAIL_PIVOT := Vector2(128, 276)
const CAT_FADE_EVERY := 11.0
const CAT_INK := Color("1e1226")


## Cuánto se ve el cuerpo del gato (1 = entero, 0 = solo ojos y sonrisa): de vez en cuando se
## desvanece y vuelve / How much of the cat's body shows (1 = all of it, 0 = just eyes and grin):
## now and then he fades away and comes back
static func cat_body_alpha(t: float) -> float:
	var ph := fposmod(t, CAT_FADE_EVERY)
	if ph < 7.0:
		return 1.0
	if ph < 8.0:
		return 1.0 - (ph - 7.0)
	if ph < 9.6:
		return 0.0
	return clampf(ph - 9.6, 0.0, 1.0)


## opts: "fade" = se desvanece de vez en cuando (en la fuente); "body" y "face" = cuánto se ve el
## cuerpo y la cara (cuando aparece en un sueño); "talk" = mueve la sonrisa al hablar
## opts: "fade" = fades away now and then (at the fountain); "body" and "face" = how much of the
## body and face shows (when he appears in a dream); "talk" = moves the grin while talking
static func _cat(t: float, opts := {}) -> void:
	var a: float = opts.get("body", cat_body_alpha(t) if opts.get("fade", false) else 1.0)
	var fa: float = opts.get("face", 1.0)
	var talk: bool = opts.get("talk", false)
	var col := Color(1, 1, 1, a)
	if a > 0.0:
		# Cola en interrogación que se menea / Question-mark tail that swishes
		var swish := sin(t * 1.3) * 0.1 + sin(t * 3.1) * 0.03
		_ci.draw_set_transform_matrix(_xf * Transform2D(swish, CAT_TAIL_PIVOT) * Transform2D(0.0, -CAT_TAIL_PIVOT))
		Sprites.draw(_ci, "npc_cat_tail", col)
		_ci.draw_set_transform_matrix(_xf)
		Sprites.draw(_ci, "npc_cat", col)
	# Sin cuerpo, la sonrisa flota y brilla un poco / Bodiless, the grin floats and glows a little
	var lift := (1.0 - a) * (5.0 + sin(t * 2.0) * 2.0)
	if a < 1.0 and fa > 0.0:
		_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(56, 166 - lift, 88, 64), false, Color(CAT_AURA, 0.3 * (1.0 - a) * fa))
	if fa <= 0.0:
		return
	_cat_eyes(t, Vector2(0, -lift), fa)
	_cat_grin(t, Vector2(0, -lift), fa, talk)


static func _cat_eyes(t: float, off: Vector2, fa: float) -> void:
	# Parpadea a ratos, despacio, como quien sabe algo / Blinks now and then, slowly, like someone who knows something
	var bl := fposmod(t, 4.7)
	var open := 1.0 if bl > 0.22 else absf(bl - 0.11) / 0.11
	for x in [84.0, 116.0]:
		var c := Vector2(x, 191) + off
		_ci.draw_colored_polygon(_ellipse(c, Vector2(10.5, 9.5 * open + 1.0)), Color(CAT_INK, fa))
		if open > 0.2:
			_ci.draw_colored_polygon(_ellipse(c, Vector2(9.0, 8.0 * open)), Color(CAT_EYE, fa))
			# Pupila de rendija que mira hacia Kroker (un poco hacia el centro) / Slit pupil glancing inward
			_ci.draw_rect(Rect2(c.x - 1.5 + (2.0 if x < 100.0 else -2.0), c.y - 7.0 * open, 3.0, 14.0 * open), Color(CAT_INK, fa))
			_ci.draw_rect(Rect2(c.x - 6.0, c.y - 5.0 * open, 2.5, 2.5), Color(1, 1, 1, 0.9 * fa))


## Sonrisa enorme de oreja a oreja, con dos filas de dientes / Huge ear-to-ear grin with two rows of teeth
static func _cat_grin(t: float, off: Vector2, fa: float, talk: bool) -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var wob := sin(t * 1.7) * 1.2
	var open := 1.0 + (absf(sin(t * 11.0)) * 0.35 if talk else 0.0)
	for i in 15:
		var u := -1.0 + 2.0 * i / 14.0
		var x := 100.0 + u * 33.0
		var k := 1.0 - u * u
		top.append(Vector2(x, 207.0 + 7.0 * k - absf(u) * (6.0 + wob)) + off)
		bot.append(Vector2(x, 208.0 + 19.0 * k * open - absf(u) * (6.0 + wob)) + off)
	var mouth := top.duplicate()
	for i in range(bot.size() - 1, -1, -1):
		mouth.append(bot[i])
	var c := Vector2(100, 214) + off
	var edge := PackedVector2Array()
	for p in mouth:
		edge.append(p + (p - c).normalized() * 2.5)
	_ci.draw_colored_polygon(edge, Color(CAT_INK, fa))
	_ci.draw_colored_polygon(mouth, Color(Color("f6f2ff"), fa))
	var mid := PackedVector2Array()
	for i in top.size():
		mid.append(top[i].lerp(bot[i], 0.45))
	_ci.draw_polyline(mid, Color(Color("9a8cb8"), fa), 1.5)
	for i in range(2, 13, 2):
		_ci.draw_line(top[i], bot[i], Color(Color("c4bcdc"), fa), 1.1)
