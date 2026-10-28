class_name WeaponVacuum
extends Weapon
## Aspiradora del Barrepesadillas: apunta al enemigo más cercano y solo absorbe
## en esa dirección, en un cono estrecho. Atrae a los enemigos hacia Kroker
## mientras los daña: por eso es la más arriesgada. (+25 % de velocidad)
## The Nightmare Sweeper's vacuum: aims at the nearest enemy and only sucks in that
## direction, in a narrow cone. It pulls enemies toward Kroker while hurting them,
## which makes it the riskiest weapon. (+25% speed)

const RANGE := 300.0
const CONE := 0.42        # medio ángulo en radianes (~24°) / half angle in radians
const PULL := 170.0       # px/s hacia Kroker / toward Kroker
const DPS := 11.0
const TICK := 0.25

var _tick := 0.0
var _t := 0.0
var _dir := Vector2.RIGHT


func _physics_process(delta: float) -> void:
	_t += delta
	player.sucking = false
	if not run.running or not player.alive:
		Audio.set_loop("vacuum", false)
		queue_redraw()
		return
	var target := nearest(RANGE)
	if target == null:
		Audio.set_loop("vacuum", false)
		queue_redraw()
		return
	Audio.set_loop("vacuum", true, -6.0)
	# Gira la boquilla con suavidad hacia el objetivo / Turns the nozzle smoothly toward the target
	var want := (_body(target) - _nozzle_base()).normalized()
	_dir = _dir.slerp(want, minf(1.0, delta * 10.0)).normalized()
	player.aim = _dir
	player.sucking = true
	if absf(_dir.x) > 0.2:
		player.set_facing(signf(_dir.x))

	_tick -= delta
	var do_tick := _tick <= 0.0
	if do_tick:
		_tick = TICK
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable():
			continue
		var to_e := _body(e) - _nozzle_base()
		if to_e.length() > RANGE or absf(_dir.angle_to(to_e)) > CONE:
			continue
		e.external_pull += -to_e.normalized() * PULL
		if do_tick:
			deal(e, DPS * TICK)
	queue_redraw()


func _nozzle_base() -> Vector2:
	return player.global_position + Vector2(0, -62)


func _draw() -> void:
	if not player.sucking:
		return
	# Cono de succión con corrientes que viajan hacia la boquilla
	# Suction cone with currents travelling toward the nozzle
	var c := Vector2(0, -62)
	var col: Color = KrokerArt.ACCENT["vacuum"]
	var a := _dir.angle()
	var pts := PackedVector2Array([c])
	for i in 13:
		var ang := a - CONE + 2.0 * CONE * i / 12.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * RANGE)
	draw_colored_polygon(pts, Color(col, 0.07))
	for i in 7:
		var k := fposmod(_t * 1.4 + i / 7.0, 1.0)  # 0 lejos → 1 cerca
		var r := lerpf(RANGE, 40.0, k)
		var off := sin(i * 2.3) * CONE * 0.8
		var p := c + Vector2.from_angle(a + off) * r
		var tail := c + Vector2.from_angle(a + off) * minf(RANGE, r + 36.0)
		draw_line(tail, p, Color(col, 0.55 * sin(k * PI)), 1.6, true)
