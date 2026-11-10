class_name Trinkets
extends Node2D
## Los cachivaches del kiosco de Charo: objetos que no suben estadísticas, sino que hacen algo
## propio durante la partida. Cuantos más compras del mismo, más fuerte el efecto.
## - Patito de goma: para el primer golpe de cada sueño.
## - Petardos: cuando te dan, estallan a tu alrededor y empujan a los enemigos.
## - Hucha: al acabar cada sueño, da intereses de la Realidad ahorrada.
## - Globo de agua: cada pocos segundos cae sobre un enemigo y ralentiza a los de alrededor.
## - Silbato: cada enemigo que cae por un agujero te cura.
## - Muñeco vudú: quien te pega recibe el triple.
## - Imán de nevera: los trozos de estrella vienen desde más lejos.
## - Cerillas: los que mueres a veces queman a los de al lado.
## - Despertador: con poca vida suena y congela a los de alrededor (una vez por sueño).
## - Piñata: los élites siempre sueltan un objeto y más Realidad.
## - Bola de nieve: al subir de nivel congela a toda la pantalla.
## - Caja de música: cada cierto tiempo duerme a los de alrededor, que reciben más daño.
## Charo's kiosk knick-knacks: items that don't raise stats but do something of their own during the
## run. The more of one you buy, the stronger it gets. Rubber duck (blocks the first hit of each
## dream), firecrackers (burst around you when you're hit, pushing enemies away), piggy bank
## (interest on saved Reality after each dream), water balloon (drops on an enemy every few seconds,
## slowing those around), whistle (each enemy that falls down a hole heals you), voodoo doll (whoever
## hits you takes triple), fridge magnet (star shards come from further away), matches (kills
## sometimes set their neighbours on fire), alarm clock (at low health it rings and freezes those
## around, once per dream), piñata (elites always drop an item and more Reality), snow globe
## (levelling up freezes the whole screen) and music box (every so often puts nearby enemies to
## sleep, and they take more damage).

## Solo se compran una vez / Only bought once
const UNIQUE := ["rubber_duck", "alarm_clock"]

const FIRECRACKER_DMG := 3.0
const FIRECRACKER_RADIUS := 170.0
const PIGGY_EVERY := 8          # 1 de interés por cada 8 ahorrados (6 con dos huchas, 5 con tres...) / 1 interest per 8 saved (6 with two, 5 with three...)
const PIGGY_MAX := 4            # como mucho, en total / at most, in total
const BALLOON_EVERY := 5.0
const BALLOON_DMG := 4.0
const BALLOON_RADIUS := 120.0
const BALLOON_SLOW := 2.0
const WHISTLE_HEAL := 2.0
const VOODOO_MULT := 3.0
const MATCHES_CHANCE := 20.0
const MATCHES_RADIUS := 110.0
const ALARM_HP := 0.35
const ALARM_RADIUS := 300.0
const ALARM_FREEZE := 2.5
const PINATA_REALITY := 2
const GLOBE_FREEZE := 2.0
const MUSIC_EVERY := 14.0
const MUSIC_RADIUS := 320.0
const MUSIC_SLEEP := 3.0
const MUSIC_VULN := 1.5

var run: Node
var _balloon_t := BALLOON_EVERY
var _music_t := MUSIC_EVERY * 0.5
var _alarms_left := 0
var _t := 0.0
## Globos cayendo: [posición, altura] / Falling balloons: [position, height]
var _balloons: Array = []
## Notas de la caja de música: [posición, vida] / Music-box notes: [position, life]
var _notes: Array = []


static func count(id: String) -> int:
	return int(GameState.bought.get(id, 0))


func setup(r: Node) -> void:
	run = r
	z_index = 6


## Al empezar cada sueño / At the start of each dream
func on_dream_start() -> void:
	# El patito y el despertador no se acumulan: uno basta (el kiosco ya no los vuelve a sacar)
	# The duck and the alarm clock don't stack: one is enough (the kiosk doesn't offer them again)
	if count("rubber_duck") > 0:
		run.player.shield_charges = maxi(run.player.shield_charges, 1)
	_alarms_left = 1 if count("alarm_clock") > 0 else 0
	_balloon_t = BALLOON_EVERY
	_music_t = MUSIC_EVERY * 0.5


## Al acabar cada sueño: la hucha da intereses / At the end of each dream: the piggy bank pays interest
func on_dream_end() -> void:
	var pig := count("piggy_bank")
	if pig <= 0 or not GameState.reality_on():
		return
	var every := maxi(4, PIGGY_EVERY - 2 * (pig - 1) + (1 if pig >= 3 else 0))
	var n := mini(GameState.reality / every, PIGGY_MAX)
	if n > 0:
		run.gain_reality(n, run.player.global_position + Vector2(0, -60))
		Audio.play("chime", -8.0)


