class_name RunCinematics
extends RefCounted
## Escenas de la partida: llegadas al sueño, el despertar del sueño 1, la intro noir del sueño 20 y el despertar final. / Run scenes: dream arrivals, the dream 1 wake-up, the dream 20 noir intro and the final waking.

var run: Run


func _init(r: Run) -> void:
	run = r


## En los sueños siguientes Kroker llega de una de tres formas (solo estético): cae del cielo y
## se estampa de boca contra el suelo, sale de uno de los agujeros del suelo o aparece en un
## resplandor, como cuando se fue pero al revés.
## In later dreams Kroker arrives in one of three ways (purely cosmetic): he falls from the sky
## and faceplants on the floor, climbs out of one of the holes in the floor, or appears in a
## glow, like when he left but in reverse.
## La llegada o el despertar en curso; con aceptar o interactuar se acelera (Run._unhandled_input)
## The arrival or wake-up in progress; accept or interact speeds it up (Run._unhandled_input)
var intro_tw: Tween
var _skip_hint: Label
const SKIP_SPEED := 8.0


## Acelera la llegada si la hay; devuelve si lo ha hecho / Speeds up the arrival if there is one; returns whether it did
func hurry() -> bool:
	if intro_tw == null or not intro_tw.is_valid() or not intro_tw.is_running() or run.running:
		return false
	intro_tw.set_speed_scale(SKIP_SPEED)
	if is_instance_valid(_skip_hint):
		_skip_hint.queue_free()
	return true


## Aviso discreto de que se puede saltar, a partir de la segunda partida
## A discreet note that it can be skipped, from the second run on
func _offer_skip() -> void:
	if int(Progress.stats.get("dreams", 0)) <= 0:
		return
	var layer := CanvasLayer.new()
	layer.layer = 20
	run.add_child(layer)
	_skip_hint = UITheme.label(Settings.controls_text(run.tr("INTRO_SKIP")), 16, Color(UITheme.ASH, 0.7), "caps")
	_skip_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_skip_hint.offset_top = -70
	_skip_hint.offset_bottom = -40
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_skip_hint)
	intro_tw.finished.connect(layer.queue_free)


func drop_in(depth: int) -> void:
	var start := Bedroom.to_world(run.room.start_point())
	run.player.position = start
	run.player.visible = true
	if run.room.open_map():
		run._camera.position = run._camera_clamped(start)
	var ways := ["fall", "glow"]
	if run.room.hole_count() > 0:
		ways.append("hole")
	var tw: Tween
	match ways[randi() % ways.size()]:
		"hole": tw = arrive_hole()
		"glow": tw = arrive_glow(start)
		_: tw = arrive_faceplant(start)
	intro_tw = tw
	tw.tween_interval(0.4)
	# La primera vez que llega al salón, Charo le da la bienvenida
	# The first time he reaches the living room, Charo welcomes him
	if depth == GameState.ACT2_START and not Progress.stats.has("charo_met"):
		tw.tween_callback(run._kiosk.welcome.bind(run._begin.bind(depth)))
	else:
		tw.tween_callback(run._begin.bind(depth))


