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
	_timer -= delta
	if _timer <= 0.0 and attack():
		_timer = cooldown


## Barras de carga que se dibujan bajo Kroker: [[fracción 0..1, color], ...]
## Charge bars drawn under Kroker: [[fraction 0..1, colour], ...]
func charge_bars() -> Array:
	return [[1.0 - clampf(_timer / maxf(cooldown, 0.01), 0.0, 1.0), UITheme.BONE]]


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
	return e.aim_point()


func deal(e: Node2D, base_damage: float, impulse := Vector2.ZERO) -> void:
	e.hit(base_damage * player.damage_mult, impulse)


## Nivel de la mejora de un personaje del plano astral / Level of an astral giver's upgrade
func lv(giver: String) -> int:
	return GameState.level(giver)


## Valor de una mejora al nivel actual (tabla en GameState.UPGRADE_VALUES)
## An upgrade's value at the current level (table in GameState.UPGRADE_VALUES)
func uv(giver: String, key: String) -> float:
	return GameState.up_value(giver, key)
