class_name UpgradeData
extends RefCounted
## Datos de las mejoras del plano astral: valores por nivel, poderes de ayudante, dúos y combos.
## Astral-plane upgrade data: per-level values, helper powers, duos and combos.
## GameState los reexpone con el mismo nombre (GameState.X), así que el resto del código no cambia.
## GameState re-exposes them under the same name (GameState.X), so the rest of the code doesn't change.

## --- Combos (sinergias) / Combos (synergies) ----------------------------------------------
## Mejoras que se ayudan entre sí. No dan nada extra: es que juntas funcionan mejor, y el juego te
## lo enseña. Cada requisito: personaje ("g") con nivel en alguna de las armas ("w", vacío = cualquiera)
## o con ese poder ("power"); "stat" pide un mínimo de estadística; "weapon" pide llevar esa arma.
## Upgrades that help each other. They give nothing extra: they just work better together, and the
## game shows you. Each requirement: a giver ("g") with a level on any of the weapons ("w", empty =
## any) or with that power ("power"); "stat" asks for a stat minimum; "weapon" asks for that weapon.
const RANGED_W := ["book", "finger", "laptop", "ball", "vacuum"]


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
		# Zarpazos, garras y picotazos saltan a "extra" enemigos más con "pct" % del daño
		"druid": {"extra": [1, 2, 3], "pct": [35, 45, 55]},
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
		"druid": {"pct": [30, 60, 100]},                  # +daño de todas las formas / +damage in every form
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
		"druid": {"hp": [10, 18, 28], "pct": [8, 12, 16]},     # −daño / −damage
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
		"druid": {"extra": [20, 35, 50], "per10": [3, 5, 8]},          # +% ataque / +% attack
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
		# Al cambiar de forma, "chance" % de congelar "secs" s a los de alrededor / On shifting, "chance" % to freeze those around for "secs" s
		"druid": {"chance": [40, 65, 90], "secs": [0.8, 1.2, 1.8]},
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
		"druid": {"dps": [1.3, 2, 3], "secs": [3, 3.5, 4]},               # sangrado / bleed
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
		"druid": {"cd": [14.0, 11.0, 8.0], "dmg": [30, 45, 65]},
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
		"druid": {"cd": [16.0, 13.0, 10.0], "secs": [3, 4, 5]},
	},
	## D. Lynx: "¡Acción!" (cada "cd" s, "count" enemigos de alrededor se vuelven actores "secs" s y
	## pegan a los demás con "dmg"), "¡Corten! Toma 2" (una vez por partida, si te matan vuelves con
	## "hp" % de vida y "inv" s sin que te hagan daño) y "Montaje" (los sueños duran "pct" % menos)
	## D. Lynx: "Action!" (every "cd" s, "count" nearby enemies turn into actors for "secs" s and hit
	## the others for "dmg"), "Cut! Take 2" (once per run, if you're killed you come back with "hp" %
	## health and "inv" s of invulnerability) and "Montage" (dreams last "pct" % less)
	"lynx": {
		"bat": {"cd": [18.0, 15.0, 12.0], "count": [2, 3, 4], "secs": [5, 7, 9], "dmg": [6, 9, 13]},
		"boots": {"cd": [18.0, 15.0, 12.0], "count": [2, 3, 4], "secs": [5, 7, 9], "dmg": [6, 9, 13]},
		"druid": {"cd": [18.0, 15.0, 12.0], "count": [2, 3, 4], "secs": [5, 7, 9], "dmg": [6, 9, 13]},
		"vacuum": {"cd": [18.0, 15.0, 12.0], "count": [2, 3, 4], "secs": [5, 7, 9], "dmg": [6, 9, 13]},
		"shield": {"hp": [30, 50, 75], "inv": [2, 3, 4]},
		"teddy": {"hp": [30, 50, 75], "inv": [2, 3, 4]},
		"ball": {"hp": [30, 50, 75], "inv": [2, 3, 4]},
		"book": {"pct": [10, 18, 25]},
		"finger": {"pct": [10, 18, 25]},
		"laptop": {"pct": [10, 18, 25]},
	},
}


