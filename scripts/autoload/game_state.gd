extends Node
## Datos compartidos entre escenas: atuendos de Kroker, armas y la elección.
## Data shared between scenes: Kroker's outfits, weapons and the player's pick.

## Siempre es Kroker; cambia el atuendo y el arma. Estadísticas de 1 a 5 (solo para la carta).
## Always Kroker; the outfit and weapon change. Stats 1-5 (card display only).
const CHARACTERS := [
	{
		"id": "bat", "name": "CHAR_BAT_NAME", "tag": "CHAR_BAT_TAG", "weapon": "CHAR_BAT_WEAPON",
		"bonus": "CHAR_BAT_BONUS", "outfit": "CHAR_BAT_OUTFIT", "desc": "CHAR_BAT_DESC",
		"stats": {"STAT_ATTACK": 4, "STAT_DEFENSE": 2, "STAT_SPEED": 3, "STAT_RANGE": 1},
	},
	{
		"id": "shield", "name": "CHAR_SHIELD_NAME", "tag": "CHAR_SHIELD_TAG", "weapon": "CHAR_SHIELD_WEAPON",
		"bonus": "CHAR_SHIELD_BONUS", "outfit": "CHAR_SHIELD_OUTFIT", "desc": "CHAR_SHIELD_DESC",
		"stats": {"STAT_ATTACK": 1, "STAT_DEFENSE": 5, "STAT_SPEED": 2, "STAT_RANGE": 2},
	},
	{
		"id": "book", "name": "CHAR_BOOK_NAME", "tag": "CHAR_BOOK_TAG", "weapon": "CHAR_BOOK_WEAPON",
		"bonus": "CHAR_BOOK_BONUS", "outfit": "CHAR_BOOK_OUTFIT", "desc": "CHAR_BOOK_DESC",
		"stats": {"STAT_ATTACK": 2, "STAT_DEFENSE": 1, "STAT_SPEED": 3, "STAT_RANGE": 5},
	},
	{
		"id": "vacuum", "name": "CHAR_VACUUM_NAME", "tag": "CHAR_VACUUM_TAG", "weapon": "CHAR_VACUUM_WEAPON",
		"bonus": "CHAR_VACUUM_BONUS", "outfit": "CHAR_VACUUM_OUTFIT", "desc": "CHAR_VACUUM_DESC",
		"stats": {"STAT_ATTACK": 2, "STAT_DEFENSE": 2, "STAT_SPEED": 5, "STAT_RANGE": 3},
	},
]

## Estadísticas base de Kroker y lo que suma cada arma.
## Kroker's base stats and what each weapon adds.
const BASE_STATS := {"max_hp": 20.0, "speed": 300.0, "damage_mult": 1.0, "armor": 0.0}
const WEAPON_BONUS := {
	"bat": {"damage_mult": 0.3},     # aumenta el ataque / raises attack
	"shield": {"armor": 3.0},        # aumenta la defensa / raises defense
	"book": {},
	"vacuum": {"speed": 75.0},       # +25 % de velocidad / +25% speed
}

