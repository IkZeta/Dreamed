extends Node
## Datos compartidos entre escenas: atuendos de Kroker, armas y la elección.
## Data shared between scenes: Kroker's outfits, weapons and the player's pick.

const CHARACTERS := RunData.CHARACTERS
## Logro que desbloquea cada pijama nuevo / Achievement that unlocks each new pajama
const WEAPON_UNLOCK := {"finger": "finger", "teddy": "teddy", "ball": "ball", "laptop": "laptop", "boots": "boots", "druid": "druid"}
## Svinho le regala su mejora a nivel 3 a la pelota / Svinho gives the ball his upgrade at level 3
const BALL_SVINHO := 3


func weapon_unlocked(id: String) -> bool:
	return not WEAPON_UNLOCK.has(id) or Progress.has_achieved(WEAPON_UNLOCK[id])

## Estadísticas base de Kroker y lo que suma cada arma.
## Kroker's base stats and what each weapon adds.
const BASE_STATS := {"max_hp": 20.0, "speed": 300.0, "damage_mult": 1.0, "armor": 0.0}
const WEAPON_BONUS := RunData.WEAPON_BONUS

## Definición de cada sueño del Acto 1 (la habitación). "mix" es el peso de cada enemigo al
## aparecer. Cada piso trae un enemigo nuevo más peligroso; el 5 es el jefe.
## Definition of each dream in Act 1 (the bedroom). "mix" is each enemy's spawn weight.
## "shop_met": Charo abre aquí el kiosco, pero solo si ya la conoces del salón.
## "shop_met": Charo opens her kiosk here, but only once you've met her in the living room.
## Every floor brings a new, more dangerous enemy; floor 5 is the boss.
## Qué hace El Pinche con cada arma / What the Kitchen Boy does with each weapon
const PINCHE_KIND := {"bat": "bleed", "shield": "burn", "book": "burn", "vacuum": "bleed", "finger": "burn", "teddy": "bleed", "ball": "bleed", "laptop": "bleed", "boots": "burn", "druid": "bleed"}

const WAVES := RunData.WAVES
## Primer sueño de cada acto / First dream of each act
const ACT2_START := 6
const ACT3_START := 11
const ACT4_START := 16
const FINAL_DREAM := 20
## Estéticas de la Metrópolis: cada sueño del Acto 4 tiene una (sin repetir en la partida)
## Metropolis looks: each Act 4 dream has one (no repeats within the run)
const CITY_STYLES: Array[String] = ["synthwave", "steampunk", "cheese", "aero", "solarpunk", "dieselpunk", "brutalist"]
## Armas cuerpo a cuerpo y a distancia: la segunda arma tiene que ser del otro tipo
## Melee and ranged weapons: the second weapon must be of the other kind
const MELEE: Array[String] = ["bat", "shield", "teddy", "boots", "druid"]
const RANGED: Array[String] = ["book", "vacuum", "finger", "ball", "laptop"]

## Personajes del plano astral y el tipo de mejora que da cada uno.
## Astral plane characters and the kind of upgrade each one gives.
const GIVERS: Array[String] = ["svinho", "stolk", "silly", "doc", "ad", "pinche", "superk", "lilkey", "lynx"]
const HELPER_POWER := UpgradeData.HELPER_POWER


## Poder de SuperK o Lil Key con esta arma ("" si no es uno de ellos) / SuperK's or Lil Key's power with this weapon ("" if it isn't one of them)
static func helper_power(giver: String, weapon: String) -> String:
	return HELPER_POWER.get(giver, {}).get(weapon, "")
