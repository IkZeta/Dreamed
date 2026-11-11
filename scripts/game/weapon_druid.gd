class_name WeaponDruid
extends Weapon
## Collar de druida (cuerpo a cuerpo): un collar de cuero con un colmillo, una garra y una pluma.
## Cada 8 s Kroker cambia de forma y a su lado aparece el espíritu de ese animal, que es el que
## ataca. Cada forma juega distinto:
##  Oso (tanque) — zarpazo en abanico con mucho empuje, +2 de defensa y algo más lento. Al
##     transformarse RUGE: aturde y aparta a los de alrededor. Su PELAJE para un golpe entero
##     (se recarga en 7 s) y, cuando le dan, el oso devuelve el zarpazo alrededor (REPRESALIA).
##  Pantera (pícara) — garras rapidísimas con 25 % de crítico y +25 % de velocidad. Al
##     transformarse, Kroker entra en SIGILO 1,5 s: los enemigos (no los jefes) le pierden la
##     pista y ni le tocan ni disparan; se rompe si le dan. El primer zarpazo es una EMBOSCADA
##     (×3 y sangrado), y cada baja prepara otra (como mucho una vez cada 5 s). Si no hay nadie
##     a mano, la pantera SALTA sobre uno que esté más lejos.
##  Buitre (vuelo) — picotazos de lejos al que menos vida le queda y REMATA a los que bajan del
##     15 % (curando). Kroker LEVITA: pasa por encima de muebles, escombros y charcos, y los sismos
##     no le pillan. Cada 8 s hace RAPIÑA: agarra a un enemigo ligero (no élite ni jefe) y lo suelta
##     encima del agujero más cercano.
## Se desbloquea al llegar a nivel 20 en una partida (en WoW, el druida aprende la forma felina al 20).
## Druid collar (melee): a leather collar with a fang, a claw and a feather. Every 8 s Kroker
## shifts form and that animal's spirit appears beside him and does the attacking. Each form
## plays differently:
##  Bear (tank) — a fanned swipe with a big shove, +2 defence and a bit slower. On shifting it
##     ROARS: stuns and pushes away those around. Its FUR stops one whole hit (recharges in 7 s)
##     and, when he gets hit, the bear swipes back all around (RETALIATION).
##  Panther (rogue) — lightning-fast claws with a 25% crit and +25% speed. On shifting, Kroker
##     goes into STEALTH for 1.5 s: enemies (not bosses) lose track of him and neither touch him
##     nor shoot; getting hit breaks it. The first swipe is an AMBUSH (×3 and bleeding), and each
##     kill readies another (at most once every 5 s). With nobody at hand, the panther LEAPS on
##     someone further off.
##  Vulture (flight) — pecks from afar at whoever has the least health left and FINISHES OFF those
##     under 15% (healing). Kroker HOVERS: over furniture, rubble and puddles, and quakes don't
##     catch him. Every 8 s it SNATCHES a light enemy (not elites or bosses) and drops it over the
##     nearest hole.
## Unlocked by reaching level 20 in a run (in WoW, druids learn Cat Form at level 20).
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — el golpe salta a "extra" enemigos más con "pct" % del daño.
##  Stolk  — +"pct" % de daño en todas las formas.
##  Silly  — al cambiar de forma, "chance" % de congelar "secs" s a los de alrededor.
##  Doc    — vida máxima a cambio de −"pct" % de daño.

