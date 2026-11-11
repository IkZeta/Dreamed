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
## Torretas especiales (una de cada, aparte del máximo): aparecen solas al empezar el sueño, en
## sitios al azar y separadas entre sí; no se pueden poner torretas de disparo cerca de ellas.
## Special turrets (one of each, besides the maximum): they appear by themselves when the dream
## starts, at random spots and apart from each other; gun turrets can't be placed near them.
##  Doc   — torreta curativa / healing turret (+ vida máxima, a cambio de recarga y daño).
##  Stolk — muñeco de boxeo: atrae a los cercanos y da puñetazos con empuje / boxing dummy: pulls
##          nearby enemies and punches them away.
##  Ad    — torreta de cobro: poco daño, apunta al que menos vida tiene y remata a los que tienen
##          menos del 15 %; el remate da Realidad Fragmentada / debt-collector turret: low damage,
##          aims at the weakest and finishes off those under 15%; each finish gives Fragmented Reality.
##  Pinche — fogón: atrae a los cercanos y, si se juntan "count" a su lado, explota ("boom" de
##          daño); al rato vuelve a aparecer / stove: pulls nearby enemies in and, if "count" crowd
##          it, explodes ("boom" damage); a while later it appears again.
## Otras mejoras / Other upgrades:
##  Svinho — el disparo salta a "extra" enemigos más / the shot jumps to "extra" more enemies.
##  Silly  — "turrets" torretas más de máximo y "chance" % de congelar "secs" s /
##           "turrets" more turrets at most and "chance"% to freeze for "secs" s.

const COOLDOWN := 6.0
const PLACE_RANGE := 420.0      # solo pone torretas si hay enemigos cerca / only places turrets with enemies near
const MAX_TURRETS := 3
const QUICK_START := 1.2        # espera entre las 2 primeras torretas / wait between the first 2 turrets
const RELOCATE := 900.0         # más lejos que esto, la recoloca / further than this, he moves it back
const RELOCATE_BOSS := 420.0    # contra un jefe, que se mueve mucho, la acerca antes / against a boss, who moves a lot, he brings it closer sooner
const SPECIAL_GAP := 380.0      # distancia mínima entre especiales / minimum distance between specials
const GUN_GAP := 60.0           # separación entre torretas de disparo / gap between gun turrets
const STOVE_BACK := 8.0         # segundos hasta que vuelve el fogón / seconds until the stove comes back
const NO_BUILD := 170.0         # no se ponen torretas tan cerca de una especial / no turrets this close to a special
## Ataque de Kroker (en %) que hace falta para cada nivel de torreta / Kroker's attack (in %) needed for each turret level
const LEVEL_ATTACK: Array[float] = [0.0, 10.0, 25.0, 45.0]
const EXECUTE_PCT := 15.0       # Mr. Ad remata por debajo de este % de vida / Mr. Ad finishes off below this % health

var _turrets: Array[Node2D] = []
var _special := {}              # "heal" / "dummy" / "ad" → torreta / turret
var _specials_done := false


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


## Máximo de torretas de disparo (Silly sube el máximo) / Gun turret maximum (Silly raises it)
func max_turrets() -> int:
	return MAX_TURRETS + int(uv("silly", "turrets"))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Al empezar el sueño aparecen las especiales / When the dream starts the specials appear
	if not _specials_done and run.running:
		_specials_done = true
		for kind in _wanted_specials():
			_special[kind] = _place(kind, _random_spot())


## Las torretas especiales que tocan con las mejoras que tiene / The special turrets due with the upgrades he has
func _wanted_specials() -> Array[String]:
	var out: Array[String] = []
	if lv("doc") > 0:
		out.append("heal")
	if lv("stolk") > 0:
		out.append("dummy")
	if lv("ad") > 0:
		out.append("ad")
	if lv("pinche") > 0:
		out.append("stove")
	return out


