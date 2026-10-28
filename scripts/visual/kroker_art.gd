class_name KrokerArt
extends RefCounted
## Dibuja a Kroker: un niño con gafas y pelo negro, siempre en pijama.
## Iluminado por la luna desde arriba a la izquierda, con sombras suaves y frías.
## Draws Kroker: a boy with glasses and black hair, always in pajamas.
## Moonlit from the upper left, with soft, cool shadows.
##
## Lienzo virtual de 200 x 300, pies en y = 288. Arte provisional: cámbialo por sprites.
## 200 x 300 virtual canvas, feet at y = 288. Placeholder art: swap for sprites.

const SKIN := Color("f1cfbb")
const SKIN_SHADE := Color("c3a0b0")
const HAIR := Color("16141f")
const HAIR_LIGHT := Color("4a5895")
const FRAME := Color("2b2945")
const SHADE := Color(0.12, 0.08, 0.32, 0.22)   # sombra fría / cool shadow
const RIM := Color("cbd6ff")

## Pijamas: base, dibujo, ribete, zapatillas y estampado.
## Pajamas: base, pattern, piping, slippers and print type.
const PAJAMAS := {
	"": {"base": Color("8e99dc"), "pattern": Color("ffffff"), "piping": Color("2f3a7a"), "slippers": Color("3b3f73"), "print": "plain"},
	"bat": {"base": Color("33457f"), "pattern": Color("ece6f4"), "piping": Color("ece6f4"), "slippers": Color("c9536b"), "print": "stripes"},
	"shield": {"base": Color("b46e8f"), "pattern": Color("7c4063"), "piping": Color("f6e9ef"), "slippers": Color("6d3a5a"), "print": "plaid"},
	"book": {"base": Color("2b3d8f"), "pattern": Color("f6d993"), "piping": Color("f6d993"), "slippers": Color("1d2560"), "print": "stars"},
	"vacuum": {"base": Color("62a9a1"), "pattern": Color("f4f1e6"), "piping": Color("f4f1e6"), "slippers": Color("2f6e69"), "print": "dots"},
}

## Color de acento del arma / Weapon accent color
const ACCENT := {
	"": Color("f6d993"),
	"bat": Color("f6d993"),
	"shield": Color("f6d993"),
	"book": Color("fff0b8"),
	"vacuum": Color("b9f0ea"),
}

static var _ci: CanvasItem
static var _xf: Transform2D
static var _local := Transform2D.IDENTITY


