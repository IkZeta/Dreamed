class_name Helpers
extends Node
## SuperK y Lil Key en la partida: no cambian el arma, aparecen en el mapa y ayudan.
## Cada arma que lleva Kroker tiene uno de sus poderes (GameState.HELPER_POWER) con su recarga.
##
## SuperK:
## - "punch": baja volando y le da un puñetazo enorme al enemigo más fuerte.
## - "guard": a veces aparece justo cuando te van a dar y para el golpe.
## - "laser": cruza la pantalla volando y barre una fila de enemigos con los láseres de los ojos.
## - "throw": agarra a un enemigo y lo tira por el agujero más cercano (o lo estampa contra otros).
## Lil Key:
## - "dance": aparece a tu lado y los enemigos de alrededor se ponen a bailar (no hacen daño).
## - "sing": canta lejos de ti; los enemigos van hacia él y les hace daño poco a poco.
## Si Lil Key ya ha salido en este sueño, Kroker lleva puestas sus gafas de sol.
## D. Lynx:
## - "actor": aparece en su silla con el megáfono, grita "¡Acción!" y unos cuantos enemigos se ponen
##   a actuar de su parte un rato (luchan contra los demás). Sus otros poderes ("retake" y "cut")
##   no salen al mapa: los usan Kroker y la partida.
##
## SuperK and Lil Key in the run: they don't change the weapon, they show up on the map and help.
## Each weapon Kroker carries has one of their powers (GameState.HELPER_POWER) with its cooldown.
## SuperK: punch (swoops down and lands a huge punch on the toughest enemy), guard (sometimes shows
## up just as you're about to be hit and stops it), laser (flies across the screen sweeping a row of
## enemies with his eye lasers), throw (grabs an enemy and hurls it down the nearest hole, or slams
## it into the others). Lil Key: dance (turns up beside you and nearby enemies dance, dealing no
## damage), sing (sings away from you; enemies flock to him and slowly take damage). Once Lil Key
## has shown up in this dream, Kroker wears his sunglasses. D. Lynx: actor (shows up in his chair with
## the megaphone, shouts "Action!" and a few enemies act on his side for a while, fighting the rest).
## His other powers (retake and cut) don't show up on the map: Kroker and the run use them.

const SCALE := 0.5               # misma escala que Kroker / same scale as Kroker
const FLY_SPEED := 1500.0
const PUNCH_PUSH := 1100.0
const LASER_BAND := 60.0         # alto de la franja que barre el láser / height of the band the laser sweeps
const SLAM_RADIUS := 150.0
const DANCE_RADIUS := 330.0
const SING_PULL_RADIUS := 560.0
const SING_HURT_RADIUS := 170.0
const ACTOR_RADIUS := 520.0      # hasta dónde llega el grito de D. Lynx / how far D. Lynx's shout reaches
const LYNX_SHOW := 1.8           # lo que se queda en el plató / how long he stays on set

var run: Node
## Kroker se pone las gafas de sol (Lil Key ya ha salido en este sueño)
## Kroker puts the sunglasses on (Lil Key has already shown up this dream)
var shades := false
var _timers := {}                # "giver:weapon" → segundos que faltan / seconds left
var _guard_cd := 0.0
var _superk: Actor
var _lilkey: Actor
var _lynx: Actor
var _t := 0.0


func setup(r: Node) -> void:
	run = r
	for w: String in GameState.weapons():
		for g: String in ["superk", "lilkey", "lynx"]:
			if GameState.level(g, w) > 0 and GameState.UPGRADE_VALUES[g][w].has("cd"):
				# La primera vez sale a media recarga / The first time comes at half cooldown
				_timers[g + ":" + w] = GameState.up_value(g, "cd", -1, w) * 0.5


