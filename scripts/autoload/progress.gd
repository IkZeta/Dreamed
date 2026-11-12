extends Node
## Progreso que se guarda entre partidas (user://progress.cfg): enemigos vistos y
## derrotados (bestiario) y actos superados con cada arma en cada dificultad.
## Progress saved between runs (user://progress.cfg): enemies seen and defeated
## (bestiary) and acts cleared with each weapon on each difficulty.

const PATH := "user://progress.cfg"

## Entradas del bestiario en orden / Bestiary entries in order
const BESTIARY: Array[String] = ["foox", "thug", "sling", "skeleton", "nest", "mosquito", "botcher", "cyber", "puppet", "golem", "police", "van", "riot", "alarm", "exam", "dreamcatcher", "golden_foox", "elite", "boss_bed", "boss_shelf", "boss_chest", "boss_chef", "boss_ufo", "boss_evil_ad"]

## id → veces derrotado (si aparece aquí, ya se ha visto) / id → times defeated (present = seen)
var kills := {}
## arma → {dificultad: true} / weapon → {difficulty: true}
var cleared := {}
## Contadores para los logros / Counters for achievements
var stats := {}
## Logros conseguidos: id → true / Unlocked achievements: id → true
var achieved := {}
## Amistad con los personajes (se mantiene entre partidas): id → nivel 0..5
## Friendship with the characters (kept between runs): id → level 0..5
var friendship := {}
const FRIEND_MAX := 5