## Opciones de pose / Pose options:
##  facing (1/-1), flash (0..1 destello de daño), attack (0..1 golpe), cast (0..1 lanzar rayo),
##  aim (Vector2 dirección de la aspiradora), sucking (bool), walk (fase del paso en radianes),
##  moving (0..1 cuánto camina), stretch (0..1 estirarse), lean (inclinación en radianes),
##  glasses (bool gafas puestas), armed (bool lleva el arma), yawn (0..1 bostezo)
static func draw(ci: CanvasItem, xf: Transform2D, outfit: String, t: float, opts := {}) -> void:
	_ci = ci
	_local = Transform2D.IDENTITY
	var facing: float = opts.get("facing", 1.0)
	var flash: float = opts.get("flash", 0.0)
	var walk: float = opts.get("walk", 0.0)
	var moving: float = opts.get("moving", 0.0)
	var stretch: float = opts.get("stretch", 0.0)
	var attack: float = opts.get("attack", 0.0)
	var cast: float = opts.get("cast", 0.0)
	var lean: float = opts.get("lean", 0.0)
	var armed: bool = opts.get("armed", true)
	var breath := 1.0 + sin(t * 1.8) * 0.008
	_xf = xf * Transform2D(0.0, Vector2(facing, breath), 0.0, Vector2(100.0 - 100.0 * facing, 288.0 * (1.0 - breath)))
	var pj: Dictionary = PAJAMAS.get(outfit, PAJAMAS[""])
	var base: Color = pj["base"]
	if flash > 0.0:
		base = base.lerp(Color.WHITE, flash * 0.6)
	var piping: Color = pj["piping"]

	# Sombra suave en el suelo / Soft ground shadow
	_use(Transform2D(0.0, Vector2(1.0, 0.2), 0.0, Vector2(100, 288)))
	ci.draw_circle(Vector2.ZERO, 44, Color(0.05, 0.03, 0.18, 0.35))
	_use(Transform2D.IDENTITY)

	if outfit == "vacuum" and armed:
		_vacuum_tank(t)

	# Rebote al andar e inclinación / Walking bounce and lean
	var bob := -absf(sin(walk)) * 5.0 * moving
	_xf = _xf * Transform2D(lean, Vector2(100, 288 + bob)) * Transform2D(0.0, Vector2(-100, -288))

	# Ángulos de piernas y brazos / Leg and arm angles
	var swing := sin(walk) * 0.42 * moving
	var arm_l := -swing * 0.8 + 2.7 * stretch - 1.25 * (attack if outfit == "shield" else 0.0)
	var arm_r := swing * 0.8 - 2.7 * stretch
	if outfit == "bat":
		arm_r += -0.9 * attack
	elif outfit == "book":
		arm_r += -1.2 * cast
	if armed and outfit in ["bat", "vacuum"]:
		arm_r *= 0.5  # el arma pesa / the weapon is heavy
	const SH_L := Vector2(75, 106)
	const SH_R := Vector2(125, 106)
	var hand_l := SH_L + (Vector2(70, 188) - SH_L).rotated(arm_l)
	var hand_r := SH_R + (Vector2(130, 188) - SH_R).rotated(arm_r)

	# Piernas / Legs
	for side in 2:
		var hip := Vector2(87, 172) if side == 0 else Vector2(113, 172)
		var rot := swing if side == 0 else -swing
		var r := Rect2(76, 170, 23, 106) if side == 0 else Rect2(101, 170, 23, 106)
		_limb(rot, hip)
		_shape(_rect_pts(r), base.darkened(0.08 if side == 0 else 0.16))
		_pattern(r, pj)
		_ci.draw_rect(Rect2(r.position.x, 268, r.size.x, 5), piping)
		var foot := Vector2(r.get_center().x, 282)
		_ci.draw_colored_polygon(_ellipse(foot, Vector2(15, 7)), pj["slippers"])
		_ci.draw_colored_polygon(_ellipse(foot - Vector2(3, 2), Vector2(7, 3)), Color(1, 1, 1, 0.18))
	_use(Transform2D.IDENTITY)

	# Brazos (detrás del torso) / Arms (behind the torso)
	_arm(arm_l, SH_L, PackedVector2Array([Vector2(68, 104), Vector2(82, 110), Vector2(78, 182), Vector2(63, 180)]),
		base.darkened(0.04), piping, Vector2(70, 188), SKIN)
	_arm(arm_r, SH_R, PackedVector2Array([Vector2(132, 104), Vector2(118, 110), Vector2(122, 182), Vector2(137, 180)]),
		base.darkened(0.12), piping, Vector2(130, 188), SKIN.lerp(SKIN_SHADE, 0.4))
	_use(Transform2D.IDENTITY)

	# Camisa del pijama / Pajama shirt
	var torso := PackedVector2Array([
		Vector2(84, 98), Vector2(116, 98), Vector2(132, 106), Vector2(134, 178), Vector2(66, 178), Vector2(68, 106),
	])
	_shape(torso, base)
	_pattern(Rect2(70, 104, 60, 72), pj)
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(112, 100), Vector2(132, 106), Vector2(134, 178), Vector2(112, 178)]), SHADE)
	# Cuello con solapas y botones / Lapel collar and buttons
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(86, 97), Vector2(99, 99), Vector2(100, 122), Vector2(90, 110)]), base.lightened(0.12))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(114, 97), Vector2(101, 99), Vector2(100, 122), Vector2(110, 110)]), base.darkened(0.05))
	_ci.draw_polyline(PackedVector2Array([Vector2(86, 97), Vector2(90, 110), Vector2(100, 122), Vector2(110, 110), Vector2(114, 97)]), piping, 2.0, true)
	_ci.draw_line(Vector2(100, 122), Vector2(100, 176), Color(piping, 0.7), 1.5)
	for y in [134.0, 150.0, 166.0]:
		_ci.draw_circle(Vector2(103, y), 2.2, piping)
	_ci.draw_rect(Rect2(76, 126, 14, 12), Color(piping, 0.7), false, 1.0)  # bolsillo / pocket
	_ci.draw_line(Vector2(66, 177), Vector2(134, 177), piping, 2.5)

	# Cuello y cabeza (se inclina un poco al estirarse) / Neck and head (tilts back when stretching)
	_ci.draw_rect(Rect2(93, 84, 14, 16), SKIN.lerp(SKIN_SHADE, 0.45))
	_use(Transform2D(-0.12 * stretch, Vector2(100, 92)) * Transform2D(0.0, Vector2(-100, -92)))
	_head(t, opts.get("glasses", true), opts.get("yawn", stretch))
	_use(Transform2D.IDENTITY)

	if armed:
		match outfit:
			"bat": _bat(t, attack, hand_r, arm_r)
			"shield": _pillow(t, attack, hand_l)
			"book": _book(t, cast, hand_r)
			"vacuum": _vacuum_nozzle(t, opts.get("aim", Vector2(1, 0.5)) * Vector2(facing, 1), opts.get("sucking", false), hand_r)

	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Gira una extremidad alrededor de su articulación / Rotates a limb around its joint
