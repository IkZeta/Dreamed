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
		return float_offset() + Vector2(0, -34)
	return Vector2(26.0 * player._facing, -42.0)


## Dónde flota la segunda arma, relativo a Kroker: detrás del hombro, subiendo y bajando
## Where the second weapon floats, relative to Kroker: behind his shoulder, bobbing
func float_offset() -> Vector2:
	return Vector2(-46.0 * player._facing, -112.0 + sin(player._t * 2.2) * 5.0) + Vector2(14.0 * player._facing, 8.0) * anim


## Marca que el arma ha atacado (anima a Kroker o a la propia arma flotante)
## Marks that the weapon attacked (animates Kroker or the floating weapon itself)
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


## Centro del cuerpo de Kroker (no los pies); la segunda arma ataca desde donde flota.
## Kroker's body centre (not his feet); the second weapon attacks from where it floats.
func origin() -> Vector2:
	if not primary:
		return player.global_position + float_offset()
	return player.global_position + Vector2(0, -44)


func nearest(max_range: float, from := Vector2.INF, exclude: Array = []) -> Node2D:
	if from == Vector2.INF:
		from = origin()
	var best: Node2D = null
	var best_d := max_range
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable() or exclude.has(e):
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
	e.hit(base_damage * player.damage_mult, impulse)
	_pinche(e)
	# Robo de salud: probabilidad de curar 1 / Life steal: chance to heal 1
	var ls := GameState.stat("lifesteal") * steal_k
	if ls > 0.0 and randf() * 100.0 < ls:
		player.heal(1.0)


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
