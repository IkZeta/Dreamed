class_name Puddle
extends Node2D
## Charco de pesadilla que deja un enemigo de élite: frena a Kroker mientras lo pisa.
## Nightmare puddle left by an elite enemy: slows Kroker while he stands in it.

const LIFE := 4.0
const RADIUS := 38.0

var run: Node
var _t := 0.0


func _ready() -> void:
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	var player: Player = run.player
	var d := player.global_position - global_position
	if Vector2(d.x, d.y / 0.45).length() < RADIUS:
		player.slow_t = maxf(player.slow_t, 0.25)
	queue_redraw()


func _draw() -> void:
	var a := clampf(minf(_t * 3.0, (LIFE - _t) / 0.8), 0.0, 1.0)
	var r := RADIUS * (0.6 + 0.4 * minf(1.0, _t * 3.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r, Color("3a5f9e", 0.45 * a))
	draw_circle(Vector2(-6, -4), r * 0.55, Color("8fe0ff", 0.25 * a))
	draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color("8fe0ff", 0.6 * a), 3.0)
	draw_set_transform(Vector2.ZERO)
