class_name RealityIcon
extends Control
## Icono de la Realidad Fragmentada: un rombo de cristal roto en tres trozos que flotan
## un poco separados. Se usa en el HUD, en el kiosco de Charo y en la chimenea.
## Fragmented Reality icon: a glass diamond broken into three pieces floating slightly
## apart. Used in the HUD, Charo's kiosk and the fireplace.

const COLOR := Color("b8a6ff")
const LIGHT := Color("e8e0ff")
const DEEP := Color("6a58c8")

var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(36, 36)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_shard(self, size / 2.0, minf(size.x, size.y) * 0.42, _t)


## Dibuja el rombo roto centrado en c / Draws the broken diamond centred on c
static func draw_shard(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var gap := r * (0.1 + 0.04 * sin(t * 2.5))
	var top := c + Vector2(0, -r)
	var bottom := c + Vector2(0, r)
	var left := c + Vector2(-r * 0.7, 0)
	var right := c + Vector2(r * 0.7, 0)
	var mid := c + Vector2(r * 0.08, r * 0.1)
	# Tres trozos: izquierda, derecha y abajo / Three pieces: left, right and bottom
	var pieces := [
		[PackedVector2Array([top, mid, left]), Vector2(-1, -0.6), LIGHT],
		[PackedVector2Array([top, right, mid]), Vector2(1, -0.6), COLOR],
		[PackedVector2Array([left, mid, right, bottom]), Vector2(0, 1), DEEP],
	]
	for p: Array in pieces:
		var pts: PackedVector2Array = p[0]
		var off: Vector2 = p[1] * gap
		var moved := PackedVector2Array()
		for q in pts:
			moved.append(q + off)
		ci.draw_colored_polygon(moved, p[2])
		var closed := moved.duplicate()
		closed.append(moved[0])
		ci.draw_polyline(closed, Color(UITheme.INK, 0.8), maxf(1.0, r * 0.08))
	ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.35), maxf(1.0, r * 0.1), Color(1, 1, 1, 0.8))
