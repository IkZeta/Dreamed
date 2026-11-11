class_name KioskRules
extends RefCounted
## Reglas del kiosco de Charo y de la chimenea: precios, ventajas de la amistad, qué sale en el
## mostrador, qué hace cada artículo y cuánto da sacrificar una mejora. Lo comprado
## (GameState.bought) sigue en GameState, que es lo que se guarda.
## Rules for Charo's kiosk and the fireplace: prices, friendship perks, what shows up on the
## counter, what each ware does and how much sacrificing an upgrade gives. What was bought
## (GameState.bought) stays in GameState, which is what gets saved.


static func ware_price(id: String) -> int:
	return int(GameState.WARES[id]["price"])


## --- Ventajas de la amistad con Charo / Perks of Charo's friendship ---
## Huecos del mostrador: 3, 4 con amistad 3 y 5 con amistad 5
## Counter slots: 3, 4 at friendship 3 and 5 at friendship 5
static func shop_slots() -> int:
	var lvl := Progress.friend_level("charo")
	return 3 + (1 if lvl >= 3 else 0) + (1 if lvl >= 5 else 0)


## Cambios gratis por visita: 1 con amistad 1 y 2 con amistad 4 / Free rerolls per visit: 1 at friendship 1, 2 at friendship 4
static func shop_free_rerolls() -> int:
	var lvl := Progress.friend_level("charo")
	return (1 if lvl >= 1 else 0) + (1 if lvl >= 4 else 0)


## Probabilidad (en %) de que un artículo salga de oferta (a mitad de precio), desde amistad 2
## Chance (in %) that a ware is on offer (half price), from friendship 2
static func shop_offer_chance() -> float:
	var lvl := Progress.friend_level("charo")
	return 0.0 if lvl < 2 else 5.0 + 5.0 * lvl


## Precio de cambiar el mostrador, que sube cada vez / Price of rerolling the counter, which goes up each time
static func reroll_price(times: int) -> int:
	return GameState.act() * 2 - 1 + times


## Mejoras que aún pueden subir de nivel: [[personaje, arma], ...] / Upgrades that can still level up: [[giver, weapon], ...]
static func upgradable() -> Array:
	var out := []
	for w in GameState.weapons():
		for g: String in GameState._ups(w):
			if GameState.level(g, w) > 0 and GameState.level(g, w) < GameState.MAX_UPGRADE_LEVEL:
				out.append([g, w])
	return out


## Artículos distintos para el kiosco según el acto, sin repetir "avoid" si se puede
## Different wares for the kiosk depending on the act, avoiding "avoid" if possible
static func roll_wares(n := 3, avoid: Array = []) -> Array[String]:
	var weights: Dictionary = GameState.WARE_TIER_WEIGHT[clampi(GameState.act(), 1, 4)]
	var pool := {}
	for w: String in GameState.WARES:
		var t: int = GameState.WARES[w]["tier"]
		if not weights.has(t):
			continue
		if w in ["newspaper", "sunday_paper", "encyclopedia"] and upgradable().is_empty():
			continue
		if w in Trinkets.UNIQUE and int(GameState.bought.get(w, 0)) > 0:
			continue
		pool[w] = float(weights[t]) * (0.25 if avoid.has(w) else 1.0)
	var out: Array[String] = []
	for i in n:
		if pool.is_empty():
			break
		var total := 0.0
		for w: String in pool:
			total += float(pool[w])
		var r := GameState._rng.randf() * total
		var pick: String = pool.keys()[0]
		for w: String in pool:
			r -= float(pool[w])
			if r <= 0.0:
				pick = w
				break
		out.append(pick)
		pool.erase(pick)
	return out


## Tira la probabilidad de oferta de un artículo / Rolls a ware's offer chance
static func roll_offer() -> bool:
	return GameState._rng.randf() * 100.0 < shop_offer_chance()


static func _add_stat_bonus(id: String, v: float) -> void:
	GameState.stat_bonus[id] = float(GameState.stat_bonus.get(id, 0.0)) + v


static func _level_random_upgrade() -> void:
	var list := upgradable()
	if not list.is_empty():
		var pick: Array = list[GameState._rng.randi_range(0, list.size() - 1)]
		GameState.add_upgrade(pick[0], pick[1])


## Aplica un artículo comprado (curar lo hace la partida) / Applies a bought ware (healing is done by the run)
static func apply_ware(id: String) -> void:
	GameState.bought[id] = int(GameState.bought.get(id, 0)) + 1
	match id:
		"candy":
			_add_stat_bonus("luck", 5.0)
		"glasses":
			_add_stat_bonus("range", 10.0)
		"sneakers":
			_add_stat_bonus("speed", 6.0)
		"plasters":
			_add_stat_bonus("regen", 0.5)
		"soda":
			_add_stat_bonus("attack_speed", 12.0)
		"stickers":
			_add_stat_bonus("parry", 2.0)
		"coin":
			_add_stat_bonus("luck", 12.0)
			_add_stat_bonus("parry", 1.0)
		"energy_drink":
			_add_stat_bonus("attack_speed", 20.0)
			_add_stat_bonus("speed", 8.0)
		"lucky_cat":
			_add_stat_bonus("luck", 20.0)
			_add_stat_bonus("parry", 2.0)
		"encyclopedia":
			_level_random_upgrade()
			_level_random_upgrade()
			GameState.pending_ups += 1
		"gum", "gold_sticker", "comic":
			var rarity := {"gum": 2, "gold_sticker": 3, "comic": 4}[id] as int
			var stat_id: String = GameState.STATS[GameState._rng.randi_range(0, GameState.STATS.size() - 1)]
			GameState.apply_stat({"stat": stat_id, "rarity": rarity, "value": float(GameState.STAT_STEPS[stat_id][rarity])})
		"newspaper":
			_level_random_upgrade()
		"sunday_paper":
			_level_random_upgrade()
			_level_random_upgrade()
		"battery":
			GameState.pending_ups += 1
		"batteries":
			GameState.pending_ups += 2


## Vida que cura un artículo, en fracción de la vida máxima / Health a ware heals, as a fraction of max health
static func ware_heal(id: String) -> float:
	match id:
		"milk": return 0.4
		"sandwich", "cake", "first_aid": return 1.0
	return 0.0


## Realidad Fragmentada que da sacrificar una mejora: más cuanto más nivel tiene (16, 24, 32; 40 la legendaria)
## Fragmented Reality a sacrifice gives: more the higher its level (16, 24, 32; 40 for a legendary)
## "before" = el nivel ya se ha restado (se llama después de sacrificar) / the level was already taken away
static func sacrifice_value(giver: String, weapon := "", before := false) -> int:
	var lvl := GameState.level(giver, weapon) + (1 if before else 0)
	return GameState.REALITY_SACRIFICE + GameState.REALITY_SACRIFICE * maxi(1, lvl)


## Sacrificar en la chimenea: la mejora pierde un nivel / Sacrificing in the fireplace: the upgrade loses a level
static func sacrifice(giver: String, weapon := "") -> void:
	var hp_before := GameState.doc_hp()
	var ups := GameState._ups(weapon)
	ups[giver] = int(ups.get(giver, 0)) - 1
	if int(ups[giver]) <= 0:
		ups.erase(giver)
	if giver == "doc" and GameState.saved_hp >= 0.0:
		GameState.saved_hp -= hp_before - GameState.doc_hp()
