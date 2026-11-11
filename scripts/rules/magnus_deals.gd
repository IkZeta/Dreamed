class_name MagnusDeals
extends RefCounted
## Reglas de los tratos de Magnus: cuándo aparece, qué ofrece, cómo se firma y cómo se cierra.
## El estado (GameState.invest y la Realidad) sigue en GameState, que es lo que se guarda.
## Magnus's deal rules: when he shows up, what he offers, how a deal is signed and closed. The
## state (GameState.invest and Reality) stays in GameState, which is what gets saved.


## ¿Puede salir Magnus en el plano astral? Hace falta dinero para el trato más pequeño, no tener
## otro en marcha, y que el próximo sueño no sea de jefe (no hay enemigos que contar).
## Can Magnus show up on the astral plane? You need money for the smallest deal, no other deal
## running, and the next dream mustn't be a boss one (no enemies to count).
static func magnus_available() -> bool:
	if not GameState.giver_unlocked("magnus") or not GameState.invest.is_empty() or not GameState.reality_on():
		return false
	if GameState.reality < int(GameState.INVEST_SIZES[0]["cost"]):
		return false
	var next := GameState.dream_depth + 1
	if next > GameState.WAVES.size():
		return false
	var w := GameState.wave_for(next)
	return not w.get("boss", false) and not w.has("boss_kind")


## Prepara el trato que ofrece Magnus: el más grande que puedas pagar
## Prepares the deal Magnus offers: the biggest one you can afford
static func roll_deal() -> Dictionary:
	var size := 0
	for i in GameState.INVEST_SIZES.size():
		if GameState.reality >= int(GameState.INVEST_SIZES[i]["cost"]):
			size = i
	var sz: Dictionary = GameState.INVEST_SIZES[size]
	# Varias estadísticas distintas al azar / Several different random stats
	var pool: Array[String] = GameState.STATS.duplicate()
	var boosts := []
	for i in int(sz["count"]):
		var stat_id: String = pool.pop_at(GameState._rng.randi_range(0, pool.size() - 1))
		boosts.append({"stat": stat_id, "value": float(GameState.STAT_STEPS[stat_id][int(sz["rarity"])])})
	var goals := GameState.INVEST_GOALS.keys()
	# Tirar enemigos por agujeros solo si alguna de tus armas puede / Pushing enemies down holes only if one of your weapons can
	if not can_push_into_holes():
		goals.erase("falls")
	var goal: String = goals[GameState._rng.randi_range(0, goals.size() - 1)]
	var g: Dictionary = GameState.INVEST_GOALS[goal]
	var amount := float(g["base"]) + float(g["per_act"]) * (GameState.act() - 1)
	var target: int
	if goal == "hits":
		# Más difícil = menos golpes permitidos / Harder = fewer hits allowed
		target = maxi(1, roundi(amount / float(sz["hard"])))
	else:
		target = maxi(1, roundi(amount * float(sz["hard"])))
	var cost := int(sz["cost"])
	return {
		"size": size, "cost": cost, "rarity": int(sz["rarity"]), "boosts": boosts,
		"goal": goal, "target": target,
		# La amistad con Magnus sube lo que devuelve / Friendship with Magnus raises the payout
		"payout": roundi(cost * float(sz["mult"]) * GameState.friend_mult("magnus")),
	}


## ¿Puede alguna de tus armas tirar enemigos por los agujeros? Desde que todas tienen golpe fuerte
## (GameState.HEAVY_EVERY), o empujan de por sí (almohada, aspiradora), sí; solo hace falta que la
## sala tenga agujeros, y todas los tienen desde el sueño 2.
## Can any of your weapons push enemies down holes? Since they all have a heavy hit
## (GameState.HEAVY_EVERY), or push on their own (pillow, vacuum), yes; the room just needs holes,
## and every room has them from dream 2.
static func can_push_into_holes() -> bool:
	for w in GameState.weapons():
		if w in ["shield", "vacuum"] or GameState.HEAVY_EVERY.has(w):
			return true
	return false


static func _goal_counter(goal: String) -> int:
	match goal:
		"kills": return GameState.run_kills
		"falls": return GameState.run_falls
		"elites": return GameState.run_elites
		"hits": return GameState.run_hits
	return 0


## Firma el trato: paga, sube la estadística y empieza a contar / Signs the deal: pays, raises the stat and starts counting
static func sign_deal(deal: Dictionary) -> void:
	GameState.add_reality(-int(deal["cost"]))
	for b: Dictionary in deal["boosts"]:
		GameState.apply_stat({"stat": b["stat"], "rarity": deal["rarity"], "value": b["value"]})
	GameState.invest = deal.duplicate(true)
	GameState.invest["base"] = _goal_counter(deal["goal"])


## Cuánto llevas del objetivo / How far into the goal you are
static func invest_progress() -> int:
	if GameState.invest.is_empty():
		return 0
	return _goal_counter(GameState.invest["goal"]) - int(GameState.invest["base"])


static func invest_met() -> bool:
	if GameState.invest.is_empty():
		return false
	if GameState.invest["goal"] == "hits":
		return invest_progress() <= int(GameState.invest["target"])
	return invest_progress() >= int(GameState.invest["target"])


## Al acabar el sueño se cierra el trato. Devuelve "won", "lost" o "" si no había trato.
## When the dream ends the deal closes. Returns "won", "lost" or "" if there was no deal.
static func settle_deal() -> String:
	if GameState.invest.is_empty():
		return ""
	var result := "won" if invest_met() else "lost"
	if result == "won":
		GameState.add_reality(int(GameState.invest["payout"]))
		GameState.run_deals_won += 1
	else:
		for b: Dictionary in _deal_boosts(GameState.invest):
			var id: String = b["stat"]
			GameState.stat_bonus[id] = float(GameState.stat_bonus.get(id, 0.0)) - float(b["value"])
	GameState.invest = {}
	return result


## Mejoras de un trato (los guardados antes tenían una sola) / A deal's boosts (older saves had just one)
static func _deal_boosts(deal: Dictionary) -> Array:
	if deal.has("boosts"):
		return deal["boosts"]
	if deal.has("stat"):
		return [{"stat": deal["stat"], "value": deal["value"]}]
	return []


## Las mejoras del trato en texto, p. ej. "+8 % de daño, +6 de suerte" / The deal's boosts as text
static func deal_boosts_text(deal: Dictionary, sep := ", ") -> String:
	var parts: Array[String] = []
	for b: Dictionary in _deal_boosts(deal):
		parts.append(GameState.stat_value_text(b["stat"], b["value"]))
	return sep.join(parts)


## Texto del objetivo, p. ej. "Derrota a 30 enemigos" / Goal text, e.g. "Defeat 30 enemies"
static func deal_goal_text(deal: Dictionary) -> String:
	return GameState.tr("INVEST_GOAL_" + String(deal["goal"]).to_upper()).format({"n": deal["target"]})