const MAX_UPGRADE_LEVEL := 3
## Nivel legendario: un cuarto nivel para un personaje que no tiene mejora dúo con esa arma.
## Sale con amistad LEGEND_FRIEND y su mejora al 3. Los números siguen la subida de los niveles
## anteriores (más grande), sin empeorar las pegas.
## Legendary level: a fourth level for a character who has no duo upgrade with that weapon. It
## shows up at friendship LEGEND_FRIEND with their upgrade at 3. The numbers follow the previous
## levels' rise (bigger), without worsening the downsides.
const LEGEND_LEVEL := 4
const LEGEND_FRIEND := 5
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
const STAT_STEPS := RunData.STAT_STEPS
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
## Tiempo eligiendo (mejoras, dones, tienda, diálogos) frente al de pelea (run_time); sale en el diario
## Time spent choosing (upgrades, gifts, shop, dialogue) versus fighting (run_time); shown in the diary
var choose_time := 0.0
## Para la pantalla de resultados: daño por arma, mejor caída en cadena y los récords de antes de
## empezar (para marcar los nuevos) / For the results screen: damage per weapon, best fall chain and
## the records from before starting (to mark the new ones)
var run_dmg := {}
var run_best_chain := 0
var records_before := {}
const RECORDS := ["best_depth", "best_kills", "fall_chain", "best_level"]
var run_kills := 0
var run_hits := 0
var run_falls := 0      # enemigos tirados por agujeros / enemies pushed down holes
var run_elites := 0     # élites derrotados / elites defeated
## Kroker lleva las gafas de sol de la taquilla durante toda esta partida / Kroker wears the locker sunglasses for this whole run
var run_shades := false
## D. Lynx ya ha dado su "toma 2" en esta partida / D. Lynx has already given his "take 2" this run
var lynx_retake_used := false
## Mejoras dúo que tiene esta partida (ids de DUOS) y tratos de Magnus ganados
## Duo upgrades this run has (DUOS ids) and Magnus deals won
var duos: Array = []
## Combos que ya se han anunciado en esta partida / Combos already announced this run
var combos_seen: Array = []
## Pegatinas nuevas del álbum ganadas en esta partida: [[tipo, id], ...] / New album stickers won this run
var new_stickers: Array = []
## Lo último que le hizo daño (id del bestiario, "bleed"...) / The last thing that hurt him (bestiary id, "bleed"...)
var last_hit := ""
var run_deals_won := 0
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
const REALITY_SACRIFICE := 8


## --- Modo Dios (para probar) / God mode (for testing) ----------------------------
## Partida de entrenamiento con el muñeco del plano astral / Training run with the astral plane's dummy
var training := false
## Dónde aparece Kroker al volver al plano astral: "" (al entrar), "fountain" o "training"
## Where Kroker appears when coming back to the astral plane: "" (on entering), "fountain" or "training"
var hub_spawn := ""
var god_mode := false
## Bot de pruebas: no muere, cuenta cuántas veces habría muerto / Test bot: doesn't die, counts how often it would have
var bot_immortal := false
var bot_deaths := 0
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
	if not god_mode and pacts_unlocked():
		pacts = pact_pick().duplicate()
	gift_ball()


## --- Fiebre: pactos opcionales antes de soñar (como el Pacto de Castigo de Hades) -------
## --- Fever: optional pacts before dreaming (like Hades' Pact of Punishment) --------------
## Cada pacto pone el sueño más difícil y sube la fiebre (grados). A cambio, cada grado da más
## trozos de estrella y Realidad, y se guarda la fiebre más alta con la que superas cada acto.
## Each pact makes the dream harder and raises the fever (degrees). In exchange, every degree gives
## more star shards and Reality, and the highest fever you clear each act with is recorded.
const PACTS := {
	"crowd": 2,     # +30 % enemigos / +30% enemies
	"swift": 1,     # enemigos +18 % más rápidos / enemies 18% faster
	"brutal": 2,    # los enemigos pegan un 30 % más / enemies hit 30% harder
	"fragile": 1,   # -25 % vida máxima / -25% max health
	"dry": 2,       # la curación continua rinde la mitad / continuous healing is worth half
	"titans": 2,    # jefes con +35 % de vida / bosses with +35% health
	"no_kiosk": 1,  # Charo no abre el kiosco / Charo doesn't open her kiosk
	"solo": 2,      # sin segunda arma / no second weapon
}
const PACT_ORDER: Array[String] = ["crowd", "swift", "brutal", "fragile", "dry", "titans", "no_kiosk", "solo"]
## Más trozos de estrella por grado / More star shards per degree
const FEVER_SHARDS := 0.08
## Pactos de esta partida / This run's pacts
var pacts: Array = []
## Fecha del sueño del día ("" si es una partida normal) / Date of the daily dream ("" for a normal run)
var daily := ""


func pact(id: String) -> bool:
	return id in pacts


func fever() -> int:
	var f := 0
	for id: String in pacts:
		f += int(PACTS.get(id, 0))
	return f


## Temperatura de Kroker con la fiebre puesta / Kroker's temperature with the fever on
func fever_temp(f := -1) -> String:
	return "%.1f °C" % (36.6 + 0.4 * float(fever() if f < 0 else f))


