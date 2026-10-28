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
		"stats": {"STAT_ATTACK": 3, "STAT_DEFENSE": 1, "STAT_SPEED": 3, "STAT_RANGE": 5},
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
	{"boss": true, "spawn_every": 6.0, "group": [1, 2], "max_alive": 3, "mix": {"foox": 2, "skeleton": 1}},
]
const BOSS_DEPTH := 5

## Personajes del plano astral y el tipo de mejora que da cada uno.
## Astral plane characters and the kind of upgrade each one gives.
const GIVERS: Array[String] = ["svinho", "stolk", "silly"]
const MAX_UPGRADE_LEVEL := 3
const STOLK_HP_COST := 5.0   # vida máxima que cuesta cada nivel de Stolk / max health each Stolk level costs

var selected_character := "bat"
var dream_depth := 1  # oleada actual / current wave
## Mejoras compradas en esta partida: "svinho" / "stolk" / "silly" → nivel
## Upgrades taken this run: "svinho" / "stolk" / "silly" → level
var upgrades := {}
var _rng := RandomNumberGenerator.new()


## Empieza una partida nueva / Starts a new run
func reset_run() -> void:
	dream_depth = 1
	upgrades = {}
	_rng.randomize()


func wave_for(depth: int) -> Dictionary:
	return WAVES[clampi(depth, 1, WAVES.size()) - 1]


## Nivel de la mejora de un personaje (0 si no la tienes) / Level of a giver's upgrade (0 if not taken)
func level(giver: String) -> int:
	return int(upgrades.get(giver, 0))


func add_upgrade(giver: String) -> void:
	upgrades[giver] = mini(MAX_UPGRADE_LEVEL, level(giver) + 1)


## Elige dos personajes distintos que aún puedan subir de nivel / Picks two different givers that can still level up
func pick_offer() -> Array[String]:
	var pool: Array[String] = []
	for g in GIVERS:
		if level(g) < MAX_UPGRADE_LEVEL:
			pool.append(g)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, 2)


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
		"bat": {"pct": [15, 30, 50]},                     # +daño / +damage
		"shield": {"pct": [25, 50, 80], "push": [10, 20, 35]},
		"book": {"pct": [8, 16, 25]},                     # −recarga / −cooldown
		"vacuum": {"pct": [10, 20, 35]},                  # +alcance, fuerza y daño / +reach, pull and damage
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
	return s


func change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
