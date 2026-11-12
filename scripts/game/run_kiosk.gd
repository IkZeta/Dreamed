class_name RunKiosk
extends RefCounted
## La kioskera Charo durante la partida: su bienvenida al Acto 2 y el kiosco al acabar algunos sueños.
## Kiosk lady Charo during the run: her Act 2 welcome and the kiosk at the end of some dreams.

var run: Run


func _init(r: Run) -> void:
	run = r


func _spawn(kiosk: bool) -> CharoNpc:
	var charo := CharoNpc.new()
	charo.run = run
	charo.with_kiosk = kiosk
	charo.position = Bedroom.to_world(LivingRoom.KIOSK_POINT if kiosk else LivingRoom.CHARO_POINT)
	if run.room.follows_camera():
		# En el pasillo pone el kiosco cerca de Kroker / In the hallway she sets up near Kroker
		charo.position.x = run.player.position.x + (-300.0 if run.player.position.x > run._camera.position.x - 200.0 else 300.0)
	run._actors.add_child(charo)
	run.player.set_facing(signf(charo.position.x - run.player.position.x))
	return charo


## Bienvenida al Acto 2: quién es, dónde está Kroker y qué es la Realidad Fragmentada
## Welcome to Act 2: who she is, where Kroker is and what Fragmented Reality is
func welcome(then: Callable) -> void:
	var charo := _spawn(false)
	run.get_tree().create_timer(0.9, false).timeout.connect(func() -> void:
		Audio.leitmotif("charo")
		var lines: Array[String] = []
		for i in 8:
			lines.append("CHARO_WELCOME_%d" % (i + 1))
		run._modal = _dialogue(lines, charo)
		run._modal.finished.connect(func() -> void:
			run._modal = null
			Progress.stats["charo_met"] = 1
			Progress.save_progress()
			charo.leave()
			run.get_tree().create_timer(0.7, false).timeout.connect(then)))


func _dialogue(lines: Array[String], charo: CharoNpc) -> CharoDialogue:
	var d := CharoDialogue.new()
	run.add_child(d)
	d.build(lines)
	charo.talk(99.0)
	d.finished.connect(func() -> void: charo.talk(0.0))
	return d


## Al acabar algunos sueños, Charo abre su kiosco / At the end of some dreams Charo opens her kiosk
func shop(then: Callable) -> void:
	var charo := _spawn(true)
	run.get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		charo.talk(1.0)
		var stall := CharoShop.new()
		run._modal = stall
		run.add_child(stall)
		stall.build()
		stall.bought.connect(_on_ware)
		stall.closed.connect(func() -> void:
			run._modal = null
			GameState.saved_hp = run.player.hp
			charo.leave()
			run.get_tree().create_timer(0.7, false).timeout.connect(run._resolve_level_ups.bind(then))))


func _on_ware(id: String) -> void:
	Progress.add_stat("bought")
	var before := run.player.max_hp
	run.player.refresh_stats()
	if run.player.max_hp > before:
		run.player.hp += run.player.max_hp - before
	if KioskRules.ware_heal(id) > 0.0:
		run.player.heal(run.player.max_hp * KioskRules.ware_heal(id))
	run.hud.set_hp(run.player.hp, run.player.max_hp)
	run.hud.set_reality()
	run.hud.set_xp()
