class_name RunEvents
extends RefCounted
## Sucesos del sueño: el suceso al azar de cada sueño, el timbre del colegio, la taquilla con las gafas de sol y los edificios que se caen en la ciudad. / Dream events: each dream's random event, the school bell, the locker with the sunglasses and the falling buildings in the city.

var run: Run


func _init(r: Run) -> void:
	run = r


## Cada cierto tiempo se cae uno de los que están cerca de Kroker (el más deshecho)
## Every so often one of those near Kroker falls (the most worn out)
func update_city(delta: float) -> void:
	if not run.room is Act4Room:
		return
	var city := run.room as Act4Room
	run._fall_t -= delta
	if run._fall_t > 0.0:
		return
	var best: CityFall = null
	var best_score := -INF
	for t: CityFall in run._towers:
		if not is_instance_valid(t) or not t.standing():
			continue
		var dist := t.position.distance_to(run.player.position)
		if dist > 900.0 or dist < 120.0:
			continue
		var score := t.wear * 2.0 - dist / 900.0 + randf() * 0.4
		if score > best_score:
			best_score = score
			best = t
	if best == null:
		run._fall_t = 2.5   # ninguno cerca: se mira otra vez enseguida / none near: check again soon
		return
	best.topple()
	run._fall_t = randf_range(6.0, 10.0) if city.final else randf_range(14.0, 22.0)


## La taquilla abierta del pasillo: con la F, Kroker se pone las gafas de sol de Lil Key
## The hallway's open locker: with F, Kroker puts on Lil Key's sunglasses
func update_locker() -> void:
	if not run.room is Act3Room:
		return
	var ar := run.room as Act3Room
	if ar.locker_x == INF:
		return
	var spot := ar.locker_spot()
	ar.shades_near = absf(run.player.position.x - spot.x) < 70.0 and run.player.position.y - spot.y < 80.0 and run._modal == null
	if ar.shades_near and Input.is_action_just_pressed("interact"):
		ar.take_shades()
		GameState.run_shades = true
		run.player.cast_anim = 1.0
		Audio.play("pickup", -2.0)
		run.fx.dissipate(run.player.global_position + Vector2(0, -110), Color("ff6a8a"))
		run.fx.ring(run.player.global_position + Vector2(0, -110), 30.0, Color("ff6a8a"), 0.5, 2.0)
		run.fx.text(run.player.global_position + Vector2(0, -170), tr("SHADES_GOT"), Color("ffb0c0"), 26)
		Progress.flag("lilkey")


func roll_event(depth: int) -> void:
	run.event = ""
	# En el colegio el timbre suena en todos los sueños, varias veces, aparte del evento
	# At school the bell rings in every dream, several times, on top of the event
	if run.room is Act3Room and not run._wave.get("boss", false):
		run._bell_wait = randf_range(run.BELL_FIRST.x, run.BELL_FIRST.y)
	if run._wave.get("boss", false) or depth < 2 or randf() > run.EVENT_CHANCE:
		return
	# Nunca el mismo que en el sueño anterior / Never the same as in the previous dream
	var pool := run.EVENTS.duplicate()
	pool.erase(GameState.last_event)
	run.event = pool[randi() % pool.size()]
	GameState.last_event = run.event
	match run.event:
		"meteors":
			var m := MeteorShower.new()
			m.run = run
			run.world.add_child(m)
		"ice":
			var ice := IceFloor.new()
			ice.run = run
			run.world.add_child(ice)
			run.world.move_child(ice, run.room.get_index() + 1)
		"yawn":
			YawnHoles.ensure(run).set_event()
		"dark":
			var d := Darkness.new()
			d.run = run
			run.world.add_child(d)
		"tilt":
			var tf := TiltFloor.new()
			tf.run = run
			run.world.add_child(tf)
			run.world.move_child(tf, run.room.get_index() + 1)


