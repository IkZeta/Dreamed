class_name TalkPortrait
extends Control
## La cara del que habla de cerca (cabeza y hombros), sobre un fondo de su color con rayos; mueve
## la cabeza al hablar y da un saltito al empezar
## A close-up of the speaker (head and shoulders) on a background in their colour with rays; it
## bobs while talking and gives a little hop when it starts

## Dónde está la cara de cada uno en su dibujo (lienzo de 200 de ancho) / Where each face is in their drawing (200-wide canvas)
const FACE := {"svinho": Vector2(100, 62), "stolk": Vector2(100, 60), "silly": Vector2(100, 70), "doc": Vector2(100, 66),
	"ad": Vector2(100, 64), "pinche": Vector2(100, 60), "magnus": Vector2(100, 72), "superk": Vector2(100, 58),
	"lilkey": Vector2(100, 62), "lynx": Vector2(100, 58), "luna": Vector2(100, 50), "charo": Vector2(100, 74), "cat": Vector2(60, 162)}
const ZOOM := 2.3
var who := "svinho"
var aura := Color.WHITE
var talking := false
var _t := 0.0
var _pop := 0.0

func pop() -> void:
	_pop = 1.0

func _process(delta: float) -> void:
	_t += delta
	_pop = move_toward(_pop, 0.0, delta * 3.0)
	queue_redraw()

func _draw() -> void:
	var c := size / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), aura.darkened(0.55))
	for i in 12:
		var a := TAU * i / 12.0 + _t * 0.15
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.12) * 90.0, c + Vector2.from_angle(a + 0.12) * 90.0]), Color(aura, 0.16))
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - size * 0.5, size), false, Color(aura, 0.35))
	var s := size.x / 200.0 * ZOOM
	var bob := (sin(_t * 16.0) * 1.0 if talking else sin(_t * 1.6) * 0.6) - sin(_pop * PI) * 4.0
	var face: Vector2 = FACE.get(who, Vector2(100, 66))
	var origin := Vector2(c.x, size.y * 0.47 + bob) - face * s
	NpcArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, origin), who, _t)
	# Viñeta en los bordes / Vignette at the edges
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25), false, 2.0)
