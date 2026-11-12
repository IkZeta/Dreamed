class_name Weapon
extends Node2D
## Base de las armas: atacan solas cada `cooldown` segundos si hay objetivo.
## Weapon base: attacks automatically every `cooldown` seconds when a target exists.

var run: Node     # Run
var player: Player
## Qué arma es y si es la del pijama (true) o la segunda, que flota junto a Kroker (false)
## Which weapon this is and whether it's the pajama's (true) or the second one, floating beside Kroker (false)
var id := "bat"
var primary := true
## Animación propia de la segunda arma (la primera usa las de Kroker) / The second weapon's own animation (the first uses Kroker's)
var anim := 0.0
var cooldown := 1.0
var _timer := 0.4


func _physics_process(delta: float) -> void:
	anim = maxf(0.0, anim - delta * 3.0)
	if not run.running or not player.alive:
		return
	# Con el mal olor del Gólem esta arma no ataca / With the Golem's stench this weapon doesn't attack
	if player.weapon_stunk(self):
		return
	_timer -= delta * speed_mult()
	if _timer <= 0.0 and attack():
		_timer = cooldown


## Barras de carga que se dibujan bajo Kroker: [[fracción 0..1, color], ...]
## Charge bars drawn under Kroker: [[fraction 0..1, colour], ...]
func charge_bars() -> Array:
	return [[1.0 - clampf(_timer / maxf(cooldown, 0.01), 0.0, 1.0), UITheme.BONE]]


## Dónde se dibuja el anillo de carga, relativo a Kroker (ya girado según hacia dónde mira).
## Where the charge ring is drawn, relative to Kroker (already flipped by facing).
func charge_anchor() -> Vector2:
	if not primary:
		return second_anchor()
	if hand() == "l" and KrokerArt.hand_of(id) == "r":
		return Vector2(-30.0 * player._facing, -40.0)
	return Vector2(26.0 * player._facing, -42.0)


## La segunda arma va en la mano libre: su anillo sale de ese lado
## The second weapon is in the free hand: its ring sits on that side
func second_anchor() -> Vector2:
	var side := 1.0 if hand() == "r" else -1.0
	return Vector2(30.0 * side * player._facing, -40.0)


## Mano en la que Kroker lleva esta arma ("l" o "r") / Hand Kroker holds this weapon in ("l" or "r")
func hand() -> String:
	var hs := KrokerArt.hands(player.outfit, player.weapon2.id if player.weapon2 else "")
	return hs["main"] if primary else hs["second"]


## Marca que el arma ha atacado (anima el brazo de Kroker que la lleva)
## Marks that the weapon attacked (animates the arm of Kroker holding it)
func swung(cast := false) -> void:
	if not primary:
		anim = 1.0
	elif cast:
		player.cast_anim = 1.0
	else:
		player.attack_anim = 1.0


## Estadísticas de nivel de Kroker que afectan al arma / Kroker's level stats that affect the weapon
func range_mult() -> float:
	return 1.0 + GameState.stat("range") / 100.0


func speed_mult() -> float:
	return 1.0 + GameState.stat("attack_speed") / 100.0


## Devuelve true si atacó. / Returns true if it attacked.
func attack() -> bool:
	return false


## Centro del cuerpo de Kroker (no los pies); las dos armas atacan desde ahí.
## Kroker's body centre (not his feet); both weapons attack from there.
func origin() -> Vector2:
	return player.global_position + Vector2(0, -44)


func nearest(max_range: float, from := Vector2.INF, exclude: Array = []) -> Node2D:
	if from == Vector2.INF:
		from = origin()
	# Revancha de Stolk: el fichado va primero si está a tiro / Stolk's Payback: the marked one goes first if in range
	var g = player.grudge
	if lv("stolk") > 0 and is_instance_valid(g) and g.is_targetable() and not exclude.has(g) and from.distance_to(_body(g)) <= max_range:
		return g
	var best: Node2D = null
	var best_d := max_range
	# Sin tipo en el bucle: un ataque diferido puede encontrarse a alguien ya liberado
	# Untyped loop: a delayed attack may run into someone already freed
	for n in run.foes():
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e == null or not e.is_targetable() or exclude.has(e):
			continue
		var d := from.distance_to(_body(e))
		# Los jefes tienen prioridad si están a una distancia parecida (si no, las armas se
		# entretienen con los enemigos de alrededor y la pelea se eterniza)
		# Bosses take priority when at a similar distance (otherwise weapons get distracted
		# by the surrounding enemies and the fight drags on forever)
		if e.is_boss():
			if d > max_range:
				continue
			d *= 0.6
		if d < best_d:
			best_d = d
			best = e
	return best


