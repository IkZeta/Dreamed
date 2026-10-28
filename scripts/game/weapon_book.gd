class_name WeaponBook
extends Weapon
## Libro: rayo a distancia que salta entre enemigos cercanos.
## Book: ranged lightning that jumps between nearby enemies.

const RANGE := 460.0
const DAMAGE := 8.0
const CHAINS := 3          # enemigos por rayo / enemies per bolt
const JUMP_RANGE := 230.0
const FALLOFF := 0.8       # cada salto hace un 20 % menos / each jump deals 20% less


func _init() -> void:
	cooldown = 1.1


func attack() -> bool:
	var target := nearest(RANGE)
	if target == null:
		return false
	player.cast_anim = 1.0
	var hit: Array = []
	var from := player.global_position + Vector2(40 * signf(player._facing), -88)
	var dmg := DAMAGE
	while target != null and hit.size() < CHAINS:
		var to := _body(target)
		run.fx.bolt(_jagged(from, to), Color("e8d9a8"))
		deal(target, dmg)
		hit.append(target)
		from = to
		dmg *= FALLOFF
		target = nearest(JUMP_RANGE, from, hit)
	return true


func _jagged(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var n := maxi(3, int(a.distance_to(b) / 28.0))
	var normal := (b - a).normalized().orthogonal()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + normal * randf_range(-12, 12))
	pts.append(b)
	return pts
