class_name ShopData
extends RefCounted
## Datos del kiosco de Charo y de los tratos de Magnus.
## Data for Charo's kiosk and Magnus's deals.
## GameState los reexpone con el mismo nombre (GameState.X), así que el resto del código no cambia.
## GameState re-exposes them under the same name (GameState.X), so the rest of the code doesn't change.

## --- Kiosco de Charo / Charo's kiosk ------------------------------------------------
## Cada artículo tiene un nivel (1, 2 o 3) y un precio. En el Acto 1 solo hay cosas de nivel 1
## (flojas y baratas); en el 2, sobre todo de nivel 2; en el 3, sobre todo de nivel 3 (las
## mejores y más caras). La amistad con Charo no baja los precios: da cambios gratis,
## ofertas y más huecos en el mostrador.
## Desde el Acto 2 todo cuesta bastante más que en el 1 (el nivel 1 se queda barato).
## Los cachivaches (Trinkets) no suben estadísticas: hacen algo propio en la partida.
## From Act 2 on everything costs a fair bit more than in Act 1 (tier 1 stays cheap).
## Knick-knacks (Trinkets) don't raise stats: they do something of their own in the run.
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
	"rubber_duck": {"tier": 1, "price": 8},   # para el primer golpe de cada sueño / blocks the first hit each dream
	"firecrackers": {"tier": 1, "price": 5},  # estallan cuando te dan / burst when you're hit
	"piggy_bank": {"tier": 1, "price": 9},    # intereses al acabar cada sueño / interest after each dream
	# Nivel 2 / Tier 2
	"gum": {"tier": 2, "price": 11},           # estadística rara al azar / random rare stat
	"soda": {"tier": 2, "price": 11},          # +12 % de velocidad de ataque / +12% attack speed
	"stickers": {"tier": 2, "price": 13},      # +2 de parry
	"sandwich": {"tier": 2, "price": 10},      # recupera toda la vida / restores all health
	"battery": {"tier": 2, "price": 14},      # una subida de nivel / one level-up
	"newspaper": {"tier": 2, "price": 17},    # sube de nivel una mejora / levels up an upgrade
	"water_balloon": {"tier": 2, "price": 14}, # cae un globo que ralentiza / a slowing balloon drops
	"whistle": {"tier": 2, "price": 13},      # curas al tirar enemigos por agujeros / heals on hole falls
	"voodoo": {"tier": 2, "price": 16},       # quien te pega recibe el triple / attackers take triple
	"magnet": {"tier": 2, "price": 11},       # trozos de estrella desde más lejos / shards from further away
	# Nivel 3 / Tier 3
	"gold_sticker": {"tier": 3, "price": 24}, # estadística épica al azar / random epic stat
	"cake": {"tier": 3, "price": 23},         # toda la vida y +5 de vida máxima / all health and +5 max health
	"coin": {"tier": 3, "price": 23},         # +12 de suerte y +1 de parry / +12 luck and +1 parry
	"batteries": {"tier": 3, "price": 27},    # dos subidas de nivel / two level-ups
	"sunday_paper": {"tier": 3, "price": 36}, # dos mejoras suben de nivel / two upgrades level up
	"matches": {"tier": 3, "price": 26},      # las muertes a veces queman a los de al lado / kills sometimes burn neighbours
	"alarm_clock": {"tier": 3, "price": 26},  # con poca vida congela a los de alrededor / at low health freezes those around
	"pinata": {"tier": 3, "price": 28},       # los élites sueltan objeto y Realidad / elites drop an item and Reality
	# Nivel 4 (Acto 4, la Metrópolis): lo mejor y lo más caro / Tier 4 (Act 4, the Metropolis): the best and priciest
	"energy_drink": {"tier": 4, "price": 35}, # +20 % de velocidad de ataque y +8 % de velocidad / +20% attack speed and +8% speed
	"lucky_cat": {"tier": 4, "price": 38},    # +20 de suerte y +2 de parry / +20 luck and +2 parry
	"first_aid": {"tier": 4, "price": 35},    # toda la vida y +10 de vida máxima / all health and +10 max health
	"comic": {"tier": 4, "price": 45},        # estadística legendaria al azar / random legendary stat
	"encyclopedia": {"tier": 4, "price": 54}, # dos mejoras suben de nivel y una subida de nivel / two upgrades level up and one level-up
	"snow_globe": {"tier": 4, "price": 42},   # al subir de nivel congela la pantalla / levelling up freezes the screen
	"music_box": {"tier": 4, "price": 48},    # duerme a los de alrededor cada poco / puts nearby enemies to sleep now and then
}


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
