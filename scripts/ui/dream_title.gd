class_name DreamTitle
extends Control
## El logo: «DREAMED» en letras de bloques de pixel art, gruesas y con contorno, rellenas de un
## degradado de luz de luna a nebulosa. Las letras caen una a una al entrar y luego flotan cada una
## a su ritmo; un brillo las recorre de vez en cuando y la última D lleva el gorro de dormir de
## Kroker, con la borla meciéndose.
## The logo: "DREAMED" in chunky, outlined pixel-art block letters, filled with a gradient from
## moonlight to nebula. The letters drop in one by one and then each floats at its own pace; a
## shine sweeps across now and then and the last D wears Kroker's nightcap, its bobble swinging.

## Letras de 6 (o 7) x 8 bloques / Letters 6 (or 7) x 8 blocks
const GLYPHS := {
	"D": ["XXXXX.", "XXXXXX", "XX..XX", "XX..XX", "XX..XX", "XX..XX", "XXXXXX", "XXXXX."],
	"R": ["XXXXX.", "XXXXXX", "XX..XX", "XXXXXX", "XXXXX.", "XX.XX.", "XX..XX", "XX..XX"],
	"E": ["XXXXXX", "XXXXXX", "XX....", "XXXXX.", "XXXXX.", "XX....", "XXXXXX", "XXXXXX"],
	"A": [".XXXX.", "XXXXXX", "XX..XX", "XX..XX", "XXXXXX", "XXXXXX", "XX..XX", "XX..XX"],
	"M": ["XX...XX", "XXX.XXX", "XXXXXXX", "XX.X.XX", "XX...XX", "XX...XX", "XX...XX", "XX...XX"],
}
const TEXT := "DREAMED"
## Degradado de arriba abajo / Top-to-bottom gradient
const FILL := [Color("fff6dc"), Color("ffe7a8"), Color("f6d993"), Color("f3b9a0"), Color("e8a6d8"), Color("c79cf0"), Color("a98cf0"), Color("8d7ff0")]
const INK := Color("140e26")
const SHADOW := Color("2a1a5e")

## Tamaño de cada bloque en píxeles / Size of each block in pixels
var block := 14
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_width() * block + block * 6, 8 * block + block * 6)


func _width() -> int:
	var w := 0
	for ch in TEXT:
		w += String(GLYPHS[ch][0]).length() + 1
	return w - 1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var b := float(block)
	var x0 := (size.x - _width() * b) * 0.5
	var y0 := b * 3.0
	# Resplandor detrás / Glow behind
	var soft := DreamBackground.soft_texture()
	draw_texture_rect(soft, Rect2(Vector2(x0 - b * 6, y0 - b * 4), Vector2(_width() * b + b * 12, b * 16)), false,
		Color(UITheme.GOLD, (0.14 + 0.04 * sin(_t * 1.1)) * minf(1.0, _t)))
	var col := 0
	var letters: Array = []
	for i in TEXT.length():
		var g: Array = GLYPHS[TEXT[i]]
		# Entrada: cae desde arriba con rebote / Entrance: drops from above with a bounce
		var k := clampf((_t - 0.1 - i * 0.08) / 0.6, 0.0, 1.0)
		var drop := (1.0 - _ease_out_back(k)) * -b * 7.0
		var bob := sin(_t * 1.4 - i * 0.7) * b * 0.35 * k
		var tilt := sin(_t * 0.9 - i * 0.9) * 0.035 * k
		letters.append({"g": g, "o": Vector2(x0 + col * b, y0 + drop + bob), "a": k, "tilt": tilt})
		col += String(g[0]).length() + 1
	# Tres pasadas: sombra, contorno y relleno, para que los contornos no tapen a la letra de al lado
	# Three passes: shadow, outline and fill, so outlines don't cover the neighbouring letter
	for pass_i in 3:
		for L: Dictionary in letters:
			_letter(L, b, pass_i)
	# Gorro de dormir en la última D / Nightcap on the last D
	var last: Dictionary = letters[letters.size() - 1]
	_nightcap(Vector2(last["o"]) + Vector2(3.0 * b, -b * 0.4), b, float(last["a"]), float(last["tilt"]))


