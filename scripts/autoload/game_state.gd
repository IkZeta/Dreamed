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
	# Se desbloquea al llegar a amistad 4 con Svinho / Unlocked at friendship 4 with Svinho
	{
		"id": "ball", "name": "CHAR_BALL_NAME", "tag": "CHAR_BALL_TAG", "weapon": "CHAR_BALL_WEAPON",
		"bonus": "CHAR_BALL_BONUS", "outfit": "CHAR_BALL_OUTFIT", "desc": "CHAR_BALL_DESC",
		"stats": {"STAT_ATTACK": 4, "STAT_DEFENSE": 1, "STAT_SPEED": 4, "STAT_RANGE": 2},
	},
	# Se desbloquea al llegar a amistad 4 con Silly / Unlocked at friendship 4 with Silly
	{
		"id": "laptop", "name": "CHAR_LAPTOP_NAME", "tag": "CHAR_LAPTOP_TAG", "weapon": "CHAR_LAPTOP_WEAPON",
		"bonus": "CHAR_LAPTOP_BONUS", "outfit": "CHAR_LAPTOP_OUTFIT", "desc": "CHAR_LAPTOP_DESC",
		"stats": {"STAT_ATTACK": 3, "STAT_DEFENSE": 2, "STAT_SPEED": 2, "STAT_RANGE": 4},
	},
	# Se desbloquea al llegar a amistad 4 con Doc / Unlocked at friendship 4 with Doc
	{
		"id": "boots", "name": "CHAR_BOOTS_NAME", "tag": "CHAR_BOOTS_TAG", "weapon": "CHAR_BOOTS_WEAPON",
		"bonus": "CHAR_BOOTS_BONUS", "outfit": "CHAR_BOOTS_OUTFIT", "desc": "CHAR_BOOTS_DESC",
		"stats": {"STAT_ATTACK": 4, "STAT_DEFENSE": 2, "STAT_SPEED": 4, "STAT_RANGE": 1},
	},
]
## Logro que desbloquea cada pijama nuevo / Achievement that unlocks each new pajama
const WEAPON_UNLOCK := {"finger": "finger", "teddy": "teddy", "ball": "ball", "laptop": "laptop", "boots": "boots"}
## Svinho le regala su mejora a nivel 3 a la pelota / Svinho gives the ball his upgrade at level 3
const BALL_SVINHO := 3


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
	"ball": {"armor": -2.0, "speed": 60.0, "damage_mult": 0.15},  # frágil, rápida y pega fuerte / fragile, fast and hits hard
	"laptop": {"max_hp": 3.0},       # +3 de vida máxima / +3 max health
	"boots": {"speed": 30.0, "armor": 1.0},  # algo más rápido y un poco de defensa / a bit faster and a little defence
}

## Definición de cada sueño del Acto 1 (la habitación). "mix" es el peso de cada enemigo al
## aparecer. Cada piso trae un enemigo nuevo más peligroso; el 5 es el jefe.
## Definition of each dream in Act 1 (the bedroom). "mix" is each enemy's spawn weight.
## "shop_met": Charo abre aquí el kiosco, pero solo si ya la conoces del salón.
## "shop_met": Charo opens her kiosk here, but only once you've met her in the living room.
## Every floor brings a new, more dangerous enemy; floor 5 is the boss.
## Qué hace El Pinche con cada arma / What the Kitchen Boy does with each weapon
const PINCHE_KIND := {"bat": "bleed", "shield": "burn", "book": "burn", "vacuum": "bleed", "finger": "burn", "teddy": "bleed", "ball": "bleed", "laptop": "bleed", "boots": "burn"}

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
	# --- Acto 3: el pasillo infinito del colegio. El 11 trae las Marionetas (poco comunes) y el
	# 13, el Gólem de papel higiénico.
	# --- Act 3: the endless school hallway. Dream 11 brings the Puppets (uncommon) and dream 13
	# the Toilet-Paper Golem.
	{"duration": 45.0, "spawn_every": 2.0, "group": [2, 4], "max_alive": 13, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 2, "nest": 1, "cyber": 0.5, "puppet": 0.7}, "new": "puppet"},
	{"duration": 50.0, "spawn_every": 1.9, "group": [3, 4], "max_alive": 14, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 3, "nest": 1, "cyber": 0.6, "puppet": 0.8}, "shop": true},
	{"duration": 55.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 3, "nest": 1, "cyber": 0.6, "puppet": 0.8, "golem": 0.6}, "new": "golem"},
	{"duration": 60.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 2, "nest": 1, "cyber": 0.7, "puppet": 1.0, "golem": 0.8}, "shop": true},
	# Sueño 15: el Ovni destroza el pasillo / Dream 15: the UFO wrecks the hallway
	{"boss": true, "boss_kind": "ufo", "duration": 150.0, "spawn_every": 3.6, "group": [1, 2], "max_alive": 7, "mix": {"foox": 3, "thug": 1, "puppet": 1, "skeleton": 1}},
	# --- Acto 4 (el final): la Metrópolis, con una estética distinta en cada sueño. El 16 trae la
	# Unidad Especial (furgo voladora que suelta policías), el 17 los Antidisturbios (salen de los
	# agujeros y ponen escudos a los demás) y el 20 es el último sueño: la ciudad se viene abajo.
	# --- Act 4 (the final one): the Metropolis, with a different look in every dream. Dream 16
	# brings the Special Unit (a flying van that drops police), 17 the Riot Police (they climb out
	# of the holes and shield the others) and 20 is the last dream: the city comes crashing down.
	{"duration": 50.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.6, "puppet": 0.8, "golem": 0.5, "police": 1.2, "van": 0.25}, "new": "van"},
	{"duration": 55.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.6, "puppet": 0.8, "golem": 0.6, "police": 1.4, "van": 0.25, "riot": 0.35}, "new": "riot", "shop": true},
	{"duration": 60.0, "spawn_every": 1.7, "group": [3, 5], "max_alive": 16, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.7, "puppet": 1.0, "golem": 0.7, "police": 1.6, "van": 0.3, "riot": 0.4}},
	{"duration": 60.0, "spawn_every": 1.6, "group": [3, 6], "max_alive": 17, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.8, "puppet": 1.0, "golem": 0.8, "police": 1.8, "van": 0.35, "riot": 0.45}, "shop": true},
	# Sueño 20, el último: la ciudad se derrumba, más furgos y edificios cayendo sin parar
	# Dream 20, the last one: the city collapses, more vans and buildings falling all the time
	{"duration": 80.0, "spawn_every": 1.5, "group": [4, 6], "max_alive": 18, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.8, "puppet": 1.0, "golem": 0.8, "police": 2.0, "van": 0.45, "riot": 0.5}, "final": true, "act_end": true},
]
const BOSS_DEPTH := 5
## Primer sueño de cada acto / First dream of each act
const ACT2_START := 6
const ACT3_START := 11
const ACT4_START := 16
## Estéticas de la Metrópolis: cada sueño del Acto 4 tiene una (sin repetir en la partida)
## Metropolis looks: each Act 4 dream has one (no repeats within the run)
const CITY_STYLES: Array[String] = ["synthwave", "steampunk", "cheese", "aero", "solarpunk", "dieselpunk", "brutalist"]
## Armas cuerpo a cuerpo y a distancia: la segunda arma tiene que ser del otro tipo
## Melee and ranged weapons: the second weapon must be of the other kind
const MELEE: Array[String] = ["bat", "shield", "teddy", "boots"]
const RANGED: Array[String] = ["book", "vacuum", "finger", "ball", "laptop"]

