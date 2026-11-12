class_name DreamWeb
extends Node2D
## Telaraña del Atrapasueños, tejida en el suelo. Atrapa los trozos de estrella que caen dentro
## (suben despacio hacia su araña), frena a todos los que pasan y deja pegado 1 s al enemigo que
## entra lanzado. Dura un rato y se deshace si muere su araña.
## A Dreamcatcher's web, woven on the floor. It catches the star shards landing in it (they creep
## towards its spider), slows everyone passing through and sticks for 1 s any enemy that comes in
## flying. It lasts a while and comes apart if its spider dies.

const RADIUS := 100.0
const LIFE := 26.0
const SLOW := 0.25
const NET := Color(0.94, 0.9, 0.81)

var run: Node
var spider: Node2D
var _t := 0.0
var _grow := 0.0
var _gone := -1.0
var _scan := 0.0
var _stuck: Array = []


func _ready() -> void:
	z_index = 1


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
	if _gone >= 0.0 or _t > LIFE:
		if _gone < 0.0:
			dissolve()
		_gone += delta
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
	var r2 := RADIUS * RADIUS * _grow * _grow
	# Trozos de estrella / Star shards
	for s in get_tree().get_nodes_in_group("shards"):
		if s.get("_magnet") or s.get("web") != null:
			continue
		if (s as Node2D).global_position.distance_squared_to(global_position) < r2:
			s.set("web", self)
			run.fx.ring((s as Node2D).global_position, 10.0, Dreamcatcher.VIOLET, 0.25, 1.5)
	# Kroker se frena dentro / Kroker slows down inside
	var p: Player = run.player
	if p.alive and not p.flying() and p.global_position.distance_squared_to(global_position) < r2:
		p.slow_t = maxf(p.slow_t, SLOW)
	# Los enemigos también; el que entra lanzado se queda pegado / Enemies too; one flying in gets stuck
	for n: Node in run.foes():
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e == null or e is Dreamcatcher or not e.is_targetable() or e.is_boss():
			continue
		if e.global_position.distance_squared_to(global_position) > r2:
			continue
		e.slow_t = maxf(e.slow_t, SLOW)
		if e.heavy_t > 0.0 and not _stuck.has(e):
			_stuck.append(e)
			e.knock = Vector2.ZERO
			e.heavy_t = 0.0
			e.stun_t = maxf(e.stun_t, 1.0)
			run.fx.text(e.global_position + Vector2(0, -e.aim_height * 2.0 - 30), tr("DCATCH_STUCK"), NET, 18)
			Audio.play("web_eat", -12.0, 0.1, 1.3)


func _draw() -> void:
	var a := clampf(1.0 - _gone / 0.6, 0.0, 1.0) if _gone >= 0.0 else minf(1.0, (LIFE - _t) / 2.0)
	var r := RADIUS * _grow
	# Plana sobre el suelo (aplastada en vertical) / Flat on the floor (squashed vertically)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r, Color(Dreamcatcher.VIOLET, 0.06 * a))
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
	draw_set_transform(Vector2.ZERO)
	# Hilo hasta la araña / Thread to the spider
	if is_instance_valid(spider) and (spider as Enemy).is_targetable():
		draw_line(Vector2.ZERO, spider.global_position + Vector2(0, -20) - global_position, Color(NET, 0.25 * a), 1.0)
