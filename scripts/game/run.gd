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

## Se emite al acabar cada sueño (lo usa el bot de equilibrio) / Emitted when each dream ends (used by the balance bot)
signal dream_finished

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
var boss: Enemy
var bosses: Array[Enemy] = []
var _boss_total := 0.0
var _boss_step := 0
var _level_screen: LevelUpScreen
## Evento de este sueño: "", "dark", "tilt" o "golden" / This dream's event
var event := ""
var _tilt := Vector2.ZERO
var _tilt_t := 0.0
var _golden_t := -1.0
var _actors: Node2D
## Pantalla que tapa la partida (diálogo, kiosco, chimenea): mientras está, no se pausa
## Screen covering the run (dialogue, kiosk, fireplace): while it's up, pausing is disabled
var _modal: Node
## Tras cancelar en la chimenea hay que apartarse para volver a cargarla
## After cancelling at the fireplace you have to step away before charging it again
var _hearth_lock := false


func _ready() -> void:
	var depth := GameState.dream_depth
	_wave = GameState.wave_for(depth)
	# Se guarda al empezar cada sueño (para "Continuar") / Saved at the start of every dream (for "Continue")
	GameState.save_run()
	var act := GameState.act_of(depth)
	Audio.play_music(["", "music_dream1", "music_living", "music_dream1"][act], 2.5)
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

	if act >= 3:
		# Acto 3 (provisional) / Act 3 (placeholder)
		room = Act3Room.new()
		room.weird = depth - GameState.ACT3_START + 1
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

	hud = HUD.new()
	add_child(hud)
	hud.visible = false
	hud.set_hp(player.hp, player.max_hp)
	hud.set_time(_time_left)
	if "shield" in GameState.weapons() and GameState.level("svinho", "shield") > 0:
		hud.set_special_mode(false)
	_roll_event(depth)
	if depth == 1:
		_play_wake_up(depth)
	else:
		_drop_in(depth)


## En los sueños siguientes Kroker llega de una de tres formas (solo estético): cae del cielo y
## se estampa de boca contra el suelo, sale de uno de los agujeros del suelo o aparece en un
## resplandor, como cuando se fue pero al revés.
## In later dreams Kroker arrives in one of three ways (purely cosmetic): he falls from the sky
## and faceplants on the floor, climbs out of one of the holes in the floor, or appears in a
## glow, like when he left but in reverse.
func _drop_in(depth: int) -> void:
	var start := Bedroom.to_world(Bedroom.START_POINT)
	player.position = start
	player.visible = true
	var ways := ["fall", "glow"]
	if room.hole_count() > 0:
		ways.append("hole")
	var tw: Tween
	match ways[randi() % ways.size()]:
		"hole": tw = _arrive_hole()
		"glow": tw = _arrive_glow(start)
		_: tw = _arrive_faceplant(start)
	tw.tween_interval(0.4)
	# La primera vez que llega al salón, Charo le da la bienvenida
	# The first time he reaches the living room, Charo welcomes him
	if depth == GameState.ACT2_START and not Progress.stats.has("charo_met"):
		tw.tween_callback(_charo_welcome.bind(_begin.bind(depth)))
	else:
		tw.tween_callback(_begin.bind(depth))


