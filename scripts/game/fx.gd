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


func swing(center: Vector2, radius: float, angle: float, spread: float, color := UITheme.BONE, width := 6.0) -> void:
	_items.append({"kind": "swing", "pos": center, "r": radius, "a": angle, "s": spread,
		"color": color, "w": width, "life": 0.18, "max": 0.18})


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
			"bolt":
				# Grueso para que se vea en pixel art / Thick so it shows in pixel art
				draw_polyline(it["points"], Color(col, 0.3 * k), 16.0)
				draw_polyline(it["points"], Color(col, k), 6.0)
				draw_polyline(it["points"], Color(1, 1, 1, k), 2.5)
			"swing":
				var a := float(it["a"])
				var sp := float(it["s"])
				var r := float(it["r"])
				for j in 4:
					var rr := r - j * 5.0
					draw_arc(it["pos"], rr, a - sp, a + sp, 24, Color(col, k * (0.8 - j * 0.18)), maxf(1.0, float(it["w"]) - j), true)
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
func _star(p: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + i * PI / 4.0
		pts.append(p + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.38))
	draw_colored_polygon(pts, col)