## Le han hecho daño a Kroker / Kroker took damage
func on_hurt(dmg: float, source: Node2D) -> void:
	var p: Vector2 = run.player.global_position
	var fire := count("firecrackers")
	if fire > 0:
		Audio.play("burst", -6.0, 0.1)
		run.fx.ring(p + Vector2(0, -30), FIRECRACKER_RADIUS * 0.55, Color("ffb14a"), 0.35, 2.0)
		run.fx.ring(p + Vector2(0, -30), FIRECRACKER_RADIUS * 0.3, Color("ff5d6a"), 0.3, 2.6)
		for k in 5:
			run.fx.dissipate(p + Vector2.from_angle(k * TAU / 5.0) * 60.0 + Vector2(0, -30), Color("ffd27a"))
		for e in _enemies_near(p, FIRECRACKER_RADIUS):
			var d := (e.global_position - p).normalized()
			e.hit(FIRECRACKER_DMG * fire * run.player.damage_mult, d * 900.0)
	var voo := count("voodoo")
	if voo > 0 and source is Enemy and is_instance_valid(source) and (source as Enemy).is_targetable():
		var e := source as Enemy
		# A los jefes solo les devuelve el mismo daño / Bosses only get the same damage back
		var mult := 1.0 if e.is_boss() else VOODOO_MULT * voo
		e.hit(dmg * mult)
		run.fx.text(e.global_position + Vector2(0, -e.aim_height * 2.0 - 50), "x%d" % roundi(mult), Color("c86ad0"), 24)
		Audio.play("pin", -8.0, 0.1)
	# Despertador / Alarm clock
	if _alarms_left > 0 and run.player.hp > 0.0 and run.player.hp <= run.player.max_hp * ALARM_HP:
		_alarms_left -= 1
		Audio.play("bell", -4.0)
		run.shake(4.0)
		run.fx.text(p + Vector2(0, -140), tr("TRINKET_ALARM"), UITheme.GOLD, 26)
		run.fx.ring(p + Vector2(0, -30), ALARM_RADIUS * 0.5, Color("ffe08a"), 0.6, 2.0)
		_freeze(_enemies_near(p, ALARM_RADIUS), ALARM_FREEZE)
		run.player._invuln = maxf(run.player._invuln, 1.0)


## Ha muerto un enemigo (contado) / An enemy died (counted)
func on_kill(e: Enemy) -> void:
	var m := count("matches")
	# Quien muere ardiendo no prende a otros (si no, el fuego barría la pantalla en cadena)
	# Whoever dies burning doesn't light others (otherwise the fire swept the screen in a chain)
	if m > 0 and e.burn_t <= 0.0 and randf() * 100.0 < minf(80.0, MATCHES_CHANCE * m):
		var p := e.global_position
		run.fx.ring(p + Vector2(0, -20), MATCHES_RADIUS * 0.5, Color("ff9a3a"), 0.35, 2.0)
		for o in _enemies_near(p, MATCHES_RADIUS):
			if o != e:
				o.burn(1.5 * run.player.damage_mult, 3.0, 15.0)
	var pin := count("pinata")
	if pin > 0 and e.elite:
		run.spawn_pickup(run.clamp_to_arena(e.global_position + Vector2(randf_range(-30, 30), 14), 20.0))
		run.gain_reality(PINATA_REALITY * pin, e.global_position + Vector2(0, -40))
		for k in 6:
			run.fx.dissipate(e.global_position + Vector2(randf_range(-40, 40), randf_range(-60, 0)), [Color("ff6fb5"), Color("ffd84a"), Color("5fc8ff")][k % 3])


## Un enemigo ha caído por un agujero / An enemy fell down a hole
func on_fall(_e: Enemy) -> void:
	var w := count("whistle")
	if w > 0:
		run.player.heal(WHISTLE_HEAL * w)
		Audio.play("whistle", -10.0, 0.1)


## Ha subido de nivel / Levelled up
func on_level_up() -> void:
	var g := count("snow_globe")
	if g <= 0:
		return
	var v: Rect2 = run.view_rect()
	var list: Array[Enemy] = []
	for o: Node in run.enemies.get_children():
		if o is Enemy and (o as Enemy).is_targetable() and v.has_point((o as Enemy).global_position):
			list.append(o)
	_freeze(list, GLOBE_FREEZE + 0.5 * (g - 1))
	run.flash_screen(Color(0.8, 0.92, 1.0, 0.35), 0.3)
	Audio.play("freeze", -8.0)


## Distancia a la que vienen los trozos de estrella / How far star shards come from
static func magnet_mult() -> float:
	return 1.0 + count("magnet")


