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
## Lo que añade la forma del collar de druida (pantera: velocidad; oso: defensa)
## What the druid collar's form adds (panther: speed; bear: defence)
var form_speed := 1.0
var form_armor := 0.0
## Buitre: Kroker levita (pasa por encima de muebles, escombros y charcos, y no le pillan los sismos)
## Vulture: Kroker hovers (over furniture, rubble and puddles, and quakes don't catch him)
var form_hover := false
var _turn := 0.0              # 1 → 0 al darse la vuelta / 1 → 0 when turning round
var _hover := 0.0
## Pantera: sigilo; los enemigos le pierden la pista mientras dura / Panther: stealth; enemies lose track of him while it lasts
var stealth_t := 0.0
var alive := true
var attack_anim := 0.0  # 1 → 0 tras un golpe / after a strike
var aim := Vector2(1, 0.5)   # hacia dónde apunta el arma / where the weapon points
var sucking := false         # la aspiradora está absorbiendo / the vacuum is sucking
var cast_anim := 0.0         # 1 → 0 al lanzar un rayo / after casting lightning
var reload_anim := 0.0       # 1 → 0: intro de la pistola de dedos / finger-gun intro
const RELOAD_TIME := 1.5
## Zona donde le pueden dar: solo el cuerpo (la cabeza no cuenta) / Where he can be hit: only the body (the head doesn't count)
const HURT := Vector2(0, -30)
const HURT_R := 20.0
var armed := true            # lleva el arma en la mano / holds the weapon
var _dead_t := 0.0
var hurt_lean := 0.0         # retroceso al recibir daño / recoil when hit
var hop := 0.0               # altura de un salto en píxeles / jump height in pixels
var fedora := false         # sombrero de detective del último sueño / the last dream's detective hat
var pose_lean := 0.0        # inclinación de pose (apoyado en la pared) / posing lean (leaning on the wall)
var shield_charges := 0      # golpes que para la almohada recogida / hits the picked-up pillow blocks
var slow_t := 0.0            # frenado por un charco / slowed by a puddle
var push := Vector2.ZERO
## Empujón que se va frenando (la estampida de ovejas) / A shove that slows down (the sheep stampede)
var _shove := Vector2.ZERO     # empuje del suelo inclinado / push from a tilted floor
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
		"druid": w = WeaponDruid.new()
		"yoyo": w = WeaponYoyo.new()
		_: w = WeaponBat.new()
	w.id = id
	w.primary = primary
	w.run = run
	w.player = self
	add_child(w)
	return w


## Color de la forma del collar de druida, si lo lleva (si no, transparente)
## The druid collar's form colour, if he wears it (otherwise transparent)
func druid() -> WeaponDruid:
	return weapon as WeaponDruid if weapon is WeaponDruid else (weapon2 as WeaponDruid if weapon2 is WeaponDruid else null)


## ¿Va levitando (forma de buitre)? / Is he hovering (vulture form)?
func flying() -> bool:
	return form_hover