func _body(e: Node2D) -> Vector2:
	var p: Vector2 = e.aim_point()
	var r: float = e.reach_bonus()
	if r > 0.0:
		p += (origin() - p).limit_length(r)
	return p


func deal(e: Node2D, base_damage: float, impulse := Vector2.ZERO, steal_k := 1.0) -> void:
	base_damage = _stolk(e, base_damage)
	if e == player.grudge and lv("stolk") > 0:
		impulse *= GRUDGE_KNOCK
	impulse = _heavy(e, impulse)
	e.hit(base_damage * player.damage_mult, impulse)
	# Chispas del color del arma / Sparks in the weapon's colour
	if e is Enemy:
		var dir := impulse if impulse.length() > 1.0 else e.global_position - player.global_position
		run.fx.spark((e as Enemy).aim_point(), dir, spark_color(), 3 if impulse.length() < 400.0 else 6, 1.0 if impulse.length() < 400.0 else 1.5)
	GameState.run_dmg[id] = float(GameState.run_dmg.get(id, 0.0)) + base_damage * player.damage_mult
	_pinche(e)
	_luna_orbit(e)
	# Robo de salud: probabilidad de curar 1 / Life steal: chance to heal 1
	var ls := GameState.lifesteal_effective() * steal_k
	if ls > 0.0 and randf() * 100.0 < ls and player.steal_ready():
		player.heal_sustain(1.0)


## Color de las chispas de cada arma / Each weapon's spark colour
const SPARK := {"bat": Color("ffd98a"), "shield": Color("c9b8ff"), "book": Color("9fe8ff"), "vacuum": Color("8ff0c8"),
	"finger": Color("ff9fc8"), "teddy": Color("ffc0d8"), "ball": Color("f4f1ea"), "laptop": Color("5ff2ff"),
	"boots": Color("ffb06a"), "druid": Color("9be38a"), "yoyo": Color("e85d75")}
func spark_color() -> Color:
	return SPARK.get(id, UITheme.BONE)


## Alcance del golpe fuerte hacia los agujeros: el libro llega a 320 por sí solo; la brújula de
## sueños se lo da a todas (220, +80 por cada una más) y al libro le suma 100.
## Reach of the heavy hit towards holes: the book reaches 320 by itself; the dream compass gives
## it to every weapon (220, +80 for each extra) and adds 100 to the book.
const VOID_BOOK := 240.0
const VOID_COMPASS := 220.0
func void_reach() -> float:
	var n := Trinkets.count("compass")
	if id == "book":
		return VOID_BOOK + (100.0 if n > 0 else 0.0)
	return VOID_COMPASS + 80.0 * (n - 1) if n > 0 else 0.0


## Dirección hacia el agujero libre más cercano al enemigo (o cero si no hay ninguno a mano); se ve
## un rayito que lo señala (violeta el del libro, dorado el de la brújula).
## Direction towards the free hole nearest the enemy (or zero if none is close); a little bolt shows
## it (violet for the book, gold for the compass).
func void_dir(e: Node2D) -> Vector2:
	var reach := void_reach()
	if reach <= 0.0 or not e is Enemy or not (e as Enemy).can_fall():
		return Vector2.ZERO
	var from := e.global_position
	var best := Vector2.INF
	var list: Array = run.room.holes_list()
	for i in run.room.hole_count():
		var rc := Bedroom.rect_world(list[i])
		var c := rc.get_center()
		if run.hole_covered(rc) or c.distance_to(from) > reach:
			continue
		if best == Vector2.INF or c.distance_to(from) < best.distance_to(from):
			best = c
	if is_instance_valid(run.yawns):
		for c in run.yawns.open_centers():
			if c.distance_to(from) <= reach and (best == Vector2.INF or c.distance_to(from) < best.distance_to(from)):
				best = c
	if best == Vector2.INF:
		return Vector2.ZERO
	var col := Color("8d7ff0") if id == "book" else UITheme.GOLD
	run.fx.bolt(_jagged_line(from + Vector2(0, -(e as Enemy).aim_height), best), col)
	run.fx.ring(best, 34.0, col, 0.35, 2.2)
	return (best - from).normalized()


