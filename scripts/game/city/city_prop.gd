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
	# Se mece girando el nodo: no hace falta volver a dibujar el sprite (ahorra mucho con cientos de árboles)
	# Sways by rotating the node: no need to redraw the sprite (saves a lot with hundreds of trees)
	rotation = sin(_t * 1.3) * 0.02

func _draw() -> void:
	Sprites.draw(self, sprite)