## Kroker convertido: el animal de la forma, con la segunda arma flotando encima con un brillo verde
## Kroker transformed: the form's animal, with the second weapon floating above in a green glow
func _draw_animal(dr: WeaponDruid, sx: float, sy: float) -> void:
	# Transformación: la forma de antes (o Kroker) se encoge con un destello y sale la nueva
	# Transformation: the old form (or Kroker) shrinks with a flash and the new one comes out
	var m := dr.morph
	if m > 0.0:
		var glow := 1.0 - absf(m - 0.5) * 2.0
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-90, -170), Vector2(180, 190)), false, Color(WeaponDruid.COLORS[dr.form].lightened(0.3), 0.55 * glow))
	if m > 0.5:
		var k := (m - 0.5) / 0.5      # 1 → 0
		var sc := 0.25 + 0.75 * k * k
		var fl := maxf(_flash, 1.0 - k)
		if dr.morph_from == "":
			KrokerArt.draw(self, Transform2D(0.0, Vector2(sx * sc, sy * sc), 0.0, Vector2(-200.0 * sx * sc / 2.0, -288.0 * sy * sc)),
				outfit, _t, {"facing": _facing, "flash": fl, "armed": false, "druid": _druid_color()})
		else:
			DruidArt.draw(self, Vector2.ZERO, dr.morph_from, _t, {"facing": _facing, "flash": fl, "scale": sc})
		return
	var grow := 1.0 if m <= 0.0 else 0.25 + 0.75 * (1.0 - m / 0.5)
	# Un rebote al salir / A bounce as it comes out
	var pop := 1.0 + 0.12 * sin(clampf(1.0 - m / 0.5, 0.0, 1.0) * PI) if m > 0.0 else 1.0
	DruidArt.draw(self, Vector2.ZERO, dr.form, _t, {"facing": _facing, "walk": _walk, "moving": _moving,
		"attack": attack_anim, "roar": dr.roar_anim, "pounce": dr.pounce_anim, "flash": maxf(_flash, m * 1.1), "turn": _turn,
		"scale": grow * pop})
	if weapon2 == null or weapon_stunk(weapon2):
		return
	var at: Vector2 = DruidArt.HELD_AT[dr.form] * Vector2(_facing, 1.0) + Vector2(0, sin(_t * 2.0) * 4.0)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(at - Vector2(34, 34), Vector2(68, 68)), false, Color("7fd49a", 0.3))
	var s := ART_SCALE * 0.85
	var hand := Vector2(100, 170)
	var xf := Transform2D(0.0, Vector2(s * _facing, s), 0.0, at - Vector2(hand.x * s * _facing, hand.y * s))
	KrokerArt.draw_held(self, xf, weapon2.id, _t, hand, weapon2.anim,
		(weapon2 as WeaponVacuum).aim_dir() if weapon2 is WeaponVacuum else Vector2(1, 0.5), weapon2 is WeaponVacuum and (weapon2 as WeaponVacuum).sucking)


func _druid_color() -> Color:
	var d := druid()
	if d == null:
		return Color(0, 0, 0, 0)
	return WeaponDruid.COLORS[d.form]


## Vuelve a leer las estadísticas (al subir de nivel) / Re-reads the stats (after a level-up)
func refresh_stats() -> void:
	var s := GameState.stats_for(outfit)
	max_hp = s["max_hp"]
	hp = minf(hp, max_hp)
	speed = s["speed"]
	damage_mult = s["damage_mult"]
	armor = s["armor"]


## El robo de salud cura como mucho 1 cada STEAL_GAP segundos (las armas rápidas lo disparaban)
## Life steal heals at most 1 every STEAL_GAP seconds (fast weapons were spamming it)
const STEAL_GAP := 1.0
var _steal_t := 0.0


func steal_ready() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _steal_t < STEAL_GAP:
		return false
	_steal_t = now
	return true


## Curación continua (regeneración y robo de salud): sale de un "depósito" que se rellena a
## SUSTAIN_PER_SEC; si está vacío, no cura / Continuous healing (regeneration and life steal): comes
## out of a "tank" that refills at SUSTAIN_PER_SEC; if it's empty, it doesn't heal
var _sustain := GameState.SUSTAIN_BUFFER


func heal_sustain(amount: float) -> void:
	if hp >= max_hp and plasters >= GameState.doc_plasters():
		return
	var a := minf(amount, _sustain)
	if a <= 0.01:
		return
	_sustain -= a
	heal(a)


