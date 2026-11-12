class_name Stampede
extends Node2D
## Estampida de ovejas (desde el Acto 2, a veces, a mitad de un sueño): las ovejas que Kroker
## contaba para dormirse cruzan la pantalla en manada. Primero se oye el retumbar y se levanta polvo
## por el lado por el que llegan; luego pasan a toda prisa. No hacen daño: solo empujan, a Kroker y a
## los enemigos (que, si hay un agujero cerca, se caen). Ellas saltan los agujeros.
## Sheep stampede (from Act 2, sometimes, mid-dream): the sheep Kroker counted to fall asleep cross
## the screen as a herd. First you hear the rumble and dust rises on the side they come from; then
## they rush past. They do no harm: they only shove, Kroker and the enemies (who, if a hole is near,
## fall in). They leap over the holes.

const WARN := 1.6
const SPEED := 600.0
const PUSH := 820.0
const ENEMY_PUSH := 900.0
const HIT_R := 44.0
const DUST := Color(0.85, 0.82, 0.95)

var run: Node
var _dir := 1.0
var _y := 0.0
var _warn := WARN
var _sheep: Array[Dictionary] = []   # {"p": Vector2, "z": float, "ph": float, "hit": Array}
var _t := 0.0
var _done := false


func _ready() -> void:
	z_index = 4
	var v: Rect2 = run.view_rect()
	_dir = 1.0 if randf() < 0.5 else -1.0
	# Pasan por donde está Kroker (más o menos): hay que apartarse o dejarse llevar
	# They run through where Kroker is (roughly): get out of the way or get carried along
	var ar: Rect2 = run.arena_rect()
	_y = clampf(run.player.global_position.y + randf_range(-60.0, 60.0), ar.position.y + 80.0, ar.end.y - 40.0)
	var start_x := (v.position.x - 90.0) if _dir > 0.0 else (v.end.x + 90.0)
	var n := randi_range(10, 14)
	for i in n:
		var row := i % 3
		_sheep.append({
			"p": Vector2(start_x - _dir * (i * 70.0 + randf_range(0.0, 40.0)), _y + (row - 1) * 54.0 + randf_range(-12.0, 12.0)),
			"z": 0.0, "ph": randf() * TAU, "hit": [], "spd": SPEED * randf_range(0.9, 1.1),
		})
	Audio.play("stampede", -6.0)
	run.fx.text(Vector2((v.position.x + 160.0) if _dir > 0.0 else (v.end.x - 160.0), _y - 140.0), tr("STAMPEDE"), Color("f4f1ea"), 30)
	Progress.tip("sheep")


func _physics_process(delta: float) -> void:
	_t += delta
	if _warn > 0.0:
		_warn -= delta
		if _warn <= 0.0:
			Audio.play("sheep_baa", -8.0, 0.1)
		queue_redraw()
		return
	var v: Rect2 = run.view_rect()
	var gone := 0
	for s: Dictionary in _sheep:
		var p: Vector2 = s["p"]
		p.x += _dir * float(s["spd"]) * delta
		s["p"] = p
		s["ph"] = float(s["ph"]) + delta * 16.0
		# Saltan los agujeros / They leap over the holes
		var over: bool = run.hole_at(p, 8.0, Vector2.ZERO) != Vector2.INF
		s["z"] = move_toward(float(s["z"]), 46.0 if over else 0.0, delta * (420.0 if over else 300.0))
		if (_dir > 0.0 and p.x > v.end.x + 120.0) or (_dir < 0.0 and p.x < v.position.x - 120.0):
			gone += 1
			continue
		if not run.running:
			continue
		_shove(s, p)
		if randf() < delta * 0.25:
			Audio.play("sheep_baa", -14.0, 0.15)
	if gone >= _sheep.size():
		queue_free()
		return
	queue_redraw()


