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
		"stats": {"STAT_ATTACK": 1, "STAT_DEFENSE": 5, "STAT_SPEED": 1, "STAT_RANGE": 1},
	},
	{
		"id": "book", "name": "CHAR_BOOK_NAME", "tag": "CHAR_BOOK_TAG", "weapon": "CHAR_BOOK_WEAPON",
		"bonus": "CHAR_BOOK_BONUS", "outfit": "CHAR_BOOK_OUTFIT", "desc": "CHAR_BOOK_DESC",
		"stats": {"STAT_ATTACK": 3, "STAT_DEFENSE": 1, "STAT_SPEED": 3, "STAT_RANGE": 3},
	},
	{
		"id": "vacuum", "name": "CHAR_VACUUM_NAME", "tag": "CHAR_VACUUM_TAG", "weapon": "CHAR_VACUUM_WEAPON",
		"bonus": "CHAR_VACUUM_BONUS", "outfit": "CHAR_VACUUM_OUTFIT", "desc": "CHAR_VACUUM_DESC",
		"stats": {"STAT_ATTACK": 3, "STAT_DEFENSE": 2, "STAT_SPEED": 5, "STAT_RANGE": 4},
	},
	# Se desbloquea al llegar al Acto 2 por primera vez / Unlocked on first reaching Act 2
	{
		"id": "finger", "name": "CHAR_FINGER_NAME", "tag": "CHAR_FINGER_TAG", "weapon": "CHAR_FINGER_WEAPON",
		"bonus": "CHAR_FINGER_BONUS", "outfit": "CHAR_FINGER_OUTFIT", "desc": "CHAR_FINGER_DESC",
		"stats": {"STAT_ATTACK": 2, "STAT_DEFENSE": 1, "STAT_SPEED": 3, "STAT_RANGE": 5},
	},
	# Se desbloquea al llegar al Acto 3 por primera vez / Unlocked on first reaching Act 3
	{
		"id": "teddy", "name": "CHAR_TEDDY_NAME", "tag": "CHAR_TEDDY_TAG", "weapon": "CHAR_TEDDY_WEAPON",
		"bonus": "CHAR_TEDDY_BONUS", "outfit": "CHAR_TEDDY_OUTFIT", "desc": "CHAR_TEDDY_DESC",
		"stats": {"STAT_ATTACK": 3, "STAT_DEFENSE": 3, "STAT_SPEED": 2, "STAT_RANGE": 1},
	},
]
## Logro que desbloquea cada pijama nuevo / Achievement that unlocks each new pajama
const WEAPON_UNLOCK := {"finger": "finger", "teddy": "teddy"}


func weapon_unlocked(id: String) -> bool:
	return not WEAPON_UNLOCK.has(id) or Progress.has_achieved(WEAPON_UNLOCK[id])

## Estadísticas base de Kroker y lo que suma cada arma.
## Kroker's base stats and what each weapon adds.
const BASE_STATS := {"max_hp": 20.0, "speed": 300.0, "damage_mult": 1.0, "armor": 0.0}
const WEAPON_BONUS := {
	"bat": {"damage_mult": 0.2},     # aumenta el ataque / raises attack
	"shield": {"armor": 4.0, "max_hp": 5.0, "speed": -25.0},  # defensa y vida, pero más lento / defence and health, but slower
	"book": {"max_hp": -5.0},        # frágil / fragile
	"vacuum": {"speed": 75.0, "max_hp": 5.0},  # +25 % de velocidad y +5 de vida / +25% speed and +5 health
	"finger": {},                    # +10 de suerte (en BASE_LEVEL_STATS) / +10 luck (in BASE_LEVEL_STATS)
	"teddy": {"max_hp": 6.0},        # +6 de vida máxima / +6 max health
}

