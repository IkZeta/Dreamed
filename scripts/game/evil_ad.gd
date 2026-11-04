class_name EvilAd
extends Enemy
## Jefe final (Sueño 20): Evil Ad, la versión retorcida y delirante de Mr. Ad. Una tele gigante
## rajada con una sonrisa enorme y ojos de «$» que giran, cuerpo de chapa roja oxidada, cables
## que se mueven como tentáculos con megáfonos y teles pequeñas dando vueltas a su alrededor.
## Flota por la ciudad (no le paran los edificios) y va cambiando de "programa":
##  - Teletienda: rocía monedas rojas en abanico mientras se mueve alrededor de Kroker.
##  - Pop-ups: suelta ventanas de anuncio que van hacia Kroker y estallan si no las cierras (rompes).
##  - Zapping: carga los ojos y barre la calle con un rayo de interferencias.
##  - Corte publicitario: se mete en la estática y reaparece encima de Kroker con una onda.
##  - Patrocinado: llama a enemigos de la ciudad.
## A media vida entra en DELIRIO: más rápido, espirales de monedas, dos rayos y más pop-ups.
## Final boss (Dream 20): Evil Ad, the twisted, delirious version of Mr. Ad. A giant cracked TV
## with a huge grin and spinning "$" eyes, a rusty red tin body, cables that move like tentacles
## with megaphones, and little TVs circling him. He floats over the city (buildings don't stop him)
## and keeps switching "programmes":
##  - Teleshopping: sprays fans of red coins while moving round Kroker.
##  - Pop-ups: lets out advert windows that drift to Kroker and blow up unless you close (break) them.
##  - Channel surf: charges his eyes and sweeps the street with an interference beam.
##  - Ad break: dives into static and reappears on top of Kroker with a shockwave.
##  - Sponsored: calls in city enemies.
## At half health he goes into DELIRIUM: faster, coin spirals, two beams and more pop-ups.

signal defeated

const HP := 1400.0
const ALT := 70.0                 # flota a esta altura / floats at this height
const DELIRIUM_AT := 0.5
const PROGRAMS: Array[String] = ["shop", "popups", "zap", "spam", "shop", "break", "sponsor"]
const COIN_DAMAGE := 3.0
const COIN_SPEED := 360.0
const POPUP_N := 3
const ZAP_WARN := 1.1
const ZAP_TIME := 1.3
const ZAP_SWEEP := 1.0           # radianes que barre / radians it sweeps
const ZAP_LEN := 900.0
const ZAP_WIDTH := 44.0
const ZAP_DAMAGE := 4.0
const BREAK_TIME := 1.1          # tiempo en la estática / time in the static
const SLAM_RADIUS := 170.0
const SLAM_DAMAGE := 5.0
const SPONSOR_KINDS: Array[String] = ["police", "police", "thug", "cyber", "skeleton"]
const RED := Color("e0303a")
const RED_D := Color("8a1420")
const TIN := Color("4a2a30")
const TIN_L := Color("6e3a40")

var entering := 0.0              # 1 → 0 mientras baja del cielo / 1 → 0 while descending from the sky
var program := "shop"
var _prog_t := 0.0
var _prog_i := 0
var _target := Vector2.ZERO
var _coin_cd := 0.8
var _zap := {}                   # {"t", "a0", "dir"} rayo en curso / beam under way
var _zap2 := {}
var _break_to := Vector2.ZERO
var _hidden := false
var _dying := -1.0
var _delirium := false
var _laugh := 0.0
var _spiral := 0.0
var _tilt := 0.0
var _tv_xf := Transform2D.IDENTITY


func _init() -> void:
	bestiary_id = "boss_evil_ad"
	max_hp = HP
	hp = max_hp
	mass = 90.0
	contact_damage = 3.0
	radius = 70.0
	speed = 220.0
	aim_height = 70.0
	shards = 0


func _ready() -> void:
	super._ready()
	state = State.ALIVE
	_fade = 1.0
	if preview:
		return
	_target = position


func is_boss() -> bool:
	return true


func is_targetable() -> bool:
	return state == State.ALIVE and not _hidden and entering <= 0.0 and _dying < 0.0


func is_dangerous() -> bool:
	return is_targetable()


func can_fall() -> bool:
	return false


