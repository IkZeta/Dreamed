class_name FeverDaily
extends RefCounted
## La fiebre (los pactos que se eligen en la fuente) y el sueño del día. Qué pactos lleva la
## partida y cuántos grados suman sigue en GameState (pacts, pact(), fever()).
## The fever (the pacts picked at the fountain) and the daily dream. Which pacts the run carries and
## how many degrees they add stays in GameState (pacts, pact(), fever()).


## Temperatura de Kroker con la fiebre puesta / Kroker's temperature with the fever on
static func fever_temp(f := -1) -> String:
	return "%.1f °C" % (36.6 + 0.4 * float(GameState.fever() if f < 0 else f))


## Pactos elegidos en la fuente (se recuerdan entre partidas) / Pacts picked at the fountain (remembered between runs)
static func pact_pick() -> Array:
	return Progress.stats.get("pact_pick", [])


static func toggle_pact(id: String) -> void:
	var pick: Array = pact_pick().duplicate()
	if id in pick:
		pick.erase(id)
	else:
		pick.append(id)
	Progress.stats["pact_pick"] = pick
	Progress.save_progress()


## Los pactos se desbloquean al superar el Acto 1 / Pacts unlock after clearing Act 1
static func pacts_unlocked() -> bool:
	return Progress.any_cleared()


## --- Sueño del día: misma semilla, pijama y pactos para todos ese día ---------------------
## --- Daily dream: same seed, pajama and pacts for everyone that day -------------------------
static func today() -> String:
	return Time.get_date_string_from_system()


## Pijama y pactos del sueño de hoy (salen de la fecha) / Today's dream pajama and pacts (from the date)
static func daily_setup(date := "") -> Dictionary:
	if date == "":
		date = today()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("dreamed-" + date)
	var pool: Array[String] = []
	for w: String in GameState.MELEE + GameState.RANGED:
		if GameState.weapon_unlocked(w):
			pool.append(w)
	var weapon: String = pool[rng.randi() % pool.size()] if not pool.is_empty() else "bat"
	var options: Array = GameState.PACT_ORDER.duplicate()
	options.erase("solo")
	var picked: Array = []
	for i in 2 + rng.randi() % 2:
		var id: String = options[rng.randi() % options.size()]
		options.erase(id)
		picked.append(id)
	return {"date": date, "weapon": weapon, "pacts": picked}


## Semilla de cada sueño en el sueño del día / Each dream's seed in the daily dream
static func seed_dream(depth: int) -> void:
	if GameState.daily != "":
		seed(hash("dreamed-" + GameState.daily) + depth * 7919)


static func start_daily() -> void:
	var d := daily_setup()
	GameState.god_mode = false
	GameState.difficulty = "normal"
	GameState.selected_character = d["weapon"]
	GameState.start_run()
	GameState.daily = d["date"]
	GameState.pacts = d["pacts"].duplicate()
