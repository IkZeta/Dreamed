class_name DreamWeb
extends Node2D
## Telaraña del Atrapasueños, tejida en el suelo. Atrapa los trozos de estrella que caen dentro
## (suben despacio hacia su araña), frena a todos los que pasan y deja pegado 1 s al enemigo que
## entra lanzado. Dura un rato y se deshace si muere su araña.
## A Dreamcatcher's web, woven on the floor. It catches the star shards landing in it (they creep
## towards its spider), slows everyone passing through and sticks for 1 s any enemy that comes in
## flying. It lasts a while and comes apart if its spider dies.
##  - En la ciudad teje entre dos farolas: una telaraña larga que cruza la calle («seg»).
##  - La pelusa del oso se le engancha: si entra un enemigo con pelusa, la red se vuelve pegajosa
##    del todo y pega 1 s a cualquier enemigo que entre, vaya lanzado o no.
##  - Un Bostezo que se abre cerca se la traga entera (y suelta los trozos que tenía).
##  - In the city it weaves between two lamp posts: a long web across the street ("seg").
##  - The teddy's fluff catches on it: if an enemy with fluff walks in, the net turns fully
##    sticky and holds any enemy that enters for 1 s, flying or not.
##  - A Yawn opening nearby swallows it whole (and lets go of the shards it held).

const RADIUS := 100.0
const LIFE := 26.0
const SLOW := 0.25
const NET := Color(0.94, 0.9, 0.81)
## Media anchura de la telaraña larga de la ciudad / Half-width of the city's long web
const HALF_W := 34.0
const STICKY_SLOW := 0.5
const FLUFF := Color(0.86, 0.84, 0.92)

var run: Node
var spider: Node2D
var _t := 0.0
var _grow := 0.0
var _gone := -1.0
var _scan := 0.0
var _stuck: Array = []
## Extremo de la telaraña larga, relativo a ella (cero = redonda) / End of the long web, relative to it (zero = round)
var seg := Vector2.ZERO
var sticky := false
var _sticky_t := 0.0
var _swallow_to := Vector2.INF


func _ready() -> void:
	z_index = 1
	add_to_group("dream_webs")


func is_long() -> bool:
	return seg != Vector2.ZERO


## ¿Está el punto dentro de la red? / Is the point inside the net?
func covers(p: Vector2, pad := 0.0) -> bool:
	var l := p - global_position
	if is_long():
		# La red se teje de un extremo a otro / The net is woven from one end to the other
		var end := seg * _grow
		var q := Geometry2D.get_closest_point_to_segment(l, Vector2.ZERO, end)
		return l.distance_to(q) < HALF_W + pad
	var r := RADIUS * _grow + pad
	return l.length_squared() < r * r


## Centro de la red (para el hilo a la araña, los Bostezos...) / Centre of the net (for the thread to the spider, Yawns...)
func middle() -> Vector2:
	return global_position + seg * 0.5


## Un Bostezo se la traga: se encoge hacia la boca y desaparece / A Yawn swallows it: it shrinks towards the mouth and vanishes
func swallow(to: Vector2) -> void:
	if _gone >= 0.0:
		return
	_swallow_to = to
	dissolve()
	run.fx.text(middle() + Vector2(0, -40), tr("DCATCH_SWALLOWED"), Color("8d7ff0"), 18)
	Audio.play("web_eat", -10.0, 0.1, 0.6)


func dissolve() -> void:
	if _gone < 0.0:
		_gone = 0.0
		# Suelta los trozos que tenía atrapados / Lets go of the shards it was holding
		for s in get_tree().get_nodes_in_group("shards"):
			if s.get("web") == self:
				s.set("web", null)


func _physics_process(delta: float) -> void:
	_t += delta
	_grow = minf(1.0, _grow + delta * 2.5)
	_sticky_t += delta
	if _gone >= 0.0 or _t > LIFE:
		if _gone < 0.0:
			dissolve()
		_gone += delta
		if _swallow_to != Vector2.INF:
			global_position = global_position.lerp(_swallow_to - seg * 0.5 * (1.0 - _gone / 0.6), minf(1.0, delta * 8.0))
		if _gone > 0.6:
			queue_free()
		queue_redraw()
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.15
		_catch()
	queue_redraw()


