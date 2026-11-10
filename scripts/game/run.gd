class_name Run
extends Node2D
## Una partida: el escenario, la oleada actual, Kroker, los enemigos y las pantallas
## de pausa, victoria y derrota. El Sueño 1 ocurre en la habitación de Kroker y
## empieza con él levantándose de la cama.
## One run: the stage, the current wave, Kroker, the enemies and the pause, win and
## lose screens. Dream 1 takes place in Kroker's bedroom and starts with him
## getting out of bed.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const HUB := "res://scenes/astral_hub.tscn"
const SETTINGS_SCENE := preload("res://scenes/settings_menu.tscn")

## Se emite al acabar cada sueño (lo usa el bot de equilibrio) / Emitted when each dream ends (used by the balance bot)
signal dream_finished

var running := false
var player: Player
var enemies: Node2D
var fx: FX
var hud: HUD
var helpers: Helpers
var trinkets: Trinkets
var _bosses := RunBosses.new(self)
var _events := RunEvents.new(self)
var _cinematics := RunCinematics.new(self)
var room: Bedroom
## Mundo de la partida, dibujado a 960 x 540 y ampliado x2 sin suavizar (pixel art).
## The run's world, drawn at 960 x 540 and scaled up x2 without smoothing (pixel art).
var world: Node2D
const PIXEL_SHRINK := 2
const BEDROOM_ZOOM := 1.22
const BEDROOM_CAM_Y := 44.0

var _wave: Dictionary
var _time_left := 0.0
var _spawn_timer := 1.2
var _kills := 0
var _camera: Camera2D
var _shake := 0.0
var _overlay: DreamOverlay
var _spawned_new := 0
var boss: Enemy
var bosses: Array[Enemy] = []
var _boss_total := 0.0
var _boss_step := 0
var _level_screen: LevelUpScreen
## Evento de este sueño: "" o uno de EVENTS (el timbre del colegio va aparte) / This dream's event: "" or one of EVENTS (the school bell is separate)
var event := ""
var _tilt := Vector2.ZERO
var _tilt_t := 0.0
## Foox dorado: ya no es un evento, es un enemigo muy raro (como mucho uno por sueño)
## Golden Foox: no longer an event, just a very rare enemy (at most one per dream)
const GOLDEN_CHANCE := 0.005
var _golden_done := false
## Timbre del colegio (Acto 3): espera hasta que suena y luego sale gente de las puertas un rato
## School bell (Act 3): waits until it rings, then people pour out of the doors for a while
const BELL_TIME := 10.0
const BELL_FIRST := Vector2(6.0, 12.0)    # primer timbre (s) / first bell (s)
const BELL_AGAIN := Vector2(14.0, 22.0)   # entre recreos (s) / between breaks (s)
const BELL_EVERY := 0.45
const BELL_MAX_ALIVE := 30
var _bell_wait := -1.0
var _bell_t := 0.0
var _bell_cd := 0.0
var _actors: Node2D
## Pantalla que tapa la partida (diálogo, kiosco, chimenea): mientras está, no se pausa
## Screen covering the run (dialogue, kiosk, fireplace): while it's up, pausing is disabled
var _modal: Node
## Tras cancelar en la chimenea hay que apartarse para volver a cargarla
## After cancelling at the fireplace you have to step away before charging it again