## Personajes del plano astral y el tipo de mejora que da cada uno.
## Astral plane characters and the kind of upgrade each one gives.
const GIVERS: Array[String] = ["svinho", "stolk", "silly", "doc", "ad", "pinche", "superk", "lilkey"]
## SuperK y Lil Key no cambian el arma: aparecen en el mapa y ayudan. Cada arma tiene uno de sus
## poderes (las armas del mismo poder comparten nombre y descripción).
## SuperK and Lil Key don't change the weapon: they show up on the map and help. Each weapon gets
## one of their powers (weapons with the same power share a name and description).
const HELPER_POWER := {
	"superk": {"bat": "punch", "boots": "punch", "shield": "guard", "teddy": "guard",
		"book": "laser", "finger": "laser", "laptop": "laser", "vacuum": "throw", "ball": "throw"},
	"lilkey": {"bat": "dance", "shield": "dance", "teddy": "dance", "boots": "dance",
		"book": "sing", "vacuum": "sing", "finger": "sing", "ball": "sing", "laptop": "sing"},
}


## Poder de SuperK o Lil Key con esta arma ("" si no es uno de ellos) / SuperK's or Lil Key's power with this weapon ("" if it isn't one of them)
static func helper_power(giver: String, weapon: String) -> String:
	return HELPER_POWER.get(giver, {}).get(weapon, "")
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
const STATS: Array[String] = ["attack", "defense", "speed", "attack_speed", "range", "regen", "lifesteal", "luck", "parry"]
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
	"regen": [0.3, 0.5, 0.7, 1.0, 1.4],         # vida cada 5 s / health every 5 s
	"lifesteal": [1, 2, 3, 4.5, 6.5],           # % de curar 1 al golpear / % to heal 1 on hit
	"luck": [5, 8, 12, 18, 25],                 # suerte / luck
	"parry": [1, 1.5, 2, 3, 4],                 # % de esquivar y contraatacar con un chasquido / % to dodge and snap back
}
## El parry nunca pasa de aquí, para no romper el juego / Parry never goes above this, so it can't break the game
const PARRY_MAX := 20.0
## El Guardián (la almohada) para más golpes: empieza con más parry y su tope es más alto
## The Guardian (the pillow) blocks more hits: starts with more parry and has a higher cap
const PARRY_MAX_SHIELD := 30.0


func parry_max() -> float:
	return PARRY_MAX_SHIELD if selected_character == "shield" else PARRY_MAX


func parry_chance() -> float:
	return clampf(stat("parry"), 0.0, parry_max())
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
var run_falls := 0      # enemigos tirados por agujeros / enemies pushed down holes
var run_elites := 0     # élites derrotados / elites defeated
## Kroker lleva las gafas de sol de la taquilla durante toda esta partida / Kroker wears the locker sunglasses for this whole run
var run_shades := false
## Evento del sueño anterior, para no repetirlo / Previous dream's event, so it isn't repeated
var last_event := ""
## Orden de las estéticas de la Metrópolis en esta partida / Order of the Metropolis looks this run
var city_styles: Array = []
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
## Partida de entrenamiento con el muñeco del plano astral / Training run with the astral plane's dummy
var training := false
## Dónde aparece Kroker al volver al plano astral: "" (al entrar), "fountain" o "training"
## Where Kroker appears when coming back to the astral plane: "" (on entering), "fountain" or "training"
var hub_spawn := ""
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
	gift_ball()


## La pelota empieza con la mejora de Svinho a nivel 3 (sea primera o segunda arma)
## The ball starts with Svinho's upgrade at level 3 (whether first or second weapon)
func gift_ball() -> void:
	if selected_character == "ball":
		upgrades["svinho"] = maxi(int(upgrades.get("svinho", 0)), BALL_SVINHO)
	elif second_weapon == "ball":
		upgrades2["svinho"] = maxi(int(upgrades2.get("svinho", 0)), BALL_SVINHO)