func heal(amount: float) -> void:
	if not alive:
		return
	# Tiritas de Doc: lo que sobra se guarda / Doc's plasters: what's left over is kept
	var extra := hp + amount - max_hp
	if extra > 0.0:
		var cap := GameState.doc_plasters()
		if cap > plasters:
			var before := floori(plasters)
			plasters = minf(cap, plasters + extra)
			if floori(plasters) > before:
				run.fx.text(global_position + Vector2(0, -110), tr("DOC_PLASTER"), Color("ffe3a3"), 18)
				Audio.play("plaster", -10.0, 0.1)
				Progress.tip("doc_plaster")
		if hp >= max_hp:
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
	_sustain = minf(GameState.SUSTAIN_BUFFER, _sustain + GameState.SUSTAIN_PER_SEC * (0.5 if GameState.pact("dry") else 1.0) * delta)
	# Recuperación de salud: "regen" de vida cada 5 s / Health regeneration: "regen" health every 5 s
	var regen := GameState.regen_effective()
	if regen > 0.0 and alive and run.running:
		_regen_acc += regen / 5.0 * delta
		if _regen_acc >= 0.5:
			heal_sustain(_regen_acc)
			_regen_acc = 0.0
	_invuln = maxf(0.0, _invuln - delta)
	if grudge != null:
		_grudge_t -= delta
		if _grudge_t <= 0.0 or not is_instance_valid(grudge):
			grudge = null
	shock_t = maxf(0.0, shock_t - delta)
	if stench_t > 0.0:
		stench_t = maxf(0.0, stench_t - delta)
		if stench_t <= 0.0:
			stench_weapon = null
	_flash = maxf(0.0, _flash - delta * 4.0)
	attack_anim = maxf(0.0, attack_anim - delta * 4.0)
	cast_anim = maxf(0.0, cast_anim - delta * 3.0)
	reload_anim = maxf(0.0, reload_anim - delta / RELOAD_TIME)
	# Al caer rendido se va hacia atrás, como quien se queda dormido de pie, y se desvanece en estrellas
	# When he falls he tips backwards, like someone dozing off standing up, and fades into stars
	if not alive:
		_dead_t += delta
		hurt_lean = move_toward(hurt_lean, -0.9, delta * 2.2)
	else:
		hurt_lean = move_toward(hurt_lean, 0.0, delta * 1.5)
	_land = move_toward(_land, 0.0, delta * 4.0)
	stealth_t = maxf(0.0, stealth_t - delta)
	_hover = move_toward(_hover, 1.0 if form_hover and alive else 0.0, delta * 3.0)
	_turn = maxf(0.0, _turn - delta * 6.0)
	# En sigilo se vuelve casi una sombra / In stealth he turns almost into a shadow
	modulate = Color(0.75, 0.68, 1.0, 0.55) if stealth_t > 0.0 and alive else Color(1, 1, 1, 1.0 if alive else clampf(1.0 - (_dead_t - 0.35) / 0.55, 0.0, 1.0))
	if alive and run.running:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		root_t = maxf(0.0, root_t - delta)
		if root_t > 0.0:
			input = Vector2.ZERO
		_update_bleed(delta)
		slow_t = 0.0 if form_hover else maxf(0.0, slow_t - delta)
		var spd := speed * form_speed * (0.6 if slow_t > 0.0 else 1.0)
		# Suelo helado: cuesta arrancar y frenar / Icy floor: hard to get going and to stop
		var grip := 2.2 if run.event == "ice" else 14.0
		# Luna: gravedad baja; algo más rápido, pero cuesta más frenar y girar / Luna: low gravity; a bit faster, but harder to stop and turn
		var luna := GameState.luna_levels()
		if luna > 0:
			spd *= 1.0 + 0.03 * luna
			grip = minf(grip, 14.0 - 1.4 * luna)
		_vel = _vel.lerp(input * spd + push, minf(1.0, delta * grip))
		if _dash_t > 0.0:
			_dash_t -= delta
			_vel = _dash_vel
			if _dash_t <= 0.0:
				_vel = _dash_vel.normalized() * spd
				# Un poco de invulnerabilidad al acabar (parpadea) / A little invulnerability when it ends (he blinks)
				_invuln = maxf(_invuln, DASH_INVULN)
		position = run.clamp_to_arena(position + (_vel + _shove) * delta, 24.0, form_hover)
		_shove = _shove.move_toward(Vector2.ZERO, 2400.0 * delta)
		if absf(_vel.x) > 10.0:
			if signf(_vel.x) != _facing:
				_turn = 1.0
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
		var before := int(_walk / PI)
		_walk += spd * delta * 0.045
		# Polvillo a cada pisada (no si levita) / A little dust at each footstep (not when hovering)
		if int(_walk / PI) != before and _moving > 0.5 and not form_hover and alive:
			var dr := druid()
			var heavy := dr != null and dr == weapon and dr.transformed and dr.form == "bear"
			_dust.append({"p": global_position + Vector2(-_facing * 10.0, 0), "t": 0.0, "big": heavy})
			# Pisadas muy bajitas; el buitre no pisa / Very quiet footsteps; the vulture doesn't step
			if heavy:
				Audio.play("step_heavy", -16.0, 0.08)
			elif not flying():
				Audio.play("step", -24.0, 0.12)
		if not run.running and absf(position.x - _last_pos.x) > 0.3:
			_facing = signf(position.x - _last_pos.x)
	_last_pos = position
	# Quieto un rato en mitad de un sueño, le entra el sueño: bosteza / Standing still a while mid-dream, he gets sleepy: he yawns
	var before_y := _idle_yawn()
	_still = _still + delta if _moving < 0.05 and alive and run.running else 0.0
	if before_y <= 0.0 and _idle_yawn() > 0.0:
		Audio.play("yawn", -18.0, 0.1)
	for d: Dictionary in _dust:
		d["t"] = float(d["t"]) + delta / 0.45
	_dust = _dust.filter(func(d: Dictionary) -> bool: return float(d["t"]) < 1.0)
	queue_redraw()


