class_name FX
extends Node2D
## Efectos visuales de la partida dibujados en una sola capa: números de daño que saltan,
## chispas de golpe, confeti de estrellas al morir, ondas expansivas, destellos, remolinos de los
## agujeros, columnas de luz al subir de nivel, rayos, tajos, anillos y disipaciones.
## Todo es del mismo estilo de sueño: estrellas de cuatro puntas, colores pastel y un poco de brillo.
## In-game visual effects drawn on one layer: bouncing damage numbers, hit sparks, star confetti
## on death, shockwaves, flashes, hole whirlpools, light pillars on level-up, lightning bolts,
## swings, rings and dissipations. All in the same dreamy style: four-point stars, pastel colours
## and a little glow.

## Como mucho tantas partículas a la vez (los textos siempre entran) / At most this many particles at once (texts always get in)
const MAX_ITEMS := 600
## Cifras pequeñas de daño por fotograma: en una pelea llena, las demás sobran
## Small damage numbers per frame: in a packed fight the rest are just clutter
const NUMBERS_PER_FRAME := 3
## Color de los destellos de cada enemigo al morir / Each enemy's flash colour on death
const DEATH_COLORS := {
	"foox": Color("9fe8ff"), "golden_foox": Color("ffe36a"), "thug": Color("ff9fb0"), "sling": Color("ffb88a"),
	"skeleton": Color("f4f1ea"), "nest": Color("c9b8ff"), "mosquito": Color("ff8fc8"), "botcher": Color("ffcf8a"),
	"cyber": Color("5ff2ff"), "puppet": Color("e8a6d8"), "golem": Color("f7f2ea"), "police": Color("8fb8ff"),
	"van": Color("ff6a8a"), "riot": Color("a8b0d0"), "alarm": Color("ff8a5c"), "exam": Color("ff6a6a"),
	"dreamcatcher": Color("b48cff"), "chef": Color("ffb04a"),
}
const INK := Color("140e26")

var _items: Array[Dictionary] = []
var _sparks_this_frame := 0
var _swing_flip := 1.0
var _numbers_this_frame := 0


func _ready() -> void:
	z_index = 50


func _room() -> bool:
	return _items.size() < MAX_ITEMS


## Número o palabra que salta: aparece grande, rebota, cae en arco y se desvanece.
## "big" para golpes fuertes y cifras importantes.
## A number or word that pops: appears big, bounces, falls in an arc and fades. "big" for heavy
## hits and important figures.
func text(pos: Vector2, value: String, color := UITheme.BONE, size := 22, big := false) -> void:
	# El mundo se ve a la mitad (pixel art): los textos van un poco más grandes para leerse
	# The world is shown at half size (pixel art): texts are a bit bigger to stay readable
	size = int(size * 1.35)
	var numeric := value.is_valid_float()
	if numeric and not big:
		_numbers_this_frame += 1
		if _numbers_this_frame > NUMBERS_PER_FRAME or not _room():
			return
	var life := 0.95 if big else 0.8
	_items.append({"kind": "text", "pos": pos, "text": value, "color": color, "size": size,
		"life": life, "max": life, "big": big, "num": numeric,
		"vel": Vector2(randf_range(-60, 60), -190) if numeric else Vector2(randf_range(-14, 14), -70)})


func bolt(points: PackedVector2Array, color := UITheme.GOLD) -> void:
	_items.append({"kind": "bolt", "points": points, "color": color, "life": 0.3, "max": 0.3})


## Tajo: una media luna que barre de un lado a otro y se afina en las puntas (ver _draw_swing).
## Cada tajo barre hacia el lado contrario que el anterior, como un combo.
## Slash: a crescent sweeping from one side to the other and tapering at the tips (see _draw_swing).
## Each slash sweeps the opposite way to the last one, like a combo.
func swing(center: Vector2, radius: float, angle: float, spread: float, color := UITheme.BONE, width := 6.0) -> void:
	_swing_flip = -_swing_flip
	_items.append({"kind": "swing", "pos": center, "r": radius, "a": angle, "s": spread,
		"color": color, "w": width, "flip": _swing_flip, "life": 0.24, "max": 0.24})