func start_bounce(_damage: float, _chain: int, _ignore: Array = []) -> void:
	pass


func glitch(stun := 0.0, slow := 0.0, vulnerable := 0.0, mult := 1.5) -> void:
	super.glitch(0.0, slow, vulnerable, mult)


func aim_point() -> Vector2:
	return global_position + Vector2(0, -ALT - 110)


func reach_bonus() -> float:
	return radius


func head_top() -> Vector2:
	return Vector2(0, -ALT - 300)


func hit(amount: float, _impulse := Vector2.ZERO) -> void:
	if not is_targetable():
		return
	super.hit(amount, Vector2.ZERO)
	run.update_boss_hp()
	if not _delirium and hp < max_hp * DELIRIUM_AT and hp > 0.0:
		_go_delirious()


func die(counted: bool) -> void:
	if not counted:
		super.die(false)
		return
	if _dying >= 0.0:
		return
	_dying = 0.0
	if _spam and is_instance_valid(_spam):
		_spam.queue_free()
	_zap = {}
	_zap2 = {}
	run.drop_shards(global_position, roundi(50 * GameState.shard_mult()))
	run.gain_reality(GameState.REALITY_CHEF * 2, global_position)
	Progress.kill(bestiary_id)
	GameState.run_kills += 1
	Progress.add_stat("kills")
	Audio.play("crack", -1.0)
	Audio.play("glitch", -2.0)
	run.shake(18.0)


## Mitad de vida: se vuelve loco / Half health: he goes mad
func _go_delirious() -> void:
	_delirium = true
	_laugh = 2.0
	speed *= 1.35
	run.shake(14.0)
	run.flash_screen(Color("e0303a"), 0.35)
	run.noir_glitch(0.8, 1.0)
	Audio.play("glitch", -2.0)
	Audio.play("boss_wake", -2.0)
	run.fx.text(global_position + Vector2(0, -ALT - 330), tr("EVIL_AD_DELIRIUM"), RED, 34)
	_set_program("popups")


func laugh(secs := 2.0) -> void:
	_laugh = secs


func delirious() -> bool:
	return _delirium


func _physics_process(delta: float) -> void:
	_t += delta
	if preview:
		queue_redraw()
		return
	_laugh = maxf(0.0, _laugh - delta)
	if _dying >= 0.0:
		_dying += delta
		if fmod(_dying, 0.12) < delta:
			var p := global_position + Vector2(randf_range(-120, 120), -ALT - randf_range(0, 260))
			run.fx.dissipate(p, RED)
			run.fx.ring(p, 34.0, Color("ffd27a"), 0.4, 2.4)
			Audio.play("crack", -10.0, 0.2)
		if _dying > 3.0:
			state = State.DYING
			defeated.emit()
			queue_free()
		queue_redraw()
		return
	_flash = maxf(0.0, _flash - delta * 4.0)
	if entering > 0.0 or not run.running:
		queue_redraw()
		return
	_update_dots(delta)
	_prog_t += delta
	var k := 0.75 if _delirium else 1.0
	match program:
		"shop": _shop(delta, k)
		"popups": _popups(delta, k)
		"zap": _zap_prog(delta, k)
		"break": _break(delta)
		"sponsor": _sponsor(delta, k)
		"spam": _spam_prog(delta)
	_tick_zap(delta)
	# En delirio, la imagen se descuadra de vez en cuando / When delirious, the picture glitches now and then
	if _delirium and randf() < delta * 0.7:
		run.noir_glitch(randf_range(0.12, 0.35), randf_range(0.5, 1.0))
	if is_dangerous():
		_touch_player()
	queue_redraw()


func _set_program(p: String) -> void:
	program = p
	_prog_t = 0.0
	_coin_cd = 0.5


func _next_program() -> void:
	_prog_i = (_prog_i + 1) % PROGRAMS.size()
	_set_program(PROGRAMS[_prog_i])


