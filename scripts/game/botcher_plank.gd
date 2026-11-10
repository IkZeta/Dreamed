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


## Tablones en pixel art: tres tonos de madera, contorno oscuro y clavos (un píxel del arte son
## 2 unidades) / Pixel-art planks: three wood tones, dark outline and nails (one art pixel is 2 units)
const W0 := Color("6e4428")
const W1 := Color("a8703e")
const W2 := Color("d09a5c")
const INK := Color("1a1024")
const NAIL := Color("c0c8e8")


func _draw() -> void:
	var k := clampf(_t / 0.25, 0.0, 1.0)
	var n := 3
	var h := floorf(rect.size.y / n / 2.0) * 2.0
	var top := rect.get_center().y - h * n * 0.5
	for i in n:
		var w := snappedf((rect.size.x + 30.0 - 8.0 * absf(i - 1)) * k, 2.0)
		var x := snappedf(rect.get_center().x - w * 0.5 + (i - 1) * 6.0, 2.0)
		var y := top + i * h
		if w <= 4.0:
			continue
		draw_rect(Rect2(x - 2, y - 2, w + 4, h + 2), INK)
		draw_rect(Rect2(x, y, w, h - 2), W1)
		draw_rect(Rect2(x, y, w, 2), W2)
		draw_rect(Rect2(x, y + h - 6, w, 4), W0)
		# Vetas / Grain
		draw_rect(Rect2(x + 12, y + 6, w * 0.35, 2), W0)
		draw_rect(Rect2(x + w * 0.55, y + h * 0.5, w * 0.3, 2), W0)
		if k >= 1.0:
			for nx in [x + 6.0, x + w - 10.0]:
				draw_rect(Rect2(nx, y + h * 0.5 - 3, 4, 4), INK)
				draw_rect(Rect2(nx, y + h * 0.5 - 3, 2, 2), NAIL)