func ring(center: Vector2, radius: float, color := UITheme.MIST, life := 0.5, grow := 1.6) -> void:
	_items.append({"kind": "ring", "pos": center, "r": radius, "color": color,
		"life": life, "max": life, "grow": grow})


func telegraph(center: Vector2, life: float) -> void:
	_items.append({"kind": "tele", "pos": center, "life": life, "max": life})


func dissipate(center: Vector2, color := UITheme.BONE) -> void:
	for i in 14:
		var a := randf() * TAU
		_items.append({"kind": "mote", "pos": center + Vector2(randf_range(-14, 14), randf_range(-24, 0)),
			"vel": Vector2(cos(a), sin(a)) * randf_range(30, 110) + Vector2(0, -40),
			"color": color, "life": randf_range(0.5, 0.9), "max": 0.9, "r": randf_range(1.5, 3.5)})


## Chispas de golpe: rayitas que salen disparadas hacia "dir" (más o menos) y un destello blanco
## Hit sparks: little streaks shooting out roughly towards "dir" and a white flash
func spark(pos: Vector2, dir: Vector2, color := UITheme.BONE, n := 4, power := 1.0) -> void:
	_sparks_this_frame += 1
	if _sparks_this_frame > 14 or not _room():
		return
	if dir == Vector2.ZERO:
		dir = Vector2.from_angle(randf() * TAU)
	dir = dir.normalized()
	for i in n:
		var a := dir.angle() + randf_range(-0.9, 0.9)
		_items.append({"kind": "spark", "pos": pos, "vel": Vector2.from_angle(a) * randf_range(320, 640) * power,
			"color": color if i % 2 == 0 else Color.WHITE, "life": 0.2, "max": 0.2, "len": randf_range(18, 30) * power})
	_items.append({"kind": "flash", "pos": pos, "r": 24.0 * power, "color": Color(color.lerp(Color.WHITE, 0.5), 0.9), "life": 0.1, "max": 0.1})


## Destello suave y redondo (sin bordes) / A soft round flash (no edges)
func flash(pos: Vector2, radius: float, color := Color.WHITE, life := 0.18) -> void:
	_items.append({"kind": "flash", "pos": pos, "r": radius, "color": color, "life": life, "max": life})


## Onda expansiva gruesa que se adelgaza al crecer / A thick shockwave that thins as it grows
func shock(pos: Vector2, radius: float, color := UITheme.BONE, life := 0.35, width := 10.0) -> void:
	_items.append({"kind": "shock", "pos": pos, "r": radius, "color": color, "life": life, "max": life, "w": width})


## Confeti de sueño al morir un enemigo: estrellitas que giran, motas, un destello y una onda
## Dream confetti when an enemy dies: spinning little stars, motes, a flash and a wave
func burst(pos: Vector2, color := UITheme.BONE, big := false) -> void:
	if not _room():
		return
	var n := 12 if big else 7
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(120, 300) * (1.4 if big else 1.0)
		_items.append({"kind": "star", "pos": pos, "vel": Vector2.from_angle(a) * sp + Vector2(0, -120),
			"color": color if i % 3 != 0 else (UITheme.GOLD if i % 2 == 0 else Color.WHITE),
			"life": randf_range(0.45, 0.8), "max": 0.8, "r": randf_range(4.0, 7.0) * (1.3 if big else 1.0),
			"spin": randf_range(-12, 12), "rot": randf() * TAU, "g": 520.0})
	flash(pos, 46.0 if big else 30.0, Color(color, 0.85), 0.16)
	shock(pos, 26.0 if big else 18.0, color, 0.32, 8.0 if big else 6.0)