## Pactos elegidos en la fuente (se recuerdan entre partidas) / Pacts picked at the fountain (remembered between runs)
func pact_pick() -> Array:
	return Progress.stats.get("pact_pick", [])


func toggle_pact(id: String) -> void:
	var pick: Array = pact_pick().duplicate()
	if id in pick:
		pick.erase(id)
	else:
		pick.append(id)
	Progress.stats["pact_pick"] = pick
	Progress.save_progress()


## Los pactos se desbloquean al superar el Acto 1 / Pacts unlock after clearing Act 1
func pacts_unlocked() -> bool:
	return Progress.any_cleared()


## --- Sueño del día: misma semilla, pijama y pactos para todos ese día ---------------------
## --- Daily dream: same seed, pajama and pacts for everyone that day -------------------------
func today() -> String:
	return Time.get_date_string_from_system()


## Pijama y pactos del sueño de hoy (salen de la fecha) / Today's dream pajama and pacts (from the date)
func daily_setup(date := "") -> Dictionary:
	if date == "":
		date = today()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("dreamed-" + date)
	var pool: Array[String] = []
	for w: String in MELEE + RANGED:
		if weapon_unlocked(w):
			pool.append(w)
	var weapon: String = pool[rng.randi() % pool.size()] if not pool.is_empty() else "bat"
	var options: Array = PACT_ORDER.duplicate()
	options.erase("solo")
	var picked: Array = []
	for i in 2 + rng.randi() % 2:
		var id: String = options[rng.randi() % options.size()]
		options.erase(id)
		picked.append(id)
	return {"date": date, "weapon": weapon, "pacts": picked}


## Semilla de cada sueño en el sueño del día / Each dream's seed in the daily dream
func seed_dream(depth: int) -> void:
	if daily != "":
		seed(hash("dreamed-" + daily) + depth * 7919)


func start_daily() -> void:
	var d := daily_setup()
	god_mode = false
	difficulty = "normal"
	selected_character = d["weapon"]
	start_run()
	daily = d["date"]
	pacts = d["pacts"].duplicate()


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
	"pending_ups", "difficulty", "run_time", "choose_time", "run_kills", "run_hits", "saved_hp", "stat_bonus", "reality", "bought", "tipped", "run_falls", "run_elites", "invest", "run_shades", "city_styles", "lynx_retake_used", "duos", "run_deals_won", "combos_seen", "new_stickers", "run_dmg", "run_best_chain", "records_before", "pacts", "daily"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	if sc is Run:
		var r := sc as Run
		if not r.running and r.player != null and r.player.alive and r.get("_overlay") == null:
			choose_time += delta
	elif sc.scene_file_path.ends_with("astral_plane.tscn"):
		choose_time += delta


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
	choose_time = 0.0
	run_dmg = {}
	run_best_chain = 0
	pacts = []
	daily = ""
	records_before = {}
	for k in RECORDS:
		records_before[k] = int(Progress.stats.get(k, 0))
	run_shades = false
	lynx_retake_used = false
	duos = []
	combos_seen = []
	new_stickers = []
	last_hit = ""
	run_deals_won = 0
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


const BASE_LEVEL_STATS := RunData.BASE_LEVEL_STATS
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
	# El último sueño siempre es noir retrofuturista / The last dream is always retro-futurist noir
	if depth >= FINAL_DREAM:
		return "noir"
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
	if n > 0:
		Progress.tip("reality")


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
	return (1.5 if difficulty == "nightmare" else 1.0) * [1.0, 1.0, 1.2, 1.4, 1.55][act()] * (1.3 if pact("brutal") else 1.0)


func shard_mult() -> float:
	return (1.5 if difficulty == "nightmare" else 1.0) * (1.0 + FEVER_SHARDS * fever())


## Regeneración que de verdad cura: a partir de 1,5 rinde el 40 %, para no ser inmortal
## Regeneration that actually heals: above 1.5 it's worth 40%, so you can't be immortal
const REGEN_SOFT_CAP := 1.5


func regen_effective() -> float:
	var r := stat("regen")
	return r if r <= REGEN_SOFT_CAP else REGEN_SOFT_CAP + (r - REGEN_SOFT_CAP) * 0.4