var _dust: Array = []
var _still := 0.0
const YAWN_AFTER := 4.0
const YAWN_EVERY := 8.0
const YAWN_TIME := 1.6


func _idle_yawn() -> float:
	if _still < YAWN_AFTER:
		return 0.0
	var ph := fmod(_still - YAWN_AFTER, YAWN_EVERY)
	return sin(ph / YAWN_TIME * PI) if ph < YAWN_TIME else 0.0


func _draw_dust() -> void:
	for d: Dictionary in _dust:
		var k: float = d["t"]
		var at: Vector2 = Vector2(d["p"]) - global_position
		var big: bool = d["big"]
		var n := 4 if big else 2
		for i in n:
			var side := -1.0 if i % 2 == 0 else 1.0
			var p := at + Vector2(side * (4.0 + k * (14.0 if big else 8.0)) + i * 2.0, -2.0 - k * 6.0)
			var r := (3.0 if big else 2.0) + k * (5.0 if big else 3.0)
			draw_circle(p, r, Color(0.85, 0.82, 0.95, 0.35 * (1.0 - k)))


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


func shove(v: Vector2) -> void:
	_shove += v
	hurt_lean = -0.18


## El Examen suspenso que le ha puesto un cero (mientras viva y no le peguen) / The Failed Exam that gave him a zero (while it lives and isn't hit)
var exam_mark: Node2D = null

## --- Stolk y Doc / Stolk and Doc -----------------------------------------------------------
## Revancha: el último enemigo que le ha hecho daño, fichado un rato / Payback: the last enemy that hurt him, marked for a while
var grudge = null
var _grudge_t := 0.0
const GRUDGE_TIME := 8.0
## Tiritas de Doc: puntos de daño que paran antes de la vida / Doc's plasters: damage points soaked before health
var plasters := 0.0
## Segunda opinión: una por sueño / Second opinion: one per dream
var _rescued := false
const RESCUE_BELOW := 0.3


func marked() -> bool:
	return is_instance_valid(exam_mark) and (exam_mark as Enemy).is_targetable()