## Remolino del agujero: motas que caen en espiral hacia el centro y un pozo morado que late
## The hole's whirlpool: motes spiralling into the middle and a pulsing purple well
func vortex(pos: Vector2, color := Color("b48cff")) -> void:
	if not _room():
		return
	for i in 14:
		_items.append({"kind": "swirl", "pos": pos, "a": i * TAU / 14.0 + randf() * 0.3, "d": randf_range(50, 90),
			"color": color if i % 2 == 0 else Color.WHITE, "life": randf_range(0.45, 0.6), "max": 0.6})
	_items.append({"kind": "well", "pos": pos, "color": color, "life": 0.5, "max": 0.5})


## Columna de luz al subir de nivel: un haz que sube con motas doradas
## A light pillar on level-up: a beam rising with golden motes
func pillar(pos: Vector2, color := UITheme.GOLD) -> void:
	_items.append({"kind": "pillar", "pos": pos, "color": color, "life": 1.0, "max": 1.0})
	for i in 16:
		_items.append({"kind": "star", "pos": pos + Vector2(randf_range(-26, 26), randf_range(-10, 10)),
			"vel": Vector2(randf_range(-20, 20), randf_range(-320, -160)), "color": color if i % 2 else Color.WHITE,
			"life": randf_range(0.6, 1.0), "max": 1.0, "r": randf_range(3.0, 6.0), "spin": randf_range(-6, 6), "rot": 0.0, "g": 0.0})
	shock(pos, 30.0, color, 0.5, 10.0)


## Brillito de recoger un trozo de estrella / A little sparkle when picking up a star shard
func twinkle(pos: Vector2, color := UITheme.GOLD) -> void:
	if not _room():
		return
	_items.append({"kind": "twinkle", "pos": pos, "color": color, "life": 0.3, "max": 0.3})


## Zarpazo: «n» garras curvas y afiladas que se trazan de golpe en diagonal sobre el blanco y se
## apagan. "angle" es hacia dónde va el golpe; "size", el tamaño de las garras.
## Claw swipe: "n" curved, sharp claws drawn in one stroke diagonally over the target, then fading.
## "angle" is where the blow travels; "size", the claws' size.
func claw(center: Vector2, angle: float, size := 30.0, color := UITheme.BONE, n := 3, life := 0.3) -> void:
	if not _room():
		return
	_items.append({"kind": "claw", "pos": center, "a": angle, "r": size, "n": n, "color": color,
		"flip": 1.0 if randf() < 0.5 else -1.0, "life": life, "max": life})


## Rastro del salto de la pantera: una estela de sombra y huellas que se apagan de la salida a la presa
## The panther's leap trail: a shadow streak and paw prints fading from the start to the prey
func pounce(from: Vector2, to: Vector2, color := UITheme.BONE) -> void:
	_items.append({"kind": "pounce", "pos": from, "to": to, "color": color, "life": 0.45, "max": 0.45})


## Picado del buitre: baja en picado desde arriba, raja con las garras y suelta unas plumas
## The vulture's dive: swoops down from above, rakes with its talons and sheds a few feathers
func talon(center: Vector2, angle: float, color := UITheme.BONE) -> void:
	if not _room():
		return
	_items.append({"kind": "dive", "pos": center, "color": color, "side": 1.0 if randf() < 0.5 else -1.0, "life": 0.22, "max": 0.22})
	claw(center + Vector2(0, -6), PI * 0.5 + clampf(angle, -0.6, 0.6) * 0.3, 30.0, color, 2, 0.28)
	for i in 3:
		_items.append({"kind": "feather", "pos": center + Vector2(randf_range(-14, 14), randf_range(-30, -10)),
			"vel": Vector2(randf_range(-60, 60), randf_range(-90, -40)), "rot": randf() * TAU,
			"spin": randf_range(-3.0, 3.0), "color": color, "ph": randf() * TAU, "life": 0.9, "max": 0.9})