## Definición de cada sueño del Acto 1 (la habitación). "mix" es el peso de cada enemigo al
## aparecer. Cada piso trae un enemigo nuevo más peligroso; el 5 es el jefe.
## Definition of each dream in Act 1 (the bedroom). "mix" is each enemy's spawn weight.
## "shop_met": Charo abre aquí el kiosco, pero solo si ya la conoces del salón.
## "shop_met": Charo opens her kiosk here, but only once you've met her in the living room.
## Every floor brings a new, more dangerous enemy; floor 5 is the boss.
## Qué hace El Pinche con cada arma / What the Kitchen Boy does with each weapon
const PINCHE_KIND := {"bat": "bleed", "shield": "burn", "book": "burn", "vacuum": "bleed", "finger": "burn", "teddy": "bleed"}

const WAVES := [
	{"duration": 30.0, "spawn_every": 3.0, "group": [1, 2], "max_alive": 5, "mix": {"foox": 1}},
	{"duration": 35.0, "spawn_every": 2.8, "group": [1, 2], "max_alive": 7, "mix": {"foox": 3, "thug": 1}, "new": "thug"},
	{"duration": 40.0, "spawn_every": 2.6, "group": [1, 3], "max_alive": 8, "mix": {"foox": 2, "thug": 1, "sling": 1}, "new": "sling", "shop_met": true},
	{"duration": 45.0, "spawn_every": 2.4, "group": [2, 3], "max_alive": 9, "mix": {"foox": 2, "thug": 1, "sling": 1, "skeleton": 2}, "new": "skeleton"},
	# Los jefes tienen tiempo límite: si aguantas, pasas; si lo derrotas antes, un nivel de regalo
	# Bosses have a time limit: survive it and you pass; beat it first and you get a bonus level
	{"boss": true, "duration": 150.0, "spawn_every": 3.5, "group": [1, 2], "max_alive": 6, "mix": {"foox": 3, "thug": 1, "sling": 1, "skeleton": 1}},
	# --- Acto 2: el salón. "fire" = la chimenea está encendida; "shop" = Charo abre el kiosco al
	# acabar. El 8 trae al Cyberpunk y el 10 es el jefe, El Chef.
	# --- Act 2: the living room. "fire" = the fireplace is lit; "shop" = Charo opens her kiosk
	# at the end. Dream 8 brings the Cyberpunk and dream 10 is the boss, The Chef.
	{"duration": 40.0, "spawn_every": 2.4, "group": [2, 3], "max_alive": 10, "mix": {"foox": 3, "thug": 1, "sling": 1, "skeleton": 1, "nest": 1}, "new": "nest", "fire": true},
	{"duration": 45.0, "spawn_every": 2.2, "group": [2, 3], "max_alive": 11, "mix": {"foox": 2, "thug": 2, "sling": 1, "skeleton": 2, "nest": 1}, "shop": true},
	{"duration": 50.0, "spawn_every": 2.1, "group": [2, 4], "max_alive": 12, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 2, "nest": 1, "cyber": 0.5}, "new": "cyber", "fire": true},
	{"duration": 55.0, "spawn_every": 2.0, "group": [3, 4], "max_alive": 13, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 3, "nest": 1, "cyber": 0.5}, "shop": true},
	# Sueño 10: El Chef sale de la tele / Dream 10: The Chef comes out of the TV
	{"boss": true, "boss_kind": "chef", "duration": 120.0, "spawn_every": 3.4, "group": [1, 2], "max_alive": 6, "mix": {"foox": 3, "thug": 1, "sling": 1, "skeleton": 1, "cyber": 0.3}},
	# --- Acto 3 (PROVISIONAL): escenario de pruebas para jugar con las dos armas.
	# --- Act 3 (PLACEHOLDER): a test stage to play with both weapons.
	{"duration": 45.0, "spawn_every": 2.0, "group": [2, 4], "max_alive": 13, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 2, "nest": 1, "cyber": 0.5}},
	{"duration": 50.0, "spawn_every": 1.9, "group": [3, 4], "max_alive": 14, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 3, "nest": 1, "cyber": 0.6}, "shop": true},
	{"duration": 55.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"foox": 2, "thug": 3, "sling": 2, "skeleton": 3, "nest": 1, "cyber": 0.7}, "act_end": true},
]
const BOSS_DEPTH := 5
## Primer sueño de cada acto / First dream of each act
const ACT2_START := 6
const ACT3_START := 11
## Armas cuerpo a cuerpo y a distancia: la segunda arma tiene que ser del otro tipo
## Melee and ranged weapons: the second weapon must be of the other kind
const MELEE: Array[String] = ["bat", "shield", "teddy"]
const RANGED: Array[String] = ["book", "vacuum", "finger"]