func _jagged_line(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var n := 6
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		pts.append(p + (b - a).orthogonal().normalized() * randf_range(-10.0, 10.0))
	pts.append(b)
	return pts


## Golpes desde el último golpe fuerte / Hits since the last heavy hit
var heavy_count := 0


## Cada cuántos golpes llega el fuerte (0 = nunca). Stolk desde el nivel 2 lo adelanta uno.
## How many hits until the heavy one (0 = never). Stolk from level 2 brings it one sooner.
func heavy_every() -> int:
	var every: int = GameState.HEAVY_EVERY.get(id, 0)
	if every > 0 and lv("stolk") >= 2:
		every = maxi(2, every - 1)
	return every


## Cada N golpes, uno fuerte que empuja de verdad (GameState.HEAVY_EVERY)
## Every N hits, a heavy one that really shoves (GameState.HEAVY_EVERY)
func _heavy(e: Node2D, impulse: Vector2) -> Vector2:
	var every := heavy_every()
	if every <= 0 or not e is Enemy or not (e as Enemy).is_targetable():
		return impulse
	heavy_count += 1
	if heavy_count < every:
		return impulse
	heavy_count = 0
	var dir := impulse.normalized() if impulse.length() > 1.0 else (e.global_position - player.global_position).normalized()
	# Hacia el agujero: el libro de por sí, y cualquier arma con la brújula de sueños
	# Towards the hole: the book by itself, and any weapon with the dream compass
	var to_hole := void_dir(e)
	if to_hole != Vector2.ZERO:
		dir = to_hole
	var en := e as Enemy
	player.run.fx.shock(en.aim_point(), 22.0, spark_color(), 0.32, 9.0)
	player.run.fx.flash(en.aim_point(), 40.0, Color(spark_color(), 0.9))
	player.run.fx.text(en.global_position + Vector2(0, -en.aim_height * 2.0 - 30), tr("HEAVY_HIT"), UITheme.BONE, 22, true)
	Audio.play("hit", -4.0, 0.05)
	player.run.shake(2.5)
	player.run.punch(0.035)
	# Sale disparado: frena despacio y puede caer aunque vaya lento al final; la masa cuenta menos
	# (raíz) para que también se pueda con los matones / Sent flying: slows down gently and can fall
	# even if slow by the end; mass counts less (square root) so it works on thugs too
	en.heavy_t = Enemy.HEAVY_TIME
	return dir * maxf(impulse.length(), GameState.HEAVY_KNOCK) * sqrt(maxf(1.0, en.mass))

## Stolk: «Abusón» (más daño a los indefensos) y «Revancha» (más al fichado)
## Stolk: "Bully" (more damage to the defenceless) and "Payback" (more to the marked one)
const GRUDGE_KNOCK := 1.6
func _stolk(e: Node2D, dmg: float) -> float:
	if lv("stolk") <= 0 or not e is Enemy:
		return dmg
	var en := e as Enemy
	var mult := 1.0
	if en.defenceless():
		mult += uv("stolk", "bully") / 100.0
	if en == player.grudge:
		mult += uv("stolk", "grudge") / 100.0
	return dmg * mult


## Luna «Órbita»: a veces el golpe deja al enemigo flotando / Luna "Orbit": sometimes the hit leaves the enemy floating
func _luna_orbit(e: Node2D) -> void:
	if lv("luna") <= 0 or GameState.helper_power("luna", id) != "orbit" or not e is Enemy:
		return
	if randf() * 100.0 < uv("luna", "chance"):
		(e as Enemy).float_up(uv("luna", "secs"))


## El Pinche: cada golpe sangra o quema según el arma / The Kitchen Boy: every hit bleeds or burns depending on the weapon
func _pinche(e: Node2D) -> void:
	if lv("pinche") <= 0 or not e is Enemy or not e.is_targetable():
		return
	var en := e as Enemy
	if GameState.PINCHE_KIND.get(id, "bleed") == "bleed":
		en.bleed(uv("pinche", "dps"), uv("pinche", "secs"))
	else:
		en.burn(uv("pinche", "dps"), uv("pinche", "secs"), uv("pinche", "pct"))


## Nivel de la mejora de un personaje del plano astral / Level of an astral giver's upgrade
func lv(giver: String) -> int:
	return GameState.level(giver, id)


## Valor de una mejora al nivel actual (tabla en GameState.UPGRADE_VALUES)
## An upgrade's value at the current level (table in GameState.UPGRADE_VALUES)
func uv(giver: String, key: String) -> float:
	return GameState.up_value(giver, key, -1, id)
