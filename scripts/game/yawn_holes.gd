class_name YawnHoles
extends Node2D
## Evento «Bostezos»: el sueño bosteza y se abren agujeros pasajeros junto a los enemigos, por
## el lado contrario a Kroker, así que basta con empujarlos hacia fuera. Duran unos segundos y
## se cierran solos. Se ven como los agujeros de siempre (vacío estrellado y borde roto) pero
## se abren y cierran como una boca.
## "Yawns" event: the dream yawns and short-lived holes open next to enemies, on the side away from
## Kroker, so pushing them outwards is enough. They last a few seconds and close by themselves.
## They look like the usual holes (starry void and a broken rim) but open and close like a mouth.

const EVERY := Vector2(5.5, 8.0)
const FIRST := 2.5
const OPEN_TIME := 0.6
const LIFE := 5.0
const HALF := Vector2(66, 28)     # medio tamaño del agujero / hole half-size
const MAX_OPEN := 2
const AWAY := 260.0              # lejos de Kroker / away from Kroker

var run: Run
var _holes: Array = []           # {c, t, seed}
var _wait := FIRST
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if not run.running:
		return
	for h: Dictionary in _holes:
		h["t"] += delta
	_holes = _holes.filter(func(h: Dictionary) -> bool: return h["t"] < LIFE)
	_wait -= delta
	if _wait <= 0.0:
		_wait = randf_range(EVERY.x, EVERY.y)
		if _holes.size() < MAX_OPEN:
			_open()
	queue_redraw()


func _open() -> void:
	var p := _spot()
	if p == Vector2.INF:
		return
	_holes.append({"c": p, "t": 0.0, "seed": randf() * 10.0})
	Audio.play("yawn", -10.0, 0.15)
	run.fx.ring(p, 40.0, Color("8d7ff0", 0.7), 0.5, 2.0)


## Junto a un enemigo, por el lado contrario a Kroker / Next to an enemy, on the side away from Kroker
func _spot() -> Vector2:
	var me := run.player.global_position
	var view := run.view_rect().grow(-60.0)
	var cands: Array = []
	for e: Node in run.enemies.get_children():
		if e is Enemy and (e as Enemy).is_targetable() and not e.is_boss() and (e as Enemy).can_fall():
			cands.append(e)
	cands.shuffle()
	for e: Enemy in cands:
		var away := (e.global_position - me).normalized()
		if away == Vector2.ZERO:
			continue
		var p := run.clamp_to_arena(e.global_position + away * (HALF.x + 50.0), HALF.x)
		if p.distance_to(me) < AWAY or not view.has_point(p) or _blocked(p):
			continue
		return p
	return Vector2.INF


func _blocked(p: Vector2) -> bool:
	for h: Dictionary in _holes:
		if (h["c"] as Vector2).distance_to(p) < HALF.x * 3.0:
			return true
	return run.hole_at(p, HALF.x, Vector2.ZERO) != Vector2.INF


func _open_k(h: Dictionary) -> float:
	var t: float = h["t"]
	var k := minf(t / OPEN_TIME, (LIFE - t) / OPEN_TIME)
	return clampf(k, 0.0, 1.0)


## ¿Es el centro de uno de estos agujeros? / Is it the centre of one of these holes?
func owns(c: Vector2) -> bool:
	for h: Dictionary in _holes:
		if (h["c"] as Vector2).distance_to(c) < 1.0:
			return true
	return false


## ¿Cae aquí? Solo cuando está bien abierto / Does it fall here? Only when it's wide open
func hole_at(p: Vector2, margin: float) -> Vector2:
	for h: Dictionary in _holes:
		if _open_k(h) < 0.75:
			continue
		var c: Vector2 = h["c"]
		var r := Rect2(c - HALF, HALF * 2.0).grow(-8.0).grow(margin * 0.6)
		if r.has_point(p):
			return c
	return Vector2.INF


func _draw() -> void:
	for h: Dictionary in _holes:
		var k := _open_k(h)
		if k <= 0.0:
			continue
		var ease := k * k * (3.0 - 2.0 * k)
		var c: Vector2 = h["c"]
		var s: float = h["seed"]
		# Se abre como una boca: primero a lo ancho, luego a lo alto / Opens like a mouth: wide first, then tall
		var rr := Vector2(HALF.x * (0.35 + 0.65 * ease), HALF.y * ease * ease)
		if rr.y < 1.5:
			continue
		var rim := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			var jag := 1.0 + 0.12 * sin(a * 5.0 + s) + 0.06 * sin(a * 11.0 + s * 2.0)
			rim.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * (jag + 0.14))
			inner.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * jag)
		draw_colored_polygon(rim, Color("2a2350"))
		draw_colored_polygon(inner, Color("07061a"))
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - rr * 0.8, rr * 1.6), false, Color("5b4bc4", 0.35))
		for i in 6:
			var sp := c + Vector2(sin(i * 2.3 + s) * rr.x * 0.6, cos(i * 1.7 + s) * rr.y * 0.5)
			draw_circle(sp, 1.6, Color(UITheme.BONE, (0.4 + 0.4 * sin(_t * 2.0 + i)) * ease))
		# Bostezo: un leve resplandor que respira mientras está abierto / Yawn: a faint glow that breathes while open
		var breath := 0.5 + 0.5 * sin(_t * 3.0 + s)
		draw_polyline(rim + PackedVector2Array([rim[0]]), Color("8d7ff0", (0.25 + 0.25 * breath) * ease), 2.0, true)
