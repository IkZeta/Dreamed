class_name Run
extends Node2D
## Una partida: el escenario, la oleada actual, Kroker, los enemigos y las pantallas
## de pausa, victoria y derrota. El Sueño 1 ocurre en la habitación de Kroker y
## empieza con él levantándose de la cama.
## One run: the stage, the current wave, Kroker, the enemies and the pause, win and
## lose screens. Dream 1 takes place in Kroker's bedroom and starts with him
## getting out of bed.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const SETTINGS_SCENE := preload("res://scenes/settings_menu.tscn")

var running := false
var player: Player
var enemies: Node2D
var fx: FX
var hud: HUD
var room: Bedroom
## Mundo de la partida, dibujado a 960 x 540 y ampliado x2 sin suavizar (pixel art).
## The run's world, drawn at 960 x 540 and scaled up x2 without smoothing (pixel art).
var world: Node2D
const PIXEL_SHRINK := 2

var _wave: Dictionary
var _time_left := 0.0
var _spawn_timer := 1.2
var _kills := 0
var _camera: Camera2D
var _shake := 0.0
var _overlay: DreamOverlay
var _spawned_new := 0
var boss: BossPiece
var bosses: Array[BossPiece] = []
var _boss_step := 0
var _level_screen: LevelUpScreen
## Evento de este sueño: "", "dark", "tilt" o "golden" / This dream's event
var event := ""
var _tilt := Vector2.ZERO
var _tilt_t := 0.0
var _golden_t := -1.0


func _ready() -> void:
	var depth := GameState.dream_depth
	_wave = GameState.wave_for(depth)
	Audio.play_music("music_dream1", 2.5)
	_time_left = float(_wave.get("duration", 0.0))

	# Pantalla pequeña donde vive el mundo / Small screen where the world lives
	var screen := CanvasLayer.new()
	screen.layer = 0
	add_child(screen)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.stretch_shrink = PIXEL_SHRINK
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vp := SubViewport.new()
	vp.snap_2d_transforms_to_pixel = true
	vp.snap_2d_vertices_to_pixel = true
	vp.msaa_2d = Viewport.MSAA_DISABLED
	holder.add_child(vp)
	world = Node2D.new()
	vp.add_child(world)

	# El cielo del sueño rodea la habitación / The dream sky surrounds the room
	var back := CanvasLayer.new()
	back.layer = -1
	world.add_child(back)
	var sky := DreamBackground.new()
	sky.show_halo = false  # la luna ya se ve por la ventana / the moon is already in the window
	back.add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	room = Bedroom.new()
	room.outfit = GameState.selected_character
	room.weird = depth - 1
	if depth > 1:
		# Ya despierto en el sueño: la cama está vacía y el arma ya la lleva
		# Already awake in the dream: the bed is empty and he already has his weapon
		room.bed_state = "empty"
		room.glasses_on_stand = false
		room.weapon_taken = true
	world.add_child(room)

	_camera = Camera2D.new()
	_camera.position = Vector2(960, 540)
	_camera.zoom = Vector2.ONE / PIXEL_SHRINK
	world.add_child(_camera)
	_camera.make_current()

	# Actores ordenados por altura / Actors sorted by height
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	enemies = Node2D.new()
	enemies.y_sort_enabled = true
	actors.add_child(enemies)
	player = Player.new()
	player.position = Bedroom.to_world(Bedroom.WAKE_POINT)
	player.visible = false
	actors.add_child(player)
	player.setup(self, GameState.selected_character)

	fx = FX.new()
	world.add_child(fx)

	hud = HUD.new()
	add_child(hud)
	hud.visible = false
	hud.set_hp(player.hp, player.max_hp)
	hud.set_time(_time_left)
	if GameState.selected_character == "shield" and GameState.level("svinho") > 0:
		hud.set_special_mode(false)
	_roll_event(depth)
	if depth == 1:
		_play_wake_up(depth)
	else:
		_drop_in(depth)