const FORMS: Array[String] = ["bear", "panther", "vulture"]
const FORM_TIME := 8.0
const COLORS := {"bear": Color("c98a52"), "panther": Color("9a7cff"), "vulture": Color("e8a0a0")}
# Oso / Bear
const BEAR_RANGE := 130.0
const BEAR_CD := 1.15
const BEAR_DMG := 9.0
const BEAR_KNOCK := 320.0
const BEAR_ARMOR := 2.0
const BEAR_SPEED := 0.88
const ROAR_RADIUS := 230.0
const ROAR_STUN := 0.6
const ROAR_KNOCK := 340.0
const GUARD_TIME := 7.0          # recarga del pelaje / fur recharge
const RETALIATE_RADIUS := 150.0
const RETALIATE_MULT := 1.5
# Pantera / Panther
const CAT_RANGE := 115.0
const CAT_CD := 0.42
const CAT_DMG := 6.5
const CAT_CRIT := 25.0
const CAT_SPEED := 1.25
const STEALTH_SHIFT := 1.5       # sigilo al transformarse / stealth on shifting
const STEALTH_CD := 5.0
const AMBUSH_MULT := 3.0
const AMBUSH_BLEED := Vector2(2.0, 3.0)   # daño por segundo, segundos / damage per second, seconds
const POUNCE_RANGE := 280.0
const POUNCE_CD := 2.5
# Buitre / Vulture
const VULTURE_RANGE := 300.0
const VULTURE_CD := 0.75
const VULTURE_DMG := 5.0
const EXECUTE := 0.15
const SNATCH_CD := 8.0
const SNATCH_RANGE := 340.0      # de Kroker al enemigo / from Kroker to the enemy
const SNATCH_HOLE := 650.0       # del enemigo al agujero / from the enemy to the hole
const SNATCH_MASS := 1.6         # los más pesados no los levanta / it can't lift heavier ones
const ALT := 118.0               # altura de vuelo / flight height
const JUMP_RANGE := 220.0
const SILLY_RADIUS := 240.0

var form := "bear"
var _form_t := FORM_TIME
var _idx := 0
## Espíritu: dónde está (relativo a Kroker), hacia dónde se lanza y cómo de visible está
## Spirit: where it is (relative to Kroker), where it lunges and how visible it is
var _spirit := Vector2(-60, 4)
var _lunge := 0.0
var _lunge_to := Vector2.ZERO
var _alpha := 0.0
var _shift_fx := 0.0
var _t := 0.0
# Oso / Bear
var _guard_t := 0.0              # 0 = pelaje listo / 0 = fur ready
var _guard_fx := 0.0
# Pantera / Panther
var _pounce_t := 0.0
var _stealth_cd := 0.0
var _ambush := false             # el próximo zarpazo es una emboscada / the next swipe is an ambush
# Buitre: rapiña (ir a por él, llevarlo, soltarlo) / Vulture: snatch (go get it, carry it, drop it)
var _snatch_t := 2.0
var _carry: Enemy
var _carry_phase := ""
var _carry_k := 0.0
var _carry_dur := 0.0
var _carry_from := Vector2.ZERO  # en el mundo / in the world
var _carry_to := Vector2.ZERO
var _carry_hole := Vector2.INF
var _bird := Vector2.ZERO        # pájaro en el mundo durante la rapiña / bird in the world during the snatch


func _init() -> void:
	cooldown = BEAR_CD


func _ready() -> void:
	show_behind_parent = true
	_idx = randi() % FORMS.size()
	_set_form(FORMS[_idx], false)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_t += delta
	_lunge = maxf(0.0, _lunge - delta * 4.0)
	_shift_fx = maxf(0.0, _shift_fx - delta * 2.0)
	_alpha = minf(1.0, _alpha + delta * 3.0)
	_guard_fx = maxf(0.0, _guard_fx - delta * 2.5)
	if run.running and player.alive:
		_form_t -= delta
		_stealth_cd = maxf(0.0, _stealth_cd - delta)
		_pounce_t = maxf(0.0, _pounce_t - delta)
		if form == "bear" and _guard_t > 0.0:
			_guard_t = maxf(0.0, _guard_t - delta)
			if _guard_t <= 0.0:
				_guard_fx = 1.0
				Audio.play("pillow", -14.0, 0.1)
		if form == "vulture":
			_update_snatch(delta)
		if _form_t <= 0.0 and _carry_phase == "":
			_idx = (_idx + 1) % FORMS.size()
			_set_form(FORMS[_idx], true)
	# El espíritu sigue a Kroker por detrás; el buitre vuela en círculos por encima
	# The spirit follows behind Kroker; the vulture circles overhead
	var home := Vector2(-58.0 * player._facing, 4.0)
	if form == "vulture":
		home = Vector2(cos(_t * 1.4) * 46.0, -ALT + sin(_t * 2.8) * 8.0)
	# Mientras lleva a alguien, por encima de todo / While carrying someone, above everything
	z_index = 2 if _carry_phase != "" else 0
	if _carry_phase != "":
		_spirit = _bird - player.global_position
	else:
		_spirit = _spirit.lerp(home, minf(1.0, delta * 6.0))
	queue_redraw()