static func _limb(rot: float, pivot: Vector2) -> void:
	_use(Transform2D(rot, pivot) * Transform2D(0.0, -pivot))


static func _arm(rot: float, shoulder: Vector2, pts: PackedVector2Array, fill: Color, piping: Color, hand: Vector2, skin: Color) -> void:
	_limb(rot, shoulder)
	_shape(pts, fill)
	_ci.draw_line(pts[3] + Vector2(0, -4), pts[2] + Vector2(0, -4), piping, 4.0)
	_ci.draw_colored_polygon(_ellipse(hand, Vector2(7, 8)), skin)


# --- Cabeza / Head -----------------------------------------------------------

static func _head(t: float, glasses: bool, yawn: float) -> void:
	# Orejas / Ears
	_ci.draw_colored_polygon(_ellipse(Vector2(76, 68), Vector2(5, 7)), SKIN)
	_ci.draw_colored_polygon(_ellipse(Vector2(124, 68), Vector2(5, 7)), SKIN_SHADE)
	var face := _ellipse(Vector2(100, 64), Vector2(24, 27))
	_shape(face, SKIN)
	_ci.draw_colored_polygon(PackedVector2Array([
		Vector2(112, 40), Vector2(124, 58), Vector2(122, 76), Vector2(110, 90), Vector2(114, 70),
	]), Color(SKIN_SHADE, 0.55))
	_ci.draw_circle(Vector2(87, 78), 5, Color("f2a0ad", 0.22))
	_ci.draw_circle(Vector2(114, 78), 5, Color("f2a0ad", 0.18))

	# Pelo negro con reflejos azulados / Black hair with bluish highlights
	var hair := PackedVector2Array([
		Vector2(75, 70), Vector2(73, 52), Vector2(78, 40), Vector2(88, 33), Vector2(100, 30), Vector2(113, 32),
		Vector2(123, 40), Vector2(127, 52), Vector2(126, 70), Vector2(121, 58), Vector2(116, 54), Vector2(111, 58),
		Vector2(106, 52), Vector2(99, 57), Vector2(93, 51), Vector2(86, 57), Vector2(80, 54),
	])
	_ci.draw_colored_polygon(hair, HAIR)
	_ci.draw_polyline(PackedVector2Array([Vector2(80, 45), Vector2(88, 37), Vector2(98, 34)]), Color(HAIR_LIGHT, 0.8), 2.0, true)
	_ci.draw_polyline(PackedVector2Array([Vector2(84, 52), Vector2(92, 44)]), Color(HAIR_LIGHT, 0.5), 1.5, true)

	# Cejas, ojos y boca / Eyebrows, eyes and mouth
	_ci.draw_line(Vector2(85, 59), Vector2(95, 58), Color(HAIR, 0.85), 2.0, true)
	_ci.draw_line(Vector2(105, 58), Vector2(115, 59), Color(HAIR, 0.85), 2.0, true)
	# Parpadea de vez en cuando; con sueño entorna los ojos / Blinks now and then; squints when sleepy
	var blink := fposmod(t, 3.7) < 0.13 or yawn > 0.5
	for x: float in [90.0, 110.0]:
		if blink:
			_ci.draw_line(Vector2(x - 3, 67), Vector2(x + 3, 67), Color("2a2238"), 1.6, true)
		else:
			_ci.draw_colored_polygon(_ellipse(Vector2(x, 67), Vector2(2.6, 3.2), 12), Color("2a2238"))
			_ci.draw_circle(Vector2(x - 0.8, 66), 0.9, Color(1, 1, 1, 0.9))
	_ci.draw_line(Vector2(101, 70), Vector2(103, 76), Color(SKIN_SHADE, 0.9), 1.5, true)
	if yawn > 0.3:
		_ci.draw_colored_polygon(_ellipse(Vector2(100, 82), Vector2(3.5, 2.0 + 4.0 * yawn), 14), Color("7d4a5e"))
	else:
		_ci.draw_polyline(PackedVector2Array([Vector2(95, 81), Vector2(100, 82.5), Vector2(105, 81)]), Color("b77d86"), 1.2, true)
	if not glasses:
		return

	# Gafas / Glasses
	for cx: float in [90.0, 110.0]:
		var lens := _ellipse(Vector2(cx, 67), Vector2(9, 7), 24)
		_ci.draw_colored_polygon(lens, Color(RIM, 0.14))
		_ci.draw_polyline(lens + PackedVector2Array([lens[0]]), FRAME, 1.3, true)
	_ci.draw_line(Vector2(99, 65), Vector2(101, 65), FRAME, 1.3)
	_ci.draw_line(Vector2(81, 64), Vector2(76, 62), FRAME, 1.5)
	_ci.draw_line(Vector2(119, 64), Vector2(124, 62), FRAME, 1.5)
	# Reflejo de la luna en los cristales / Moon reflection on the lenses
	var g := fposmod(t * 0.3, 1.0)
	var gx := 83.0 + g * 30.0
	if g < 0.8:
		_ci.draw_line(Vector2(gx, 72), Vector2(gx + 4, 62), Color(1, 1, 1, 0.45), 1.5, true)