func _ready() -> void:
	var depth := GameState.dream_depth
	_wave = GameState.wave_for(depth)
	# Fiebre: más enemigos a la vez y más seguidos / Fever: more enemies at once and more often
	if GameState.pact("crowd") and _wave.has("max_alive"):
		_wave = _wave.duplicate()
		_wave["max_alive"] = ceili(float(_wave["max_alive"]) * 1.3)
		_wave["spawn_every"] = float(_wave["spawn_every"]) / 1.3
	var act := GameState.act_of(depth)
	# Entrenamiento del plano astral: sin oleadas, solo el muñeco / Astral-plane training: no waves, just the dummy
	if GameState.training:
		_wave = {"duration": 0.0, "spawn_every": 99999.0}
		_spawn_timer = INF
		act = 0
		Audio.play_music("music_astral", 1.5)
	else:
		# Se guarda al empezar cada sueño (para "Continuar") / Saved at the start of every dream (for "Continue")
		GameState.save_run()
		Audio.play_music(["", "music_dream1", "music_living", "music_school", "music_city"][act], 2.5)
	# Llegar al salón por primera vez desbloquea a Mr. Ad / Reaching the living room for the first time unlocks Mr. Ad
	# El Acto 2 también desbloquea la pistola de dedos; el Acto 3, el oso de peluche y El Pinche
	# Act 2 also unlocks the finger gun; Act 3, the teddy bear and the Kitchen Boy
	if act >= 2:
		Progress.flag("mr_ad")
		Progress.flag("finger")
	if act >= 3:
		Progress.flag("two_weapons")
		Progress.flag("teddy")
		Progress.flag("pinche")
	# D. Lynx recorta el sueño (en los jefes no, que se acaban al vencerlos) / D. Lynx trims the dream (not on bosses, which end when beaten)
	_time_left = float(_wave.get("duration", 0.0))
	if not _wave.get("boss", false):
		_time_left *= 1.0 - GameState.lynx_cut()
	if depth >= GameState.FINAL_DREAM and not GameState.training:
		Progress.flag("lynx")

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
	# Último sueño: todo en blanco y negro salvo el rojo, con grano y viñeta (noir)
	# Last dream: everything black and white except red, with grain and vignette (noir)
	if act >= 4 and not GameState.training and GameState.city_style(depth) == "noir":
		var nm := ShaderMaterial.new()
		nm.shader = NOIR_SHADER
		holder.material = nm
		_noir_mat = nm
		_noir_holder = holder
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

	if GameState.training:
		room = TrainingRoom.new()
	elif act >= 4:
		# Acto 4: la Metrópolis, con la estética de este sueño / Act 4: the Metropolis, with this dream's look
		var city := Act4Room.new()
		city.style = GameState.city_style(depth)
		city.weird = depth - GameState.ACT4_START + 1
		city.final = bool(_wave.get("final", false))
		room = city
	elif act >= 3:
		room = Act3Room.new()
		room.weird = depth - GameState.ACT3_START + 1
		if not boss_wave():
			(room as Act3Room).roll_locker()
	elif act >= 2:
		# Acto 2: el salón, más raro desde el primer sueño / Act 2: the living room, stranger from the first dream
		var lr := LivingRoom.new()
		lr.weird = depth - GameState.ACT2_START + 1
		lr.fire_lit = bool(_wave.get("fire", false))
		room = lr
	else:
		room = Bedroom.new()
		room.weird = depth - 1
	room.outfit = GameState.selected_character
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
	if room.get_script() == Bedroom or room is LivingRoom:
		# Actos 1 y 2: la habitación y el salón caben enteros con un poco de zoom, así ocupan más pantalla
		# Acts 1 and 2: the bedroom and the living room still fit whole with a bit of zoom, so they fill more of the screen
		_camera.zoom *= BEDROOM_ZOOM
		_camera.position.y += BEDROOM_CAM_Y
	_camera.ignore_rotation = false  # para que la cámara se ladee en el suelo inclinado / so the camera leans on the tilted floor
	world.add_child(_camera)
	_camera.make_current()

	# Actores ordenados por altura / Actors sorted by height
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	_actors = actors
	enemies = Node2D.new()
	enemies.y_sort_enabled = true
	actors.add_child(enemies)
	# Los muebles del medio del salón se ordenan con los personajes / Mid-room furniture sorts with the characters
	# Edificios, árboles y farolas de la ciudad / The city's buildings, trees and lamps
	if room is Act4Room:
		for prop: Node2D in (room as Act4Room).make_props(self):
			actors.add_child(prop)
		_build_towers()
	if room is LivingRoom:
		for sprite: String in LivingRoom.PROPS:
			var prop := LivingRoom.Prop.new()
			prop.sprite = sprite
			prop.base = LivingRoom.PROPS[sprite]
			actors.add_child(prop)
	player = Player.new()
	player.position = Bedroom.to_world(Bedroom.WAKE_POINT)
	player.visible = false
	actors.add_child(player)
	player.setup(self, GameState.selected_character)

	fx = FX.new()
	world.add_child(fx)
	# Cachivaches del kiosco de Charo / Charo's kiosk knick-knacks
	trinkets = Trinkets.new()
	trinkets.setup(self)
	world.add_child(trinkets)
	# SuperK y Lil Key, si te han dado algún don / SuperK and Lil Key, if they've given you a gift
	helpers = Helpers.new()
	add_child(helpers)
	helpers.setup(self)
	if not GameState.training:
		GameState.check_combos.call_deferred()

	hud = HUD.new()
	add_child(hud)
	hud.status.player = player
	hud.visible = false
	hud.set_hp(player.hp, player.max_hp)
	hud.set_time(_time_left)
	if "shield" in GameState.weapons() and GameState.level("svinho", "shield") > 0:
		hud.set_special_mode(false)
	if GameState.training:
		_begin_training()
		return
	GameState.seed_dream(depth)
	_events.roll_event(depth)
	if depth == 1:
		_cinematics.play_wake_up(depth)
	elif depth == GameState.FINAL_DREAM:
		event = ""
		player.fedora = true
		_cinematics.noir_intro(depth)
	else:
		_cinematics.drop_in(depth)


## Entrenamiento: Kroker aparece en un resplandor junto al muñeco de pruebas
## Training: Kroker appears in a glow next to the practice dummy
func _begin_training() -> void:
	var start := Bedroom.to_world(TrainingRoom.START_AT)
	player.position = start
	player.visible = true
	var tw := _cinematics.arrive_glow(start)
	tw.tween_callback(func() -> void:
		hud.visible = true
		hud.start_training()
		running = true
		var d := TrainingDummy.new()
		d.setup(self)
		d.position = Bedroom.to_world(TrainingRoom.DUMMY_AT)
		enemies.add_child(d))


## Empieza el sueño de verdad / The dream really starts
func _begin(depth: int) -> void:
	hud.visible = true
	Progress.tip("move")
	hud.start(depth)
	hud.show_event(event)
	hud.set_reality()
	running = true
	trinkets.on_dream_start()
	if room is LivingRoom and (room as LivingRoom).fire_lit:
		hud.show_fire(true)
		Audio.set_loop("fire", true, -16.0)
	_resolve_level_ups(Callable())
	if _wave.get("boss", false):
		_bosses.spawn_boss()
	elif HoleTutorial.wanted(self):
		HoleTutorial.start(self)


# --- Kioskera Charo / Kiosk lady Charo -------------------------------------------------

func _spawn_charo(kiosk: bool) -> CharoNpc:
	var charo := CharoNpc.new()
	charo.run = self
	charo.with_kiosk = kiosk
	charo.position = Bedroom.to_world(LivingRoom.KIOSK_POINT if kiosk else LivingRoom.CHARO_POINT)
	if room.follows_camera():
		# En el pasillo pone el kiosco cerca de Kroker / In the hallway she sets up near Kroker
		charo.position.x = player.position.x + (-300.0 if player.position.x > _camera.position.x - 200.0 else 300.0)
	_actors.add_child(charo)
	player.set_facing(signf(charo.position.x - player.position.x))
	return charo


## Bienvenida al Acto 2: quién es, dónde está Kroker y qué es la Realidad Fragmentada
## Welcome to Act 2: who she is, where Kroker is and what Fragmented Reality is
func _charo_welcome(then: Callable) -> void:
	var charo := _spawn_charo(false)
	get_tree().create_timer(0.9, false).timeout.connect(func() -> void:
		Audio.leitmotif("charo")
		var lines: Array[String] = []
		for i in 8:
			lines.append("CHARO_WELCOME_%d" % (i + 1))
		_modal = _dialogue(lines, charo)
		_modal.finished.connect(func() -> void:
			_modal = null
			Progress.stats["charo_met"] = 1
			Progress.save_progress()
			charo.leave()
			get_tree().create_timer(0.7, false).timeout.connect(then)))


