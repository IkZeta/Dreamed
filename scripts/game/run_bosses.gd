class_name RunBosses
extends RefCounted
## Los jefes de cada acto: los muebles de la habitación, el chef, el ovni y Evil Ad; su aparición, su barra de vida y cómo acaba cada pelea (ganada o por tiempo). / Each act's bosses: the bedroom furniture, the chef, the UFO and Evil Ad; how they appear, their health bar and how each fight ends (won or on time).

var run: Run


func _init(r: Run) -> void:
	run = r


## El jefe del acto: los muebles despiertan de uno en uno / The act boss: the furniture wakes up one at a time
func spawn_boss() -> void:
	Progress.tip("boss")
	if run._wave.get("boss_kind", "") == "":
		Audio.play_music("music_boss", 1.0)
	if run._wave.get("boss_kind", "") == "chef":
		spawn_chef()
		return
	if run._wave.get("boss_kind", "") == "ufo":
		spawn_ufo()
		return
	if run._wave.get("boss_kind", "") == "evil_ad":
		spawn_evil_ad()
		return
	run.hud.show_boss("BOSS_NAME")
	run._boss_step = 0
	if GameState.difficulty == "nightmare":
		# Pesadilla: los tres muebles despiertan a la vez / Nightmare: all three pieces wake at once
		run.hud.set_boss_part("BOSS_PART_ALL")
		for i in BossPiece.ORDER.size():
			run.get_tree().create_timer(0.6 * i, false).timeout.connect(add_boss_piece.bind(BossPiece.ORDER[i], 1.6))
		run._boss_step = BossPiece.ORDER.size()
	else:
		next_boss_piece()


func next_boss_piece() -> void:
	if run._boss_step >= BossPiece.ORDER.size():
		run._on_act_cleared()
		return
	var kind: String = BossPiece.ORDER[run._boss_step]
	run._boss_step += 1
	run.hud.set_boss_part(BossPiece.PARTS[kind]["name"])
	add_boss_piece(kind)


func add_boss_piece(kind: String, slow := 1.0) -> void:
	if not run.running:
		return
	run.room.gone.append(kind)
	var piece := BossPiece.new()
	piece.attack_slow = slow
	piece.setup_piece(run, kind)
	run.enemies.add_child(piece)
	add_boss(piece)
	piece.defeated.connect(on_piece_defeated)


func add_boss(b: Enemy) -> void:
	run.boss = b
	run.bosses.append(b)
	run._boss_total += b.max_hp
	run.update_boss_hp()


## Jefe del Acto 2: El Chef sale de la tele / Act 2 boss: The Chef comes out of the TV
func spawn_chef() -> void:
	Audio.play_music("music_chef", 1.0)
	run.hud.show_boss("BOSS_CHEF_NAME")
	var chef := Chef.new()
	chef.setup(run)
	run.enemies.add_child(chef)
	add_boss(chef)
	chef.defeated.connect(on_chef_defeated)


## Se acabó el tiempo del jefe: se retira y Kroker pasa igualmente (ha aguantado)
## The boss's time is up: it retreats and Kroker passes anyway (he survived)
func boss_time_up() -> void:
	if not run.running:
		return
	for b in run.bosses:
		if is_instance_valid(b) and float(b.get("_dying")) < 0.0:
			run.fx.dissipate(b.aim_point(), UITheme.BONE)
			run.fx.ring(b.global_position, 60.0, UITheme.BONE, 0.6, 3.0)
			b.die(false)
			# El mueble vuelve a su sitio, dormido otra vez / The furniture goes back to its place, asleep again
			if b is BossPiece:
				run.room.gone.erase((b as BossPiece).kind)
	run.shake(8.0)
	if run._wave.get("boss_kind", "") == "chef":
		chef_end(false)
	elif run._wave.get("boss_kind", "") == "ufo":
		ufo_end(false)
	elif run._wave.get("boss_kind", "") == "evil_ad":
		evil_end(false)
	else:
		run._on_act_cleared(false)


## Recompensa por derrotar al jefe antes de tiempo: un nivel de regalo
## Reward for beating the boss before the time runs out: a bonus level
func boss_bonus() -> void:
	GameState.pending_ups += 1
	run.fx.text(run.player.global_position + Vector2(0, -130), tr("BOSS_BONUS_LEVEL"), UITheme.GOLD, 30, true)
	run.fx.pillar(run.player.global_position, UITheme.GOLD)
	Audio.play("chime", -2.0)
	_fireworks()


## Fuegos artificiales de sueño por la pantalla al ganar a un jefe: estallidos de confeti de
## colores, uno tras otro, con su ondita y un «pop» suave
## Dream fireworks across the screen on beating a boss: bursts of coloured confetti, one after
## another, each with its little wave and a soft "pop"
func _fireworks() -> void:
	var v: Rect2 = run.view_rect()
	var cols := [Color("f6d993"), Color("ff9fc8"), Color("9fe8ff"), Color("b48cff"), Color("9be38a")]
	run.pulse(UITheme.GOLD, 0.35, 0.006)
	run.punch(0.04)
	for i in 9:
		run.get_tree().create_timer(0.15 + i * 0.22, false).timeout.connect(func() -> void:
			if not is_instance_valid(run):
				return
			var p := Vector2(randf_range(v.position.x + v.size.x * 0.15, v.end.x - v.size.x * 0.15), randf_range(v.position.y + v.size.y * 0.15, v.position.y + v.size.y * 0.6))
			var c: Color = cols[i % cols.size()]
			run.fx.burst(p, c, true)
			run.fx.burst(p, Color.WHITE, false)
			Audio.play("dream_pop", -12.0, 0.1, 0.8 + 0.06 * i))