func _catch() -> void:
	# Trozos de estrella / Star shards
	for s in get_tree().get_nodes_in_group("shards"):
		if s.get("_magnet") or s.get("web") != null:
			continue
		if covers((s as Node2D).global_position):
			s.set("web", self)
			run.fx.ring((s as Node2D).global_position, 10.0, Dreamcatcher.VIOLET, 0.25, 1.5)
	# Kroker se frena dentro / Kroker slows down inside
	var p: Player = run.player
	if p.alive and not p.flying() and covers(p.global_position):
		p.slow_t = maxf(p.slow_t, SLOW)
	# Los enemigos también; el que entra lanzado (o con la red pegajosa, cualquiera) se queda pegado
	# Enemies too; one flying in (or anyone, once the net is sticky) gets stuck
	for n: Node in run.foes():
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e == null or e is Dreamcatcher or not e.is_targetable() or e.is_boss():
			continue
		if not covers(e.global_position):
			continue
		e.slow_t = maxf(e.slow_t, STICKY_SLOW if sticky else SLOW)
		if not sticky and not e.fluffs.is_empty():
			_go_sticky(e.global_position)
		if (e.heavy_t > 0.0 or sticky) and not _stuck.has(e):
			_stuck.append(e)
			e.knock = Vector2.ZERO
			e.heavy_t = 0.0
			e.stun_t = maxf(e.stun_t, 1.0)
			run.fx.text(e.global_position + Vector2(0, -e.aim_height * 2.0 - 30), tr("DCATCH_STUCK"), NET, 18)
			Audio.play("web_eat", -12.0, 0.1, 1.3)


## La pelusa se engancha y la red pega del todo / The fluff catches and the net turns fully sticky
func _go_sticky(at: Vector2) -> void:
	sticky = true
	_sticky_t = 0.0
	run.fx.text(at + Vector2(0, -70), tr("DCATCH_STICKY"), FLUFF, 20)
	run.fx.ring(middle(), 60.0, Color(FLUFF, 0.7), 0.4, 2.0)
	Audio.play("fluff", -8.0, 0.1)
	Progress.tip("dcatch_sticky")


func _draw() -> void:
	var a := clampf(1.0 - _gone / 0.6, 0.0, 1.0) if _gone >= 0.0 else minf(1.0, (LIFE - _t) / 2.0)
	# Tragada: se encoge hacia la boca del Bostezo / Swallowed: it shrinks into the Yawn's mouth
	var shrink := 1.0 - clampf(_gone / 0.6, 0.0, 1.0) * 0.9 if _swallow_to != Vector2.INF else 1.0
	if is_long():
		_draw_long(a, shrink)
	else:
		_draw_round(a, shrink)
	# Hilo hasta la araña / Thread to the spider
	if is_instance_valid(spider) and (spider as Enemy).is_targetable():
		draw_line(seg * 0.5, spider.global_position + Vector2(0, -20) - global_position, Color(NET, 0.25 * a), 1.0)


func _draw_round(a: float, shrink: float) -> void:
	var r := RADIUS * _grow * shrink
	# Plana sobre el suelo (aplastada en vertical) / Flat on the floor (squashed vertically)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r, Color(FLUFF if sticky else Dreamcatcher.VIOLET, (0.16 if sticky else 0.06) * a))
	var col := Color(NET, 0.5 * a)
	for k in 10:
		var ang := k * TAU / 10.0 + 0.15
		draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * r, col, 1.5)
	# Espiral que brilla a ratos / A spiral glinting now and then
	var pts := PackedVector2Array()
	for i in 60:
		var ang := i * TAU / 10.0
		pts.append(Vector2(cos(ang), sin(ang)) * (8.0 + i * (r - 8.0) / 60.0))
	draw_polyline(pts, col, 1.2)
	var glint := fposmod(_t * 0.4, 1.0)
	draw_arc(Vector2.ZERO, r * glint, 0.0, TAU, 32, Color(1, 1, 1, 0.35 * (1.0 - glint) * a), 1.5)
	# Cuentas de rocío en la red / Dew beads on the net
	for k in 6:
		var ang := k * 1.7 + 0.4
		var d := r * (0.35 + 0.1 * (k % 4))
		draw_circle(Vector2(cos(ang), sin(ang)) * d, 2.5, Color(StarShard.COLORS[k % 5], 0.7 * a))
	if sticky:
		for k in 9:
			var ang := k * 2.4 + 0.9
			_tuft(Vector2(cos(ang), sin(ang)) * r * (0.25 + 0.08 * (k % 7)), k, a)
	draw_set_transform(Vector2.ZERO)