## Cae en línea recta, de plancha, y se estampa de bruces; se queda un momento tirado, se
## incorpora a cuatro patas, gatea un poco y se levanta sacudiéndose
## Falls in a straight line, flat, and faceplants; lies there for a moment, gets up on all
## fours, crawls a little and stands up, shaking himself off
func arrive_faceplant(at: Vector2) -> Tween:
	var p := run.player
	var f := p._facing
	# Hacia el lado donde no haya agujeros ni pared delante; si no hay ninguno libre, gatea en el sitio
	# Towards the side with no holes or wall ahead; if neither is clear, he crawls on the spot
	var reach := 95.0
	if not _floor_clear(at, f, reach):
		if _floor_clear(at, -f, reach):
			f = -f
		else:
			reach = 0.0
	p.set_facing(f)
	const LIE := 1.5
	p.rotation = LIE * f
	p.hop = 720.0
	p.pose_stretch = 0.0
	p.crawl = 0.0
	p.falling = true
	var head := at + Vector2(118.0 * Player.ART_SCALE * f, -14)
	var tw := run.create_tween()
	tw.tween_interval(0.35)
	# Caída recta, cada vez más deprisa / Straight drop, faster and faster
	tw.tween_property(p, "hop", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		p.falling = false
		Audio.play("land")
		Audio.play("crack", -4.0)
		run.shake(8.0)
		run.fx.dissipate(head, UITheme.BONE)
		run.fx.dissipate(at + Vector2(10 * f, -4), UITheme.BONE)
		run.fx.ring(at + Vector2(55 * f, 0), 34.0, UITheme.BONE, 0.45, 2.2)
		# Estrellitas de mareo sobre la cabeza / Dizzy little stars over the head
		for i in 3:
			run.fx.ring(head + Vector2((i - 1) * 20, -30 - (i % 2) * 10), 5.0, UITheme.GOLD, 1.1, 1.2))
	# Aplastón y rebote contra el suelo / Squash and bounce off the floor
	tw.tween_method(func(k: float) -> void: p.hop = sin(k * PI) * 10.0, 0.0, 1.0, 0.16)
	tw.tween_interval(0.45)
	# Un temblorcito de piernas / A little leg twitch
	tw.tween_method(func(k: float) -> void: p.rotation = (LIE - sin(k * TAU * 2.0) * 0.04) * f, 0.0, 1.0, 0.25)
	tw.tween_interval(0.15)
	# Se incorpora a cuatro patas: el cuerpo gira desde los pies y se adelanta un poco
	# Gets up on all fours: the body turns from the feet and shifts forward a little
	tw.tween_callback(Audio.play.bind("puff", -12.0, 0.1))
	tw.tween_property(p, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "crawl", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "position", at + Vector2(34 * f * signf(reach), 0), 0.35).set_trans(Tween.TRANS_SINE)
	# Gatea tres pasitos / Crawls three little steps
	var crawl_to := at + Vector2(reach * 0.95 * f, 0)
	tw.tween_property(p, "crawl_phase", 3.0 * PI, 0.9)
	tw.parallel().tween_property(p, "position", crawl_to, 0.9)
	for i in 3:
		tw.parallel().tween_callback(func() -> void:
			Audio.play("step", -14.0, 0.15)
			run.fx.dissipate(p.position + Vector2(20 * f, -2), Color(UITheme.BONE, 0.6))).set_delay(0.15 + i * 0.3)
	# Se levanta de un impulso / Springs up
	tw.tween_callback(Audio.play.bind("dash", -10.0, 0.1))
	tw.tween_property(p, "crawl", 0.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(k: float) -> void: p.hop = sin(k * PI) * 22.0, 0.0, 1.0, 0.26)
	tw.tween_callback(func() -> void:
		p.rotation = 0.0
		p.hop = 0.0
		p.crawl = 0.0
		p.crawl_phase = 0.0
		p.pose_stretch = 0.0
		p.falling = false
		p.land())
	return tw


## ¿Hay suelo firme hacia ese lado (sin agujeros ni salirse de la habitación)?
## Is there solid floor that way (no holes, not leaving the room)?
func _floor_clear(at: Vector2, f: float, reach: float) -> bool:
	var area := run.arena_rect().grow(-40.0)
	for d: float in [30.0, 60.0, reach]:
		var q := at + Vector2(d * f, 0)
		if not area.has_point(q) or run.hole_at(q, 40.0, Vector2.ZERO) != Vector2.INF:
			return false
	return true


