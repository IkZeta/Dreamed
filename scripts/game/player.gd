class_name Player
extends Node2D
## Kroker en la partida: se mueve y su arma ataca sola (estilo Brotato).
## Kroker in game: moves around while his weapon attacks on its own (Brotato style).

const ART_SCALE := 0.5
const HIT_INVULN := 0.8
const DASH_INVULN := 0.4     # invulnerable tras el dash de las botas / invulnerable after the boots dash

var run: Node  # Run
var outfit := "bat"
var max_hp := 20.0
var hp := 20.0
var speed := 300.0
var damage_mult := 1.0
var armor := 0.0
var alive := true
var attack_anim := 0.0  # 1 → 0 tras un golpe / after a strike
var aim := Vector2(1, 0.5)   # hacia dónde apunta el arma / where the weapon points
var sucking := false         # la aspiradora está absorbiendo / the vacuum is sucking
var cast_anim := 0.0         # 1 → 0 al lanzar un rayo / after casting lightning
## Zona donde le pueden dar: solo el cuerpo (la cabeza no cuenta) / Where he can be hit: only the body (the head doesn't count)
const HURT := Vector2(0, -30)
const HURT_R := 20.0
var armed := true            # lleva el arma en la mano / holds the weapon
var hurt_lean := 0.0         # retroceso al recibir daño / recoil when hit
var hop := 0.0               # altura de un salto en píxeles / jump height in pixels
var shield_charges := 0      # golpes que para la almohada recogida / hits the picked-up pillow blocks
var slow_t := 0.0            # frenado por un charco / slowed by a puddle
var push := Vector2.ZERO     # empuje del suelo inclinado / push from a tilted floor
var bleed_t := 0.0           # sangrado de los cuchillos del Chef / bleeding from the Chef's knives
var _bleed_tick := 0.0
var shock_t := 0.0           # descarga de la Marioneta: chispas mientras está paralizado / Puppet zap: sparks while paralysed
## Mal olor del Gólem de papel higiénico: una de las armas deja de funcionar un rato
## Toilet-Paper Golem stench: one of the weapons stops working for a while
var stench_t := 0.0
var stench_weapon: Weapon = null
var root_t := 0.0            # aturdido por el sartenazo: no se puede mover / dazed by the pan: can't move
var _land := 0.0             # rebote al aterrizar / landing squash
## Dash de las botas: velocidad y tiempo que le queda (mientras dura no le pueden dar)
## Boots dash: velocity and time left (he can't be hit while it lasts)
var _dash_vel := Vector2.ZERO
var _dash_t := 0.0

var _walk := 0.0
var _moving := 0.0
var _last_pos := Vector2.INF

var _vel := Vector2.ZERO
var _invuln := 0.0
var _flash := 0.0
var _facing := 1.0
var _t := 0.0
var _regen_acc := 0.0
var _heal_text := 0.0
## Transparencia de cada anillo de carga (se apaga al llenarse, como la stamina de Zelda)
## Opacity of each charge ring (fades out once full, like Zelda's stamina wheel)
var _ring_a: Array[float] = []
var _ring_b: Array[float] = []
var weapon: Weapon
## Segunda arma (Acto 3): flota junto a Kroker y ataca sola / Second weapon (Act 3): floats beside Kroker and attacks on its own
var weapon2: Weapon


func setup(p_run: Node, p_outfit: String) -> void:
	run = p_run
	outfit = p_outfit
	refresh_stats()
	# La vida se arrastra de un sueño a otro y solo se recupera un poco
	# Health carries over between dreams and only a little comes back
	if GameState.saved_hp >= 0.0:
		hp = minf(max_hp, GameState.saved_hp + max_hp * GameState.HEAL_BETWEEN_DREAMS)
	else:
		hp = max_hp
	weapon = _make_weapon(outfit, true)
	var second := GameState.second_weapon
	if second != "" and second != outfit:
		weapon2 = _make_weapon(second, false)