func clear() -> void:
	_items.clear()


func _process(delta: float) -> void:
	_sparks_this_frame = 0
	_numbers_this_frame = 0
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		it["life"] = float(it["life"]) - delta
		if float(it["life"]) <= 0.0:
			_items.remove_at(i)
			continue
		if it.has("vel"):
			var v: Vector2 = it["vel"]
			it["pos"] = Vector2(it["pos"]) + v * delta
			match it["kind"]:
				"text":
					# Los números caen en arco; las palabras suben y frenan / Numbers fall in an arc; words rise and slow down
					if it["num"]:
						v.y += 520.0 * delta
						v.x *= 1.0 - 1.5 * delta
					else:
						v *= 1.0 - 2.0 * delta
				"spark":
					v *= 1.0 - 9.0 * delta
				"star":
					v *= 1.0 - 2.5 * delta
					v.y += float(it["g"]) * delta
					it["rot"] = float(it["rot"]) + float(it["spin"]) * delta
				"feather":
					# Cae despacio meciéndose de lado a lado / Falls slowly, rocking side to side
					v *= 1.0 - 3.0 * delta
					v.y += 70.0 * delta
					v.x += sin(float(it["life"]) * 9.0 + float(it["ph"])) * 220.0 * delta
					it["rot"] = float(it["rot"]) + float(it["spin"]) * delta
				_:
					v *= 1.0 - 2.0 * delta
			it["vel"] = v
	queue_redraw()