## Definición de cada sueño del Acto 1 (la habitación). "mix" es el peso de cada enemigo al
## aparecer. Cada piso trae un enemigo nuevo más peligroso; el 5 es el jefe.
## Definition of each dream in Act 1 (the bedroom). "mix" is each enemy's spawn weight.
## Every floor brings a new, more dangerous enemy; floor 5 is the boss.
const WAVES := [
	{"duration": 30.0, "spawn_every": 3.0, "group": [1, 2], "max_alive": 5, "mix": {"foox": 1}},
	{"duration": 35.0, "spawn_every": 2.8, "group": [1, 2], "max_alive": 7, "mix": {"foox": 3, "thug": 1}, "new": "thug"},
	{"duration": 40.0, "spawn_every": 2.6, "group": [1, 3], "max_alive": 8, "mix": {"foox": 2, "thug": 1, "sling": 1}, "new": "sling"},
	{"duration": 45.0, "spawn_every": 2.4, "group": [2, 3], "max_alive": 9, "mix": {"foox": 2, "thug": 1, "sling": 1, "skeleton": 2}, "new": "skeleton"},
	{"boss": true, "spawn_every": 3.5, "group": [1, 2], "max_alive": 6, "mix": {"foox": 3, "thug": 1, "sling": 1, "skeleton": 1}},
	# --- Acto 2: el salón. "fire" = la chimenea está encendida; "shop" = Charo abre el kiosco al
	# acabar; "act_end" = de momento, aquí termina el acto (el jefe del salón vendrá después).
	# --- Act 2: the living room. "fire" = the fireplace is lit; "shop" = Charo opens her kiosk
	# at the end; "act_end" = for now the act ends here (the living-room boss comes later).
	{"duration": 40.0, "spawn_every": 2.4, "group": [2, 3], "max_alive": 10, "mix": {"foox": 3, "thug": 1, "sling": 1, "skeleton": 1, "nest": 1}, "new": "nest", "fire": true},
	{"duration": 45.0, "spawn_every": 2.2, "group": [2, 3], "max_alive": 11, "mix": {"foox": 2, "thug": 2, "sling": 1, "skeleton": 2, "nest": 1}, "shop": true},
	{"duration": 50.0, "spawn_every": 2.1, "group": [2, 4], "max_alive": 12, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 2, "nest": 1}, "fire": true},
	{"duration": 55.0, "spawn_every": 2.0, "group": [3, 4], "max_alive": 13, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 3, "nest": 1}, "shop": true, "act_end": true},
]
const BOSS_DEPTH := 5
## Primer sueño de cada acto / First dream of each act
const ACT2_START := 6

## Personajes del plano astral y el tipo de mejora que da cada uno.
## Astral plane characters and the kind of upgrade each one gives.
const GIVERS: Array[String] = ["svinho", "stolk", "silly", "doc"]
const MAX_UPGRADE_LEVEL := 3
const STOLK_HP_COST := 5.0   # vida máxima que cuesta cada nivel de Stolk / max health each Stolk level costs

var selected_character := "bat"
var dream_depth := 1  # oleada actual / current wave
## Mejoras compradas en esta partida: "svinho" / "stolk" / "silly" → nivel
## Upgrades taken this run: "svinho" / "stolk" / "silly" → level
var upgrades := {}
var _rng := RandomNumberGenerator.new()

## --- Nivel de Kroker / Kroker's level ---------------------------------------------
## Los enemigos sueltan trozos de estrella; al llenar la barra, Kroker sube de nivel y
## elige una de 3 mejoras de estadística. Cuanto mejor es la rareza, mayor la subida.
## Enemies drop star shards; when the bar fills Kroker levels up and picks one of 3 stat
## upgrades. The better the rarity, the bigger the boost.
const STATS: Array[String] = ["attack", "defense", "speed", "attack_speed", "range", "regen", "lifesteal", "luck"]
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_WEIGHT: Array[float] = [60.0, 25.0, 10.0, 4.0, 1.0]
## Subida de cada estadística en cada rareza (común → legendaria)
## Boost of each stat at each rarity (common → legendary)
const STAT_STEPS := {
	"attack": [5, 8, 12, 18, 26],               # +% daño / +% damage
	"defense": [0.5, 1, 1.5, 2.5, 4],           # +defensa (resta daño) / +defense (subtracts damage)
	"speed": [4, 6, 9, 13, 18],                 # +% velocidad / +% speed
	"attack_speed": [5, 8, 12, 17, 25],         # +% velocidad de ataque / +% attack speed
	"range": [6, 10, 15, 21, 30],               # +% alcance / +% range
	"regen": [0.5, 0.8, 1.2, 1.8, 2.5],         # vida cada 5 s / health every 5 s
	"lifesteal": [2, 4, 6, 9, 13],              # % de curar 1 al golpear / % to heal 1 on hit
	"luck": [5, 8, 12, 18, 25],                 # suerte / luck
}
var xp := 0
var plevel := 1
## Subidas de nivel aún sin elegir / Level-ups not yet chosen
var pending_ups := 0
## Dificultad: "normal" o "nightmare" (pesadilla, se desbloquea al superar el Acto 1)
## Difficulty: "normal" or "nightmare" (unlocked by clearing Act 1)
var difficulty := "normal"
## Estadísticas de la partida para la pantalla final / Run stats for the end screen
var run_time := 0.0
var run_kills := 0
var run_hits := 0
## Vida con la que acabó el último sueño (−1 = empezar con la vida llena)
## Health at the end of the last dream (−1 = start at full health)
var saved_hp := -1.0
## Total ganado en cada estadística / Total gained in each stat
var stat_bonus := {}
## Realidad Fragmentada: la moneda de Charo (dura lo que dura la partida). Solo sale de los
## élites, los jefes, los enemigos tirados por los agujeros y los sacrificios en la chimenea.
## Fragmented Reality: Charo's currency (lasts for the run). It only comes from elites,
## bosses, enemies thrown down holes and sacrifices in the fireplace.
var reality := 0
const REALITY_ELITE := 2
const REALITY_BOSS := 5
const REALITY_FALL := 1
const REALITY_SACRIFICE := 4