## Personajes del plano astral y el tipo de mejora que da cada uno.
## Astral plane characters and the kind of upgrade each one gives.
const GIVERS: Array[String] = ["svinho", "stolk", "silly", "doc", "ad", "pinche"]
const MAX_UPGRADE_LEVEL := 3
const STOLK_HP_COST := 5.0   # vida máxima que cuesta cada nivel de Stolk / max health each Stolk level costs

var selected_character := "bat"
var dream_depth := 1  # oleada actual / current wave
## Mejoras compradas en esta partida: "svinho" / "stolk" / "silly" → nivel
## Upgrades taken this run: "svinho" / "stolk" / "silly" → level
var upgrades := {}
## Segunda arma (se elige al vencer a El Chef) y sus mejoras, aparte de las de la primera
## Second weapon (chosen after beating The Chef) and its upgrades, separate from the first's
var second_weapon := ""
var upgrades2 := {}
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
## Hackeos del Cyberpunk: id del enemigo → {stat, value}. Duran hasta que muere el que te hackeó.
## Cyberpunk hacks: enemy id → {stat, value}. They last until whoever hacked you dies.
var hacks := {}
## Se ganaba demasiado (sobre todo tirando enemigos por los agujeros en las peleas de jefe):
## ahora caer solo da 1 a veces, y casi nunca durante un jefe.
## Too much was earned (above all by throwing enemies down holes during boss fights): now a
## fall only gives 1 sometimes, and hardly ever during a boss.
const REALITY_ELITE := 2
const REALITY_BOSS := 3          # cada mueble del jefe del Acto 1 / each Act 1 boss piece
const REALITY_CHEF := 10
const REALITY_FALL := 1
const FALL_REALITY_CHANCE := 0.35
const FALL_REALITY_CHANCE_BOSS := 0.1
const REALITY_SACRIFICE := 4


## --- Modo Dios (para probar) / God mode (for testing) ----------------------------
var god_mode := false
var god_invuln := true          # con la F se cambia en partida / toggled in game with F
var god_depth := 1              # sueño en el que empezar / dream to start in
var god_upgrades := {}          # personaje → nivel / giver → level
var god_stats := {}             # estadística → total / stat → total
var god_second := ""            # segunda arma de prueba ("" = ninguna) / test second weapon ("" = none)
var god_upgrades2 := {}         # mejoras de la segunda arma / second weapon's upgrades


## Empieza una partida desde la selección o al repetir: con el modo Dios aplica sus ajustes
## Starts a run from the select screen or on retry: in god mode it applies its settings
func start_run() -> void:
	reset_run()
	clear_saved_run()
	if Demo.on():
		god_mode = false
	if god_mode:
		dream_depth = clampi(god_depth, 1, WAVES.size())
		upgrades = god_upgrades.duplicate()
		stat_bonus = god_stats.duplicate()
		# Para probar el kiosco de Charo / To try out Charo's kiosk
		if dream_depth >= ACT2_START:
			reality = 30
		# Segunda arma elegida en el panel; en el Acto 3 hace falta una / Second weapon from the panel; Act 3 needs one
		if god_second in (RANGED if selected_character in MELEE else MELEE):
			second_weapon = god_second
			upgrades2 = god_upgrades2.duplicate()
		elif dream_depth >= ACT3_START and not other_weapons().is_empty():
			second_weapon = other_weapons()[0]


