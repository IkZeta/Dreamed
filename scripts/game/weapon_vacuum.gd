class_name WeaponVacuum
extends Weapon
## Aspiradora del Barrepesadillas: apunta al enemigo más cercano y solo absorbe
## en esa dirección, en un cono estrecho. Atrae a los enemigos hacia Kroker
## mientras los daña: por eso es la más arriesgada. (+25 % de velocidad)
## The Nightmare Sweeper's vacuum: aims at the nearest enemy and only sucks in that
## direction, in a narrow cone. It pulls enemies toward Kroker while hurting them,
## which makes it the riskiest weapon. (+25% speed)
##
## Mejoras / Upgrades:
##  (valores por nivel en GameState.UPGRADE_VALUES / per-level values there)
##  Svinho  — Chut: cada "cd" segundos escupe al enemigo que llega a la boquilla y sale rebotando.
##            La espera empieza larga y baja con cada nivel.
##  Stolk   — Turbo: +"pct" % de alcance, fuerza y daño.
##  Silly   — Error de memoria: lo absorbido recibe +"pct" % de daño durante "secs" segundos.

const RANGE := 320.0
const CONE := 0.42        # medio ángulo en radianes (~24°) / half angle in radians
const PULL := 170.0       # px/s hacia Kroker / toward Kroker
const DPS := 15.0
const TICK := 0.25

var _tick := 0.0
var _t := 0.0
var _dir := Vector2.RIGHT
var _spit_cd := 0.0
var _boost := 1.0
var sucking := false


func _ready() -> void:
	_boost = 1.0 + uv("stolk", "pct") / 100.0


func _physics_process(delta: float) -> void:
	_t += delta
	anim = 0.0
	sucking = false
	if primary:
		player.sucking = false
	if not run.running or not player.alive:
		Audio.set_loop("vacuum", false)
		queue_redraw()
		return
	_spit_cd = maxf(0.0, _spit_cd - delta)
	var target := nearest(RANGE * _boost * range_mult())
	if target == null:
		Audio.set_loop("vacuum", false)
		queue_redraw()
		return
	Audio.set_loop("vacuum", true, -12.0)
	# Gira la boquilla con suavidad hacia el objetivo / Turns the nozzle smoothly toward the target
	var want := (_body(target) - _nozzle_base()).normalized()
	_dir = _dir.slerp(want, minf(1.0, delta * 10.0)).normalized()
	sucking = true
	if primary:
		player.aim = _dir
		player.sucking = true
		if absf(_dir.x) > 0.2:
			player.set_facing(signf(_dir.x))

	_tick -= delta
	var do_tick := _tick <= 0.0
	if do_tick:
		_tick = TICK
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable() or e.bounce_t > 0.0:
			continue
		var to_e := _body(e) - _nozzle_base()
		if to_e.length() > RANGE * _boost * range_mult() or absf(_dir.angle_to(to_e)) > CONE:
			continue
		if lv("svinho") > 0 and to_e.length() < 90.0 and _spit_cd <= 0.0:
			_spit(e)
			continue
		e.external_pull += -to_e.normalized() * PULL * _boost
		if do_tick:
			deal(e, DPS * TICK * _boost * speed_mult(), Vector2.ZERO, 0.3)
			if lv("silly") > 0:
				e.glitch(0.0, 0.0, uv("silly", "secs"), 1.0 + uv("silly", "pct") / 100.0)
	queue_redraw()


## Escupe al enemigo con fuerza: sale rebotando / Spits the enemy out hard: it ricochets away
func _spit(e: Node2D) -> void:
	_spit_cd = uv("svinho", "cd")
	e.stun_t = maxf(e.stun_t, 0.6)
	e.start_bounce(uv("svinho", "dmg") * player.damage_mult, int(uv("svinho", "chain")))
	deal(e, uv("svinho", "dmg") * 0.5, _dir * 800.0)
	run.fx.ring(_nozzle_base() + _dir * 50.0, 24.0, KrokerArt.ACCENT["vacuum"], 0.35, 2.2)
	Audio.play("kick", -3.0, 0.1)


## La aspiradora no tiene recarga; solo se muestra la del chut de Svinho
## The vacuum has no cooldown; only Svinho's volley shows a bar
func charge_bars() -> Array:
	if lv("svinho") <= 0:
		return []
	return [[1.0 - clampf(_spit_cd / maxf(uv("svinho", "cd"), 0.01), 0.0, 1.0), UITheme.GOLD]]


## El anillo del chut sale en la propia boquilla / The volley ring sits on the nozzle itself
func charge_anchor() -> Vector2:
	if not primary:
		return super.charge_anchor()
	var hand := Vector2(15.0 * player._facing, -26.0)
	return hand + player.aim.normalized() * 44.0 + Vector2(0, -14)


func _nozzle_base() -> Vector2:
	return player.global_position + Vector2(0, -30)


## Hacia dónde apunta la boquilla / Where the nozzle points
func aim_dir() -> Vector2:
	return _dir


func _draw() -> void:
	if not sucking:
		return
	# Cono de succión con corrientes que viajan hacia la boquilla
	# Suction cone with currents travelling toward the nozzle
	var c := Vector2(0, -30)
	var col: Color = KrokerArt.ACCENT["vacuum"]
	var a := _dir.angle()
	var pts := PackedVector2Array([c])
	for i in 13:
		var ang := a - CONE + 2.0 * CONE * i / 12.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * RANGE * _boost * range_mult())
	draw_colored_polygon(pts, Color(col, 0.07))
	for i in 7:
		var k := fposmod(_t * 1.4 + i / 7.0, 1.0)  # 0 lejos → 1 cerca
		var r := lerpf(RANGE * _boost * range_mult(), 40.0, k)
		var off := sin(i * 2.3) * CONE * 0.8
		var p := c + Vector2.from_angle(a + off) * r
		var tail := c + Vector2.from_angle(a + off) * minf(RANGE * _boost * range_mult(), r + 36.0)
		draw_line(tail, p, Color(col, 0.55 * sin(k * PI)), 1.6, true)