func _draw() -> void:
	var font := UITheme.font("caps")
	var digits := UITheme.font("display")
	var soft := DreamBackground.soft_texture()
	for it in _items:
		var k := float(it["life"]) / float(it["max"])  # 1 → 0
		var col: Color = it.get("color", UITheme.BONE)
		match it["kind"]:
			"text":
				var age := float(it["max"]) - float(it["life"])
				# Aparece de golpe más grande y rebota a su tamaño / Pops in bigger and bounces to its size
				var pop := 1.0 + (0.9 if it["big"] else 0.5) * maxf(0.0, 1.0 - age / 0.12) - 0.12 * sin(clampf(age / 0.25, 0.0, 1.0) * PI)
				var sz := maxi(8, int(float(it["size"]) * pop * (1.25 if it["big"] else 1.0)))
				var c := Color(col, minf(1.0, k * 2.5))
				var s := String(it["text"])
				# Las cifras con la fuente gorda del reloj; las palabras con la de siempre
				# Figures in the clock's chunky font; words in the usual one
				var f: Font = digits if it["num"] else font
				var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
				var p := Vector2(it["pos"]) - Vector2(w / 2.0, 0)
				UITheme.ink_text(self, f, p.round(), s, sz, c, 2.0)
			"claw":
				_draw_claw(it, k, col)
			"pounce":
				_draw_pounce(it, k, col)
			"dive":
				# Estela en cuña que baja en picado / A wedge streak diving down
				var to := Vector2(it["pos"])
				var e := minf(1.0, (1.0 - k) / 0.5)
				var from := to + Vector2(70.0 * float(it["side"]), -170.0)
				var head := from.lerp(to, e)
				var nrm := (to - from).normalized().orthogonal()
				var tail := from.lerp(to, maxf(0.0, e - 0.6))
				draw_colored_polygon(PackedVector2Array([tail, head + nrm * 9.0, head - nrm * 9.0]), Color(col, 0.35 * k))
				draw_colored_polygon(PackedVector2Array([tail, head + nrm * 4.0, head - nrm * 4.0]), Color(1, 1, 1, 0.7 * k))
			"feather":
				_draw_feather(Vector2(it["pos"]), float(it["rot"]), Color(col, minf(1.0, k * 2.0)))
			"bolt":
				_draw_bolt(it["points"], k, col)
			"swing":
				_draw_swing(it, k, col)
			"ring":
				var r := float(it["r"]) * lerpf(float(it["grow"]), 1.0, k)
				draw_arc(it["pos"], r, 0, TAU, 48, Color(col, k * 0.8), 2.0, true)
			"tele":
				var p := 1.0 - k
				var c := Vector2(it["pos"])
				draw_arc(c, 30.0 * (1.0 - p) + 10.0, 0, TAU, 40, Color(UITheme.MIST, 0.25 + 0.5 * p), 1.5, true)
				draw_circle(c, 18.0 * p, Color(UITheme.MIST, 0.12 * p))
			"mote":
				draw_circle(it["pos"], float(it["r"]) * k, Color(col, k * 0.8))
			"spark":
				var p: Vector2 = it["pos"]
				var v: Vector2 = it["vel"]
				var tail := v.normalized() * float(it["len"]) * k
				draw_line(p - tail, p, Color(col, k), 4.0 * k + 2.0)
			"flash":
				var r := float(it["r"]) * (1.4 - 0.4 * k)
				draw_texture_rect(soft, Rect2(Vector2(it["pos"]) - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(col, col.a * k))
				draw_circle(it["pos"], r * 0.45 * k, Color(1, 1, 1, 0.7 * k))
			"shock":
				var e := 1.0 - pow(k, 2.5)
				var r := float(it["r"]) * (1.0 + e * 2.6)
				draw_arc(it["pos"], r, 0, TAU, 40, Color(col, 0.9 * k), maxf(1.0, float(it["w"]) * k), true)
				draw_circle(it["pos"], r, Color(col, 0.08 * k))
			"star":
				_star(Vector2(it["pos"]), float(it["r"]) * (0.4 + 0.6 * k), float(it["rot"]), Color(col, minf(1.0, k * 1.8)))
			"swirl":
				var f := 1.0 - k
				var a := float(it["a"]) + f * 5.0
				var d := float(it["d"]) * (1.0 - f)
				var p := Vector2(it["pos"]) + Vector2(cos(a) * d, sin(a) * d * 0.5) + Vector2(0, -6)
				draw_circle(p, 2.5 + 1.5 * k, Color(col, 0.9 * sin(f * PI)))
			"well":
				var f := 1.0 - k
				draw_set_transform(it["pos"], 0.0, Vector2(1.0, 0.5))
				draw_circle(Vector2.ZERO, 40.0 * sin(f * PI), Color(0.06, 0.02, 0.15, 0.55 * k))
				draw_arc(Vector2.ZERO, 46.0 * (1.0 - f * 0.6), 0, TAU, 32, Color(col, 0.9 * k), 4.0, true)
				draw_set_transform(Vector2.ZERO)
				draw_texture_rect(soft, Rect2(Vector2(it["pos"]) - Vector2(60, 40), Vector2(120, 80)), false, Color(col, 0.4 * k))
			"pillar":
				var p: Vector2 = it["pos"]
				var f := 1.0 - k
				var h := 420.0 * minf(1.0, f * 4.0)
				var w := 46.0 * (1.0 - f * 0.6)
				draw_texture_rect(soft, Rect2(p + Vector2(-w * 1.6, -h), Vector2(w * 3.2, h + 30)), false, Color(col, 0.35 * k))
				draw_rect(Rect2(p + Vector2(-w * 0.35, -h), Vector2(w * 0.7, h)), Color(col, 0.35 * k))
				draw_rect(Rect2(p + Vector2(-w * 0.12, -h), Vector2(w * 0.24, h)), Color(1, 1, 1, 0.55 * k))
			"twinkle":
				var f := 1.0 - k
				_star(it["pos"], 4.0 + 10.0 * sin(f * PI), f * 2.0, Color(col, k))
				draw_circle(it["pos"], 2.0 * k, Color(1, 1, 1, k))


## Estrella de cuatro puntas (la de todo el juego) / Four-point star (the game-wide one)
## Tajo en media luna: la cabeza barre el arco en la primera mitad y la cola la alcanza después.
## Es gordo cerca de la cabeza y acaba en punta por los dos lados; lleva contorno de tinta, el
## color del arma y un filo blanco por fuera. Se dibuja a trozos (cuadriláteros) para que nunca
## salga un polígono imposible.
## Crescent slash: the head sweeps the arc in the first half and the tail catches up afterwards.
## It's fat near the head and pointed at both ends; it has an ink outline, the weapon's colour and
## a white edge on the outside. It's drawn in pieces (quads) so it never makes an impossible polygon.
func _draw_swing(it: Dictionary, k: float, col: Color) -> void:
	var c := Vector2(it["pos"])
	var r := float(it["r"])
	var a := float(it["a"])
	var sp := minf(float(it["s"]), PI)
	var flip := float(it.get("flip", 1.0))
	var age := 1.0 - k
	var head := 1.0 - pow(1.0 - minf(1.0, age / 0.45), 2.0)
	var tail := clampf((age - 0.3) / 0.7, 0.0, 1.0) * 0.9
	var a0 := a - sp * flip
	var a1 := a + sp * flip
	var from := lerpf(a0, a1, tail)
	var to := lerpf(a0, a1, head)
	var thick := float(it["w"]) * 2.4 + r * 0.16
	var fade := minf(1.0, k * 2.6)
	var n := clampi(int(absf(to - from) / 0.1), 4, 40)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var core := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		var ang := lerpf(from, to, u)
		var th := thick * sin(PI * pow(u, 1.8))
		var d := Vector2.from_angle(ang)
		outer.append(c + d * (r + th * 0.35))
		inner.append(c + d * (r - th * 0.65))
		core.append(c + d * (r + th * 0.02))
	for pass_i in 3:
		for i in n:
			var o0 := outer[i]
			var o1 := outer[i + 1]
			var i0 := inner[i] if pass_i < 2 else core[i]
			var i1 := inner[i + 1] if pass_i < 2 else core[i + 1]
			if pass_i == 0:
				# Contorno de tinta: un poco más ancho / Ink outline: a little wider
				o0 += (o0 - c).normalized() * 2.0
				o1 += (o1 - c).normalized() * 2.0
				i0 -= (i0 - c).normalized() * 2.0
				i1 -= (i1 - c).normalized() * 2.0
			if o0.distance_squared_to(i0) < 0.5 and o1.distance_squared_to(i1) < 0.5:
				continue
			var quad := PackedVector2Array([o0, o1, i1, i0]) if o1.distance_squared_to(i1) > 0.05 else PackedVector2Array([o0, o1, i0])
			if o0.distance_squared_to(i0) < 0.05:
				quad = PackedVector2Array([o0, o1, i1])
			var qc: Color = [Color(INK, 0.55 * fade), Color(col, 0.9 * fade), Color(1, 1, 1, 0.85 * fade)][pass_i]
			draw_colored_polygon(quad, qc)


## Rayo: resplandor ancho, cuerpo de color y alma blanca. Si es un tramo recto (un enlace entre
## dos puntos) se dibuja como un haz que se afina, con un nudo de luz en cada extremo; si es
## quebrado (un rayo de verdad) le salen dos ramitas y estalla al llegar.
## Bolt: a wide glow, a coloured body and a white core. A straight stretch (a link between two
## points) is drawn as a tapering beam with a knot of light at each end; a jagged one (real
## lightning) grows two little forks and bursts where it lands.
func _draw_bolt(points: PackedVector2Array, k: float, col: Color) -> void:
	if points.size() < 2:
		return
	var soft := DreamBackground.soft_texture()
	var last := points[points.size() - 1]
	if points.size() == 2:
		var a := points[0]
		var nrm := (last - a).normalized().orthogonal()
		for layer: Array in [[11.0, 4.0, Color(col, 0.3 * k)], [6.0, 2.0, Color(col, k)], [2.5, 1.0, Color(1, 1, 1, k)]]:
			var w0: float = layer[0] * (0.4 + 0.6 * k)
			var w1: float = layer[1]
			draw_colored_polygon(PackedVector2Array([a + nrm * w0, last + nrm * w1, last - nrm * w1, a - nrm * w0]), layer[2])
		for q: Vector2 in [a, last]:
			draw_texture_rect(soft, Rect2(q - Vector2(16, 16), Vector2(32, 32)), false, Color(col, 0.8 * k))
			draw_circle(q, 3.5 * k + 1.0, Color(1, 1, 1, k))
		return
	draw_polyline(points, Color(col, 0.28 * k), 22.0)
	draw_polyline(points, Color(col, k), 8.0)
	# Ramitas: salen de dos codos, hacia fuera / Forks: out of two elbows, pointing away
	for idx: int in [points.size() / 3, points.size() * 2 / 3]:
		if idx <= 0 or idx >= points.size() - 1:
			continue
		var p := points[idx]
		var along := (points[idx + 1] - points[idx - 1]).normalized()
		var side := 1.0 if int(p.x + p.y) % 2 == 0 else -1.0
		var q1 := p + (along * 0.6 + along.orthogonal() * side).normalized() * 26.0
		var q2 := q1 + (along + along.orthogonal() * side * 0.3).normalized() * 18.0
		draw_polyline(PackedVector2Array([p, q1, q2]), Color(col, 0.9 * k), 4.0)
		draw_polyline(PackedVector2Array([p, q1, q2]), Color(1, 1, 1, k), 1.5)
	draw_polyline(points, Color(1, 1, 1, k), 3.0)
	# Estallido donde cae / Burst where it lands
	var e := 1.0 - k
	draw_texture_rect(soft, Rect2(last - Vector2(46, 46), Vector2(92, 92)), false, Color(col, 0.7 * k))
	for j in 6:
		var d := Vector2.from_angle(j * TAU / 6.0 + 0.4)
		draw_line(last + d * (6.0 + 22.0 * e), last + d * (16.0 + 34.0 * e), Color(1, 1, 1, k), 3.0 * k + 1.0)


## Garras: arcos que se afinan en las puntas, con contorno de tinta, color y filo blanco. Se trazan
## en la primera mitad de su vida y luego se apagan.
## Claws: arcs tapering at the tips, with an ink outline, colour and a white edge. They're drawn in
## the first half of their life, then fade.
func _draw_claw(it: Dictionary, k: float, col: Color) -> void:
	var c := Vector2(it["pos"])
	var size := float(it["r"])
	var n := int(it["n"])
	var flip := float(it["flip"])
	var draw_k := minf(1.0, (1.0 - k) / 0.4)
	var fade := minf(1.0, k * 2.2)
	# Cruza al blanco en diagonal respecto al golpe / Crosses the target diagonally to the blow
	var a := float(it["a"]) + 0.9 * flip
	var dir := Vector2.from_angle(a)
	var nrm := dir.orthogonal()
	var soft := DreamBackground.soft_texture()
	draw_texture_rect(soft, Rect2(c - Vector2(size, size) * 1.4, Vector2(size, size) * 2.8), false, Color(col, 0.35 * fade))
	for j in n:
		var off := (j - (n - 1) * 0.5) * size * 0.42
		var len := size * (2.0 - absf(j - (n - 1) * 0.5) * 0.35)
		var pts_l := PackedVector2Array()
		var pts_r := PackedVector2Array()
		var steps := 10
		for i in steps + 1:
			var t := float(i) / steps * draw_k
			var along := (t - 0.5) * len
			# Curva de garra (hacia un lado) / Claw curve (to one side)
			var bend := sin(t * PI) * size * 0.28 * flip
			var p := c + dir * along + nrm * (off + bend)
			var w := sin(t / maxf(draw_k, 0.001) * PI) * size * 0.11 + 0.6
			pts_l.append(p + nrm * w)
			pts_r.append(p - nrm * w)
		pts_r.reverse()
		var body := pts_l + pts_r
		if body.size() < 3:
			continue
		var ink := PackedVector2Array()
		var mid := c + nrm * off
		for q in body:
			ink.append(q + (q - mid).normalized() * 1.5)
		draw_colored_polygon(ink, Color(INK, 0.8 * fade))
		draw_colored_polygon(body, Color(col.lightened(0.15), fade))
		# Filo blanco por el centro / A white edge along the middle
		var edge := PackedVector2Array()
		for i in range(1, steps):
			edge.append(pts_l[i].lerp(pts_r[pts_r.size() - 1 - i], 0.5))
		if edge.size() >= 2:
			draw_polyline(edge, Color(1, 1, 1, 0.85 * fade), 1.5)


## Salto de la pantera: estela de sombra en cuña y cuatro huellas que se encienden en orden
## Panther leap: a wedge shadow streak and four paw prints lighting up in order
func _draw_pounce(it: Dictionary, k: float, col: Color) -> void:
	var a := Vector2(it["pos"])
	var b := Vector2(it["to"])
	var d := b - a
	if d.length() < 4.0:
		return
	var dir := d.normalized()
	var nrm := dir.orthogonal()
	var e := minf(1.0, (1.0 - k) / 0.3)
	var head := a.lerp(b, e)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(head - Vector2(40, 40), Vector2(80, 80)), false, Color(col, 0.5 * k))
	draw_colored_polygon(PackedVector2Array([a + nrm * 2.0, head + nrm * 16.0, head - nrm * 16.0, a - nrm * 2.0]), Color(col, 0.35 * k))
	draw_colored_polygon(PackedVector2Array([a.lerp(head, 0.45), head + nrm * 6.0, head - nrm * 6.0]), Color(1, 1, 1, 0.6 * k))
	for i in 4:
		var t := (i + 1) / 5.0
		if t > e:
			break
		var p := a.lerp(b, t) + nrm * (10.0 if i % 2 == 0 else -10.0)
		_paw(p, dir.angle(), Color(col.lightened(0.35), minf(1.0, k * 1.6)))