## Flota hacia un punto alrededor de Kroker, a tumbos / Floats towards a point round Kroker, lurching
func _float(delta: float, dist: float) -> void:
	var player: Player = run.player
	if position.distance_to(_target) < 40.0 or fmod(_t, 2.4) < delta:
		var a := randf() * TAU
		_target = _clamp(player.position + Vector2(cos(a) * dist, sin(a) * dist * 0.6))
	var to := _target - position
	var jolt := Vector2(sin(_t * 2.7) * 60.0, cos(_t * 1.9) * 30.0)
	if to.length() > 10.0:
		position += (to.normalized() * speed + jolt) * delta
	position = _clamp(position)
	_tilt = lerpf(_tilt, clampf(to.x / 600.0, -0.25, 0.25), delta * 3.0)
	_facing = signf(run.player.position.x - position.x) if absf(run.player.position.x - position.x) > 30.0 else _facing


func _clamp(p: Vector2) -> Vector2:
	var r: Rect2 = run.arena_rect().grow(-radius)
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


## Teletienda: abanicos de monedas (en delirio, espirales) / Teleshopping: fans of coins (spirals when delirious)
func _shop(delta: float, k: float) -> void:
	_float(delta, 420.0)
	_coin_cd -= delta
	if _coin_cd <= 0.0:
		_coin_cd = 1.25 * k
		var from := global_position + Vector2(0, -ALT - 110)
		if _delirium and fmod(_prog_t, 2.0) > 1.0:
			# Espiral de monedas / Coin spiral
			for i in 10:
				_coin(from, Vector2.from_angle(_spiral + TAU * i / 10.0), COIN_SPEED * 0.75)
			_spiral += 0.35
		else:
			var dir: Vector2 = (run.player.global_position + Player.HURT - from).normalized()
			var n := 7 if _delirium else 5
			for i in n:
				_coin(from, dir.rotated((i - (n - 1) / 2.0) * 0.2), COIN_SPEED)
		Audio.play("reality", -12.0, 0.2)
	if _prog_t > 6.5:
		_next_program()


func _coin(from: Vector2, dir: Vector2, spd: float) -> void:
	var s := EnemyShot.new()
	s.run = run
	s.kind = "coin"
	s.position = from
	s.velocity = dir * spd
	s.damage = COIN_DAMAGE * atk_mult()
	s.radius = 11.0
	s.life = 3.2
	run.world.add_child(s)


## Pop-ups: ventanas que van a por Kroker / Pop-ups: windows that go after Kroker
func _popups(delta: float, _k: float) -> void:
	_float(delta, 480.0)
	if _prog_t < delta * 1.5:
		_laugh = 1.2
		Audio.play("spawn", -6.0, 0.1)
		var n := POPUP_N * (2 if _delirium else 1)
		for i in n:
			var p := PopupAd.new()
			p.setup(run)
			var a := TAU * i / n + randf() * 0.4
			p.position = _clamp(global_position + Vector2(cos(a) * 140.0, sin(a) * 70.0))
			run.enemies.add_child(p)
			run.fx.ring(p.position + Vector2(0, -30), 26.0, RED, 0.4, 2.0)
	if _prog_t > 5.0:
		_next_program()


## Zapping: aviso, luego un rayo que barre / Channel surf: a warning, then a sweeping beam
func _zap_prog(delta: float, _k: float) -> void:
	if _prog_t < delta * 1.5:
		var dir: Vector2 = (run.player.global_position + Player.HURT - _eye()).normalized()
		var side := -1.0 if randf() < 0.5 else 1.0
		_zap = {"t": 0.0, "a0": dir.angle() - side * ZAP_SWEEP * 0.5, "side": side}
		if _delirium:
			_zap2 = {"t": 0.0, "a0": dir.angle() + side * ZAP_SWEEP * 0.5, "side": -side}
		Audio.play("zap", -6.0)
	_tilt = lerpf(_tilt, 0.0, delta * 4.0)
	if _prog_t > ZAP_WARN + ZAP_TIME + 0.6:
		_next_program()


func _eye() -> Vector2:
	return global_position + Vector2(0, -ALT - 200)


func _zap_angle(z: Dictionary) -> float:
	var f := clampf((float(z["t"]) - ZAP_WARN) / ZAP_TIME, 0.0, 1.0)
	return float(z["a0"]) + float(z["side"]) * ZAP_SWEEP * f


