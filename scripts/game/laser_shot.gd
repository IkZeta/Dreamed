class_name LaserShot
extends Node2D
## Rayo láser de la pistola de dedos. Viaja muy rápido y aplica su efecto al golpear.
## Laser beam from the finger gun. Travels very fast and applies its effect on hit.

const SPEED := 1500.0
const LENGTH := 46.0
const PUSH := 950.0
const BOUNCE_RANGE := 280.0
const PIERCE_FALLOFF := 0.8
const BOUNCE_FALLOFF := 0.85

var weapon: WeaponFinger
var kind := "normal"
var dir := Vector2.RIGHT
var damage := 4.5
var max_travel := 600.0
var bounces := 0
var pierces := 0
var _travel := 0.0
var _hit: Array = []
var _dead := 0.0       # >0 mientras se desvanece / >0 while fading out
var _trail := PackedVector2Array()


func _ready() -> void:
	z_index = 40
	_trail.append(position)


func _physics_process(delta: float) -> void:
	if _dead > 0.0:
		_dead -= delta
		if _dead <= 0.0:
			queue_free()
		queue_redraw()
		return
	if not is_instance_valid(weapon) or not is_instance_valid(weapon.run):
		queue_free()
		return
	var run := weapon.run
	var step := dir * SPEED * delta
	var a := position
	var b := position + step
	# ¿A quién atraviesa en este tramo? / Who does it cross on this stretch?
	var best: Node2D = null
	var best_u := 2.0
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable() or _hit.has(e):
			continue
		var p: Vector2 = e.aim_point()
		var u := clampf((p - a).dot(step) / maxf(step.length_squared(), 0.001), 0.0, 1.0)
		var d := (a + step * u).distance_to(p)
		if d < float(e.get("radius")) + 12.0 and u < best_u:
			best_u = u
			best = e
	if best:
		position = a + step * best_u
		_trail.append(position)
		_on_hit(best)
		return
	position = b
	_trail.append(position)
	if _trail.size() > 4:
		_trail.remove_at(0)
	_travel += step.length()
	if _travel > max_travel or not run.arena_rect().grow(80).has_point(position):
		_fade()
	queue_redraw()


func _on_hit(e: Node2D) -> void:
	_hit.append(e)
	var run := weapon.run
	var col: Color = WeaponFinger.COLORS[kind]
	var impulse := dir * (PUSH if kind == "push" else 60.0)
	weapon.deal(e, damage, impulse)
	weapon.on_laser_hit(e)
	run.fx.ring(e.aim_point(), 14.0 if kind != "crit" else 22.0, col, 0.3, 2.2)
	if kind == "crit":
		run.fx.text(e.aim_point() + Vector2(0, -60), "x1.75", col, 18)
	if kind == "push":
		Audio.play("pillow", -12.0, 0.15)
	if pierces > 0:
		pierces -= 1
		damage *= PIERCE_FALLOFF
		return
	if bounces > 0:
		# Rebota hacia el enemigo más cercano que aún no ha tocado / Ricochets to the nearest enemy it hasn't touched
		var next: Node2D = weapon.nearest(BOUNCE_RANGE * weapon.range_mult(), e.aim_point(), _hit)
		if next:
			bounces -= 1
			damage *= BOUNCE_FALLOFF
			dir = (next.aim_point() - position).normalized()
			_travel = 0.0
			max_travel = BOUNCE_RANGE * weapon.range_mult() * 1.4
			Audio.play("ricochet", -14.0, 0.1)
			return
	_fade()


func _fade() -> void:
	_dead = 0.12
	queue_redraw()


func _draw() -> void:
	var col: Color = WeaponFinger.COLORS[kind]
	var k := 1.0 if _dead <= 0.0 else _dead / 0.12
	var tail := -dir * LENGTH
	var w := 7.0 if kind == "crit" else 5.0
	draw_line(tail, Vector2.ZERO, Color(col, 0.3 * k), w * 2.2)
	draw_line(tail, Vector2.ZERO, Color(col, 0.9 * k), w)
	draw_line(tail * 0.8, Vector2.ZERO, Color(1, 1, 1, 0.85 * k), w * 0.4)
	draw_circle(Vector2.ZERO, w * 0.8, Color(1, 1, 1, 0.8 * k))