## Cabeza dormida sobre la almohada (vista desde arriba) / Sleeping head on the pillow (top view)
static func draw_sleeping(ci: CanvasItem, center: Vector2, scale: float, t: float) -> void:
	ci.draw_set_transform(center, -0.25, Vector2(scale, scale))
	ci.draw_colored_polygon(_ellipse(Vector2(0, 2), Vector2(22, 25)), SKIN)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-24, 4), Vector2(-22, -14), Vector2(-12, -26), Vector2(4, -29), Vector2(18, -22), Vector2(25, -6),
		Vector2(18, -10), Vector2(10, -6), Vector2(2, -12), Vector2(-6, -6), Vector2(-14, -10),
	]), HAIR)
	ci.draw_arc(Vector2(-8, 6), 4, 0.2, PI - 0.2, 8, Color("5a4258"), 1.5, true)
	ci.draw_arc(Vector2(8, 6), 4, 0.2, PI - 0.2, 8, Color("5a4258"), 1.5, true)
	ci.draw_circle(Vector2(-11, 13), 4, Color("f2a0ad", 0.3))
	ci.draw_circle(Vector2(11, 13), 4, Color("f2a0ad", 0.3))
	ci.draw_set_transform(Vector2.ZERO)


# --- Armas / Weapons --------------------------------------------------------