## Un cero rojo encima de la cabeza y un hilo de tinta hasta el examen que se lo ha puesto
## A red zero above his head and an ink thread to the exam that gave it to him
func _draw_exam_mark() -> void:
	if not marked():
		return
	var top := Vector2(0, -132 + sin(_t * 4.0) * 3.0)
	var red := Color("e0303a")
	var to := exam_mark.global_position + Vector2(0, -60) - global_position
	var n := 14
	for i in n:
		if i % 2 == 0:
			draw_line(top.lerp(to, float(i) / n), top.lerp(to, float(i + 1) / n), Color(red, 0.45), 2.0)
	draw_circle(top, 15.0, Color(1, 0.98, 0.94, 0.9))
	draw_arc(top, 15.0, 0, TAU, 20, red, 2.0)
	draw_set_transform(top, 0.0, Vector2(0.75, 1.0))
	draw_arc(Vector2.ZERO, 8.0, 0, TAU, 16, red, 3.0)
	draw_set_transform(Vector2.ZERO)


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
	# Oso: el pelaje para el golpe entero y el oso devuelve el zarpazo / Bear: the fur stops the whole hit and the bear swipes back
	var dr := druid()
	if dr and not weapon_stunk(dr) and dr.try_guard(source):
		_invuln = HIT_INVULN
		return
	# SuperK aparece y para el golpe / SuperK shows up and stops the hit
	if run.helpers and run.helpers.try_guard(source):
		_invuln = HIT_INVULN
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
	# Quién le ha dado, para el diario / Who hit him, for the diary
	if source != null:
		var who: Variant = source.get("bestiary_id")
		if who == null or str(who) == "":
			who = source.get("cause")
		if who != null and str(who) != "":
			GameState.last_hit = str(who)
	var def := (armor + form_armor) * (Enemy.BLEED_DEFENSE if bleed_t > 0.0 else 1.0)
	var dmg := maxf(maxf(1.0, amount * 0.5), amount - def)
	# Marcado por el Examen suspenso: duele más / Marked by the Failed Exam: it hurts more
	if marked():
		dmg *= Exam.MARK_MULT
	# Revancha de Stolk: quien le pega queda fichado / Stolk's Payback: whoever hits him gets marked
	if source is Enemy and GameState.has_stolk():
		if grudge != source:
			run.fx.text(source.global_position + Vector2(0, -(source as Enemy).aim_height * 2.0 - 40), tr("STOLK_GRUDGE"), Color("ff6a6a"), 22)
			Audio.play("knuckles", -8.0, 0.1)
			Progress.tip("stolk_grudge")
		grudge = source
		_grudge_t = GRUDGE_TIME
	# Tiritas de Doc: paran lo que pueden / Doc's plasters: soak what they can
	if plasters >= 1.0:
		var soak := minf(floorf(plasters), dmg)
		plasters -= soak
		dmg -= soak
		run.fx.ring(global_position + Vector2(0, -50), 26.0, Color("ffe3a3"), 0.35, 2.0)
		if dmg <= 0.0:
			_invuln = HIT_INVULN
			run.fx.text(global_position + Vector2(0, -88), tr("DOC_PLASTER_SOAK"), Color("ffe3a3"), 20)
			Audio.play("pillow", -10.0, 0.1, 1.3)
			return
	hp = maxf(0.0, hp - dmg)
	# Segunda opinión de Doc: una vez por sueño, si se queda muy tocado / Doc's second opinion: once per dream, if badly hurt
	if not _rescued and hp > 0.0 and hp < max_hp * RESCUE_BELOW and GameState.doc_rescue() > 0.0:
		_rescued = true
		var cure := GameState.doc_rescue()
		get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
			if alive:
				hp = minf(max_hp, hp + cure)
				run.hud.set_hp(hp, max_hp)
				run.fx.text(global_position + Vector2(0, -130), tr("DOC_RESCUE"), Color("ffe3a3"), 24)
				run.fx.ring(global_position + Vector2(0, -40), 60.0, Color("9be38a"), 0.6, 3.0)
				Audio.play("chime", -6.0, 0.0, 1.1)
				Progress.tip("doc_rescue"))
	_invuln = HIT_INVULN
	_flash = 1.0
	Settings.rumble(0.5, 0.7, 0.2)
	hurt_lean = -0.18
	run.fx.text(global_position + Vector2(0, -88), "-%d" % roundi(dmg), UITheme.EMBER, 26)
	run.on_player_hit(dmg)
	stealth_t = 0.0
	if dr and not weapon_stunk(dr):
		dr.on_hurt(source)
	if run.trinkets:
		run.trinkets.on_hurt(dmg, source)
	if hp <= 0.0 and not _retake():
		alive = false
		run.on_player_died()