func _tick_zap(delta: float) -> void:
	for key in ["_zap", "_zap2"]:
		var z: Dictionary = get(key)
		if z.is_empty():
			continue
		z["t"] = float(z["t"]) + delta
		if float(z["t"]) >= ZAP_WARN and float(z["t"]) < ZAP_WARN + ZAP_TIME:
			if fmod(float(z["t"]), 0.1) < delta:
				Audio.play("laser", -16.0, 0.2)
			var dir := Vector2.from_angle(_zap_angle(z))
			var player: Player = run.player
			var rel: Vector2 = player.global_position + Player.HURT - _eye()
			var along := rel.dot(dir)
			var off := absf(rel.cross(dir))
			if along > 0.0 and along < ZAP_LEN and off < ZAP_WIDTH * 0.5 + Player.HURT_R:
				player.take_damage(ZAP_DAMAGE * GameState.enemy_dmg_mult() * atk_mult(), self)
		if float(z["t"]) >= ZAP_WARN + ZAP_TIME:
			z = {}
		set(key, z)


## Corte publicitario: se mete en la estática y cae encima de Kroker / Ad break: dives into static and lands on Kroker
func _break(_delta: float) -> void:
	if _prog_t < 0.02:
		_hidden = true
		_break_to = _clamp(run.player.position)
		run.fx.text(global_position + Vector2(0, -ALT - 300), tr("EVIL_AD_BREAK"), RED, 26)
		Audio.play("glitch", -4.0)
	if _hidden and _prog_t >= BREAK_TIME:
		_hidden = false
		position = _break_to
		run.shake(14.0)
		Audio.play("stomp", 0.0)
		run.fx.ring(global_position, SLAM_RADIUS, Color(Settings.warning_color(), 0.8), 0.45, 3.0)
		run.fx.ring(global_position, 90.0, RED, 0.6, 2.4)
		var player: Player = run.player
		if player.global_position.distance_to(global_position) < SLAM_RADIUS:
			player.take_damage(SLAM_DAMAGE * GameState.enemy_dmg_mult() * atk_mult(), self)
		# Anillo de monedas al caer / A ring of coins on landing
		for i in 12 if _delirium else 8:
			_coin(global_position + Vector2(0, -40), Vector2.from_angle(TAU * i / (12 if _delirium else 8)), COIN_SPEED * 0.7)
	if _prog_t > BREAK_TIME + 1.4:
		_next_program()


## Spam: te llena la pantalla de pop-ups que hay que cerrar con QTE, mientras sigue tirando
## monedas despacio / Spam: fills your screen with pop-ups to close with QTEs, while still throwing
## coins slowly
var _spam: AdSpam = null


func _spam_prog(delta: float) -> void:
	_float(delta, 460.0)
	if _prog_t < delta * 1.5:
		_laugh = 1.5
		run.fx.text(global_position + Vector2(0, -ALT - 320), tr("EVIL_AD_SPAM"), RED, 28)
		Audio.play("glitch", -4.0)
		_spam = AdSpam.new()
		_spam.run = run
		_spam.count = 8 if _delirium else 5
		run.add_child(_spam)
	_coin_cd -= delta
	if _coin_cd <= 0.0:
		_coin_cd = 2.2
		var from := global_position + Vector2(0, -ALT - 110)
		var dir: Vector2 = (run.player.global_position + Player.HURT - from).normalized()
		for i in 3:
			_coin(from, dir.rotated((i - 1) * 0.25), COIN_SPEED * 0.75)
	if (_spam == null or not is_instance_valid(_spam) or _spam.done()) and _prog_t > 1.5:
		_next_program()


## Patrocinado: llama a la policía y a otros / Sponsored: calls the police and others
func _sponsor(delta: float, _k: float) -> void:
	_float(delta, 460.0)
	if _prog_t < delta * 1.5:
		_laugh = 1.5
		Audio.play("spawn", -6.0, 0.1)
		for i in (3 if _delirium else 2):
			var p: Vector2 = run.clamp_to_arena(run.player.position + Vector2.from_angle(randf() * TAU) * randf_range(260, 420), 30.0)
			run.fx.telegraph(p + Vector2(0, -16), 0.8)
			run.spawn_enemy_soon(SPONSOR_KINDS[randi() % SPONSOR_KINDS.size()], p, 0.8)
	if _prog_t > 3.0:
		_next_program()


# --- Dibujo / Drawing --------------------------------------------------------------------

