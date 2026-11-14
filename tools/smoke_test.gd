extends Node
## Prueba de humo (solo para pruebas): recorre las pantallas del juego que el bot de equilibrio no
## toca y deja que el propio motor diga si algo falla. Carga todos los scripts, abre el menú, los
## ajustes, el plano astral con cada isla, charla, pijama y panel, el modo Dios y el entrenamiento;
## juega unos segundos con cada pijama en sueños distintos y, en cada partida, abre la pausa, sube
## de nivel, abre el kiosco, acaba el sueño, elige mejora en el plano de las mejoras y muere.
## No comprueba que se vea bien: solo que nada lance un error. Se lanza con tools/check.sh, que
## cuenta los «SCRIPT ERROR» del registro.
## Smoke test (testing only): walks the screens the balance bot never touches and lets the engine
## itself say whether something breaks. It loads every script, opens the menu, settings, the astral
## plane with every island, chat, pajama and panel, god mode and training; it plays a few seconds
## with each pajama in different dreams and, in each run, opens the pause, levels up, opens the
## kiosk, ends the dream, picks an upgrade in the upgrade plane and dies. It doesn't check that
## things look right: only that nothing throws. Run it with tools/check.sh, which counts the
## "SCRIPT ERROR" lines in the log.

const WEAPONS: Array[String] = ["bat", "shield", "book", "vacuum", "finger", "teddy", "ball", "laptop", "boots", "druid", "yoyo"]
## Un sueño distinto para cada pijama, para pasar por los cuatro actos, los jefes y el final
## A different dream for each pajama, to go through the four acts, the bosses and the finale
const DEPTHS: Array[int] = [1, 3, 5, 7, 9, 10, 12, 14, 15, 17, 19]
const SPEED := 3.0

var _steps := 0


class DrawProbe extends Node2D:
	var drawn := false
	func _draw() -> void:
		drawn = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = SPEED
	await _go()
	print("SMOKE DONE ", _steps, " steps")
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().quit()


func _step(what: String) -> void:
	_steps += 1
	print("SMOKE ", what)


func _wait(secs: float) -> void:
	# Tiempo de juego, y sigue contando en pausa / Game time, and it keeps counting while paused
	await get_tree().create_timer(secs, true, false, false).timeout


func _press(action: String) -> void:
	for down: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


func _scene() -> Node:
	return get_tree().current_scene


func _go() -> void:
	_step("load every script")
	var files: Array[String] = []
	_walk("res://scripts", files)
	for f in files:
		if load(f) == null:
			push_error("SMOKE: no carga %s" % f)
	Progress.unlock_everything()
	Settings.tips = false
	# ¿Se dibuja de verdad? (sin pantalla, en --headless, puede que no) / Is it really drawing? (--headless may not)
	var probe := DrawProbe.new()
	add_child(probe)
	await _wait(0.5)
	print("SMOKE drawing: ", probe.drawn)
	probe.queue_free()
	await _menu()
	await _hub()
	for i in WEAPONS.size():
		await _run(WEAPONS[i], DEPTHS[i], WEAPONS[(i + 3) % WEAPONS.size()], i)
	await _final_dream()