func _dialogue(lines: Array[String], charo: CharoNpc) -> CharoDialogue:
	var d := CharoDialogue.new()
	add_child(d)
	d.build(lines)
	charo.talk(99.0)
	d.finished.connect(func() -> void: charo.talk(0.0))
	return d


## Al acabar algunos sueños, Charo abre su kiosco / At the end of some dreams Charo opens her kiosk
func _charo_shop(then: Callable) -> void:
	var charo := _spawn_charo(true)
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		charo.talk(1.0)
		var shop := CharoShop.new()
		_modal = shop
		add_child(shop)
		shop.build()
		shop.bought.connect(_on_ware)
		shop.closed.connect(func() -> void:
			_modal = null
			GameState.saved_hp = player.hp
			charo.leave()
			get_tree().create_timer(0.7, false).timeout.connect(_resolve_level_ups.bind(then))))


func _on_ware(id: String) -> void:
	Progress.add_stat("bought")
	var before := player.max_hp
	player.refresh_stats()
	if player.max_hp > before:
		player.hp += player.max_hp - before
	if GameState.ware_heal(id) > 0.0:
		player.heal(player.max_hp * GameState.ware_heal(id))
	hud.set_hp(player.hp, player.max_hp)
	hud.set_reality()
	hud.set_xp()


## ¿Es un sueño con jefe? / Is this a boss dream?
func boss_wave() -> bool:
	return bool(_wave.get("boss", false))


## Gana Realidad Fragmentada (solo desde el Acto 2) / Gains Fragmented Reality (only from Act 2)
func gain_reality(n: int, pos: Vector2) -> void:
	if not GameState.reality_on() or n <= 0:
		return
	# Mr. Ad: a veces cae 1 más / Mr. Ad: sometimes 1 more drops in
	if randf() * 100.0 < GameState.ad_extra_chance():
		n += 1
	# Fiebre: a veces 1 más / Fever: sometimes 1 more
	if randf() < 0.05 * GameState.fever():
		n += 1
	GameState.add_reality(n)
	Progress.best_stat("best_reality", GameState.reality)
	hud.set_reality()
	# Las mejoras de Mr. Ad dependen de lo ahorrado / Mr. Ad's upgrades depend on the savings
	player.refresh_stats()
	hud.set_hp(player.hp, player.max_hp)
	Audio.play("reality", -5.0, 0.06)
	fx.text(pos + Vector2(0, -30), "+%d" % n, RealityIcon.COLOR, 24)
	fx.ring(pos, 18.0, RealityIcon.COLOR, 0.5, 2.0)


# --- Chimenea del salón / Living-room fireplace ----------------------------------------

## La Metrópolis: de vez en cuando se derrumba un edificio cerca de Kroker
## The Metropolis: now and then a building collapses near Kroker
const NOIR_SHADER := preload("res://assets/shaders/noir.gdshader")
var _fall_t := 8.0
var _towers: Array[CityFall] = []


## Los rascacielos que se caerán, en pie desde el principio / The skyscrapers that will fall, standing from the start
func _build_towers() -> void:
	var city := room as Act4Room
	_towers.clear()
	for site: Array in city.tower_sites(16 if city.final else 10):
		var f := CityFall.new()
		f.run = self
		f.setup(self, site[0], site[1])
		city.tower_bases.append(f.base_rect)
		_towers.append(f)
		_actors.add_child(f)


func _update_hearth(_delta: float) -> void:
	if not room is LivingRoom:
		return
	var lr := room as LivingRoom
	if not lr.can_sacrifice():
		return
	# Delante del fuego, con la F (o A) se abre el sacrificio / In front of the fire, F (or A) opens the sacrifice
	var inside := Bedroom.rect_world(LivingRoom.HEARTH_ZONE).has_point(player.position)
	lr.fire_near = inside and _modal == null
	if lr.fire_near and Input.is_action_just_pressed("interact"):
		_open_sacrifice()


func _open_sacrifice() -> void:
	var lr := room as LivingRoom
	lr.fire_near = false
	get_tree().paused = true
	var sc := SacrificeScreen.new()
	_modal = sc
	add_child(sc)
	sc.build()
	sc.chosen.connect(func(giver: String, weapon: String) -> void:
		_modal = null
		get_tree().paused = false
		GameState.sacrifice(giver, weapon)
		Progress.add_stat("sacrifices")
		player.refresh_stats()
		hud.set_hp(player.hp, player.max_hp)
		if weapon == "shield" and giver == "svinho" and GameState.level("svinho", "shield") <= 0:
			hud.set_special_mode(false)
		lr.flare()
		hud.show_fire(false)
		Audio.play("sacrifice", -2.0)
		Audio.set_loop("fire", false)
		shake(6.0)
		var at := Bedroom.to_world(LivingRoom.FIREBOX.get_center())
		fx.dissipate(at, Color("b98aff"))
		fx.ring(at, 40.0, Color("b98aff"), 0.8, 3.0)
		gain_reality(GameState.sacrifice_value(giver, weapon, true), at))
	sc.cancelled.connect(func() -> void:
		_modal = null
		get_tree().paused = false)


## Cinemática del último sueño: Kroker apoyado en una pared piensa en su viaje como un detective
## de cine negro; luego estallan los edificios y llega Evil Ad
## The last dream's cutscene: Kroker, leaning on a wall, muses on his journey like a film-noir
## detective; then the buildings blow up and Evil Ad arrives
var cam_focus := Vector2.INF
var _cam_free := false   # la cámara se sale de los límites del mapa (cinemática) / the camera ignores the map limits (cutscene)
var _noir_mat: ShaderMaterial = null
var _noir_holder: Control = null


## La imagen se descuadra un momento (Evil Ad en delirio) / The picture glitches for a moment (Evil Ad delirious)
func noir_glitch(secs := 0.3, power := 1.0) -> void:
	if _noir_mat == null:
		return
	_noir_mat.set_shader_parameter("glitch", power * Settings.flash_mult())
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(_noir_mat.set_shader_parameter.bind("glitch", 0.0))


## Jefe final: Evil Ad (ya ha llegado en la cinemática) / Final boss: Evil Ad (he already arrived in the cutscene)
var _evil: EvilAd = null


