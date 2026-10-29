class_name StarShard
extends Node2D
## Trozo de estrella que sueltan los enemigos al disiparse. Salta, se queda en el suelo y
## vuela hacia Kroker cuando pasa cerca. Llenan la barra de nivel.
## Star shard dropped by enemies as they fade. It pops out, rests on the floor and flies
## to Kroker when he passes nearby. Shards fill the level bar.

const MAGNET := 150.0
const GRAVITY := 900.0

var run: Node
var value := 1
var _vel := Vector2.ZERO
var _hop := 0.0
var _vz := 0.0
var _t := 0.0
var _rot := 0.0
var _magnet := false


func _ready() -> void:
	z_index = 4
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(50.0, 170.0)
	_vz = randf_range(180.0, 300.0)
	_rot = randf() * TAU


func _physics_process(delta: float) -> void:
	_t += delta
	if _hop > 0.0 or _vz > 0.0:
		_vz -= GRAVITY * delta
		_hop = maxf(0.0, _hop + _vz * delta)
		if _hop <= 0.0:
			_vz = 0.0
	var player: Node2D = run.player
	var target: Vector2 = player.global_position + Vector2(0, -50)
	var dist := global_position.distance_to(target)
	if not _magnet and _t > 0.4 and player.alive and dist < MAGNET:
		_magnet = true
		_hop = 0.0
	if _magnet:
		var want := (target - global_position).normalized() * (420.0 + _t * 200.0)
		_vel = _vel.lerp(want, minf(1.0, delta * 9.0))
		position += _vel * delta
		if global_position.distance_to(target) < 30.0:
			run.collect_shards(value)
			queue_free()
			return
	else:
		_vel = _vel.move_toward(Vector2.ZERO, 260.0 * delta)
		position = run.clamp_to_arena(position + _vel * delta, 10.0)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(0, -8 - _hop + sin(_t * 3.0 + _rot) * 2.0)
	var tw := 0.75 + 0.25 * sin(_t * 6.0 + _rot)
	draw_colored_polygon(_ellipse(Vector2(0, 0), Vector2(7, 2.5)), Color(0.05, 0.02, 0.15, 0.3))
	draw_circle(c, 13.0, Color(UITheme.GOLD, 0.12 * tw))
	# Trozo de estrella: una punta rota de cuatro picos / Star shard: a broken four-pointed tip
	var pts := PackedVector2Array()
	for i in 8:
		var a := _rot + _t * 1.2 + i * PI / 4.0
		var r := 8.0 if i % 2 == 0 else 3.0
		if i == 4:
			r = 5.0  # la punta rota / the broken tip
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color("fff1c9"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(UITheme.GOLD, 0.9), 1.2, true)
	draw_circle(c, 1.8, Color(1, 1, 1, tw))


func _ellipse(c: Vector2, r: Vector2, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