## --- Continuar partida / Continue a run ---------------------------------------------
## Al empezar cada sueño se guarda cómo estaba todo; "Continuar" vuelve a ese momento.
## At the start of every dream the state is saved; "Continue" goes back to that moment.
const RUN_SAVE_BASE := "user://run.cfg"
var RUN_SAVE: String:
	get:
		return Demo.save_path(RUN_SAVE_BASE)
const RUN_FIELDS: Array[String] = ["selected_character", "dream_depth", "upgrades", "second_weapon", "upgrades2", "xp", "plevel",
	"pending_ups", "difficulty", "run_time", "run_kills", "run_hits", "saved_hp", "stat_bonus", "reality", "bought", "tipped", "run_falls", "run_elites", "invest", "run_shades", "city_styles"]


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
	run_shades = false
	city_styles = []
	run_kills = 0
	run_hits = 0
	run_falls = 0
	run_elites = 0
	invest = {}
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
	"shield": {"regen": 2.0, "parry": 8.0},
	"book": {"luck": -15.0, "lifesteal": 5.0},
	"vacuum": {"lifesteal": 5.0},
	"finger": {"luck": 10.0, "lifesteal": 5.0},
	"teddy": {"regen": 3.0},
	"ball": {"luck": -10.0, "parry": 6.0},
	"laptop": {"attack_speed": -15.0, "luck": 5.0},   # torretas muy de tarde en tarde / turrets very rarely
	"boots": {"regen": 2.0},
}
## Entre un sueño y otro solo se recupera un 5 % de la vida máxima
## Between one dream and the next only 5% of max health comes back
const HEAL_BETWEEN_DREAMS := 0.05


## Acto del sueño actual (1 = la habitación, 2 = el salón) / Act of the current dream (1 = bedroom, 2 = living room)
func act_of(depth: int) -> int:
	if depth >= ACT4_START:
		return 4
	if depth >= ACT3_START:
		return 3
	return 1 if depth < ACT2_START else 2


## Estética de la ciudad en este sueño (las baraja al llegar al Acto 4) / City look this dream (shuffled on reaching Act 4)
func city_style(depth := -1) -> String:
	if depth < 0:
		depth = dream_depth
	if city_styles.size() != CITY_STYLES.size():
		city_styles = CITY_STYLES.duplicate()
		city_styles.shuffle()
	return city_styles[posmod(depth - ACT4_START, city_styles.size())]


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
	return (1.6 if difficulty == "nightmare" else 1.0) * [1.0, 1.0, 1.35, 1.7, 1.7][act()]


## Desde el sueño 13 los enemigos (no los jefes) aguantan cada vez más: +40 % por sueño
## From dream 13 on, enemies (not bosses) get tougher and tougher: +40% per dream
const LATE_DEPTH := 13
const LATE_HP_STEP := 0.4


func late_hp_mult() -> float:
	if training:
		return 1.0
	# Del 13 al 15, +40 % por sueño; en el Acto 4 sigue subiendo, +25 % por sueño
	# From 13 to 15, +40% per dream; in Act 4 it keeps rising, +25% per dream
	return 1.0 + LATE_HP_STEP * maxi(0, mini(dream_depth, ACT4_START - 1) - LATE_DEPTH + 1) + 0.25 * maxi(0, dream_depth - ACT4_START + 1)


## Los jefes atacan más a menudo y pegan más fuerte (en las dos dificultades)
## Bosses attack more often and hit harder (on both difficulties)
const BOSS_POWER := 1.25


func enemy_dmg_mult() -> float:
	return (1.5 if difficulty == "nightmare" else 1.0) * [1.0, 1.0, 1.2, 1.4, 1.55][act()]


func shard_mult() -> float:
	return 1.5 if difficulty == "nightmare" else 1.0


## Regeneración que de verdad cura: a partir de 2 rinde la mitad, para no ser inmortal
## Regeneration that actually heals: above 2 it's worth half, so you can't be immortal
const REGEN_SOFT_CAP := 2.0


func regen_effective() -> float:
	var r := stat("regen")
	return r if r <= REGEN_SOFT_CAP else REGEN_SOFT_CAP + (r - REGEN_SOFT_CAP) * 0.5


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
const AD_STAT := {"bat": "attack", "shield": "defense", "book": "attack_speed", "vacuum": "speed", "finger": "luck", "teddy": "regen", "ball": "parry", "laptop": "attack_speed", "boots": "speed"}
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
	# Magnus no da mejoras de arma: sale si se le puede pagar / Magnus gives no weapon upgrade: he shows up if you can pay him
	if magnus_available():
		pool.append("magnus")
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
	if g == "magnus":
		return 1.0
	return 1.0 + (stat("luck") / 20.0 if best_level(g) > 0 else 0.0)


## Mr. Ad aparece desde que se llega al Acto 2 por primera vez y El Pinche desde el Acto 3
## Mr. Ad shows up once Act 2 has been reached, and the Kitchen Boy once Act 3 has
func giver_unlocked(g: String) -> bool:
	match g:
		"ad": return Progress.has_achieved("mr_ad")
		"pinche": return Progress.has_achieved("pinche")
		"magnus": return Progress.has_achieved("magnus")
		"superk": return Progress.has_achieved("superk")
		"lilkey": return Progress.has_achieved("lilkey")
	return true


