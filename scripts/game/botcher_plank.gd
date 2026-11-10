class_name BotcherPlank
extends Node2D
## Tablones del Chapuzas sobre un agujero. Se rompen en astillas cuando cae su torreta.
## The Botcher's planks over a hole. They break into splinters when their turret goes down.

var owner_turret: Enemy
var rect := Rect2()
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(owner_turret) or owner_turret.state == Enemy.State.DYING:
		_break()
		return
	if _t < 0.5:
		queue_redraw()


func _break() -> void:
	var run := owner_turret.run if is_instance_valid(owner_turret) else null
	if run != null:
		for i in 6:
			var p := rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y)
			run.fx.ring(p, 10.0, Botcher.WOOD, 0.3, 2.0)
		run.fx.text(rect.get_center() + Vector2(0, -40), tr("BOTCHER_BROKEN"), UITheme.GOLD, 20)
		Audio.play("crack", -8.0, 0.1)
	queue_free()


func _draw() -> void:
	var k := clampf(_t / 0.25, 0.0, 1.0)
	var n := 3
	var h := rect.size.y / n
	for i in n:
		var y := rect.position.y + i * h
		var tilt := (i - 1) * 3.0
		var w := rect.size.x + 30.0
		var x := rect.get_center().x - w * 0.5 * k
		var pts := PackedVector2Array([Vector2(x, y + 2 + tilt), Vector2(x + w * k, y + 2 - tilt),
			Vector2(x + w * k, y + h - 2 - tilt), Vector2(x, y + h - 2 + tilt)])
		draw_colored_polygon(pts, Botcher.WOOD.darkened(0.08 * i))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Botcher.WOOD.darkened(0.45), 2.0)
		# Vetas y clavos / Grain and nails
		draw_line(Vector2(x + 10, y + h * 0.5), Vector2(x + w * k - 14, y + h * 0.5 - tilt), Botcher.WOOD.darkened(0.25), 1.0)
		if k >= 1.0:
			draw_rect(Rect2(x + 8, y + h * 0.5 - 2, 4, 4), Color("cfd6e6"))
			draw_rect(Rect2(x + w - 12, y + h * 0.5 - 2, 4, 4), Color("cfd6e6"))