## Un fogonazo de color en toda la pantalla / A flash of colour over the whole screen
func flash_screen(color: Color, secs := 0.3) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.modulate.a = 0.55 * Settings.flash_mult()
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, secs)
	tw.tween_callback(layer.queue_free)


## Pantalla para elegir la segunda arma (la del otro tipo) / Screen to pick the second weapon (the other kind)
func _choose_second_weapon(then: Callable) -> void:
	if GameState.second_weapon != "" or GameState.pact("solo"):
		then.call()
		return
	get_tree().paused = true
	var sc := WeaponChoiceScreen.new()
	_modal = sc
	add_child(sc)
	sc.build()
	sc.chosen.connect(func(id: String) -> void:
		_modal = null
		get_tree().paused = false
		GameState.second_weapon = id
		GameState.gift_ball()
		then.call())


## Barra del jefe: la vida que les queda a los muebles despiertos / Boss bar: health left on the awake pieces
func update_boss_hp() -> void:
	var hp := 0.0
	for b in bosses:
		if is_instance_valid(b) and float(b.get("_dying")) < 0.0:
			hp += maxf(b.hp, 0.0)
	hud.set_boss_hp(hp, maxf(_boss_total, 1.0))


## Salto en arco desde la cama al suelo / Arcing hop from the bed to the floor
func _hop_down(k: float, from: Vector2, to: Vector2) -> void:
	player.position = from.lerp(to, k)
	player.hop = sin(k * PI) * 34.0


func _walk_time(a: Vector2, b: Vector2) -> float:
	return maxf(0.3, a.distance_to(b) / 280.0)


func _physics_process(delta: float) -> void:
	_follow_camera(delta)
	_shake = maxf(0.0, _shake - delta * 30.0)
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * Settings.shake_amount
	if not running:
		player.push = Vector2.ZERO
		return
	GameState.run_time += delta
	_fall_chain_t = maxf(0.0, _fall_chain_t - delta)
	_burst_budget = minf(4.0, _burst_budget + delta * 3.0)
	hud.set_run_clock(GameState.run_time)
	_events.update_event(delta)
	# El objetivo de Magnus, cuatro veces por segundo / Magnus's goal, four times a second
	if not GameState.invest.is_empty() and int(GameState.run_time * 4.0) != int((GameState.run_time - delta) * 4.0):
		hud.set_invest()
	_update_hearth(delta)
	_events.update_locker()
	_events.update_city(delta)
	if float(_wave.get("duration", 0.0)) > 0.0:
		_time_left -= delta
		hud.set_time(_time_left)
		if _time_left <= 0.0:
			if _wave.get("boss", false):
				_bosses.boss_time_up()
			else:
				_on_wave_cleared()
			return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = float(_wave["spawn_every"]) * (FRENZY_SPAWN if event == "frenzy" else (SLEEPY_SPAWN if event == "sleepy" else 1.0))
		_spawn_group()
	if room.follows_camera():
		_recycle_far_enemies()


## Pasillo infinito: la cámara sigue a Kroker de lado a lado / Endless hallway: the camera follows Kroker sideways
func _follow_camera(delta: float) -> void:
	if not room.follows_camera() or not is_instance_valid(player):
		return
	var focus := player.position if cam_focus == Vector2.INF else cam_focus
	_camera.position.x = lerpf(_camera.position.x, focus.x, minf(1.0, delta * 6.0))
	if room.open_map():
		_camera.position.y = lerpf(_camera.position.y, focus.y - 40.0, minf(1.0, delta * (6.0 if cam_focus == Vector2.INF else 2.0)))
		if not _cam_free:
			_camera.position = _camera_clamped(_camera.position)


## En la ciudad la cámara no se sale del mapa / In the city the camera doesn't leave the map
func _camera_clamped(p: Vector2) -> Vector2:
	var m: Rect2 = room.map_world_rect()
	var half := Vector2(960, 540)
	return Vector2(clampf(p.x, m.position.x + half.x, m.end.x - half.x), clampf(p.y, m.position.y + half.y, m.end.y - half.y + 60.0))


## Los enemigos que se quedan muy atrás vuelven a aparecer por delante (como en Vampire Survivors)
## Enemies left far behind reappear ahead (like in Vampire Survivors)
func _recycle_far_enemies() -> void:
	for e: Node in enemies.get_children():
		if not e is Enemy or e.is_boss() or e is GoldenFoox or not e.is_targetable():
			continue
		if room.open_map():
			# En la ciudad: los que se quedan lejos vuelven por fuera de la pantalla, cerca / In the city: those left far away come back just off screen
			if e.position.distance_to(player.position) > 1600.0:
				for attempt in 8:
					var q: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * randf_range(1100.0, 1300.0)
					q = clamp_to_arena(q, 40.0)
					if not _blocked(q, 40.0) and q.distance_to(player.position) > 900.0:
						e.position = q
						break
			continue
		var dx: float = e.position.x - player.position.x
		if absf(dx) > 1700.0:
			var ahead := signf(player.velocity_hint().x) if absf(player.velocity_hint().x) > 10.0 else -signf(dx)
			var p := Vector2(player.position.x + ahead * randf_range(1050.0, 1250.0), e.position.y)
			if not _blocked(p, 40.0):
				e.position = p

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
	if event.is_action_pressed("pause") and running and _overlay == null and _level_screen == null and _modal == null:
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
				if not e.is_boss():
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
		# Los mosquitos de los nidos no cuentan / Nest mosquitoes don't count
		if not e.is_boss() and not e is Mosquito and not e is BotcherTurret:
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
		if new_kind in ["cyber", "van", "riot"] and _spawned_new > 1:
			pass   # solo sale uno seguro / only one is guaranteed
		elif new_kind != "nest" or _count_alive(Nest) < 3:
			return new_kind
	var mix: Dictionary = _wave["mix"]
	var total := 0.0
	for k: String in mix:
		total += float(mix[k])
	var roll := randf() * total
	for k: String in mix:
		roll -= float(mix[k])
		if roll <= 0.0:
			# Como mucho 3 nidos a la vez / At most 3 nests at a time
			if k == "nest" and _count_alive(Nest) >= 3:
				return "foox"
			# Como mucho 2 Cyberpunks a la vez: muchos son un caos / At most 2 Cyberpunks at once: many is chaos
			if k == "cyber" and _count_alive(Cyberpunk) >= 2:
				return "foox"
			# Como mucho 2 Gólems y 3 Marionetas / At most 2 Golems and 3 Puppets
			if k == "golem" and _count_alive(Golem) >= 2:
				return "thug"
			if k == "puppet" and _count_alive(Puppet) >= 3:
				return "foox"
			# Como mucho 2 Chapuzas, y solo si hay agujeros / At most 2 Botchers, and only if there are holes
			if k == "botcher" and (_count_alive(Botcher) >= 2 or room.hole_count() == 0):
				return "foox"
			# Acto 4: pocas furgos y antidisturbios a la vez / Act 4: few vans and riot officers at once
			var fin := bool(_wave.get("final", false))
			if k == "van" and _count_alive(Van) >= (2 if fin else 1):
				return "police"
			if k == "riot" and _count_alive(Riot) >= (3 if fin else 2):
				return "police"
			if k == "police" and _count_alive(Police) >= 10:
				return "thug"
			return k
	return "foox"


