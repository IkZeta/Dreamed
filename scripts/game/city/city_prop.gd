class_name CityProp
extends Node2D
## Árbol, seto, farola o banco / A tree, hedge, lamp or bench

var sprite := ""
var sway := false
var size := 1.0
var flip := false
var _t := 0.0

func _ready() -> void:
	scale = Vector2(Bedroom.S * size * (-1.0 if flip else 1.0), Bedroom.S * size)
	_t = randf() * 5.0
	set_process(sway)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, sin(_t * 1.3) * 0.02 if sway else 0.0, Vector2.ONE)
	Sprites.draw(self, sprite)