func _set_form(f: String, announce: bool) -> void:
	form = f
	_form_t = FORM_TIME
	cooldown = {"bear": BEAR_CD, "panther": CAT_CD, "vulture": VULTURE_CD}[f]
	_timer = minf(_timer, 0.3)
	player.form_speed = {"bear": BEAR_SPEED, "panther": CAT_SPEED, "vulture": 1.0}[f]
	player.form_armor = BEAR_ARMOR if f == "bear" else 0.0
	player.form_hover = f == "vulture"
	player.stealth_t = 0.0
	_guard_t = 0.0
	_pounce_t = 0.0
	_snatch_t = 2.0
	if not announce:
		return
	_alpha = 0.0
	_shift_fx = 1.0
	var at: Vector2 = player.global_position + Vector2(0, -60)
	run.fx.ring(at, 46.0, COLORS[f], 0.5, 2.6)
	for k in 8:
		run.fx.dissipate(at + Vector2.from_angle(k * TAU / 8.0) * 30.0, [Color("7fc46a"), Color("b8d870"), COLORS[f]][k % 3])
	run.fx.text(player.global_position + Vector2(0, -130), tr("DRUID_FORM_" + f.to_upper()), COLORS[f], 22)
	Audio.play("druid_shift", -8.0, 0.08)
	Progress.tip("druid")
	# Silly: el cambio de forma congela a los de alrededor / Silly: shifting freezes those around
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		for e: Node in run.enemies.get_children():
			if e is Enemy and (e as Enemy).is_targetable() and (e as Enemy).global_position.distance_to(player.global_position) < SILLY_RADIUS:
				(e as Enemy).glitch(uv("silly", "secs"))
	match f:
		"bear": _roar()
		"panther": _hide(STEALTH_SHIFT)
		"vulture":
			run.fx.text(player.global_position + Vector2(0, -175), tr("DRUID_HOVER"), COLORS[f], 16)


func _mult() -> float:
	return (1.0 + uv("stolk", "pct") / 100.0) * (1.0 - uv("doc", "pct") / 100.0)


func attack() -> bool:
	match form:
		"bear": return _bear()
		"panther": return _panther()
	return _vulture()


## Oso: zarpazo en abanico / Bear: fanned swipe
func _bear() -> bool:
	var target := nearest(BEAR_RANGE * range_mult())
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	var r := BEAR_RANGE * range_mult()
	var hit := 0
	for e: Node in run.enemies.get_children():
		if not e is Enemy or not (e as Enemy).is_targetable():
			continue
		var to := _body(e) - origin()
		if to.length() <= r and (to.length() < 30.0 or to.normalized().dot(dir) > 0.35):
			deal(e, BEAR_DMG * _mult(), to.normalized() * BEAR_KNOCK)
			hit += 1
	_bounce(target, BEAR_DMG)
	_strike(target, dir, 1.0)
	run.fx.swing(origin() + dir * 20.0, 84.0, dir.angle(), 1.4, COLORS["bear"], 7.0)
	Audio.play("bear_swipe", -6.0, 0.08)
	return true