## --- Continuar partida / Continue a run ---------------------------------------------
## Al empezar cada sueño se guarda cómo estaba todo; "Continuar" vuelve a ese momento.
## At the start of every dream the state is saved; "Continue" goes back to that moment.
const RUN_SAVE_BASE := "user://run.cfg"
var RUN_SAVE: String:
	get:
		return Demo.save_path(RUN_SAVE_BASE)
const RUN_FIELDS: Array[String] = ["selected_character", "dream_depth", "upgrades", "second_weapon", "upgrades2", "xp", "plevel",
	"pending_ups", "difficulty", "run_time", "run_kills", "run_hits", "saved_hp", "stat_bonus", "reality", "bought", "tipped"]


func save_run() -> void:
	if god_mode:
		return   # las partidas de prueba no se guardan / test runs aren't saved
	var cfg := ConfigFile.new()
	for f in RUN_FIELDS:
		cfg.set_value("run", f, get(f))
	cfg.save(RUN_SAVE)


func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_SAVE)


## Sueño en el que se quedó la partida guardada / Dream the saved run stopped at
func saved_run_info() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(RUN_SAVE) != OK:
		return {}
	return {"depth": cfg.get_value("run", "dream_depth", 1), "weapon": cfg.get_value("run", "selected_character", "bat")}


func load_run() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(RUN_SAVE) != OK:
		return false
	reset_run()
	god_mode = false
	for f in RUN_FIELDS:
		if cfg.has_section_key("run", f):
			set(f, cfg.get_value("run", f))
	return true


func clear_saved_run() -> void:
	if FileAccess.file_exists(RUN_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE))


## Empieza una partida nueva / Starts a new run
func reset_run() -> void:
	dream_depth = 1
	upgrades = {}
	second_weapon = ""
	upgrades2 = {}
	xp = 0
	plevel = 1
	pending_ups = 0
	saved_hp = -1.0
	run_time = 0.0
	run_kills = 0
	run_hits = 0
	stat_bonus = {}
	reality = 0
	bought = {}
	tipped = {}
	hacks = {}
	_rng.randomize()


## Estadísticas de nivel que trae cada arma de serie: el bate y la almohada regeneran vida;
## el libro y la aspiradora roban vida (y el libro empieza con −15 de suerte)
## Level stats each weapon starts with: bat and pillow regenerate health; book and vacuum
## steal health (and the book starts with −10 luck)
const BASE_LEVEL_STATS := {
	"bat": {"regen": 3.0},
	"shield": {"regen": 5.0},
	"book": {"luck": -15.0, "lifesteal": 5.0},
	"vacuum": {"lifesteal": 5.0},
	"finger": {"luck": 10.0, "lifesteal": 5.0},
	"teddy": {"regen": 3.0},
}
## Entre un sueño y otro solo se recupera un 5 % de la vida máxima
## Between one dream and the next only 5% of max health comes back
const HEAL_BETWEEN_DREAMS := 0.05


## Acto del sueño actual (1 = la habitación, 2 = el salón) / Act of the current dream (1 = bedroom, 2 = living room)
func act_of(depth: int) -> int:
	if depth >= ACT3_START:
		return 3
	return 1 if depth < ACT2_START else 2


func act() -> int:
	return act_of(dream_depth)


## La Realidad Fragmentada solo existe desde que Charo la presenta en el Acto 2
## Fragmented Reality only exists once Charo introduces it in Act 2
## (después de conocer a Charo, también en el Acto 1 / after meeting Charo, also in Act 1)
func reality_on() -> bool:
	return act() >= 2 or Progress.stats.has("charo_met")


func add_reality(n: int) -> void:
	reality = maxi(0, reality + n)


## Multiplicadores de la pesadilla y del Acto 2 / Nightmare and Act 2 multipliers
func enemy_hp_mult() -> float:
	return (1.6 if difficulty == "nightmare" else 1.0) * [1.0, 1.0, 1.35, 1.7][act()]


