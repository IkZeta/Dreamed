class_name RunData
extends RefCounted
## Datos de la partida: oleadas, pijamas, bonus de cada arma y subidas de nivel.
## Run data: waves, pajamas, each weapon's bonuses and level-ups.
## GameState los reexpone con el mismo nombre (GameState.X), así que el resto del código no cambia.
## GameState re-exposes them under the same name (GameState.X), so the rest of the code doesn't change.

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
	{"duration": 45.0, "spawn_every": 2.2, "group": [2, 3], "max_alive": 11, "mix": {"foox": 2, "thug": 2, "sling": 1, "skeleton": 2, "nest": 1, "botcher": 0.5}, "new": "botcher", "shop": true},
	{"duration": 50.0, "spawn_every": 2.1, "group": [2, 4], "max_alive": 12, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 2, "nest": 1, "cyber": 0.5, "botcher": 0.3}, "new": "cyber", "fire": true},
	{"duration": 55.0, "spawn_every": 2.0, "group": [3, 4], "max_alive": 13, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 3, "nest": 1, "cyber": 0.5, "botcher": 0.3}, "shop": true},
	# Sueño 10: El Chef sale de la tele / Dream 10: The Chef comes out of the TV
	{"boss": true, "boss_kind": "chef", "duration": 120.0, "spawn_every": 3.4, "group": [1, 2], "max_alive": 6, "mix": {"foox": 3, "thug": 1, "sling": 1, "skeleton": 1, "cyber": 0.3}},
	# --- Acto 3: el pasillo infinito del colegio. El 11 trae las Marionetas (poco comunes) y el
	# 13, el Gólem de papel higiénico.
	# --- Act 3: the endless school hallway. Dream 11 brings the Puppets (uncommon) and dream 13
	# the Toilet-Paper Golem.
	{"duration": 45.0, "spawn_every": 2.0, "group": [2, 4], "max_alive": 13, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 2, "nest": 1, "cyber": 0.5, "puppet": 0.7, "botcher": 0.3}, "new": "puppet"},
	{"duration": 50.0, "spawn_every": 1.9, "group": [3, 4], "max_alive": 14, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 3, "nest": 1, "cyber": 0.6, "puppet": 0.8, "botcher": 0.3}, "shop": true},
	{"duration": 55.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 3, "nest": 1, "cyber": 0.6, "puppet": 0.8, "golem": 0.6, "botcher": 0.3}, "new": "golem"},
	{"duration": 60.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"foox": 2, "thug": 2, "sling": 2, "skeleton": 2, "nest": 1, "cyber": 0.7, "puppet": 1.0, "golem": 0.8, "botcher": 0.3}, "shop": true},
	# Sueño 15: el Ovni destroza el pasillo / Dream 15: the UFO wrecks the hallway
	{"boss": true, "boss_kind": "ufo", "duration": 150.0, "spawn_every": 3.6, "group": [1, 2], "max_alive": 7, "mix": {"foox": 3, "thug": 1, "puppet": 1, "skeleton": 1}},
	# --- Acto 4 (el final): la Metrópolis, con una estética distinta en cada sueño. El 16 trae la
	# Unidad Especial (furgo voladora que suelta policías), el 17 los Antidisturbios (salen de los
	# agujeros y ponen escudos a los demás) y el 20 es el último sueño: la ciudad se viene abajo.
	# --- Act 4 (the final one): the Metropolis, with a different look in every dream. Dream 16
	# brings the Special Unit (a flying van that drops police), 17 the Riot Police (they climb out
	# of the holes and shield the others) and 20 is the last dream: the city comes crashing down.
	{"duration": 50.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.6, "puppet": 0.8, "golem": 0.5, "police": 1.2, "van": 0.25, "botcher": 0.3}, "new": "van"},
	{"duration": 55.0, "spawn_every": 1.8, "group": [3, 5], "max_alive": 15, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.6, "puppet": 0.8, "golem": 0.6, "police": 1.4, "van": 0.25, "riot": 0.35, "botcher": 0.3}, "new": "riot", "shop": true},
	{"duration": 60.0, "spawn_every": 1.7, "group": [3, 5], "max_alive": 16, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.7, "puppet": 1.0, "golem": 0.7, "police": 1.6, "van": 0.3, "riot": 0.4, "botcher": 0.3}},
	{"duration": 60.0, "spawn_every": 1.6, "group": [3, 6], "max_alive": 17, "mix": {"thug": 2, "sling": 2, "skeleton": 2, "cyber": 0.8, "puppet": 1.0, "golem": 0.8, "police": 1.8, "van": 0.35, "riot": 0.45, "botcher": 0.3}, "shop": true},
	# Sueño 20, el último: noir retrofuturista. Kroker piensa en voz baja apoyado en una pared,
	# los edificios estallan y llega el jefe final, Evil Ad. La ciudad se derrumba durante la pelea.
	# Dream 20, the last one: retro-futurist noir. Kroker muses leaning on a wall, the buildings
	# blow up and the final boss, Evil Ad, arrives. The city collapses during the fight.
	{"boss": true, "boss_kind": "evil_ad", "duration": 210.0, "spawn_every": 3.2, "group": [1, 2], "max_alive": 8, "mix": {"thug": 2, "sling": 1, "skeleton": 1, "cyber": 0.5, "police": 2.0}, "final": true, "act_end": true},
]


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