static func _bat(t: float, attack: float, hand: Vector2, arm: float) -> void:
	_use(Transform2D(0.55 - attack * 2.2 + arm * 0.5 + sin(t * 1.6) * 0.03, hand + Vector2(2, 2)))
	var bat := PackedVector2Array([
		Vector2(-3, 4), Vector2(3, 4), Vector2(8, -96), Vector2(5, -108), Vector2(-5, -108), Vector2(-8, -96),
	])
	_ci.draw_colored_polygon(bat, Color("c99a68"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(1, 4), Vector2(3, 4), Vector2(8, -96), Vector2(5, -108), Vector2(1, -108)]), Color("9e6f4a"))
	_ci.draw_line(Vector2(-5, -100), Vector2(-2, -20), Color(1, 1, 1, 0.3), 1.2)
	_ci.draw_rect(Rect2(-3.5, -14, 7, 16), Color("3a3355"))
	_use(Transform2D.IDENTITY)


static func _pillow(t: float, attack: float, hand: Vector2) -> void:
	# La sujeta con la mano izquierda y la empuja al atacar / Held in the left hand, shoved forward on attack
	_use(Transform2D(-0.12 + sin(t * 1.2) * 0.03 + attack * 0.25, hand + Vector2(-8 + attack * 18.0, -26)))
	# Almohada mullida con esquinas redondeadas / Fluffy pillow with rounded corners
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var c := Vector2(cos(a), sin(a))
		# superelipse para una forma de almohada / superellipse for a pillow shape
		var p := Vector2(signf(c.x) * pow(absf(c.x), 0.6) * 36.0, signf(c.y) * pow(absf(c.y), 0.6) * 26.0)
		pts.append(p * (1.0 - 0.06 * absf(sin(a * 2.0))))
	_ci.draw_colored_polygon(pts, Color("f3effc"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(4, -24), Vector2(34, -18), Vector2(34, 22), Vector2(4, 26)]), Color(0.45, 0.4, 0.75, 0.16))
	_ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("cfc6ee"), 1.5, true)
	_ci.draw_line(Vector2(-28, 0), Vector2(28, 0), Color("ddd5f4"), 1.0)
	DreamBackground.draw_star(_ci, Vector2(-2, -2), 3.5, Color(UITheme.GOLD, 0.9))
	_use(Transform2D.IDENTITY)


static func _book(t: float, cast: float, hand: Vector2) -> void:
	var y := sin(t * 1.8) * 4.0
	_use(Transform2D(-0.12 - cast * 0.3, hand + Vector2(20, -26 + y)))
	var glow := 50.0 + cast * 40.0
	_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(-glow, -glow - 6, glow * 2, glow * 2), false, Color(UITheme.GOLD, 0.35 + cast * 0.4))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(-28, -13), Vector2(0, -9), Vector2(0, 15), Vector2(-28, 11)]), Color("3b4fa8"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(28, -13), Vector2(0, -9), Vector2(0, 15), Vector2(28, 11)]), Color("34479c"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(-25, -11), Vector2(-1, -7), Vector2(-1, 12), Vector2(-25, 9)]), Color("fbf3dc"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(25, -11), Vector2(1, -7), Vector2(1, 12), Vector2(25, 9)]), Color("f1e6c8"))
	for ly in [-2.0, 3.0, 8.0]:
		_ci.draw_line(Vector2(-21, ly - 4), Vector2(-6, ly - 2), Color(0.3, 0.3, 0.5, 0.35), 1.0)
		_ci.draw_line(Vector2(6, ly - 2), Vector2(21, ly - 4), Color(0.3, 0.3, 0.5, 0.35), 1.0)
	# Chispas eléctricas / Electric sparks
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 8.0)
	for s in 2:
		var p := Vector2(rng.randf_range(-8, 8), -12)
		var pts := PackedVector2Array([p])
		for i in 4:
			p += Vector2(rng.randf_range(-8, 8), -rng.randf_range(5, 9))
			pts.append(p)
		_ci.draw_polyline(pts, Color(ACCENT["book"], 0.85), 1.4, true)
	_use(Transform2D.IDENTITY)


static func _vacuum_tank(t: float) -> void:
	var tank := _ellipse(Vector2(150, 252), Vector2(22, 30))
	_ci.draw_colored_polygon(tank, Color("e9e3f3"))
	_ci.draw_colored_polygon(_ellipse(Vector2(156, 254), Vector2(14, 26)), Color(0.4, 0.35, 0.7, 0.18))
	_ci.draw_colored_polygon(_ellipse(Vector2(148, 244), Vector2(10, 12)), Color(ACCENT["vacuum"], 0.45 + 0.15 * sin(t * 4.0)))
	_ci.draw_circle(Vector2(136, 280), 5, Color("3b3f73"))
	_ci.draw_circle(Vector2(164, 280), 5, Color("3b3f73"))


