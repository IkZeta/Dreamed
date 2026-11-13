class_name RunSpawner
extends RefCounted
## Las oleadas: cuántos enemigos salen, cuáles (según los pesos del sueño y los topes de cada tipo),
## dónde y cómo (el Foox dorado de vez en cuando, los élites, los antidisturbios por las
## alcantarillas). Run llama a spawn_group() y los demás piden enemigos con Run.spawn_enemy_soon().
## Waves: how many enemies come, which (by the dream's weights and each kind's cap), where and how
## (the occasional golden Foox, elites, riot officers out of the manholes). Run calls
## spawn_group() and everyone else asks for enemies through Run.spawn_enemy_soon().

const GOLDEN_CHANCE := 0.005

var run: Run
var _spawned_new := 0
var _golden_done := false


func _init(r: Run) -> void:
	run = r


func spawn_group() -> void:
	var alive := 0
	for e in run.enemies.get_children():
		# Los mosquitos de los nidos no cuentan / Nest mosquitoes don't count
		if not e.is_boss() and not e is Mosquito and not e is BotcherTurret:
			alive += 1
	var group: Array = run._wave["group"]
	var count := mini(randi_range(group[0], group[1]), int(run._wave["max_alive"]) - alive)
	for i in count:
		var pos := spawn_point()
		var kind := pick_kind()
		run.fx.telegraph(pos + Vector2(0, -16), 0.8)
		run.get_tree().create_timer(0.8, false).timeout.connect(spawn.bind(kind, pos))


## Elige qué enemigo sale según los pesos del sueño; el enemigo nuevo sale seguro al principio.
## Picks which enemy appears by the dream's weights; the new enemy is guaranteed early on.
func pick_kind() -> String:
	var new_kind: String = run._wave.get("new", "")
	if new_kind != "" and _spawned_new < 2:
		_spawned_new += 1
		if new_kind in ["cyber", "van", "riot"] and _spawned_new > 1:
			pass   # solo sale uno seguro / only one is guaranteed
		elif new_kind != "nest" or run._count_alive(Nest) < 3:
			return new_kind
	var mix: Dictionary = run._wave["mix"]
	var total := 0.0
	for k: String in mix:
		total += float(mix[k])
	var roll := randf() * total
	for k: String in mix:
		roll -= float(mix[k])
		if roll <= 0.0:
			# Como mucho 3 nidos a la vez / At most 3 nests at a time
			if k == "nest" and run._count_alive(Nest) >= 3:
				return "foox"
			# Como mucho 2 Cyberpunks a la vez: muchos son un caos / At most 2 Cyberpunks at once: many is chaos
			if k == "cyber" and run._count_alive(Cyberpunk) >= 2:
				return "foox"
			# Como mucho 2 Gólems y 3 Marionetas / At most 2 Golems and 3 Puppets
			if k == "golem" and run._count_alive(Golem) >= 2:
				return "thug"
			if k == "puppet" and run._count_alive(Puppet) >= 3:
				return "foox"
			# Como mucho 2 Despertadores y 2 Exámenes / At most 2 Alarm Clocks and 2 Exams
			if k == "alarm" and run._count_alive(AlarmClock) >= 2:
				return "foox"
			if k == "exam" and run._count_alive(Exam) >= 2:
				return "thug"
			if k == "dreamcatcher" and run._count_alive(Dreamcatcher) >= 2:
				return "foox"
			# Como mucho 2 Chapuzas, y solo si hay agujeros / At most 2 Botchers, and only if there are holes
			if k == "botcher" and (run._count_alive(Botcher) >= 2 or run.room.hole_count() == 0):
				return "foox"
			# Acto 4: pocas furgos y antidisturbios a la vez / Act 4: few vans and riot officers at once
			var fin := bool(run._wave.get("final", false))
			if k == "van" and run._count_alive(Van) >= (2 if fin else 1):
				return "police"
			if k == "riot" and run._count_alive(Riot) >= (3 if fin else 2):
				return "police"
			if k == "police" and run._count_alive(Police) >= 10:
				return "thug"
			return k
	return "foox"


func spawn_point() -> Vector2:
	var area := run.arena_rect().grow(-30)
	# En el pasillo infinito salen alrededor de lo que se ve / In the endless hallway they spawn around the view
	if run.room.open_map():
		area = run.view_rect().grow(220.0).intersection(area)
	elif run.room.follows_camera():
		var v := run.view_rect()
		area = Rect2(Vector2(v.position.x - 200.0, area.position.y), Vector2(v.size.x + 400.0, area.size.y))
	for attempt in 30:
		var p := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(run.player.position) > 360.0 and not run._blocked(p, 40.0) and not run._near_boss(p):
			return p
	return Vector2(area.end.x - 40, area.end.y - 40)


## Aviso en el suelo y el enemigo aparece poco después / Floor warning, then the enemy appears shortly after
func spawn_soon(kind: String, pos: Vector2, delay: float) -> void:
	run.get_tree().create_timer(delay, false).timeout.connect(spawn.bind(kind, pos))


func spawn(kind: String, pos: Vector2) -> void:
	if not run.running:
		return
	Audio.play_at("spawn", pos, -13.0, 0.08)
	var e: Enemy
	match kind:
		"thug": e = Thug.new()
		"sling": e = SlingThug.new()
		"skeleton": e = Skeleton.new()
		"nest": e = Nest.new()
		"mosquito": e = Mosquito.new()
		"cyber": e = Cyberpunk.new()
		"puppet": e = Puppet.new()
		"golem": e = Golem.new()
		"police": e = Police.new()
		"van": e = Van.new()
		"riot": e = Riot.new()
		"botcher": e = Botcher.new()
		"alarm": e = AlarmClock.new()
		"exam": e = Exam.new()
		"dreamcatcher": e = Dreamcatcher.new()
		_: e = Foox.new()
	# Muy de vez en cuando, en lugar del enemigo sale un Foox dorado (la suerte ayuda un poco)
	# Every so often a golden Foox turns up instead (luck helps a little)
	if not _golden_done and GameState.dream_depth >= 2 and not run._wave.get("boss", false) \
			and randf() < GOLDEN_CHANCE * (1.0 + maxf(0.0, GameState.stat("luck")) / 50.0):
		_golden_done = true
		e.free()
		e = GoldenFoox.new()
		Audio.play("chime", -2.0)
		run.fx.ring(pos + Vector2(0, -20), 30.0, UITheme.GOLD, 0.8, 2.6)
	e.setup(run, 1.0, Run.FRENZY_SPEED if run.event == "frenzy" else (Run.SLEEPY_SPEED if run.event == "sleepy" else 1.0))
	e.position = pos
	# Los antidisturbios salen de una alcantarilla abierta / Riot officers climb out of an open manhole
	if e is Riot and run.room is Act4Room and run.room.hole_count() > 0:
		var best := Vector2.INF
		var list: Array[Rect2] = run.room.holes_list()
		for i in run.room.hole_count():
			var c := Bedroom.rect_world(list[i]).get_center()
			if run.view_rect().grow(150.0).has_point(c) and c.distance_to(run.player.position) > 300.0 and (best == Vector2.INF or c.distance_to(pos) < best.distance_to(pos)):
				best = c
		if best != Vector2.INF:
			e.position = best + Vector2(0, 50)
			(e as Riot).rise = 1.0
	# Élites desde el Sueño 2 / Elites from Dream 2
	if GameState.dream_depth >= 2 and not e is GoldenFoox and not e is Van and not e is Riot and randf() < (0.12 if GameState.difficulty == "nightmare" else 0.07):
		e.elite = true
	run.enemies.add_child(e)