## Pantera: garras rápidas a uno; desde el sigilo, emboscada; sin nadie cerca, salta
## Panther: quick claws on one; from stealth, an ambush; with nobody close, it leaps
func _panther() -> bool:
	var target := nearest(CAT_RANGE * range_mult())
	var pounce := false
	if target == null and _pounce_t <= 0.0:
		target = nearest(POUNCE_RANGE * range_mult())
		pounce = target != null
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	var ambush := _ambush
	var crit := ambush or randf() * 100.0 < CAT_CRIT
	var mult := AMBUSH_MULT if ambush else (2.0 if crit else 1.0)
	deal(target, CAT_DMG * _mult() * mult, dir * (160.0 if pounce else 60.0))
	if ambush:
		_ambush = false
		if target is Enemy and (target as Enemy).state != Enemy.State.DYING:
			(target as Enemy).bleed(AMBUSH_BLEED.x, AMBUSH_BLEED.y)
		run.fx.text(_body(target) + Vector2(0, -46), tr("DRUID_AMBUSH"), COLORS["panther"].lightened(0.3), 20)
		run.fx.ring(_body(target), 30.0, COLORS["panther"], 0.35, 2.4)
		run.hit_stop(0.035)
	elif crit:
		run.fx.text(_body(target) + Vector2(0, -40), tr("DRUID_CRIT"), COLORS["panther"], 18)
	# Una baja: prepara otra emboscada (como mucho una vez cada 5 s) / A kill: readies another ambush (at most once every 5 s)
	if target is Enemy and (target as Enemy).state == Enemy.State.DYING and _stealth_cd <= 0.0:
		_stealth_cd = STEALTH_CD
		_ambush = true
	_bounce(target, CAT_DMG)
	_strike(target, dir, 1.0 if pounce else 0.7, 300.0 if pounce else 90.0)
	if pounce:
		_pounce_t = POUNCE_CD
		run.fx.swing(_body(target), 40.0, dir.angle(), 0.9, COLORS["panther"], 4.0)
	for k in 3:
		run.fx.swing(_body(target), 26.0 + k * 4.0, dir.angle() + 1.2 + k * 0.25, 0.5, COLORS["panther"], 2.0)
	Audio.play("claw", -8.0, 0.12)
	return true


## Sigilo: Kroker se funde con las sombras / Stealth: Kroker melts into the shadows
func _hide(secs: float) -> void:
	_stealth_cd = STEALTH_CD
	if player.stealth_t <= 0.0:
		run.fx.text(player.global_position + Vector2(0, -175), tr("DRUID_STEALTH"), COLORS["panther"], 16)
		for k in 6:
			run.fx.dissipate(player.global_position + Vector2(randf_range(-30, 30), randf_range(-90, -10)), Color("2a1f4a"))
		Audio.play("puff", -14.0, 0.15)
	player.stealth_t = maxf(player.stealth_t, secs)
	_ambush = true


## Buitre: picotazo al más débil, remata a los que casi no tienen vida
## Vulture: pecks the weakest, finishes off those almost out of health
func _vulture() -> bool:
	if _carry_phase != "":
		return false
	var r := VULTURE_RANGE * range_mult()
	var best: Enemy = null
	var best_k := 9.0
	for e: Node in run.enemies.get_children():
		if not e is Enemy or not (e as Enemy).is_targetable():
			continue
		var en := e as Enemy
		if _body(en).distance_to(origin()) > r:
			continue
		var k := en.hp / maxf(1.0, en.max_hp) + (1.0 if en.is_boss() else 0.0)
		if k < best_k:
			best_k = k
			best = en
	if best == null:
		return false
	var dir := (_body(best) - origin()).normalized()
	# Dúo Mr. Ad + Pinche: a los que sangran los remata antes y a veces sueltan Realidad Fragmentada
	# Ad + Pinche duo: bleeding ones are finished off sooner and sometimes drop Fragmented Reality
	var duo := GameState.has_duo("ad_pinche") and best.bleed_t > 0.0
	var line := EXECUTE + (GameState.duo_value("ad_pinche", "pct") / 100.0 if duo else 0.0)
	if not best.is_boss() and best.hp / maxf(1.0, best.max_hp) < line:
		var at := _body(best)
		deal(best, best.hp * 3.0 + 5.0, dir * 80.0)
		run.fx.text(at + Vector2(0, -40), tr("DRUID_EXECUTE"), COLORS["vulture"], 18)
		if player.steal_ready():
			player.heal_sustain(1.0)
		if duo and randf() * 100.0 < GameState.duo_value("ad_pinche", "chance"):
			run.gain_reality(1, at)
	else:
		deal(best, VULTURE_DMG * _mult(), dir * 40.0)
	_bounce(best, VULTURE_DMG)
	_strike(best, dir, 0.9)
	run.fx.bolt(PackedVector2Array([player.global_position + _spirit, _body(best)]), COLORS["vulture"])
	Audio.play("peck", -8.0, 0.1)
	return true