## Logros: "stat" + "goal" se cuentan solos; "check" es una comprobación especial.
## "drawing" es el dibujo que aparece en la pared de un escenario al conseguirlo (cada escenario
## decide dónde cuelga los suyos: Bedroom/LivingRoom/Act3Room.drawing_slots()).
## Achievements: "stat" + "goal" count by themselves; "check" is a special test.
## "drawing" is the drawing that appears on a stage wall once unlocked (each stage decides where
## its own hang: Bedroom/LivingRoom/Act3Room.drawing_slots()).
const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "first_dream", "stat": "dreams", "goal": 1, "drawing": "foox"},
	{"id": "act1", "check": "act1", "goal": 1, "drawing": "bed"},
	{"id": "nightmare", "check": "nightmare", "goal": 1, "drawing": "moon"},
	{"id": "all_pajamas", "check": "all_pajamas", "goal": 4, "drawing": "pajamas"},
	{"id": "no_hit", "flag": true, "goal": 1, "drawing": "no_hit"},
	{"id": "void", "stat": "falls", "goal": 50, "drawing": "void"},
	{"id": "golden", "stat": "golden", "goal": 10, "drawing": "golden"},
	{"id": "elites", "stat": "elites", "goal": 25, "drawing": "elites"},
	{"id": "kills", "stat": "kills", "goal": 500, "drawing": "kills"},
	{"id": "level10", "stat": "best_level", "goal": 10, "drawing": "level10"},
	{"id": "max_gift", "flag": true, "goal": 1, "drawing": "gift"},
	{"id": "bestiary", "check": "bestiary", "goal": 1, "drawing": "star"},
	{"id": "mr_ad", "flag": true, "goal": 1, "drawing": "mr_ad"},
	{"id": "chef", "check": "act2", "goal": 1, "drawing": "chef"},
	{"id": "two_weapons", "flag": true, "goal": 1, "drawing": "two_weapons"},
	{"id": "shopper", "stat": "bought", "goal": 10, "drawing": "shopper"},
	{"id": "pyro", "stat": "sacrifices", "goal": 5, "drawing": "pyro"},
	{"id": "saver", "stat": "best_reality", "goal": 100, "drawing": "coin"},
	# Pijamas y personajes nuevos que se desbloquean al llegar a cada acto
	# New pajamas and characters unlocked on reaching each act
	{"id": "finger", "flag": true, "goal": 1, "drawing": "finger"},
	{"id": "teddy", "flag": true, "goal": 1, "drawing": "teddy"},
	{"id": "pinche", "flag": true, "goal": 1, "drawing": "pinche"},
	# La pelota: amistad 4 con Svinho / The ball: friendship 4 with Svinho
	{"id": "ball", "check": "svinho4", "goal": 4, "drawing": "ball"},
	# Magnus: superar el Acto 3 / Magnus: clear Act 3
	{"id": "magnus", "check": "act3", "goal": 1, "drawing": "magnus"},
	# El portátil: amistad 4 con Silly / The laptop: friendship 4 with Silly
	{"id": "laptop", "check": "silly4", "goal": 4, "drawing": "laptop"},
	# Las botas steampunk: amistad 4 con Doc / The steampunk boots: friendship 4 with Doc
	{"id": "boots", "check": "doc4", "goal": 4, "drawing": "boots"},
	# El collar de druida: llegar a nivel 20 en una partida / The druid collar: reach level 20 in a run
	{"id": "druid", "stat": "best_level", "goal": 20},
	# El yoyó: tirar 5 enemigos seguidos por los agujeros / The yo-yo: send 5 enemies down the holes in a row
	{"id": "yoyo", "stat": "fall_chain", "goal": 5},
	# SuperK: tumbar los tres muebles a la vez en pesadilla (no vale aguantar hasta el final)
	# SuperK: knock out all three pieces at once on nightmare (holding out till the end doesn't count)
	{"id": "superk", "flag": true, "goal": 1, "drawing": "superk"},
	# Lil Key: ponerle a Kroker las gafas de sol de la taquilla del colegio
	# Lil Key: put the sunglasses from the school locker on Kroker
	{"id": "lilkey", "flag": true, "goal": 1, "drawing": "lilkey"},
	# Superar el Acto 4: el final de la partida / Clear Act 4: the end of the run
	{"id": "act4", "check": "act4", "goal": 1},
	{"id": "evil_ad", "flag": true, "goal": 1},
	{"id": "lynx", "flag": true, "goal": 1},
	# Luna: tirar 150 enemigos por los agujeros, sumando partidas / Luna: send 150 enemies down holes, across runs
	{"id": "luna", "stat": "falls", "goal": 150},
	{"id": "duo", "flag": true, "goal": 1},
	{"id": "legend", "flag": true, "goal": 1},
	# Fiebre y sueño del día / Fever and the daily dream
	{"id": "fever", "flag": true, "goal": 1},
	{"id": "delirium", "flag": true, "goal": 1},
	{"id": "daily", "flag": true, "goal": 1},
	# Agujeros: romper torretas del Chapuzas y tirar enemigos en los Bostezos
	# Holes: break Botcher turrets and throw enemies down Yawns
	{"id": "turrets", "stat": "turrets", "goal": 15},
	{"id": "yawn", "stat": "yawn_falls", "goal": 10},
	{"id": "snatch", "stat": "druid_snatch", "goal": 25},
	{"id": "ambush", "stat": "druid_ambush", "goal": 40},
	{"id": "fur", "stat": "druid_guard", "goal": 30},
]
## Amistad que desbloquea la pelota (Svinho) y el portátil (Silly) / Friendship that unlocks the ball (Svinho) and the laptop (Silly)
const BALL_FRIEND := 4

## Aviso de logro en pantalla / On-screen achievement notice
var _toast: CanvasLayer


func _ready() -> void:
	load_progress()
	_skip_known_tips()


## Los consejos solo salen la primera vez que hacen falta: si en partidas anteriores ya te ha
## pasado (ya has cogido trozos, tirado enemigos por agujeros, visto élites...), no salen.
## Tips only show the first time they're needed: if it already happened in earlier runs (you've
## picked up shards, pushed enemies down holes, seen elites...), they don't show.
func _skip_known_tips() -> void:
	var known := {
		"move": int(stats.get("dreams", 0)) > 0,
		"shard": int(stats.get("dreams", 0)) > 0,
		"hole": int(stats.get("falls", 0)) > 0,
		"elite": has_seen("elite"),
		"bleed": has_seen("puppet") or has_seen("police") or has_seen("boss_chef"),
		"reality": stats.has("charo_met"),
		"boss": has_seen("boss_bed") or has_seen("boss_shelf") or has_seen("boss_chest"),
	}
	for id: String in known:
		if known[id]:
			stats["tip_" + id] = 1