func _physics_process(delta: float) -> void:
	_t += delta
	_update_fx(delta)
	if run == null or not run.running or not run.player.alive:
		return
	var bal := count("water_balloon")
	if bal > 0:
		_balloon_t -= delta
		if _balloon_t <= 0.0:
			_balloon_t = BALLOON_EVERY / (1.0 + 0.3 * (bal - 1))
			var target := _nearest(run.player.global_position, 650.0)
			if target != null:
				_balloons.append([target.global_position, 260.0, bal])
	var mus := count("music_box")
	if mus > 0:
		_music_t -= delta
		if _music_t <= 0.0:
			_music_t = MUSIC_EVERY / (1.0 + 0.15 * (mus - 1))
			_lullaby(mus)


func _update_fx(delta: float) -> void:
	for b: Array in _balloons.duplicate():
		b[1] = float(b[1]) - 700.0 * delta
		if float(b[1]) <= 0.0:
			_balloons.erase(b)
			_splash(b[0], int(b[2]))
	for n: Array in _notes.duplicate():
		n[1] = float(n[1]) - delta
		n[0] = (n[0] as Vector2) + Vector2(sin(_t * 4.0 + float(n[2])) * 20.0, -40.0) * delta
		if float(n[1]) <= 0.0:
			_notes.erase(n)
	queue_redraw()


func _splash(at: Vector2, n: int) -> void:
	Audio.play("splash", -6.0, 0.15)
	run.fx.ring(at + Vector2(0, -10), BALLOON_RADIUS * 0.5, Color("7fd0ff"), 0.4, 2.0)
	for k in 4:
		run.fx.dissipate(at + Vector2.from_angle(k * TAU / 4.0) * 30.0, Color("bfe8ff"))
	for e in _enemies_near(at, BALLOON_RADIUS):
		e.hit(BALLOON_DMG * n * run.player.damage_mult)
		e.slow_t = maxf(e.slow_t, BALLOON_SLOW)


func _lullaby(n: int) -> void:
	var p: Vector2 = run.player.global_position
	Audio.play("music_box", -6.0)
	run.fx.ring(p + Vector2(0, -30), MUSIC_RADIUS * 0.5, Color("c9b4ff"), 0.9, 2.0)
	for k in 6:
		_notes.append([p + Vector2(randf_range(-60, 60), randf_range(-90, -40)), 1.4, randf() * TAU])
	for e in _enemies_near(p, MUSIC_RADIUS):
		e.stun_t = maxf(e.stun_t, MUSIC_SLEEP)
		e.vuln_mult = maxf(e.vuln_mult if e.vuln_t > 0.0 else 1.0, MUSIC_VULN + 0.1 * (n - 1))
		e.vuln_t = maxf(e.vuln_t, MUSIC_SLEEP)
		run.fx.text(e.global_position + Vector2(0, -e.aim_height * 2.0 - 40), "z", Color("c9b4ff"), 22)


func _freeze(list: Array, secs: float) -> void:
	for e: Enemy in list:
		e.stun_t = maxf(e.stun_t, secs)
		e.slow_t = maxf(e.slow_t, secs + 1.0)
		run.fx.ring(e.aim_point(), 20.0, Color("bfe8ff"), 0.4, 1.8)


func _enemies_near(p: Vector2, r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for o: Node in run.enemies.get_children():
		if o is Enemy and (o as Enemy).is_targetable() and (o as Enemy).global_position.distance_to(p) < r:
			out.append(o)
	return out


func _nearest(p: Vector2, r: float) -> Enemy:
	var best: Enemy = null
	var best_d := r
	for o: Node in run.enemies.get_children():
		if o is Enemy and (o as Enemy).is_targetable() and (o as Enemy).state == Enemy.State.ALIVE:
			var d := (o as Enemy).global_position.distance_to(p)
			if d < best_d:
				best_d = d
				best = o
	return best


func _draw() -> void:
	# Globos de agua cayendo, con su sombra / Falling water balloons, with their shadow
	for b: Array in _balloons:
		var at: Vector2 = b[0]
		var h: float = b[1]
		var k := 1.0 - h / 260.0
		draw_circle(at, 6.0 + 10.0 * k, Color(0, 0, 0, 0.25 * k))
		var c := at + Vector2(0, -h)
		draw_circle(c, 11.0, Color("4fa8e8"))
		draw_circle(c + Vector2(-3, -4), 4.0, Color("bfe8ff"))
		draw_line(c + Vector2(0, 11), c + Vector2(0, 16), Color("2a6fae"), 3.0)
	# Notas de la nana / Lullaby notes
	for n: Array in _notes:
		var p: Vector2 = n[0]
		var a := clampf(float(n[1]) / 0.6, 0.0, 1.0)
		var col := Color("c9b4ff", a)
		draw_circle(p, 5.0, col)
		draw_line(p + Vector2(4, 0), p + Vector2(4, -16), col, 2.0)
		draw_line(p + Vector2(4, -16), p + Vector2(11, -12), col, 2.0)