## La pelota está en el aire (no se dibuja en la mano) / The ball is in the air (not drawn in the hand)
func _ball_away(w: Weapon) -> bool:
	return w is WeaponBall and not (w as WeaponBall).has_ball()


func _make_weapon(id: String, primary: bool) -> Weapon:
	var w: Weapon
	match id:
		"shield": w = WeaponShield.new()
		"book": w = WeaponBook.new()
		"vacuum": w = WeaponVacuum.new()
		"finger": w = WeaponFinger.new()
		"teddy": w = WeaponTeddy.new()
		"ball": w = WeaponBall.new()
		"laptop": w = WeaponLaptop.new()
		"boots": w = WeaponBoots.new()
		_: w = WeaponBat.new()
	w.id = id
	w.primary = primary
	w.run = run
	w.player = self
	add_child(w)
	return w


## Vuelve a leer las estadísticas (al subir de nivel) / Re-reads the stats (after a level-up)
func refresh_stats() -> void:
	var s := GameState.stats_for(outfit)
	max_hp = s["max_hp"]
	hp = minf(hp, max_hp)
	speed = s["speed"]
	damage_mult = s["damage_mult"]
	armor = s["armor"]


func heal(amount: float) -> void:
	if not alive or hp >= max_hp:
		return
	hp = minf(max_hp, hp + amount)
	run.hud.set_hp(hp, max_hp)
	# Sin llenar la pantalla de números / Without flooding the screen with numbers
	if _heal_text <= 0.0:
		_heal_text = 0.6
		run.fx.text(global_position + Vector2(0, -96), "+%s" % str(snappedf(amount, 0.1)).trim_suffix(".0"), Color("9be38a"), 20)


func _physics_process(delta: float) -> void:
	_t += delta
	_heal_text = maxf(0.0, _heal_text - delta)
	# Recuperación de salud: "regen" de vida cada 5 s / Health regeneration: "regen" health every 5 s
	var regen := GameState.stat("regen")
	if regen > 0.0 and alive and run.running:
		_regen_acc += regen / 5.0 * delta
		if _regen_acc >= 0.5:
			heal(_regen_acc)
			_regen_acc = 0.0
	_invuln = maxf(0.0, _invuln - delta)
	shock_t = maxf(0.0, shock_t - delta)
	if stench_t > 0.0:
		stench_t = maxf(0.0, stench_t - delta)
		if stench_t <= 0.0:
			stench_weapon = null
	_flash = maxf(0.0, _flash - delta * 4.0)
	attack_anim = maxf(0.0, attack_anim - delta * 4.0)
	cast_anim = maxf(0.0, cast_anim - delta * 3.0)
	hurt_lean = move_toward(hurt_lean, 0.0, delta * 1.5)
	_land = move_toward(_land, 0.0, delta * 4.0)
	modulate.a = 1.0 if alive else 0.35
	if alive and run.running:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		root_t = maxf(0.0, root_t - delta)
		if root_t > 0.0:
			input = Vector2.ZERO
		_update_bleed(delta)
		slow_t = maxf(0.0, slow_t - delta)
		var spd := speed * (0.6 if slow_t > 0.0 else 1.0)
		_vel = _vel.lerp(input * spd + push, minf(1.0, delta * 14.0))
		if _dash_t > 0.0:
			_dash_t -= delta
			_vel = _dash_vel
			if _dash_t <= 0.0:
				_vel = _dash_vel.normalized() * spd
				# Un poco de invulnerabilidad al acabar (parpadea) / A little invulnerability when it ends (he blinks)
				_invuln = maxf(_invuln, DASH_INVULN)
		position = run.clamp_to_arena(position + _vel * delta, 24.0)
		if absf(_vel.x) > 10.0:
			_facing = signf(_vel.x)
	else:
		_vel = Vector2.ZERO
	queue_redraw()