## --- Magnus: inversiones / Magnus: investments -----------------------------------------
## Magnus no da mejoras de arma: le pagas Realidad Fragmentada, te sube una estadística y te
## pone un objetivo para el próximo sueño. Si lo cumples, te quedas la estadística y te devuelve
## más de lo que pusiste; si no, te la quita y se queda el dinero.
## Magnus doesn't give weapon upgrades: you pay him Fragmented Reality, he raises a stat and
## sets you a goal for the next dream. Meet it and you keep the stat and get back more than you
## put in; miss it and he takes the stat away and keeps the money.
##
## Tamaños de inversión: coste, rareza de la estadística, cuánto devuelve y lo difícil del objetivo
## Investment sizes: cost, stat rarity, how much it pays back and how hard the goal is
const INVEST_SIZES := [
	# "count" = cuántas estadísticas distintas sube / how many different stats it raises
	{"cost": 6, "count": 2, "rarity": 1, "mult": 1.5, "hard": 0.75},
	{"cost": 12, "count": 3, "rarity": 1, "mult": 1.75, "hard": 1.0},
	{"cost": 20, "count": 4, "rarity": 2, "mult": 2.0, "hard": 1.3},
]
## Objetivos y su cantidad base (por acto se suma "per_act"). "hits" es al revés: como mucho N golpes.
## Goals and their base amount ("per_act" is added per act). "hits" is the other way round: at most N hits.
const INVEST_GOALS := {
	"kills": {"base": 20, "per_act": 10},
	"falls": {"base": 3, "per_act": 1},
	"elites": {"base": 1, "per_act": 0.5},
	"hits": {"base": 7, "per_act": -1},
}
## Inversión en curso (vacía si no hay) / Investment in progress (empty if none)
var invest := {}


## ¿Puede salir Magnus en el plano astral? Hace falta dinero para el trato más pequeño, no tener
## otro en marcha, y que el próximo sueño no sea de jefe (no hay enemigos que contar).
## Can Magnus show up on the astral plane? You need money for the smallest deal, no other deal
## running, and the next dream mustn't be a boss one (no enemies to count).
func magnus_available() -> bool:
	if not giver_unlocked("magnus") or not invest.is_empty() or not reality_on():
		return false
	if reality < int(INVEST_SIZES[0]["cost"]):
		return false
	var next := dream_depth + 1
	if next > WAVES.size():
		return false
	var w := wave_for(next)
	return not w.get("boss", false) and not w.has("boss_kind")


## Prepara el trato que ofrece Magnus: el más grande que puedas pagar
## Prepares the deal Magnus offers: the biggest one you can afford
func roll_deal() -> Dictionary:
	var size := 0
	for i in INVEST_SIZES.size():
		if reality >= int(INVEST_SIZES[i]["cost"]):
			size = i
	var sz: Dictionary = INVEST_SIZES[size]
	# Varias estadísticas distintas al azar / Several different random stats
	var pool: Array[String] = STATS.duplicate()
	var boosts := []
	for i in int(sz["count"]):
		var stat_id: String = pool.pop_at(_rng.randi_range(0, pool.size() - 1))
		boosts.append({"stat": stat_id, "value": float(STAT_STEPS[stat_id][int(sz["rarity"])])})
	var goals := INVEST_GOALS.keys()
	# Tirar enemigos por agujeros solo si alguna de tus armas puede / Pushing enemies down holes only if one of your weapons can
	if not can_push_into_holes():
		goals.erase("falls")
	var goal: String = goals[_rng.randi_range(0, goals.size() - 1)]
	var g: Dictionary = INVEST_GOALS[goal]
	var amount := float(g["base"]) + float(g["per_act"]) * (act() - 1)
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
		"payout": roundi(cost * float(sz["mult"]) * friend_mult("magnus")),
	}


## ¿Puede alguna de tus armas tirar enemigos por los agujeros? / Can any of your weapons push enemies down holes?
## Empujan lo bastante: la almohada, la aspiradora (lo que arrastras), la pistola de dedos (sus rayos
## que empujan) y la pelota; el bate solo con Svinho; el portátil con el muñeco de Stolk, con el
## fogón del Pinche o con torretas de nivel 3. El libro y el oso no empujan.
## Push hard enough: pillow, vacuum (what you drag), finger gun (its pushing beams) and ball; the bat
## only with Svinho; the laptop with Stolk's dummy, the Kitchen Boy's stove or level-3 turrets.
## The book and the teddy don't push.
func can_push_into_holes() -> bool:
	for w in weapons():
		match w:
			"shield", "vacuum", "finger", "ball", "boots":
				return true
			"bat":
				if level("svinho", w) > 0:
					return true
			"laptop":
				if level("stolk", w) > 0 or level("pinche", w) > 0 or WeaponLaptop.turret_level() >= 3:
					return true
	return false


func _goal_counter(goal: String) -> int:
	match goal:
		"kills": return run_kills
		"falls": return run_falls
		"elites": return run_elites
		"hits": return run_hits
	return 0


## Firma el trato: paga, sube la estadística y empieza a contar / Signs the deal: pays, raises the stat and starts counting
func sign_deal(deal: Dictionary) -> void:
	add_reality(-int(deal["cost"]))
	for b: Dictionary in deal["boosts"]:
		apply_stat({"stat": b["stat"], "rarity": deal["rarity"], "value": b["value"]})
	invest = deal.duplicate(true)
	invest["base"] = _goal_counter(deal["goal"])


## Cuánto llevas del objetivo / How far into the goal you are
func invest_progress() -> int:
	if invest.is_empty():
		return 0
	return _goal_counter(invest["goal"]) - int(invest["base"])


func invest_met() -> bool:
	if invest.is_empty():
		return false
	if invest["goal"] == "hits":
		return invest_progress() <= int(invest["target"])
	return invest_progress() >= int(invest["target"])


## Al acabar el sueño se cierra el trato. Devuelve "won", "lost" o "" si no había trato.
## When the dream ends the deal closes. Returns "won", "lost" or "" if there was no deal.
func settle_deal() -> String:
	if invest.is_empty():
		return ""
	var result := "won" if invest_met() else "lost"
	if result == "won":
		add_reality(int(invest["payout"]))
	else:
		for b: Dictionary in _deal_boosts(invest):
			var id: String = b["stat"]
			stat_bonus[id] = float(stat_bonus.get(id, 0.0)) - float(b["value"])
	invest = {}
	return result