## En los sueños siguientes Kroker cae desde lo alto entre estrellas.
## In later dreams Kroker falls in from above among stars.
func _drop_in(depth: int) -> void:
	var start := Bedroom.to_world(Bedroom.START_POINT)
	player.position = start
	player.hop = 600.0
	player.visible = true
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(player, "hop", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		player.land()
		Audio.play("land")
		Audio.play("crack", -4.0)
		shake(6.0)
		fx.dissipate(start + Vector2(0, -20), UITheme.GOLD)
		fx.ring(start, 30.0, UITheme.GOLD, 0.5, 2.4))
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		hud.visible = true
		hud.start(depth)
		hud.show_event(event)
		running = true
		_resolve_level_ups(Callable())
		if _wave.get("boss", false):
			_spawn_boss())


## El jefe del acto: los muebles despiertan de uno en uno / The act boss: the furniture wakes up one at a time
func _spawn_boss() -> void:
	Audio.play_music("music_boss", 1.0)
	hud.show_boss("BOSS_NAME")
	_boss_step = 0
	if GameState.difficulty == "nightmare":
		# Pesadilla: los tres muebles despiertan a la vez / Nightmare: all three pieces wake at once
		hud.set_boss_part("BOSS_PART_ALL")
		for i in BossPiece.ORDER.size():
			get_tree().create_timer(0.6 * i, false).timeout.connect(_add_boss_piece.bind(BossPiece.ORDER[i], 1.6))
		_boss_step = BossPiece.ORDER.size()
	else:
		_next_boss_piece()


func _next_boss_piece() -> void:
	if _boss_step >= BossPiece.ORDER.size():
		_on_act_cleared()
		return
	var kind: String = BossPiece.ORDER[_boss_step]
	_boss_step += 1
	hud.set_boss_part(BossPiece.PARTS[kind]["name"])
	_add_boss_piece(kind)


func _add_boss_piece(kind: String, slow := 1.0) -> void:
	if not running:
		return
	room.gone.append(kind)
	boss = BossPiece.new()
	boss.attack_slow = slow
	boss.setup_piece(self, kind)
	enemies.add_child(boss)
	bosses.append(boss)
	boss.defeated.connect(_on_piece_defeated)
	update_boss_hp()


## Barra del jefe: la vida que les queda a los muebles despiertos / Boss bar: health left on the awake pieces
func update_boss_hp() -> void:
	var hp := 0.0
	var total := 0.0
	for b in bosses:
		if is_instance_valid(b) and b._dying < 0.0:
			hp += maxf(b.hp, 0.0)
		total += BossPiece.HP_PER_PIECE * GameState.enemy_hp_mult()
	hud.set_boss_hp(hp, maxf(total, 1.0))


func _on_piece_defeated() -> void:
	if not running:
		return
	update_boss_hp()
	if _boss_step >= BossPiece.ORDER.size():
		# Se acaba cuando no queda ningún mueble en pie / It ends when no piece is left standing
		for b in bosses:
			if is_instance_valid(b) and b._dying < 0.0:
				return
		if bosses.size() >= BossPiece.ORDER.size():
			_on_act_cleared()
		return
	# Respiro entre muebles (los enemigos siguen saliendo) / A breather between pieces (enemies keep coming)
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void:
		if running:
			_next_boss_piece())