## La telaraña larga de la ciudad: hilos de farola a farola, con travesaños y rocío
## The city's long web: threads from lamp to lamp, with cross-strands and dew
func _draw_long(a: float, shrink: float) -> void:
	var end := seg * _grow
	var mid := end * 0.5
	var len := end.length()
	if len < 2.0:
		return
	var dir := end / len
	var nrm := dir.orthogonal()
	draw_set_transform(mid * (1.0 - shrink), 0.0, Vector2.ONE * shrink)
	# Sombra de la franja sobre el asfalto / The band's shadow on the asphalt
	var band := PackedVector2Array([nrm * HALF_W, end + nrm * HALF_W, end - nrm * HALF_W, -nrm * HALF_W])
	draw_colored_polygon(band, Color(FLUFF if sticky else Dreamcatcher.VIOLET, (0.16 if sticky else 0.07) * a))
	var col := Color(NET, 0.55 * a)
	# Hilos maestros que cuelgan un poco / Main threads sagging slightly
	for k in 4:
		var off := (k / 3.0 - 0.5) * 2.0 * HALF_W * 0.85
		var pts := PackedVector2Array()
		for i in 17:
			var f := i / 16.0
			var sag := sin(PI * f) * 10.0 * (1.0 if k % 2 == 0 else -0.6)
			pts.append(dir * len * f + nrm * (off + sag + sin(_t * 1.2 + f * 6.0 + k) * 1.2))
		draw_polyline(pts, col, 1.4 if k in [0, 3] else 1.1)
	# Travesaños en zigzag / Zigzag cross-strands
	var steps := int(len / 26.0)
	for i in steps:
		var f0 := float(i) / steps
		var f1 := float(i + 1) / steps
		var s0 := -1.0 if i % 2 == 0 else 1.0
		draw_line(dir * len * f0 + nrm * s0 * HALF_W * 0.85, dir * len * f1 - nrm * s0 * HALF_W * 0.85, Color(NET, 0.35 * a), 1.0)
	# Brillo que recorre la red / A glint running along the net
	var g := fposmod(_t * 0.35, 1.0)
	draw_line(dir * len * g + nrm * HALF_W, dir * len * g - nrm * HALF_W, Color(1, 1, 1, 0.4 * (1.0 - g) * a), 2.0)
	for k in 7:
		var f := fposmod(k * 0.37 + 0.11, 1.0)
		draw_circle(dir * len * f + nrm * ((k % 3) - 1) * HALF_W * 0.6, 2.5, Color(StarShard.COLORS[k % 5], 0.7 * a))
	# Nudos en las farolas / Knots at the lamp posts
	for q: Vector2 in [Vector2.ZERO, end]:
		draw_circle(q, 5.0, Color(NET, 0.7 * a))
	if sticky:
		for k in int(len / 40.0) + 3:
			var f := fposmod(k * 0.29 + 0.05, 1.0)
			_tuft(dir * len * f + nrm * (fposmod(k * 0.53, 1.0) - 0.5) * HALF_W * 1.4, k, a)
	draw_set_transform(Vector2.ZERO)


## Un mechón de pelusa enganchado / A tuft of caught fluff
func _tuft(at: Vector2, k: int, a: float) -> void:
	var pulse := 1.0 + 0.15 * sin(_sticky_t * 3.0 + k)
	var fade := minf(1.0, _sticky_t * 3.0)
	for j in 3:
		var o := Vector2(cos(k + j * 2.1), sin(k + j * 2.1)) * 4.0
		draw_circle(at + o, (4.5 - j) * pulse, Color(FLUFF, (0.75 - j * 0.15) * a * fade))
