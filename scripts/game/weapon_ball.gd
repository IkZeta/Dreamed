class_name WeaponBall
extends Weapon
## Pelota (a distancia, alcance corto): Kroker la chuta al enemigo más cercano, rebota de uno a
## otro y vuelve a sus pies. Mientras está en el aire no puede chutar otra. Empieza con la mejora
## de Svinho al nivel 3 (rebota en más enemigos).
## Ball (ranged, short reach): Kroker kicks it at the nearest enemy, it bounces from one to the
## next and comes back to his feet. While it's in the air he can't kick another. It starts with
## Svinho's upgrade at level 3 (bounces off more enemies).
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — Tiki-taka: rebota en "extra" enemigos más.
##  Stolk  — Chut de matón: +"pct" % de daño.
##  Silly  — Balón glitch: "chance" % de congelar al enemigo "secs" segundos.
##  Doc    — vida máxima a cambio de +"pct" % de recarga.

const RANGE := 230.0
const DAMAGE := 7.0
const BOUNCE_RANGE := 260.0
const KNOCKBACK := 260.0

var _ball: Node2D


func _init() -> void:
	cooldown = 0.5


func _ready() -> void:
	cooldown = 0.5 * (1.0 + uv("doc", "pct") / 100.0)


## ¿Tiene la pelota en los pies? / Does he have the ball at his feet?
func has_ball() -> bool:
	return not is_instance_valid(_ball)


func attack() -> bool:
	if not has_ball():
		return false
	var target := nearest(RANGE * range_mult())
	if target == null:
		return false
	var b := BallShot.new()
	b.weapon = self
	b.target = target
	b.damage = DAMAGE * (1.0 + uv("stolk", "pct") / 100.0)
	b.bounces = 1 + int(uv("svinho", "extra"))
	b.position = origin() + Vector2(0, 30)
	run.world.add_child(b)
	_ball = b
	swung()
	Audio.play("kick", -6.0, 0.1)
	return true


## Silly: el balón congela / Silly: the ball freezes
func on_ball_hit(e: Node2D) -> void:
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		e.glitch(uv("silly", "secs"))


func charge_bars() -> Array:
	# Con la pelota en el aire, el anillo espera / With the ball in the air, the ring waits
	if not has_ball():
		return [[0.0, UITheme.BONE]]
	return super.charge_bars()


class BallShot extends Node2D:
	const SPEED := 900.0
	var weapon: WeaponBall
	var target: Node2D
	var damage := 7.0
	var bounces := 1
	var _hit: Array = []
	var _returning := false
	var _spin := 0.0

	func _ready() -> void:
		z_index = 40

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(weapon) or not is_instance_valid(weapon.player):
			queue_free()
			return
		_spin += delta * 16.0
		var goal: Vector2
		if not _returning and (not is_instance_valid(target) or not target.is_targetable()):
			_next_target()
		if _returning:
			goal = weapon.player.global_position + Vector2(0, -8)
			if global_position.distance_to(goal) < 26.0:
				queue_free()
				return
		else:
			goal = target.aim_point()
		var dir := (goal - global_position).normalized()
		global_position += dir * SPEED * (1.2 if _returning else 1.0) * delta
		if not _returning and global_position.distance_to(goal) < 24.0:
			_hit.append(target)
			weapon.deal(target, damage, dir * WeaponBall.KNOCKBACK)
			weapon.on_ball_hit(target)
			weapon.run.fx.ring(goal, 18.0, Color.WHITE, 0.25, 2.0)
			Audio.play("ricochet", -10.0, 0.1)
			bounces -= 1
			damage *= 0.9
			_next_target()
		queue_redraw()

	func _next_target() -> void:
		target = null
		if bounces <= 0:
			_returning = true
			return
		target = weapon.nearest(WeaponBall.BOUNCE_RANGE * weapon.range_mult(), global_position, _hit)
		if target == null:
			_returning = true

	func _draw() -> void:
		draw_circle(Vector2(0, 14), 8.0, Color(0.05, 0.02, 0.15, 0.3))
		draw_set_transform(Vector2.ZERO, _spin, Vector2(Player.ART_SCALE, Player.ART_SCALE))
		Sprites.draw(self, "weapon_ball")
		draw_set_transform(Vector2.ZERO)
