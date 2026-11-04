class_name ParryBurst
extends Node2D
## El efecto del parry: un destello en Kroker con rayos que salen en estrella, una onda que se abre,
## un rayo blanco y dorado hasta cada enemigo que cae y un "¡clac!" de chasquido. Dura medio segundo.
## The parry effect: a flash on Kroker with rays bursting out like a star, an opening shockwave, a
## white-and-gold bolt to every enemy that falls and a snap "clack!". Lasts half a second.

const LIFE := 0.55
const GOLD := Color("ffd84a")

var targets: Array[Vector2] = []   # posiciones relativas de los que caen / relative positions of those who fall
var radius := 170.0
var _t := 0.0
var _seed := 0


func _ready() -> void:
	z_index = 5
	_seed = randi()


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var fade := 1.0 - k
	var c := Vector2(0, -40)
	# Destello central / Central flash
	draw_circle(c, 34.0 * (1.0 - k * 0.6), Color(1, 1, 1, 0.9 * fade))
	draw_circle(c, 18.0 * (1.0 - k * 0.4), Color(GOLD, fade))
	# Rayos en estrella que salen disparados / Star rays shooting out
	for i in 12:
		var a := i * TAU / 12.0 + 0.13
		var long := (i % 2 == 0)
		var r0 := 20.0 + k * 60.0
		var r1 := r0 + (70.0 if long else 40.0) * (1.0 - k * 0.5)
		var w := (6.0 if long else 3.0) * fade
		draw_line(c + Vector2.from_angle(a) * r0, c + Vector2.from_angle(a) * r1, Color(1, 1, 1, 0.9 * fade) if long else Color(GOLD, fade), maxf(1.0, w))
	# Onda que se abre hasta el radio del parry / Shockwave opening up to the parry radius
	var ease := 1.0 - pow(1.0 - k, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_arc(Vector2.ZERO, radius * ease, 0, TAU, 48, Color(1, 1, 1, 0.8 * fade), 6.0 * fade + 1.0)
	draw_arc(Vector2.ZERO, radius * ease * 0.85, 0, TAU, 48, Color(GOLD, 0.6 * fade), 3.0)
	draw_set_transform(Vector2.ZERO)
	# Rayo hasta cada enemigo (solo al principio) / Bolt to each enemy (only at the start)
	if k < 0.45:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed + int(_t * 30.0)
		var bk := 1.0 - k / 0.45
		for p in targets:
			var pts := PackedVector2Array([c])
			var to := p + Vector2(0, -30)
			for s in range(1, 6):
				var q := c.lerp(to, s / 6.0) + (to - c).orthogonal().normalized() * rng.randf_range(-12.0, 12.0)
				pts.append(q)
			pts.append(to)
			draw_polyline(pts, Color(GOLD, bk), 6.0)
			draw_polyline(pts, Color(1, 1, 1, bk), 2.5)
			draw_circle(to, 16.0 * bk + 4.0, Color(1, 1, 1, 0.8 * bk))
