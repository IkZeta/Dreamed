class_name WeaponBook
extends Weapon
## Libro: hace caer rayos del cielo. Cada vez lanza de 1 a 3 rayos (40 % / 35 % / 25 %,
## mejor con suerte) y cada rayo golpea a un solo enemigo, distinto si puede.
## Book: calls lightning down from the sky. Each cast drops 1 to 3 bolts (40% / 35% / 25%,
## better with luck) and each bolt hits a single enemy, a different one if it can.
##
## Mejoras / Upgrades:
##  (valores por nivel en GameState.UPGRADE_VALUES / per-level values there)
##  Svinho  — Rebote de página: cada rayo rebota en "extra" enemigos más.
##  Stolk   — Libro de castigo: −"pct" % de tiempo entre rayos.
##  Silly   — Rayo en bucle: un segundo después se repite el "pct" % del daño.

const RANGE := 260.0
const DAMAGE := 8.0
const BOLT_WEIGHTS: Array[float] = [40.0, 35.0, 25.0]   # 1, 2 o 3 rayos / 1, 2 or 3 bolts
const BOLT_GAP := 0.09     # tiempo entre un rayo y el siguiente / time between bolts
const JUMP_RANGE := 230.0
const FALLOFF := 0.8       # cada rebote hace un 20 % menos / each bounce deals 20% less


func _init() -> void:
	cooldown = 1.8


func _ready() -> void:
	cooldown = 1.8 * (1.0 - uv("stolk", "pct") / 100.0) * (1.0 + uv("doc", "pct") / 100.0)


## Cuántos rayos caen esta vez; la suerte hace más probables 2 y 3
## How many bolts fall this time; luck makes 2 and 3 likelier
static func roll_bolts() -> int:
	var luck := GameState.stat("luck") / 100.0
	var total := 0.0
	var w: Array[float] = []
	for i in BOLT_WEIGHTS.size():
		var v := BOLT_WEIGHTS[i] * pow(maxf(0.1, 1.0 + luck * 2.0), i)
		w.append(v)
		total += v
	var roll := randf() * total
	for i in w.size():
		roll -= w[i]
		if roll <= 0.0:
			return i + 1
	return 1


func attack() -> bool:
	var first := nearest(RANGE * range_mult())
	if first == null:
		return false
	swung(true)
	# Objetivos: primero el más cercano y luego otros distintos al alcance
	# Targets: the nearest first, then other different ones in range
	var n := roll_bolts()
	var targets: Array = [first]
	while targets.size() < n:
		var t := nearest(RANGE * range_mult(), Vector2.INF, targets)
		if t == null:
			break
		targets.append(t)
	while targets.size() < n:
		targets.append(targets[randi() % targets.size()])  # sobran rayos: repiten / spare bolts repeat
	for i in targets.size():
		var ref: WeakRef = weakref(targets[i])
		if i == 0:
			_strike(targets[i])
		else:
			get_tree().create_timer(BOLT_GAP * i, false).timeout.connect(func() -> void:
				var e: Node2D = ref.get_ref()
				if e != null and e.is_targetable():
					_strike(e))
	return true


## Un rayo cae del cielo sobre el enemigo; con Svinho rebota en otros
## A bolt falls from the sky onto the enemy; with Svinho it bounces to others
func _strike(target: Node2D) -> void:
	var to := _body(target)
	var sky := to + Vector2(randf_range(-40, 40), -620)
	run.fx.bolt(_jagged(sky, to), Color("f2e6b8"))
	run.fx.ring(target.global_position, 26.0, Color("f2e6b8"), 0.3, 2.2)
	Audio.play("zap", -9.0, 0.12)
	var dmg := DAMAGE
	var hit: Array = []
	var bounces := int(uv("svinho", "extra"))
	var from := to
	while target != null:
		deal(target, dmg)
		if lv("silly") > 0:
			_echo(target, dmg * player.damage_mult * uv("silly", "pct") / 100.0)
		hit.append(target)
		if hit.size() > bounces:
			break
		target = nearest(JUMP_RANGE * range_mult(), from, hit)
		if target != null:
			var next := _body(target)
			run.fx.bolt(_jagged(from, next), Color("e8d9a8"))
			from = next
			dmg *= FALLOFF


## El daño se repite al cabo de un segundo / The damage repeats one second later
func _echo(e: Node2D, amount: float) -> void:
	e.glitch_t = maxf(e.glitch_t, 1.0)
	var ref: WeakRef = weakref(e)
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		var target: Node2D = ref.get_ref()
		if target != null and target.is_targetable():
			target.hit(amount)
			run.fx.ring(target.aim_point(), 16.0, Enemy.GLITCH_B, 0.3, 2.0))


func _jagged(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var n := maxi(3, int(a.distance_to(b) / 28.0))
	var normal := (b - a).normalized().orthogonal()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + normal * randf_range(-12, 12))
	pts.append(b)
	return pts


## El anillo sale junto al libro / The ring sits by the book
func charge_anchor() -> Vector2:
	return Vector2(34.0 * player._facing, -54.0)
