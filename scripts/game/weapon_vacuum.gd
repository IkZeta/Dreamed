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
const DPS := 12.0
## Cada cuánto muerde el chupón. Empieza lento y la velocidad de ataque lo acorta poco a poco
## (la mitad de lo que sube: +20 % de velocidad de ataque = un 10 % más rápido), nunca por debajo
## de 0,25 s. Cada mordisco hace el daño de ese rato, así que con 0 de velocidad de ataque son
## 13 de daño por segundo.
## How often the suction bites. It starts slow and attack speed shortens it bit by bit (half as
## much as it rises: +20% attack speed = 10% faster), never below 0.25 s. Each bite deals that
## stretch's worth of damage, so with 0 attack speed it's 13 damage per second.
const TICK := 0.5
const TICK_MIN := 0.25
const SPEED_SCALE := 0.5

var _tick := 0.0
var _t := 0.0
var _dir := Vector2.RIGHT
var _spit_cd := 0.0
var _boost := 1.0
var sucking := false
## Pulso de cada mordisco (1 → 0): el cono se aviva y la boquilla escupe un soplo
## Each bite's pulse (1 → 0): the cone brightens and the nozzle puffs
var _bite := 0.0


func _ready() -> void:
	_boost = 1.0 + uv("stolk", "pct") / 100.0


func _physics_process(delta: float) -> void:
	_t += delta
	_bite = maxf(0.0, _bite - delta * 5.0)
	anim = 0.0
	sucking = false
	if primary:
		player.sucking = false
	if not run.running or not player.alive or player.weapon_stunk(self):
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
		_tick = tick_time()
	# Los del cono, del más cercano al más lejano: atrae a todos, pero el daño se reparte (el primero
	# entero, cada uno de los siguientes un 30 % menos, como poco una cuarta parte)
	# Those in the cone, nearest first: it pulls them all, but the damage is shared (the first in
	# full, each one after 30% less, at least a quarter)
	var inside: Array = []
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable() or e.bounce_t > 0.0:
			continue
		var to_e := _body(e) - _nozzle_base()
		if to_e.length() > RANGE * _boost * range_mult() or absf(_dir.angle_to(to_e)) > CONE:
			continue
		inside.append(e)
	inside.sort_custom(func(a: Node2D, b: Node2D) -> bool: return _body(a).distance_squared_to(_nozzle_base()) < _body(b).distance_squared_to(_nozzle_base()))
	var share := 1.0
	for e: Node2D in inside:
		var to_e := _body(e) - _nozzle_base()
		if lv("svinho") > 0 and to_e.length() < 90.0 and _spit_cd <= 0.0:
			_spit(e)
			continue
		e.external_pull += -to_e.normalized() * PULL * _boost
		e.vacuumed = true
		if GameState.has_duo("silly_lynx") and primary:
			_digitize(e, delta)
		if do_tick:
			_bite = 1.0
			deal(e, DPS * TICK * _boost * share, Vector2.ZERO, 0.6)
			share = maxf(0.25, share * 0.7)
			if lv("silly") > 0:
				e.glitch(0.0, 0.0, uv("silly", "secs"), 1.0 + uv("silly", "pct") / 100.0)
	queue_redraw()


## Espera entre mordiscos según la velocidad de ataque / Wait between bites by attack speed
func tick_time() -> float:
	var k := maxf(0.5, 1.0 + GameState.stat("attack_speed") / 100.0 * SPEED_SCALE)
	return maxf(TICK_MIN, TICK / k)


## Dúo Silly y D. Lynx: lo que aspiras un rato sale convertido en un doble digital que actúa para
## ti / Silly & D. Lynx duo: whatever you suck in for a while comes out as a digital double acting for you
func _digitize(e: Node2D, delta: float) -> void:
	var en := e as Enemy
	if en == null or not en.can_act():
		return
	var t: float = en.get_meta("suck_t", 0.0) + delta
	en.set_meta("suck_t", t)
	if t < GameState.duo_value("silly_lynx", "secs"):
		return
	var acting := 0
	for o: Node in run.enemies.get_children():
		if o is Enemy and (o as Enemy).actor_t > 0.0:
			acting += 1
	if acting >= int(GameState.duo_value("silly_lynx", "max")):
		return
	en.set_meta("suck_t", 0.0)
	en.start_acting(GameState.duo_value("silly_lynx", "dur"), 6.0 + 2.0 * lv("lynx"))
	en.glitch_t = maxf(en.glitch_t, GameState.duo_value("silly_lynx", "dur"))
	en.knock = _dir * 600.0
	run.fx.ring(en.aim_point(), 28.0, Color("5ff2ff"), 0.4, 2.4)
	run.fx.text(en.aim_point() + Vector2(0, -60), tr("LYNX_SHOUT"), Color("ffb0b0"), 18)
	Audio.play("glitch", -6.0, 0.1)


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