## Oso: rugido al transformarse; aturde y aparta a los de alrededor
## Bear: a roar on shifting; stuns and pushes away those around
func _roar() -> void:
	var at: Vector2 = player.global_position
	for e: Node in run.enemies.get_children():
		if not e is Enemy or not (e as Enemy).is_targetable():
			continue
		var en := e as Enemy
		var to := en.global_position - at
		if to.length() > ROAR_RADIUS * range_mult():
			continue
		if not en.is_boss():
			en.stun_t = maxf(en.stun_t, ROAR_STUN)
		en.knock += to.normalized() * ROAR_KNOCK / maxf(1.0, en.mass)
	run.fx.ring(at + Vector2(0, -40), ROAR_RADIUS * range_mult(), COLORS["bear"], 0.5, 3.0)
	run.fx.text(at + Vector2(0, -180), tr("DRUID_ROAR"), COLORS["bear"], 24)
	run.shake(5.0)
	Audio.play("roar", -6.0, 0.06)
	_lunge = 0.6
	_lunge_to = Vector2(player._facing * 30.0, 0.0)


## Oso: el pelaje para el golpe entero si está cargado / Bear: the fur stops the whole hit if it's charged
func try_guard(source: Node2D) -> bool:
	if form != "bear" or _guard_t > 0.0 or not run.running:
		return false
	_guard_t = GUARD_TIME
	_guard_fx = 1.0
	run.fx.ring(player.global_position + Vector2(0, -40), 44.0, COLORS["bear"], 0.4, 3.0)
	run.fx.text(player.global_position + Vector2(0, -175), tr("DRUID_GUARD"), COLORS["bear"].lightened(0.3), 18)
	Audio.play("pillow", -6.0, 0.08)
	_retaliate(source)
	return true


## Le han dado: el oso devuelve el zarpazo / He got hit: the bear swipes back
func on_hurt(source: Node2D) -> void:
	if form == "bear":
		_retaliate(source)


## Represalia: zarpazo alrededor, más fuerte contra quien le ha pegado
## Retaliation: a swipe all around, harder on whoever hit him
func _retaliate(source: Node2D) -> void:
	var at := origin()
	var r := RETALIATE_RADIUS * range_mult()
	var any := false
	for e: Node in run.enemies.get_children():
		if not e is Enemy or not (e as Enemy).is_targetable():
			continue
		var to := _body(e) - at
		if to.length() > r and e != source:
			continue
		var k := RETALIATE_MULT * (1.5 if e == source else 1.0)
		deal(e, BEAR_DMG * _mult() * k, to.normalized() * BEAR_KNOCK)
		any = true
	if any:
		run.fx.swing(at, r * 0.7, 0.0, TAU, COLORS["bear"], 6.0)
		Audio.play("bear_swipe", -5.0, 0.08)
		_lunge = 1.0
		_lunge_to = Vector2(-player._facing * 20.0, -10.0)
	_timer = 0.0


## Buitre: rapiña. Busca uno ligero cerca de un agujero, lo agarra y lo suelta encima
## Vulture: snatch. Finds a light one near a hole, grabs it and drops it over the hole
func _update_snatch(delta: float) -> void:
	if _carry_phase == "":
		_snatch_t -= delta
		if _snatch_t <= 0.0:
			_snatch_t = 0.5      # si no hay nadie, vuelve a mirar enseguida / if nobody fits, looks again soon
			_try_snatch()
		return
	if not is_instance_valid(_carry) or _carry.state != Enemy.State.ALIVE:
		_end_snatch()
		return
	_carry_k += delta / _carry_dur
	var k := minf(1.0, _carry_k)
	var e := k * k * (3.0 - 2.0 * k)
	match _carry_phase:
		"dive":
			var to: Vector2 = _carry.global_position + _carry.head_top() + Vector2(0, 4)
			_bird = _carry_from.lerp(to, e)
			if k >= 1.0:
				_carry_phase = "carry"
				_carry_k = 0.0
				_carry_from = _carry.global_position
				_carry_dur = clampf(_carry_from.distance_to(_carry_to) / 520.0, 0.45, 1.3)
				run.fx.text(_carry_from + Vector2(0, -150), tr("DRUID_SNATCH"), COLORS["vulture"], 18)
				Audio.play("flap", -6.0, 0.1)
		"carry":
			var lift := sin(k * PI) * 50.0 + 20.0 * k
			var ground := _carry_from.lerp(_carry_to, e)
			_carry.global_position = ground + Vector2(0, -lift)
			_carry.stun_t = maxf(_carry.stun_t, 0.2)
			_carry.knock = Vector2.ZERO
			_bird = _carry.global_position + _carry.head_top() + Vector2(0, 4)
			if k >= 1.0:
				_carry.global_position = _carry_to
				_carry._start_fall(_carry_hole)
				_end_snatch()