## Intro: Kroker duerme, se revuelve, se incorpora, se estira, se pone las gafas,
## sale de la cama, va a por su arma y empieza el sueño.
## Intro: Kroker sleeps, tosses, sits up, stretches, puts on his glasses, gets out
## of bed, goes to fetch his weapon and the dream begins.
func _play_wake_up(depth: int) -> void:
	var outfit := GameState.selected_character
	var wake := Bedroom.to_world(Bedroom.WAKE_POINT)
	var start := Bedroom.to_world(Bedroom.START_POINT)
	var pickup := Bedroom.to_world(Bedroom.PICKUP.get(outfit, Bedroom.START_POINT))
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(room, "stir", 1.0, 0.9)
	tw.tween_callback(func() -> void:
		room.bed_state = "sitting"
		Audio.play("blanket"))
	tw.tween_property(room, "sit", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Audio.play.bind("yawn"))
	tw.tween_property(room, "stretch", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.45)
	tw.tween_property(room, "stretch", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		room.glasses_on_stand = false
		Audio.play("chime")
		fx.dissipate(Bedroom.to_world(Bedroom.NIGHTSTAND.position + Vector2(30, 64)), UITheme.GOLD))
	tw.tween_interval(0.4)
	# Se desliza hasta el borde de la cama, mirando hacia fuera
	# Shuffles to the edge of the bed, facing out
	tw.tween_callback(Audio.play.bind("blanket"))
	tw.tween_property(room, "slide", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Baja de un saltito a la alfombrita / Hops down onto the little rug
	tw.tween_callback(func() -> void:
		room.bed_state = "empty"
		player.armed = false
		player.set_facing(1.0)
		player.position = Bedroom.to_world(room.sitting_feet())
		player.visible = true)
	tw.tween_method(_hop_down.bind(Bedroom.to_world(room.sitting_feet_end()), wake), 0.0, 1.0, 0.55)
	tw.tween_callback(func() -> void:
		player.hop = 0.0
		player.land()
		Audio.play("land")
		fx.ring(wake + Vector2(0, -4), 22.0, UITheme.BONE, 0.4, 2.2))
	tw.tween_interval(0.35)
	tw.tween_property(player, "position", pickup, _walk_time(wake, pickup))
	tw.tween_callback(func() -> void:
		room.weapon_taken = true
		player.armed = true
		player.attack_anim = 1.0
		player.cast_anim = 1.0
		Audio.play("pickup")
		fx.dissipate(pickup + Vector2(0, -80), UITheme.GOLD)
		fx.ring(pickup + Vector2(0, -80), 30.0, UITheme.GOLD, 0.5, 2.0))
	tw.tween_interval(0.6)
	tw.tween_property(player, "position", start, _walk_time(pickup, start))
	tw.tween_callback(func() -> void:
		hud.visible = true
		hud.start(depth)
		hud.show_event(event)
		running = true)


## Salto en arco desde la cama al suelo / Arcing hop from the bed to the floor
func _hop_down(k: float, from: Vector2, to: Vector2) -> void:
	player.position = from.lerp(to, k)
	player.hop = sin(k * PI) * 34.0


func _walk_time(a: Vector2, b: Vector2) -> float:
	return maxf(0.3, a.distance_to(b) / 280.0)


func _physics_process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 30.0)
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * Settings.shake_amount
	if not running:
		player.push = Vector2.ZERO
		return
	GameState.run_time += delta
	_update_event(delta)
	if not _wave.get("boss", false):
		_time_left -= delta
		hud.set_time(_time_left)
		if _time_left <= 0.0:
			_on_wave_cleared()
			return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _wave["spawn_every"]
		_spawn_group()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.god_mode and running and _level_screen == null and _overlay == null \
			and event is InputEventKey and event.pressed and not event.echo:
		if _god_key(event.physical_keycode):
			get_viewport().set_input_as_handled()
			return
	# Con mando: el botón Select cambia la invulnerabilidad del modo Dios
	# With a gamepad: the Select button toggles god mode invulnerability
	if GameState.god_mode and running and event is InputEventJoypadButton and event.pressed \
			and event.button_index == JOY_BUTTON_BACK:
		_god_key(KEY_F)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and running and _overlay == null and _level_screen == null:
		get_viewport().set_input_as_handled()
		_open_pause()


## Teclas del modo Dios / God mode keys
func _god_key(key: Key) -> bool:
	match key:
		KEY_F:
			GameState.god_invuln = not GameState.god_invuln
			hud.set_god()
			Audio.play("chime", -8.0)
		KEY_N:
			if _wave.get("boss", false):
				for b in bosses:
					if is_instance_valid(b) and b.is_targetable():
						b.hit(1000000.0)
						break
			else:
				_on_wave_cleared()
		KEY_K:
			for e: Node in enemies.get_children():
				if not e is BossPiece:
					e.die(false)
		KEY_L:
			collect_shards(GameState.xp_needed() - GameState.xp)
		_:
			return false
	return true


# --- Oleada / Wave ----------------------------------------------------------

func _spawn_group() -> void:
	var alive := 0
	for e in enemies.get_children():
		if not e is BossPiece:
			alive += 1
	var group: Array = _wave["group"]
	var count := mini(randi_range(group[0], group[1]), int(_wave["max_alive"]) - alive)
	for i in count:
		var pos := _spawn_point()
		var kind := _pick_kind()
		fx.telegraph(pos + Vector2(0, -16), 0.8)
		get_tree().create_timer(0.8, false).timeout.connect(_spawn_enemy.bind(kind, pos))