## La "toma 2" de D. Lynx: una vez por partida, en vez de caer, "¡Corten!" y vuelve con vida.
## true = se ha salvado / D. Lynx's "take 2": once per run, instead of falling, "Cut!" and he's back
## with health. true = he was saved
func _retake() -> bool:
	# Solo para el bot de pruebas: apunta la «muerte» y sigue, para poder ver la partida entera
	# Only for the test bot: notes the "death" and carries on, so the whole run can be seen
	if GameState.bot_immortal:
		GameState.bot_deaths += 1
		hp = max_hp
		_invuln = 2.0
		return true
	var rt := GameState.lynx_retake()
	if rt.is_empty():
		return false
	GameState.lynx_retake_used = true
	hp = maxf(1.0, max_hp * float(rt["hp"]) / 100.0)
	_invuln = float(rt["inv"])
	bleed_t = 0.0
	run.hud.set_hp(hp, max_hp)
	run.flash_screen(Color(1, 1, 1, 0.8), 0.5)
	run.shake(6.0)
	run.fx.text(global_position + Vector2(0, -150), tr("LYNX_RETAKE"), Color("ffb0b0"), 30)
	run.fx.ring(global_position + Vector2(0, -36), 220.0, Color("e0303a"), 0.6, 1.4)
	Audio.play("snap", -2.0)
	Audio.leitmotif("lynx", -2.0, -14.0)
	for e: Node in run.enemies.get_children():
		if e is Enemy and (e as Enemy).is_targetable() and not (e as Enemy).is_boss():
			var d: Vector2 = (e as Node2D).global_position - global_position
			if d.length() < 260.0:
				(e as Enemy).knock += d.normalized() * 900.0
				(e as Enemy).stun_t = maxf((e as Enemy).stun_t, 1.0)
	return true


const PARRY_RADIUS := 170.0
const PARRY_EXTRA := 3         # cuántos más de alrededor caen / how many more around him fall
const PARRY_BOSS_DAMAGE := 30.0


func _parry(source: Node2D) -> void:
	_invuln = HIT_INVULN
	cast_anim = 1.0
	# Se tiene que notar: chasquido con brillo, temblor, un fogonazo suave y un instante a cámara lenta
	# It has to be felt: a shimmering snap, shake, a soft flash and a moment of slow motion
	Audio.play("parry", 0.0, 0.04)
	run.shake(9.0)
	run.flash_screen(Color(1.0, 0.95, 0.75, 0.55), 0.2)
	Settings.rumble(0.6, 0.4, 0.15)
	run.fx.text(global_position + Vector2(0, -150), tr("PARRY_SNAP"), Color("ffd84a"), 34)
	_hit_stop()
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
	var burst := ParryBurst.new()
	burst.radius = PARRY_RADIUS
	burst.position = global_position
	for e in victims:
		burst.targets.append((e as Node2D).global_position - global_position)
	run.world.add_child(burst)
	for e in victims:
		run.fx.ring(e.global_position + Vector2(0, -30), 24.0, Color.WHITE, 0.3, 2.0)
		if e.is_boss():
			e.hit(PARRY_BOSS_DAMAGE)
		else:
			e.die(true)


## Un instante casi parado tras el parry (en tiempo real, para que no dependa de la cámara lenta)
## A near-frozen instant after the parry (in real time, so it doesn't depend on the slow motion)
func _hit_stop() -> void:
	run.hit_stop(0.11, 0.12)


## Sangra: pierde 1 de vida cada 1,3 s (sin parpadeo de invulnerabilidad) y su defensa baja al 75 %
## Bleeding: loses 1 health every 1.3 s (without invulnerability blinking) and his defence drops to 75%
const BLEED_TICK := 1.3
func start_bleed(seconds: float) -> void:
	Progress.tip("bleed")
	if bleed_t <= 0.0:
		_bleed_tick = BLEED_TICK
	bleed_t = maxf(bleed_t, seconds)


func _update_bleed(delta: float) -> void:
	if bleed_t <= 0.0:
		return
	bleed_t -= delta
	_bleed_tick -= delta
	if _bleed_tick > 0.0:
		return
	_bleed_tick = BLEED_TICK
	if GameState.god_mode and GameState.god_invuln:
		return
	hp = maxf(0.0, hp - 1.0)
	if hp <= 0.0:
		GameState.last_hit = "bleed"
	_flash = 0.5
	run.fx.text(global_position + Vector2(randf_range(-14, 14), -80), "-1", Color("e8455a"), 20)
	run.fx.dissipate(global_position + Vector2(randf_range(-10, 10), -40), Color("c8304a"))
	run.hud.set_hp(hp, max_hp)
	if hp <= 0.0 and not _retake():
		alive = false
		run.on_player_died()


## Golpe que deja a Kroker clavado en el sitio / A hit that leaves Kroker stuck in place
func root(seconds: float) -> void:
	root_t = maxf(root_t, seconds)


func shock(seconds: float) -> void:
	Progress.tip("shock")
	shock_t = maxf(shock_t, seconds)