## Cae dando vueltas y se estampa de boca; se queda un momento mareado y se levanta
## Falls tumbling and faceplants; stays dizzy for a moment and gets up
func _arrive_faceplant(at: Vector2) -> Tween:
	var f := player._facing
	player.hop = 600.0
	player.rotation = -0.4 * f
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(player, "hop", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(player, "rotation", 1.45 * f, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Audio.play("land")
		Audio.play("crack", -4.0)
		shake(7.0)
		fx.dissipate(at + Vector2(60 * f, -10), UITheme.BONE)
		fx.ring(at + Vector2(60 * f, 0), 26.0, UITheme.BONE, 0.45, 2.2)
		# Estrellitas de mareo / Dizzy little stars
		for i in 3:
			fx.ring(at + Vector2(70 * f + (i - 1) * 22, -50 - (i % 2) * 10), 5.0, UITheme.GOLD, 0.9, 1.2))
	# Rebote al estamparse / Bounce on impact
	tw.tween_property(player, "rotation", 1.32 * f, 0.08)
	tw.tween_property(player, "rotation", 1.45 * f, 0.1)
	tw.tween_interval(0.7)
	# Se levanta de un salto / Springs back up
	tw.tween_callback(Audio.play.bind("dash", -10.0, 0.1))
	tw.tween_property(player, "rotation", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(k: float) -> void: player.hop = sin(k * PI) * 26.0, 0.0, 1.0, 0.28)
	tw.tween_callback(func() -> void:
		player.rotation = 0.0
		player.hop = 0.0
		player.land())
	return tw


## Asoma por un agujero del suelo, trepa y salta fuera / Pops up through a floor hole, climbs and hops out
func _arrive_hole() -> Tween:
	var holes := room.holes_list()
	var hole: Rect2 = Bedroom.rect_world(holes[randi() % room.hole_count()])
	var from := hole.get_center() + Vector2(0, hole.size.y * 0.2)
	# Sale hacia delante (abajo en pantalla) o hacia el lado con más sitio / Hops out forward or toward the roomier side
	var area := arena_rect().grow(-60)
	var to := from + Vector2(0, hole.size.y * 0.5 + 60)
	if not area.has_point(to):
		to = from + Vector2((hole.size.x * 0.5 + 70) * (1.0 if from.x < area.get_center().x else -1.0), 0)
	to = Vector2(clampf(to.x, area.position.x, area.end.x), clampf(to.y, area.position.y, area.end.y))
	player.position = from
	player.scale = Vector2(1.0, 0.0)
	player.set_facing(signf(to.x - from.x) if absf(to.x - from.x) > 4.0 else 1.0)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		Audio.play("crack", -8.0)
		fx.dissipate(from, Color("2a2148")))
	# Asoma la cabeza, mira y trepa / Head pops up, looks around and climbs out
	tw.tween_property(player, "scale", Vector2(1.0, 0.45), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(player, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Audio.play.bind("dash", -10.0, 0.1))
	tw.tween_method(_hop_down.bind(from, to), 0.0, 1.0, 0.45)
	tw.tween_callback(func() -> void:
		player.position = to
		player.hop = 0.0
		player.land()
		Audio.play("land", -4.0)
		fx.ring(to, 22.0, UITheme.BONE, 0.4, 2.0))
	return tw


## Aparece en un resplandor pequeño, como cuando se fue pero al revés
## Appears in a small glow, like when he left but in reverse
func _arrive_glow(at: Vector2) -> Tween:
	var glow := DreamGlow.new()
	glow.position = at + Vector2(0, -70)
	world.add_child(glow)
	player.modulate = Color(3, 3, 3, 0)
	player.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(Audio.play.bind("astral", -8.0))
	tw.tween_property(glow, "power", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "modulate", Color(3, 3, 3, 1), 0.25)
	tw.parallel().tween_property(player, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "modulate", Color.WHITE, 0.45)
	tw.parallel().tween_property(glow, "power", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		glow.queue_free()
		player.land()
		fx.dissipate(at + Vector2(0, -40), UITheme.GOLD))
	return tw


## Empieza el sueño de verdad / The dream really starts
func _begin(depth: int) -> void:
	hud.visible = true
	hud.start(depth)
	hud.show_event(event)
	hud.set_reality()
	running = true
	if room is LivingRoom and (room as LivingRoom).fire_lit:
		hud.show_fire(true)
		Audio.set_loop("fire", true, -16.0)
	_resolve_level_ups(Callable())
	if _wave.get("boss", false):
		_spawn_boss()


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
		Audio.play("giver_charo", -4.0)
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
	if id == "milk":
		player.heal(player.max_hp * 0.4)
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

func _update_hearth(delta: float) -> void:
	if not room is LivingRoom:
		return
	var lr := room as LivingRoom
	if not lr.can_sacrifice():
		return
	var inside := Bedroom.rect_world(LivingRoom.HEARTH_ZONE).has_point(player.position)
	if not inside:
		_hearth_lock = false
	if inside and not _hearth_lock:
		lr.fire_charge = minf(1.0, lr.fire_charge + delta / 1.2)
		if lr.fire_charge >= 1.0:
			_open_sacrifice()
	else:
		lr.fire_charge = maxf(0.0, lr.fire_charge - delta * 2.0)


func _open_sacrifice() -> void:
	var lr := room as LivingRoom
	lr.fire_charge = 0.0
	_hearth_lock = true
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
		gain_reality(GameState.REALITY_SACRIFICE, at))
	sc.cancelled.connect(func() -> void:
		_modal = null
		get_tree().paused = false)


## El jefe del acto: los muebles despiertan de uno en uno / The act boss: the furniture wakes up one at a time
func _spawn_boss() -> void:
	Audio.play_music("music_boss", 1.0)
	if _wave.get("boss_kind", "") == "chef":
		_spawn_chef()
		return
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
	var piece := BossPiece.new()
	piece.attack_slow = slow
	piece.setup_piece(self, kind)
	enemies.add_child(piece)
	_add_boss(piece)
	piece.defeated.connect(_on_piece_defeated)


func _add_boss(b: Enemy) -> void:
	boss = b
	bosses.append(b)
	_boss_total += b.max_hp
	update_boss_hp()