## Álbum de pegatinas del diario: combos descubiertos, dúos y legendarias conseguidos. true si es nueva
## The diary's sticker album: combos discovered, duos and legendaries obtained. true if it's new
func sticker(kind: String, id: String) -> bool:
	var key := "%s_%s" % [kind, id]
	if int(stats.get(key, 0)) > 0:
		return false
	stats[key] = 1
	save_progress()
	return true


func has_sticker(kind: String, id: String) -> bool:
	return int(stats.get("%s_%s" % [kind, id], 0)) > 0


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


## Acto superado con un pijama. El Acto 1 se guarda como "normal"/"nightmare" y el 2 como "normal_act2"...
## Act cleared with a pajama. Act 1 is stored as "normal"/"nightmare", Act 2 as "normal_act2"...
func clear_act(weapon: String, difficulty: String, act := 1) -> void:
	if not cleared.has(weapon):
		cleared[weapon] = {}
	cleared[weapon][_act_key(difficulty, act)] = true
	_record_fever(weapon, act)
	# Superarlo en pesadilla también cuenta como superado en normal / Clearing it on nightmare also counts as normal
	if difficulty == "nightmare":
		cleared[weapon][_act_key("normal", act)] = true
	check_achievements()
	save_progress()


## Fiebre más alta con la que se ha superado un acto (por pijama y en total)
## Highest fever an act has been cleared with (per pajama and overall)
func _record_fever(weapon: String, act: int) -> void:
	var f := GameState.fever()
	if f <= 0 or GameState.god_mode:
		return
	stats["fever_" + weapon] = maxi(int(stats.get("fever_" + weapon, 0)), f)
	stats["fever_best"] = maxi(int(stats.get("fever_best", 0)), f)
	if f >= 5:
		_unlock("fever")
	if act >= 4 and f >= 8:
		_unlock("delirium")


func best_fever(weapon: String) -> int:
	return int(stats.get("fever_" + weapon, 0))


## Resumen de la última partida, para que los del plano astral comenten qué tal fue
## Summary of the last run, so the astral plane folks can comment on how it went
func record_last_run(won: bool) -> void:
	var prev: Dictionary = stats.get("last_run", {})
	stats["last_run"] = {
		"n": int(prev.get("n", 0)) + 1, "won": won, "depth": GameState.dream_depth,
		"falls": GameState.run_falls, "killer": GameState.last_hit, "fever": GameState.fever(),
		"weapon": GameState.selected_character,
	}
	save_progress()


## Qué comentario toca sobre la última partida ("" si ya lo ha dicho) / Which comment about the
## last run is due ("" if they've already said it)
func run_reaction(id: String) -> String:
	var last: Dictionary = stats.get("last_run", {})
	if last.is_empty() or int(stats.get("reacted_" + id, 0)) >= int(last["n"]):
		return ""
	stats["reacted_" + id] = int(last["n"])
	var cat := "loss"
	if bool(last["won"]):
		cat = "won"
	elif int(last["falls"]) >= 25:
		cat = "falls"
	elif int(last["depth"]) <= 3:
		cat = "early"
	elif int(last["depth"]) >= 11:
		cat = "deep"
	var key := "REACT_%s_%s" % [id.to_upper(), cat.to_upper()]
	if tr(key) == key:
		key = "REACT_" + cat.to_upper()
	var text := tr(key)
	if "%s" in text:
		var killer := str(last.get("killer", ""))
		var who := tr("BEST_%s_NAME" % killer.to_upper()) if killer != "" else ""
		if killer == "bleed":
			who = tr("REACT_BLEEDING")
		elif who == "" or who.begins_with("BEST_"):
			who = tr("REACT_SOMETHING")
		text = text % who
		# Si la frase empieza por el nombre, en mayúscula / If the line starts with the name, capitalise it
		if text.length() > 1 and text[0] in ["«", "“"]:
			text = text[0] + text[1].to_upper() + text.substr(2)
	text = text.replace("{depth}", str(int(last["depth"])))
	return text


## Mejor sueño alcanzado en el sueño del día de hoy / Best dream reached in today's daily dream
func record_daily(date: String, depth: int) -> void:
	if date == "":
		return
	if str(stats.get("daily_date", "")) != date:
		stats["daily_date"] = date
		stats["daily_best"] = 0
	stats["daily_best"] = maxi(int(stats["daily_best"]), depth)
	add_stat("dailies")
	if depth >= 10:
		_unlock("daily")
	save_progress()