func _try_snatch() -> void:
	var me: Vector2 = player.global_position
	var best: Enemy = null
	var best_hole := Vector2.INF
	var best_d := INF
	for n: Node in run.enemies.get_children():
		if not n is Enemy:
			continue
		var en := n as Enemy
		if en.state != Enemy.State.ALIVE or en.is_boss() or en.elite or not en.can_fall() or en.mass > SNATCH_MASS \
				or not en.is_targetable() or en.global_position.distance_to(me) > SNATCH_RANGE * range_mult():
			continue
		var hole := _nearest_hole(en.global_position)
		if hole == Vector2.INF:
			continue
		var d := en.global_position.distance_to(hole)
		if d < SNATCH_HOLE and d < best_d:
			best_d = d
			best = en
			best_hole = hole
	if best == null:
		return
	_carry = best
	_carry_hole = best_hole
	_carry_to = best_hole
	_carry_phase = "dive"
	_carry_k = 0.0
	_carry_from = player.global_position + _spirit
	_bird = _carry_from
	_carry_dur = clampf(_carry_from.distance_to(best.global_position) / 900.0, 0.2, 0.5)


func _end_snatch() -> void:
	_carry = null
	_carry_phase = ""
	_snatch_t = SNATCH_CD
	_spirit = _bird - player.global_position


