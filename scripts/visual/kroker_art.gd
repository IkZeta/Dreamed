class_name KrokerArt
extends RefCounted
## Dibuja a Kroker: un niño con gafas y pelo negro, siempre en pijama.
## Iluminado por la luna desde arriba a la izquierda, con sombras suaves y frías.
## Draws Kroker: a boy with glasses and black hair, always in pajamas.
## Moonlit from the upper left, with soft, cool shadows.
##
## Lienzo virtual de 200 x 300, pies en y = 288. Se dibuja con sprites recortables
## (tools/make_sprites.py) que se mueven en sus articulaciones.
## 200 x 300 virtual canvas, feet at y = 288. Drawn with cut-out sprites
## (tools/make_sprites.py) that move at their joints.

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
	"finger": {"base": Color("3a2457"), "pattern": Color("ff5f7a"), "piping": Color("7ff5ff"), "slippers": Color("ff5f7a"), "print": "bolts"},
	"teddy": {"base": Color("b8845e"), "pattern": Color("f4e2c8"), "piping": Color("f4e2c8"), "slippers": Color("6e432c"), "print": "paws"},
}

## Color de acento del arma / Weapon accent color
const ACCENT := {
	"": Color("f6d993"),
	"bat": Color("f6d993"),
	"shield": Color("f6d993"),
	"book": Color("fff0b8"),
	"vacuum": Color("b9f0ea"),
	"finger": Color("ff8fa2"),
	"teddy": Color("f4e9da"),
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
	var o := outfit if PAJAMAS.has(outfit) and outfit != "" else "bat"
	var mod := Sprites.flash_color(flash)

	# Sombra suave en el suelo / Soft ground shadow
	_use(Transform2D(0.0, Vector2(1.0, 0.2), 0.0, Vector2(100, 288)))
	ci.draw_circle(Vector2.ZERO, 44, Color(0.05, 0.03, 0.18, 0.35))
	_use(Transform2D.IDENTITY)

	# Segunda arma (desde El Chef): va en la mano libre / Second weapon (after The Chef): goes in the free hand
	var second: String = opts.get("second", "")
	var anim2: float = opts.get("anim2", 0.0)
	var show2: bool = second != "" and not opts.get("hide2", false)
	if (outfit == "vacuum" and armed) or (second == "vacuum" and show2):
		_vacuum_tank(t, mod)

	# Rebote al andar e inclinación / Walking bounce and lean
	var bob := -absf(sin(walk)) * 5.0 * moving
	_xf = _xf * Transform2D(lean, Vector2(100, 288 + bob)) * Transform2D(0.0, Vector2(-100, -288))

	# Qué lleva cada mano: el pijama decide la suya y la segunda arma va en la otra
	# What each hand holds: the pajama picks its hand and the second weapon goes in the other
	var hs := hands(outfit if armed else "", second if show2 else "")
	var main_hand: String = hs["main"] if armed else hand_of(outfit)
	var w_l := ""
	var w_r := ""
	var a_l := 0.0
	var a_r := 0.0
	if armed:
		if main_hand == "l":
			w_l = outfit
			a_l = attack if outfit in ["shield", "teddy", "bat"] else cast
		else:
			w_r = outfit
			a_r = cast if outfit in ["book", "finger"] else attack
	if show2:
		if hs["second"] == "r":
			w_r = second
			a_r = anim2
		else:
			w_l = second
			a_l = anim2

	# Ángulos de piernas y brazos / Leg and arm angles
	var swing := sin(walk) * 0.42 * moving
	var arm_l := _arm_pose(w_l, -swing * 0.8 + 2.7 * stretch, a_l, swing)
	var arm_r := _arm_pose(w_r, swing * 0.8 - 2.7 * stretch, a_r, swing)
	# Kroker es bajito: hombros y caderas más abajo, brazos y piernas cortos
	# Kroker is short: shoulders and hips sit lower, arms and legs are short
	const SH_L := Vector2(75, 184)
	const SH_R := Vector2(125, 184)
	var hand_l := SH_L + Vector2(-5, 53.3).rotated(arm_l)
	var hand_r := SH_R + Vector2(5, 53.3).rotated(arm_r)

	# Piernas / Legs
	_limb(swing, Vector2(87, 227))
	Sprites.draw(ci, "kroker_leg_l_" + o, mod)
	_limb(-swing, Vector2(113, 227))
	Sprites.draw(ci, "kroker_leg_r_" + o, mod)

	# Brazos (detrás del torso) / Arms (behind the torso)
	_limb(arm_l, SH_L)
	Sprites.draw(ci, "kroker_arm_l_" + o, mod)
	_limb(arm_r, SH_R)
	Sprites.draw(ci, "kroker_arm_r_" + o, mod)
	_use(Transform2D.IDENTITY)

	# En la mano izquierda, todo menos la almohada y el oso va por detrás del cuerpo
	# In the left hand, everything but the pillow and the teddy goes behind the body
	var aim_main: Vector2 = opts.get("aim", Vector2(1, 0.5))
	var aim_2: Vector2 = opts.get("aim2", Vector2(1, 0.5))
	var suck_main: bool = opts.get("sucking", false)
	var suck_2: bool = opts.get("sucking2", false)
	var l_behind := w_l != "" and not w_l in ["shield", "teddy"]
	if l_behind:
		_weapon(ci, w_l, t, hand_l, arm_l, Vector2(-5, 53.3).rotated(arm_l).normalized(), a_l,
			aim_2 * Vector2(facing, 1), suck_2, mod, true)

	# Pijama / Pajamas
	Sprites.draw(ci, "kroker_torso_" + o, mod)

	# Cabeza (se inclina un poco al estirarse) / Head (tilts back when stretching)
	_use(Transform2D(-0.12 * stretch, Vector2(100, 170)) * Transform2D(0.0, Vector2(-100, -170)))
	_head(t, opts.get("glasses", true), opts.get("yawn", stretch), mod)
	_use(Transform2D.IDENTITY)

	# Armas en las manos / Weapons in the hands
	if w_l != "" and not l_behind:
		var mine := w_l == outfit and main_hand == "l"
		_weapon(ci, w_l, t, hand_l, arm_l, Vector2(-5, 53.3).rotated(arm_l).normalized(), a_l,
			(aim_main if mine else aim_2) * Vector2(facing, 1), suck_main if mine else suck_2, mod)
	if w_r != "":
		var mine := w_r == outfit and main_hand == "r"
		_weapon(ci, w_r, t, hand_r, arm_r, Vector2(5, 53.3).rotated(arm_r).normalized(), a_r,
			(aim_main if mine else aim_2) * Vector2(facing, 1), suck_main if mine else suck_2, mod)

	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Mano con la que se lleva cada arma: almohada y oso en la izquierda, el resto en la derecha
## Hand each weapon is held in: pillow and teddy in the left, the rest in the right
static func hand_of(weapon: String) -> String:
	return "l" if weapon in ["shield", "teddy"] else "r"


## Reparte las dos armas entre las manos: cada una en la suya y, si las dos quieren la derecha
## (el bate con el libro, la aspiradora o la pistola de dedos), el bate pasa a la izquierda.
## Splits the two weapons between the hands: each in its own and, if both want the right one
## (the bat with the book, the vacuum or the finger gun), the bat moves to the left.
static func hands(main: String, second: String) -> Dictionary:
	if main == "":
		# Sin arma principal (la ha soltado), la segunda va en su mano de siempre
		# With no main weapon (dropped), the second one goes in its usual hand
		return {"main": "", "second": hand_of(second)}
	var hm := hand_of(main)
	if second == "":
		return {"main": hm, "second": ""}
	var hs := hand_of(second)
	if hm == hs:
		if main == "bat":
			hm = "l" if hs == "r" else "r"
		elif second == "bat":
			hs = "l" if hm == "r" else "r"
		else:
			hs = "l" if hm == "r" else "r"
	return {"main": hm, "second": hs}


## Ángulo del brazo según lo que lleve en la mano y cómo esté atacando
## Arm angle depending on what the hand holds and how it's attacking
static func _arm_pose(w: String, base: float, a: float, swing: float) -> float:
	match w:
		"bat": return (base - 0.9 * a) * 0.5        # el bate pesa / the bat is heavy
		"vacuum": return base * 0.5
		"book": return base - 1.2 * a
		"shield", "teddy": return base - 1.25 * a
		# Apunta con el dedo hacia delante y da un respingo al disparar / Points forward and kicks up when firing
		"finger": return -1.3 + swing * 0.15 - 0.35 * a
	return base


## Dibuja un arma en una mano / Draws a weapon in a hand
static func _weapon(ci: CanvasItem, w: String, t: float, hand: Vector2, arm: float, arm_dir: Vector2, a: float, aim: Vector2, sucking: bool, mod: Color, left := false) -> void:
	match w:
		"bat": _bat(t, a, hand, arm, mod, left)
		"shield": _pillow(t, a, hand, mod)
		"book": _book(t, a, hand, mod)
		"vacuum": _vacuum_nozzle(t, aim, sucking, hand, mod)
		"finger":
			_use(Transform2D.IDENTITY)
			finger_gun(ci, _xf, hand + arm_dir * 3.0, arm_dir, a, "weapon_finger", 1.0)
		"teddy": _teddy(t, a, hand, mod)


## Gira una extremidad alrededor de su articulación / Rotates a limb around its joint
static func _limb(rot: float, pivot: Vector2) -> void:
	_use(Transform2D(rot, pivot) * Transform2D(0.0, -pivot))


# --- Cabeza / Head -----------------------------------------------------------

static func _head(t: float, glasses: bool, yawn: float, mod: Color) -> void:
	# La cara va pintada en el sprite: ojos, boca y gafas / The face is painted on the sprite: eyes, mouth and glasses
	var face := ""
	if yawn > 0.3:
		face = "_yawn"
	elif fposmod(t, 3.7) < 0.13 or yawn > 0.5:
		face = "_blink"   # parpadea de vez en cuando / blinks now and then
	Sprites.draw(_ci, "kroker_head" + face + ("_g" if glasses else ""), mod)


## Cabeza dormida sobre la almohada (vista desde arriba) / Sleeping head on the pillow (top view)
static func draw_sleeping(ci: CanvasItem, center: Vector2, scale: float, _t: float, turn := 0.0) -> void:
	ci.draw_set_transform(center, -0.25 + turn, Vector2(scale, scale))
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

static func _bat(t: float, attack: float, hand: Vector2, arm: float, mod: Color, left := false) -> void:
	# En la izquierda descansa inclinado hacia atrás y golpea hacia delante / In the left hand it rests tilted back and swings forward
	var rot := (-0.5 + attack * 1.4 + arm * 0.3) if left else (0.55 - attack * 2.2 + arm * 0.5)
	_use(Transform2D(rot + sin(t * 1.6) * 0.03, hand + Vector2(2, 2)))
	Sprites.draw(_ci, "weapon_bat", mod)
	_use(Transform2D.IDENTITY)


static func _pillow(t: float, attack: float, hand: Vector2, mod: Color) -> void:
	# La sujeta con la mano izquierda y la empuja al atacar / Held in the left hand, shoved forward on attack
	_use(Transform2D(-0.12 + sin(t * 1.2) * 0.03 + attack * 0.25, hand + Vector2(-8 + attack * 18.0, -26)))
	Sprites.draw(_ci, "weapon_pillow", mod)
	_use(Transform2D.IDENTITY)


static func _book(t: float, cast: float, hand: Vector2, mod: Color) -> void:
	var y := sin(t * 1.8) * 4.0
	_use(Transform2D(-0.12 - cast * 0.3, hand + Vector2(20, -26 + y)))
	var glow := 50.0 + cast * 40.0
	_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(-glow, -glow - 6, glow * 2, glow * 2), false, Color(UITheme.GOLD, 0.35 + cast * 0.4))
	Sprites.draw(_ci, "weapon_book", mod)
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