func _paw(p: Vector2, ang: float, col: Color) -> void:
	draw_set_transform(p, ang + PI * 0.5, Vector2(1.4, 1.0))
	draw_circle(Vector2(0, 3), 6.5, Color(INK, col.a * 0.7))
	draw_circle(Vector2(0, 3), 5.0, col)
	for tx: float in [-5.5, -2.0, 2.0, 5.5]:
		var tp := Vector2(tx, -4.5 - (0.0 if absf(tx) > 3.0 else 1.8))
		draw_circle(tp, 3.0, Color(INK, col.a * 0.7))
		draw_circle(tp, 2.0, col)
	draw_set_transform(Vector2.ZERO)


## Pluma: palo y barbas, con su contorno / Feather: quill and vanes, with an outline
func _draw_feather(p: Vector2, rot: float, col: Color) -> void:
	draw_set_transform(p, rot, Vector2.ONE)
	var vane := PackedVector2Array([Vector2(-9, 0), Vector2(-4, -3.2), Vector2(5, -2.6), Vector2(9, 0), Vector2(5, 2.6), Vector2(-4, 3.2)])
	var ink := PackedVector2Array()
	for q in vane:
		ink.append(q * 1.2)
	draw_colored_polygon(ink, Color(INK, col.a * 0.7))
	draw_colored_polygon(vane, col.lightened(0.25))
	draw_line(Vector2(-11, 0), Vector2(8, 0), Color(col.darkened(0.35), col.a), 1.0)
	draw_set_transform(Vector2.ZERO)


func _star(p: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + i * PI / 4.0
		pts.append(p + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.38))
	draw_colored_polygon(pts, col)
