class_name CharoNpc
extends Node2D
## La Kioskera Charo dentro del sueño, al tamaño de Kroker. Aparece y se va con una nubecita
## y, cuando vende, trae su carrito del kiosco al lado.
## Kiosk lady Charo inside the dream, at Kroker's size. She appears and leaves in a little
## puff and, when she's selling, brings her kiosk cart along.

var with_kiosk := false
var run: Node
var _t := 0.0
var _show := 0.0
var _target := 1.0
var _talk := 0.0


func _ready() -> void:
	Audio.play("puff", -4.0)
	if run:
		run.fx.dissipate(global_position + Vector2(0, -50), Color("7fe0d0"))


## Hace como que habla un rato / Pretends to talk for a while
func talk(seconds := 0.6) -> void:
	_talk = maxf(_talk, seconds)


func leave() -> void:
	_target = 0.0
	Audio.play("puff", -4.0)
	if run:
		run.fx.dissipate(global_position + Vector2(0, -50), Color("7fe0d0"))
	get_tree().create_timer(0.5, false).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_t += delta
	_talk = maxf(0.0, _talk - delta)
	_show = move_toward(_show, _target, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var s := Player.ART_SCALE
	var squash := 1.0 + sin(_t * 9.0) * 0.03 * minf(1.0, _talk * 3.0)
	modulate.a = _show
	draw_colored_polygon(_ellipse(Vector2(0, 2), Vector2(34, 9)), Color(0, 0, 0, 0.25))
	if with_kiosk:
		draw_set_transform(Vector2(-100, -288) * s, 0.0, Vector2(s, s))
		Sprites.draw(self, "charo_kiosk")
	var pop := 0.6 + 0.4 * _show
	draw_set_transform(Vector2(-100 * s * pop, -288 * s * pop * squash), 0.0, Vector2(s * pop, s * pop * squash))
	Sprites.draw(self, "charo_small")
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, rr: Vector2, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
	return pts