func update_event(delta: float) -> void:
	match run.event:
		"tilt":
			# El suelo se inclina despacio hacia un lado y luego hacia otro
			# The floor slowly tips one way, then another
			run._tilt_t += delta
			var dir := Vector2.from_angle(run._tilt_t * 0.35 + sin(run._tilt_t * 0.21) * 2.0)
			run._tilt = run._tilt.lerp(dir * 75.0, minf(1.0, delta * 0.8))
			run.player.push = run._tilt
			for e: Node in run.enemies.get_children():
				if e is Enemy and not e.is_boss():
					e.external_pull += run._tilt * 0.8
			# La cámara se ladea con la pendiente y se desplaza un poco cuesta abajo
			# The camera leans with the slope and drifts a little downhill
			run._camera.rotation = lerpf(run._camera.rotation, -run._tilt.x / 75.0 * 0.06, minf(1.0, delta * 2.0))
			run._camera.offset += run._tilt * 0.35
			run.hud.set_tilt(run._tilt)
	if run._bell_wait > 0.0 or run._bell_t > 0.0 or (run.room is Act3Room and (run.room as Act3Room).bell_open > 0.0):
		update_bell(delta)


## Suena el timbre: las puertas se abren y salen enemigos sin parar durante un rato
## The bell rings: the doors open and enemies keep pouring out for a while
func update_bell(delta: float) -> void:
	var hall := run.room as Act3Room
	if run._bell_wait > 0.0:
		run._bell_wait -= delta
		if run._bell_wait <= 0.0:
			run._bell_t = run.BELL_TIME
			Audio.play("bell", -2.0)
			run.shake(5.0)
			run.hud.show_event("bell_on")
			run.fx.text(run.player.global_position + Vector2(0, -170), tr("BELL_RING"), UITheme.GOLD, 30)
		return
	if run._bell_t > 0.0:
		run._bell_t -= delta
		hall.bell_open = minf(1.0, hall.bell_open + delta * 3.0)
		run._bell_cd -= delta
		if run._bell_cd <= 0.0 and run.enemies.get_child_count() < run.BELL_MAX_ALIVE:
			run._bell_cd = run.BELL_EVERY
			var v := run.view_rect()
			var pts := hall.door_points((v.position.x - Bedroom.OFFSET.x) / Bedroom.S, (v.end.x - Bedroom.OFFSET.x) / Bedroom.S)
			if not pts.is_empty():
				var p := Bedroom.to_world(pts[randi() % pts.size()]) + Vector2(randf_range(-30, 30), randf_range(0, 20))
				var kind: String = ["foox", "foox", "thug", "sling", "puppet"][randi() % 5]
				run.fx.dissipate(p + Vector2(0, -30), Color("f6d993"))
				run._spawn_enemy(kind, p)
				# Salen corriendo de la puerta y se desperdigan por el pasillo (antes se quedaban
				# amontonados en la puerta y se barrían de un golpe)
				# They rush out of the door and scatter down the hall (they used to pile up at the
				# door and get swept away in one go)
				var last := run.enemies.get_child(run.enemies.get_child_count() - 1) as Enemy
				if last != null and not last is GoldenFoox:
					last.spawn_time = 0.15
					last.rush_t = randf_range(0.7, 1.0)
					# De lado, alejándose de Kroker, para no echársele encima sin avisar
					# Sideways, away from Kroker, so they don't pounce on him without warning
					var side := signf(p.x - run.player.global_position.x)
					if absf(p.x - run.player.global_position.x) < 40.0:
						side = 1.0 if randf() < 0.5 else -1.0
					last.rush_dir = Vector2(side, randf_range(0.2, 0.6)).normalized()
		if run._bell_t <= 0.0:
			run.hud.show_event(run.event)
			# Y al rato vuelve a sonar / And after a while it rings again
			run._bell_wait = randf_range(run.BELL_AGAIN.x, run.BELL_AGAIN.y)
	else:
		hall.bell_open = maxf(0.0, hall.bell_open - delta * 1.5)