func _draw() -> void:
	if not preview and state == State.ALIVE:
		for z: Dictionary in [_zap, _zap2]:
			if not z.is_empty():
				_draw_zap(z)
		if _hidden:
			# Aviso donde va a caer / Warning where he'll land
			var at := _break_to - global_position
			var k2 := minf(1.0, _prog_t / BREAK_TIME)
			draw_colored_polygon(_ellipse(at, Vector2(SLAM_RADIUS, SLAM_RADIUS * 0.4)), Color(Settings.warning_color(), 0.12 + 0.25 * k2))
			draw_arc(at, SLAM_RADIUS * k2, 0, TAU, 32, Color(Settings.warning_color(), 0.8), 3.0)
	super._draw()


func _draw_zap(z: Dictionary) -> void:
	var from := _eye() - global_position
	var dir := Vector2.from_angle(_zap_angle(z))
	if float(z["t"]) < ZAP_WARN:
		EnemyShot.draw_warning(self, from, dir, ZAP_LEN, ZAP_WIDTH, float(z["t"]) / ZAP_WARN)
		return
	var to := from + dir * ZAP_LEN
	var side := Vector2(-dir.y, dir.x)
	for i in 3:
		var w := ZAP_WIDTH * (1.0 - i * 0.3)
		draw_line(from, to, [Color(RED, 0.35), Color("ff7a8a"), Color.WHITE][i], w)
	# Interferencias a lo largo del rayo / Interference along the beam
	for i in 10:
		var d := randf() * ZAP_LEN
		draw_line(from + dir * d - side * ZAP_WIDTH * 0.7, from + dir * d + side * ZAP_WIDTH * 0.7, Color(1, 1, 1, 0.6), 2.0)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	if _hidden and not preview:
		# Dentro de la estática: solo un torbellino de ruido / Inside the static: just a whirl of noise
		for i in 40:
			var p := offset + Vector2(randf_range(-110, 110), -ALT - randf_range(0, 280))
			draw_rect(Rect2(p, Vector2(6, 4)), Color(1, 1, 1, randf() * 0.6 * a))
		return
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	var up := entering * 900.0
	var bob := sin(_t * 2.2) * 8.0
	var base := offset + Vector2(0, -ALT - up + bob)
	# Sombra en el suelo / Ground shadow
	draw_colored_polygon(_ellipse(offset, Vector2(130, 30) * (1.0 - entering * 0.6)), Color(0.05, 0.0, 0.05, 0.45 * a))
	# Columna de estática en lugar de piernas / A column of static instead of legs
	for i in 18:
		var ph := fposmod(_t * 1.4 + i * 0.055, 1.0)
		var w := lerpf(70.0, 20.0, ph)
		draw_rect(Rect2(base + Vector2(randf_range(-w, w) - 4, ph * 60.0), Vector2(8, 4)), Color(RED.lerp(Color.WHITE, randf()), (1.0 - ph) * 0.8 * a))
	draw_set_transform(base, _tilt + sin(_t * 1.3) * 0.05, Vector2.ONE)
	var m := mod
	# Tentáculos de cable con megáfonos / Cable tentacles with megaphones
	for i in 4:
		var side := -1.0 if i < 2 else 1.0
		var root := Vector2(side * 56.0, -90.0 - (i % 2) * 40.0)
		var wave := sin(_t * (2.0 + i * 0.4) + i) * (40.0 if not _delirium else 70.0)
		var mid := root + Vector2(side * 70.0, 20.0 + wave)
		var end := root + Vector2(side * (130.0 + (i % 2) * 30.0), -40.0 + wave * 1.4)
		var pts := PackedVector2Array()
		for s in 12:
			var u := s / 11.0
			pts.append(root.lerp(mid, u).lerp(mid.lerp(end, u), u))
		draw_polyline(pts, Color("1a0a10", a), 14.0)
		draw_polyline(pts, Color(RED_D, a) * m, 8.0)
		# Megáfono o tele pequeña en la punta / Megaphone or a little TV at the tip
		if i % 2 == 0:
			var dir := (end - mid).normalized()
			var perp := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([end - perp * 8, end + perp * 8, end + dir * 34 + perp * 22, end + dir * 34 - perp * 22]), Color("c8c4cc", a) * m)
			draw_colored_polygon(PackedVector2Array([end + dir * 30 + perp * 18, end + dir * 34 + perp * 22, end + dir * 34 - perp * 22, end + dir * 30 - perp * 18]), Color("1a0a10", a))
		else:
			draw_rect(Rect2(end - Vector2(20, 16), Vector2(40, 32)), Color("1a0a10", a))
			draw_rect(Rect2(end - Vector2(16, 12), Vector2(32, 24)), Color(RED if fmod(_t * 3.0 + i, 2.0) < 1.0 else Color("ffd0d0"), a))
	# Cuerpo de chapa roja oxidada con pegatinas / Rusty red tin body with stickers
	draw_colored_polygon(PackedVector2Array([Vector2(-62, -150), Vector2(62, -150), Vector2(74, -10), Vector2(-74, -10)]), Color("1a0a10", a))
	draw_colored_polygon(PackedVector2Array([Vector2(-58, -146), Vector2(58, -146), Vector2(70, -14), Vector2(-70, -14)]), Color(TIN, a) * m)
	draw_rect(Rect2(-54, -142, 10, 124), Color(TIN_L, a) * m)
	draw_rect(Rect2(28, -60, 30, 18), Color("f6c24a", a) * m)
	draw_rect(Rect2(-40, -40, 24, 16), Color("ff4f8a", a) * m)
	# Pantalla de la barriga con anuncios que pasan muy deprisa / Belly screen with adverts flying past
	draw_rect(Rect2(-40, -128, 80, 56), Color("0d0a10", a))
	_strip(Rect2(-36, -124, 72, 48), a)
	draw_line(Vector2(10, -124), Vector2(-6, -100), Color("e8ecff", 0.8 * a), 2.0)
	draw_line(Vector2(-6, -100), Vector2(4, -80), Color("e8ecff", 0.8 * a), 2.0)
	# Cuello de cables / Cable neck
	for x in [-20.0, -6.0, 8.0, 22.0]:
		draw_line(Vector2(x, -150), Vector2(x + sin(_t * 3.0 + x) * 6.0, -176), Color([RED, Color("3fa8ff"), Color("f6c24a"), RED][int(x + 20) / 14 % 4], a), 5.0)
	# La tele gigante, ladeada y rajada / The giant TV, tilted and cracked
	_tv_xf = Transform2D(_tilt + sin(_t * 0.9) * 0.08 + (sin(_t * 23.0) * 0.04 if _laugh > 0.0 else 0.0), base + Vector2(0, -250).rotated(_tilt))
	draw_set_transform_matrix(_tv_xf)
	var tv := Rect2(-120, -84, 240, 168)
	draw_rect(tv.grow(8), Color("1a0a10", a))
	draw_rect(tv, Color(RED_D, a) * m)
	draw_rect(Rect2(tv.position, Vector2(tv.size.x, 12)), Color(RED, a) * m)
	draw_rect(Rect2(tv.position + Vector2(0, tv.size.y - 10), Vector2(tv.size.x, 10)), Color("5a0c16", a))
	var scr := Rect2(-100, -66, 200, 132)
	draw_rect(scr, Color("100408", a))
	_face(scr, a)
	# Brillo del cristal y grieta / Glass glare and crack
	draw_colored_polygon(PackedVector2Array([scr.position + Vector2(14, 6), scr.position + Vector2(60, 6), scr.position + Vector2(26, 60), scr.position + Vector2(8, 60)]), Color(1, 1, 1, 0.08 * a))
	draw_polyline(PackedVector2Array([Vector2(60, -66), Vector2(48, -40), Vector2(56, -24), Vector2(36, 4), Vector2(40, 22)]), Color("f4f1fa", 0.85 * a), 2.5)
	draw_line(Vector2(48, -40), Vector2(70, -30), Color("f4f1fa", 0.7 * a), 2.0)
	# Botones y rejilla del altavoz / Knobs and speaker grille
	for i in 2:
		draw_circle(Vector2(108, -40 + i * 34), 7.0, Color("1a0a10", a))
		draw_line(Vector2(108, -40 + i * 34), Vector2(108, -40 + i * 34) + Vector2.from_angle(_t * (3.0 + i)) * 6.0, Color("c8c4cc", a), 2.0)
	# Antenas torcidas con bombilla / Bent antennas with a bulb
	for side in [-1.0, 1.0]:
		var tip := Vector2(side * 90.0, -170.0 + sin(_t * 2.0 + side) * 8.0)
		draw_polyline(PackedVector2Array([Vector2(side * 30.0, -84), Vector2(side * 56.0, -130), tip]), Color("c8c4cc", a), 5.0)
		var on := fmod(_t * (2.0 if not _delirium else 6.0) + side, 1.0) < 0.5
		draw_circle(tip, 9.0, Color(RED if on else RED_D, a))
		if on:
			draw_texture_rect(DreamBackground.soft_texture(), Rect2(tip - Vector2(28, 28), Vector2(56, 56)), false, Color(RED, 0.4 * a))
	# Corona de banderines rotos / A crown of torn pennants
	for i in 5:
		var x := -80.0 + i * 40.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -92), Vector2(x + 30, -92), Vector2(x + 15, -118 - (i % 2) * 10)]), Color([RED, Color("f6c24a"), Color("ff4f8a")][i % 3], a) * m)
	draw_set_transform(Vector2.ZERO)
	# Teles pequeñas que giran a su alrededor (por fuera de la cara) / Little TVs circling him (outside the face)
	_orbit(base, a, false)
	draw_set_transform(Vector2.ZERO)