func count_alive(type: Variant) -> int:
	return _count_alive(type)


func _count_alive(type: Variant) -> int:
	var n := 0
	for e: Node in enemies.get_children():
		if is_instance_of(e, type) and e.is_targetable():
			n += 1
	return n


func _spawn_point() -> Vector2:
	var area := arena_rect().grow(-30)
	# En el pasillo infinito salen alrededor de lo que se ve / In the endless hallway they spawn around the view
	if room.open_map():
		area = view_rect().grow(220.0).intersection(area)
	elif room.follows_camera():
		var v := view_rect()
		area = Rect2(Vector2(v.position.x - 200.0, area.position.y), Vector2(v.size.x + 400.0, area.size.y))
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
		"nest": e = Nest.new()
		"mosquito": e = Mosquito.new()
		"cyber": e = Cyberpunk.new()
		"puppet": e = Puppet.new()
		"golem": e = Golem.new()
		"police": e = Police.new()
		"van": e = Van.new()
		"riot": e = Riot.new()
		"botcher": e = Botcher.new()
		_: e = Foox.new()
	# Muy de vez en cuando, en lugar del enemigo sale un Foox dorado (la suerte ayuda un poco)
	# Every so often a golden Foox turns up instead (luck helps a little)
	if not _golden_done and GameState.dream_depth >= 2 and not _wave.get("boss", false) \
			and randf() < GOLDEN_CHANCE * (1.0 + maxf(0.0, GameState.stat("luck")) / 50.0):
		_golden_done = true
		e.free()
		e = GoldenFoox.new()
		Audio.play("chime", -2.0)
		fx.ring(pos + Vector2(0, -20), 30.0, UITheme.GOLD, 0.8, 2.6)
	e.setup(self, 1.0, FRENZY_SPEED if event == "frenzy" else (SLEEPY_SPEED if event == "sleepy" else 1.0))
	e.position = pos
	# Los antidisturbios salen de una alcantarilla abierta / Riot officers climb out of an open manhole
	if e is Riot and room is Act4Room and room.hole_count() > 0:
		var best := Vector2.INF
		var list: Array[Rect2] = room.holes_list()
		for i in room.hole_count():
			var c := Bedroom.rect_world(list[i]).get_center()
			if view_rect().grow(150.0).has_point(c) and c.distance_to(player.position) > 300.0 and (best == Vector2.INF or c.distance_to(pos) < best.distance_to(pos)):
				best = c
		if best != Vector2.INF:
			e.position = best + Vector2(0, 50)
			(e as Riot).rise = 1.0
	# Élites desde el Sueño 2 / Elites from Dream 2
	if GameState.dream_depth >= 2 and not e is GoldenFoox and not e is Van and not e is Riot and randf() < (0.12 if GameState.difficulty == "nightmare" else 0.07):
		e.elite = true
	enemies.add_child(e)


## Rectángulo de la zona de juego en pantalla / Play area rectangle on screen
func arena_rect() -> Rect2:
	return Bedroom.rect_world(room.walkable())


## Lo que se ve de la zona de juego (en el pasillo infinito, solo el tramo de la cámara)
## The visible part of the play area (in the endless hallway, only the camera's stretch)
func view_rect() -> Rect2:
	var half := Vector2(960, 540)
	var cam := Rect2(_camera.position - half, half * 2.0)
	return arena_rect().intersection(cam)


## Si un enemigo empujado cae por un agujero, devuelve hacia dónde cae; si no, Vector2.INF.
## If a shoved enemy falls into a hole, returns where it falls to; otherwise Vector2.INF.
func hole_at(p: Vector2, margin: float, push: Vector2) -> Vector2:
	var holes := room.holes_list()
	for i in room.hole_count():
		var hr := Bedroom.rect_world(holes[i].grow(-10)).grow(margin * 0.6)
		if hr.has_point(p) and not hole_covered(Bedroom.rect_world(holes[i])):
			return Bedroom.rect_world(holes[i]).get_center()
	# Boquetes de la pared: hay que ir hacia arriba contra el fondo
	# Wall holes: it has to be moving up against the back
	var top := arena_rect().position.y + margin * 0.5
	if p.y <= top + 6.0 and push.y < -60.0:
		var wall_holes := room.wall_holes_list()
		for i in room.wall_hole_count():
			var wr := Bedroom.rect_world(wall_holes[i])
			if p.x > wr.position.x + 6.0 and p.x < wr.end.x - 6.0:
				return Vector2(wr.get_center().x, wr.end.y - wr.size.y * 0.3)
	# Agujeros pasajeros del evento «Bostezos» / Short-lived holes from the "Yawns" event
	if is_instance_valid(yawns):
		return yawns.hole_at(p, margin)
	return Vector2.INF


## ¿Tiene este agujero un tablón del Chapuzas encima? / Does this hole have a Botcher's plank on it?
func hole_covered(world_rect: Rect2) -> bool:
	for e: Node in enemies.get_children():
		if e is BotcherTurret and (e as BotcherTurret).covers(world_rect):
			return true
	return false


