class_name Weapon
extends Node2D
## Base de las armas: atacan solas cada `cooldown` segundos si hay objetivo.
## Weapon base: attacks automatically every `cooldown` seconds when a target exists.

var run: Node     # Run
var player: Player
var cooldown := 1.0
var _timer := 0.4


func _physics_process(delta: float) -> void:
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
	return Vector2(34.0 * player._facing, -66.0)


## Estadísticas de nivel de Kroker que afectan al arma / Kroker's level stats that affect the weapon
func range_mult() -> float:
	return 1.0 + GameState.stat("range") / 100.0


func speed_mult() -> float:
	return 1.0 + GameState.stat("attack_speed") / 100.0


## Devuelve true si atacó. / Returns true if it attacked.
func attack() -> bool:
	return false


## Centro del cuerpo de Kroker (no los pies). / Kroker's body center (not his feet).
func origin() -> Vector2:
	return player.global_position + Vector2(0, -80)


func nearest(max_range: float, from := Vector2.INF, exclude: Array = []) -> Node2D:
	if from == Vector2.INF:
		from = origin()
	var best: Node2D = null
	var best_d := max_range
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable() or exclude.has(e):
			continue
		var d := from.distance_to(_body(e))
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
	# Robo de salud: probabilidad de curar 1 / Life steal: chance to heal 1
	var ls := GameState.stat("lifesteal") * steal_k
	if ls > 0.0 and randf() * 100.0 < ls:
		player.heal(1.0)


## Nivel de la mejora de un personaje del plano astral / Level of an astral giver's upgrade
func lv(giver: String) -> int:
	return GameState.level(giver)


## Valor de una mejora al nivel actual (tabla en GameState.UPGRADE_VALUES)
## An upgrade's value at the current level (table in GameState.UPGRADE_VALUES)
func uv(giver: String, key: String) -> float:
	return GameState.up_value(giver, key)