func _orbit(base: Vector2, a: float, _back: bool) -> void:
	var n := 5 if _delirium else 3
	for i in n:
		var ang := _t * (0.9 if not _delirium else 1.6) + TAU * i / n
		var c := base + Vector2(cos(ang) * 250.0, -150.0 + sin(ang) * 70.0)
		draw_rect(Rect2(c - Vector2(24, 18), Vector2(48, 36)), Color("1a0a10", a))
		draw_rect(Rect2(c - Vector2(20, 14), Vector2(40, 28)), Color(RED_D, a))
		for k in 4:
			draw_rect(Rect2(c + Vector2(randf_range(-18, 12), randf_range(-12, 10)), Vector2(8, 2)), Color(1, 1, 1, 0.6 * a))


## La cara en la pantalla: ojos de «$» que giran y una sonrisa enorme / The face on the screen: spinning "$" eyes and a huge grin
func _face(scr: Rect2, a: float) -> void:
	var c := scr.get_center()
	var glitchy := _delirium and fmod(_t, 1.3) < 0.15
	# Fondo con rayas de interferencia / Background with interference lines
	for i in 6:
		var y := scr.position.y + fposmod(_t * 60.0 + i * 24.0, scr.size.y)
		draw_rect(Rect2(scr.position.x, y, scr.size.x, 3), Color(RED, 0.12 * a))
	if glitchy:
		var words := ["BUY", "OBEY", "CONSUME", "$$$"]
		var font := ThemeDB.fallback_font
		draw_string(font, c + Vector2(-80, 14), words[int(_t * 7.0) % words.size()], HORIZONTAL_ALIGNMENT_CENTER, 160, 42, Color(RED, a))
		return
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 46.0, -24.0)
		draw_circle(e, 26.0, Color(RED, a))
		draw_circle(e, 20.0, Color("100408", a))
		# «$» que gira / Spinning "$"
		var sx := cos(_t * (4.0 if not _delirium else 9.0) + side)
		draw_set_transform_matrix(_tv_xf * Transform2D(0.0, Vector2(sx if absf(sx) > 0.15 else 0.15, 1.0), 0.0, e))
		var gold := Color("ffd84a", a)
		draw_arc(Vector2(0, -6), 8.0, PI * 0.2, PI * 1.5, 10, gold, 4.0)
		draw_arc(Vector2(0, 6), 8.0, -PI * 0.8, PI * 0.5, 10, gold, 4.0)
		draw_line(Vector2(0, -18), Vector2(0, 18), gold, 3.0)
		draw_set_transform_matrix(_tv_xf)
	# Cejas furiosas / Furious brows
	draw_line(c + Vector2(-74, -58), c + Vector2(-22, -44), Color(RED, a), 6.0)
	draw_line(c + Vector2(74, -58), c + Vector2(22, -44), Color(RED, a), 6.0)
	# Sonrisa enorme con dientes (se abre al reírse) / Huge toothy grin (opens wider when laughing)
	var open := 18.0 + (16.0 + sin(_t * 30.0) * 6.0 if _laugh > 0.0 else sin(_t * 2.0) * 3.0)
	var mouth := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		mouth.append(c + Vector2(lerpf(-80, 80, u), 16 + sin(u * PI) * 10.0))
	for i in range(12, -1, -1):
		var u := i / 12.0
		mouth.append(c + Vector2(lerpf(-70, 70, u), 22 + sin(u * PI) * (10.0 + open)))
	draw_colored_polygon(mouth, Color(RED, a))
	for i in 9:
		var x := lerpf(-66, 66, i / 8.0)
		var y := 16 + sin((x + 80) / 160.0 * PI) * 10.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(x - 7, y), c + Vector2(x + 7, y), c + Vector2(x, y + 12)]), Color("f4f1fa", a))