## Mejoras de un trato (los guardados antes tenían una sola) / A deal's boosts (older saves had just one)
func _deal_boosts(deal: Dictionary) -> Array:
	if deal.has("boosts"):
		return deal["boosts"]
	if deal.has("stat"):
		return [{"stat": deal["stat"], "value": deal["value"]}]
	return []


## Las mejoras del trato en texto, p. ej. "+8 % de daño, +6 de suerte" / The deal's boosts as text
func deal_boosts_text(deal: Dictionary, sep := ", ") -> String:
	var parts: Array[String] = []
	for b: Dictionary in _deal_boosts(deal):
		parts.append(stat_value_text(b["stat"], b["value"]))
	return sep.join(parts)


## Texto del objetivo, p. ej. "Derrota a 30 enemigos" / Goal text, e.g. "Defeat 30 enemies"
func deal_goal_text(deal: Dictionary) -> String:
	return tr("INVEST_GOAL_" + String(deal["goal"]).to_upper()).format({"n": deal["target"]})


## Clave de traducción del nombre o la descripción de una mejora / Translation key of an upgrade's name or description
func upgrade_key(giver: String, weapon: String, part: String) -> String:
	var power := helper_power(giver, weapon)
	if power != "":
		return "UP_%s_%s_%s" % [giver.to_upper(), power.to_upper(), part]
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
		"shield": {"hits": [1, 2, 3], "dmg": [9, 13, 18], "cd": [1.3, 1.0, 0.8]},
		# El rayo salta a "extra" enemigos más
		"book": {"extra": [1, 2, 3]},
		# La aspiradora escupe un enemigo cada "cd" s; rebota contra "chain" más
		"vacuum": {"cd": [9.0, 6.0, 3.5], "chain": [0, 1, 2], "dmg": [6, 9, 12]},
		# Más disparos que rebotan, y rebotan en "extra" enemigos más
		"finger": {"chance": [10, 18, 26], "extra": [1, 2, 3]},
		# La pelusa salta a "extra" enemigos cercanos
		"teddy": {"extra": [1, 2, 3]},
		# La pelota rebota en "extra" enemigos más (empieza a nivel 3)
		"ball": {"extra": [1, 2, 3]},
		# Cada disparo de torreta salta a "extra" enemigos más
		"laptop": {"extra": [1, 2, 3]},
		# Las patadas y el dash lanzan al enemigo contra "chain" más con "pct" % del daño
		"boots": {"chain": [1, 2, 3], "pct": [30, 45, 60]},
	},
	"stolk": {
		"bat": {"pct": [30, 60, 100]},                    # +daño / +damage
		"shield": {"pct": [60, 120, 200], "push": [25, 50, 80]},
		"book": {"pct": [15, 28, 40]},                    # −recarga / −cooldown
		"vacuum": {"pct": [25, 50, 80]},                  # +alcance, fuerza y daño / +reach, pull and damage
		"finger": {"pct": [30, 60, 100]},                 # +daño / +damage
		"teddy": {"pct": [30, 60, 100], "fluff": [1, 1, 2]},  # +daño y pelusa extra / +damage and extra fluff
		"ball": {"pct": [30, 60, 100]},                   # +daño / +damage
		# Muñeco de boxeo: puñetazos de "dmg" y atrae con fuerza "pull" / Boxing dummy: "dmg" punches, "pull" strength
		"laptop": {"dmg": [6, 9, 13], "pull": [60, 90, 130]},
		"boots": {"pct": [30, 60, 100]},                  # +daño de patadas y dash / +kick and dash damage
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
		"ball": {"hp": [10, 18, 28], "pct": [8, 12, 16]},      # +recarga / +cooldown
		# +recarga y −daño, pero una torreta curativa que cura "heal" cada 4 s
		# +cooldown and −damage, but a healing turret that heals "heal" every 4 s
		"laptop": {"hp": [10, 18, 28], "pct": [8, 12, 16], "dmg": [10, 15, 20], "heal": [0.6, 0.9, 1.2]},
		"boots": {"hp": [10, 18, 28], "pct": [8, 12, 16]},     # +recarga de las patadas / +kick cooldown
	},
	## Mr. Ad: "extra" = % de ganar 1 más de Realidad Fragmentada; "per10" = estadística por cada 10 ahorradas
	## Mr. Ad: "extra" = % chance of 1 extra Fragmented Reality; "per10" = stat per 10 saved
	"ad": {
		"bat": {"extra": [20, 35, 50], "per10": [3, 5, 8]},           # +% ataque / +% attack
		"shield": {"extra": [20, 35, 50], "per10": [0.4, 0.7, 1.0]},  # +defensa / +defense
		"book": {"extra": [20, 35, 50], "per10": [3, 5, 8]},          # +% velocidad de ataque / +% attack speed
		"vacuum": {"extra": [20, 35, 50], "per10": [2, 4, 6]},        # +% velocidad / +% speed
		"finger": {"extra": [20, 35, 50], "per10": [2, 3, 5]},        # +suerte / +luck
		"teddy": {"extra": [20, 35, 50], "per10": [0.1, 0.2, 0.3]},  # +regeneración / +regen
		"ball": {"extra": [20, 35, 50], "per10": [0.3, 0.5, 0.8]},    # +parry
		# Torreta de cobro: remata y da "cash" de Realidad Fragmentada / Debt-collector turret: finishes off and gives "cash"
		"laptop": {"extra": [20, 35, 50], "per10": [0, 0, 0], "cash": [1, 2, 3]},
		"boots": {"extra": [20, 35, 50], "per10": [2, 4, 6]},          # +% velocidad / +% speed
	},
	"silly": {
		"bat": {"chance": [8, 15, 25], "secs": [0.5, 0.8, 1.2]},   # congelar / freeze
		"shield": {"chance": [30, 50, 75], "secs": [0.8, 1.4, 2.0]},  # cámara lenta / slow motion
		"book": {"pct": [15, 25, 35]},                    # eco del daño / damage echo
		"vacuum": {"pct": [20, 35, 50], "secs": [0.6, 1.0, 1.6]},  # vulnerable
		"finger": {"chance": [10, 18, 28], "secs": [1.0, 1.5, 2.0]},  # ralentizar / slow
		"teddy": {"pct": [20, 35, 50]},                   # pegados reciben más daño / stuck ones take more damage
		"ball": {"chance": [10, 18, 28], "secs": [0.6, 0.9, 1.3]},  # congelar / freeze
		# +"turrets" de máximo y congelar / +"turrets" maximum and freeze
		"laptop": {"turrets": [1, 1, 2], "chance": [10, 18, 28], "secs": [0.6, 0.9, 1.3]},
		# −"pct" % de recarga del dash y el dash congela "secs" s / −"pct" % dash cooldown and the dash freezes for "secs" s
		"boots": {"pct": [15, 25, 35], "secs": [0.6, 1.0, 1.5]},
	},
	## El Pinche: sangrado (daño residual fuerte) o quemadura (flojo, pero baja su daño y su defensa)
	## The Kitchen Boy: bleed (strong damage over time) or burn (weak, but lowers its damage and defence)
	"pinche": {
		"bat": {"dps": [1.3, 2, 3], "secs": [3, 3.5, 4]},                 # sangrado / bleed
		"shield": {"dps": [1, 1.5, 2], "secs": [3, 4, 5], "pct": [15, 20, 25]},  # quemadura / burn
		"book": {"dps": [1, 1.5, 2], "secs": [3, 4, 5], "pct": [15, 20, 25]},    # quemadura / burn
		"vacuum": {"dps": [1, 1.6, 2.3], "secs": [2, 2.5, 3]},          # sangrado / bleed
		"finger": {"dps": [1, 1.5, 2], "secs": [3, 4, 5], "pct": [15, 20, 25]},  # quemadura / burn
		"teddy": {"dps": [1.3, 2, 3], "secs": [3, 3.5, 4]},               # sangrado / bleed
		"ball": {"dps": [1, 1.6, 2.3], "secs": [2, 2.5, 3]},            # sangrado / bleed
		# Fogón: atrae con fuerza "pull"; con "count" enemigos al lado explota con "boom" de daño
		# Stove: pulls with "pull" strength; with "count" enemies beside it, it explodes for "boom" damage
		"laptop": {"count": [5, 5, 4], "boom": [20, 30, 45], "pull": [50, 70, 90]},
		"boots": {"dps": [1, 1.5, 2], "secs": [3, 4, 5], "pct": [15, 20, 25]},  # quemadura / burn
	},	## SuperK: puñetazo (cada "cd" s baja volando y pega "dmg" con mucho empuje), escudo ("chance" % de
	## parar un golpe, recarga "cd"), láser de los ojos ("dmg" en línea cada "cd" s) y lanzar (agarra a uno
	## y lo tira a un agujero o contra los demás, "dmg")
	## SuperK: punch (every "cd" s he swoops down and hits for "dmg" with a big shove), guard ("chance" %
	## to stop a hit, "cd" cooldown), eye laser ("dmg" in a line every "cd" s) and throw (grabs one and
	## hurls it down a hole or into the others, "dmg")
	"superk": {
		"bat": {"cd": [14.0, 11.0, 8.0], "dmg": [30, 45, 65]},
		"shield": {"chance": [20, 30, 40], "cd": [8.0, 6.0, 4.5]},
		"book": {"cd": [12.0, 9.0, 7.0], "dmg": [14, 20, 28]},
		"vacuum": {"cd": [14.0, 11.0, 8.0], "dmg": [20, 30, 45]},
		"finger": {"cd": [12.0, 9.0, 7.0], "dmg": [14, 20, 28]},
		"teddy": {"chance": [20, 30, 40], "cd": [8.0, 6.0, 4.5]},
		"ball": {"cd": [14.0, 11.0, 8.0], "dmg": [20, 30, 45]},
		"laptop": {"cd": [12.0, 9.0, 7.0], "dmg": [14, 20, 28]},
		"boots": {"cd": [14.0, 11.0, 8.0], "dmg": [30, 45, 65]},
	},
	## Lil Key: baile (cada "cd" s, los de alrededor bailan "secs" s sin hacer daño) o canto (se pone a
	## cantar lejos de ti "secs" s: atrae a los enemigos y les hace "dmg" por segundo)
	## Lil Key: dance (every "cd" s, those around you dance for "secs" s and do no damage) or song (he
	## sings away from you for "secs" s: pulls enemies in and deals "dmg" per second)
	"lilkey": {
		"bat": {"cd": [16.0, 13.0, 10.0], "secs": [3, 4, 5]},
		"shield": {"cd": [16.0, 13.0, 10.0], "secs": [3, 4, 5]},
		"book": {"cd": [15.0, 12.0, 9.0], "secs": [4, 5, 6], "dmg": [2, 3, 4]},
		"vacuum": {"cd": [15.0, 12.0, 9.0], "secs": [4, 5, 6], "dmg": [2, 3, 4]},
		"finger": {"cd": [15.0, 12.0, 9.0], "secs": [4, 5, 6], "dmg": [2, 3, 4]},
		"teddy": {"cd": [16.0, 13.0, 10.0], "secs": [3, 4, 5]},
		"ball": {"cd": [15.0, 12.0, 9.0], "secs": [4, 5, 6], "dmg": [2, 3, 4]},
		"laptop": {"cd": [15.0, 12.0, 9.0], "secs": [4, 5, 6], "dmg": [2, 3, 4]},
		"boots": {"cd": [16.0, 13.0, 10.0], "secs": [3, 4, 5]},
	},
}


