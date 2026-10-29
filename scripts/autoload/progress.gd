extends Node
## Progreso que se guarda entre partidas (user://progress.cfg): enemigos vistos y
## derrotados (bestiario) y actos superados con cada arma en cada dificultad.
## Progress saved between runs (user://progress.cfg): enemies seen and defeated
## (bestiary) and acts cleared with each weapon on each difficulty.

const PATH := "user://progress.cfg"

## Entradas del bestiario en orden / Bestiary entries in order
const BESTIARY: Array[String] = ["foox", "thug", "sling", "skeleton", "golden_foox", "elite", "boss_bed", "boss_shelf", "boss_chest"]
const DIFFICULTIES: Array[String] = ["normal", "nightmare"]

## id → veces derrotado (si aparece aquí, ya se ha visto) / id → times defeated (present = seen)
var kills := {}
## arma → {dificultad: true} / weapon → {difficulty: true}
var cleared := {}


func _ready() -> void:
	load_progress()


func see(id: String) -> void:
	if id != "" and not kills.has(id):
		kills[id] = 0
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


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bestiary", "kills", kills)
	cfg.set_value("acts", "cleared", cleared)
	cfg.save(PATH)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	kills = cfg.get_value("bestiary", "kills", {})
	cleared = cfg.get_value("acts", "cleared", {})