## Empuja a Kroker y a los enemigos que se cruzan: hacia delante y hacia fuera de la manada
## Shoves Kroker and the enemies in the way: forwards and out of the herd
func _shove(s: Dictionary, p: Vector2) -> void:
	var hit: Array = s["hit"]
	var player: Player = run.player
	if player.alive and not hit.has(player) and p.distance_to(player.global_position) < HIT_R + 10.0:
		hit.append(player)
		var side := signf(player.global_position.y - p.y)
		if side == 0.0:
			side = 1.0
		player.shove(Vector2(_dir * PUSH, side * PUSH * 0.45))
		Audio.play("pillow", -10.0, 0.15)
		run.shake(2.0)
		run.fx.ring(player.global_position + Vector2(0, -30), 26.0, DUST, 0.3, 2.0)
	for n: Node in run.foes():
		if not is_instance_valid(n) or hit.has(n):
			continue
		var e := n as Enemy
		if e == null or not e.is_targetable() or e.is_boss() or p.distance_to(e.global_position) > HIT_R + e.radius:
			continue
		hit.append(e)
		var side := signf(e.global_position.y - p.y)
		e.knock += Vector2(_dir * ENEMY_PUSH, (side if side != 0.0 else 1.0) * ENEMY_PUSH * 0.35) / sqrt(maxf(1.0, e.mass))
		e.heavy_t = maxf(e.heavy_t, 0.4)
		run.fx.ring(e.aim_point(), 16.0, DUST, 0.3, 2.0)


func _draw() -> void:
	# Aviso: polvo y flechas en el borde por el que llegan / Warning: dust and arrows on the edge they come from
	if _warn > 0.0:
		var v: Rect2 = run.view_rect()
		var ex := (v.position.x + 30.0) if _dir > 0.0 else (v.end.x - 30.0)
		var k := 1.0 - _warn / WARN
		for i in 7:
			var y := _y - 90.0 + i * 30.0
			var r := 10.0 + 12.0 * k + sin(_t * 9.0 + i) * 3.0
			draw_circle(Vector2(ex + sin(_t * 7.0 + i * 2.0) * 8.0, y), r, Color(DUST, 0.25 + 0.25 * k))
		var col := Color(Settings.warning_color(), 0.5 + 0.4 * sin(_t * 10.0))
		for i in 3:
			var ax := ex + _dir * (60.0 + i * 34.0 + fposmod(_t * 120.0, 34.0))
			var tip := Vector2(ax, _y)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(_dir * 16.0, 0), tip + Vector2(-_dir * 8.0, -16), tip + Vector2(-_dir * 8.0, 16)]), col)
		return
	# Las ovejas, de atrás adelante para que se tapen bien / The sheep, back to front so they overlap properly
	var order := _sheep.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["p"]).y < Vector2(b["p"]).y)
	for s: Dictionary in order:
		_draw_sheep(Vector2(s["p"]), float(s["z"]), float(s["ph"]))


func _draw_sheep(p: Vector2, z: float, ph: float) -> void:
	var gallop := -absf(sin(ph * 0.5)) * 7.0 - z
	# Sombra en el suelo (más pequeña cuando salta) / Shadow on the floor (smaller when leaping)
	draw_set_transform(p, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 34.0 - z * 0.3, Color(0.05, 0.02, 0.15, 0.28))
	var f := Vector2(_dir, 1.0)
	# Patas al galope (se encogen al saltar) / Galloping legs (tucked in while leaping)
	var tuck := clampf(z / 30.0, 0.0, 1.0)
	for i in 4:
		var lx: float = [-22.0, -12.0, 12.0, 22.0][i]
		var swing: float = sin(ph + (0.0 if i % 2 == 0 else PI)) * 0.6 * (1.0 - tuck) + tuck * (0.9 if i < 2 else -0.9)
		draw_set_transform(p + Vector2(lx * _dir, -18.0 + gallop), swing * _dir, f)
		Sprites.draw(self, "sheep_leg")
	draw_set_transform(p + Vector2(0, gallop), sin(ph * 0.5) * 0.05 - tuck * 0.15 * _dir, f)
	Sprites.draw(self, "sheep_body")
	draw_set_transform(p + Vector2(30.0 * _dir, -36.0 + gallop + sin(ph * 0.5 + 0.8) * 2.0), sin(ph * 0.5) * 0.08, f)
	Sprites.draw(self, "sheep_head")
	draw_set_transform(Vector2.ZERO)
	# Polvo que levantan / Dust they kick up
	if z <= 0.1:
		var k := fposmod(ph, TAU) / TAU
		draw_circle(p + Vector2(-_dir * (34.0 + k * 20.0), -4.0 - k * 6.0), 4.0 + k * 6.0, Color(DUST, 0.3 * (1.0 - k)))