func _physics_process(delta: float) -> void:
	_t += delta
	_guard_cd = maxf(0.0, _guard_cd - delta)
	if not run.running:
		return
	for key: String in _timers:
		var g: String = key.get_slice(":", 0)
		var w: String = key.get_slice(":", 1)
		var power := GameState.helper_power(g, w)
		if power == "guard":
			continue
		_timers[key] = float(_timers[key]) - delta
		if float(_timers[key]) > 0.0:
			continue
		# Si ya está ocupado, espera un poco / If he's busy, wait a moment
		if (g == "superk" and is_instance_valid(_superk)) or (g == "lilkey" and is_instance_valid(_lilkey)) or (g == "lynx" and is_instance_valid(_lynx)):
			_timers[key] = 0.5
			continue
		if _start(g, power, w):
			_timers[key] = GameState.up_value(g, "cd", -1, w)
			# Lil Key con las dos armas no sale el doble: comparten la recarga y se turnan
			# (la otra arma sale en la siguiente, esta en la de después)
			# Lil Key with both weapons doesn't come twice as often: they share the cooldown and
			# take turns (the other weapon goes next, this one the time after)
			if g == "lilkey":
				for other: String in _timers:
					if other != key and other.begins_with("lilkey:"):
						_timers[other] = maxf(float(_timers[other]), GameState.up_value(g, "cd", -1, other.get_slice(":", 1)))
						_timers[key] = float(_timers[key]) * 2.0
		else:
			_timers[key] = 1.0


func _start(g: String, power: String, w: String) -> bool:
	var a := Actor.new()
	a.helpers = self
	a.who = g
	a.power = power
	a.weapon = w
	if not a.plan():
		a.free()
		return false
	run._actors.add_child(a)
	if g == "superk":
		_superk = a
	elif g == "lynx":
		_lynx = a
	else:
		_lilkey = a
		shades = true
	return true


## SuperK para el golpe: lo llama Kroker antes de recibir daño. true = golpe parado.
## SuperK stops the hit: Kroker calls this before taking damage. true = hit stopped.
func try_guard(source: Node2D) -> bool:
	if _guard_cd > 0.0 or is_instance_valid(_superk):
		return false
	for w: String in GameState.weapons():
		if GameState.helper_power("superk", w) != "guard" or GameState.level("superk", w) <= 0:
			continue
		if randf() * 100.0 >= GameState.up_value("superk", "chance", -1, w):
			continue
		_guard_cd = GameState.up_value("superk", "cd", -1, w)
		var a := Actor.new()
		a.helpers = self
		a.who = "superk"
		a.power = "guard"
		a.weapon = w
		a.target = source
		a.plan()
		run._actors.add_child(a)
		_superk = a
		return true
	return false


# --- Ayudas / Utilities ---------------------------------------------------------------

func enemies_alive() -> Array:
	var out := []
	for e: Node in run.enemies.get_children():
		if e is Enemy and (e as Enemy).is_targetable():
			out.append(e)
	return out


func in_view(p: Vector2, margin := 60.0) -> bool:
	return (run.view_rect() as Rect2).grow(-margin).has_point(p)


