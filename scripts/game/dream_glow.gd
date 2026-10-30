class_name DreamGlow
extends Node2D
## Resplandor pequeño de los sueños: un brillo con rayos y motas que crece alrededor de Kroker
## cuando se va al plano astral y que, al revés, lo trae al empezar un sueño.
## Small dream glow: a glow with rays and motes that grows around Kroker when he leaves for the
## astral plane and that, in reverse, brings him in when a dream starts.

const COL := Color("f7f2ff")
const GOLD := Color("ffe9a8")

var power := 0.0      # 0..1, lo controla quien lo crea con un tween / driven by its creator with a tween
var radius := 110.0
var _t := 0.0


func _ready() -> void:
	z_index = 45


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if power <= 0.0:
		return
	var r := radius * (0.35 + 0.65 * power)
	# Halo en capas (en bloques de color, sin difuminar) / Layered halo (colour steps, no blur)
	for i in 5:
		var k := 1.0 - i / 5.0
		draw_circle(Vector2.ZERO, r * k, Color(COL, 0.12 * power + 0.1 * power * (1.0 - k)))
	draw_circle(Vector2.ZERO, r * 0.22, Color(Color.WHITE, 0.85 * power))
	# Rayos que giran despacio / Slowly turning rays
	for i in 8:
		var a := _t * 0.8 + i * TAU / 8.0
		var len := r * (1.1 + 0.25 * sin(_t * 5.0 + i))
		var d := Vector2(cos(a), sin(a))
		draw_line(d * r * 0.25, d * len, Color(GOLD if i % 2 == 0 else COL, 0.55 * power), 3.0)
	# Motas que suben / Rising motes
	for i in 10:
		var ph := fmod(_t * 0.7 + i * 0.137, 1.0)
		var x := sin(i * 12.9898) * r * 0.8
		var p := Vector2(x, r * 0.3 - ph * r * 1.4)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(GOLD, power * (1.0 - ph)))