func enemy_dmg_mult() -> float:
	return (1.5 if difficulty == "nightmare" else 1.0) * [1.0, 1.0, 1.2, 1.4][act()]


func shard_mult() -> float:
	return 1.5 if difficulty == "nightmare" else 1.0


func stat(id: String) -> float:
	var base: Dictionary = BASE_LEVEL_STATS.get(selected_character, {})
	var hacked := 0.0
	for h: Dictionary in hacks.values():
		if h["stat"] == id:
			hacked += float(h["value"])
	return float(stat_bonus.get(id, 0.0)) + float(base.get(id, 0.0)) + hacked + ad_bonus(id)


## --- Mr. Ad: cuanta más Realidad Fragmentada ahorrada, más estadística ----------------
## --- Mr. Ad: the more Fragmented Reality saved, the higher the stat ------------------------
## Qué estadística sube Mr. Ad con cada arma / Which stat Mr. Ad raises with each weapon
const AD_STAT := {"bat": "attack", "shield": "defense", "book": "attack_speed", "vacuum": "speed", "finger": "luck", "teddy": "regen"}
const AD_MAX_TIERS := 10   # cuenta hasta 100 de Realidad Fragmentada / counts up to 100 Fragmented Reality


func ad_bonus(id: String) -> float:
	var total := 0.0
	var tiers := mini(reality / 10, AD_MAX_TIERS)
	if tiers <= 0:
		return 0.0
	for w in weapons():
		if AD_STAT[w] == id:
			total += up_value("ad", "per10", -1, w) * tiers
	return total


## Probabilidad (en %) de ganar 1 más cada vez que se gana Realidad Fragmentada
## Chance (in %) of gaining 1 extra whenever Fragmented Reality is gained
func ad_extra_chance() -> float:
	var total := 0.0
	for w in weapons():
		total += up_value("ad", "extra", -1, w)
	return total


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
	# Solo lo ganado (sin contar lo de serie ni los hackeos) / Only what was gained (not the base or hacks)
	stat_bonus[id] = float(stat_bonus.get(id, 0.0)) + float(choice["value"])


## Texto de la subida, p. ej. "+8 %" / Boost text, e.g. "+8%"
func stat_value_text(id: String, value: float) -> String:
	var num := str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.1))
	return tr("STATV_" + id.to_upper()).format({"v": num})


func wave_for(depth: int) -> Dictionary:
	return WAVES[clampi(depth, 1, WAVES.size()) - 1]


## Nivel de la mejora de un personaje (0 si no la tienes) / Level of a giver's upgrade (0 if not taken)
## Armas que lleva Kroker: la del pijama y, desde el Acto 3, la segunda
## Weapons Kroker carries: the pajama's one and, from Act 3, the second one
func weapons() -> Array[String]:
	var out: Array[String] = [selected_character]
	if second_weapon != "" and second_weapon != selected_character:
		out.append(second_weapon)
	return out


## Armas que se pueden coger como segunda: las del otro tipo / Weapons that can be taken second: the other kind
func other_weapons() -> Array[String]:
	var out: Array[String] = []
	for w in (RANGED if selected_character in MELEE else MELEE):
		if weapon_unlocked(w):
			out.append(w)
	return out


func _ups(weapon: String) -> Dictionary:
	return upgrades2 if weapon != "" and weapon == second_weapon and weapon != selected_character else upgrades


func level(giver: String, weapon := "") -> int:
	return int(_ups(weapon).get(giver, 0))


## Nivel más alto de un personaje entre las dos armas / A giver's highest level across both weapons
func best_level(giver: String) -> int:
	var best := 0
	for w in weapons():
		best = maxi(best, level(giver, w))
	return best


## Vida máxima total que da Doc con las dos armas / Total max health Doc gives across both weapons
func doc_hp() -> float:
	var total := 0.0
	for w in weapons():
		total += up_value("doc", "hp", -1, w)
	return total