## Agujero del suelo libre más cercano que se vea (también los Bostezos)
## Nearest visible free floor hole (the Yawns too)
func _nearest_hole(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var view: Rect2 = run.view_rect().grow(-20.0)
	var holes: Array = run.room.holes_list()
	for i in run.room.hole_count():
		var rc := Bedroom.rect_world(holes[i])
		var c := rc.get_center()
		if view.has_point(c) and not run.hole_covered(rc) and (best == Vector2.INF or from.distance_to(c) < from.distance_to(best)):
			best = c
	if is_instance_valid(run.yawns):
		for c: Vector2 in run.yawns.open_centers():
			if view.has_point(c) and (best == Vector2.INF or from.distance_to(c) < from.distance_to(best)):
				best = c
	return best


## Svinho: el golpe salta a otros cercanos / Svinho: the hit jumps to others nearby
func _bounce(from_e: Node2D, base: float) -> void:
	if lv("svinho") <= 0:
		return
	var done: Array = [from_e]
	var from: Vector2 = _body(from_e)
	for i in int(uv("svinho", "extra")):
		var next := nearest(JUMP_RANGE * range_mult(), from, done)
		if next == null:
			break
		done.append(next)
		run.fx.bolt(PackedVector2Array([from, _body(next)]), COLORS[form])
		deal(next, base * _mult() * uv("svinho", "pct") / 100.0, Vector2.ZERO, 0.5)
		from = _body(next)


## El espíritu se lanza hacia el objetivo / The spirit lunges at the target
func _strike(target: Node2D, dir: Vector2, power: float, reach := 90.0) -> void:
	swung()
	_lunge = power
	_lunge_to = (target.global_position - player.global_position).limit_length(reach)
	if absf(dir.x) > 0.1:
		player._facing = signf(dir.x)


func charge_bars() -> Array:
	var bars := super.charge_bars()
	bars.append([1.0 - clampf(_form_t / FORM_TIME, 0.0, 1.0), COLORS[form]])
	# La habilidad de la forma: pelaje, salto o rapiña / The form's skill: fur, leap or snatch
	match form:
		"bear": bars.append([1.0 - _guard_t / GUARD_TIME, COLORS["bear"].lightened(0.35)])
		"panther": bars.append([1.0 - _pounce_t / POUNCE_CD, COLORS["panther"].lightened(0.35)])
		"vulture": bars.append([0.0 if _carry_phase != "" else 1.0 - clampf(_snatch_t / SNATCH_CD, 0.0, 1.0), COLORS["vulture"].lightened(0.25)])
	return bars


func _draw() -> void:
	# Pelaje del oso listo: un anillo de pelo a los pies de Kroker / Bear fur ready: a ring of fur at Kroker's feet
	if form == "bear" and _guard_t <= 0.0 and run.running:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			var tuft := 1.0 + 0.08 * sin(a * 9.0 + _t)
			pts.append(Vector2(cos(a) * 46.0, sin(a) * 15.0 - 4.0) * tuft * (1.0 + _guard_fx * 0.4))
		draw_polyline(pts, Color("1a1024", 0.45), 6.0)
		draw_polyline(pts, Color(COLORS["bear"], 0.55 + 0.3 * pulse), 3.0)
	var col: Color = COLORS[form]
	var lunge := sin(_lunge * PI) if _lunge > 0.0 else 0.0
	var at := _spirit.lerp(_lunge_to, lunge * 0.7)
	var face := signf(_lunge_to.x) if _lunge > 0.0 and absf(_lunge_to.x) > 4.0 else player._facing
	var a := _alpha * 0.92
	# Brillo del espíritu / Spirit glow
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(at + Vector2(-60, -80), Vector2(120, 100)), false, Color(col, 0.22 * _alpha))
	if form != "vulture":
		draw_set_transform(at, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 30.0, Color(0.05, 0.02, 0.15, 0.3 * a))
	var tint := Color(1, 1, 1, a).lerp(Color(col.lightened(0.4), a), 0.25 + 0.4 * lunge)
	match form:
		"bear":
			draw_set_transform(at + Vector2(0, -absf(sin(_t * 3.0)) * 2.0), lunge * 0.15 * face, Vector2(face, 1.0) * (0.9 + 0.1 * lunge))
			Sprites.draw(self, "druid_bear", tint)
		"panther":
			var stretch := 1.0 + 0.25 * lunge
			draw_set_transform(at + Vector2(0, -absf(sin(_t * 6.0)) * 1.5), 0.0, Vector2(face * 0.75 * stretch, 0.75 / sqrt(stretch)))
			Sprites.draw(self, "druid_panther", tint)
		_:
			# Ala de atrás, cuerpo y ala de delante, batiendo / Back wing, body and front wing, flapping
			var flap := sin(_t * 9.0) * 0.6
			draw_set_transform(at + Vector2(-4.0 * face, -26.0), (-0.3 - flap) * face, Vector2(face, 1.0) * 0.8)
			Sprites.draw(self, "druid_wing", Color(tint, a * 0.8))
			draw_set_transform(at, 0.0, Vector2(face, 1.0) * 0.8)
			Sprites.draw(self, "druid_vulture", tint)
			draw_set_transform(at + Vector2(2.0 * face, -24.0), (0.2 + flap) * face, Vector2(face, 1.0) * 0.8)
			Sprites.draw(self, "druid_wing", tint)
	draw_set_transform(Vector2.ZERO)
	# Hojas que giran al cambiar de forma / Leaves swirling when shifting form
	if _shift_fx > 0.0:
		for k in 10:
			var ang := k * TAU / 10.0 + (1.0 - _shift_fx) * 5.0
			var p := Vector2(0, -50) + Vector2(cos(ang), sin(ang) * 0.6) * (30.0 + (1.0 - _shift_fx) * 50.0)
			draw_rect(Rect2(p - Vector2(3, 2), Vector2(6, 4)), Color("1a1024", _shift_fx * 0.6))
			draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), Color("7fc46a" if k % 2 else "b8d870", _shift_fx))


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.form_speed = 1.0
		player.form_armor = 0.0