func attack() -> bool:
	if nearest(PLACE_RANGE * range_mult()) == null:
		return false
	_turrets = _turrets.filter(func(t: Node2D) -> bool: return is_instance_valid(t))
	if _turrets.size() < max_turrets():
		_turrets.append(_place("gun", _spot()))
	else:
		# Con el máximo puesto, recoloca la que se haya quedado más lejos (en el pasillo infinito)
		# With the maximum placed, move back the one left furthest away (in the endless hallway)
		var far: Node2D = null
		var boss_fight: bool = is_instance_valid(run.boss) and run.boss.state != Enemy.State.DYING
		var far_d := RELOCATE_BOSS if boss_fight else RELOCATE
		for t in _all():
			var d := t.global_position.distance_to(player.global_position)
			if d > far_d:
				far_d = d
				far = t
		if far == null:
			return false
		far.position = _spot() if far.kind == "gun" else _random_spot(far)
		run.fx.ring(far.position, 26.0, Color("5ff2ff"), 0.35, 2.0)
		# Contra un jefe, recolocar es rápido: así las torretas le siguen el ritmo
		# Against a boss, moving one is quick: so the turrets keep up with him
		if boss_fight:
			swung(true)
			Audio.play("typing", -6.0, 0.1)
			_timer = QUICK_START
			return false
	swung(true)
	Audio.play("typing", -6.0, 0.1)
	# Al empezar el sueño monta las primeras torretas deprisa / At the start of the dream he sets up the first turrets quickly
	if _turrets.size() < mini(2, max_turrets()):
		_timer = QUICK_START
		return false
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


## Sitio junto a Kroker para una torreta de disparo, lejos de las especiales
## Spot beside Kroker for a gun turret, away from the specials
func _spot() -> Vector2:
	var best := player.global_position
	var best_d := -1.0
	for i in 16:
		var r := randf_range(50.0, 90.0) if i < 8 else randf_range(110.0, 240.0)
		var side := Vector2.from_angle(randf() * TAU) * r
		var p: Vector2 = run.clamp_to_arena(player.global_position + side * Vector2(1.0, 0.6), 20.0)
		var d := _special_distance(p)
		# Tampoco encima de otra torreta de disparo / Nor on top of another gun turret
		var crowded := false
		for t in _turrets:
			if is_instance_valid(t) and t.global_position.distance_to(p) < GUN_GAP:
				crowded = true
		if d >= NO_BUILD and not crowded:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best


## Distancia a la especial más cercana / Distance to the nearest special
func _special_distance(p: Vector2, except: Node2D = null) -> float:
	var best := INF
	for t: Variant in _special.values():
		if is_instance_valid(t) and t != except:
			best = minf(best, (t as Node2D).global_position.distance_to(p))
	return best


## Sitio al azar en la zona visible, separado de las otras especiales y de Kroker
## Random spot in the visible area, apart from the other specials and from Kroker
func _random_spot(except: Node2D = null) -> Vector2:
	var area: Rect2 = run.view_rect().grow(-140.0)
	var best := player.global_position
	var best_score := -1.0
	for i in 30:
		var p: Vector2 = run.clamp_to_arena(area.position + Vector2(randf(), randf()) * area.size, 30.0)
		var score := minf(_special_distance(p, except) / SPECIAL_GAP, p.distance_to(player.global_position) / 200.0)
		if score >= 1.0:
			return p
		if score > best_score:
			best_score = score
			best = p
	return best


func _place(kind: String, at: Vector2) -> Node2D:
	var t := Turret.new()
	t.weapon = self
	t.kind = kind
	t.level = turret_level()
	t.position = at
	run.world.add_child(t)
	run.fx.ring(t.position, 26.0, Turret.KIND_COLOR.get(kind, Color("5ff2ff")), 0.35, 2.0)
	return t


## El fogón del Pinche ha explotado: al rato sale otro en otro sitio
## The Kitchen Boy's stove exploded: a while later another one appears elsewhere
func stove_broken(t: Node2D) -> void:
	_special.erase("stove")
	get_tree().create_timer(STOVE_BACK, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and run.running and not is_instance_valid(_special.get("stove")):
			_special["stove"] = _place("stove", _random_spot()))