## --- Modo Dios (para probar) / God mode (for testing) ----------------------------
var god_mode := false
var god_invuln := true          # con la F se cambia en partida / toggled in game with F
var god_depth := 1              # sueño en el que empezar / dream to start in
var god_upgrades := {}          # personaje → nivel / giver → level
var god_stats := {}             # estadística → total / stat → total


## Empieza una partida desde la selección o al repetir: con el modo Dios aplica sus ajustes
## Starts a run from the select screen or on retry: in god mode it applies its settings
func start_run() -> void:
	reset_run()
	if god_mode:
		dream_depth = clampi(god_depth, 1, WAVES.size())
		upgrades = god_upgrades.duplicate()
		stat_bonus = god_stats.duplicate()
		# Para probar el kiosco de Charo / To try out Charo's kiosk
		if dream_depth >= ACT2_START:
			reality = 30


## Empieza una partida nueva / Starts a new run
func reset_run() -> void:
	dream_depth = 1
	upgrades = {}
	xp = 0
	plevel = 1
	pending_ups = 0
	saved_hp = -1.0
	run_time = 0.0
	run_kills = 0
	run_hits = 0
	stat_bonus = {}
	reality = 0
	_rng.randomize()


## Estadísticas de nivel que trae cada arma de serie: el bate y la almohada regeneran vida;
## el libro y la aspiradora roban vida (y el libro empieza con −10 de suerte)
## Level stats each weapon starts with: bat and pillow regenerate health; book and vacuum
## steal health (and the book starts with −10 luck)
const BASE_LEVEL_STATS := {
	"bat": {"regen": 3.0},
	"shield": {"regen": 3.0},
	"book": {"luck": -10.0, "lifesteal": 5.0},
	"vacuum": {"lifesteal": 5.0},
}
## Entre un sueño y otro solo se recupera un 5 % de la vida máxima
## Between one dream and the next only 5% of max health comes back
const HEAL_BETWEEN_DREAMS := 0.05


## Acto del sueño actual (1 = la habitación, 2 = el salón) / Act of the current dream (1 = bedroom, 2 = living room)
func act_of(depth: int) -> int:
	return 1 if depth < ACT2_START else 2


func act() -> int:
	return act_of(dream_depth)


## La Realidad Fragmentada solo existe desde que Charo la presenta en el Acto 2
## Fragmented Reality only exists once Charo introduces it in Act 2
func reality_on() -> bool:
	return act() >= 2


func add_reality(n: int) -> void:
	reality = maxi(0, reality + n)


## Multiplicadores de la pesadilla y del Acto 2 / Nightmare and Act 2 multipliers
func enemy_hp_mult() -> float:
	return (1.6 if difficulty == "nightmare" else 1.0) * (1.35 if act() >= 2 else 1.0)