## Jefe del Acto 2: El Chef sale de la tele / Act 2 boss: The Chef comes out of the TV
func _spawn_chef() -> void:
	Audio.play_music("music_chef", 1.0)
	hud.show_boss("BOSS_CHEF_NAME")
	var chef := Chef.new()
	chef.setup(self)
	enemies.add_child(chef)
	_add_boss(chef)
	chef.defeated.connect(_on_chef_defeated)


## Se acabó el tiempo del jefe: se retira y Kroker pasa igualmente (ha aguantado)
## The boss's time is up: it retreats and Kroker passes anyway (he survived)
func _boss_time_up() -> void:
	if not running:
		return
	for b in bosses:
		if is_instance_valid(b) and float(b.get("_dying")) < 0.0:
			fx.dissipate(b.aim_point(), UITheme.BONE)
			fx.ring(b.global_position, 60.0, UITheme.BONE, 0.6, 3.0)
			b.die(false)
			# El mueble vuelve a su sitio, dormido otra vez / The furniture goes back to its place, asleep again
			if b is BossPiece:
				room.gone.erase((b as BossPiece).kind)
	shake(8.0)
	if _wave.get("boss_kind", "") == "chef":
		_chef_end(false)
	else:
		_on_act_cleared(false)


## Recompensa por derrotar al jefe antes de tiempo: un nivel de regalo
## Reward for beating the boss before the time runs out: a bonus level
func _boss_bonus() -> void:
	GameState.pending_ups += 1
	fx.text(player.global_position + Vector2(0, -130), tr("BOSS_BONUS_LEVEL"), UITheme.GOLD, 30)
	fx.ring(player.global_position + Vector2(0, -60), 50.0, UITheme.GOLD, 0.8, 3.0)
	Audio.play("chime", -2.0)


func _on_chef_defeated() -> void:
	_chef_end(true)


func _chef_end(killed: bool) -> void:
	if not running:
		return
	update_boss_hp()
	running = false
	Audio.stop_loops()
	for e: Node in enemies.get_children():
		if not e.is_boss():
			e.die(false)
	dream_finished.emit()
	Progress.clear_act(GameState.selected_character, GameState.difficulty, 2)
	if GameState.run_hits == 0 and not (GameState.god_mode and GameState.god_invuln):
		Progress.flag("no_hit")
	Progress.add_stat("dreams")
	Audio.fade_music(-30.0, 1.5)
	Audio.play("act_clear", -1.0)
	# El sueño sigue: Kroker elige una segunda arma y cae en el Acto 3
	# The dream goes on: Kroker picks a second weapon and falls into Act 3
	GameState.saved_hp = player.hp
	Progress.save_progress()
	hud.hide_boss()
	hud.banner("ACT2_CLEAR_TITLE", "BOSS_KILLED_SUB" if killed else "BOSS_SURVIVED_SUB")
	if killed:
		_boss_bonus()
	for sh in get_tree().get_nodes_in_group("shards"):
		sh.set("_magnet", true)
	get_tree().create_timer(3.4, false).timeout.connect(_choose_second_weapon.bind(_resolve_level_ups.bind(_flash_to_astral)))


## Pantalla para elegir la segunda arma (la del otro tipo) / Screen to pick the second weapon (the other kind)
func _choose_second_weapon(then: Callable) -> void:
	if GameState.second_weapon != "":
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
		then.call())


## Barra del jefe: la vida que les queda a los muebles despiertos / Boss bar: health left on the awake pieces
func update_boss_hp() -> void:
	var hp := 0.0
	for b in bosses:
		if is_instance_valid(b) and float(b.get("_dying")) < 0.0:
			hp += maxf(b.hp, 0.0)
	hud.set_boss_hp(hp, maxf(_boss_total, 1.0))


func _on_piece_defeated() -> void:
	if not running:
		return
	update_boss_hp()
	if _boss_step >= BossPiece.ORDER.size():
		# Se acaba cuando no queda ningún mueble en pie / It ends when no piece is left standing
		for b in bosses:
			if is_instance_valid(b) and float(b.get("_dying")) < 0.0:
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
	_follow_camera(delta)
	_shake = maxf(0.0, _shake - delta * 30.0)
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * Settings.shake_amount
	if not running:
		player.push = Vector2.ZERO
		return
	GameState.run_time += delta
	_update_event(delta)
	_update_hearth(delta)
	if float(_wave.get("duration", 0.0)) > 0.0:
		_time_left -= delta
		hud.set_time(_time_left)
		if _time_left <= 0.0:
			if _wave.get("boss", false):
				_boss_time_up()
			else:
				_on_wave_cleared()
			return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _wave["spawn_every"]
		_spawn_group()
	if room.follows_camera():
		_recycle_far_enemies()