## Torretas del Chapuzas en pie / Botcher turrets standing
func count_turrets() -> int:
	var n := 0
	for e: Node in enemies.get_children():
		if e is BotcherTurret and (e as Enemy).state != Enemy.State.DYING:
			n += 1
	return n


## ¿Va otro Chapuzas ya a por este agujero? / Is another Botcher already heading for this hole?
func hole_claimed(world_rect: Rect2, by: Node) -> bool:
	for e: Node in enemies.get_children():
		if e != by and e is Botcher and (e as Enemy).state == Enemy.State.ALIVE and (e as Botcher).hole.is_equal_approx(world_rect):
			return true
	return false


func _near_boss(p: Vector2) -> bool:
	for b in bosses:
		if is_instance_valid(b) and p.distance_to(b.aim_point()) < 160.0:
			return true
	return false


func _blocked(p: Vector2, margin: float) -> bool:
	for r in room.blockers_near(p):
		if Bedroom.rect_world(r).grow(margin).has_point(p):
			return true
	return false


## Mantiene a alguien dentro del suelo y fuera de los muebles.
## Keeps someone on the floor and out of the furniture.
func clamp_to_arena(p: Vector2, margin: float) -> Vector2:
	var r := arena_rect().grow(-margin * 0.5)
	p = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	for o in room.blockers_near(p):
		var g := Bedroom.rect_world(o).grow(margin * 0.6)
		if g.has_point(p):
			# Empuja hacia el borde más cercano / Push out through the nearest edge
			var d_left := p.x - g.position.x
			var d_right := g.end.x - p.x
			var d_bottom := g.end.y - p.y
			# Por arriba solo si el mueble está en medio del suelo (el sofá del salón)
			# Out through the top only if the piece stands in the middle of the floor (the living-room sofa)
			var d_top := p.y - g.position.y if g.position.y > r.position.y else INF
			var m := minf(minf(d_left, d_top), minf(d_right, d_bottom))
			if m == d_top:
				p.y = g.position.y
			elif m == d_bottom:
				p.y = g.end.y
			elif m == d_left:
				p.x = g.position.x
			else:
				p.x = g.end.x
	return p


## Micro-pausa: un instante casi parado para que un golpe gordo se note. Como mucho una cada
## 0,4 s para que una ristra de caídas no frene la partida.
## Hit stop: a near-frozen instant so a big hit lands. At most one every 0.4 s so a string of
## falls doesn't slow the game down.
var _stop_at := -1000
func hit_stop(duration := 0.05, slow := 0.15) -> void:
	var now := Time.get_ticks_msec()
	if not is_equal_approx(Engine.time_scale, 1.0) or now - _stop_at < 400 or not running:
		return
	_stop_at = now
	Engine.time_scale = slow
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func shake(amount: float) -> void:
	if amount >= 10.0:
		Settings.rumble(0.3, 0.6 * minf(1.0, amount / 18.0), 0.25)
	_shake = maxf(_shake, amount)


# --- Eventos / Events -------------------------------------------------------

## Combo «Estallido de píxeles» (Silly + Svinho): los glitcheados estallan al morir y glitchean a
## los de alrededor. Como mucho unos cuantos por segundo, para que la cadena no barra la pantalla.
## "Pixel burst" combo (Silly + Svinho): glitched enemies burst when they die and glitch those around.
## At most a few per second, so the chain doesn't sweep the screen.
var _burst_budget := 0.0


func _pixel_burst(e: Enemy) -> void:
	var marked := e.glitch_t > 0.0 or (e.is_stuck() and e.stuck_bonus > 0.0)
	if _burst_budget < 1.0 or not marked or not "pixel_burst" in GameState.combos_seen:
		return
	_burst_budget -= 1.0
	var p := e.aim_point()
	Audio.play("glitch", -6.0, 0.15)
	fx.ring(p, GameState.PIXEL_BURST_RADIUS * 0.5, Color("5ff2ff"), 0.35, 2.4)
	for k in 8:
		fx.dissipate(p + Vector2.from_angle(k * TAU / 8.0) * 40.0, Color("ff5fd2") if k % 2 else Color("5ff2ff"))
	for o: Node in enemies.get_children():
		if o is Enemy and o != e and (o as Enemy).is_targetable() and (o as Enemy).global_position.distance_to(e.global_position) < GameState.PIXEL_BURST_RADIUS:
			(o as Enemy).glitch(0.0, 1.2, 1.5, 1.25)
			(o as Enemy).hit(GameState.PIXEL_BURST_DMG * player.damage_mult, ((o as Enemy).global_position - e.global_position).normalized() * 180.0)


func on_enemy_killed(e: Node) -> void:
	if e is Enemy:
		_pixel_burst(e as Enemy)
	_kills += 1
	GameState.run_kills += 1
	Progress.kill(e.get("bestiary_id"))
	var elite: bool = e.get("elite")
	Progress.add_stat("kills")
	if elite:
		Progress.kill("elite")
		Progress.add_stat("elites")
		GameState.run_elites += 1
		gain_reality(GameState.REALITY_ELITE, e.global_position)
	if e is Enemy:
		trinkets.on_kill(e as Enemy)
	if e.get("bestiary_id") == "golden_foox":
		Progress.add_stat("golden")
	# En las peleas contra jefes, los enemigos de alrededor sueltan un tercio de estrellas (para no
	# subir diez niveles en una pelea larga); los élites, todas
	# In boss fights the surrounding enemies drop a third of the stars (so a long fight doesn't
	# grant ten levels); elites still drop them all
	var shard_k := 0.34 if _wave.get("boss", false) and not elite and not e.is_boss() else 1.0
	var bonus := 1 if event == "frenzy" and not e.is_boss() else 0
	drop_shards(e.global_position, roundi(int(e.get("shards")) * GameState.shard_mult() * shard_k) + bonus)
	# Los objetos solo salen de los enemigos y es raro; la suerte los hace más probables
	# Items only drop from enemies and rarely; luck makes them likelier
	if randf() < item_drop_chance(elite) * float(e.get("drop_mult")):
		spawn_pickup(clamp_to_arena(e.global_position + Vector2(randf_range(-30, 30), 10), 20.0))
	# Élite que se divide: salen dos Foox / Splitting elite: two Foox come out
	if elite and e.get("elite_power") == "split" and running:
		for k in 2:
			_spawn_enemy("foox", clamp_to_arena(e.global_position + Vector2(-30 + k * 60, 0), 22.0))


