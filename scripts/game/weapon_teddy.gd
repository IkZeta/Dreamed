class_name WeaponTeddy
extends Weapon
## Oso de peluche: Kroker le arranca pelusa de dentro y se la pega al enemigo más cercano.
## Hace un daño moderado y cada pelusa pegada frena al enemigo (se cae a los 8 s). Si dos
## enemigos con pelusa se tocan, se quedan pegados y van aún más lentos (ver Enemy).
## Teddy bear: Kroker tears fluff out of it and sticks it on the nearest enemy. It deals
## moderate damage and every stuck fluff slows the enemy down (it falls off after 8 s). If two
## fluffy enemies touch, they get stuck together and go even slower (see Enemy).
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — Pelusa saltarina: la pelusa salta a "extra" enemigos cercanos.
##  Stolk  — Abrazo de oso: +"pct" % de daño y, desde el nivel 2, una pelusa más.
##  Silly  — Pelusa con virus: los pegados reciben +"pct" % de daño.
##  Doc    — vida máxima a cambio de −"pct" % de duración de la pelusa.

const RANGE := 135.0
const DAMAGE := 5.0
const KNOCKBACK := 90.0
const JUMP_RANGE := 240.0
const FLUFF := Color("f4e9da")


func _init() -> void:
	cooldown = 0.7


func attack() -> bool:
	var target := nearest(RANGE * range_mult())
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	var dmg := DAMAGE * (1.0 + uv("stolk", "pct") / 100.0)
	deal(target, dmg, dir * KNOCKBACK)
	_stick(target, 1 + int(uv("stolk", "fluff")))
	# Svinho: la pelusa salta a otros enemigos cercanos / Svinho: the fluff hops to other nearby enemies
	var done: Array = [target]
	var from: Vector2 = target.aim_point()
	for i in int(uv("svinho", "extra")):
		var next := nearest(JUMP_RANGE * range_mult(), from, done)
		if next == null:
			break
		done.append(next)
		_fly(from, next)
		deal(next, dmg * 0.3, Vector2.ZERO, 0.5)
		_stick(next, 1)
		from = next.aim_point()
	swung()
	_fly(origin(), target)
	Audio.play("fluff", -6.0, 0.12)
	run.fx.swing(origin(), 70.0, dir.angle(), 0.7, FLUFF, 5.0)
	return true


func _stick(e: Node2D, n: int) -> void:
	if not e is Enemy or not e.is_targetable():
		return
	var en := e as Enemy
	en.add_fluff(n, Enemy.FLUFF_TIME * (1.0 - uv("doc", "pct") / 100.0))
	if lv("silly") > 0:
		en.stuck_bonus = maxf(en.stuck_bonus, uv("silly", "pct"))


## Bolita de pelusa que vuela hasta el enemigo / Ball of fluff flying to the enemy
func _fly(from: Vector2, to: Node2D) -> void:
	var f := FluffFly.new()
	f.position = from
	f.target = to.aim_point()
	run.world.add_child(f)


func charge_anchor() -> Vector2:
	if not primary:
		return super.charge_anchor()
	return Vector2(-30.0 * player._facing, -40.0)


class FluffFly extends Node2D:
	var target := Vector2.ZERO
	var _from := Vector2.ZERO
	var _k := 0.0

	func _ready() -> void:
		z_index = 40
		_from = position

	func _process(delta: float) -> void:
		_k += delta / 0.16
		if _k >= 1.0:
			queue_free()
			return
		position = _from.lerp(target, _k) + Vector2(0, -sin(_k * PI) * 30.0)
		queue_redraw()

	func _draw() -> void:
		for i in 4:
			draw_circle(Vector2(cos(i * 1.6) * 4.0, sin(i * 2.1) * 3.0), 5.0, Color(WeaponTeddy.FLUFF, 0.9))
		draw_circle(Vector2(-2, -2), 2.0, Color.WHITE)