func _walk(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_walk(dir + "/" + sub, out)


# --- Menú principal y ajustes / Main menu and settings ---

func _menu() -> void:
	_step("main menu")
	GameState.change_scene("res://scenes/main_menu.tscn")
	await _wait(2.5)
	var menu := _scene()
	for m: String in ["_on_achievements", "_on_credits"]:
		_step("menu " + m)
		menu.call(m)
		await _wait(1.0)
		await _press("ui_down")
		await _press("ui_cancel")
		await _wait(0.5)
	_step("settings tabs")
	menu.call("_on_settings")
	await _wait(0.8)
	var settings: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("settings_menu.gd"):
			settings = n
	if settings == null:
		push_error("SMOKE: no se abrieron los ajustes")
	else:
		for t in 4:
			if is_instance_valid(settings):
				settings.call("_show_tab", t)
			await _wait(0.3)
	await _press("ui_cancel")
	await _wait(0.5)


# --- Plano astral: islas, charlas, pijamas, paneles / Astral plane: islands, chats, pajamas, panels ---

func _hub() -> void:
	_step("astral hub")
	GameState.change_scene("res://scenes/astral_hub.tscn")
	await _wait(3.0)
	var hub := _scene()
	var world: Node = hub.get("_world")
	# Pasear por cada isla para que se dibuje / Visit every island so it gets drawn
	for id: String in HubLayout.ISLES:
		_step("island " + id)
		world.set("_pos", world.call("_isle_pos", id) + Vector2(0, 30))
		world.set("_cam", world.get("_pos"))
		await _wait(0.4)
	var spots: Array = (world.get("_spots") as Array).duplicate()
	for spot: Dictionary in spots:
		if spot["kind"] in ["fountain", "training"]:
			continue
		_step("spot %s %s" % [spot["kind"], spot["id"]])
		hub.call("_open", spot)
		await _wait(0.4)
		# Pasar las frases y cerrar / Go through the lines and close
		for k in 3:
			await _press("interact")
		if not (hub.get("_talking") as Dictionary).is_empty():
			hub.call("_close_box")
		if spot["kind"] == "album":
			await _press("ui_cancel")
		await _wait(0.2)
		if _scene() != hub:
			push_error("SMOKE: %s sacó del plano astral" % spot["id"])
			return
	_step("start panel + god panel")
	hub.call("_open_start")
	await _wait(0.6)
	var gp := GodPanel.new()
	gp.weapon = "bat"
	hub.add_child(gp)
	await _wait(0.6)
	gp.close()
	await _wait(0.3)
	hub.call("_close_start")
	_step("training room")
	hub.call("_go_training")
	await _wait(5.0)
	if _scene() is Run:
		await _pause_cycle(_scene())


# --- Partidas / Runs ---

func _start(weapon: String, depth: int, second: String) -> Run:
	GameState.training = false
	GameState.selected_character = weapon
	GameState.god_mode = true
	GameState.god_invuln = true
	GameState.god_depth = depth
	GameState.god_second = second if depth > 10 else ""
	GameState.god_upgrades = {}
	GameState.god_upgrades2 = {}
	var givers: Array = GameState.GIVERS.duplicate()
	for k in 5:
		GameState.god_upgrades[givers[(depth + k * 2) % givers.size()]] = 1 + (depth + k) % 3
	GameState.start_run()
	GameState.change_scene("res://scenes/run.tscn")
	await _wait(3.0)
	var waited := 0.0
	while not (_scene() is Run and (_scene() as Run).running) and waited < 40.0:
		# Saltar charlas y cinemáticas / Skip chats and cutscenes
		await _press("ui_accept")
		await _wait(0.5)
		waited += 0.5
	return _scene() as Run


func _pause_cycle(run: Run) -> void:
	_step("pause")
	run.call("_open_pause")
	await _wait(0.6)
	run.call("_open_settings")
	await _wait(0.5)
	await _press("ui_cancel")
	await _wait(0.3)
	run.call("_resume")
	await _wait(0.3)


func _run(weapon: String, depth: int, second: String, i: int) -> void:
	_step("run %s dream %d" % [weapon, depth])
	var run := await _start(weapon, depth, second)
	if run == null or not run.running:
		push_error("SMOKE: el sueño %d con %s no arrancó" % [depth, weapon])
		return
	await _wait(6.0)
	await _pause_cycle(run)
	# Subida de nivel / Level-up
	_step("level up")
	GameState.pending_ups = 1
	run.call("_resolve_level_ups", Callable())
	await _wait(0.8)
	await _press("ui_accept")
	await _wait(0.6)
	get_tree().paused = false
	# Kiosco de Charo / Charo's kiosk
	if i % 3 == 1:
		_step("kiosk")
		run.get("_kiosk").call("shop", func() -> void: pass)
		await _wait(1.2)
		await _press("ui_accept")
		await _press("ui_cancel")
		await _wait(0.6)
		get_tree().paused = false
	await _wait(3.0)
	if i % 2 == 0 and not (run.get("_wave") as Dictionary).has("boss"):
		# Acabar el sueño y elegir mejora / End the dream and pick an upgrade
		_step("wave cleared → upgrade plane")
		run.call("_on_wave_cleared")
		var waited := 0.0
		while _scene() == run and waited < 30.0:
			await _press("ui_accept")
			await _wait(0.5)
			waited += 0.5
		await _wait(2.5)
		for k in 12:
			await _press("ui_accept")
			await _wait(0.4)
			if _scene() is Run:
				break
		await _wait(1.0)
	else:
		# Morir: pantalla de despertar / Die: the wake-up screen
		_step("death")
		GameState.god_invuln = false
		run.player.hp = 0.5
		run.player.take_damage(999.0)
		await _wait(4.0)
		for k in 6:
			await _press("ui_accept")
			await _wait(0.4)
	get_tree().paused = false


## El sueño 20: la cinemática noir y Evil Ad / Dream 20: the noir cutscene and Evil Ad
func _final_dream() -> void:
	_step("final dream")
	var run := await _start("bat", 20, "book")
	if run:
		await _wait(8.0)
		await _pause_cycle(run)