func enemy_dmg_mult() -> float:
	return (1.5 if difficulty == "nightmare" else 1.0) * (1.2 if act() >= 2 else 1.0)


func shard_mult() -> float:
	return 1.5 if difficulty == "nightmare" else 1.0


func stat(id: String) -> float:
	var base: Dictionary = BASE_LEVEL_STATS.get(selected_character, {})
	return float(stat_bonus.get(id, 0.0)) + float(base.get(id, 0.0))


## Trozos que hacen falta para el siguiente nivel / Shards needed for the next level
func xp_needed() -> int:
	return 12 + 10 * (plevel - 1)


## Suma trozos de estrella; devuelve cuántos niveles se han subido
## Adds star shards; returns how many levels were gained
func add_xp(n: int) -> int:
	xp += n
	var ups := 0
	while xp >= xp_needed():
		xp -= xp_needed()
		plevel += 1
		ups += 1
	if ups > 0:
		Progress.best_stat("best_level", plevel)
	return ups


## La suerte hace más probables las rarezas altas / Luck makes the higher rarities likelier
func roll_rarity() -> int:
	var luck := stat("luck") / 100.0
	var weights: Array[float] = []
	var total := 0.0
	for i in RARITIES.size():
		var w := RARITY_WEIGHT[i] * pow(1.0 + luck * 2.0, i)
		weights.append(w)
		total += w
	var roll := _rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return 0


## Tres estadísticas distintas, cada una con su rareza: [{stat, rarity, value}, ...]
## Three different stats, each with its rarity: [{stat, rarity, value}, ...]
func roll_level_choices() -> Array[Dictionary]:
	var pool := STATS.duplicate()
	var out: Array[Dictionary] = []
	for i in 3:
		var stat_id: String = pool.pop_at(_rng.randi_range(0, pool.size() - 1))
		var r := roll_rarity()
		out.append({"stat": stat_id, "rarity": r, "value": float(STAT_STEPS[stat_id][r])})
	return out


func apply_stat(choice: Dictionary) -> void:
	var id: String = choice["stat"]
	stat_bonus[id] = stat(id) + float(choice["value"])


## Texto de la subida, p. ej. "+8 %" / Boost text, e.g. "+8%"
func stat_value_text(id: String, value: float) -> String:
	var num := str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.1))
	return tr("STATV_" + id.to_upper()).format({"v": num})


func wave_for(depth: int) -> Dictionary:
	return WAVES[clampi(depth, 1, WAVES.size()) - 1]


## Nivel de la mejora de un personaje (0 si no la tienes) / Level of a giver's upgrade (0 if not taken)
func level(giver: String) -> int:
	return int(upgrades.get(giver, 0))


func add_upgrade(giver: String) -> void:
	var hp_before := up_value("doc", "hp")
	upgrades[giver] = mini(MAX_UPGRADE_LEVEL, level(giver) + 1)
	if level(giver) >= MAX_UPGRADE_LEVEL:
		Progress.flag("max_gift")
	# La vida máxima que da Doc llega llena / The max health Doc gives arrives full
	if giver == "doc" and saved_hp >= 0.0:
		saved_hp += up_value("doc", "hp") - hp_before


## Elige dos personajes distintos que aún puedan subir de nivel / Picks two different givers that can still level up
func pick_offer() -> Array[String]:
	var pool: Array[String] = []
	for g in GIVERS:
		if level(g) < MAX_UPGRADE_LEVEL:
			pool.append(g)
	# Con suerte es más fácil que vuelva alguien que ya te ha dado un don, para subirlo de nivel
	# With luck, someone who already gave you a gift is likelier to return, to level it up
	var out: Array[String] = []
	for n in 2:
		if pool.is_empty():
			break
		var total := 0.0
		for g in pool:
			total += _giver_weight(g)
		var roll := _rng.randf() * total
		var pick := pool[pool.size() - 1]
		for g in pool:
			roll -= _giver_weight(g)
			if roll <= 0.0:
				pick = g
				break
		out.append(pick)
		pool.erase(pick)
	return out


