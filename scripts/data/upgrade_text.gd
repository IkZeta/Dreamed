class_name UpgradeText
extends RefCounted
## Los textos de las mejoras, los dúos y los pijamas, con sus números ya puestos. Las reglas
## (valores, niveles) siguen en GameState y los datos en UpgradeData; aquí solo se escriben.
## The texts of upgrades, duos and pajamas, with their numbers filled in. The rules (values,
## levels) stay in GameState and the data in UpgradeData; this only writes them out.


## Descripción traducida con los números del nivel indicado / Translated description with that level's numbers
static func upgrade_desc(giver: String, weapon: String, lvl: int) -> String:
	var vals := {}
	for key: String in GameState.UPGRADE_VALUES[giver][weapon]:
		var v := GameState.up_value(giver, key, lvl, weapon)
		vals[key] = str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.1))
	var text := String(TranslationServer.translate(GameState.upgrade_key(giver, weapon, "DESC"))).format(vals)
	# Stolk y Doc tienen además dos efectos con cualquier arma / Stolk and Doc also have two effects with any weapon
	if giver in ["stolk", "doc"]:
		text += "\n" + String(TranslationServer.translate("UP_%s_COMMON" % giver.to_upper())).format(vals)
	return text


static func duo_desc(id: String) -> String:
	var vals := {}
	for k: String in GameState.DUO_VALUES[id]:
		var v := float(GameState.DUO_VALUES[id][k])
		vals[k] = str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)
	return String(TranslationServer.translate("DUO_%s_DESC" % id.to_upper())).format(vals)


## Todo lo que el pijama cambia de serie, para enseñarlo en su carta: [{"text", "good"}, ...]
## Everything the pajama changes out of the box, to show on its card: [{"text", "good"}, ...]
static func pajama_perks(id: String) -> Array:
	var out := []
	var bonus: Dictionary = GameState.WEAPON_BONUS.get(id, {})
	var base: Dictionary = GameState.BASE_LEVEL_STATS.get(id, {})
	var vals := []   # [clave de texto, valor] / [text key, value]
	if bonus.has("damage_mult"):
		vals.append(["STATV_ATTACK", roundf(float(bonus["damage_mult"]) * 100.0)])
	if bonus.has("max_hp"):
		vals.append(["STATV_MAX_HP", float(bonus["max_hp"])])
	if bonus.has("armor"):
		vals.append(["STATV_DEFENSE", float(bonus["armor"])])
	if bonus.has("speed"):
		vals.append(["STATV_SPEED", roundf(float(bonus["speed"]) / float(GameState.BASE_STATS["speed"]) * 100.0)])
	for st: String in GameState.STATS:
		if base.has(st):
			vals.append(["CHIPV_" + st.to_upper() if st in ["regen", "lifesteal"] else "STATV_" + st.to_upper(), float(base[st])])
	# La almohada tiene el tope de parry más alto / The pillow has the highest parry cap
	if id == "shield":
		vals.append(["CHIPV_PARRY_MAX", GameState.PARRY_MAX_SHIELD])
	if GameState.HEAVY_EVERY.has(id):
		vals.append(["CHIPV_HEAVY", float(GameState.HEAVY_EVERY[id])])
	for pair: Array in vals:
		var v: float = pair[1]
		if pair[0] == "CHIPV_HEAVY":
			out.append({"text": String(TranslationServer.translate(pair[0])).format({"n": int(v)}), "good": true})
			continue
		if pair[0] == "CHIPV_PARRY_MAX":
			out.append({"text": String(TranslationServer.translate(pair[0])).format({"v": int(v)}), "good": true})
			continue
		var num := str(int(absf(v))) if is_equal_approx(v, roundf(v)) else str(snappedf(absf(v), 0.1))
		var text := String(TranslationServer.translate(pair[0])).replace("+{v}", ("+" if v > 0.0 else "−") + num)
		out.append({"text": text, "good": v > 0.0})
	return out