## --- Amistad: cada nivel mejora los dones de ese personaje un 6 % (un 30 % al máximo) ---------
## --- Friendship: each level improves that character's gifts by 6% (30% at the most) ---------
const FRIEND_BONUS := 0.06
## Claves que son número de cosas (no se tocan) / Keys that are a count of things (left alone)
const COUNT_KEYS: Array[String] = ["chain", "hits", "fluff", "count", "cash", "turrets"]


func friend_mult(giver: String) -> float:
	return 1.0 + FRIEND_BONUS * Progress.friend_level(giver)


## Aplica la amistad a un valor: sube lo bueno y baja lo malo (recargas y peajes de Doc)
## Applies friendship to a value: raises the good and lowers the bad (cooldowns and Doc's tolls)
func _friendly(giver: String, key: String, v: float) -> float:
	if key in COUNT_KEYS or (key == "extra" and giver != "ad"):
		return v
	var m := friend_mult(giver)
	if key == "cd" or (giver == "doc" and key in ["pct", "dmg"]):
		return v / m
	return v * m


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
## Cada artículo tiene un nivel (1, 2 o 3) y un precio. En el Acto 1 solo hay cosas de nivel 1
## (flojas y baratas); en el 2, sobre todo de nivel 2; en el 3, sobre todo de nivel 3 (las
## mejores y más caras). La amistad con Charo no baja los precios: da cambios gratis,
## ofertas y más huecos en el mostrador.
## Each ware has a tier (1, 2 or 3) and a price. Act 1 only has tier 1 (weak and cheap); Act 2
## mostly tier 2; Act 3 mostly tier 3 (the best and priciest). Friendship with Charo doesn't
## lower prices: it gives free rerolls, offers and more slots on the counter.
const WARES := {
	# Nivel 1 / Tier 1
	"milk": {"tier": 1, "price": 4},          # recupera un 40 % de la vida / restores 40% health
	"candy": {"tier": 1, "price": 4},         # +5 de suerte / +5 luck
	"glasses": {"tier": 1, "price": 5},       # +10 % de alcance / +10% range
	"sneakers": {"tier": 1, "price": 5},      # +6 % de velocidad / +6% speed
	"plasters": {"tier": 1, "price": 4},      # +0,5 de regeneración / +0.5 regen
	# Nivel 2 / Tier 2
	"gum": {"tier": 2, "price": 8},           # estadística rara al azar / random rare stat
	"soda": {"tier": 2, "price": 8},          # +12 % de velocidad de ataque / +12% attack speed
	"stickers": {"tier": 2, "price": 9},      # +2 de parry
	"sandwich": {"tier": 2, "price": 7},      # recupera toda la vida / restores all health
	"battery": {"tier": 2, "price": 10},      # una subida de nivel / one level-up
	"newspaper": {"tier": 2, "price": 12},    # sube de nivel una mejora / levels up an upgrade
	# Nivel 3 / Tier 3
	"gold_sticker": {"tier": 3, "price": 16}, # estadística épica al azar / random epic stat
	"cake": {"tier": 3, "price": 15},         # toda la vida y +5 de vida máxima / all health and +5 max health
	"coin": {"tier": 3, "price": 15},         # +12 de suerte y +1 de parry / +12 luck and +1 parry
	"batteries": {"tier": 3, "price": 18},    # dos subidas de nivel / two level-ups
	"sunday_paper": {"tier": 3, "price": 24}, # dos mejoras suben de nivel / two upgrades level up
}
## Vida máxima que da cada tarta / Max health each cake gives
const CAKE_HP := 5.0
## Peso de cada nivel de artículo en cada acto / Weight of each ware tier in each act
const WARE_TIER_WEIGHT := {1: {1: 1.0}, 2: {1: 1.0, 2: 3.0}, 3: {2: 1.0, 3: 3.0}}
## Lo comprado en esta partida: artículo → cuántos / Bought this run: ware → how many
var bought := {}
## A quién se le ha dado propina en esta partida (solo una por personaje y partida)
## Who has been tipped this run (only one per character per run)
var tipped := {}