## Robo de salud que cuenta: a partir de 8 rinde la mitad / Life steal that counts: above 8 it's worth half
const STEAL_SOFT_CAP := 8.0


func lifesteal_effective() -> float:
	var l := stat("lifesteal")
	return l if l <= STEAL_SOFT_CAP else STEAL_SOFT_CAP + (l - STEAL_SOFT_CAP) * 0.5


## Defensa que cuenta: a partir de 6 rinde la mitad / Defence that counts: above 6 it's worth half
const DEFENSE_SOFT_CAP := 6.0


func armor_effective(a: float) -> float:
	return a if a <= DEFENSE_SOFT_CAP else DEFENSE_SOFT_CAP + (a - DEFENSE_SOFT_CAP) * 0.5


## Curación continua (regeneración y robo de salud) que cabe por segundo, con un pequeño colchón.
## Sin esto, con defensa alta los golpes flojos quitaban menos de lo que se curaba y no se moría nunca.
## Continuous healing (regeneration and life steal) allowed per second, with a small buffer.
## Without it, with high defence weak hits took off less than was healed and you never died.
const SUSTAIN_PER_SEC := 0.5
const SUSTAIN_BUFFER := 3.0


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
const AD_STAT := {"bat": "attack", "shield": "defense", "book": "attack_speed", "vacuum": "speed", "finger": "luck", "teddy": "regen", "ball": "parry", "laptop": "attack_speed", "boots": "speed", "druid": "attack"}
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
	_apply_stat(choice)
	check_combos()


func _apply_stat(choice: Dictionary) -> void:
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


## ¿Tiene este personaje mejora dúo con esa arma? / Does this character have a duo upgrade with that weapon?
func has_duo_with(giver: String, weapon: String) -> bool:
	for id: String in DUOS:
		var d: Dictionary = DUOS[id]
		if d["weapon"] == weapon and (d["a"] == giver or d["b"] == giver):
			return true
	return false


## ¿Se le puede ofrecer el nivel legendario? (la segunda arma nunca tiene dúo)
## Can the legendary level be offered? (the second weapon never has a duo)
func legend_ok(giver: String, weapon := "") -> bool:
	if weapon == "":
		weapon = selected_character
	if giver == "magnus" or Progress.friend_level(giver) < LEGEND_FRIEND:
		return false
	return not (weapon == selected_character and has_duo_with(giver, weapon))


## Nivel máximo que puede llegar a tener ahora / Highest level it can reach right now
func max_level(giver: String, weapon := "") -> int:
	return LEGEND_LEVEL if legend_ok(giver, weapon) else MAX_UPGRADE_LEVEL


func add_upgrade(giver: String, weapon := "") -> void:
	var hp_before := doc_hp()
	var ups := _ups(weapon)
	ups[giver] = mini(max_level(giver, weapon), int(ups.get(giver, 0)) + 1)
	if int(ups[giver]) >= LEGEND_LEVEL:
		Progress.flag("legend")
		if not god_mode and Progress.sticker("legend", giver):
			new_stickers.append(["legend", giver])
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
			if level(g, w) < max_level(g, w):
				pool.append(g)
				break
	# Magnus no da mejoras de arma: sale si se le puede pagar / Magnus gives no weapon upgrade: he shows up if you can pay him
	if MagnusDeals.magnus_available():
		pool.append("magnus")
	# Mejora dúo lista: sale casi seguro / A duo upgrade ready: it shows up almost surely
	if duo_ready() != "":
		pool.append("duo")
	# Con suerte es más fácil que vuelva alguien que ya te ha dado un don, para subirlo de nivel
	# With luck, someone who already gave you a gift is likelier to return, to level it up
	var out: Array[String] = []
	if GUIDE_COMBOS and active_combos().is_empty():
		for g in pool:
			if g in ["magnus", "duo"]:
				continue
			var hit := false
			for w in weapons():
				if level(g, w) < max_level(g, w) and not combos_completed_by(g, w).is_empty():
					hit = true
			if hit:
				out.append(g)
				pool.erase(g)
				break
	while out.size() < offer_size():
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
	if g == "duo":
		return 6.0
	return 1.0 + (stat("luck") / 20.0 if best_level(g) > 0 else 0.0)