## Grosor mínimo de línea: un píxel del arte (4 de pantalla), como en FX
## Minimum line width: one art pixel (4 on screen), as in FX
const PXW := 4.0


func _draw() -> void:
	if not sucking:
		return
	# Cono de succión: relleno tenue, bordes marcados y corrientes que entran en espiral hacia la
	# boquilla, con motas de polvo. En cada mordisco todo se aviva un instante.
	# Suction cone: faint fill, marked edges and currents spiralling into the nozzle, with dust
	# motes. On every bite it all brightens for a moment.
	var c := Vector2(0, -30)
	var col: Color = KrokerArt.ACCENT["vacuum"]
	var a := _dir.angle()
	var reach := RANGE * _boost * range_mult()
	var bite := _bite * _bite
	var pts := PackedVector2Array([c])
	for i in 13:
		var ang := a - CONE + 2.0 * CONE * i / 12.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * reach)
	draw_colored_polygon(pts, Color(col, 0.06 + 0.08 * bite))
	# Bordes: dos rayas discontinuas que avanzan hacia dentro / Edges: two dashed lines marching inwards
	for side: float in [-1.0, 1.0]:
		var dir := Vector2.from_angle(a + CONE * side)
		var dash := 26.0
		var shift := fposmod(_t * 120.0, dash * 2.0)
		var d := reach - shift
		while d > 30.0:
			var d2 := maxf(30.0, d - dash)
			draw_line(c + dir * d, c + dir * d2, Color(col, 0.18 + 0.25 * bite), PXW)
			d -= dash * 2.0
	# Corrientes: arcos que se curvan hacia la boquilla y aceleran al acercarse
	# Currents: arcs curving towards the nozzle, speeding up as they get close
	for i in 6:
		var k := fposmod(_t * 1.6 + i / 6.0, 1.0)
		var kk := k * k
		var r := lerpf(reach, 34.0, kk)
		var off := sin(i * 2.3) * CONE * 0.75 * (1.0 - kk)
		var swirl := (1.0 - kk) * 0.5 * (1.0 if i % 2 == 0 else -1.0)
		var head := c + Vector2.from_angle(a + off) * r
		var tail := c + Vector2.from_angle(a + off + swirl * 0.35) * minf(reach, r + 30.0 + 40.0 * kk)
		draw_line(tail, head, Color(col.lerp(Color.WHITE, 0.3), (0.35 + 0.35 * bite) * sin(k * PI)), PXW)
	# Motas de polvo que entran girando / Dust motes swirling in
	for i in 9:
		var k := fposmod(_t * 0.9 + i * 0.137, 1.0)
		var kk := k * k * k
		var r := lerpf(reach * 0.95, 26.0, kk)
		var off := sin(i * 1.7 + _t * 3.0) * CONE * 0.9 * (1.0 - kk)
		var p := (c + Vector2.from_angle(a + off) * r).round()
		var sz := PXW if i % 3 else PXW * 1.5
		draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(Color("e8e0ff") if i % 2 else col, 0.75 * sin(k * PI)))
	# Boca de la boquilla: un remolino que se aprieta en cada mordisco
	# Nozzle mouth: a little whirl that tightens on every bite
	var mouth := c + _dir * 40.0
	var rr := 14.0 - 5.0 * bite
	draw_arc(mouth, rr, _t * 9.0, _t * 9.0 + 3.6, 10, Color(col, 0.55 + 0.4 * bite), PXW)
	if bite > 0.05:
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(mouth - Vector2(24, 24), Vector2(48, 48)), false, Color(col.lerp(Color.WHITE, 0.5), 0.5 * bite))