func ware_price(id: String) -> int:
	return int(WARES[id]["price"])


## --- Ventajas de la amistad con Charo / Perks of Charo's friendship ---
## Huecos del mostrador: 3, 4 con amistad 3 y 5 con amistad 5
## Counter slots: 3, 4 at friendship 3 and 5 at friendship 5
func shop_slots() -> int:
	var lvl := Progress.friend_level("charo")
	return 3 + (1 if lvl >= 3 else 0) + (1 if lvl >= 5 else 0)


## Cambios gratis por visita: 1 con amistad 1 y 2 con amistad 4 / Free rerolls per visit: 1 at friendship 1, 2 at friendship 4
func shop_free_rerolls() -> int:
	var lvl := Progress.friend_level("charo")
	return (1 if lvl >= 1 else 0) + (1 if lvl >= 4 else 0)


## Probabilidad (en %) de que un artículo salga de oferta (a mitad de precio), desde amistad 2
## Chance (in %) that a ware is on offer (half price), from friendship 2
func shop_offer_chance() -> float:
	var lvl := Progress.friend_level("charo")
	return 0.0 if lvl < 2 else 5.0 + 5.0 * lvl


const OFFER_MULT := 0.5


## Precio de cambiar el mostrador, que sube cada vez / Price of rerolling the counter, which goes up each time
func reroll_price(times: int) -> int:
	return 1 + act() + times