## --- Mejoras dúo / Duo upgrades -------------------------------------------------------
## Cada personaje tiene una pareja y la mejora dúo va con un arma concreta. Solo cuenta el arma
## principal (no la segunda que se consigue al final del Acto 2). Se desbloquea con amistad 3 con
## los dos, y sale en partida cuando las mejoras de los dos con esa arma están al máximo (Magnus no
## da mejoras de arma: él está "al máximo" tras ganar DUO_MAGNUS_DEALS tratos en la partida).
## Every character has a partner and the duo upgrade goes with one specific weapon. Only the main
## weapon counts (not the second one you get at the end of Act 2). It unlocks with friendship 3
## with both, and shows up in a run once both of their upgrades for that weapon are maxed (Magnus
## gives no weapon upgrades: he's "maxed" after winning DUO_MAGNUS_DEALS deals in the run).
const DUO_FRIEND := 3
const DUO_MAGNUS_DEALS := 2
const DUOS := UpgradeData.DUOS
const DUO_VALUES := UpgradeData.DUO_VALUES


static func duo_value(id: String, key: String) -> float:
	return float(DUO_VALUES[id][key])


func has_duo(id: String) -> bool:
	return id in duos


## Desbloqueado para siempre (amistad 3 con los dos) / Unlocked for good (friendship 3 with both)
func duo_unlocked(id: String) -> bool:
	var d: Dictionary = DUOS[id]
	for g: String in [d["a"], d["b"]]:
		if not giver_unlocked(g) or Progress.friend_level(g) < DUO_FRIEND:
			return false
	return true


func _duo_maxed(g: String, weapon: String) -> bool:
	if g == "magnus":
		return run_deals_won >= DUO_MAGNUS_DEALS
	return level(g, weapon) >= MAX_UPGRADE_LEVEL


## El dúo que se puede ofrecer ahora ("" si ninguno) / The duo that can be offered now ("" if none)
func duo_ready() -> String:
	for id: String in DUOS:
		var d: Dictionary = DUOS[id]
		if has_duo(id) or d["weapon"] != selected_character or not duo_unlocked(id):
			continue
		if _duo_maxed(d["a"], selected_character) and _duo_maxed(d["b"], selected_character):
			return id
	return ""


func add_duo(id: String) -> void:
	if not has_duo(id):
		duos.append(id)
		Progress.flag("duo")
		if not god_mode and Progress.sticker("duo", id):
			new_stickers.append(["duo", id])


func duo_desc(id: String) -> String:
	var vals := {}
	for k: String in DUO_VALUES[id]:
		var v := float(DUO_VALUES[id][k])
		vals[k] = str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)
	return tr("DUO_%s_DESC" % id.to_upper()).format(vals)


const RANGED_W := UpgradeData.RANGED_W
const COMBOS := UpgradeData.COMBOS
## Estallido de píxeles: daño y radio / Pixel burst: damage and radius
const PIXEL_BURST_DMG := 6.0
const PIXEL_BURST_RADIUS := 130.0
## Combos guiados: mientras la partida no tenga ningún combo, si una mejora del plano astral
## completaría uno, ese personaje sale seguro (así se descubren pronto)
## Guided combos: while the run has no combo, if an astral upgrade would complete one, that
## character is sure to show up (so they're discovered early)
const GUIDE_COMBOS := true


## ¿Se cumple el requisito? "plus" = mejora que estás a punto de coger ([personaje, arma])
## Is the requirement met? "plus" = upgrade you're about to take ([giver, weapon])
func _combo_need(n: Dictionary, plus: Array) -> bool:
	if n.has("stat"):
		return stat(n["stat"]) >= float(n["min"])
	if n.has("weapon"):
		return n["weapon"] in weapons()
	var g: String = n["g"]
	if g == "magnus":
		return not invest.is_empty() or run_deals_won > 0 or (not plus.is_empty() and plus[0] == "magnus")
	for w in weapons():
		var has: bool = level(g, w) > 0 or (not plus.is_empty() and plus[0] == g and plus[1] == w)
		if not has:
			continue
		if n.has("w") and not (w in n["w"]):
			continue
		if n.has("power") and helper_power(g, w) != n["power"]:
			continue
		return true
	return false


func combo_active(id: String, plus: Array = []) -> bool:
	for n: Dictionary in COMBOS[id]["needs"]:
		if not _combo_need(n, plus):
			return false
	return true


func active_combos() -> Array[String]:
	var out: Array[String] = []
	for id: String in COMBOS:
		if combo_active(id):
			out.append(id)
	return out


