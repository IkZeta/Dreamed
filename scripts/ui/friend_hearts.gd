class_name FriendHearts
extends Control
## Cinco corazones con el nivel de amistad de un personaje (llenos hasta el nivel).
## Five hearts showing a character's friendship level (filled up to the level).

var level := 0
var color := Color("ff8fb0")
var heart := 18.0       # tamaño de cada corazón / size of each heart
var _pop := 0.0         # latido al subir de nivel / beat when levelling up


func _init(p_level := 0, p_color := Color("ff8fb0"), p_size := 18.0) -> void:
	level = p_level
	color = p_color
	heart = p_size
	custom_minimum_size = Vector2(heart * 5.6, heart * 1.2)
	mouse_filter = MOUSE_FILTER_IGNORE


func set_level(n: int) -> void:
	if n > level:
		_pop = 1.0
	level = n
	queue_redraw()


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta * 2.0)
		queue_redraw()


func _draw() -> void:
	for i in Progress.FRIEND_MAX:
		var c := Vector2(heart * (0.6 + i * 1.1), size.y / 2.0)
		var full := i < level
		var s := heart * (1.0 + (0.35 * _pop if full and i == level - 1 else 0.0))
		var pts := _heart(c, s)
		draw_colored_polygon(pts, Color(color, 0.95) if full else Color(0.1, 0.08, 0.2, 0.55))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color, 0.9 if full else 0.45), 1.5)
		if full:
			draw_circle(c + Vector2(-s * 0.18, -s * 0.12), s * 0.08, Color(1, 1, 1, 0.7))


func _heart(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * s / 34.0)
	return pts