## Elige qué enemigo sale según los pesos del sueño; el enemigo nuevo sale seguro al principio.
## Picks which enemy appears by the dream's weights; the new enemy is guaranteed early on.
func _pick_kind() -> String:
	var new_kind: String = _wave.get("new", "")
	if new_kind != "" and _spawned_new < 2:
		_spawned_new += 1
		return new_kind
	var mix: Dictionary = _wave["mix"]
	var total := 0.0
	for k: String in mix:
		total += float(mix[k])
	var roll := randf() * total
	for k: String in mix:
		roll -= float(mix[k])
		if roll <= 0.0:
			return k
	return "foox"


func _spawn_point() -> Vector2:
	var area := Bedroom.rect_world(Bedroom.WALKABLE).grow(-30)
	for attempt in 30:
		var p := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(player.position) > 360.0 and not _blocked(p, 40.0) and not _near_boss(p):
			return p
	return Vector2(area.end.x - 40, area.end.y - 40)


## Aviso en el suelo y el enemigo aparece poco después / Floor warning, then the enemy appears shortly after
func spawn_enemy_soon(kind: String, pos: Vector2, delay: float) -> void:
	get_tree().create_timer(delay, false).timeout.connect(_spawn_enemy.bind(kind, pos))


func _spawn_enemy(kind: String, pos: Vector2) -> void:
	if not running:
		return
	Audio.play("spawn", -13.0, 0.08)
	var e: Enemy
	match kind:
		"thug": e = Thug.new()
		"sling": e = SlingThug.new()
		"skeleton": e = Skeleton.new()
		_: e = Foox.new()
	e.setup(self)
	e.position = pos
	# Élites desde el Sueño 2 / Elites from Dream 2
	if GameState.dream_depth >= 2 and randf() < (0.12 if GameState.difficulty == "nightmare" else 0.07):
		e.elite = true
	enemies.add_child(e)


## Rectángulo de la zona de juego en pantalla / Play area rectangle on screen
func arena_rect() -> Rect2:
	return Bedroom.rect_world(Bedroom.WALKABLE)


## Si un enemigo empujado cae por un agujero, devuelve hacia dónde cae; si no, Vector2.INF.
## If a shoved enemy falls into a hole, returns where it falls to; otherwise Vector2.INF.
func hole_at(p: Vector2, margin: float, push: Vector2) -> Vector2:
	for i in room.hole_count():
		var hr := Bedroom.rect_world(Bedroom.HOLES[i].grow(-10)).grow(margin * 0.6)
		if hr.has_point(p):
			return Bedroom.rect_world(Bedroom.HOLES[i]).get_center()
	# Boquetes de la pared: hay que ir hacia arriba contra el fondo
	# Wall holes: it has to be moving up against the back
	var top := arena_rect().position.y + margin * 0.5
	if p.y <= top + 6.0 and push.y < -60.0:
		for i in room.wall_hole_count():
			var wr := Bedroom.rect_world(Bedroom.WALL_HOLES[i])
			if p.x > wr.position.x + 6.0 and p.x < wr.end.x - 6.0:
				return Vector2(wr.get_center().x, wr.end.y - wr.size.y * 0.3)
	return Vector2.INF


func _near_boss(p: Vector2) -> bool:
	for b in bosses:
		if is_instance_valid(b) and p.distance_to(b.aim_point()) < 160.0:
			return true
	return false


func _blocked(p: Vector2, margin: float) -> bool:
	for r in room.blockers():
		if Bedroom.rect_world(r).grow(margin).has_point(p):
			return true
	return false


## Mantiene a alguien dentro del suelo y fuera de los muebles.
## Keeps someone on the floor and out of the furniture.
func clamp_to_arena(p: Vector2, margin: float) -> Vector2:
	var r := Bedroom.rect_world(Bedroom.WALKABLE).grow(-margin * 0.5)
	p = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	for o in room.blockers():
		var g := Bedroom.rect_world(o).grow(margin * 0.6)
		if g.has_point(p):
			# Empuja hacia el borde más cercano / Push out through the nearest edge
			var d_left := p.x - g.position.x
			var d_right := g.end.x - p.x
			var d_bottom := g.end.y - p.y
			var m := minf(d_left, minf(d_right, d_bottom))
			if m == d_bottom:
				p.y = g.end.y
			elif m == d_left:
				p.x = g.position.x
			else:
				p.x = g.end.x
	return p