## Centro del agujero del suelo más cercano que se vea (Vector2.INF si no hay)
## Centre of the nearest visible floor hole (Vector2.INF if there's none)
func nearest_hole(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var holes: Array = run.room.holes_list()
	for i in run.room.hole_count():
		var c := Bedroom.rect_world(holes[i]).get_center()
		if in_view(c, 20.0) and (best == Vector2.INF or from.distance_to(c) < from.distance_to(best)):
			best = c
	return best


## Un ayudante en el mapa: va por fases (llegar, actuar, irse) y se dibuja solo.
## A helper on the map: goes through phases (arrive, act, leave) and draws itself.
class Actor extends Node2D:
	var helpers: Helpers
	var who := "superk"
	var power := "punch"
	var weapon := ""
	var target: Node2D
	var phase := "in"
	var alt := 0.0          # altura de vuelo (píxeles) / flight height (pixels)
	var facing := 1.0
	var flying := true
	var _t := 0.0
	var _phase_t := 0.0
	var _from := Vector2.ZERO
	var _to := Vector2.ZERO
	var _dur := 0.5
	var _hit := {}          # enemigos ya golpeados por el láser / enemies already hit by the laser
	var _carry: Enemy
	var _tick := 0.0
	var _secs := 0.0
	var _fade := 0.0

	func _ready() -> void:
		z_index = 2

	## Decide qué hace; false si no tiene sentido ahora (no hay enemigos)
	## Decides what to do; false if it makes no sense right now (no enemies)
	func plan() -> bool:
		var run: Node = helpers.run
		var kroker: Vector2 = run.player.global_position
		var view: Rect2 = run.view_rect()
		var foes := helpers.enemies_alive()
		match power:
			"punch":
				var best: Enemy = null
				for e: Enemy in foes:
					if helpers.in_view(e.global_position) and (best == null or e.hp > best.hp):
						best = e
				if best == null:
					return false
				target = best
				_fly_in(best.global_position)
			"laser":
				# La fila con más enemigos / The row with the most enemies
				var best_y := 0.0
				var best_n := 0
				for e: Enemy in foes:
					if not helpers.in_view(e.global_position):
						continue
					var n := 0
					for o: Enemy in foes:
						if absf(o.global_position.y - e.global_position.y) < LASER_BAND:
							n += 1
					if n > best_n:
						best_n = n
						best_y = e.global_position.y
				if best_n == 0:
					return false
				facing = 1.0 if randf() < 0.5 else -1.0
				_from = Vector2(view.position.x - 140.0 if facing > 0.0 else view.end.x + 140.0, best_y)
				_to = Vector2(view.end.x + 140.0 if facing > 0.0 else view.position.x - 140.0, best_y)
				position = _from
				alt = 150.0
				phase = "sweep"
				_dur = _from.distance_to(_to) / 900.0
				Audio.play("dash", -8.0)
				Audio.leitmotif("superk", -2.0, -14.0)
			"throw":
				var best: Enemy = null
				var best_d := INF
				for e: Enemy in foes:
					if e.is_boss() or not e.can_fall() or not helpers.in_view(e.global_position):
						continue
					var hole := helpers.nearest_hole(e.global_position)
					var d := e.global_position.distance_to(hole) if hole != Vector2.INF else 99999.0 + e.global_position.distance_to(kroker)
					if d < best_d:
						best_d = d
						best = e
				if best == null:
					return false
				target = best
				_fly_in(best.global_position)
			"guard":
				# Aparece de golpe entre Kroker y el golpe / Appears at once between Kroker and the hit
				var side := 1.0
				if is_instance_valid(target):
					side = signf(target.global_position.x - kroker.x) if absf(target.global_position.x - kroker.x) > 1.0 else 1.0
				facing = side
				position = kroker + Vector2(46.0 * side, 6.0)
				alt = 0.0
				flying = false
				phase = "guard"
				_dur = 0.9
				run.fx.ring(position + Vector2(0, -60), 60.0, Color("b48cff"), 0.4, 2.0)
				run.fx.text(kroker + Vector2(0, -150), tr("SUPERK_BLOCK"), Color("e0c8ff"), 24)
				Audio.play("pillow", -4.0)
				Audio.leitmotif("superk", -2.0, -14.0)
				run.player.set("_invuln", 0.6)
				if is_instance_valid(target) and target is Enemy and not (target as Enemy).is_boss():
					(target as Enemy).hit(5.0, (target.global_position - kroker).normalized() * 700.0)
			"dance":
				flying = false
				position = kroker + Vector2(randf_range(-1.0, 1.0) * 110.0, -70.0)
				position = run.clamp_to_arena(position, 30.0)
				_secs = GameState.up_value("lilkey", "secs", -1, weapon)
				phase = "show"
				_appear()
			"sing":
				flying = false
				# Lejos de Kroker, pero a la vista / Away from Kroker, but in view
				var best := Vector2.INF
				for i in 12:
					var p := Vector2(randf_range(view.position.x + 120.0, view.end.x - 120.0), randf_range(view.position.y + 160.0, view.end.y - 80.0))
					p = run.clamp_to_arena(p, 40.0)
					if best == Vector2.INF or p.distance_to(kroker) > best.distance_to(kroker):
						best = p
				position = best
				_secs = GameState.up_value("lilkey", "secs", -1, weapon)
				phase = "show"
				_appear()
			"actor":
				# Los más cercanos a Kroker que se puedan poner a actuar / The ones closest to Kroker that can be made to act
				var cast: Array = []
				for e: Enemy in foes:
					if e.can_act() and helpers.in_view(e.global_position) and e.global_position.distance_to(kroker) < ACTOR_RADIUS:
						cast.append(e)
				if cast.size() < 2:
					return false
				cast.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.distance_squared_to(kroker) < b.global_position.distance_squared_to(kroker))
				cast.resize(mini(cast.size(), int(GameState.up_value("lynx", "count", -1, weapon))))
				flying = false
				facing = 1.0 if randf() < 0.5 else -1.0
				position = run.clamp_to_arena(kroker + Vector2(-facing * 120.0, -40.0), 40.0)
				_secs = LYNX_SHOW
				phase = "show"
				_fade = 0.0
				var secs := GameState.up_value("lynx", "secs", -1, weapon)
				var dmg := GameState.up_value("lynx", "dmg", -1, weapon)
				for e: Enemy in cast:
					e.start_acting(secs, dmg)
					run.fx.ring(e.global_position + Vector2(0, -20), 30.0, Color("e0303a"), 0.4, 2.4)
				set_meta("cast", cast)
				run.fx.ring(position + Vector2(0, -50), 60.0, Color("e0303a"), 0.5, 2.4)
				run.fx.text(position + Vector2(0, -180), tr("LYNX_SHOUT"), Color("ffb0b0"), 24)
				Audio.play("snap", -4.0, 0.05)
				Audio.leitmotif("lynx", -2.0, -14.0)
		return true

	func _appear() -> void:
		var run: Node = helpers.run
		_fade = 0.0
		run.fx.ring(position + Vector2(0, -50), 50.0, Color("ff6a8a"), 0.5, 2.4)
		run.fx.text(position + Vector2(0, -170), tr("LILKEY_SHOUT"), Color("ffb0c0"), 22)
		# Su leitmotiv al aparecer (la música baja un poco) / His leitmotif when he shows up (the music dips a little)
		Audio.leitmotif("lilkey", -2.0, -14.0)

	## Entra volando en diagonal desde arriba / Flies in diagonally from above
	func _fly_in(at: Vector2) -> void:
		var run: Node = helpers.run
		var view: Rect2 = run.view_rect()
		facing = 1.0 if at.x > view.get_center().x - 1.0 and randf() < 0.5 else (-1.0 if at.x > view.get_center().x else 1.0)
		_from = Vector2(at.x - facing * 700.0, view.position.y - 200.0)
		_to = at - Vector2(facing * 50.0, 0)
		position = _from
		alt = 0.0
		phase = "in"
		_dur = maxf(0.35, _from.distance_to(_to) / FLY_SPEED)
		run.fx.text(_to + Vector2(0, -160), tr("SUPERK_SHOUT"), Color("e0c8ff"), 22)
		Audio.play("dash", -6.0)
		Audio.leitmotif("superk", -2.0, -14.0)

	func _fly_out() -> void:
		phase = "out"
		_phase_t = 0.0
		_from = position
		_to = position + Vector2(facing * 900.0, -900.0)
		_dur = 0.6
		flying = true

	func _physics_process(delta: float) -> void:
		_t += delta
		_phase_t += delta
		_fade = minf(1.0, _fade + delta * 4.0)
		var run: Node = helpers.run
		var k := clampf(_phase_t / _dur, 0.0, 1.0)
		match phase:
			"in":
				position = _from.lerp(_to, k * (2.0 - k))
				if is_instance_valid(target) and power == "punch":
					_to = target.global_position - Vector2(facing * 50.0, 0)
				if k >= 1.0:
					_phase_t = 0.0
					flying = false
					if power == "punch":
						_punch()
						phase = "pose"
						_dur = 0.45
					else:
						_grab()
			"pose":
				if k >= 1.0:
					_fly_out()
			"carry":
				position = _from.lerp(_to, k * k * (3.0 - 2.0 * k))
				alt = sin(k * PI) * 60.0
				if is_instance_valid(_carry):
					_carry.global_position = position + Vector2(facing * 30.0, -10.0 - alt)
					_carry.stun_t = maxf(_carry.stun_t, 0.2)
					_carry.knock = Vector2.ZERO
				if k >= 1.0:
					_drop()
			"sweep":
				position = _from.lerp(_to, k)
				_laser_hits()
				if k >= 1.0:
					queue_free()
			"out":
				position = _from.lerp(_to, k * k)
				if k >= 1.0:
					queue_free()
			"guard":
				if k >= 1.0:
					_fly_out()
			"show":
				_secs -= delta
				if who == "lilkey":
					_lilkey_effect(delta)
				if _secs <= 0.0:
					phase = "gone"
					_phase_t = 0.0
					_dur = 0.35
					run.fx.ring(position + Vector2(0, -50), 40.0, Color("e0303a" if who == "lynx" else "ff6a8a"), 0.4, 2.0)
			"gone":
				_fade = 1.0 - k
				if k >= 1.0:
					queue_free()
		queue_redraw()

	func _punch() -> void:
		var run: Node = helpers.run
		if not is_instance_valid(target):
			return
		var e := target as Enemy
		var dir := Vector2(facing, -0.1).normalized()
		e.hit(GameState.up_value("superk", "dmg", -1, weapon) * run.player.damage_mult, dir * PUNCH_PUSH * e.mass)
		run.shake(7.0)
		run.fx.ring(e.global_position + Vector2(0, -40), 46.0, Color("ffe08a"), 0.35, 2.2)
		run.fx.text(e.global_position + Vector2(0, -120), "¡POW!" if TranslationServer.get_locale().begins_with("es") else "POW!", Color("ffe08a"), 30)
		Audio.play("punch", -2.0)

	func _grab() -> void:
		var run: Node = helpers.run
		if not is_instance_valid(target):
			_fly_out()
			return
		_carry = target as Enemy
		var hole := helpers.nearest_hole(_carry.global_position)
		_from = position
		if hole != Vector2.INF:
			_to = hole - Vector2(facing * 30.0, -10.0)
		else:
			# Sin agujero: lo lleva hasta el montón más grande de enemigos / No hole: carries it to the biggest pile of enemies
			var best := position
			var best_n := -1
			for e: Enemy in helpers.enemies_alive():
				if e == _carry:
					continue
				var n := 0
				for o: Enemy in helpers.enemies_alive():
					if o.global_position.distance_to(e.global_position) < SLAM_RADIUS:
						n += 1
				if n > best_n:
					best_n = n
					best = e.global_position
			_to = best - Vector2(facing * 30.0, -10.0)
		set_meta("hole", hole)
		phase = "carry"
		_phase_t = 0.0
		_dur = clampf(_from.distance_to(_to) / 700.0, 0.4, 1.2)
		flying = true
		Audio.play("throw", -6.0)

	func _drop() -> void:
		var run: Node = helpers.run
		var hole: Vector2 = get_meta("hole", Vector2.INF)
		if is_instance_valid(_carry) and _carry.state == Enemy.State.ALIVE:
			if hole != Vector2.INF:
				_carry._start_fall(hole)
			else:
				var at := _carry.global_position + Vector2(0, 10)
				_carry.global_position = run.clamp_to_arena(at, _carry.radius)
				var dmg: float = GameState.up_value("superk", "dmg", -1, weapon) * run.player.damage_mult
				for e: Enemy in helpers.enemies_alive():
					if e.global_position.distance_to(at) < SLAM_RADIUS:
						e.hit(dmg * (2.0 if e == _carry else 1.0), (e.global_position - at).normalized() * 500.0 * e.mass)
				run.shake(8.0)
				run.fx.ring(at, SLAM_RADIUS, Color("b48cff"), 0.45, 1.4)
				Audio.play("stomp", -2.0)
		_carry = null
		_fly_out()

	func _laser_hits() -> void:
		var run: Node = helpers.run
		var dmg: float = GameState.up_value("superk", "dmg", -1, weapon) * run.player.damage_mult
		for e: Enemy in helpers.enemies_alive():
			if _hit.has(e):
				continue
			var p := e.global_position
			if absf(p.y - position.y) < LASER_BAND and absf(p.x - (position.x + facing * 40.0)) < 40.0:
				_hit[e] = true
				e.hit(dmg)
				run.fx.ring(p + Vector2(0, -20), 20.0, Color("ff4a5a"), 0.3, 2.0)
				Audio.play("laser", -12.0, 0.1)

	func _lilkey_effect(delta: float) -> void:
		var run: Node = helpers.run
		_tick -= delta
		var tick := _tick <= 0.0
		if tick:
			_tick = 0.5
		for e: Enemy in helpers.enemies_alive():
			if e.is_boss():
				continue
			var d := e.global_position.distance_to(position)
			if power == "dance":
				if e.global_position.distance_to(run.player.global_position) < DANCE_RADIUS or d < DANCE_RADIUS * 0.7:
					e.dance_t = maxf(e.dance_t, 0.6)
			else:
				if d < SING_PULL_RADIUS and d > 60.0:
					var pull := maxf(170.0, e.speed * 1.4)
					e.external_pull += (position - e.global_position).normalized() * pull
				if d < SING_HURT_RADIUS:
					e.dance_t = maxf(e.dance_t, 0.6)
					if tick:
						e.hit(GameState.up_value("lilkey", "dmg", -1, weapon) * 0.5 * run.player.damage_mult)

	func _draw() -> void:
		var s := SCALE
		var a := _fade if who != "superk" else 1.0
		modulate.a = a
		if who == "lynx":
			_draw_lynx(s)
			return
		if who == "lilkey":
			draw_colored_polygon(_ring(Vector2.ZERO, Vector2(46, 12)), Color(0, 0, 0, 0.25))
			# Altavoz a sus pies y ondas de sonido / Speaker at his feet and sound waves
			var pulse := 0.5 + 0.5 * sin(_t * 8.4)
			var r := (DANCE_RADIUS if power == "dance" else SING_HURT_RADIUS) * (0.4 + 0.6 * fposmod(_t * 0.9, 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color("ff6a8a", 0.35 * (1.0 - fposmod(_t * 0.9, 1.0))), 3.0)
			draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(Vector2(34, -36), Vector2(26, 36)), Color("1e1f2e"))
			draw_circle(Vector2(47, -24), 7.0 + pulse * 1.5, Color("4a4f72"))
			draw_circle(Vector2(47, -24), 3.0, Color("ff6a8a"))
			draw_circle(Vector2(47, -8), 4.0, Color("4a4f72"))
			NpcArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, Vector2(-100.0 * s, -288.0 * s)), "lilkey", _t, {"dance": 1.0})
			return
		# SuperK: sombra en el suelo y el cuerpo en el aire / SuperK: shadow on the ground and the body in the air
		var air := alt + (40.0 if flying else 0.0)
		draw_colored_polygon(_ring(Vector2.ZERO, Vector2(40.0 - air * 0.1, 10.0)), Color(0, 0, 0, 0.25 * clampf(1.0 - air / 400.0, 0.2, 1.0)))
		var xf := Transform2D(0.0, Vector2(s * facing, s), 0.0, Vector2(-100.0 * s * facing, -288.0 * s - air))
		if flying:
			NpcArt.draw(self, xf * Transform2D(0.0, Vector2(0, 110)), "superk", _t, {"fly": true})
		else:
			NpcArt.draw(self, xf, "superk", _t, {"hover": phase == "guard"})
			if phase == "guard":
				var k := clampf(_phase_t / 0.3, 0.0, 1.0)
				var a0 := -1.4 if facing > 0.0 else PI - 1.4
				draw_arc(Vector2(facing * 30.0, -70.0), 70.0, a0, a0 + 2.8, 20, Color("b48cff", 0.8 * (1.0 - k * 0.5)), 5.0)
		if phase == "sweep":
			# Láseres de los ojos hasta el suelo / Eye lasers down to the ground
			var eyes := Vector2(facing * 20.0, -air - 60.0)
			var ground := Vector2(facing * 40.0, 0.0)
			for off in [-4.0, 4.0]:
				draw_line(eyes + Vector2(0, off), ground + Vector2(0, off * 2.0), Color("ff4a5a", 0.9), 4.0)
				draw_line(eyes + Vector2(0, off), ground + Vector2(0, off * 2.0), Color("ffe0e0"), 1.5)
			draw_circle(ground, 14.0 + sin(_t * 30.0) * 3.0, Color("ff4a5a", 0.5))

	## D. Lynx en el plató: foco desde arriba, silla de director y el megáfono en alto; una tira de
	## película une su silla con cada enemigo que actúa / D. Lynx on set: a spotlight from above, the
	## director's chair and the megaphone up; a film strip links his chair to each acting enemy
	func _draw_lynx(s: float) -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-20, -260), Vector2(20, -260), Vector2(70, 0), Vector2(-70, 0)]), Color(1.0, 0.95, 0.8, 0.10))
		draw_colored_polygon(_ring(Vector2.ZERO, Vector2(60, 14)), Color(1.0, 0.95, 0.8, 0.18))
		for e: Variant in get_meta("cast", []):
			if is_instance_valid(e) and (e as Enemy).actor_t > 0.0:
				var to: Vector2 = (e as Node2D).global_position - global_position + Vector2(0, -30)
				var k := clampf(_phase_t * 3.0, 0.0, 1.0)
				var end := Vector2(0, -60).lerp(to, k)
				draw_line(Vector2(0, -60), end, Color("16141a", 0.8), 7.0)
				var n := int(Vector2(0, -60).distance_to(end) / 12.0)
				for i in n:
					draw_rect(Rect2(Vector2(0, -60).lerp(end, (i + 0.5) / maxf(1.0, n)) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 1, 1, 0.7))
		var xf := Transform2D(0.0, Vector2(s * facing, s), 0.0, Vector2(-100.0 * s * facing, -288.0 * s))
		NpcArt.draw(self, xf, "lynx", _t, {"shout": clampf(_phase_t * 4.0, 0.0, 1.0)})

	func _ring(c: Vector2, r: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 20:
			var ang := TAU * i / 20.0
			pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
		return pts