## Probabilidad de soltar un objeto: 6 % (50 % los élites), +2 % relativo por punto de suerte
## Chance to drop an item: 6% (50% for elites), +2% relative per luck point
func item_drop_chance(elite: bool) -> float:
	var luck_k := maxf(0.2, 1.0 + GameState.stat("luck") / 50.0)
	return clampf((0.5 if elite else 0.06) * luck_k, 0.0, 0.9)


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
## Eventos posibles de un sueño / Possible events in a dream
const EVENTS: Array[String] = ["dark", "tilt", "meteors", "ice", "frenzy", "sleepy", "yawn"]
const EVENT_CHANCE := 0.55
## Fiebre de estrellas y sonámbulos: velocidad de los enemigos y cada cuánto salen
## Star fever and sleepwalkers: enemy speed and how often they spawn
const FRENZY_SPEED := 1.2
const FRENZY_SPAWN := 0.7
const SLEEPY_SPEED := 0.55
const SLEEPY_SPAWN := 0.6


# --- Trozos de estrella y niveles / Star shards and levels ---------------------

## Caídas en cadena: cada enemigo que cae poco después del anterior suma uno a la cadena y suelta
## tantos trozos de estrella extra como la cadena (hasta FALL_CHAIN_MAX). Solo da experiencia.
## Fall chains: every enemy that falls shortly after the previous one adds one to the chain and drops
## as many extra star shards as the chain (up to FALL_CHAIN_MAX). It only gives experience.
var _fall_chain := 0
var _fall_chain_t := 0.0
var yawns: YawnHoles


func on_fall_chain(_e: Enemy, at: Vector2) -> void:
	_fall_chain = _fall_chain + 1 if _fall_chain_t > 0.0 else 1
	_fall_chain_t = GameState.FALL_CHAIN_GAP
	Progress.best_stat("fall_chain", _fall_chain)
	GameState.run_best_chain = maxi(GameState.run_best_chain, _fall_chain)
	if _fall_chain < 2:
		return
	drop_shards(at, mini(_fall_chain, GameState.FALL_CHAIN_MAX))
	fx.text(at + Vector2(0, -120), tr("FALL_CHAIN") % _fall_chain, UITheme.GOLD, 24 + mini(_fall_chain, 6) * 2)
	Audio.play("chime", -8.0 + mini(_fall_chain, 5), 0.0)


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
		trinkets.on_level_up()
		fx.ring(player.global_position + Vector2(0, -60), 40.0, UITheme.GOLD, 0.7, 2.6)
		fx.dissipate(player.global_position + Vector2(0, -60), UITheme.GOLD)
		# Las mejoras se eligen al acabar el sueño, para no cortar la pelea: aquí solo se avisa
		# Upgrades are chosen when the dream ends, so the fight isn't cut: here it's only announced
		fx.text(player.global_position + Vector2(0, -150), tr("LEVELUP_LATER") % GameState.plevel, UITheme.GOLD, 26)
		Audio.play("chime", -10.0)
		hud.set_xp()
		if not running and _level_screen == null:
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
		hud.set_xp()
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
	GameState.clear_saved_run()
	GameState.saved_hp = -1.0
	Progress.save_progress()
	Audio.stop_loops()
	Audio.fade_music(-24.0, 1.0)
	Audio.play("lose", -2.0)
	shake(18.0)
	fx.dissipate(player.position + Vector2(0, -40), UITheme.BONE)
	get_tree().create_timer(0.9, false).timeout.connect(_cinematics.wake_scene.bind(false))


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
	var act := GameState.act()
	var m := int(GameState.run_time) / 60
	var sec := int(GameState.run_time) % 60
	var lines := [
		tr("SUM_TIME") % ("%d:%02d" % [m, sec]),
		tr("SUM_KILLS") % GameState.run_kills,
		tr("SUM_DIFFICULTY") % tr("DIFF_" + GameState.difficulty.to_upper()),
	]
	_show_end("ACT%d_CLEAR_TITLE" % act, "ACT%d_CLEAR_SUB" % act, [["BTN_DREAM_AGAIN", _restart], ["BTN_TO_HUB", _to_menu]], lines)
	_end_records(true)
	_overlay.add_side(DreamDiary.make(true))
	_overlay.add_under(RunResults.make())


## Apunta los récords de la partida (el de nivel y el de caída en cadena ya se apuntan solos)
## Records the run's bests (level and fall chain already record themselves)
func _end_records(won := false) -> void:
	if GameState.god_mode:
		return
	Progress.record_last_run(won)
	Progress.best_stat("best_depth", GameState.dream_depth)
	Progress.best_stat("best_kills", GameState.run_kills)
	Progress.record_daily(GameState.daily, GameState.dream_depth)


## Al perder: la pantalla de fin con el diario del sueño / On losing: the end screen with the dream diary
func _show_loss() -> void:
	_show_end("LOSE_TITLE", "", [["BTN_DREAM_AGAIN", _restart], ["BTN_TO_HUB", _to_menu]])
	_end_records()
	_overlay.add_side(DreamDiary.make(false))
	_overlay.add_under(RunResults.make())


func _on_wave_cleared() -> void:
	dream_finished.emit()
	Progress.add_stat("dreams")
	running = false
	_settle_deal()
	trinkets.on_dream_end()
	GameState.saved_hp = player.hp
	Progress.save_progress()
	Audio.stop_loops()
	Audio.fade_music(-20.0, 1.0)
	Audio.play("win", -2.0)
	hud.set_time(0.0)
	# El último sueño: la ciudad se queda en silencio / The last dream: the city falls silent
	if _wave.get("final", false):
		hud.banner("ACT4_CLEAR_TITLE", "FINAL_SUB")
	for e: Node in enemies.get_children():
		e.die(false)
	# Los trozos que quedan vuelan hacia Kroker / Leftover shards fly to Kroker
	for s in get_tree().get_nodes_in_group("shards"):
		s.set("_magnet", true)
	get_tree().create_timer(1.5, false).timeout.connect(_resolve_level_ups.bind(_after_dream))


