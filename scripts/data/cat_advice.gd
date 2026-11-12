class_name CatAdvice
extends RefCounted
## Los consejos del Gato Siniestro, sentado en la fuente del plano astral. Cada vez que hablas con
## él te cuenta uno: primero los que aún no te ha contado (en orden, como un tutorial) y, cuando ya
## te los sabes todos, uno al azar. Solo cuenta los que ya tienen sentido (no te habla de la
## pesadilla hasta que la puedes elegir). Antes que nada, comenta el último sueño.
## The Sinister Cat's advice, sitting on the astral plane's fountain. Each time you talk to him he
## tells you one: first those he hasn't told you yet (in order, like a tutorial) and, once you know
## them all, a random one. He only tells those that already make sense (he won't mention
## nightmare mode until you can pick it). Before anything, he comments on the last dream.

## En orden de tutorial / In tutorial order
const ORDER: Array[String] = ["intro", "fountain", "move", "holes", "heavy", "level", "gifts", "keywords",
	"museum", "album", "training", "kiosk", "friends", "wardrobe", "elites", "events", "boss", "parry",
	"luck", "second", "nightmare", "fever", "duos", "magnus", "druid", "death"]


static func _ok(id: String) -> bool:
	match id:
		"kiosk": return Progress.met("charo")
		"friends": return GameState.GIVERS.any(func(g: String) -> bool: return Progress.met(g))
		"wardrobe": return ["finger", "teddy", "ball", "laptop", "boots", "druid"].any(func(w: String) -> bool: return GameState.weapon_unlocked(w))
		"second": return Progress.has_seen("boss_chef")
		"nightmare": return Progress.any_cleared()
		"fever": return GameState.pacts_unlocked()
		"duos": return GameState.GIVERS.any(func(g: String) -> bool: return Progress.friend_level(g) >= 2)
		"death": return int(Progress.stats.get("dreams", 0)) > 0
		"magnus": return Progress.met("magnus")
		"druid": return GameState.weapon_unlocked("druid")
	return true


static func _told(id: String) -> bool:
	return Progress.stats.has("cat_" + id)


## ¿Tiene algo nuevo que contar? (para el «!» encima de su cabeza) / Has he got something new to tell? (for the "!" over his head)
static func has_new() -> bool:
	for id in ORDER:
		if _ok(id) and not _told(id):
			return true
	return false


static var _last := ""


## La frase que toca (ya traducida) / The line that's due (already translated)
static func next_line() -> String:
	Progress.stats["met_cat"] = 1
	var react := Progress.run_reaction("cat")
	if react != "":
		Progress.save_progress()
		return react
	var pick := ""
	for id in ORDER:
		if _ok(id) and not _told(id):
			pick = id
			break
	if pick == "":
		var pool: Array[String] = []
		for id in ORDER:
			if id != "intro" and id != _last and _ok(id):
				pool.append(id)
		pick = pool[randi() % pool.size()]
	_last = pick
	Progress.stats["cat_" + pick] = 1
	Progress.save_progress()
	return Settings.controls_text(TranslationServer.translate("CAT_ADV_" + pick.to_upper()))