## Mal olor: pierde una de sus armas al azar durante un rato (si solo lleva una, no pasa nada)
## Stench: loses one of his weapons at random for a while (with only one weapon, nothing happens)
func stink(seconds: float) -> void:
	if weapon2 == null:
		return
	Progress.tip("stench")
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
	_draw_dust()
	_draw_exam_mark()
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
	# Con el collar de druida puesto (arma principal), Kroker ES el animal / With the druid collar as
	# the main weapon, Kroker IS the animal
	var dr := druid()
	if alive and dr != null and dr == weapon and dr.transformed and not weapon_stunk(dr):
		_draw_animal(dr, sx, sy)
		if run.running:
			# Los anillos de carga: los del collar en el lomo; los de la segunda arma, junto a ella
			# Charge rings: the collar's on the back; the second weapon's, next to it
			if weapon2 and not weapon_stunk(weapon2):
				_ring_b = _draw_charge_rings(weapon2.charge_bars(), (DruidArt.HELD_AT[dr.form] + Vector2(30, 6)) * Vector2(_facing, 1.0), _ring_b)
			_ring_a = _draw_charge_rings(dr.charge_bars(), DruidArt.RING_AT[dr.form] * Vector2(_facing, 1.0), _ring_a)
			_draw_heavy_pips(dr, Vector2(0, 14))
		_draw_hearth_ring()
		_draw_shield_bubble()
		_draw_grudge()
		return
	# Un saltito al girar / A little hop while spinning
	var lift := sin(boots.spin * PI) * 12.0 if boots and boots.spin > 0.0 else 0.0
	# Levitando: flota un palmo y se mece / Hovering: floats a hand's breadth up and sways
	var hover_px := _hover * (16.0 + sin(_t * 2.6) * 4.0)
	lift += hover_px
	KrokerArt.draw(self, Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2(-200.0 * sx / 2.0, -288.0 * sy - hop - lift)),
		outfit, _t, {"facing": facing, "boots": boots != null and armed, "reload": reload_anim,
		"shades": GameState.run_shades or (run.helpers != null and run.helpers.shades), "fedora": fedora, "kick_l": boots.kick_l if boots else 0.0, "kick_r": boots.kick_r if boots else 0.0,
		"thrust": maxf(boots.thrust, 1.0 if _dash_t > 0.0 else 0.0) if boots else 0.0, "flash": _flash, "attack": attack_anim, "aim": aim, "sucking": sucking,
		"cast": cast_anim, "walk": _walk, "moving": _moving, "armed": armed and not weapon_stunk(weapon) and not _ball_away(weapon), "lean": hurt_lean + pose_lean,
		# La segunda arma va en la mano libre / The second weapon goes in the free hand
		"second": weapon2.id if weapon2 else "", "anim2": weapon2.anim if weapon2 else 0.0,
		"druid": _druid_color(), "hover": hover_px / sy, "yawn": _idle_yawn(),
		"hide2": (weapon2 is WeaponShield and (weapon2 as WeaponShield).hidden_pillow) or weapon_stunk(weapon2) or _ball_away(weapon2),
		"aim2": (weapon2 as WeaponVacuum).aim_dir() if weapon2 is WeaponVacuum else Vector2(1, 0.5),
		"sucking2": weapon2 is WeaponVacuum and (weapon2 as WeaponVacuum).sucking})
	if spin_a > 0.0:
		_draw_spin_trail(spin_a, true)
	if alive and run.running and weapon and not weapon_stunk(weapon):
		_ring_a = _draw_charge_rings(weapon.charge_bars(), weapon.charge_anchor(), _ring_a)
	if alive and run.running and weapon2 and not weapon_stunk(weapon2):
		_ring_b = _draw_charge_rings(weapon2.charge_bars(), weapon2.charge_anchor(), _ring_b)
	# Puntitos del golpe fuerte bajo los pies / Heavy-hit dots under the feet
	if alive and run.running:
		if weapon and not weapon_stunk(weapon):
			_draw_heavy_pips(weapon, Vector2(0, 14))
		if weapon2 and not weapon_stunk(weapon2):
			_draw_heavy_pips(weapon2, Vector2(0, 26))
	_draw_hearth_ring()
	_draw_shield_bubble()
	_draw_states()
	_draw_plasters(sx, sy, hop + lift)
	_draw_grudge()


