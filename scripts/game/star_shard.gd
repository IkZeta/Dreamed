class_name StarShard
extends Node2D
## Trozo de estrella que sueltan los enemigos al disiparse. Salta, se queda en el suelo y
## vuela hacia Kroker cuando pasa cerca. Llenan la barra de nivel. Son cristalitos de colores
## con picos (como los de Mario Galaxy), para no confundirlos con las estrellas del decorado.
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
## Telaraña que lo tiene atrapado (DreamWeb) / Web holding it (DreamWeb)
var web: Node2D = null
const WEB_CREEP := 55.0
## Colores de caramelo de los trozos / Candy colours for the shards
const COLORS := [Color("ff6fb5"), Color("ffd84a"), Color("5fc8ff"), Color("7fe07a"), Color("b77bff")]
var _col := Color.WHITE


func _ready() -> void:
	z_index = 4
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(50.0, 170.0)
	_vz = randf_range(180.0, 300.0)
	_rot = randf() * TAU
	_col = COLORS[randi() % COLORS.size()]


func _physics_process(delta: float) -> void:
	_t += delta
	if _hop > 0.0 or _vz > 0.0:
		_vz -= GRAVITY * delta
		_hop = maxf(0.0, _hop + _vz * delta)
		if _hop <= 0.0:
			# Rebota un par de veces antes de quedarse quieto / Bounces a couple of times before settling
			_vz = -_vz * 0.4 if _vz < -120.0 else 0.0
	# Atrapado en una telaraña del Atrapasueños: no se puede coger y sube despacio hacia la araña
	# Caught in a Dreamcatcher's web: it can't be picked up and creeps slowly towards the spider
	if is_instance_valid(web) and not _magnet:
		var spider: Node2D = web.get("spider")
		if is_instance_valid(spider) and (spider as Enemy).is_targetable():
			var goal := spider.global_position + Vector2(0, -40)
			position += (goal - global_position).limit_length(WEB_CREEP * delta)
			if global_position.distance_to(goal) < 16.0:
				spider.call("eat", value)
				queue_free()
				return
		queue_redraw()
		return
	var player: Node2D = run.player
	var target: Vector2 = player.global_position + Vector2(0, -38)
	var dist := global_position.distance_to(target)
	if not _magnet and _t > 0.4 and player.alive and dist < MAGNET * Trinkets.magnet_mult():
		_magnet = true
		_hop = 0.0
	if _magnet:
		var want := (target - global_position).normalized() * (420.0 + _t * 200.0)
		_vel = _vel.lerp(want, minf(1.0, delta * 9.0))
		position += _vel * delta
		if global_position.distance_to(target) < 30.0:
			run.collect_shards(value)
			Progress.tip("shard")
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
	draw_circle(c, 12.0, Color(_col, 0.14 * tw))
	# Cristal con seis picos que gira / Crystal with six spikes that spins
	var spin := _rot + _t * 2.2
	var pts := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in 12:
		var a := spin + i * TAU / 12.0
		var r := 9.0 if i % 2 == 0 else 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, _col)
	# Media cara en sombra para que parezca facetado / Half the face in shadow so it looks faceted
	lower.append(c)
	for i in range(3, 10):
		var a := spin + i * TAU / 12.0
		var r := 9.0 if i % 2 == 0 else 5.0
		lower.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(lower, _col.darkened(0.3))
	draw_polyline(pts + PackedVector2Array([pts[0]]), _col.darkened(0.55), 1.0)
	draw_rect(Rect2(c + Vector2(-3, -3), Vector2(2, 2)), Color(1, 1, 1, 0.9))
	# Destello en cruz de vez en cuando / Occasional cross sparkle
	if tw > 0.95:
		draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), Color(1, 1, 1, 0.8), 1.0)
		draw_line(c + Vector2(0, -9), c + Vector2(0, 9), Color(1, 1, 1, 0.8), 1.0)


func _ellipse(c: Vector2, r: Vector2, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