## El Pinche ya no sangra con el portátil: tiene su fogón / The Kitchen Boy doesn't bleed with the laptop: he has his stove
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
	const HEAL_RADIUS := 450.0      # alcance de las balas curativas / healing bullet range
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
	const STOVE_PULL_RADIUS := 260.0
	const KIND_COLOR := {"gun": Color("5ff2ff"), "heal": Color("9be38a"), "dummy": Color("ff8f9e"), "ad": Color("ffb04a"), "stove": Color("ff9a3a")}
	const SPRITE := {"gun": "turret", "heal": "turret_heal", "dummy": "turret_dummy", "ad": "turret_ad", "stove": "turret_stove"}

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
	var _face := 1.0          # hacia dónde mira (los cañones apuntan a la derecha) / facing (the barrels point right)

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
		# El nivel sigue al ataque de Kroker también en las que ya están puestas
		# The level follows Kroker's attack on turrets already placed too
		if kind == "gun" and fmod(_t, 0.5) < delta:
			var lvl := WeaponLaptop.turret_level()
			if lvl != level:
				var up := lvl > level
				level = lvl
				if up:
					weapon.run.fx.ring(global_position + Vector2(0, -20), 30.0, LEVEL_COLOR[level - 1], 0.4, 2.5)
					weapon.run.fx.text(global_position + Vector2(0, -70), "Lv %d" % level, LEVEL_COLOR[level - 1], 20)
					Audio.play("chime", -14.0, 0.1)
		if kind == "dummy":
			_pull(DUMMY_PULL_RADIUS, weapon.uv("stolk", "pull"))
		if kind == "stove":
			_pull(STOVE_PULL_RADIUS, weapon.uv("pinche", "pull"))
			_boom -= delta
			if _boom <= 0.0:
				_boom = BOOM_CHECK
				_check_boom()
			return
		_fire -= delta * weapon.speed_mult()
		if _fire > 0.0:
			return
		match kind:
			"heal": _heal()
			"dummy": _box()
			_: _shoot()

	## Le dispara a Kroker una bala curativa si le falta vida y está a su alcance
	## Fires a healing bullet at Kroker if he's missing health and within range
	func _heal() -> void:
		var p: Player = weapon.player
		if p.global_position.distance_to(global_position) > HEAL_RADIUS or p.hp >= p.max_hp:
			_fire = 0.3
			return
		_fire = HEAL_EVERY
		var b := HealShot.new()
		b.weapon = weapon
		b.amount = weapon.uv("doc", "heal")
		b.position = global_position + Vector2(0, -27 * SIZE)
		weapon.run.world.add_child(b)
		Audio.play("turret", -10.0, 0.05)

	## Muñeco y fogón: atraen a los de alrededor / Dummy and stove: pull those around them
	func _pull(radius: float, force: float) -> void:
		for e: Node2D in weapon.run.enemies.get_children():
			if not e is Enemy or not e.is_targetable() or e.is_boss():
				continue
			var to := global_position - e.global_position
			var d := to.length()
			if d < radius and d > DUMMY_REACH * 0.6:
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
		Audio.play("punch", -6.0, 0.12)

	## Torreta de cobro: apunta al que menos vida le queda (en proporción) dentro de su alcance; los jefes, los últimos
	## Debt-collector turret: aims at whoever has the least health left (proportionally) in range; bosses last
	func _weakest() -> Node2D:
		var best: Node2D = null
		var best_k := INF
		var r := RANGE * weapon.range_mult()
		for e: Node2D in weapon.run.enemies.get_children():
			if not e is Enemy or not e.is_targetable():
				continue
			var en := e as Enemy
			if en.aim_point().distance_to(global_position + Vector2(0, -24)) > r:
				continue
			var k := en.hp / maxf(en.max_hp, 1.0) + (10.0 if en.is_boss() else 0.0)
			if k < best_k:
				best_k = k
				best = en
		return best

	func _shoot() -> void:
		var target := _weakest() if kind == "ad" else weapon.nearest(RANGE * weapon.range_mult(), global_position + Vector2(0, -24))
		if target == null:
			_fire = 0.15
			return
		_fire = FIRE_EVERY
		var from := global_position + Vector2(0, -27 * SIZE)
		if absf(target.global_position.x - global_position.x) > 8.0:
			_face = signf(target.global_position.x - global_position.x)
		if kind == "ad":
			var to: Vector2 = target.aim_point()
			_beams.append([from - global_position, to - global_position, 0.1])
			weapon.on_ad_hit(target, (to - from).normalized())
			Audio.play("turret", -10.0, 0.15)
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
		Audio.play("turret", -8.0, 0.15)

	## Fogón del Pinche: con muchos enemigos pegados, explota / The Kitchen Boy's stove: with many enemies crowding it, it explodes
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
		Audio.play("stove_boom", -2.0, 0.08)
		weapon.stove_broken(self)
		queue_free()

	func _draw() -> void:
		var col: Color = LEVEL_COLOR[clampi(level, 1, 4) - 1] if kind == "gun" else KIND_COLOR[kind]
		var s := (0.6 + 0.4 * _pop) * SIZE
		draw_circle(Vector2(0, 2), 14.0 * SIZE, Color(0.05, 0.02, 0.15, 0.3))
		# El muñeco se echa hacia atrás y vuelve al dar un puñetazo / The dummy rocks back and forth when punching
		var rock := sin(_punch * PI) * 0.25 if kind == "dummy" else 0.0
		var sprite: String = SPRITE[kind]
		var lift := 0.0
		if kind == "gun":
			# Cada nivel, un modelo más futurista; el 4 flota / Each level, a more futuristic model; level 4 floats
			sprite = "turret" if level <= 1 else "turret_%d" % level
			if level >= 4:
				lift = -8.0 + sin(_t * 2.5) * 3.0
				draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-26, -12) * SIZE, Vector2(52, 24) * SIZE), false, Color(col, 0.35))
			elif level == 3:
				draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-20, -8) * SIZE, Vector2(40, 16) * SIZE), false, Color(col, 0.2))
		draw_set_transform(Vector2(0, lift * SIZE), rock, Vector2(s * (_face if kind == "gun" and level >= 2 else 1.0), s))
		Sprites.draw(self, sprite)
		if kind == "stove":
			# Llamas del fogón, más altas cuando está a punto / Stove flames, taller when it's ready
			var ready := 1.0 if _boom <= BOOM_CHECK else 0.5
			for i in 3:
				var x := -6.0 + i * 6.0
				var h := (6.0 + 3.0 * sin(_t * 14.0 + i * 2.1)) * ready
				draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5, -24), Vector2(x, -24 - h), Vector2(x + 2.5, -24)]), Color("ff9a3a"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 1.2, -24), Vector2(x, -24 - h * 0.55), Vector2(x + 1.2, -24)]), Color("8fd8ff"))
		elif kind != "dummy":
			# Luz de la pantalla y del nivel / Screen and level light
			var blink := 0.6 + 0.4 * sin(_t * 6.0)
			draw_rect(Rect2(-7, -31, 14, 8), Color(col, 0.55 * blink))
			if kind == "gun" and level <= 2:
				for i in level:
					draw_rect(Rect2(-7 + i * 4, -18, 2, 2), col)
			if kind == "gun" and level >= 4:
				# Aro de energía que gira / Spinning energy ring
				var ang := _t * 2.0
				draw_arc(Vector2(0, -26), 20.0, ang, ang + PI * 1.3, 24, Color(col, 0.75), 1.5)
				draw_arc(Vector2(0, -26), 20.0, ang + PI, ang + PI * 1.6, 12, Color(col, 0.4), 1.5)
		if kind == "heal":
			var r := 18.0 + fmod(_t * 20.0, 30.0)
			draw_arc(Vector2(0, -6), r, 0, TAU, 24, Color(col, 0.35 * (1.0 - (r - 18.0) / 30.0)), 1.5)
		draw_set_transform(Vector2.ZERO)
		if kind == "dummy" or kind == "stove":
			# Zona de atracción, muy suave / Pull zone, very faint
			draw_arc(Vector2.ZERO, DUMMY_PULL_RADIUS if kind == "dummy" else STOVE_PULL_RADIUS, 0, TAU, 48, Color(col, 0.12), 1.5)
		for b: Array in _beams:
			var k := float(b[2]) / 0.1
			draw_line(b[0], b[1], Color(col, 0.9 * k), 3.0)
			draw_line(b[0], b[1], Color(1, 1, 1, 0.8 * k), 1.0)


## Bala curativa: va siguiendo a Kroker y le cura al tocarle / Healing bullet: homes in on Kroker and heals him on touch
class HealShot extends Node2D:
	const SPEED := 520.0
	var weapon: WeaponLaptop
	var amount := 1.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 41

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(weapon) or not is_instance_valid(weapon.player):
			queue_free()
			return
		_t += delta
		var p: Player = weapon.player
		var goal := p.global_position + Player.HURT
		var to := goal - global_position
		if to.length() < 22.0 or _t > 3.0:
			if to.length() < 22.0 and p.alive:
				p.heal(amount)
				weapon.run.fx.ring(goal, 30.0, Color("9be38a"), 0.4, 2.0)
				Audio.play("pickup", -14.0, 0.2)
			queue_free()
			return
		global_position += to.normalized() * minf(SPEED * delta, to.length())
		queue_redraw()

	func _draw() -> void:
		var col := Color("9be38a")
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(-16, -16, 32, 32), false, Color(col, 0.5))
		draw_circle(Vector2.ZERO, 6.0, col)
		draw_rect(Rect2(-1.5, -4, 3, 8), Color.WHITE)
		draw_rect(Rect2(-4, -1.5, 8, 3), Color.WHITE)
