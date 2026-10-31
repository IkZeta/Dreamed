extends Node
## Guarda, carga y aplica los ajustes del jugador (user://settings.cfg).
## Saves, loads and applies player settings.

const PATH := "user://settings.cfg"
const BUSES: Array[String] = ["Master", "Music", "SFX"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440),
]
const FPS_OPTIONS: Array[int] = [0, 30, 60, 120, 144]  # 0 = sin límite / unlimited

enum WindowMode { WINDOWED, FULLSCREEN, EXCLUSIVE }

var volumes := {"Master": 0.8, "Music": 0.7, "SFX": 0.8}
var muted := false
var locale := "es"
var window_mode: int = WindowMode.WINDOWED
var resolution_index := 1
var vsync := true
var fps_index := 0
var screen_shake := true
var shake_amount := 1.0       # 0..1, fuerza de la sacudida / shake strength
var colorblind := false       # avisos en amarillo en vez de rojo / warnings in yellow instead of red
var damage_numbers := true    # números de daño sobre los enemigos / damage numbers above enemies
var vibration := true         # vibración del mando / gamepad rumble


## --- Teclado y ratón o mando / Keyboard & mouse or gamepad ------------------------------
## Se cambia sola según lo último que se ha tocado; la interfaz enseña los controles de ese.
## It switches by itself depending on what was touched last; the UI shows that device's controls.
signal input_device_changed(pad: bool)
var using_pad := false


func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		pad = true
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		pad = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 6.0:
		pad = false
	if pad != using_pad:
		using_pad = pad
		# Con mando se esconde el puntero / With a gamepad the pointer hides
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if pad else Input.MOUSE_MODE_VISIBLE
		input_device_changed.emit(pad)


## Nombre del botón o tecla de una acción para el dispositivo en uso
## Name of an action's button or key for the device in use
func control_name(what: String) -> String:
	if not using_pad:
		return tr("CTRL_KB_" + what.to_upper())
	var joy := Input.get_joy_name(0).to_lower() if not Input.get_connected_joypads().is_empty() else ""
	var family := "XBOX"
	if "ps" in joy or "dualshock" in joy or "dualsense" in joy or "sony" in joy or "playstation" in joy:
		family = "PS"
	elif "nintendo" in joy or "switch" in joy or "joy-con" in joy:
		family = "NIN"
	var key := "CTRL_PAD_%s_%s" % [family, what.to_upper()]
	return tr(key) if tr(key) != key else tr("CTRL_PAD_" + what.to_upper())


## Cambia {move}, {pause}, {special}, {accept} y {back} por los controles del dispositivo en uso
## Replaces {move}, {pause}, {special}, {accept} and {back} with the controls of the device in use
func controls_text(text: String) -> String:
	if not "{" in text:
		return text
	for what in ["move", "pause", "special", "accept", "back"]:
		text = text.replace("{%s}" % what, control_name(what))
	return text


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_ensure_input()
	reset_defaults(false)
	load_settings()
	apply_all()


func reset_defaults(apply := true) -> void:
	volumes = {"Master": 0.8, "Music": 0.7, "SFX": 0.8}
	muted = false
	locale = "es" if OS.get_locale_language() == "es" else "en"
	window_mode = WindowMode.WINDOWED
	resolution_index = 1
	vsync = true
	fps_index = 0
	screen_shake = true
	shake_amount = 1.0
	colorblind = false
	damage_numbers = true
	vibration = true
	if apply:
		apply_all()


# --- Aplicar / Apply -------------------------------------------------------

func apply_all() -> void:
	apply_audio()
	apply_locale()
	apply_display()


func apply_audio() -> void:
	for bus: String in BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx == -1:
			continue
		var v: float = volumes[bus]
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.0)
	AudioServer.set_bus_mute(0, muted or float(volumes["Master"]) <= 0.0)


func apply_locale() -> void:
	TranslationServer.set_locale(locale)


func apply_display() -> void:
	Engine.max_fps = FPS_OPTIONS[fps_index]
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var win_size := RESOLUTIONS[resolution_index]
			var screen := DisplayServer.window_get_current_screen()
			var usable := DisplayServer.screen_get_usable_rect(screen)
			win_size = Vector2i(mini(win_size.x, usable.size.x), mini(win_size.y, usable.size.y))
			DisplayServer.window_set_size(win_size)
			DisplayServer.window_set_position(usable.position + (usable.size - win_size) / 2)


