class_name Darkness
extends Node2D
## Evento "apagón": la habitación se queda a oscuras y solo se ve alrededor de Kroker.
## "Blackout" event: the room goes dark and only the area around Kroker can be seen.

const LIGHT := 300.0

var run: Node
var _t := 0.0
var _fade := 0.0
static var _hole: GradientTexture2D


func _ready() -> void:
	z_index = 45
	if _hole == null:
		var g := Gradient.new()
		# Primero los extremos y luego el punto del medio (si no, se pisan los índices)
		# Ends first, then the middle point (otherwise the indices get mixed up)
		g.set_color(0, Color(0.02, 0.01, 0.08, 0.0))
		g.set_color(1, Color(0.02, 0.01, 0.08, 0.92))
		g.add_point(0.55, Color(0.02, 0.01, 0.08, 0.25))
		_hole = GradientTexture2D.new()
		_hole.gradient = g
		_hole.fill = GradientTexture2D.FILL_RADIAL
		_hole.fill_from = Vector2(0.5, 0.5)
		_hole.fill_to = Vector2(1.0, 0.5)
		_hole.width = 128
		_hole.height = 128


func _process(delta: float) -> void:
	_t += delta
	_fade = move_toward(_fade, 1.0 if run.running else 0.0, delta * 1.5)
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.0:
		return
	var c: Vector2 = run.player.global_position + Vector2(0, -36)
	var r := LIGHT * (1.0 + 0.04 * sin(_t * 7.0) + 0.03 * sin(_t * 13.0))
	var dark := Color(0.02, 0.01, 0.08, 0.92 * _fade)
	var big := Rect2(-400, -400, 2720, 1880)
	var hole := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	draw_rect(Rect2(big.position, Vector2(big.size.x, hole.position.y - big.position.y)), dark)
	draw_rect(Rect2(Vector2(big.position.x, hole.end.y), Vector2(big.size.x, big.end.y - hole.end.y)), dark)
	draw_rect(Rect2(Vector2(big.position.x, hole.position.y), Vector2(hole.position.x - big.position.x, hole.size.y)), dark)
	draw_rect(Rect2(Vector2(hole.end.x, hole.position.y), Vector2(big.end.x - hole.end.x, hole.size.y)), dark)
	draw_texture_rect(_hole, hole, false, Color(1, 1, 1, _fade))