func add_upgrade(giver: String, weapon := "") -> void:
	var hp_before := doc_hp()
	var ups := _ups(weapon)
	ups[giver] = mini(MAX_UPGRADE_LEVEL, int(ups.get(giver, 0)) + 1)
	if int(ups[giver]) >= MAX_UPGRADE_LEVEL:
		Progress.flag("max_gift")
	# La vida máxima que da Doc llega llena / The max health Doc gives arrives full
	if giver == "doc" and saved_hp >= 0.0:
		saved_hp += doc_hp() - hp_before


## Elige dos personajes distintos que aún puedan subir de nivel / Picks two different givers that can still level up
## A partir de este nivel de Kroker aparecen tres personajes en el plano astral en vez de dos
## From this Kroker level on, three characters show up on the astral plane instead of two
const THIRD_GIVER_LEVEL := 3


func offer_size() -> int:
	return 3 if plevel >= THIRD_GIVER_LEVEL else 2


func pick_offer() -> Array[String]:
	var pool: Array[String] = []
	for g in GIVERS:
		if not giver_unlocked(g):
			continue
		for w in weapons():
			if level(g, w) < MAX_UPGRADE_LEVEL:
				pool.append(g)
				break
	# Con suerte es más fácil que vuelva alguien que ya te ha dado un don, para subirlo de nivel
	# With luck, someone who already gave you a gift is likelier to return, to level it up
	var out: Array[String] = []
	for n in offer_size():
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
	return 1.0 + (stat("luck") / 20.0 if best_level(g) > 0 else 0.0)