## Tiritas de Doc pegadas por el cuerpo de Kroker, una por punto (como mucho 6 a la vista)
## Doc's plasters stuck around Kroker's body, one per point (6 visible at most)
const PLASTER_AT := [Vector2(116, 152), Vector2(70, 214), Vector2(92, 258), Vector2(88, 118), Vector2(130, 206), Vector2(110, 262)]
const PLASTER_ROT := [0.5, -0.4, 0.2, -0.6, 0.7, -0.2]
func _draw_plasters(sx: float, sy: float, up: float) -> void:
	var n := mini(floori(plasters), PLASTER_AT.size())
	for i in n:
		var k: Vector2 = PLASTER_AT[i]
		var p := Vector2((k.x - 100.0) * absf(sx) * _facing, (k.y - 288.0) * sy - up)
		draw_set_transform(p, PLASTER_ROT[i] * _facing, Vector2.ONE)
		draw_rect(Rect2(-7, -3, 14, 6), Color("6a4a3a"))
		draw_rect(Rect2(-6, -2, 12, 4), Color("f2cfa0"))
		draw_rect(Rect2(-2, -2, 4, 4), Color("e0b088"))
		draw_set_transform(Vector2.ZERO)


## El fichado por la Revancha de Stolk: una vena de enfado roja encima y un anillo a sus pies
## The one marked by Stolk's Payback: a red anger vein above it and a ring at its feet
func _draw_grudge() -> void:
	if not is_instance_valid(grudge) or not (grudge as Enemy).is_targetable():
		return
	var e := grudge as Enemy
	var at := e.global_position - global_position
	var red := Color("ff4a5a")
	draw_set_transform(at, 0.0, Vector2(1.0, 0.4))
	for i in 4:
		var a := _t * 2.0 + i * TAU / 4.0
		draw_arc(Vector2.ZERO, e.radius + 14.0, a, a + 0.9, 8, Color(red, 0.75), 4.0)
	draw_set_transform(Vector2.ZERO)
	var top := at + e.head_top() + Vector2(0, -16.0 + sin(_t * 6.0) * 2.0)
	var pulse := 1.0 + 0.15 * absf(sin(_t * 5.0))
	draw_set_transform(top, 0.0, Vector2(pulse, pulse))
	# La vena de enfado de los tebeos: cuatro arcos que se curvan hacia el centro
	# The comic-book anger vein: four arcs curving in towards the middle
	for pass_i in 2:
		for i in 4:
			var c := Vector2(1.0 if i % 2 == 0 else -1.0, 1.0 if i < 2 else -1.0) * 9.0
			var ang := (-c).angle()
			draw_arc(c, 7.0, ang - 0.95, ang + 0.95, 8, Color("140e26") if pass_i == 0 else red, 6.0 if pass_i == 0 else 3.0)
	draw_set_transform(Vector2.ZERO)


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
	var ar := run.room as Act3Room
	var locker := ar != null and ar.shades_near
	if not locker and (lr == null or not lr.fire_near or not lr.can_sacrifice()):
		return
	var font := UITheme.font("caps")
	var size := UITheme.pixel_size(14)
	var text := Settings.controls_text(tr("SHADES_PROMPT" if locker else "HEARTH_PROMPT")).to_upper()
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


## Una fila de puntitos: se van llenando y el último avisa de que el siguiente golpe es fuerte
## A row of dots: they fill up and the last one warns that the next hit is heavy
func _draw_heavy_pips(w: Weapon, at: Vector2) -> void:
	var every := w.heavy_every()
	if every <= 0:
		return
	var n := every - 1
	var ready := w.heavy_count >= n
	for i in n:
		var p := at + Vector2((i - (n - 1) / 2.0) * 13.0, 0)
		var on := i < w.heavy_count
		draw_circle(p, 5.0, Color(0.05, 0.03, 0.18, 0.7))
		var col := UITheme.GOLD if ready else UITheme.BONE
		draw_circle(p, 3.4, Color(col, (0.85 + 0.15 * sin(_t * 10.0)) if on else 0.25))
		if ready:
			draw_arc(p, 5.5, 0, TAU, 12, Color(UITheme.GOLD, 0.5 + 0.4 * sin(_t * 10.0)), 1.5)


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