## Animación de andar según lo que se ha movido de verdad (también en la intro).
## Se calcula por fotograma dibujado, que es cuando se mueven las animaciones.
## Walk animation from actual movement (also during the intro), computed per drawn frame.
func _process(delta: float) -> void:
	if _last_pos != Vector2.INF and delta > 0.0:
		var spd := position.distance_to(_last_pos) / delta
		_moving = move_toward(_moving, clampf(spd / 200.0, 0.0, 1.0), delta * 8.0)
		_walk += spd * delta * 0.045
		if not run.running and absf(position.x - _last_pos.x) > 0.3:
			_facing = signf(position.x - _last_pos.x)
	_last_pos = position
	queue_redraw()


## Pequeño rebote al caer de un salto / Small bounce when landing from a hop
## Hacia dónde se mueve ahora mismo / Where he's moving right now
func velocity_hint() -> Vector2:
	return _vel


## Sale disparado en una dirección durante un momento (dash de las botas)
## Shoots off in a direction for a moment (boots dash)
func dash(vel: Vector2, seconds: float) -> void:
	_dash_vel = vel
	_dash_t = seconds
	if absf(vel.x) > 1.0:
		_facing = signf(vel.x)


func dashing() -> bool:
	return _dash_t > 0.0


func land() -> void:
	_land = 1.0


func set_facing(f: float) -> void:
	_facing = f


func take_damage(amount: float, source: Node2D = null) -> void:
	if not alive or _invuln > 0.0 or not run.running or _dash_t > 0.0:
		return
	if GameState.god_mode and GameState.god_invuln:
		return  # modo Dios / god mode
	# Parry: a veces lo esquiva y, con un chasquido de dedos, acaba con quien le atacaba y con los de alrededor
	# Parry: sometimes he dodges it and, with a snap of his fingers, finishes off the attacker and those around
	if randf() * 100.0 < GameState.parry_chance():
		_parry(source)
		return
	if shield_charges > 0:
		# La almohada recogida para el golpe / The picked-up pillow blocks the hit
		shield_charges -= 1
		_invuln = HIT_INVULN
		run.fx.ring(global_position + Vector2(0, -36), 34.0, Color("8fe0ff"), 0.5, 2.0)
		Audio.play("pillow", -4.0)
		return
	# La defensa resta daño, pero nunca quita más de la mitad del golpe y siempre se recibe al menos 1.
	# Defense subtracts damage, but never more than half the hit, and at least 1 always gets through.
	var dmg := maxf(maxf(1.0, amount * 0.5), amount - armor)
	hp = maxf(0.0, hp - dmg)
	_invuln = HIT_INVULN
	_flash = 1.0
	Settings.rumble(0.5, 0.7, 0.2)
	hurt_lean = -0.18
	run.fx.text(global_position + Vector2(0, -88), "-%d" % roundi(dmg), UITheme.EMBER, 26)
	run.on_player_hit(dmg)
	if hp <= 0.0:
		alive = false
		run.on_player_died()


const PARRY_RADIUS := 170.0
const PARRY_EXTRA := 3         # cuántos más de alrededor caen / how many more around him fall
const PARRY_BOSS_DAMAGE := 30.0


func _parry(source: Node2D) -> void:
	_invuln = HIT_INVULN
	cast_anim = 1.0
	Audio.play("snap", -2.0, 0.05)
	run.shake(5.0)
	run.fx.text(global_position + Vector2(0, -140), tr("PARRY_SNAP"), Color.WHITE, 26)
	run.fx.ring(global_position + HURT, PARRY_RADIUS, Color.WHITE, 0.4, 1.2)
	# Quién le atacaba (o el más cercano si fue un disparo) / Who attacked (or the nearest if it was a shot)
	var victims: Array[Node2D] = []
	if source is Enemy and source.is_targetable():
		victims.append(source)
	var near: Array = []
	for e: Node in run.enemies.get_children():
		if e is Enemy and e.is_targetable() and not victims.has(e) and (e as Node2D).global_position.distance_to(global_position) < PARRY_RADIUS:
			near.append(e)
	near.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	for e in near:
		if victims.size() >= PARRY_EXTRA + 1:
			break
		victims.append(e)
	for e in victims:
		run.fx.ring(e.global_position + Vector2(0, -30), 24.0, Color.WHITE, 0.3, 2.0)
		if e.is_boss():
			e.hit(PARRY_BOSS_DAMAGE)
		else:
			e.die(true)