## Combos que se completarían al coger esta mejora / Combos that taking this upgrade would complete
func combos_completed_by(giver: String, weapon: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in COMBOS:
		if not combo_active(id) and combo_active(id, [giver, weapon]):
			out.append(id)
	return out


## Anuncia los combos nuevos que se hayan completado / Announces any newly completed combos
func check_combos() -> void:
	for id in active_combos():
		if id in combos_seen:
			continue
		combos_seen.append(id)
		if not god_mode and Progress.sticker("combo", id):
			new_stickers.append(["combo", id])
		Progress.note(tr("COMBO_NEW"), "[b]%s[/b] · %s" % [tr("COMBO_%s_NAME" % id.to_upper()), tr("COMBO_%s_DESC" % id.to_upper())], Color("ff9ad0"), 5.0)


## Mr. Ad aparece desde que se llega al Acto 2 por primera vez y El Pinche desde el Acto 3
## Mr. Ad shows up once Act 2 has been reached, and the Kitchen Boy once Act 3 has
func giver_unlocked(g: String) -> bool:
	match g:
		"ad": return Progress.has_achieved("mr_ad")
		"pinche": return Progress.has_achieved("pinche")
		"magnus": return Progress.has_achieved("magnus")
		"superk": return Progress.has_achieved("superk")
		"lilkey": return Progress.has_achieved("lilkey")
		"lynx": return Progress.has_achieved("lynx")
	return true


const INVEST_SIZES := ShopData.INVEST_SIZES
const INVEST_GOALS := ShopData.INVEST_GOALS
## Inversión en curso (vacía si no hay) / Investment in progress (empty if none)
var invest := {}


## Clave de traducción del nombre o la descripción de una mejora / Translation key of an upgrade's name or description
func upgrade_key(giver: String, weapon: String, part: String) -> String:
	var power := helper_power(giver, weapon)
	if power != "":
		return "UP_%s_%s_%s" % [giver.to_upper(), power.to_upper(), part]
	return "UP_%s_%s_%s" % [giver.to_upper(), weapon.to_upper(), part]


const UPGRADE_VALUES := UpgradeData.UPGRADE_VALUES


## Lo que recorta D. Lynx de cada sueño (0..0.5) / How much D. Lynx trims off each dream (0..0.5)
func lynx_cut() -> float:
	var total := 0.0
	for w in weapons():
		if helper_power("lynx", w) == "cut":
			total += up_value("lynx", "pct", -1, w)
	return clampf(total / 100.0, 0.0, 0.5)


## La "toma 2" de D. Lynx, si queda: {"hp", "inv"} o vacío / D. Lynx's "take 2", if there's one left: {"hp", "inv"} or empty
func lynx_retake() -> Dictionary:
	if lynx_retake_used:
		return {}
	var best := {}
	for w in weapons():
		if helper_power("lynx", w) == "retake" and level("lynx", w) > 0:
			var hp := up_value("lynx", "hp", -1, w)
			if best.is_empty() or hp > float(best["hp"]):
				best = {"hp": hp, "inv": up_value("lynx", "inv", -1, w)}
	return best


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
	if lvl > values.size():
		return _friendly(giver, key, _legend_value(giver, key, values))
	return _friendly(giver, key, float(values[lvl - 1]))


## El valor legendario: sigue la subida del último nivel, una vez y media más grande. Las cosas que
## se cuentan suben al menos 1; las recargas bajan como mucho un 30 %; las pegas de Doc no empeoran.
## The legendary value: follows the last level's rise, one and a half times bigger. Counted things
## go up by at least 1; cooldowns drop by 30% at most; Doc's downsides don't get worse.
func _legend_value(giver: String, key: String, values: Array) -> float:
	var v3 := float(values[values.size() - 1])
	var v2 := float(values[values.size() - 2]) if values.size() > 1 else v3
	var v1 := float(values[0])
	if giver == "doc" and key in ["pct", "dmg"]:
		return v3
	var step := v3 - v2
	if is_zero_approx(step):
		step = (v3 - v1) * 0.5
	if key in COUNT_KEYS or key == "extra" and giver != "ad":
		if is_zero_approx(step):
			return v3 + (1.0 if v3 > 0.0 else 0.0)
		return v3 + signf(step) * maxf(1.0, roundf(absf(step)))
	if is_zero_approx(step):
		return v3 * 1.25
	var v4 := v3 + step * 1.5
	if key == "cd":
		return maxf(v3 * 0.7, v4)
	if key in ["chance", "hp"]:
		return minf(v4, 100.0)
	return snappedf(v4, 0.1)


## Descripción traducida con los números del nivel indicado / Translated description with that level's numbers
func upgrade_desc(giver: String, weapon: String, lvl: int) -> String:
	var vals := {}
	for key: String in UPGRADE_VALUES[giver][weapon]:
		var v := up_value(giver, key, lvl, weapon)
		vals[key] = str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.1))
	return tr(upgrade_key(giver, weapon, "DESC")).format(vals)


