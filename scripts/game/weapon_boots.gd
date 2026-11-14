class_name WeaponBoots
extends Weapon
## Botas steampunk: Kroker las lleva en los pies y las maneja con un mando pequeño en la mano.
## Ataque básico: patadas propulsadas por los motores, en combo de tres: derecha, izquierda y un
## giro que golpea a todo lo que hay alrededor y devuelve los proyectiles enemigos.
## Dash: espacio (R1 en el mando), hacia donde se mueve. Si arrolla a un
## enemigo le hace mucho daño y lo empuja lejos. Tiene su propia recarga (segundo anillo).
## (+10 % de velocidad y +1 de defensa en Kroker)
## Steampunk boots: Kroker wears them on his feet and drives them with a little remote in his hand.
## Basic attack: kicks powered by the engines, in a three-hit combo: right, left and a spin that
## hits everything around and sends enemy projectiles back.
## Dash: space (R1 on the gamepad), in the direction he's moving. If it ploughs into an
## enemy it deals a lot of damage and knocks it far away. It has its own cooldown (second ring).
## (+10% speed and +1 defence on Kroker)
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — Chilena: el pateado sale volando y golpea a "chain" enemigos más.
##  Stolk  — Puntera de acero: +"pct" % de daño.
##  Silly  — Firmware pirata: −"pct" % de recarga del dash y el dash congela "secs" s.
##  Doc    — vida máxima a cambio de +"pct" % de recarga de las patadas.

const RANGE := 118.0
const KICK_DAMAGE := 9.0
const KICK_KNOCK := 230.0
const SPIN_DAMAGE := 5.0        # el giro hace poco daño... / the spin does little damage...
const SPIN_RADIUS := 100.0      # ...es cuerpo a cuerpo, como las patadas... / ...it's melee, like the kicks...
const SPIN_KNOCK := 600.0       # ...pero empuja mucho / ...but it shoves hard
const SPIN_TIME := 0.42         # lo que tarda la vuelta entera / how long the full turn takes
const COOLDOWN := 0.5
const COMBO_RESET := 1.4       # sin atacar tanto tiempo, el combo vuelve a empezar / this long without attacking resets the combo
const DASH_CD := 2.4
const DASH_TIME := 0.17
const DASH_DIST := 240.0
const DASH_DAMAGE := 24.0
const DASH_KNOCK := 650.0
const DASH_HIT_R := 46.0
const BRASS := Color("e0b860")

## Animación para KrokerArt: patada de cada pierna, giro y llamas de los motores (1 → 0)
## Animation for KrokerArt: each leg's kick, the spin and the engine flames (1 → 0)
var kick_l := 0.0
var kick_r := 0.0
var spin := 0.0
var thrust := 0.0
var combo := 0
var _since := 9.0
var _clock := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.ZERO
var _dash_hit: Array = []
var _trail := 0.0


func _init() -> void:
	cooldown = COOLDOWN


func _physics_process(delta: float) -> void:
	super(delta)
	_clock += delta
	_since += delta
	if _since > COMBO_RESET:
		combo = 0
	kick_l = maxf(0.0, kick_l - delta * 4.0)
	kick_r = maxf(0.0, kick_r - delta * 4.0)
	spin = maxf(0.0, spin - delta / SPIN_TIME)
	if spin > 0.0:
		kick_r = 1.0   # la pierna estirada barre en círculo / the stretched-out leg sweeps round
	thrust = maxf(0.0, thrust - delta * 3.0)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	if not run.running or not player.alive:
		return
	_check_taps()
	if player.dashing():
		_dash_contact()
		_trail -= delta
		if _trail <= 0.0:
			_trail = 0.03
			run.fx.dissipate(player.global_position + Vector2(randf_range(-8, 8), -6), Color("d8d0e8"))


## Espacio (o R1 en el mando): dash hacia donde se mueve, o hacia donde mira si está quieto
## Space (or R1 on the gamepad): dash where he's moving, or where he faces if standing still
func _check_taps() -> void:
	if not Input.is_action_just_pressed("dash"):
		return
	if _dash_cd > 0.0 or player.weapon_stunk(self) or player.root_t > 0.0:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() < 0.2:
		dir = Vector2(player._facing, 0)
	_start_dash(dir.normalized())