func shake(amount: float) -> void:
	if amount >= 10.0:
		Settings.rumble(0.3, 0.6 * minf(1.0, amount / 18.0), 0.25)
	_shake = maxf(_shake, amount)


# --- Eventos / Events -------------------------------------------------------

func on_enemy_killed(e: Node) -> void:
	_kills += 1
	GameState.run_kills += 1
	Progress.kill(e.get("bestiary_id"))
	var elite: bool = e.get("elite")
	Progress.add_stat("kills")
	if elite:
		Progress.kill("elite")
		Progress.add_stat("elites")
	if e.get("bestiary_id") == "golden_foox":
		Progress.add_stat("golden")
	drop_shards(e.global_position, roundi(int(e.get("shards")) * GameState.shard_mult()))
	# Los objetos solo salen de los enemigos y es raro; la suerte los hace más probables
	# Items only drop from enemies and rarely; luck makes them likelier
	if randf() < item_drop_chance(elite):
		spawn_pickup(clamp_to_arena(e.global_position + Vector2(randf_range(-30, 30), 10), 20.0))
	# Élite que se divide: salen dos Foox / Splitting elite: two Foox come out
	if elite and e.get("elite_power") == "split" and running:
		for k in 2:
			_spawn_enemy("foox", clamp_to_arena(e.global_position + Vector2(-30 + k * 60, 0), 22.0))


## Probabilidad de soltar un objeto: 2,5 % (35 % los élites), +2 % relativo por punto de suerte
## Chance to drop an item: 2.5% (35% for elites), +2% relative per luck point
func item_drop_chance(elite: bool) -> float:
	var luck_k := maxf(0.2, 1.0 + GameState.stat("luck") / 50.0)
	return clampf((0.35 if elite else 0.025) * luck_k, 0.0, 0.9)


func spawn_pickup(pos: Vector2, kind := "") -> void:
	var p := Pickup.new()
	p.run = self
	p.kind = kind if kind != "" else Pickup.KINDS[randi() % Pickup.KINDS.size()]
	p.position = pos
	world.add_child(p)


func spawn_puddle(pos: Vector2) -> void:
	var p := Puddle.new()
	p.run = self
	p.position = pos
	world.add_child(p)


## Destello azul al congelar con el despertador / Blue flash when the clock freezes everything
func freeze_flash() -> void:
	Audio.play("glitch", -6.0)
	for e: Node in enemies.get_children():
		if e is Enemy and e.is_targetable():
			fx.ring(e.aim_point(), 20.0, Color("8fe0ff"), 0.6, 2.0)


# --- Eventos del sueño / Dream events ----------------------------------------------

## Algunos sueños traen un evento al azar / Some dreams bring a random event
func _roll_event(depth: int) -> void:
	event = ""
	if _wave.get("boss", false) or depth < 2 or randf() > 0.4:
		return
	event = ["dark", "tilt", "golden"][randi() % 3]
	match event:
		"dark":
			var d := Darkness.new()
			d.run = self
			world.add_child(d)
		"golden":
			_golden_t = randf_range(6.0, 14.0)


func _update_event(delta: float) -> void:
	match event:
		"tilt":
			# El suelo se inclina despacio hacia un lado y luego hacia otro
			# The floor slowly tips one way, then another
			_tilt_t += delta
			var dir := Vector2.from_angle(_tilt_t * 0.35 + sin(_tilt_t * 0.21) * 2.0)
			_tilt = _tilt.lerp(dir * 75.0, minf(1.0, delta * 0.8))
			player.push = _tilt
			for e: Node in enemies.get_children():
				if e is Enemy and not e is BossPiece:
					e.external_pull += _tilt * 0.8
			_camera.rotation = lerpf(_camera.rotation, _tilt.x / 75.0 * 0.025, minf(1.0, delta * 2.0))
		"golden":
			if _golden_t > 0.0:
				_golden_t -= delta
				if _golden_t <= 0.0:
					var g := GoldenFoox.new()
					g.setup(self)
					g.position = _spawn_point()
					enemies.add_child(g)
					Audio.play("chime", -2.0)
					fx.ring(g.position + Vector2(0, -20), 30.0, UITheme.GOLD, 0.8, 2.6)