## Asoma por un agujero del suelo, trepa y salta fuera / Pops up through a floor hole, climbs and hops out
func arrive_hole() -> Tween:
	var holes := run.room.holes_list()
	var hole: Rect2 = Bedroom.rect_world(holes[randi() % run.room.hole_count()])
	var from := hole.get_center() + Vector2(0, hole.size.y * 0.2)
	# Sale hacia delante (abajo en pantalla) o hacia el lado con más sitio / Hops out forward or toward the roomier side
	var area := run.arena_rect().grow(-60)
	var to := from + Vector2(0, hole.size.y * 0.5 + 60)
	if not area.has_point(to):
		to = from + Vector2((hole.size.x * 0.5 + 70) * (1.0 if from.x < area.get_center().x else -1.0), 0)
	to = Vector2(clampf(to.x, area.position.x, area.end.x), clampf(to.y, area.position.y, area.end.y))
	run.player.position = from
	run.player.scale = Vector2(1.0, 0.0)
	run.player.set_facing(signf(to.x - from.x) if absf(to.x - from.x) > 4.0 else 1.0)
	var tw := run.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		Audio.play("crack", -8.0)
		run.fx.dissipate(from, Color("2a2148")))
	# Asoma la cabeza, mira y trepa / Head pops up, looks around and climbs out
	tw.tween_property(run.player, "scale", Vector2(1.0, 0.45), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(run.player, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Audio.play.bind("dash", -10.0, 0.1))
	tw.tween_method(run._hop_down.bind(from, to), 0.0, 1.0, 0.45)
	tw.tween_callback(func() -> void:
		run.player.position = to
		run.player.hop = 0.0
		run.player.land()
		Audio.play("land", -4.0)
		run.fx.ring(to, 22.0, UITheme.BONE, 0.4, 2.0))
	return tw


## Aparece en un resplandor pequeño, como cuando se fue pero al revés
## Appears in a small glow, like when he left but in reverse
func arrive_glow(at: Vector2) -> Tween:
	var glow := DreamGlow.new()
	glow.position = at + Vector2(0, -70)
	run.world.add_child(glow)
	run.player.modulate = Color(3, 3, 3, 0)
	run.player.scale = Vector2(0.4, 0.4)
	var tw := run.create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(Audio.play.bind("astral", -8.0))
	tw.tween_property(glow, "power", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(run.player, "modulate", Color(3, 3, 3, 1), 0.25)
	tw.parallel().tween_property(run.player, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(run.player, "modulate", Color.WHITE, 0.45)
	tw.parallel().tween_property(glow, "power", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		glow.queue_free()
		run.player.land()
		run.fx.dissipate(at + Vector2(0, -40), UITheme.GOLD))
	return tw


func noir_intro(depth: int) -> void:
	var city := run.room as Act4Room
	var at := Bedroom.to_world(city.lean_spot())
	run.player.position = at
	run.player.visible = true
	run.player.set_facing(1.0)
	run.player.pose_lean = -0.09
	run._camera.position = run._camera_clamped(at)
	var intro := NoirIntro.new()
	run.add_child(intro)
	Audio.play_music("music_noir", 1.5)
	intro.bars(true)
	var base_zoom := run._camera.zoom
	run.create_tween().tween_property(run._camera, "zoom", base_zoom * 1.35, 2.5).set_trans(Tween.TRANS_SINE)
	await run.get_tree().create_timer(1.4, false).timeout
	var keys: Array[String] = []
	for i in 8:
		keys.append("NOIR_%d" % (i + 1))
	intro.monologue(keys)
	await intro.finished
	# Estallan los edificios / The buildings blow up
	Audio.fade_music(-30.0, 0.6)
	run.player.pose_lean = 0.0
	run.create_tween().tween_property(run._camera, "zoom", base_zoom, 0.7).set_trans(Tween.TRANS_SINE)
	await run.get_tree().create_timer(0.6, false).timeout
	var blds: Array = []
	for n: Node in run._actors.get_children():
		if n is CityBuilding:
			blds.append(n)
	blds.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.distance_to(run.player.position) < b.position.distance_to(run.player.position))
	for i in mini(6, blds.size()):
		(blds[i] as CityBuilding).explode()
		run.flash_screen(Color(1, 0.97, 0.9), 0.25)
		await run.get_tree().create_timer(0.32, false).timeout
	var toppled := 0
	for t: CityFall in run._towers:
		if toppled < 2 and is_instance_valid(t) and t.standing() and t.position.distance_to(run.player.position) < 900.0:
			t.wear = 1.0
			t.topple()
			toppled += 1
	await run.get_tree().create_timer(1.2, false).timeout
	# La cámara se aleja hasta ver toda la ciudad / The camera pulls back to show the whole city
	var city_c: Vector2 = city.map_world_rect().get_center()
	run._cam_free = true
	run.cam_focus = city_c + Vector2(0, 40)
	run.create_tween().tween_property(run._camera, "zoom", base_zoom * 0.42, 2.4).set_trans(Tween.TRANS_SINE)
	Audio.play("rumble", -2.0)
	await run.get_tree().create_timer(2.5, false).timeout
	# Las vallas y las pantallas salen volando y se juntan en el cielo / Billboards and screens fly off and gather in the sky
	var evil_at := run.clamp_to_arena(city_c + Vector2(0, 260), 80.0)
	var swarm := AdSwarm.new()
	swarm.center = evil_at + Vector2(0, -EvilAd.ALT - 250.0)
	for n: Node in run._actors.get_children():
		if n is CityBillboard:
			var bb := n as CityBillboard
			swarm.add_piece(bb.panel_world(), "board", bb.ad, randf_range(0.0, 1.6))
			run.get_tree().create_timer(randf_range(0.0, 1.6), false).timeout.connect(func() -> void:
				if is_instance_valid(bb):
					bb.take())
		elif n is CityBuilding and (n as CityBuilding).kind != "house":
			var bl := n as CityBuilding
			swarm.add_piece(bl.screen_world(), "tv", 0, randf_range(0.2, 1.8))
			run.get_tree().create_timer(randf_range(0.2, 1.8), false).timeout.connect(func() -> void:
				if is_instance_valid(bl):
					bl.screen_taken = true)
	run.world.add_child(swarm)
	Audio.play("glitch", -2.0)
	Audio.play("boss_wake", -4.0)
	for i in 5:
		run.get_tree().create_timer(0.7 + i * 0.8, false).timeout.connect(func() -> void:
			# Si se ha salido de la partida a mitad de la escena, no queda nada que sacudir
			# If the run was left mid-scene, there's nothing left to shake
			if not is_instance_valid(run) or not run.is_inside_tree():
				return
			run.shake(4.0 + i * 2.0)
			Audio.play("glitch", -10.0, 0.2))
	await swarm.formed
	# Se forma Evil Ad / Evil Ad takes shape
	run._evil = EvilAd.new()
	run._evil.setup(run)
	run._evil.entering = 0.0
	run._evil.position = evil_at
	run.enemies.add_child(run._evil)
	run.shake(18.0)
	run.flash_screen(Color("e0303a"), 0.5)
	run.noir_glitch(0.5, 1.0)
	Audio.play("stomp", 0.0)
	Audio.play("crack", -2.0)
	run._evil.laugh(3.0)
	await run.get_tree().create_timer(1.0, false).timeout
	# Vuelve la cámara y Evil Ad se planta delante de Kroker / The camera comes back and Evil Ad plants himself in front of Kroker
	var meet := run.clamp_to_arena(run.player.position + Vector2(360, 40), 80.0)
	run.cam_focus = (run.player.position + meet) / 2.0
	var back := run.create_tween().set_parallel()
	back.tween_property(run._camera, "zoom", base_zoom, 2.2).set_trans(Tween.TRANS_SINE)
	back.tween_property(run._evil, "position", meet, 2.2).set_trans(Tween.TRANS_SINE)
	await back.finished
	run._cam_free = false
	run.player.set_facing(1.0)
	# Diálogo antes de la pelea / Dialogue before the fight
	var talk: Array[String] = ["evil:EVIL_TALK_1", "kroker:EVIL_TALK_2", "evil:EVIL_TALK_3", "kroker:EVIL_TALK_4", "evil:EVIL_TALK_5", "kroker:EVIL_TALK_6"]
	intro.monologue(talk)
	await intro.finished
	run.shake(16.0)
	run.flash_screen(Color("e0303a"), 0.4)
	Audio.play("stomp", 0.0)
	run._evil.laugh(2.5)
	run.fx.text(run._evil.global_position + Vector2(0, -420), tr("EVIL_AD_SHOUT"), Color("e0303a"), 34)
	intro.title_card("BOSS_EVIL_AD_NAME", "BOSS_EVIL_AD_SUB")
	await run.get_tree().create_timer(2.8, false).timeout
	intro.bars(false)
	run.cam_focus = Vector2.INF
	run.get_tree().create_timer(1.0, false).timeout.connect(intro.queue_free)
	run._begin(depth)


## Intro: Kroker duerme, se revuelve, se incorpora, se estira, se pone las gafas,
## sale de la cama, va a por su arma y empieza el sueño.
## Intro: Kroker sleeps, tosses, sits up, stretches, puts on his glasses, gets out
## of bed, goes to fetch his weapon and the dream begins.
func play_wake_up(depth: int) -> void:
	var outfit := GameState.selected_character
	var wake := Bedroom.to_world(Bedroom.WAKE_POINT)
	var start := Bedroom.to_world(Bedroom.START_POINT)
	var pickup := Bedroom.to_world(Bedroom.PICKUP.get(outfit, Bedroom.START_POINT))
	var tw := run.create_tween()
	intro_tw = tw
	_offer_skip()
	tw.tween_interval(1.5)
	tw.tween_property(run.room, "stir", 1.0, 0.9)
	tw.tween_callback(func() -> void:
		run.room.bed_state = "sitting"
		Audio.play("blanket"))
	tw.tween_property(run.room, "sit", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Audio.play.bind("yawn"))
	tw.tween_property(run.room, "stretch", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.45)
	tw.tween_property(run.room, "stretch", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		run.room.glasses_on_stand = false
		Audio.play("chime")
		run.fx.dissipate(Bedroom.to_world(Bedroom.NIGHTSTAND.position + Vector2(30, 64)), UITheme.GOLD))
	tw.tween_interval(0.4)
	# Se desliza hasta el borde de la cama, mirando hacia fuera
	# Shuffles to the edge of the bed, facing out
	tw.tween_callback(Audio.play.bind("blanket"))
	tw.tween_property(run.room, "slide", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Baja de un saltito a la alfombrita / Hops down onto the little rug
	tw.tween_callback(func() -> void:
		run.room.bed_state = "empty"
		run.player.armed = false
		run.player.set_facing(1.0)
		run.player.position = Bedroom.to_world(run.room.sitting_feet())
		run.player.visible = true)
	tw.tween_method(run._hop_down.bind(Bedroom.to_world(run.room.sitting_feet_end()), wake), 0.0, 1.0, 0.55)
	tw.tween_callback(func() -> void:
		run.player.hop = 0.0
		run.player.land()
		Audio.play("land")
		run.fx.ring(wake + Vector2(0, -4), 22.0, UITheme.BONE, 0.4, 2.2))
	tw.tween_interval(0.35)
	# La pistola de dedos no hay que ir a buscarla: la "recarga" con la mano y sopla el humo
	# The finger gun needn't be fetched: he "reloads" it with his hand and blows the smoke away
	if outfit == "finger":
		tw.tween_callback(func() -> void:
			run.room.weapon_taken = true
			run.player.armed = true
			run.player.reload_anim = 1.0)
		tw.tween_interval(Player.RELOAD_TIME * 0.27)
		tw.tween_callback(Audio.play.bind("ui_click", -4.0))
		tw.tween_interval(Player.RELOAD_TIME * 0.31)
		tw.tween_callback(func() -> void:
			Audio.play("ui_click", -2.0)
			run.fx.ring(wake + Vector2(30, -110), 14.0, KrokerArt.ACCENT["finger"], 0.35, 2.0))
		tw.tween_interval(Player.RELOAD_TIME * 0.15)
		tw.tween_callback(Audio.play.bind("puff", -8.0))
		tw.tween_interval(Player.RELOAD_TIME * 0.35)
		tw.tween_property(run.player, "position", start, run._walk_time(wake, start))
		tw.tween_callback(func() -> void:
			run.hud.visible = true
			run.hud.start(depth)
			run.hud.show_event(run.event)
			run.running = true)
		return
	tw.tween_property(run.player, "position", pickup, run._walk_time(wake, pickup))
	tw.tween_callback(func() -> void:
		run.room.weapon_taken = true
		run.player.armed = true
		run.player.attack_anim = 1.0
		run.player.cast_anim = 1.0
		Audio.play("pickup")
		run.fx.dissipate(pickup + Vector2(0, -80), UITheme.GOLD)
		run.fx.ring(pickup + Vector2(0, -80), 30.0, UITheme.GOLD, 0.5, 2.0))
	tw.tween_interval(0.6)
	tw.tween_property(run.player, "position", start, run._walk_time(pickup, start))
	tw.tween_callback(func() -> void:
		run.hud.visible = true
		run.hud.start(depth)
		run.hud.show_event(run.event)
		run.running = true)


## Kroker se despierta en su cama de verdad: sobresaltado al morir o tranquilo al ganar.
## Kroker wakes up in his real bed: startled when he dies, peaceful when he wins.
func wake_scene(won: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	run.add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color("f7f2ff") if not Settings.reduce_flashes else Color("3a3570")
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := run.create_tween()
	tw.tween_property(flash, "modulate:a", 1.0, 0.35)
	tw.tween_callback(build_real_room.bind(won))
	tw.tween_property(flash, "modulate:a", 0.0, 0.8)
	if won:
		tw.tween_interval(2.6)
		# Al despertar del sueño 20 por primera vez, pasan los créditos
		# On waking from dream 20 for the first time, the credits roll
		if GameState.act() == 4 and not Progress.stats.has("credits_seen") and not GameState.god_mode:
			tw.tween_callback(_roll_credits)
		else:
			tw.tween_callback(run._show_victory)
	else:
		tw.tween_callback(run._startle)
		tw.tween_interval(2.2)
		tw.tween_callback(run._show_loss)


func _roll_credits() -> void:
	Progress.stats["credits_seen"] = 1
	Progress.save_progress()
	var layer := CanvasLayer.new()
	layer.layer = 40
	run.add_child(layer)
	var c := CreditsRoll.make()
	layer.add_child(c)
	c.closed.connect(func() -> void:
		layer.queue_free()
		run._show_victory())


## La habitación de verdad, sin nada raro / The real bedroom, with nothing strange
func build_real_room(won: bool) -> void:
	for n: Node in run.world.get_children():
		if n is Darkness or n is YawnHoles or n is TiltFloor or n is MeteorShower or n is IceFloor or n is CityFall or n is AdSwarm or n is Pickup or n is Puddle or n is StarShard or n is EnemyShot or n is PillowProjectile or n is ChefShot or n is PlateShards:
			n.queue_free()
	for e: Node in run.enemies.get_children():
		e.queue_free()
	# Los edificios, árboles y escombros de la ciudad / The city's buildings, trees and rubble
	for n: Node in run._actors.get_children():
		if n is CityBuilding or n is CityProp or n is CityBillboard or n is CityFall or n is Helpers.Actor:
			n.queue_free()
	run.fx.clear()
	# Al despertar, el mundo vuelve a tener color / On waking up, the world gets its colour back
	if is_instance_valid(run._noir_holder):
		run._noir_holder.material = null
	run._noir_mat = null
	run.player.fedora = false
	run.hud.visible = false
	run.player.visible = false
	run.player.push = Vector2.ZERO
	var idx := run.room.get_index()
	run.room.queue_free()
	run.room = Bedroom.new()
	run.room.outfit = GameState.selected_character
	run.room.weird = 0
	run.room.bed_state = "sleeping" if won else "sitting"
	run.room.sit = 0.0
	run.room.glasses_on_stand = true
	run.world.add_child(run.room)
	run.world.move_child(run.room, idx)
	run._camera.rotation = 0.0
	run._camera.position = Bedroom.to_world(Vector2(800, 460))
	run._camera.zoom = Vector2.ONE * 0.64
	Audio.play_music("music_menu", 1.5)
