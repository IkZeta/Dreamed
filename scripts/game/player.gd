class_name Player
extends Node2D
## Kroker en la partida: se mueve y su arma ataca sola (estilo Brotato).
## Kroker in game: moves around while his weapon attacks on its own (Brotato style).

const ART_SCALE := 0.5
const HIT_INVULN := 0.8

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
var armed := true            # lleva el arma en la mano / holds the weapon
var hurt_lean := 0.0         # retroceso al recibir daño / recoil when hit
var hop := 0.0               # altura de un salto en píxeles / jump height in pixels
var shield_charges := 0      # golpes que para la almohada recogida / hits the picked-up pillow blocks
var slow_t := 0.0            # frenado por un charco / slowed by a puddle
var push := Vector2.ZERO     # empuje del suelo inclinado / push from a tilted floor
var bleed_t := 0.0           # sangrado de los cuchillos del Chef / bleeding from the Chef's knives
var _bleed_tick := 0.0
var root_t := 0.0            # aturdido por el sartenazo: no se puede mover / dazed by the pan: can't move
var _land := 0.0             # rebote al aterrizar / landing squash

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


func _make_weapon(id: String, primary: bool) -> Weapon:
	var w: Weapon
	match id:
		"shield": w = WeaponShield.new()
		"book": w = WeaponBook.new()
		"vacuum": w = WeaponVacuum.new()
		"finger": w = WeaponFinger.new()
		"teddy": w = WeaponTeddy.new()
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
func land() -> void:
	_land = 1.0


func set_facing(f: float) -> void:
	_facing = f


func take_damage(amount: float) -> void:
	if not alive or _invuln > 0.0 or not run.running:
		return
	if GameState.god_mode and GameState.god_invuln:
		return  # modo Dios / god mode
	if shield_charges > 0:
		# La almohada recogida para el golpe / The picked-up pillow blocks the hit
		shield_charges -= 1
		_invuln = HIT_INVULN
		run.fx.ring(global_position + Vector2(0, -36), 34.0, Color("8fe0ff"), 0.5, 2.0)
		Audio.play("pillow", -4.0)
		return
	# La defensa resta daño, pero siempre se recibe al menos 1.
	# Defense subtracts damage, but at least 1 always gets through.
	var dmg := maxf(1.0, amount - armor)
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


func _draw() -> void:
	# Parpadea mientras es invulnerable / Blinks while invulnerable
	var visible_now := _invuln <= 0.0 or fmod(_t, 0.12) < 0.07 or not alive
	if not visible_now:
		return
	# Al aterrizar se aplasta un poco y recupera la forma / Squashes a little on landing, then springs back
	var squash := sin(_land * PI) * 0.12
	var sx := ART_SCALE * (1.0 + squash)
	var sy := ART_SCALE * (1.0 - squash)
	KrokerArt.draw(self, Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2(-200.0 * sx / 2.0, -288.0 * sy - hop)),
		outfit, _t, {"facing": _facing, "flash": _flash, "attack": attack_anim, "aim": aim, "sucking": sucking,
		"cast": cast_anim, "walk": _walk, "moving": _moving, "armed": armed, "lean": hurt_lean})
	if weapon2:
		_draw_floating_weapon()
	if alive and run.running and weapon:
		_ring_a = _draw_charge_rings(weapon.charge_bars(), weapon.charge_anchor(), _ring_a)
	if alive and run.running and weapon2:
		_ring_b = _draw_charge_rings(weapon2.charge_bars(), weapon2.charge_anchor(), _ring_b)
	_draw_hearth_ring()
	_draw_shield_bubble()
	_draw_states()


## Anillo naranja sobre la cabeza mientras carga el sacrificio en la chimenea
## Orange ring over his head while the fireplace sacrifice charges
func _draw_hearth_ring() -> void:
	var lr := run.room as LivingRoom
	if lr == null or lr.fire_charge <= 0.0:
		return
	var c := Vector2(0, -170)
	draw_circle(c, 15.0, Color(0.05, 0.03, 0.18, 0.5))
	draw_arc(c, 11.0, 0, TAU, 28, Color("ffb06a", 0.2), 4.0, true)
	draw_arc(c, 11.0, -PI / 2.0, -PI / 2.0 + TAU * lr.fire_charge, 28, Color("ffb06a"), 4.0, true)
	# Llamita dentro / A little flame inside
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 5), c + Vector2(0, -7 - sin(_t * 12.0) * 1.5), c + Vector2(4, 5)]), Color("ffd07a"))


## Estrellitas de mareo, gotas de sangre y glitch del hackeo / Dizzy stars, blood drops and hack glitch
func _draw_states() -> void:
	if root_t > 0.0:
		for i in 3:
			var ang := _t * 7.0 + i * TAU / 3.0
			DreamBackground.draw_star(self, Vector2(cos(ang) * 18.0, -158 + sin(ang) * 5.0), 3.0, UITheme.GOLD)
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


## La segunda arma flota detrás del hombro de Kroker, con un aura suave
## The second weapon floats behind Kroker's shoulder, with a soft aura
func _draw_floating_weapon() -> void:
	var w := weapon2
	if w is WeaponShield and (w as WeaponShield).hidden_pillow:
		return
	var c := w.float_offset()
	var col: Color = KrokerArt.ACCENT.get(w.id, UITheme.GOLD)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(46, 46), Vector2(92, 92)), false, Color(col, 0.25))
	var s := ART_SCALE
	match w.id:
		"bat":
			draw_set_transform(c + Vector2(0, 26), (0.5 - w.anim * 2.2) * _facing, Vector2(s, s))
			Sprites.draw(self, "weapon_bat")
		"shield":
			draw_set_transform(c, sin(_t * 1.5) * 0.15, Vector2(s, s) * (1.0 + w.anim * 0.3))
			Sprites.draw(self, "weapon_pillow")
		"book":
			draw_set_transform(c, sin(_t * 1.2) * 0.1, Vector2(s, s))
			Sprites.draw(self, "weapon_book")
			if w.anim > 0.0:
				draw_circle(Vector2.ZERO, 20.0 * w.anim, Color(col, 0.5 * w.anim))
		"vacuum":
			var dir: Vector2 = (w as WeaponVacuum).aim_dir()
			draw_set_transform(c - Vector2(150, 253) * s, 0.0, Vector2(s, s))
			Sprites.draw(self, "weapon_tank")
			draw_set_transform(c + dir * 14.0, dir.angle(), Vector2(s, s))
			Sprites.draw(self, "weapon_nozzle")
		"finger":
			# Una mano que flota haciendo la pistola con los dedos / A floating hand making a finger gun
			KrokerArt.finger_gun(self, Transform2D(0.0, Vector2(_facing, 1.0) * s * 1.6, 0.0, c), Vector2.ZERO, Vector2(1, 0), w.anim)
		"teddy":
			draw_set_transform(c, sin(_t * 1.4) * 0.12 - w.anim * 0.4 * _facing, Vector2(s, s) * (1.0 + w.anim * 0.2))
			Sprites.draw(self, "weapon_teddy")
	draw_set_transform(Vector2.ZERO)