## Mano haciendo la pistola (sprite con la forma que pidió el autor: puño redondeado, pulgar
## recto hacia arriba e índice apuntando) y un fogonazo en la punta al disparar.
## "base" es la transformación del lienzo donde se dibuja.
## Hand making a finger gun (sprite shaped as the author asked: rounded fist, thumb straight up
## and index finger pointing) and a flash at the tip when firing. "base" is the canvas transform.
const FINGER_TIP := Vector2(18.5, -3.0)


static func finger_gun(ci: CanvasItem, base: Transform2D, hand: Vector2, dir: Vector2, cast: float, sprite := "weapon_finger", scale := 1.0) -> void:
	var flip := -1.0 if dir.x < 0.0 else 1.0
	var local := Transform2D(dir.angle(), Vector2(scale, scale * flip), 0.0, hand)
	ci.draw_set_transform_matrix(base * local)
	Sprites.draw(ci, sprite)
	if cast > 0.4:
		var k := (cast - 0.4) / 0.6
		ci.draw_circle(FINGER_TIP + Vector2(4, 0), 7.0 * k, Color(ACCENT["finger"], 0.8 * k))
		ci.draw_circle(FINGER_TIP + Vector2(4, 0), 3.5 * k, Color(1, 1, 1, 0.9 * k))
	ci.draw_set_transform_matrix(base)


