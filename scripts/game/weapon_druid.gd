class_name WeaponDruid
extends Weapon
## Collar de druida (cuerpo a cuerpo): un collar de cuero con un colmillo, una garra y una pluma.
## Cada 8 s Kroker cambia de forma y a su lado aparece el espíritu de ese animal, que es el que
## ataca:
##  Oso      — zarpazo en abanico a todos los de delante, con mucho empuje; Kroker gana defensa.
##  Pantera  — garras rapidísimas a uno solo, con un 25 % de zarpazo doble; Kroker corre más.
##  Buitre   — picotazos desde lejos al que menos vida le queda; remata a los que están por debajo
##             del 15 % (no a los jefes) y cada remate cura un poco.
## Se desbloquea al llegar a nivel 20 en una partida (en WoW, el druida aprende la forma felina al 20).
## Druid collar (melee): a leather collar with a fang, a claw and a feather. Every 8 s Kroker
## shifts form and that animal's spirit appears beside him and does the attacking:
##  Bear     — a fanned swipe at everyone in front, with a big shove; Kroker gains defence.
##  Panther  — lightning-fast claws on a single target, 25% chance of a double swipe; Kroker runs faster.
##  Vulture  — pecks from afar at whoever has the least health left; finishes off those under 15%
##             (not bosses) and each finish heals a little.
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
const BEAR_ARMOR := 3.0
# Pantera / Panther
const CAT_RANGE := 115.0
const CAT_CD := 0.42
const CAT_DMG := 6.5
const CAT_CRIT := 25.0
const CAT_SPEED := 1.25
# Buitre / Vulture
const VULTURE_RANGE := 300.0
const VULTURE_CD := 0.75
const VULTURE_DMG := 5.0
const EXECUTE := 0.15
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
	if run.running and player.alive:
		_form_t -= delta
		if _form_t <= 0.0:
			_idx = (_idx + 1) % FORMS.size()
			_set_form(FORMS[_idx], true)
	# El espíritu sigue a Kroker por detrás; el buitre vuela en círculos por encima
	# The spirit follows behind Kroker; the vulture circles overhead
	var home := Vector2(-58.0 * player._facing, 4.0)
	if form == "vulture":
		home = Vector2(cos(_t * 1.4) * 46.0, -118.0 + sin(_t * 2.8) * 8.0)
	_spirit = _spirit.lerp(home, minf(1.0, delta * 6.0))
	queue_redraw()


func _set_form(f: String, announce: bool) -> void:
	form = f
	_form_t = FORM_TIME
	cooldown = {"bear": BEAR_CD, "panther": CAT_CD, "vulture": VULTURE_CD}[f]
	_timer = minf(_timer, 0.3)
	player.form_speed = CAT_SPEED if f == "panther" else 1.0
	player.form_armor = BEAR_ARMOR if f == "bear" else 0.0
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
	# Silly: el cambio de forma congela a los de alrededor / Silly: shifting freezes those around
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		for e: Node in run.enemies.get_children():
			if e is Enemy and (e as Enemy).is_targetable() and (e as Enemy).global_position.distance_to(player.global_position) < SILLY_RADIUS:
				(e as Enemy).glitch(uv("silly", "secs"))


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


## Pantera: garras rápidas a uno / Panther: quick claws on one
func _panther() -> bool:
	var target := nearest(CAT_RANGE * range_mult())
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	var crit := randf() * 100.0 < CAT_CRIT
	deal(target, CAT_DMG * _mult() * (2.0 if crit else 1.0), dir * 60.0)
	if crit:
		run.fx.text(_body(target) + Vector2(0, -40), tr("DRUID_CRIT"), COLORS["panther"], 18)
	_bounce(target, CAT_DMG)
	_strike(target, dir, 0.7)
	for k in 3:
		run.fx.swing(_body(target), 26.0 + k * 4.0, dir.angle() + 1.2 + k * 0.25, 0.5, COLORS["panther"], 2.0)
	Audio.play("claw", -8.0, 0.12)
	return true


## Buitre: picotazo al más débil, remata a los que casi no tienen vida
## Vulture: pecks the weakest, finishes off those almost out of health
func _vulture() -> bool:
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
func _strike(target: Node2D, dir: Vector2, power: float) -> void:
	swung()
	_lunge = power
	_lunge_to = (target.global_position - player.global_position).limit_length(90.0)
	if absf(dir.x) > 0.1:
		player._facing = signf(dir.x)


func charge_bars() -> Array:
	var bars := super.charge_bars()
	bars.append([1.0 - clampf(_form_t / FORM_TIME, 0.0, 1.0), COLORS[form]])
	return bars


func _draw() -> void:
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