func daily_best(date: String) -> int:
	return int(stats.get("daily_best", 0)) if str(stats.get("daily_date", "")) == date else 0


func has_cleared(weapon: String, difficulty: String, act := 1) -> bool:
	var c: Dictionary = cleared.get(weapon, {})
	if difficulty == "normal" and bool(c.get(_act_key("nightmare", act), false)):
		return true   # partidas guardadas de antes / saves from before
	return bool(c.get(_act_key(difficulty, act), false))


func _act_key(difficulty: String, act: int) -> String:
	return difficulty if act <= 1 else "%s_act%d" % [difficulty, act]


## ¿Se ha superado el Acto 1 con cualquier arma? (desbloquea la pesadilla)
## Has Act 1 been cleared with any weapon? (unlocks nightmare)
func any_cleared() -> bool:
	if stats.has("unlock_all"):
		return true   # desbloquear todo también abre la pesadilla / unlocking everything also opens nightmare
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
		"act2":
			for w: String in cleared:
				if has_cleared(w, "normal", 2) or has_cleared(w, "nightmare", 2):
					return [1, 1]
			return [0, 1]
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
		"act3":
			for w: String in cleared:
				if has_cleared(w, "normal", 3):
					return [1, 1]
			return [0, 1]
		"act4":
			for w: String in cleared:
				if has_cleared(w, "normal", 4):
					return [1, 1]
			return [0, 1]
		"silly4":
			return [mini(friend_level("silly"), BALL_FRIEND), BALL_FRIEND]
		"svinho4":
			return [mini(friend_level("svinho"), BALL_FRIEND), BALL_FRIEND]
		"doc4":
			return [mini(friend_level("doc"), BALL_FRIEND), BALL_FRIEND]
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


# --- Amistad / Friendship ----------------------------------------------------------------

func friend_level(id: String) -> int:
	return int(friendship.get(id, 0))


## Propina para subir al siguiente nivel: 10, 13, 16, 19 y 22 de Realidad Fragmentada
## Tip to reach the next level: 10, 13, 16, 19 and 22 Fragmented Reality
func tip_cost(id: String) -> int:
	return 10 + 3 * friend_level(id)


func can_tip(id: String) -> bool:
	return friend_level(id) < FRIEND_MAX


## La primera vez que coges un don de alguien te dice algo especial y aún no admite propina
## The first time you take someone's gift they say something special and won't take a tip yet
func first_talk(id: String) -> bool:
	return not stats.has("talked_" + id)


func mark_talked(id: String) -> void:
	stats["talked_" + id] = 1
	save_progress()


func add_friend(id: String) -> void:
	friendship[id] = mini(FRIEND_MAX, friend_level(id) + 1)
	save_progress()
	check_achievements()


## Botón «Desbloquear todo» del menú: logros (y con ellos pijamas, Mr. Ad, El Pinche y dibujos),
## bestiario, personajes, Charo y la dificultad pesadilla. Sin avisos uno a uno.
## Menu "Unlock everything" button: achievements (and with them pajamas, Mr. Ad, the Kitchen Boy
## and drawings), bestiary, characters, Charo and nightmare difficulty. No one-by-one notices.
func unlock_everything() -> void:
	for a in ACHIEVEMENTS:
		achieved[a["id"]] = true
	for id in BESTIARY:
		if not kills.has(id):
			kills[id] = 0
	for g in ["svinho", "stolk", "silly", "doc", "ad", "pinche", "superk", "lilkey", "lynx", "luna"]:
		stats["met_" + g] = 1
	stats["charo_met"] = 1
	stats["unlock_all"] = 1
	save_progress()


func _unlock(id: String) -> void:
	if has_achieved(id):
		return
	achieved[id] = true
	save_progress()
	_show_toast(id)


## Cartelito de «¡Logro conseguido!» arriba a la derecha / "Achievement unlocked!" note at the top right
func _show_toast(id: String) -> void:
	note(tr("ACH_UNLOCKED"), tr("ACH_%s_NAME" % id.to_upper()))