## Tira de anuncios muy rápida en la barriga / Very fast advert strip on the belly
func _strip(screen: Rect2, a: float) -> void:
	var tex := Sprites.tex("ad_strip")
	var r: Rect2 = SpriteRects.RECTS["ad_strip"]
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var u := fmod(_t * (120.0 if _delirium else 60.0), 300.0 - 50.0)
	var src := Rect2(u / r.size.x * tw, 0, 50.0 / r.size.x * tw, th)
	draw_texture_rect_region(tex, screen, src, Color(1, 0.6, 0.6, a))


func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts


func _draw_statuses(bob: float, a: float) -> void:
	super._draw_statuses(bob - ALT - 60.0, a)


## Pop-up de anuncio: una ventanita que va a por Kroker y estalla si no la cierras a tiempo
## Advert pop-up: a little window that goes after Kroker and bursts unless you close it in time
class PopupAd extends Enemy:
	const LIFE := 5.0
	const BLAST := 90.0
	const DAMAGE := 3.5
	var _life := LIFE
	var _word := 0

	func _init() -> void:
		max_hp = 9.0
		hp = max_hp
		radius = 26.0
		speed = 95.0
		mass = 0.6
		aim_height = 30.0
		contact_damage = 0.0
		shards = 0
		drop_mult = 0.0

	func _ready() -> void:
		super._ready()
		# Sin el aumento de vida de los últimos sueños: son de usar y tirar / Without the late-dream health boost: they're disposable
		max_hp = 9.0 * GameState.enemy_hp_mult()
		hp = max_hp
		_word = randi() % 4

	func can_fall() -> bool:
		return false

	func is_dangerous() -> bool:
		return false

	func _act(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			# Estalla / It bursts
			run.fx.ring(global_position + Vector2(0, -30), BLAST, Color("e0303a"), 0.4, 1.6)
			run.fx.dissipate(global_position + Vector2(0, -30), Color("ffd0d0"))
			Audio.play("crack", -8.0, 0.2)
			if run.player.global_position.distance_to(global_position) < BLAST:
				run.player.take_damage(DAMAGE * GameState.enemy_dmg_mult(), self)
			die(false)

	func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
		var mod := Sprites.flash_color(_flash * 0.6, a) * tint
		var c := offset + Vector2(0, -36 + sin(_t * 4.0) * 3.0)
		var urgent := _life < 1.5 and fmod(_t, 0.2) < 0.1
		var r := Rect2(c - Vector2(34, 24), Vector2(68, 48))
		draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.35 * a))
		draw_rect(r.grow(2), Color("1a0a10", a))
		draw_rect(r, Color("f4f1fa", a) * mod)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 12)), Color("e0303a" if not urgent else "ffffff", a))
		draw_rect(Rect2(r.end.x - 12, r.position.y + 1, 10, 10), Color("1a0a10", a))
		draw_line(Vector2(r.end.x - 10, r.position.y + 3), Vector2(r.end.x - 4, r.position.y + 9), Color.WHITE, 2.0)
		draw_line(Vector2(r.end.x - 4, r.position.y + 3), Vector2(r.end.x - 10, r.position.y + 9), Color.WHITE, 2.0)
		var font := ThemeDB.fallback_font
		var word: String = ["SALE!", "WIN!", "BUY!", "50%"][_word]
		draw_string(font, Vector2(r.position.x, c.y + 12), word, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Color("e0303a", a))
		# Cuenta atrás / Countdown
		draw_rect(Rect2(r.position + Vector2(4, r.size.y - 6), Vector2((r.size.x - 8) * _life / LIFE, 3)), Color("e0303a", a))