## Sangra: pierde 1 de vida cada 0,8 s (sin parpadeo de invulnerabilidad)
## Bleeding: loses 1 health every 0.8 s (without invulnerability blinking)
func start_bleed(seconds: float) -> void:
	if bleed_t <= 0.0:
		_bleed_tick = 0.8
	bleed_t = maxf(bleed_t, seconds)


func _update_bleed(delta: float) -> void:
	if bleed_t <= 0.0:
		return
	bleed_t -= delta
	_bleed_tick -= delta
	if _bleed_tick > 0.0:
		return
	_bleed_tick = 0.8
	if GameState.god_mode and GameState.god_invuln:
		return
	hp = maxf(0.0, hp - 1.0)
	_flash = 0.5
	run.fx.text(global_position + Vector2(randf_range(-14, 14), -80), "-1", Color("e8455a"), 20)
	run.fx.dissipate(global_position + Vector2(randf_range(-10, 10), -40), Color("c8304a"))
	run.hud.set_hp(hp, max_hp)
	if hp <= 0.0:
		alive = false
		run.on_player_died()


## Golpe que deja a Kroker clavado en el sitio / A hit that leaves Kroker stuck in place
func root(seconds: float) -> void:
	root_t = maxf(root_t, seconds)


func shock(seconds: float) -> void:
	shock_t = maxf(shock_t, seconds)


## Mal olor: pierde una de sus armas al azar durante un rato (si solo lleva una, no pasa nada)
## Stench: loses one of his weapons at random for a while (with only one weapon, nothing happens)
func stink(seconds: float) -> void:
	if weapon2 == null:
		return
	if stench_t <= 0.0 or stench_weapon == null:
		stench_weapon = weapon if randf() < 0.5 else weapon2
		run.fx.text(global_position + Vector2(0, -150), tr("STENCH_LOST"), Color("9fd86a"), 22)
		Audio.play("puff", -4.0, 0.1)
	stench_t = maxf(stench_t, seconds)


## ¿Esta arma está anulada por el mal olor? / Is this weapon knocked out by the stench?
func weapon_stunk(w: Weapon) -> bool:
	return stench_t > 0.0 and w == stench_weapon


func _draw() -> void:
	# Parpadea mientras es invulnerable / Blinks while invulnerable
	var visible_now := _invuln <= 0.0 or fmod(_t, 0.12) < 0.07 or not alive
	if not visible_now:
		return
	# Al aterrizar se aplasta un poco y recupera la forma / Squashes a little on landing, then springs back
	var squash := sin(_land * PI) * 0.12
	var sx := ART_SCALE * (1.0 + squash)
	var sy := ART_SCALE * (1.0 - squash)
	# Las botas: patadas, giro y llamas de los motores / The boots: kicks, spin and engine flames
	var boots: WeaponBoots = weapon as WeaponBoots if weapon is WeaponBoots else (weapon2 as WeaponBoots if weapon2 is WeaponBoots else null)
	var facing := _facing
	var spin_a := 0.0
	if boots and boots.spin > 0.0:
		# Vuelta de 360°: se estrecha y se da la vuelta como una peonza, con la pierna estirada
		# 360° turn: he narrows and flips round like a spinning top, leg stretched out
		spin_a = (1.0 - boots.spin) * TAU
		var c := cos(spin_a)
		facing = _facing * (1.0 if c >= 0.0 else -1.0)
		sx *= maxf(0.4, absf(c))
		_draw_spin_trail(spin_a, false)
	# Un saltito al girar / A little hop while spinning
	var lift := sin(boots.spin * PI) * 12.0 if boots and boots.spin > 0.0 else 0.0
	KrokerArt.draw(self, Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2(-200.0 * sx / 2.0, -288.0 * sy - hop - lift)),
		outfit, _t, {"facing": facing, "boots": boots != null, "kick_l": boots.kick_l if boots else 0.0, "kick_r": boots.kick_r if boots else 0.0,
		"thrust": maxf(boots.thrust, 1.0 if _dash_t > 0.0 else 0.0) if boots else 0.0, "flash": _flash, "attack": attack_anim, "aim": aim, "sucking": sucking,
		"cast": cast_anim, "walk": _walk, "moving": _moving, "armed": armed and not weapon_stunk(weapon) and not _ball_away(weapon), "lean": hurt_lean,
		# La segunda arma va en la mano libre / The second weapon goes in the free hand
		"second": weapon2.id if weapon2 else "", "anim2": weapon2.anim if weapon2 else 0.0,
		"hide2": (weapon2 is WeaponShield and (weapon2 as WeaponShield).hidden_pillow) or weapon_stunk(weapon2) or _ball_away(weapon2),
		"aim2": (weapon2 as WeaponVacuum).aim_dir() if weapon2 is WeaponVacuum else Vector2(1, 0.5),
		"sucking2": weapon2 is WeaponVacuum and (weapon2 as WeaponVacuum).sucking})
	if spin_a > 0.0:
		_draw_spin_trail(spin_a, true)
	if alive and run.running and weapon and not weapon_stunk(weapon):
		_ring_a = _draw_charge_rings(weapon.charge_bars(), weapon.charge_anchor(), _ring_a)
	if alive and run.running and weapon2 and not weapon_stunk(weapon2):
		_ring_b = _draw_charge_rings(weapon2.charge_bars(), weapon2.charge_anchor(), _ring_b)
	_draw_hearth_ring()
	_draw_shield_bubble()
	_draw_states()