func _giver_weight(g: String) -> float:
	return 1.0 + (stat("luck") / 20.0 if level(g) > 0 else 0.0)


## Clave de traducción del nombre o la descripción de una mejora / Translation key of an upgrade's name or description
func upgrade_key(giver: String, weapon: String, part: String) -> String:
	return "UP_%s_%s_%s" % [giver.to_upper(), weapon.to_upper(), part]


## Valores de cada mejora en los niveles 1, 2 y 3. Empiezan flojas y mejoran con cada nivel.
## Los porcentajes van en números enteros (30 = 30 %). Las descripciones usan las mismas claves.
## Each upgrade's values at levels 1, 2 and 3. They start weak and grow with each level.
## Percentages are whole numbers (30 = 30%). Descriptions use the same keys.
const UPGRADE_VALUES := {
	"svinho": {
		# El golpeado sale volando y golpea a "chain" enemigos más con "pct" % del daño
		"bat": {"chain": [1, 2, 3], "pct": [30, 45, 60]},
		# Lanzar la almohada: golpea a "hits" enemigos, "dmg" de daño, recarga "cd" s
		"shield": {"hits": [1, 2, 3], "dmg": [5, 7, 9], "cd": [1.8, 1.5, 1.2]},
		# El rayo salta a "extra" enemigos más
		"book": {"extra": [1, 2, 3]},
		# La aspiradora escupe un enemigo cada "cd" s; rebota contra "chain" más
		"vacuum": {"cd": [9.0, 6.0, 3.5], "chain": [0, 1, 2], "dmg": [6, 9, 12]},
	},
	"stolk": {
		"bat": {"pct": [30, 60, 100]},                    # +daño / +damage
		"shield": {"pct": [60, 120, 200], "push": [25, 50, 80]},
		"book": {"pct": [15, 28, 40]},                    # −recarga / −cooldown
		"vacuum": {"pct": [25, 50, 80]},                  # +alcance, fuerza y daño / +reach, pull and damage
	},
	## Doc: más vida máxima a cambio de empeorar otra estadística del arma
	## Doc: more max health in exchange for weakening another weapon stat
	"doc": {
		"bat": {"hp": [10, 18, 28], "pct": [8, 12, 16]},       # −daño / −damage
		"shield": {"hp": [10, 18, 28], "pct": [10, 15, 20]},   # −empuje / −shove
		"book": {"hp": [10, 18, 28], "pct": [8, 12, 16]},      # +recarga / +cooldown
		"vacuum": {"hp": [10, 18, 28], "pct": [6, 9, 12]},     # −velocidad / −speed
	},
	"silly": {
		"bat": {"chance": [8, 15, 25], "secs": [0.5, 0.8, 1.2]},   # congelar / freeze
		"shield": {"chance": [30, 50, 75], "secs": [0.8, 1.4, 2.0]},  # cámara lenta / slow motion
		"book": {"pct": [15, 25, 35]},                    # eco del daño / damage echo
		"vacuum": {"pct": [20, 35, 50], "secs": [0.6, 1.0, 1.6]},  # vulnerable
	},
}


## Valor de una mejora en un nivel (por defecto, el nivel que tienes). 0 si no la tienes.
## Value of an upgrade at a level (by default, your current level). 0 if you don't have it.
func up_value(giver: String, key: String, lvl := -1, weapon := "") -> float:
	if weapon == "":
		weapon = selected_character
	if lvl < 0:
		lvl = level(giver)
	if lvl <= 0:
		return 0.0
	var values: Array = UPGRADE_VALUES[giver][weapon][key]
	return float(values[mini(lvl, values.size()) - 1])


