class_name WeaponLaptop
extends Weapon
## Portátil (a distancia): Kroker teclea y pone torretas en el suelo, a su lado. No desaparecen:
## hay un máximo y, una vez puestas, ya no salen más (si una se queda muy lejos de Kroker, la
## recoloca a su lado). Salen de tarde en tarde: dependen de la velocidad de ataque, que empieza
## muy baja.
## Laptop (ranged): Kroker types and places turrets on the floor beside him. They don't go away:
## there's a maximum and once placed no more come out (if one is left very far from Kroker, he
## moves it back beside him). They come out rarely: they depend on attack speed, which starts
## very low.
##
## Nivel de las torretas de disparo: sube con el ataque de Kroker, hasta 4. El 2 quema, el 3
## empuja y el 4 hace sangrar. / Gun turret level: goes up with Kroker's attack, up to 4. Level 2
## burns, 3 pushes and 4 makes bleed.
##
## Torretas especiales (una de cada, aparte del máximo) / Special turrets (one of each, besides the maximum):
##  Doc   — torreta curativa / healing turret (+ vida máxima, a cambio de recarga y daño).
##  Stolk — muñeco de boxeo: atrae a los cercanos y da puñetazos con empuje / boxing dummy: pulls
##          nearby enemies and punches them away.
##  Ad    — torreta de cobro: poco daño, pero remata a los que tienen menos del 25 % de vida y
##          el remate da Realidad Fragmentada / debt-collector turret: low damage, but finishes off
##          those under 25% health and each finish gives Fragmented Reality.
## Otras mejoras / Other upgrades:
##  Svinho — el disparo salta a "extra" enemigos más / the shot jumps to "extra" more enemies.
##  Silly  — "chance" % de congelar "secs" s / "chance"% to freeze for "secs" s.
##  Pinche — si se juntan "count" enemigos al lado de una torreta, explota ("boom" de daño), se
##           rompe y Kroker pone otra al instante / if "count" enemies crowd a turret, it explodes
##           ("boom" damage), breaks and Kroker places another one at once.

const COOLDOWN := 6.0
const PLACE_RANGE := 420.0      # solo pone torretas si hay enemigos cerca / only places turrets with enemies near
const MAX_TURRETS := 3
const RELOCATE := 900.0         # más lejos que esto, la recoloca / further than this, he moves it back
## Ataque de Kroker (en %) que hace falta para cada nivel de torreta / Kroker's attack (in %) needed for each turret level
const LEVEL_ATTACK: Array[float] = [0.0, 10.0, 25.0, 45.0]
const EXECUTE_PCT := 25.0       # Mr. Ad remata por debajo de este % de vida / Mr. Ad finishes off below this % health

var _turrets: Array[Node2D] = []
var _special := {}              # "heal" / "dummy" / "ad" → torreta / turret


func _init() -> void:
	cooldown = COOLDOWN


func _ready() -> void:
	cooldown = COOLDOWN * (1.0 + uv("doc", "pct") / 100.0)


## Nivel de las torretas según el ataque / Turret level from attack
static func turret_level() -> int:
	var atk := GameState.stat("attack")
	var lvl := 1
	for i in LEVEL_ATTACK.size():
		if atk >= LEVEL_ATTACK[i]:
			lvl = i + 1
	return lvl


## Las torretas especiales que tocan con las mejoras que tiene / The special turrets due with the upgrades he has
func _wanted_specials() -> Array[String]:
	var out: Array[String] = []
	if lv("doc") > 0:
		out.append("heal")
	if lv("stolk") > 0:
		out.append("dummy")
	if lv("ad") > 0:
		out.append("ad")
	return out