# --- Trozos de estrella y niveles / Star shards and levels ---------------------

func drop_shards(pos: Vector2, n: int) -> void:
	for i in n:
		var s := StarShard.new()
		s.run = self
		s.position = clamp_to_arena(pos + Vector2(randf_range(-8, 8), randf_range(-6, 6)), 10.0)
		s.add_to_group("shards")
		world.add_child(s)


func collect_shards(n: int) -> void:
	var ups := GameState.add_xp(n)
	hud.set_xp()
	Audio.play("pickup", -17.0, 0.2)
	if ups > 0:
		GameState.pending_ups += ups
		fx.ring(player.global_position + Vector2(0, -60), 40.0, UITheme.GOLD, 0.7, 2.6)
		fx.dissipate(player.global_position + Vector2(0, -60), UITheme.GOLD)
		if running and _level_screen == null:
			_resolve_level_ups(Callable())


## Muestra las subidas de nivel pendientes una a una y luego sigue con "then"
## Shows pending level-ups one by one, then carries on with "then"
func _resolve_level_ups(then: Callable) -> void:
	if GameState.pending_ups <= 0 or not player.alive:
		if then.is_valid():
			then.call()
		return
	get_tree().paused = true
	_level_screen = LevelUpScreen.new()
	add_child(_level_screen)
	_level_screen.build(GameState.roll_level_choices(), GameState.plevel - GameState.pending_ups + 1)
	_level_screen.chosen.connect(func(choice: Dictionary) -> void:
		GameState.apply_stat(choice)
		GameState.pending_ups -= 1
		player.refresh_stats()
		hud.set_hp(player.hp, player.max_hp)
		_level_screen = null
		if GameState.pending_ups > 0:
			_resolve_level_ups.call_deferred(then)
		else:
			get_tree().paused = false
			if then.is_valid():
				then.call())


func on_player_hit(_dmg: float) -> void:
	GameState.run_hits += 1
	Audio.play("hurt", -2.0, 0.08)
	hud.set_hp(player.hp, player.max_hp)
	shake(10.0)


func on_player_died() -> void:
	running = false
	GameState.saved_hp = -1.0
	Progress.save_progress()
	Audio.stop_loops()
	Audio.fade_music(-24.0, 1.0)
	Audio.play("lose", -2.0)
	shake(18.0)
	fx.dissipate(player.position + Vector2(0, -40), UITheme.BONE)
	get_tree().create_timer(0.9, false).timeout.connect(_wake_scene.bind(false))


## Kroker se despierta en su cama de verdad: sobresaltado al morir o tranquilo al ganar.
## Kroker wakes up in his real bed: startled when he dies, peaceful when he wins.
func _wake_scene(won: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color("f7f2ff")
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_build_real_room.bind(won))
	tw.tween_property(flash, "modulate:a", 0.0, 0.8)
	if won:
		tw.tween_interval(2.6)
		tw.tween_callback(_show_victory)
	else:
		tw.tween_callback(_startle)
		tw.tween_interval(2.2)
		tw.tween_callback(_show_end.bind("LOSE_TITLE", "", [["BTN_DREAM_AGAIN", _restart], ["BTN_MAIN_MENU", _to_menu]]))


## La habitación de verdad, sin nada raro / The real bedroom, with nothing strange
func _build_real_room(won: bool) -> void:
	for n: Node in world.get_children():
		if n is Darkness or n is Pickup or n is Puddle or n is StarShard or n is EnemyShot or n is PillowProjectile:
			n.queue_free()
	for e: Node in enemies.get_children():
		e.queue_free()
	fx.clear()
	hud.visible = false
	player.visible = false
	player.push = Vector2.ZERO
	var idx := room.get_index()
	room.queue_free()
	room = Bedroom.new()
	room.outfit = GameState.selected_character
	room.weird = 0
	room.bed_state = "sleeping" if won else "sitting"
	room.sit = 0.0
	room.glasses_on_stand = true
	world.add_child(room)
	world.move_child(room, idx)
	_camera.rotation = 0.0
	_camera.position = Bedroom.to_world(Vector2(800, 460))
	_camera.zoom = Vector2.ONE * 0.64
	Audio.play_music("music_menu", 1.5)


