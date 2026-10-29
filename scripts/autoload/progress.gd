extends Node
## Progreso que se guarda entre partidas (user://progress.cfg): enemigos vistos y
## derrotados (bestiario) y actos superados con cada arma en cada dificultad.
## Progress saved between runs (user://progress.cfg): enemies seen and defeated
## (bestiary) and acts cleared with each weapon on each difficulty.

const PATH := "user://progress.cfg"

## Entradas del bestiario en orden / Bestiary entries in order
const BESTIARY: Array[String] = ["foox", "thug", "sling", "skeleton", "nest", "mosquito", "golden_foox", "elite", "boss_bed", "boss_shelf", "boss_chest"]
const DIFFICULTIES: Array[String] = ["normal", "nightmare"]

## id → veces derrotado (si aparece aquí, ya se ha visto) / id → times defeated (present = seen)
var kills := {}
## arma → {dificultad: true} / weapon → {difficulty: true}
var cleared := {}
## Contadores para los logros / Counters for achievements
var stats := {}
## Logros conseguidos: id → true / Unlocked achievements: id → true
var achieved := {}

## Logros: "stat" + "goal" se cuentan solos; "check" es una comprobación especial.
## "drawing" es el dibujo que aparece en la pared de la habitación al conseguirlo.
## Achievements: "stat" + "goal" count by themselves; "check" is a special test.
## "drawing" is the drawing that appears on the bedroom wall once unlocked.
const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "first_dream", "stat": "dreams", "goal": 1, "drawing": "foox"},
	{"id": "act1", "check": "act1", "goal": 1, "drawing": "bed"},
	{"id": "nightmare", "check": "nightmare", "goal": 1, "drawing": "moon"},
	{"id": "all_pajamas", "check": "all_pajamas", "goal": 4},
	{"id": "no_hit", "flag": true, "goal": 1},
	{"id": "void", "stat": "falls", "goal": 50},
	{"id": "golden", "stat": "golden", "goal": 10, "drawing": "golden"},
	{"id": "elites", "stat": "elites", "goal": 25},
	{"id": "kills", "stat": "kills", "goal": 500},
	{"id": "level10", "stat": "best_level", "goal": 10},
	{"id": "max_gift", "flag": true, "goal": 1},
	{"id": "bestiary", "check": "bestiary", "goal": 1, "drawing": "star"},
]

## Aviso de logro en pantalla / On-screen achievement notice
var _toast: CanvasLayer


func _ready() -> void:
	load_progress()


func see(id: String) -> void:
	if id != "" and not kills.has(id):
		kills[id] = 0
		check_achievements()
		save_progress()


func kill(id: String) -> void:
	if id == "":
		return
	kills[id] = int(kills.get(id, 0)) + 1


func has_seen(id: String) -> bool:
	return kills.has(id)


func clear_act(weapon: String, difficulty: String) -> void:
	if not cleared.has(weapon):
		cleared[weapon] = {}
	cleared[weapon][difficulty] = true
	check_achievements()
	save_progress()


func has_cleared(weapon: String, difficulty: String) -> bool:
	return bool(cleared.get(weapon, {}).get(difficulty, false))


## ¿Se ha superado el Acto 1 con cualquier arma? (desbloquea la pesadilla)
## Has Act 1 been cleared with any weapon? (unlocks nightmare)
func any_cleared() -> bool:
	for w: String in cleared:
		if has_cleared(w, "normal"):
			return true
	return false


# --- Logros / Achievements -----------------------------------------------------

func add_stat(id: String, n := 1) -> void:
	stats[id] = int(stats.get(id, 0)) + n
	check_achievements()


## Guarda el mejor valor (p. ej. el nivel más alto) / Keeps the best value (e.g. the highest level)
func best_stat(id: String, value: int) -> void:
	if value > int(stats.get(id, 0)):
		stats[id] = value
		check_achievements()


## Logros que se consiguen de golpe (sin contador) / Achievements earned in one go (no counter)
func flag(id: String) -> void:
	_unlock(id)


func has_achieved(id: String) -> bool:
	return bool(achieved.get(id, false))


## Progreso de un logro: [valor, objetivo] / An achievement's progress: [value, goal]
func achievement_progress(a: Dictionary) -> Array:
	var goal := int(a["goal"])
	if has_achieved(a["id"]):
		return [goal, goal]
	if a.has("stat"):
		return [mini(int(stats.get(a["stat"], 0)), goal), goal]
	match a.get("check", ""):
		"act1":
			return [1 if any_cleared() else 0, 1]
		"nightmare":
			for w: String in cleared:
				if has_cleared(w, "nightmare"):
					return [1, 1]
			return [0, 1]
		"all_pajamas":
			var n := 0
			for w in ["bat", "shield", "book", "vacuum"]:
				if has_cleared(w, "normal") or has_cleared(w, "nightmare"):
					n += 1
			return [n, goal]
		"bestiary":
			for id in BESTIARY:
				if not has_seen(id):
					return [0, 1]
			return [1, 1]
	return [0, goal]


func check_achievements() -> void:
	for a in ACHIEVEMENTS:
		if has_achieved(a["id"]) or a.get("flag", false):
			continue
		var p := achievement_progress(a)
		if int(p[0]) >= int(p[1]):
			_unlock(a["id"])


func _unlock(id: String) -> void:
	if has_achieved(id):
		return
	achieved[id] = true
	save_progress()
	_show_toast(id)


## Cartelito de «¡Logro conseguido!» arriba a la derecha / "Achievement unlocked!" note at the top right
func _show_toast(id: String) -> void:
	if _toast == null:
		_toast = CanvasLayer.new()
		_toast.layer = 40
		_toast.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_toast)
	var box := PanelContainer.new()
	box.theme = UITheme.build()
	box.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.95), Color(UITheme.GOLD, 0.8), Color(UITheme.GOLD, 0.2), 16, 12, 22))
	_toast.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -40
	box.offset_top = 150 + 110 * (_toast.get_child_count() - 1)
	var v := VBoxContainer.new()
	box.add_child(v)
	v.add_child(UITheme.label("ACH_UNLOCKED", 24, UITheme.GOLD, "caps"))
	v.add_child(UITheme.label("ACH_%s_NAME" % id.to_upper(), 24, UITheme.BONE, "body"))
	Audio.play("chime", -2.0)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bestiary", "kills", kills)
	cfg.set_value("acts", "cleared", cleared)
	cfg.set_value("achievements", "stats", stats)
	cfg.set_value("achievements", "achieved", achieved)
	cfg.save(PATH)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	kills = cfg.get_value("bestiary", "kills", {})
	cleared = cfg.get_value("acts", "cleared", {})
	stats = cfg.get_value("achievements", "stats", {})
	achieved = cfg.get_value("achievements", "achieved", {})