## Jefe del Acto 3: el Ovni baja dando tumbos por el pasillo / Act 3 boss: the UFO lurches down the hallway
func spawn_ufo() -> void:
	Audio.play_music("music_ufo", 1.0)
	run.hud.show_boss("BOSS_UFO_NAME")
	var ufo := Ufo.new()
	ufo.setup(run)
	run.enemies.add_child(ufo)
	add_boss(ufo)
	ufo.defeated.connect(ufo_end.bind(true))


func spawn_evil_ad() -> void:
	Audio.play_music("music_evil_ad", 0.5)
	run.hud.show_boss("BOSS_EVIL_AD_NAME")
	if run._evil == null or not is_instance_valid(run._evil):
		run._evil = EvilAd.new()
		run._evil.setup(run)
		run._evil.position = run.clamp_to_arena(run.player.position + Vector2(0, -260), 80.0)
		run.enemies.add_child(run._evil)
	add_boss(run._evil)
	run._evil.defeated.connect(evil_end.bind(true))


## Fin del último sueño: Evil Ad cae (o Kroker aguanta) y toca despertar
## End of the last dream: Evil Ad falls (or Kroker holds out) and it's time to wake up
func evil_end(killed: bool) -> void:
	if not run.running:
		return
	run.update_boss_hp()
	run.running = false
	Audio.stop_loops()
	for n: Node in run.get_children():
		if n is AdSpam:
			n.queue_free()
	for e: Node in run.enemies.get_children():
		if not e.is_boss():
			e.die(false)
	run.dream_finished.emit()
	Progress.add_stat("dreams")
	run._settle_deal()
	if killed:
		Progress.flag("evil_ad")
	GameState.saved_hp = run.player.hp
	Progress.save_progress()
	Audio.fade_music(-30.0, 1.5)
	Audio.play("act_clear", -1.0)
	run.hud.hide_boss()
	run.hud.banner("ACT4_CLEAR_TITLE", "EVIL_AD_KILLED_SUB" if killed else "EVIL_AD_SURVIVED_SUB")
	for s in run.get_tree().get_nodes_in_group("shards"):
		s.set("_magnet", true)
	run.get_tree().create_timer(3.6, false).timeout.connect(run._resolve_level_ups.bind(run._after_dream))


## Fin del Acto 3: el sueño sigue y Kroker cae en la Metrópolis (Acto 4)
## End of Act 3: the dream goes on and Kroker falls into the Metropolis (Act 4)
func ufo_end(killed: bool) -> void:
	if not run.running:
		return
	run.update_boss_hp()
	run.running = false
	Audio.stop_loops()
	for e: Node in run.enemies.get_children():
		if not e.is_boss():
			e.die(false)
	run.dream_finished.emit()
	Progress.clear_act(GameState.selected_character, GameState.difficulty, 3)
	if GameState.run_hits == 0 and not (GameState.god_mode and GameState.god_invuln):
		Progress.flag("no_hit")
	Progress.add_stat("dreams")
	Audio.fade_music(-30.0, 1.5)
	Audio.play("act_clear", -1.0)
	GameState.saved_hp = run.player.hp
	Progress.save_progress()
	run.hud.hide_boss()
	run.hud.banner("ACT3_CLEAR_TITLE", "BOSS_KILLED_SUB" if killed else "BOSS_SURVIVED_SUB")
	if killed:
		boss_bonus()
	for s in run.get_tree().get_nodes_in_group("shards"):
		s.set("_magnet", true)
	run.get_tree().create_timer(3.4, false).timeout.connect(run._resolve_level_ups.bind(run._flash_to_astral))


func on_chef_defeated() -> void:
	chef_end(true)


func chef_end(killed: bool) -> void:
	if not run.running:
		return
	run.update_boss_hp()
	run.running = false
	Audio.stop_loops()
	for e: Node in run.enemies.get_children():
		if not e.is_boss():
			e.die(false)
	run.dream_finished.emit()
	Progress.clear_act(GameState.selected_character, GameState.difficulty, 2)
	if GameState.run_hits == 0 and not (GameState.god_mode and GameState.god_invuln):
		Progress.flag("no_hit")
	Progress.add_stat("dreams")
	Audio.fade_music(-30.0, 1.5)
	Audio.play("act_clear", -1.0)
	# El sueño sigue: Kroker elige una segunda arma y cae en el Acto 3
	# The dream goes on: Kroker picks a second weapon and falls into Act 3
	GameState.saved_hp = run.player.hp
	Progress.save_progress()
	run.hud.hide_boss()
	run.hud.banner("ACT2_CLEAR_TITLE", "BOSS_KILLED_SUB" if killed else "BOSS_SURVIVED_SUB")
	if killed:
		boss_bonus()
	for sh in run.get_tree().get_nodes_in_group("shards"):
		sh.set("_magnet", true)
	run.get_tree().create_timer(3.4, false).timeout.connect(run._choose_second_weapon.bind(run._resolve_level_ups.bind(run._flash_to_astral)))


func on_piece_defeated() -> void:
	if not run.running:
		return
	run.update_boss_hp()
	if run._boss_step >= BossPiece.ORDER.size():
		# Se acaba cuando no queda ningún mueble en pie / It ends when no piece is left standing
		for b in run.bosses:
			if is_instance_valid(b) and float(b.get("_dying")) < 0.0:
				return
		if run.bosses.size() >= BossPiece.ORDER.size():
			run._on_act_cleared()
		return
	# Respiro entre muebles (los enemigos siguen saliendo) / A breather between pieces (enemies keep coming)
	run.get_tree().create_timer(2.0, false).timeout.connect(func() -> void:
		if run.running:
			next_boss_piece())
