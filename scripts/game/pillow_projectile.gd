class_name PillowProjectile
extends Node2D
## La almohada lanzada (mejora de Svinho): vuela al enemigo, rebota de uno a otro
## y vuelve a las manos de Kroker.
## The thrown pillow (Svinho's upgrade): flies at an enemy, bounces from one to the
## next and returns to Kroker's hands.

const SPEED := 760.0
const BOUNCE_RANGE := 380.0

var run: Node
var player: Node2D
var damage := 9.0
var bounces := 2
var slow := 0.0
var slow_chance := 0.0
var target: Node2D
var _hit: Array = []
var _returning := false
var _spin := 0.0


func _ready() -> void:
	z_index = 40


func _physics_process(delta: float) -> void:
	_spin += delta * 14.0
	var goal: Vector2
	if _returning or not is_instance_valid(target) or not target.is_targetable():
		if not _returning:
			_next_target()
		if _returning:
			goal = player.global_position + Vector2(0, -80)
			if global_position.distance_to(goal) < 30.0:
				queue_free()
				return
		else:
			goal = target.aim_point()
	else:
		goal = target.aim_point()
	var dir := (goal - global_position).normalized()
	global_position += dir * SPEED * delta
	if not _returning and is_instance_valid(target) and global_position.distance_to(goal) < 28.0:
		_hit.append(target)
		target.hit(damage, dir * 380.0)
		if slow > 0.0 and randf() * 100.0 < slow_chance:
			target.glitch(0.0, slow)
		run.fx.ring(goal, 22.0, UITheme.GOLD, 0.3, 2.0)
		Audio.play("ricochet", -9.0, 0.1)
		bounces -= 1
		_next_target()
	queue_redraw()


func _next_target() -> void:
	target = null
	if bounces < 0:
		_returning = true
		return
	var best_d := BOUNCE_RANGE
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable() or _hit.has(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			target = e
	if target == null:
		_returning = true


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _spin, Vector2(0.6, 0.6))
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var c := Vector2(cos(a), sin(a))
		pts.append(Vector2(signf(c.x) * pow(absf(c.x), 0.6) * 36.0, signf(c.y) * pow(absf(c.y), 0.6) * 26.0))
	draw_colored_polygon(pts, Color("f3effc"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("cfc6ee"), 2.0, true)
	DreamBackground.draw_star(self, Vector2.ZERO, 4.0, Color(UITheme.GOLD, 0.9))
	draw_set_transform(Vector2.ZERO)