const WARES := ShopData.WARES
## Vida máxima que da cada tarta / Max health each cake gives
const CAKE_HP := 5.0
## Peso de cada nivel de artículo en cada acto / Weight of each ware tier in each act
const WARE_TIER_WEIGHT := {1: {1: 1.0}, 2: {1: 1.0, 2: 3.0}, 3: {2: 1.0, 3: 3.0}, 4: {3: 1.0, 4: 3.0}}
## Vida máxima que da cada botiquín / Max health each first-aid kit gives
const FIRST_AID_HP := 10.0
## Lo comprado en esta partida: artículo → cuántos / Bought this run: ware → how many
var bought := {}
## A quién se le ha dado propina en esta partida (solo una por personaje y partida)
## Who has been tipped this run (only one per character per run)
var tipped := {}


const OFFER_MULT := 0.5


## Todo lo que el pijama cambia de serie, para enseñarlo en su carta: [{"text", "good"}, ...]
## Everything the pajama changes out of the box, to show on its card: [{"text", "good"}, ...]
## Golpe fuerte: cada N golpes, uno empuja lo bastante para tirar enemigos por los agujeros. Así
## todas las armas tienen una forma de usar los agujeros (la almohada y la aspiradora ya la tienen).
## Heavy hit: every N hits, one shoves hard enough to throw enemies down holes. This way every weapon
## has a way to use the holes (the pillow and the vacuum already have one).
const HEAVY_EVERY := {"bat": 3, "book": 5, "finger": 5, "teddy": 3, "laptop": 5, "ball": 3, "boots": 3, "druid": 3}
const HEAVY_KNOCK := 520.0
## Caídas en cadena: tirar a varios seguidos (con menos de este hueco) da trozos de estrella extra
## Fall chains: throwing several in a row (with less than this gap) gives extra star shards
const FALL_CHAIN_GAP := 3.0
const FALL_CHAIN_MAX := 5


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
	if HEAVY_EVERY.has(id):
		vals.append(["CHIPV_HEAVY", float(HEAVY_EVERY[id])])
	for pair: Array in vals:
		var v: float = pair[1]
		if pair[0] == "CHIPV_HEAVY":
			out.append({"text": tr(pair[0]).format({"n": int(v)}), "good": true})
			continue
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
	# Dúo Stolk y Doc: el Doc le cura la factura / Stolk & Doc duo: Doc covers the bill
	if has_duo("stolk_doc"):
		stolk -= level("stolk", selected_character)
	s["max_hp"] = maxf(5.0, float(s["max_hp"]) - STOLK_HP_COST * stolk)
	# Doc: suma vida máxima; con la aspiradora cuesta velocidad / Doc: adds max health; with the vacuum it costs speed
	s["max_hp"] = float(s["max_hp"]) + doc_hp()
	# Tartas del kiosco / Kiosk cakes
	s["max_hp"] = float(s["max_hp"]) + CAKE_HP * int(bought.get("cake", 0)) + FIRST_AID_HP * int(bought.get("first_aid", 0))
	if "vacuum" in weapons():
		s["speed"] = float(s["speed"]) * (1.0 - up_value("doc", "pct", -1, "vacuum") / 100.0)
	# Estadísticas ganadas al subir de nivel / Stats gained by levelling up
	s["damage_mult"] = float(s["damage_mult"]) + stat("attack") / 100.0
	s["armor"] = armor_effective(float(s["armor"]) + stat("defense"))
	s["speed"] = float(s["speed"]) * (1.0 + stat("speed") / 100.0)
	if pact("fragile"):
		s["max_hp"] = maxf(5.0, roundf(float(s["max_hp"]) * 0.75))
	return s


func change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