## Descripción traducida con los números del nivel indicado / Translated description with that level's numbers
func upgrade_desc(giver: String, weapon: String, lvl: int) -> String:
	var vals := {}
	for key: String in UPGRADE_VALUES[giver][weapon]:
		var v := up_value(giver, key, lvl, weapon)
		vals[key] = str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.1))
	return tr(upgrade_key(giver, weapon, "DESC")).format(vals)


## --- Kiosco de Charo / Charo's kiosk ------------------------------------------------
const WARES := {
	"milk": 3,       # recupera un 40 % de la vida / restores 40% health
	"candy": 4,      # +8 de suerte / +8 luck
	"gum": 5,        # estadística rara al azar / random rare stat
	"glasses": 5,    # +15 % de alcance / +15% range
	"newspaper": 6,  # sube de nivel una mejora / levels up an upgrade
	"battery": 7,    # una subida de nivel / one level-up
}


## Mejoras que aún pueden subir de nivel / Upgrades that can still level up
func upgradable() -> Array[String]:
	var out: Array[String] = []
	for g: String in upgrades:
		if level(g) > 0 and level(g) < MAX_UPGRADE_LEVEL:
			out.append(g)
	return out


## Tres artículos distintos para el kiosco / Three different wares for the kiosk
func roll_wares() -> Array[String]:
	var pool: Array[String] = []
	for w: String in WARES:
		if w == "newspaper" and upgradable().is_empty():
			continue
		pool.append(w)
	var out: Array[String] = []
	for i in 3:
		if pool.is_empty():
			break
		out.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	return out


## Aplica un artículo comprado (lo que toca la vida lo hace la partida) / Applies a bought ware (health is handled by the run)
func apply_ware(id: String) -> void:
	match id:
		"candy":
			stat_bonus["luck"] = float(stat_bonus.get("luck", 0.0)) + 8.0
		"glasses":
			stat_bonus["range"] = float(stat_bonus.get("range", 0.0)) + 15.0
		"gum":
			var stat_id: String = STATS[_rng.randi_range(0, STATS.size() - 1)]
			apply_stat({"stat": stat_id, "rarity": 2, "value": float(STAT_STEPS[stat_id][2])})
		"newspaper":
			var list := upgradable()
			if not list.is_empty():
				add_upgrade(list[_rng.randi_range(0, list.size() - 1)])
		"battery":
			pending_ups += 1


## Sacrificar en la chimenea: la mejora pierde un nivel / Sacrificing in the fireplace: the upgrade loses a level
func sacrifice(giver: String) -> void:
	var hp_before := up_value("doc", "hp")
	upgrades[giver] = level(giver) - 1
	if level(giver) <= 0:
		upgrades.erase(giver)
	if giver == "doc" and saved_hp >= 0.0:
		saved_hp -= hp_before - up_value("doc", "hp")


func get_character(id: String) -> Dictionary:
	for c: Dictionary in CHARACTERS:
		if c["id"] == id:
			return c
	return {}


func stats_for(id: String) -> Dictionary:
	var s := BASE_STATS.duplicate()
	var bonus: Dictionary = WEAPON_BONUS.get(id, {})
	for k: String in bonus:
		s[k] = float(s[k]) + float(bonus[k])
	# Stolk: cada nivel quita vida máxima / Stolk: each level costs max health
	s["max_hp"] = maxf(5.0, float(s["max_hp"]) - STOLK_HP_COST * level("stolk"))
	# Doc: suma vida máxima; con la aspiradora cuesta velocidad / Doc: adds max health; with the vacuum it costs speed
	s["max_hp"] = float(s["max_hp"]) + up_value("doc", "hp", -1, id)
	if id == "vacuum":
		s["speed"] = float(s["speed"]) * (1.0 - up_value("doc", "pct", -1, id) / 100.0)
	# Estadísticas ganadas al subir de nivel / Stats gained by levelling up
	s["damage_mult"] = float(s["damage_mult"]) + stat("attack") / 100.0
	s["armor"] = float(s["armor"]) + stat("defense")
	s["speed"] = float(s["speed"]) * (1.0 + stat("speed") / 100.0)
	return s


func change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