func attack() -> bool:
	if nearest(PLACE_RANGE * range_mult()) == null:
		return false
	_turrets = _turrets.filter(func(t: Node2D) -> bool: return is_instance_valid(t))
	var placed := false
	if _turrets.size() < MAX_TURRETS:
		_turrets.append(_place("gun"))
		placed = true
	# Una especial que falte (de una en una) / One missing special (one at a time)
	for kind in _wanted_specials():
		if not is_instance_valid(_special.get(kind)):
			_special[kind] = _place(kind)
			placed = true
			break
	# Si no ha puesto nada, recoloca la que se haya quedado más lejos
	# If nothing was placed, move back the one left furthest away
	if not placed:
		var far: Node2D = null
		var far_d := RELOCATE
		for t in _all():
			var d := t.global_position.distance_to(player.global_position)
			if d > far_d:
				far_d = d
				far = t
		if far == null:
			return false
		far.position = _spot()
		run.fx.ring(far.position, 26.0, Color("5ff2ff"), 0.35, 2.0)
	swung(true)
	Audio.play("hack", -10.0, 0.15)
	return true


func _all() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for t in _turrets:
		if is_instance_valid(t):
			out.append(t)
	for t: Variant in _special.values():
		if is_instance_valid(t):
			out.append(t)
	return out


func _spot() -> Vector2:
	var side := Vector2.from_angle(randf() * TAU) * randf_range(50.0, 90.0)
	return run.clamp_to_arena(player.global_position + side * Vector2(1.0, 0.6), 20.0)


func _place(kind: String) -> Node2D:
	var t := Turret.new()
	t.weapon = self
	t.kind = kind
	t.level = turret_level()
	t.position = _spot()
	run.world.add_child(t)
	run.fx.ring(t.position, 26.0, Turret.KIND_COLOR.get(kind, Color("5ff2ff")), 0.35, 2.0)
	return t


## El Pinche: la torreta ha explotado; Kroker pone otra al instante
## The Kitchen Boy: the turret exploded; Kroker places another one at once
func turret_broken(t: Node2D) -> void:
	var kind: String = t.kind
	if kind == "gun":
		_turrets.erase(t)
		_turrets.append(_place("gun"))
	else:
		_special[kind] = _place(kind)
	swung(true)


## El Pinche ya no sangra con el portátil: sus torretas explotan / The Kitchen Boy doesn't bleed with the laptop: its turrets explode
func _pinche(_e: Node2D) -> void:
	pass


## Daño de cada disparo / Damage of each shot
func shot_damage() -> float:
	return Turret.DAMAGE * (1.0 - uv("doc", "dmg") / 100.0)


## Lo que pasa al acertar una torreta de disparo: los efectos de nivel y Silly
## What happens when a gun turret hits: level effects and Silly
func on_turret_hit(e: Node2D, dir: Vector2, level: int) -> void:
	var push := dir * (Turret.PUSH if level >= 3 else 60.0)
	deal(e, shot_damage(), push)
	_after_hit(e, level)


func _after_hit(e: Node2D, level: int) -> void:
	if not is_instance_valid(e) or not e is Enemy or not e.is_targetable():
		return
	var en := e as Enemy
	if level >= 2:
		en.burn(1.0, 3.0, 10.0)
	if level >= 4:
		en.bleed(2.0, 3.0)
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		en.glitch(uv("silly", "secs"))


## Torreta de Mr. Ad: poco daño, pero remata a los que están muy tocados y cobra por ello
## Mr. Ad's turret: low damage, but finishes off the badly hurt and charges for it
func on_ad_hit(e: Node2D, dir: Vector2) -> void:
	if not e is Enemy:
		return
	var en := e as Enemy
	var execute := not en.is_boss() and en.hp <= en.max_hp * EXECUTE_PCT / 100.0
	if execute:
		var pos := en.global_position
		deal(en, en.hp * 4.0 + 10.0, dir * 120.0)
		if en.state == Enemy.State.DYING:
			run.gain_reality(int(uv("ad", "cash")), pos)
			run.fx.text(pos + Vector2(0, -90), "$", Color("ffb04a"), 26)
			Audio.play("reality", -10.0, 0.1)
	else:
		deal(en, Turret.AD_DAMAGE, dir * 40.0)