## Mr. Ad aparece desde que se llega al Acto 2 por primera vez y El Pinche desde el Acto 3
## Mr. Ad shows up once Act 2 has been reached, and the Kitchen Boy once Act 3 has
func giver_unlocked(g: String) -> bool:
	match g:
		"ad": return Progress.has_achieved("mr_ad")
		"pinche": return Progress.has_achieved("pinche")
	return true


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
		# Más disparos que rebotan, y rebotan en "extra" enemigos más
		"finger": {"chance": [10, 18, 26], "extra": [1, 2, 3]},
		# La pelusa salta a "extra" enemigos cercanos
		"teddy": {"extra": [1, 2, 3]},
	},
	"stolk": {
		"bat": {"pct": [30, 60, 100]},                    # +daño / +damage
		"shield": {"pct": [60, 120, 200], "push": [25, 50, 80]},
		"book": {"pct": [15, 28, 40]},                    # −recarga / −cooldown
		"vacuum": {"pct": [25, 50, 80]},                  # +alcance, fuerza y daño / +reach, pull and damage
		"finger": {"pct": [30, 60, 100]},                 # +daño / +damage
		"teddy": {"pct": [30, 60, 100], "fluff": [1, 1, 2]},  # +daño y pelusa extra / +damage and extra fluff
	},
	## Doc: más vida máxima a cambio de empeorar otra estadística del arma
	## Doc: more max health in exchange for weakening another weapon stat
	"doc": {
		"bat": {"hp": [10, 18, 28], "pct": [8, 12, 16]},       # −daño / −damage
		"shield": {"hp": [10, 18, 28], "pct": [10, 15, 20]},   # −empuje / −shove
		"book": {"hp": [10, 18, 28], "pct": [8, 12, 16]},      # +recarga / +cooldown
		"vacuum": {"hp": [10, 18, 28], "pct": [6, 9, 12]},     # −velocidad / −speed
		"finger": {"hp": [10, 18, 28], "pct": [8, 12, 16]},    # +recarga / +cooldown
		"teddy": {"hp": [10, 18, 28], "pct": [15, 25, 35]},    # −duración de la pelusa / −fluff duration
	},
	## Mr. Ad: "extra" = % de ganar 1 más de Realidad Fragmentada; "per10" = estadística por cada 10 ahorradas
	## Mr. Ad: "extra" = % chance of 1 extra Fragmented Reality; "per10" = stat per 10 saved
	"ad": {
		"bat": {"extra": [20, 35, 50], "per10": [3, 5, 8]},           # +% ataque / +% attack
		"shield": {"extra": [20, 35, 50], "per10": [0.4, 0.7, 1.0]},  # +defensa / +defense
		"book": {"extra": [20, 35, 50], "per10": [3, 5, 8]},          # +% velocidad de ataque / +% attack speed
		"vacuum": {"extra": [20, 35, 50], "per10": [2, 4, 6]},        # +% velocidad / +% speed
		"finger": {"extra": [20, 35, 50], "per10": [2, 3, 5]},        # +suerte / +luck
		"teddy": {"extra": [20, 35, 50], "per10": [0.2, 0.35, 0.5]},  # +regeneración / +regen
	},
	"silly": {
		"bat": {"chance": [8, 15, 25], "secs": [0.5, 0.8, 1.2]},   # congelar / freeze
		"shield": {"chance": [30, 50, 75], "secs": [0.8, 1.4, 2.0]},  # cámara lenta / slow motion
		"book": {"pct": [15, 25, 35]},                    # eco del daño / damage echo
		"vacuum": {"pct": [20, 35, 50], "secs": [0.6, 1.0, 1.6]},  # vulnerable
		"finger": {"chance": [10, 18, 28], "secs": [1.0, 1.5, 2.0]},  # ralentizar / slow
		"teddy": {"pct": [20, 35, 50]},                   # pegados reciben más daño / stuck ones take more damage
	},
	## El Pinche: sangrado (daño residual fuerte) o quemadura (flojo, pero baja su daño y su defensa)
	## The Kitchen Boy: bleed (strong damage over time) or burn (weak, but lowers its damage and defence)
	"pinche": {
		"bat": {"dps": [2, 3, 4.5], "secs": [3, 3.5, 4]},                 # sangrado / bleed
		"shield": {"dps": [1, 1.5, 2], "secs": [3, 4, 5], "pct": [15, 20, 25]},  # quemadura / burn
		"book": {"dps": [1, 1.5, 2], "secs": [3, 4, 5], "pct": [15, 20, 25]},    # quemadura / burn
		"vacuum": {"dps": [1.5, 2.5, 3.5], "secs": [2, 2.5, 3]},          # sangrado / bleed
		"finger": {"dps": [1, 1.5, 2], "secs": [3, 4, 5], "pct": [15, 20, 25]},  # quemadura / burn
		"teddy": {"dps": [2, 3, 4.5], "secs": [3, 3.5, 4]},               # sangrado / bleed
	},
}


## --- Amistad: cada nivel mejora los dones de ese personaje un 6 % (un 30 % al máximo) ---------
## --- Friendship: each level improves that character's gifts by 6% (30% at the most) ---------
const FRIEND_BONUS := 0.06
## Claves que son número de cosas (no se tocan) / Keys that are a count of things (left alone)
const COUNT_KEYS: Array[String] = ["chain", "hits", "fluff"]


func friend_mult(giver: String) -> float:
	return 1.0 + FRIEND_BONUS * Progress.friend_level(giver)


## Aplica la amistad a un valor: sube lo bueno y baja lo malo (recargas y peajes de Doc)
## Applies friendship to a value: raises the good and lowers the bad (cooldowns and Doc's tolls)
func _friendly(giver: String, key: String, v: float) -> float:
	if key in COUNT_KEYS or (key == "extra" and giver != "ad"):
		return v
	var m := friend_mult(giver)
	if key == "cd" or (giver == "doc" and key == "pct"):
		return v / m
	return v * m


## Precio de un artículo del kiosco: la amistad con Charo lo rebaja un 6 % por nivel
## Price of a kiosk ware: friendship with Charo cuts it by 6% per level
func ware_price(id: String) -> int:
	return maxi(1, roundi(float(WARES[id]) * (1.0 - FRIEND_BONUS * Progress.friend_level("charo"))))