# --- Setters usados por el menú / Setters used by the menu ------------------

func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply_audio()


func set_muted(on: bool) -> void:
	muted = on
	apply_audio()


func set_locale(code: String) -> void:
	locale = code
	apply_locale()


# --- Guardar / Save ---------------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus: String in BUSES:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("general", "locale", locale)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "fps_index", fps_index)
	cfg.set_value("display", "screen_shake", screen_shake)
	cfg.set_value("access", "shake_amount", shake_amount)
	cfg.set_value("access", "colorblind", colorblind)
	cfg.set_value("access", "damage_numbers", damage_numbers)
	cfg.set_value("access", "vibration", vibration)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for bus: String in BUSES:
		volumes[bus] = float(cfg.get_value("audio", bus, volumes[bus]))
	muted = bool(cfg.get_value("audio", "muted", muted))
	locale = str(cfg.get_value("general", "locale", locale))
	window_mode = int(cfg.get_value("display", "window_mode", window_mode))
	resolution_index = clampi(int(cfg.get_value("display", "resolution_index", resolution_index)), 0, RESOLUTIONS.size() - 1)
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	fps_index = clampi(int(cfg.get_value("display", "fps_index", fps_index)), 0, FPS_OPTIONS.size() - 1)
	screen_shake = bool(cfg.get_value("display", "screen_shake", screen_shake))
	shake_amount = clampf(float(cfg.get_value("access", "shake_amount", 1.0 if screen_shake else 0.0)), 0.0, 1.0)
	colorblind = bool(cfg.get_value("access", "colorblind", colorblind))
	damage_numbers = bool(cfg.get_value("access", "damage_numbers", damage_numbers))
	vibration = bool(cfg.get_value("access", "vibration", vibration))


## Vibra el mando si hay alguno conectado / Rumbles the gamepad if one is connected
func rumble(weak: float, strong: float, secs: float) -> void:
	if not vibration:
		return
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, weak, strong, secs)


## Color de los avisos de peligro (trayectorias, zonas de caída)
## Colour of danger warnings (trajectories, landing zones)
func warning_color() -> Color:
	return Color("ffd23a") if colorblind else Color("ff6f86")


## Controles de movimiento: WASD, flechas y mando. / Movement: WASD, arrows and gamepad.
func _ensure_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT, JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
		"move_right": [KEY_D, KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
		"move_up": [KEY_W, KEY_UP, JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
		"move_down": [KEY_S, KEY_DOWN, JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		var def: Array = map[action]
		for i in 2:
			var k := InputEventKey.new()
			k.physical_keycode = def[i]
			InputMap.action_add_event(action, k)
		var j := InputEventJoypadMotion.new()
		j.device = -1
		j.axis = def[2]
		j.axis_value = def[3]
		InputMap.action_add_event(action, j)
		# Cruceta del mando / Gamepad d-pad
		var d := InputEventJoypadButton.new()
		d.device = -1
		d.button_index = def[4]
		InputMap.action_add_event(action, d)
	if not InputMap.has_action("special"):
		InputMap.add_action("special")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_E
		InputMap.action_add_event("special", e)
		var y := InputEventJoypadButton.new()
		y.device = -1
		y.button_index = JOY_BUTTON_Y
		InputMap.action_add_event("special", y)
	# Aceptar con A y volver con B (Godot no los trae puestos) / Accept with A and go back with B (Godot doesn't set them)
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var has := false
		for ev in InputMap.action_get_events(pair[0]):
			if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == pair[1]:
				has = true
		if not has:
			var jb := InputEventJoypadButton.new()
			jb.button_index = pair[1]
			jb.device = -1
			InputMap.action_add_event(pair[0], jb)
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var esc := InputEventKey.new()
		esc.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", esc)
		var start := InputEventJoypadButton.new()
		start.device = -1
		start.button_index = JOY_BUTTON_START
		InputMap.action_add_event("pause", start)


func _ensure_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