class Turret extends Node2D:
	const RANGE := 300.0
	const FIRE_EVERY := 0.8
	const DAMAGE := 4.0
	const AD_DAMAGE := 2.0
	const PUSH := 300.0
	const JUMP := 220.0
	const HEAL_RADIUS := 170.0
	const HEAL_EVERY := 4.0
	const DUMMY_PULL_RADIUS := 240.0
	const DUMMY_REACH := 80.0
	const DUMMY_EVERY := 0.7
	const DUMMY_PUSH := 520.0
	const BOOM_CHECK := 0.5
	const BOOM_ARM := 3.0           # segundos antes de poder explotar / seconds before it can explode
	const BOOM_NEAR := 110.0
	const BOOM_RADIUS := 170.0
	const SIZE := 1.3               # escala del dibujo / drawing scale
	## Color de cada nivel / Colour of each level
	const LEVEL_COLOR: Array[Color] = [Color("5ff2ff"), Color("ffb06a"), Color("b9a2ff"), Color("ff5f7a")]
	const KIND_COLOR := {"gun": Color("5ff2ff"), "heal": Color("9be38a"), "dummy": Color("ff8f9e"), "ad": Color("ffb04a")}
	const SPRITE := {"gun": "turret", "heal": "turret_heal", "dummy": "turret_dummy", "ad": "turret_ad"}

	var weapon: WeaponLaptop
	var kind := "gun"
	var level := 1
	var _fire := 0.4
	var _boom := BOOM_ARM
	var _beams: Array = []    # [[desde, hasta, tiempo], ...] / [[from, to, time], ...]
	var _t := 0.0
	var _pop := 0.0
	var _punch := 0.0
	var _broken := false

	func _ready() -> void:
		z_index = 5
		add_to_group("turrets")

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(weapon) or not is_instance_valid(weapon.player):
			queue_free()
			return
		_t += delta
		_pop = minf(1.0, _pop + delta * 5.0)
		_punch = maxf(0.0, _punch - delta * 4.0)
		for b: Array in _beams:
			b[2] = float(b[2]) - delta
		_beams = _beams.filter(func(b: Array) -> bool: return float(b[2]) > 0.0)
		queue_redraw()
		if not weapon.run.running or _broken:
			return
		if kind == "dummy":
			_pull()
		if weapon.lv("pinche") > 0:
			_boom -= delta
			if _boom <= 0.0:
				_boom = BOOM_CHECK
				_check_boom()
				if _broken:
					return
		_fire -= delta * weapon.speed_mult()
		if _fire > 0.0:
			return
		match kind:
			"heal": _heal()
			"dummy": _box()
			_: _shoot()

	func _heal() -> void:
		_fire = HEAL_EVERY
		var p: Player = weapon.player
		if p.global_position.distance_to(global_position) < HEAL_RADIUS and p.hp < p.max_hp:
			p.heal(weapon.uv("doc", "heal"))
			weapon.run.fx.ring(p.global_position + Vector2(0, -40), 30.0, KIND_COLOR["heal"], 0.4, 2.0)
			Audio.play("pickup", -16.0, 0.2)

	## Muñeco de boxeo: atrae a los de alrededor / Boxing dummy: pulls those around it
	func _pull() -> void:
		var force := weapon.uv("stolk", "pull")
		for e: Node2D in weapon.run.enemies.get_children():
			if not e is Enemy or not e.is_targetable() or e.is_boss():
				continue
			var to := global_position - e.global_position
			var d := to.length()
			if d < DUMMY_PULL_RADIUS and d > DUMMY_REACH * 0.6:
				(e as Enemy).external_pull += to.normalized() * force

	## Puñetazo al que esté más cerca / Punch the closest one
	func _box() -> void:
		var target := weapon.nearest(DUMMY_REACH, global_position + Vector2(0, -20))
		if target == null:
			_fire = 0.1
			return
		_fire = DUMMY_EVERY
		_punch = 1.0
		var dir := (target.global_position - global_position).normalized()
		weapon.deal(target, weapon.uv("stolk", "dmg"), dir * DUMMY_PUSH)
		weapon.run.fx.ring(target.global_position + Vector2(0, -30), 18.0, KIND_COLOR["dummy"], 0.25, 2.0)
		Audio.play("hit", -8.0, 0.15)

	func _shoot() -> void:
		var target := weapon.nearest(RANGE * weapon.range_mult(), global_position + Vector2(0, -24))
		if target == null:
			_fire = 0.15
			return
		_fire = FIRE_EVERY
		var from := global_position + Vector2(0, -27 * SIZE)
		if kind == "ad":
			var to: Vector2 = target.aim_point()
			_beams.append([from - global_position, to - global_position, 0.1])
			weapon.on_ad_hit(target, (to - from).normalized())
			Audio.play("laser", -20.0, 0.15)
			return
		var hit: Array = []
		var jumps := 1 + int(weapon.uv("svinho", "extra"))
		var cur := target
		while cur != null and jumps > 0:
			var to: Vector2 = cur.aim_point()
			_beams.append([from - global_position, to - global_position, 0.1])
			weapon.on_turret_hit(cur, (to - from).normalized(), level)
			hit.append(cur)
			jumps -= 1
			from = to
			cur = weapon.nearest(JUMP * weapon.range_mult(), from, hit) if jumps > 0 else null
		Audio.play("laser", -18.0, 0.15)

	## El Pinche: con muchos enemigos pegados, explota / The Kitchen Boy: with many enemies crowding it, it explodes
	func _check_boom() -> void:
		var near := 0
		for e: Node2D in weapon.run.enemies.get_children():
			if e.is_targetable() and e.global_position.distance_to(global_position) < BOOM_NEAR:
				near += 1
		if near < int(weapon.uv("pinche", "count")):
			return
		_broken = true
		var dmg := weapon.uv("pinche", "boom")
		for e: Node2D in weapon.run.enemies.get_children():
			if e.is_targetable() and e.global_position.distance_to(global_position) < BOOM_RADIUS:
				var dir := (e.global_position - global_position).normalized()
				weapon.deal(e, dmg, dir * 380.0)
		weapon.run.fx.ring(global_position, BOOM_RADIUS, Color("ff9a3a"), 0.45, 4.0)
		weapon.run.fx.ring(global_position, BOOM_RADIUS * 0.5, Color("ffe08a"), 0.3, 3.0)
		weapon.run.shake(10.0)
		Audio.play("crack", -4.0, 0.1)
		weapon.turret_broken(self)
		queue_free()

	func _draw() -> void:
		var col: Color = LEVEL_COLOR[clampi(level, 1, 4) - 1] if kind == "gun" else KIND_COLOR[kind]
		var s := (0.6 + 0.4 * _pop) * SIZE
		draw_circle(Vector2(0, 2), 14.0 * SIZE, Color(0.05, 0.02, 0.15, 0.3))
		# El muñeco se echa hacia atrás y vuelve al dar un puñetazo / The dummy rocks back and forth when punching
		var rock := sin(_punch * PI) * 0.25 if kind == "dummy" else 0.0
		draw_set_transform(Vector2.ZERO, rock, Vector2(s, s))
		Sprites.draw(self, SPRITE[kind])
		if kind != "dummy":
			# Luz de la pantalla y del nivel / Screen and level light
			var blink := 0.6 + 0.4 * sin(_t * 6.0)
			draw_rect(Rect2(-7, -31, 14, 8), Color(col, 0.55 * blink))
			if kind == "gun":
				for i in level:
					draw_rect(Rect2(-7 + i * 4, -18, 2, 2), col)
		if kind == "heal":
			var r := 18.0 + fmod(_t * 20.0, 30.0)
			draw_arc(Vector2(0, -6), r, 0, TAU, 24, Color(col, 0.35 * (1.0 - (r - 18.0) / 30.0)), 1.5)
		draw_set_transform(Vector2.ZERO)
		if kind == "dummy":
			# Zona de atracción, muy suave / Pull zone, very faint
			draw_arc(Vector2.ZERO, DUMMY_PULL_RADIUS, 0, TAU, 48, Color(col, 0.12), 1.5)
		# El Pinche: aviso cuando está cargada / The Kitchen Boy: hint when it's armed
		if weapon and weapon.lv("pinche") > 0 and _boom <= BOOM_CHECK:
			draw_circle(Vector2(10, -40) * SIZE, 2.5, Color("ff9a3a", 0.6 + 0.4 * sin(_t * 8.0)))
		for b: Array in _beams:
			var k := float(b[2]) / 0.1
			draw_line(b[0], b[1], Color(col, 0.9 * k), 3.0)
			draw_line(b[0], b[1], Color(1, 1, 1, 0.8 * k), 1.0)