## Valor de una mejora en un nivel (por defecto, el nivel que tienes). 0 si no la tienes.
## Value of an upgrade at a level (by default, your current level). 0 if you don't have it.
func up_value(giver: String, key: String, lvl := -1, weapon := "") -> float:
	if weapon == "":
		weapon = selected_character
	if lvl < 0:
		lvl = level(giver, weapon)
	if lvl <= 0:
		return 0.0
	var values: Array = UPGRADE_VALUES[giver][weapon][key]
	return _friendly(giver, key, float(values[mini(lvl, values.size()) - 1]))


## Descripción traducida con los números del nivel indicado / Translated description with that level's numbers
func upgrade_desc(giver: String, weapon: String, lvl: int) -> String:
	var vals := {}
	for key: String in UPGRADE_VALUES[giver][weapon]:
		var v := up_value(giver, key, lvl, weapon)
		vals[key] = str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.1))
	return tr(upgrade_key(giver, weapon, "DESC")).format(vals)


## --- Kiosco de Charo / Charo's kiosk ------------------------------------------------
const WARES := {
	"milk": 5,       # recupera un 40 % de la vida / restores 40% health
	"candy": 6,      # +8 de suerte / +8 luck
	"gum": 8,        # estadística rara al azar / random rare stat
	"glasses": 8,    # +15 % de alcance / +15% range
	"newspaper": 10, # sube de nivel una mejora / levels up an upgrade
	"battery": 12,   # una subida de nivel / one level-up
}
## Lo comprado en esta partida: artículo → cuántos / Bought this run: ware → how many
var bought := {}
## A quién se le ha dado propina en esta partida (solo una por personaje y partida)
## Who has been tipped this run (only one per character per run)
var tipped := {}


## Mejoras que aún pueden subir de nivel / Upgrades that can still level up
## Mejoras que aún pueden subir de nivel: [[personaje, arma], ...] / Upgrades that can still level up: [[giver, weapon], ...]
func upgradable() -> Array:
	var out := []
	for w in weapons():
		for g: String in _ups(w):
			if level(g, w) > 0 and level(g, w) < MAX_UPGRADE_LEVEL:
				out.append([g, w])
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
	bought[id] = int(bought.get(id, 0)) + 1
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
				var pick: Array = list[_rng.randi_range(0, list.size() - 1)]
				add_upgrade(pick[0], pick[1])
		"battery":
			pending_ups += 1


## Sacrificar en la chimenea: la mejora pierde un nivel / Sacrificing in the fireplace: the upgrade loses a level
func sacrifice(giver: String, weapon := "") -> void:
	var hp_before := doc_hp()
	var ups := _ups(weapon)
	ups[giver] = int(ups.get(giver, 0)) - 1
	if int(ups[giver]) <= 0:
		ups.erase(giver)
	if giver == "doc" and saved_hp >= 0.0:
		saved_hp -= hp_before - doc_hp()


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
	# (con dos armas cuentan los niveles de las dos / with two weapons both weapons' levels count)
	var stolk := 0
	for w in weapons():
		stolk += level("stolk", w)
	s["max_hp"] = maxf(5.0, float(s["max_hp"]) - STOLK_HP_COST * stolk)
	# Doc: suma vida máxima; con la aspiradora cuesta velocidad / Doc: adds max health; with the vacuum it costs speed
	s["max_hp"] = float(s["max_hp"]) + doc_hp()
	if "vacuum" in weapons():
		s["speed"] = float(s["speed"]) * (1.0 - up_value("doc", "pct", -1, "vacuum") / 100.0)
	# Estadísticas ganadas al subir de nivel / Stats gained by levelling up
	s["damage_mult"] = float(s["damage_mult"]) + stat("attack") / 100.0
	s["armor"] = float(s["armor"]) + stat("defense")
	s["speed"] = float(s["speed"]) * (1.0 + stat("speed") / 100.0)
	return s


func change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
