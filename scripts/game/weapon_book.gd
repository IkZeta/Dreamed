class_name WeaponBook
extends Weapon
## Libro: rayo a distancia que salta entre enemigos cercanos.
## Book: ranged lightning that jumps between nearby enemies.
##
## Mejoras / Upgrades:
##  Svinho  — Rebote de página: el rayo salta a más enemigos y más lejos.
##  Stolk   — Libro de castigo: lanza rayos mucho más a menudo (cuesta vida máxima).
##  Silly   — Rayo en bucle: el daño se repite un segundo después, como un eco con glitch.

const RANGE := 460.0
const DAMAGE := 8.0
const CHAINS := 3          # enemigos por rayo / enemies per bolt
const JUMP_RANGE := 230.0
const FALLOFF := 0.8       # cada salto hace un 20 % menos / each jump deals 20% less


func _init() -> void:
	cooldown = 1.1


func _ready() -> void:
	cooldown = maxf(0.35, 1.1 * (1.0 - 0.25 * lv("stolk")))


func attack() -> bool:
	var target := nearest(RANGE)
	if target == null:
		return false
	player.cast_anim = 1.0
	Audio.play("zap", -8.0, 0.08)
	var hit: Array = []
	var from := player.global_position + Vector2(40 * signf(player._facing), -88)
	var dmg := DAMAGE
	var chains := CHAINS + 2 * lv("svinho")
	var jump := JUMP_RANGE * (1.0 + 0.4 * minf(1.0, lv("svinho")))
	while target != null and hit.size() < chains:
		var to := _body(target)
		run.fx.bolt(_jagged(from, to), Color("e8d9a8"))
		deal(target, dmg)
		if lv("silly") > 0:
			_echo(target, dmg * player.damage_mult * (0.35 + 0.15 * lv("silly")))
		hit.append(target)
		from = to
		dmg *= FALLOFF
		target = nearest(jump, from, hit)
	return true


## El daño se repite al cabo de un segundo / The damage repeats one second later
func _echo(e: Node2D, amount: float) -> void:
	e.glitch(0.0, 0.0, 0.0)
	e.glitch_t = 1.0
	var ref: WeakRef = weakref(e)
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		var target: Node2D = ref.get_ref()
		if target != null and target.is_targetable():
			target.hit(amount)
			run.fx.ring(target.global_position + Vector2(0, -18), 16.0, Foox.GLITCH_B, 0.3, 2.0))


func _jagged(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var n := maxi(3, int(a.distance_to(b) / 28.0))
	var normal := (b - a).normalized().orthogonal()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + normal * randf_range(-12, 12))
	pts.append(b)
	return pts