## SuperK y Lil Key no cambian el arma: aparecen en el mapa y ayudan. Cada arma tiene uno de sus
## poderes (las armas del mismo poder comparten nombre y descripción).
## SuperK and Lil Key don't change the weapon: they show up on the map and help. Each weapon gets
## one of their powers (weapons with the same power share a name and description).
const HELPER_POWER := {
	"superk": {"bat": "punch", "boots": "punch", "druid": "punch", "shield": "guard", "teddy": "guard",
		"book": "laser", "finger": "laser", "laptop": "laser", "vacuum": "throw", "ball": "throw"},
	"lilkey": {"bat": "dance", "shield": "dance", "teddy": "dance", "boots": "dance", "druid": "dance",
		"book": "sing", "vacuum": "sing", "finger": "sing", "ball": "sing", "laptop": "sing"},
	# D. Lynx: "actor" (enemigos que luchan para ti), "retake" (una vida extra) y "cut" (sueños más cortos)
	# D. Lynx: "actor" (enemies that fight for you), "retake" (an extra life) and "cut" (shorter dreams)
	"lynx": {"bat": "actor", "boots": "actor", "druid": "actor", "vacuum": "actor", "shield": "retake", "teddy": "retake", "ball": "retake",
		"book": "cut", "finger": "cut", "laptop": "cut"},
}


const DUOS := {
	"svinho_silly": {"a": "svinho", "b": "silly", "weapon": "boots"},
	"stolk_doc": {"a": "stolk", "b": "doc", "weapon": "bat"},
	"superk_lilkey": {"a": "superk", "b": "lilkey", "weapon": "shield"},
	"ad_lynx": {"a": "ad", "b": "lynx", "weapon": "laptop"},
	"pinche_magnus": {"a": "pinche", "b": "magnus", "weapon": "book"},
	"svinho_superk": {"a": "svinho", "b": "superk", "weapon": "ball"},
	"silly_lynx": {"a": "silly", "b": "lynx", "weapon": "vacuum"},
	"stolk_magnus": {"a": "stolk", "b": "magnus", "weapon": "finger"},
	"doc_lilkey": {"a": "doc", "b": "lilkey", "weapon": "teddy"},
	"ad_pinche": {"a": "ad", "b": "pinche", "weapon": "druid"},
}


## Valores de cada dúo (las descripciones usan las mismas claves) / Each duo's values (descriptions use the same keys)
const DUO_VALUES := {
	"svinho_silly": {"extra": 1, "secs": 1.0, "pct": 50},
	"stolk_doc": {"heal": 1},
	"superk_lilkey": {"secs": 4, "chance": 10},
	"ad_lynx": {"cd": 20, "secs": 3, "pct": 50, "per": 4, "max": 5},
	"pinche_magnus": {"chance": 30, "spread": 2},
	"svinho_superk": {"hits": 6, "dmg": 40},
	"silly_lynx": {"secs": 1.5, "dur": 6, "max": 3},
	"stolk_magnus": {"crit": 2, "pct": 50, "chance": 15},
	"doc_lilkey": {"heal": 0.3, "max": 1.5},
	"ad_pinche": {"pct": 15, "chance": 35},
}


const COMBOS := {
	"clinic": {"needs": [{"g": "doc"}, {"g": "stolk"}]},
	"capital": {"needs": [{"g": "ad"}, {"g": "magnus"}]},
	"row": {"needs": [{"g": "lilkey", "power": "sing"}, {"g": "svinho", "w": RANGED_W}]},
	"laser_row": {"needs": [{"g": "lilkey", "power": "sing"}, {"g": "superk", "power": "laser"}]},
	"fluffball": {"needs": [{"g": "silly", "w": ["teddy"]}, {"g": "svinho", "w": ["teddy"]}]},
	"suction": {"needs": [{"g": "silly", "w": ["vacuum"]}, {"g": "stolk", "w": ["vacuum"]}]},
	"second_take": {"needs": [{"g": "stolk"}, {"g": "lynx", "power": "retake"}]},
	"lucky_finger": {"needs": [{"weapon": "finger"}, {"stat": "luck", "min": 20.0}]},
	"pillow_wall": {"needs": [{"weapon": "shield"}, {"stat": "parry", "min": 12.0}]},
	"hole": {"needs": [{"g": "superk", "power": "throw"}, {"g": "svinho"}]},
	"bbq": {"needs": [{"g": "pinche", "w": ["laptop"]}, {"g": "lilkey", "power": "sing"}]},
	# Con los personajes del principio y cualquier arma: se puede descubrir en la primera partida
	# With the starting characters and any weapon: it can be discovered in the first run
	"pixel_burst": {"needs": [{"g": "silly"}, {"g": "svinho"}]},
}
