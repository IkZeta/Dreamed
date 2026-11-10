class_name CityAmbience
extends Node2D
## Ambiente de cada ciudad por encima de todo: neblina de su color y partículas (neón, humo, migas
## de queso, burbujas, pétalos, ascuas o lluvia)
## Each city's ambience over everything: haze in its colour and particles (neon, smoke, cheese
## crumbs, bubbles, petals, embers or rain)

var room: Act4Room
var _t := 0.0
var _p: Array[Vector4] = []   # x, y, fase, tamaño / x, y, phase, size
const N := 70
const BOX := Vector2(2900, 1700)

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in N:
		_p.append(Vector4(rng.randf() * BOX.x, rng.randf() * BOX.y, rng.randf() * TAU, rng.randf_range(0.6, 1.4)))

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var view := room._view_canvas()
	var haze := room.look("haze")
	draw_rect(view.grow(40), Color(haze, 0.06))
	if room.style == "noir":
		# Relámpago de vez en cuando / Lightning now and then
		var fl := fmod(_t, 9.0)
		if fl < 0.08 or (fl > 0.16 and fl < 0.22):
			draw_rect(view.grow(40), Color(1, 1, 1, 0.22))
	if room.style == "dieselpunk" or room.style == "noir":
		# La sombra de un zepelín que cruza despacio la ciudad / A zeppelin's shadow slowly crossing the city
		var zx := fposmod(_t * 60.0, Act4Room.MAP_SIZE.x + 1600.0) - 800.0
		var zc := Vector2(zx, Act4Room.MAP_SIZE.y * 0.45 + sin(_t * 0.05) * 600.0)
		draw_colored_polygon(room._ellipse(zc, Vector2(420, 120)), Color(0.05, 0.02, 0.0, 0.18))
		draw_colored_polygon(PackedVector2Array([zc + Vector2(-380, 0), zc + Vector2(-520, -90), zc + Vector2(-500, 90)]), Color(0.05, 0.02, 0.0, 0.18))
		draw_rect(Rect2(zc + Vector2(-60, 90), Vector2(120, 40)), Color(0.05, 0.02, 0.0, 0.14))
	var vel := Vector2.ZERO
	match room.style:
		"synthwave", "aero": vel = Vector2(6, -40)
		"steampunk": vel = Vector2(30, -14)
		"dieselpunk": vel = Vector2(14, -50)
		"cheese", "solarpunk": vel = Vector2(16, 34)
		"brutalist", "noir": vel = Vector2(-140, 620)
	for i in N:
		var q := _p[i]
		var pos := Vector2(q.x, q.y) + vel * _t * q.w + Vector2(sin(_t * 0.8 + q.z) * 30.0, 0)
		pos = Vector2(fposmod(pos.x - view.position.x, BOX.x), fposmod(pos.y - view.position.y, BOX.y)) + view.position - (BOX - view.size) * 0.5
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + q.z)
		match room.style:
			"synthwave":
				var col := room.look("curb") if i % 2 else room.look("accent")
				draw_rect(Rect2(pos, Vector2(7, 7) * q.w), Color(col, 0.35 + 0.4 * tw))
			"steampunk":
				draw_circle(pos, 18.0 * q.w, Color(0.9, 0.85, 0.78, 0.08 + 0.06 * tw))
				if i % 6 == 0:
					draw_rect(Rect2(pos, Vector2(4, 4)), Color(1.0, 0.75, 0.3, 0.6 * tw))
			"cheese":
				draw_rect(Rect2(pos, Vector2(8, 6) * q.w), Color(1.0, 0.85, 0.3, 0.6))
			"aero":
				var br := (10.0 + 10.0 * float(i % 3)) * q.w
				draw_circle(pos, br, Color(0.75, 0.95, 1.0, 0.12))
				draw_arc(pos, br, 0, TAU, 18, Color(1, 1, 1, 0.6), 2.0)
				draw_arc(pos, br * 0.7, 3.6, 4.6, 8, Color(1, 1, 1, 0.8), 3.0)
			"solarpunk":
				draw_set_transform(pos, _t * 1.5 + q.z, Vector2.ONE)
				draw_colored_polygon(room._ellipse(Vector2.ZERO, Vector2(7, 4) * q.w), Color("ffb0c8") if i % 3 else Color("fff8e0"))
				draw_set_transform(Vector2.ZERO)
			"dieselpunk":
				draw_rect(Rect2(pos, Vector2(5, 5) * q.w), Color(1.0, 0.55, 0.2, 0.3 + 0.5 * tw) if i % 3 else Color(0.5, 0.48, 0.5, 0.4))
			"brutalist":
				draw_line(pos, pos + Vector2(-6, 34) * q.w, Color(0.75, 0.8, 0.9, 0.35), 2.0)
			"noir":
				# Lluvia fuerte, con salpicones / Heavy rain, with splashes
				draw_line(pos, pos + Vector2(-8, 46) * q.w, Color(0.8, 0.82, 0.9, 0.4), 2.0)
				draw_line(pos + Vector2(140, 300), pos + Vector2(132, 346) * Vector2(1, 1), Color(0.8, 0.82, 0.9, 0.3), 2.0)
