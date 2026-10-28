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

## Definición de cada oleada. A partir de la última, cada sueño es un poco más difícil.
## Wave definitions. After the last one, each dream gets a bit harder.
const WAVES := [
	{"duration": 30.0, "enemy": "foox", "spawn_every": 3.0, "group": [1, 2], "max_alive": 5},
	{"duration": 35.0, "enemy": "foox", "spawn_every": 2.6, "group": [1, 3], "max_alive": 7},
	{"duration": 40.0, "enemy": "foox", "spawn_every": 2.2, "group": [2, 3], "max_alive": 9},
]

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
	if depth <= WAVES.size():
		return WAVES[depth - 1]
	var extra := depth - WAVES.size()
	var last: Dictionary = WAVES[WAVES.size() - 1]
	return {
		"duration": minf(60.0, float(last["duration"]) + extra * 4.0),
		"enemy": "foox",
		"spawn_every": maxf(1.0, float(last["spawn_every"]) - extra * 0.2),
		"group": [2, 3 + extra / 2],
		"max_alive": mini(16, int(last["max_alive"]) + extra * 2),
		"hp_mult": 1.0 + extra * 0.25,
		"speed_mult": 1.0 + extra * 0.06,
	}


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