## Tutorial ligero: un consejo la primera vez que pasa algo (se puede quitar en Accesibilidad)
## Light tutorial: a tip the first time something happens (can be switched off in Accessibility)
func tip(id: String) -> void:
	if not Settings.tips or GameState.training or int(stats.get("tip_" + id, 0)) > 0:
		return
	stats["tip_" + id] = 1
	save_progress()
	# Los consejos los da el Gato Siniestro: en un sueño aparece en persona al lado de Kroker y se
	# lo dice en un bocadillo; fuera de los sueños, un cartel con su cara
	# Tips come from the Sinister Cat: in a dream he shows up in person beside Kroker and says it in
	# a speech bubble; outside dreams, a note with his face
	var text := Settings.controls_text(tr("TIP_" + id.to_upper()))
	var sc := get_tree().current_scene
	if sc is Run and is_instance_valid((sc as Run).player):
		CatGuide.appear(sc as Run, text)
		return
	note(tr("CAT_WHISPERS"), text, NpcArt.CAT_AURA, 7.0, "ui_click", "cat")


## Cartelito genérico arriba a la derecha (logros, combos, consejos); el texto puede llevar
## palabras clave / Generic note at the top right (achievements, combos, tips); the text may carry keywords
func note(head: String, body: String, color := UITheme.GOLD, secs := 3.0, sound := "chime", face := "") -> void:
	if _toast == null:
		_toast = CanvasLayer.new()
		_toast.layer = 40
		_toast.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_toast)
	var box := PanelContainer.new()
	box.theme = UITheme.build()
	box.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.95), Color(color, 0.8), Color(color, 0.2), 16, 12, 22))
	_toast.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -40
	box.offset_top = 150 + 110 * (_toast.get_child_count() - 1)
	var v := VBoxContainer.new()
	# Con cara: medallón a la izquierda / With a face: a badge on the left
	if face != "":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var badge := FaceBadge.make(face, 72)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(badge)
		row.add_child(v)
	else:
		box.add_child(v)
	var h := UITheme.label(head, 24, color, "caps")
	h.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(h)
	var b := Keywords.label(body, 22, UITheme.BONE, "body")
	b.custom_minimum_size.x = 460
	v.add_child(b)
	if sound != "":
		Audio.play(sound, -2.0 if sound == "chime" else -8.0)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(secs)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


## ¿Ya lo has conocido? Se conoce a alguien cuando sale en el plano astral (no basta con
## desbloquearlo): hasta entonces su isla no aparece en el hub. Kroker, siempre.
## Have you met them yet? You meet someone when they show up on the astral plane (unlocking them
## isn't enough): until then their island doesn't appear in the hub. Kroker, always.
func met(id: String) -> bool:
	if id == "kroker":
		return true
	if id == "charo":
		return stats.has("charo_met")
	return stats.has("met_" + id) or friend_level(id) > 0


## Frases ya leídas: las que se repiten salen casi de golpe. Devuelve si ya se había leído y la
## apunta. / Lines already read: repeated ones show almost at once. Returns whether it had already
## been read, and records it.
const REPEAT_SPEED := 6.0


func line_seen(text: String) -> bool:
	var lines: Dictionary = stats.get("seen_lines", {})
	var k := text.hash()
	var seen := lines.has(k)
	if not seen:
		lines[k] = 1
		stats["seen_lines"] = lines
	return seen


## Borra todo el progreso guardado (menú principal) / Deletes all saved progress (main menu)
func reset_all() -> void:
	kills = {}
	cleared = {}
	stats = {}
	achieved = {}
	friendship = {}
	var path := Demo.save_path(PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_skip_known_tips()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bestiary", "kills", kills)
	cfg.set_value("acts", "cleared", cleared)
	cfg.set_value("achievements", "stats", stats)
	cfg.set_value("achievements", "achieved", achieved)
	cfg.set_value("friends", "levels", friendship)
	cfg.save(Demo.save_path(PATH))


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Demo.save_path(PATH)) != OK:
		return
	kills = cfg.get_value("bestiary", "kills", {})
	cleared = cfg.get_value("acts", "cleared", {})
	stats = cfg.get_value("achievements", "stats", {})
	achieved = cfg.get_value("achievements", "achieved", {})
	friendship = cfg.get_value("friends", "levels", {})