## Se incorpora de golpe / He sits bolt upright
func _startle() -> void:
	Audio.play("blanket", -2.0)
	shake(8.0)
	var tw := create_tween()
	tw.tween_property(room, "sit", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		var head := Bedroom.to_world(room.sitting_feet()) + Vector2(0, -115)
		fx.text(head, "!", UITheme.EMBER, 40)
		Audio.play("hurt", -6.0))


func _show_victory() -> void:
	var m := int(GameState.run_time) / 60
	var sec := int(GameState.run_time) % 60
	var lines := [
		tr("SUM_TIME") % ("%d:%02d" % [m, sec]),
		tr("SUM_KILLS") % GameState.run_kills,
		tr("SUM_DIFFICULTY") % tr("DIFF_" + GameState.difficulty.to_upper()),
	]
	_show_end("ACT1_CLEAR_TITLE", "ACT1_CLEAR_SUB", [["BTN_DREAM_AGAIN", _restart], ["BTN_MAIN_MENU", _to_menu]], lines)
	_overlay.add_side(PauseSummary.make(player))


func _on_wave_cleared() -> void:
	Progress.add_stat("dreams")
	running = false
	GameState.saved_hp = player.hp
	Progress.save_progress()
	Audio.stop_loops()
	Audio.fade_music(-20.0, 1.0)
	Audio.play("win", -2.0)
	hud.set_time(0.0)
	for e: Node in enemies.get_children():
		e.die(false)
	# Los trozos que quedan vuelan hacia Kroker / Leftover shards fly to Kroker
	for s in get_tree().get_nodes_in_group("shards"):
		s.set("_magnet", true)
	get_tree().create_timer(1.5, false).timeout.connect(_resolve_level_ups.bind(_flash_to_astral))


## Un destello leve y Kroker pasa al plano astral / A soft flash takes Kroker to the astral plane
func _flash_to_astral() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color("f7f2ff")
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(Audio.play.bind("astral", -2.0))
	tw.tween_property(flash, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(GameState.change_scene.bind("res://scenes/astral_plane.tscn"))


## El jefe ha caído: fin del Acto 1 / The boss has fallen: end of Act 1
func _on_act_cleared() -> void:
	running = false
	Audio.stop_loops()
	Audio.fade_music(-30.0, 1.5)
	Audio.play("act_clear", -1.0)
	for e: Node in enemies.get_children():
		if not e is BossPiece:
			e.die(false)
	Progress.clear_act(GameState.selected_character, GameState.difficulty)
	# Sin un rasguño (no vale con la invulnerabilidad del modo Dios) / Not a scratch (god mode invulnerability doesn't count)
	if GameState.run_hits == 0 and not (GameState.god_mode and GameState.god_invuln):
		Progress.flag("no_hit")
	GameState.dream_depth = 1
	get_tree().create_timer(1.6, false).timeout.connect(_wake_scene.bind(true))


# --- Pantallas / Screens ----------------------------------------------------

func _show_end(title: String, subtitle: String, buttons: Array, lines: Array = []) -> void:
	get_tree().paused = true
	_overlay = DreamOverlay.new()
	add_child(_overlay)
	_overlay.build(title, subtitle, buttons, lines)


func _open_pause() -> void:
	get_tree().paused = true
	Audio.stop_loops()
	Audio.fade_music(-16.0, 0.4)
	_overlay = DreamOverlay.new()
	add_child(_overlay)
	_overlay.on_cancel = _resume
	_overlay.build("PAUSE_TITLE", "", [
		["PAUSE_RESUME", _resume],
		["MENU_SETTINGS", _open_settings],
		["PAUSE_QUIT_RUN", _to_menu],
	])
	_overlay.add_side(PauseSummary.make(player))


func _resume() -> void:
	if _overlay:
		_overlay.close()
		_overlay = null
	get_tree().paused = false
	Audio.fade_music(-6.0, 0.4)


func _open_settings() -> void:
	var menu := SETTINGS_SCENE.instantiate()
	_overlay.add_child(menu)
	menu.closed.connect(_overlay.refocus)


func _restart() -> void:
	GameState.start_run()
	GameState.change_scene("res://scenes/run.tscn")


func _to_menu() -> void:
	GameState.change_scene(MAIN_MENU)


func _exit_tree() -> void:
	Audio.stop_loops()