func _letter(L: Dictionary, b: float, pass_i: int) -> void:
	var g: Array = L["g"]
	var a: float = L["a"]
	if a <= 0.0:
		return
	var o: Vector2 = L["o"]
	var w := String(g[0]).length()
	draw_set_transform(o + Vector2(w * b, 8.0 * b) * 0.5, float(L["tilt"]), Vector2.ONE)
	var base := -Vector2(w * b, 8.0 * b) * 0.5
	# Un brillo diagonal que cruza cada pocos segundos / A diagonal shine crossing every few seconds
	var shine := fposmod(_t * 0.22, 1.0) * 3.0 - 0.6
	for r in 8:
		var row: String = g[r]
		for c in w:
			if row[c] != "X":
				continue
			var p := base + Vector2(c, r) * b
			match pass_i:
				0:
					draw_rect(Rect2(p + Vector2(b * 0.5, b * 0.9), Vector2(b, b)), Color(SHADOW, 0.85 * a))
				1:
					draw_rect(Rect2(p - Vector2(b, b) * 0.32, Vector2(b, b) * 1.64), Color(INK, a))
				2:
					var fill: Color = FILL[r]
					# Filo de luz arriba y sombra en el borde de abajo / Light edge on top, shade on the bottom edge
					var up := r == 0 or String(g[r - 1])[c] != "X"
					var down := r == 7 or String(g[r + 1])[c] != "X"
					if up:
						fill = fill.lerp(Color.WHITE, 0.45)
					elif down:
						fill = fill.darkened(0.18)
					var d := absf((float(c) + float(r) * 0.6) / 14.0 + float(o.x) / size.x - shine)
					if d < 0.08:
						fill = fill.lerp(Color.WHITE, (1.0 - d / 0.08) * 0.7)
					draw_rect(Rect2(p, Vector2(b, b)), Color(fill, a))
	draw_set_transform(Vector2.ZERO)


## Gorro de dormir azul con estrellas y borla blanca que se mece / Blue nightcap with stars and a white swinging bobble
func _nightcap(at: Vector2, b: float, a: float, tilt: float) -> void:
	if a <= 0.0:
		return
	draw_set_transform(at, tilt - 0.18, Vector2.ONE)
	# Copa del gorro y la cola caída hacia la derecha, que se mece / The cap's crown and the tail drooping right, swinging
	var tip := Vector2(b * 5.0, b * (0.6 + sin(_t * 1.6) * 0.7))
	var dome := PackedVector2Array([Vector2(-b * 3.2, b * 0.6), Vector2(-b * 2.6, -b * 1.2), Vector2(-b * 1.0, -b * 2.3),
		Vector2(b * 1.0, -b * 2.5), Vector2(b * 2.6, -b * 1.6), Vector2(b * 3.2, b * 0.4)])
	var tail := PackedVector2Array([Vector2(b * 0.6, -b * 2.5), Vector2(b * 3.4, -b * 2.0), tip, Vector2(b * 2.6, -b * 0.6)])
	for poly: PackedVector2Array in [dome, tail]:
		var mid := Vector2.ZERO
		for p in poly:
			mid += p
		mid /= poly.size()
		var out := PackedVector2Array()
		for p in poly:
			out.append(p + (p - mid).normalized() * b * 0.35)
		draw_colored_polygon(out, Color(INK, a))
	draw_colored_polygon(dome, Color("4a6ad8", a))
	draw_colored_polygon(tail, Color("4a6ad8", a))
	draw_colored_polygon(PackedVector2Array([Vector2(-b * 3.2, b * 0.6), Vector2(-b * 2.6, -b * 1.2), Vector2(-b * 1.0, -b * 2.3), Vector2(-b * 1.6, b * 0.5)]), Color("6f8cf0", a))
	# Ribete blanco / White trim
	draw_rect(Rect2(Vector2(-b * 3.5, b * 0.1), Vector2(b * 6.9, b * 1.1)), Color(INK, a))
	draw_rect(Rect2(Vector2(-b * 3.2, b * 0.3), Vector2(b * 6.3, b * 0.7)), Color("f7f2ea", a))
	for sp: Vector2 in [Vector2(-b * 1.2, -b * 0.6), Vector2(b * 1.0, -b * 1.4), Vector2(b * 2.6, -b * 1.5)]:
		draw_rect(Rect2(sp, Vector2(b, b) * 0.45), Color(UITheme.GOLD, a))
	draw_circle(tip, b * 1.05, Color(INK, a))
	draw_circle(tip, b * 0.75, Color("f7f2ea", a))
	draw_set_transform(Vector2.ZERO)


static func _ease_out_back(k: float) -> float:
	var c1 := 1.4
	return 1.0 + (c1 + 1.0) * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)