static func _vacuum_nozzle(t: float, aim: Vector2, sucking: bool, hand: Vector2) -> void:
	var dir := aim.normalized() if aim.length() > 0.01 else Vector2(1, 0.5).normalized()
	var tip := hand + dir * 52.0
	# Manguera de la cisterna a la mano / Hose from the tank to the hand
	var a := Vector2(150, 226)
	var mid := Vector2(166, 200)
	var pts := PackedVector2Array()
	for i in 17:
		var s := i / 16.0
		pts.append(a.lerp(mid, s).lerp(mid.lerp(hand, s), s))
	_ci.draw_polyline(pts, Color("4a4f86"), 5.0, true)
	_ci.draw_line(hand, tip, Color("b7b2d6"), 5.0, true)
	_use(Transform2D(dir.angle(), tip))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -6), Vector2(10, -11), Vector2(12, 11), Vector2(-4, 6)]), Color("4a4f86"))
	_ci.draw_line(Vector2(11, -11), Vector2(12, 11), Color(ACCENT["vacuum"], 0.9), 1.5)
	if sucking:
		for i in 3:
			var r := fposmod(t * 40.0 + i * 10.0, 30.0)
			_ci.draw_arc(Vector2(14 + 30 - r, 0), 3.0 + (30.0 - r) * 0.4, PI - 0.8, PI + 0.8, 10,
				Color(ACCENT["vacuum"], 0.8 * r / 30.0), 1.4, true)
	_use(Transform2D.IDENTITY)


# --- Estampados / Prints ----------------------------------------------------

static func _pattern(area: Rect2, pj: Dictionary) -> void:
	var col: Color = pj["pattern"]
	match pj["print"]:
		"stripes":
			var x := area.position.x + 4.0
			while x < area.end.x:
				_ci.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(col, 0.55), 2.2)
				x += 9.0
		"plaid":
			var y := area.position.y + 6.0
			while y < area.end.y:
				_ci.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(col, 0.55), 4.0)
				_ci.draw_line(Vector2(area.position.x, y + 5), Vector2(area.end.x, y + 5), Color("f6e9ef", 0.3), 1.0)
				y += 16.0
			var x := area.position.x + 6.0
			while x < area.end.x:
				_ci.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(col, 0.45), 4.0)
				x += 16.0
		"stars":
			var row := 0
			var y := area.position.y + 7.0
			while y < area.end.y - 3.0:
				var x := area.position.x + (6.0 if row % 2 == 0 else 14.0)
				while x < area.end.x - 3.0:
					_small_star(Vector2(x, y), 2.6, Color(col, 0.9))
					x += 16.0
				y += 13.0
				row += 1
		"dots":
			var row := 0
			var y := area.position.y + 6.0
			while y < area.end.y - 2.0:
				var x := area.position.x + (5.0 if row % 2 == 0 else 12.0)
				while x < area.end.x - 2.0:
					_ci.draw_circle(Vector2(x, y), 2.2, Color(col, 0.85))
					x += 14.0
				y += 11.0
				row += 1


static func _small_star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	_ci.draw_colored_polygon(pts, color)


# --- Utilidades / Helpers ---------------------------------------------------

static func _use(local: Transform2D) -> void:
	_local = local
	_ci.draw_set_transform_matrix(_xf * local)


## Relleno con luz de luna en el borde izquierdo / Fill with moonlight on the left edge
static func _shape(pts: PackedVector2Array, fill: Color) -> void:
	var base := _xf * _local
	_ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(-1.6, -1.0)))
	_ci.draw_colored_polygon(pts, Color(RIM, 0.55))
	_ci.draw_set_transform_matrix(base)
	_ci.draw_colored_polygon(pts, fill)


static func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _ellipse(c: Vector2, r: Vector2, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
