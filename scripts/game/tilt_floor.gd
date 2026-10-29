class_name TiltFloor
extends Node2D
## Evento "el suelo se inclina": dibuja sobre el suelo corrientes de flechas y motas de polvo
## que resbalan cuesta abajo, para que se vea hacia dónde tira la inclinación.
## "The floor tilts" event: draws streams of arrows and dust motes sliding downhill over the
## floor, so you can see which way the tilt is pulling.

const MAX_TILT := 75.0
const ARROW_GAP := 150.0
const MOTES := 70
const COL := Color("d9c8ff")

var run: Node
var _t := 0.0
var _scroll := 0.0
var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 1
	_rng.randomize()
	var area: Rect2 = run.arena_rect()
	for i in MOTES:
		_motes.append({"p": _rand_point(area), "s": _rng.randf_range(0.6, 1.4), "ph": _rng.randf() * TAU})


func _rand_point(area: Rect2) -> Vector2:
	return area.position + Vector2(_rng.randf() * area.size.x, _rng.randf() * area.size.y)


func _process(delta: float) -> void:
	_t += delta
	var tilt: Vector2 = run.get("_tilt")
	var k := clampf(tilt.length() / MAX_TILT, 0.0, 1.0)
	_scroll = fmod(_scroll + delta * (40.0 + 90.0 * k), ARROW_GAP)
	# Las motas ruedan cuesta abajo y reaparecen por el lado de arriba
	# The motes roll downhill and reappear on the uphill side
	var area: Rect2 = run.arena_rect()
	for m in _motes:
		var p: Vector2 = m["p"] + tilt * float(m["s"]) * 2.2 * delta
		if not area.has_point(p):
			p = Vector2(wrapf(p.x, area.position.x, area.end.x), wrapf(p.y, area.position.y, area.end.y))
		m["p"] = p
	queue_redraw()


func _draw() -> void:
	var tilt: Vector2 = run.get("_tilt")
	var k := clampf(tilt.length() / MAX_TILT, 0.0, 1.0)
	if k < 0.05:
		return
	var area: Rect2 = run.arena_rect()
	var dir := tilt.normalized()
	var side := dir.orthogonal()
	var c := area.get_center()
	var reach := area.size.length() * 0.5
	# Corrientes de flechas en filas perpendiculares a la pendiente
	# Streams of arrows in rows across the slope
	var rows := int(reach * 2.0 / 190.0)
	for r in range(-rows / 2, rows / 2 + 1):
		var stagger := ARROW_GAP * 0.5 if r % 2 != 0 else 0.0
		var n := int(reach * 2.0 / ARROW_GAP) + 2
		for i in n:
			var along := -reach + i * ARROW_GAP + _scroll + stagger
			var p := c + side * (r * 190.0) + dir * along
			if not area.grow(-20).has_point(p):
				continue
			# Se desvanecen en los bordes / They fade near the edges
			var edge := minf(minf(p.x - area.position.x, area.end.x - p.x), minf(p.y - area.position.y, area.end.y - p.y))
			var a := k * 0.32 * clampf(edge / 90.0, 0.0, 1.0)
			_chevron(p, dir, side, 22.0 + 8.0 * k, Color(COL, a))
	# Polvo que resbala / Sliding dust
	for m in _motes:
		var p: Vector2 = m["p"]
		var a := k * 0.5 * (0.6 + 0.4 * sin(_t * 3.0 + float(m["ph"])))
		var tail := tilt * float(m["s"]) * 0.35
		draw_line(p - tail, p, Color(COL, a * 0.4), 3.0)
		draw_circle(p, 2.5 * float(m["s"]), Color(COL, a))


func _chevron(p: Vector2, dir: Vector2, side: Vector2, s: float, col: Color) -> void:
	var tip := p + dir * s * 0.6
	var pts := PackedVector2Array([p - dir * s * 0.4 + side * s * 0.7, tip, p - dir * s * 0.4 - side * s * 0.7])
	draw_polyline(pts, col, 6.0)