## Pasillo infinito: la cámara sigue a Kroker de lado a lado / Endless hallway: the camera follows Kroker sideways
func _follow_camera(delta: float) -> void:
	if not room.follows_camera() or not is_instance_valid(player):
		return
	_camera.position.x = lerpf(_camera.position.x, player.position.x, minf(1.0, delta * 6.0))


## Los enemigos que se quedan muy atrás vuelven a aparecer por delante (como en Vampire Survivors)
## Enemies left far behind reappear ahead (like in Vampire Survivors)
func _recycle_far_enemies() -> void:
	for e: Node in enemies.get_children():
		if not e is Enemy or e.is_boss() or e is GoldenFoox or not e.is_targetable():
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
		if not e.is_boss() and not e is Mosquito:
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
		if new_kind == "cyber" and _spawned_new > 1:
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
			return k
	return "foox"


func _count_alive(type: Variant) -> int:
	var n := 0
	for e: Node in enemies.get_children():
		if is_instance_of(e, type) and e.is_targetable():
			n += 1
	return n


func _spawn_point() -> Vector2:
	var area := arena_rect().grow(-30)
	# En el pasillo infinito salen alrededor de lo que se ve / In the endless hallway they spawn around the view
	if room.follows_camera():
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
		_: e = Foox.new()
	e.setup(self)
	e.position = pos
	# Élites desde el Sueño 2 / Elites from Dream 2
	if GameState.dream_depth >= 2 and randf() < (0.12 if GameState.difficulty == "nightmare" else 0.07):
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
		if hr.has_point(p):
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
	var r := arena_rect().grow(-margin * 0.5)
	p = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	for o in room.blockers():
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
		gain_reality(GameState.REALITY_ELITE, e.global_position)
	if e.get("bestiary_id") == "golden_foox":
		Progress.add_stat("golden")
	# En las peleas contra jefes, los enemigos de alrededor sueltan un tercio de estrellas (para no
	# subir diez niveles en una pelea larga); los élites, todas
	# In boss fights the surrounding enemies drop a third of the stars (so a long fight doesn't
	# grant ten levels); elites still drop them all
	var shard_k := 0.34 if _wave.get("boss", false) and not elite and not e.is_boss() else 1.0
	drop_shards(e.global_position, roundi(int(e.get("shards")) * GameState.shard_mult() * shard_k))
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
		"tilt":
			var tf := TiltFloor.new()
			tf.run = self
			world.add_child(tf)
			world.move_child(tf, room.get_index() + 1)


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
				if e is Enemy and not e.is_boss():
					e.external_pull += _tilt * 0.8
			# La cámara se ladea con la pendiente y se desplaza un poco cuesta abajo
			# The camera leans with the slope and drifts a little downhill
			_camera.rotation = lerpf(_camera.rotation, -_tilt.x / 75.0 * 0.06, minf(1.0, delta * 2.0))
			_camera.offset += _tilt * 0.35
			hud.set_tilt(_tilt)
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
	GameState.clear_saved_run()
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
		if n is Darkness or n is TiltFloor or n is Pickup or n is Puddle or n is StarShard or n is EnemyShot or n is PillowProjectile or n is ChefShot or n is PlateShards:
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
	var act := GameState.act()
	var m := int(GameState.run_time) / 60
	var sec := int(GameState.run_time) % 60
	var lines := [
		tr("SUM_TIME") % ("%d:%02d" % [m, sec]),
		tr("SUM_KILLS") % GameState.run_kills,
		tr("SUM_DIFFICULTY") % tr("DIFF_" + GameState.difficulty.to_upper()),
	]
	_show_end("ACT%d_CLEAR_TITLE" % act, "ACT%d_CLEAR_SUB" % act, [["BTN_DREAM_AGAIN", _restart], ["BTN_MAIN_MENU", _to_menu]], lines)
	_overlay.add_side(PauseSummary.make(player))


func _on_wave_cleared() -> void:
	dream_finished.emit()
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
	get_tree().create_timer(1.5, false).timeout.connect(_resolve_level_ups.bind(_after_dream))


## Después de un sueño: a veces el kiosco de Charo; luego el plano astral o el final del acto
## After a dream: sometimes Charo's kiosk; then the astral plane or the end of the act
func _after_dream() -> void:
	var next := _end_run_victory if _wave.get("act_end", false) else _flash_to_astral
	# En el Acto 1 solo si ya conoces a Charo / In Act 1 only if you've already met Charo
	if _wave.get("shop", false) or (_wave.get("shop_met", false) and Progress.stats.has("charo_met")):
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
	get_tree().create_timer(1.6, false).timeout.connect(_wake_scene.bind(true))


## Un resplandor pequeño sale de Kroker, se lo lleva y pasa al plano astral
## A small glow comes out of Kroker, takes him away and he goes to the astral plane
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
		_boss_bonus()
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