## Magnus cierra el trato al acabar el sueño / Magnus closes the deal when the dream ends
## Se apunta cómo acabó el trato; Magnus lo cuenta después del sueño (_magnus_verdict)
## Notes how the deal ended; Magnus tells you after the dream (_magnus_verdict)
var _deal_result := {}


func _settle_deal() -> void:
	if GameState.invest.is_empty():
		return
	var deal := GameState.invest.duplicate(true)
	var progress := GameState.invest_progress()
	var result := GameState.settle_deal()
	_deal_result = {"result": result, "deal": deal, "progress": progress}
	player.refresh_stats()
	hud.set_reality()
	hud.set_invest()


## Magnus aparece a cerrar el trato, lo hayas cumplido o no / Magnus shows up to close the deal, met or not
func _magnus_verdict(then: Callable) -> void:
	if _deal_result.is_empty():
		then.call()
		return
	get_tree().paused = true
	var v := MagnusVerdict.new()
	_modal = v
	add_child(v)
	v.build(_deal_result["result"], _deal_result["deal"], int(_deal_result["progress"]))
	_deal_result = {}
	v.closed.connect(func() -> void:
		_modal = null
		get_tree().paused = false
		hud.set_reality()
		then.call())


## Después de un sueño: a veces el kiosco de Charo; luego el plano astral o el final del acto
## After a dream: sometimes Charo's kiosk; then the astral plane or the end of the act
func _after_dream() -> void:
	# Primero Magnus, si había trato / First Magnus, if there was a deal
	if not _deal_result.is_empty():
		_magnus_verdict(_after_dream)
		return
	var next := _end_run_victory if _wave.get("act_end", false) else _flash_to_astral
	# En el Acto 1 solo si ya conoces a Charo / In Act 1 only if you've already met Charo
	if GameState.pact("no_kiosk"):
		next.call()
	elif _wave.get("shop", false) or (_wave.get("shop_met", false) and Progress.stats.has("charo_met")):
		_charo_shop(next)
	else:
		next.call()


## Final provisional del Acto 2 (su jefe vendrá más adelante) / Provisional end of Act 2 (its boss comes later)
func _end_run_victory() -> void:
	GameState.clear_saved_run()
	Progress.clear_act(GameState.selected_character, GameState.difficulty, GameState.act())
	Audio.fade_music(-30.0, 1.5)
	Audio.play("act_clear", -1.0)
	if GameState.run_hits == 0 and not (GameState.god_mode and GameState.god_invuln):
		Progress.flag("no_hit")
	get_tree().create_timer(1.6, false).timeout.connect(_cinematics.wake_scene.bind(true))


## Un resplandor pequeño sale de Kroker, se lo lleva y pasa al plano astral
## A small glow comes out of Kroker, takes him away and he goes to the astral plane
func _flash_to_astral() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color("f7f2ff") if not Settings.reduce_flashes else Color("3a3570")
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glow := DreamGlow.new()
	glow.position = player.global_position + Vector2(0, -70)
	world.add_child(glow)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(Audio.play.bind("astral", -2.0))
	tw.tween_property(glow, "power", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(player, "modulate", Color(3, 3, 3, 1), 0.6)
	# Kroker se encoge dentro del brillo y desaparece / Kroker shrinks into the glow and vanishes
	tw.tween_property(player, "scale", Vector2(0.3, 0.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(player, "modulate:a", 0.0, 0.3)
	tw.tween_property(glow, "radius", 40.0, 0.25)
	tw.tween_property(flash, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(GameState.change_scene.bind("res://scenes/astral_plane.tscn"))


## El jefe ha caído: fin del Acto 1 / The boss has fallen: end of Act 1
func _on_act_cleared(killed := true) -> void:
	if not running:
		return
	dream_finished.emit()
	running = false
	Audio.stop_loops()
	Audio.fade_music(-30.0, 1.5)
	Audio.play("act_clear", -1.0)
	for e: Node in enemies.get_children():
		if not e.is_boss():
			e.die(false)
	Progress.clear_act(GameState.selected_character, GameState.difficulty)
	Progress.add_stat("dreams")
	# Los tres muebles tumbados en pesadilla (no vale aguantar): llega SuperK
	# All three pieces knocked out on nightmare (holding out doesn't count): SuperK arrives
	if killed and GameState.difficulty == "nightmare" and not GameState.training:
		Progress.flag("superk")
	# Sin un rasguño (no vale con la invulnerabilidad del modo Dios) / Not a scratch (god mode invulnerability doesn't count)
	if GameState.run_hits == 0 and not (GameState.god_mode and GameState.god_invuln):
		Progress.flag("no_hit")
	# El sueño sigue: tras el plano astral, Kroker cae en el salón (Acto 2)
	# The dream goes on: after the astral plane, Kroker falls into the living room (Act 2)
	GameState.saved_hp = player.hp
	Progress.save_progress()
	hud.hide_boss()
	hud.banner("ACT1_CLEAR_TITLE", "BOSS_KILLED_SUB" if killed else "BOSS_SURVIVED_SUB")
	if killed:
		_bosses.boss_bonus()
	for s in get_tree().get_nodes_in_group("shards"):
		s.set("_magnet", true)
	get_tree().create_timer(3.4, false).timeout.connect(_resolve_level_ups.bind(_flash_to_astral))


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
		["PAUSE_LEAVE_TRAINING" if GameState.training else "PAUSE_QUIT_RUN", _to_menu],
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
	if GameState.daily != "":
		GameState.start_daily()
	else:
		GameState.start_run()
	GameState.change_scene("res://scenes/run.tscn")


## Al acabar (o abandonar) un sueño se vuelve al plano astral / After (or leaving) a dream you go back to the astral plane
func _to_menu() -> void:
	get_tree().paused = false
	GameState.hub_spawn = "training" if GameState.training else "fountain"
	GameState.training = false
	GameState.change_scene(HUB)


func _exit_tree() -> void:
	Audio.stop_loops()
