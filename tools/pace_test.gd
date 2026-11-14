extends Node
## Ritmo de una primera partida (solo para pruebas): con un guardado vacío, un jugador que no se
## mueve (inmortal) y pulsa aceptar cada 0,3 s cuando no hay combate. Escribe «PACE fase segundos»
## por cada tramo (menú, plano astral, llegada, combate, salida, elecciones) y el total, para ver
## cuánto se espera sin poder hacer nada. Como el bot: autoload temporal y carpeta de guardado
## aparte:
##   P="*res://tools/pace_test.gd"  en [autoload] de project.godot (sin commitear)
##   XDG_DATA_HOME=/tmp/vacio godot --headless --path . -- --depth=6
## Pace of a first run (testing only): with an empty save, a player who stands still (immortal)
## and presses accept every 0.3 s when there's no fight. Prints "PACE phase seconds" per stretch
## (menu, astral plane, arrival, fight, exit, choices) and the total, to see how much is spent
## waiting with nothing to do. Like the bot: a temporary autoload and its own save folder.
const SPEED := 4.0
var _t := 0.0
var _state := ""
var _since := 0.0
var _log: Array = []
var _accept_t := 0.0
var _max_depth := 6
var _started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = SPEED
	Engine.physics_ticks_per_second = int(60.0 * SPEED)
	Engine.max_physics_steps_per_frame = int(8.0 * SPEED)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--depth="):
			_max_depth = int(a.split("=")[1])

func _state_now() -> String:
	var sc := get_tree().current_scene
	if sc == null:
		return "loading"
	if sc is Run:
		var run := sc as Run
		var d := "d%d " % GameState.dream_depth
		if get_tree().paused:
			return d + "choice/paused"
		if run.running:
			return d + "FIGHT"
		return d + ("intro" if GameState.run_time < 0.5 or not _fought.has(GameState.dream_depth) else "outro")
	return String(sc.name)

var _fought := {}

func _process(delta: float) -> void:
	if Engine.time_scale != SPEED and Engine.time_scale >= 0.9:
		Engine.time_scale = SPEED
	_t += delta
	var sc := get_tree().current_scene
	var st := _state_now()
	if sc is Run and (sc as Run).running:
		_fought[GameState.dream_depth] = true
		GameState.bot_immortal = true
	if st != _state:
		if _state != "":
			_log.append([_state, _t - _since])
			print("PACE %-22s %6.1f s" % [_state, _t - _since])
		_state = st
		_since = _t
	if sc is Run and GameState.dream_depth > _max_depth:
		_finish()
		return
	# Fuera del combate: aceptar en cuanto se pueda / Out of combat: accept as soon as possible
	if not st.ends_with("FIGHT"):
		_accept_t -= delta
		if _accept_t <= 0.0:
			_accept_t = 0.3
			_drive(sc)

func _drive(sc: Node) -> void:
	if sc == null:
		return
	if sc.name == "MainMenu" and not _started:
		if _t > 1.5:
			_started = true
			sc.call("_on_play")
		return
	if String(sc.get_script().resource_path).ends_with("astral_hub.gd"):
		if sc.get("_start_panel") == null and not sc.get("_leaving"):
			sc.call("_open_start")
		elif not sc.get("_leaving"):
			sc.call("_start_dream")
		return
	for a: String in ["ui_accept", "interact"]:
		var ev := InputEventAction.new()
		ev.action = a
		ev.pressed = true
		Input.parse_input_event(ev)
		var up := InputEventAction.new()
		up.action = a
		up.pressed = false
		Input.parse_input_event(up)

func _finish() -> void:
	set_process(false)
	var sum := {}
	for e: Array in _log:
		var key: String = e[0]
		var kind := key.split(" ")[-1] if key.begins_with("d") else key
		sum[kind] = float(sum.get(kind, 0.0)) + float(e[1])
	print("PACE TOTAL ", sum)
	print("PACE fight=", GameState.run_time, " choose=", GameState.choose_time)
	get_tree().quit()