func _start_dash(dir: Vector2) -> void:
	_dash_dir = dir
	_dash_hit.clear()
	_dash_cd = DASH_CD * (1.0 - uv("silly", "pct") / 100.0)
	player.dash(dir * DASH_DIST / DASH_TIME, DASH_TIME)
	thrust = 1.0
	kick_r = 0.6
	Audio.play("dash", -4.0, 0.1)
	run.fx.ring(player.global_position + Vector2(0, -8), 26.0, BRASS, 0.3, 2.0)


## Lo que arrolla el dash / What the dash ploughs through
func _dash_contact() -> void:
	var c := player.global_position + Vector2(0, -24)
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable() or _dash_hit.has(e) or c.distance_to(e.aim_point()) > DASH_HIT_R + e.reach_bonus():
			continue
		_dash_hit.append(e)
		var dmg := DASH_DAMAGE * _dmg_mult()
		_bounce(e, dmg)
		deal(e, dmg, _dash_dir * DASH_KNOCK)
		if lv("silly") > 0:
			e.glitch(uv("silly", "secs"))
		run.shake(4.0)
		Audio.play("kick", -2.0, 0.1)
		run.fx.ring(e.aim_point(), 30.0, BRASS, 0.3, 3.0)


func _dmg_mult() -> float:
	return 1.0 + uv("stolk", "pct") / 100.0


## Svinho: el golpeado sale volando contra otros / Svinho: the one hit flies into others
func _bounce(e: Node2D, dmg: float) -> void:
	if lv("svinho") > 0:
		e.start_bounce(dmg * player.damage_mult * uv("svinho", "pct") / 100.0, int(uv("svinho", "chain")) - 1)


func attack() -> bool:
	cooldown = COOLDOWN * (1.0 + uv("doc", "pct") / 100.0)
	if combo >= 2:
		if nearest(SPIN_RADIUS * range_mult()) == null:
			return false
		_spin_attack()
		return true
	var target := nearest(RANGE * range_mult())
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	if absf(dir.x) > 0.2:
		player.set_facing(signf(dir.x))
	var dmg := KICK_DAMAGE * _dmg_mult()
	var knock := KICK_KNOCK + (380.0 if lv("svinho") > 0 else 0.0)
	_bounce(target, dmg)
	deal(target, dmg, dir * knock)
	# Primero la derecha y luego la izquierda / First the right, then the left
	if combo == 0:
		kick_r = 1.0
	else:
		kick_l = 1.0
	thrust = 1.0
	combo += 1
	_since = 0.0
	swung()
	Audio.play("kick", -6.0, 0.12)
	run.fx.swing(origin() + Vector2(0, 26), 70.0, dir.angle(), 0.8, BRASS, 5.0)
	return true


## Tercer golpe: gira sobre sí mismo, golpea a todo alrededor y devuelve los proyectiles
## Third hit: spins round, hits everything around and sends projectiles back
func _spin_attack() -> void:
	combo = 0
	_since = 0.0
	spin = 1.0
	thrust = 1.0
	kick_r = 1.0
	var r := SPIN_RADIUS * range_mult()
	var dmg := SPIN_DAMAGE * _dmg_mult()
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable():
			continue
		var to := _body(e) - origin()
		if to.length() < r:
			deal(e, dmg, to.normalized() * SPIN_KNOCK)
	for s: Node in run.world.get_children():
		if s is EnemyShot and not (s as EnemyShot).reflected and (s as EnemyShot).global_position.distance_to(origin()) < r + 20.0:
			(s as EnemyShot).reflect(nearest(600.0))
	_timer = cooldown * 1.3
	swung()
	Audio.play("swing", -3.0, 0.1)
	Audio.play("kick", -8.0, 0.15)


func charge_bars() -> Array:
	var bars := super.charge_bars()
	bars.append([1.0 - clampf(_dash_cd / maxf(DASH_CD * (1.0 - uv("silly", "pct") / 100.0), 0.01), 0.0, 1.0), BRASS])
	return bars