## Estela del giro de las botas: un arco a la altura de los pies que sigue a la bota
## Trail of the boots' spin: an arc at foot height that follows the boot
func _draw_spin_trail(a: float, front: bool) -> void:
	var c := Vector2(0, -10)
	var r := Vector2(62, 18)
	for k in 10:
		var a0 := a - k * 0.22
		var a1 := a0 - 0.22
		# La mitad de delante va por encima de Kroker / The front half goes over Kroker
		if (sin(a0) > 0.0) != front:
			continue
		var p0 := c + Vector2(cos(a0) * r.x * _facing, sin(a0) * r.y)
		var p1 := c + Vector2(cos(a1) * r.x * _facing, sin(a1) * r.y)
		draw_line(p0, p1, Color("e0b860", 0.75 * (1.0 - k / 10.0)), 6.0 - k * 0.4)
	if (sin(a) > 0.0) == front:
		draw_line(c + Vector2(cos(a) * r.x * _facing, sin(a) * r.y) + Vector2(0, -2), c + Vector2(cos(a) * r.x * _facing, sin(a) * r.y) + Vector2(0, 2), Color("ffe8b0"), 8.0)


## Aviso sobre la cabeza delante de la chimenea: «F · Echar al fuego», con una llamita
## Prompt over his head in front of the fireplace: "F · Into the fire", with a little flame
func _draw_hearth_ring() -> void:
	var lr := run.room as LivingRoom
	if lr == null or not lr.fire_near or not lr.can_sacrifice():
		return
	var font := UITheme.font("caps")
	var size := UITheme.pixel_size(14)
	var text := Settings.controls_text(tr("HEARTH_PROMPT")).to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var c := Vector2(0, -178 + sin(_t * 3.0) * 2.0)
	draw_rect(Rect2(c + Vector2(-w / 2.0 - 30, -20), Vector2(w + 44, 30)), Color(0.05, 0.03, 0.18, 0.6))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-w / 2.0 - 22, 4), c + Vector2(-w / 2.0 - 18, -12 - sin(_t * 12.0) * 2.0), c + Vector2(-w / 2.0 - 14, 4)]), Color("ffb06a"))
	draw_string(font, c + Vector2(-w / 2.0 - 6, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("ffd07a"))


## Estrellitas de mareo, gotas de sangre y glitch del hackeo / Dizzy stars, blood drops and hack glitch
func _draw_states() -> void:
	if root_t > 0.0:
		for i in 3:
			var ang := _t * 7.0 + i * TAU / 3.0
			DreamBackground.draw_star(self, Vector2(cos(ang) * 18.0, -158 + sin(ang) * 5.0), 3.0, UITheme.GOLD)
	if shock_t > 0.0:
		for i in 4:
			var p := Vector2(randf_range(-26, 26), randf_range(-140, -20))
			draw_line(p, p + Vector2(randf_range(-12, 12), randf_range(-12, 12)), Color("8fe0ff", 0.9), 2.0)
	if stench_t > 0.0:
		# Mal olor: líneas onduladas verdes que suben y dos moscas dando vueltas
		# Stench: wavy green lines rising and two flies buzzing around
		for i in 3:
			var x0 := -18.0 + i * 18.0
			var ph := fposmod(_t * 0.8 + i * 0.33, 1.0)
			var pts := PackedVector2Array()
			for kk in 7:
				var y := -40.0 - ph * 60.0 - kk * 9.0
				pts.append(Vector2(x0 + sin(_t * 6.0 + kk * 1.2 + i) * 5.0, y))
			draw_polyline(pts, Color("8fd14f", 0.85 * (1.0 - ph * 0.6)), 3.0)
		for f in 2:
			var a := _t * (5.0 + f) + f * PI
			var fp := Vector2(cos(a) * 30.0, -150.0 + sin(a * 2.0) * 10.0)
			draw_rect(Rect2(fp - Vector2(2, 2), Vector2(4, 4)), Color("1a1328"))
			draw_rect(Rect2(fp + Vector2(-4, -5), Vector2(3, 2)), Color(1, 1, 1, 0.7))
			draw_rect(Rect2(fp + Vector2(1, -5), Vector2(3, 2)), Color(1, 1, 1, 0.7))
	if bleed_t > 0.0:
		for i in 3:
			var y := -60.0 + fposmod(_t * 60.0 + i * 20.0, 50.0)
			draw_rect(Rect2(-10 + i * 9, y, 3, 4), Color("e8455a", 0.8))
	if not GameState.hacks.is_empty() and fmod(_t, 0.6) < 0.12:
		draw_rect(Rect2(-22, randf_range(-140, -20), 44, 3), Color("ff5fd2", 0.7))
		draw_rect(Rect2(-18, randf_range(-140, -20), 36, 2), Color("5ff2ff", 0.7))


## Anillos de carga junto al arma: se rellenan en círculo y se apagan cuando están llenos.
## Charge rings by the weapon: they fill in a circle and fade out once full.
## Burbuja de la almohada recogida / Bubble of the picked-up pillow
func _draw_shield_bubble() -> void:
	if shield_charges <= 0:
		return
	var c := Vector2(0, -36)
	var pulse := 1.0 + 0.05 * sin(_t * 5.0)
	draw_circle(c, 46.0 * pulse, Color("8fe0ff", 0.12))
	draw_arc(c, 46.0 * pulse, 0, TAU, 32, Color("8fe0ff", 0.7), 3.0)


func _draw_charge_rings(bars: Array, anchor: Vector2, ring_a: Array[float]) -> Array[float]:
	ring_a.resize(bars.size())
	var dt := get_process_delta_time()
	for i in bars.size():
		var k: float = clampf(bars[i][0], 0.0, 1.0)
		var col: Color = bars[i][1]
		ring_a[i] = move_toward(ring_a[i], 0.0 if k >= 1.0 else 1.0, dt * (2.5 if k >= 1.0 else 8.0))
		var a: float = ring_a[i]
		if a <= 0.01:
			continue
		var c := anchor + Vector2(0, -26.0 * i)
		var r := 10.0
		draw_circle(c, r + 3.5, Color(0.05, 0.03, 0.18, 0.45 * a))
		draw_arc(c, r, 0, TAU, 28, Color(col, 0.18 * a), 4.0, true)
		if k > 0.0:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * k, maxi(4, int(28 * k)), Color(col, 0.95 * a), 4.0, true)
		if k >= 1.0:
			draw_circle(c, r * 0.45, Color(col, 0.7 * a))
	return ring_a