## El osito en la mano izquierda; al atacar lo estira hacia delante / The teddy in the left hand; pushed forward to attack
static func _teddy(t: float, attack: float, hand: Vector2, mod: Color) -> void:
	_use(Transform2D(-0.1 + sin(t * 1.3) * 0.05 + attack * 0.3, hand + Vector2(-4 + attack * 14.0, -14)))
	Sprites.draw(_ci, "weapon_teddy", mod)
	_use(Transform2D.IDENTITY)


static func _vacuum_tank(t: float, mod: Color) -> void:
	Sprites.draw(_ci, "weapon_tank", mod)
	# La ventanita brilla con lo que ha tragado / The little window glows with what it swallowed
	_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(148, 244) - Vector2(16, 18), Vector2(32, 36)), false,
		Color(ACCENT["vacuum"], 0.3 + 0.2 * sin(t * 4.0)))


static func _vacuum_nozzle(t: float, aim: Vector2, sucking: bool, hand: Vector2, mod: Color) -> void:
	var dir := aim.normalized() if aim.length() > 0.01 else Vector2(1, 0.5).normalized()
	var tip := hand + dir * 52.0
	# Manguera de la cisterna a la mano / Hose from the tank to the hand
	var a := Vector2(150, 226)
	var mid := Vector2(166, 232)
	var pts := PackedVector2Array()
	for i in 17:
		var s := i / 16.0
		pts.append(a.lerp(mid, s).lerp(mid.lerp(hand, s), s))
	_ci.draw_polyline(pts, Color("2f3361"), 7.0, true)
	_ci.draw_polyline(pts, Color("4a4f86"), 5.0, true)
	_ci.draw_polyline(pts, Color("7a80bd", 0.6), 1.5, true)
	_ci.draw_line(hand, tip, Color("8f8ab3"), 6.0, true)
	_ci.draw_line(hand, tip, Color("cfcaea"), 3.5, true)
	_use(Transform2D(dir.angle(), tip))
	Sprites.draw(_ci, "weapon_nozzle", mod)
	if sucking:
		for i in 3:
			var r := fposmod(t * 40.0 + i * 10.0, 30.0)
			_ci.draw_arc(Vector2(14 + 30 - r, 0), 3.0 + (30.0 - r) * 0.4, PI - 0.8, PI + 0.8, 10,
				Color(ACCENT["vacuum"], 0.8 * r / 30.0), 1.4, true)
	_use(Transform2D.IDENTITY)


# --- Utilidades / Helpers ---------------------------------------------------

static func _use(local: Transform2D) -> void:
	_local = local
	_ci.draw_set_transform_matrix(_xf * local)


static func _ellipse(c: Vector2, r: Vector2, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
