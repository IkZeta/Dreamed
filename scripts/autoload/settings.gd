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


## Color de los avisos de peligro (trayectorias, zonas de caída)
## Colour of danger warnings (trajectories, landing zones)
func warning_color() -> Color:
	return Color("ffd23a") if colorblind else Color("ff6f86")


## Controles de movimiento: WASD, flechas y mando. / Movement: WASD, arrows and gamepad.
func _ensure_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT, JOY_AXIS_LEFT_X, -1.0],
		"move_right": [KEY_D, KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0],
		"move_up": [KEY_W, KEY_UP, JOY_AXIS_LEFT_Y, -1.0],
		"move_down": [KEY_S, KEY_DOWN, JOY_AXIS_LEFT_Y, 1.0],
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
		j.axis = def[2]
		j.axis_value = def[3]
		InputMap.action_add_event(action, j)
	if not InputMap.has_action("special"):
		InputMap.add_action("special")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_E
		InputMap.action_add_event("special", e)
		var y := InputEventJoypadButton.new()
		y.button_index = JOY_BUTTON_Y
		InputMap.action_add_event("special", y)
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var esc := InputEventKey.new()
		esc.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", esc)
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		InputMap.action_add_event("pause", start)


func _ensure_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