## Mejoras que aún pueden subir de nivel: [[personaje, arma], ...] / Upgrades that can still level up: [[giver, weapon], ...]
func upgradable() -> Array:
	var out := []
	for w in weapons():
		for g: String in _ups(w):
			if level(g, w) > 0 and level(g, w) < MAX_UPGRADE_LEVEL:
				out.append([g, w])
	return out


## Artículos distintos para el kiosco según el acto, sin repetir "avoid" si se puede
## Different wares for the kiosk depending on the act, avoiding "avoid" if possible
func roll_wares(n := 3, avoid: Array = []) -> Array[String]:
	var weights: Dictionary = WARE_TIER_WEIGHT[clampi(act(), 1, 3)]
	var pool := {}
	for w: String in WARES:
		var t: int = WARES[w]["tier"]
		if not weights.has(t):
			continue
		if w in ["newspaper", "sunday_paper"] and upgradable().is_empty():
			continue
		pool[w] = float(weights[t]) * (0.25 if avoid.has(w) else 1.0)
	var out: Array[String] = []
	for i in n:
		if pool.is_empty():
			break
		var total := 0.0
		for w: String in pool:
			total += float(pool[w])
		var r := _rng.randf() * total
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
func roll_offer() -> bool:
	return _rng.randf() * 100.0 < shop_offer_chance()


func _add_stat_bonus(id: String, v: float) -> void:
	stat_bonus[id] = float(stat_bonus.get(id, 0.0)) + v


func _level_random_upgrade() -> void:
	var list := upgradable()
	if not list.is_empty():
		var pick: Array = list[_rng.randi_range(0, list.size() - 1)]
		add_upgrade(pick[0], pick[1])


## Aplica un artículo comprado (curar lo hace la partida) / Applies a bought ware (healing is done by the run)
func apply_ware(id: String) -> void:
	bought[id] = int(bought.get(id, 0)) + 1
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
		"gum", "gold_sticker":
			var rarity := 2 if id == "gum" else 3
			var stat_id: String = STATS[_rng.randi_range(0, STATS.size() - 1)]
			apply_stat({"stat": stat_id, "rarity": rarity, "value": float(STAT_STEPS[stat_id][rarity])})
		"newspaper":
			_level_random_upgrade()
		"sunday_paper":
			_level_random_upgrade()
			_level_random_upgrade()
		"battery":
			pending_ups += 1
		"batteries":
			pending_ups += 2


## Vida que cura un artículo, en fracción de la vida máxima / Health a ware heals, as a fraction of max health
func ware_heal(id: String) -> float:
	match id:
		"milk": return 0.4
		"sandwich", "cake": return 1.0
	return 0.0


## Realidad Fragmentada que da sacrificar una mejora: más cuanto más nivel tiene (8, 12, 16)
## Fragmented Reality a sacrifice gives: more the higher its level (8, 12, 16)
## "before" = el nivel ya se ha restado (se llama después de sacrificar) / the level was already taken away
func sacrifice_value(giver: String, weapon := "", before := false) -> int:
	var lvl := level(giver, weapon) + (1 if before else 0)
	return REALITY_SACRIFICE + REALITY_SACRIFICE * maxi(1, lvl)


## Sacrificar en la chimenea: la mejora pierde un nivel / Sacrificing in the fireplace: the upgrade loses a level
func sacrifice(giver: String, weapon := "") -> void:
	var hp_before := doc_hp()
	var ups := _ups(weapon)
	ups[giver] = int(ups.get(giver, 0)) - 1
	if int(ups[giver]) <= 0:
		ups.erase(giver)
	if giver == "doc" and saved_hp >= 0.0:
		saved_hp -= hp_before - doc_hp()


## Todo lo que el pijama cambia de serie, para enseñarlo en su carta: [{"text", "good"}, ...]
## Everything the pajama changes out of the box, to show on its card: [{"text", "good"}, ...]
func pajama_perks(id: String) -> Array:
	var out := []
	var bonus: Dictionary = WEAPON_BONUS.get(id, {})
	var base: Dictionary = BASE_LEVEL_STATS.get(id, {})
	var vals := []   # [clave de texto, valor] / [text key, value]
	if bonus.has("damage_mult"):
		vals.append(["STATV_ATTACK", roundf(float(bonus["damage_mult"]) * 100.0)])
	if bonus.has("max_hp"):
		vals.append(["STATV_MAX_HP", float(bonus["max_hp"])])
	if bonus.has("armor"):
		vals.append(["STATV_DEFENSE", float(bonus["armor"])])
	if bonus.has("speed"):
		vals.append(["STATV_SPEED", roundf(float(bonus["speed"]) / float(BASE_STATS["speed"]) * 100.0)])
	for st: String in STATS:
		if base.has(st):
			vals.append(["CHIPV_" + st.to_upper() if st in ["regen", "lifesteal"] else "STATV_" + st.to_upper(), float(base[st])])
	# La almohada tiene el tope de parry más alto / The pillow has the highest parry cap
	if id == "shield":
		vals.append(["CHIPV_PARRY_MAX", PARRY_MAX_SHIELD])
	for pair: Array in vals:
		var v: float = pair[1]
		if pair[0] == "CHIPV_PARRY_MAX":
			out.append({"text": tr(pair[0]).format({"v": int(v)}), "good": true})
			continue
		var num := str(int(absf(v))) if is_equal_approx(v, roundf(v)) else str(snappedf(absf(v), 0.1))
		var text := tr(pair[0]).replace("+{v}", ("+" if v > 0.0 else "−") + num)
		out.append({"text": text, "good": v > 0.0})
	return out


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
	# Tartas del kiosco / Kiosk cakes
	s["max_hp"] = float(s["max_hp"]) + CAKE_HP * int(bought.get("cake", 0))
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
