class_name Puppet
extends Enemy
## Marioneta (Acto 3, desde el Sueño 11; poco común): un muñeco de madera colgado de sus hilos
## que avanza a saltitos. Cada una sale con un brazo distinto:
##  - Cuchilla: se acerca y da un tajo que te hace sangrar.
##  - Barra eléctrica: se acerca, se carga y te da una descarga que te paraliza un momento.
##  - Arcabuz: se queda lejos, apunta despacio y dispara una bala muy fuerte; el retroceso la
##    lanza hacia atrás. Dispara poco.
## Puppet (Act 3, from Dream 11; uncommon): a wooden doll hanging from its strings that hops
## forward. Each one comes with a different arm:
##  - Blade: closes in and slashes, making you bleed.
##  - Shock rod: closes in, charges up and zaps you, paralysing you for a moment.
##  - Arquebus: keeps its distance, aims slowly and fires a very strong bullet; the recoil
##    throws it back. It doesn't fire often.

const ARMS: Array[String] = ["blade", "rod", "gun"]
const MELEE_REACH := 95.0
const BLADE_DAMAGE := 3.0
const BLADE_BLEED := 3.0
const ROD_DAMAGE := 2.0
const ROD_ROOT := 1.2
const GUN_DAMAGE := 6.0
const GUN_SPEED := 760.0
const GUN_RECOIL := 1100.0
const GUN_EVERY := 4.2
const GUN_AIM := 0.9
const KEEP_MIN := 340.0
const KEEP_MAX := 520.0
## Cuánto tarda en preparar cada golpe y cada cuánto puede atacar / Wind-up time and attack interval
const WINDUP := {"blade": 0.35, "rod": 0.55}
const EVERY := {"blade": 1.4, "rod": 2.2}
const SPARK := Color("8fe0ff")

var arm := "blade"
var _atk_cd := 1.0
var _windup := 0.0        # >0 mientras prepara el golpe / while winding up the hit
var _swing := 0.0         # animación del golpe / hit animation
var _aim_dir := Vector2.ZERO
var _aiming := 0.0


func _init() -> void:
	bestiary_id = "puppet"
	max_hp = 30.0
	hp = max_hp
	contact_damage = 2.0
	radius = 22.0
	speed = 105.0
	mass = 0.9
	aim_height = 50.0
	shards = 3
	arm = ARMS[randi() % ARMS.size()]
	if arm == "gun":
		speed = 80.0
		_atk_cd = 2.0


func _desired_velocity() -> Vector2:
	if _windup > 0.0 or _aiming > 0.0:
		return Vector2.ZERO
	var to_player: Vector2 = run.player.global_position - global_position
	var d := to_player.length()
	var dir := to_player / maxf(d, 0.01)
	# Avanza a saltitos, como si tiraran de los hilos / Hops forward, as if the strings were pulled
	var hop := 0.45 + 0.55 * absf(sin(_t * 3.2 + _phase))
	if arm == "gun":
		var side := Vector2(-dir.y, dir.x) * (1.0 if fmod(_phase, 2.0) > 1.0 else -1.0)
		if d < KEEP_MIN:
			return (-dir + side * 0.3).normalized() * speed * hop
		if d > KEEP_MAX:
			return dir * speed * hop
		return side * speed * 0.4
	if d < MELEE_REACH * 0.7:
		return Vector2.ZERO
	return dir * speed * hop


func _act(delta: float) -> void:
	var k := 0.5 if slow_t > 0.0 else 1.0
	_swing = maxf(0.0, _swing - delta * 3.0)
	var to_player: Vector2 = run.player.global_position - global_position
	if _windup <= 0.0 and _aiming <= 0.0 and absf(to_player.x) > 4.0:
		_facing = signf(to_player.x)
	_atk_cd -= delta * k
	if arm == "gun":
		_act_gun(delta * k, to_player)
		return
	if _windup > 0.0:
		_windup -= delta * k
		if arm == "rod" and fmod(_windup, 0.1) < delta:
			run.fx.ring(_hand(), 8.0, SPARK, 0.2, 2.0)
		if _windup <= 0.0:
			_strike()
		return
	if _atk_cd <= 0.0 and to_player.length() < MELEE_REACH:
		_windup = WINDUP[arm]
		Audio.play("swing" if arm == "blade" else "zap", -10.0, 0.1)


## Golpe cuerpo a cuerpo: tajo que hace sangrar o descarga que paraliza
## Melee hit: a slash that causes bleeding or a zap that paralyses
func _strike() -> void:
	_atk_cd = EVERY[arm] + randf_range(-0.2, 0.3)
	_swing = 1.0
	var player: Player = run.player
	var hit_at := global_position + Vector2(_facing * 50.0, -50)
	var close := player.global_position.distance_to(global_position) < MELEE_REACH + 10.0
	if arm == "blade":
		run.fx.swing(hit_at, 50.0, 0.0 if _facing > 0 else PI, 0.9, Color("dfe6ff"), 5.0)
		if close:
			var before := player.hp
			player.take_damage(BLADE_DAMAGE * GameState.enemy_dmg_mult() * atk_mult())
			if player.hp < before:
				player.start_bleed(BLADE_BLEED)
	else:
		run.fx.ring(hit_at, 30.0, SPARK, 0.35, 2.4)
		Audio.play("zap", -4.0, 0.1)
		if close:
			var before := player.hp
			player.take_damage(ROD_DAMAGE * GameState.enemy_dmg_mult() * atk_mult())
			if player.hp < before:
				player.root(ROD_ROOT)
				player.shock(ROD_ROOT)


## Arcabuz: apunta despacio, dispara una bala fuerte y el retroceso la lanza hacia atrás
## Arquebus: aims slowly, fires a strong bullet and the recoil throws it back
func _act_gun(dt: float, to_player: Vector2) -> void:
	if _aiming > 0.0:
		_aiming += dt / GUN_AIM
		if _aiming >= 1.0:
			_aiming = 0.0
			_fire()
		return
	if _atk_cd <= 0.0 and to_player.length() < KEEP_MAX + 180.0:
		_aim_dir = (run.player.global_position + Vector2(0, -44) - _muzzle()).normalized()
		_facing = signf(_aim_dir.x) if absf(_aim_dir.x) > 0.05 else _facing
		_aiming = 0.01
		Audio.play("throw", -12.0, 0.1)


func _fire() -> void:
	_atk_cd = GUN_EVERY + randf_range(-0.4, 0.6)
	_swing = 1.0
	var shot := EnemyShot.new()
	shot.run = run
	shot.position = _muzzle()
	shot.velocity = _aim_dir * GUN_SPEED
	shot.damage = GUN_DAMAGE * atk_mult()
	shot.radius = 10.0
	run.world.add_child(shot)
	Audio.play("shoot", -3.0, 0.05)
	run.shake(4.0)
	run.fx.ring(_muzzle(), 18.0, UITheme.GOLD, 0.3, 2.2)
	run.fx.dissipate(_muzzle(), Color("cfc6e8"))
	# Retroceso: sale despedida hacia atrás / Recoil: it's thrown backwards
	knock += -_aim_dir * GUN_RECOIL / mass


func _hand() -> Vector2:
	return global_position + Vector2(_facing * 40.0, -64)


func _muzzle() -> Vector2:
	return global_position + Vector2(_facing * 84.0, -70)


func _draw() -> void:
	if not preview and state == State.ALIVE and _aiming > 0.0 and _aim_dir != Vector2.ZERO:
		EnemyShot.draw_warning(self, _muzzle() - global_position, _aim_dir, EnemyShot.reach(run, _muzzle(), _aim_dir, 1000.0), 22.0, _aiming)
	super._draw()


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	var bob := -absf(sin(_t * 3.2 + _phase)) * 8.0
	var sway := sin(_t * 1.6 + _phase) * 0.06
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(22, 7)), Color(0.05, 0.02, 0.15, 0.4 * a))
	draw_set_transform(offset + Vector2(0, bob - 4), sway, Vector2(_facing, 1.0))
	# Hilos hacia la cruceta / Strings up to the control bar
	var bar := Vector2(sin(_t * 1.6 + _phase) * 10.0, -200)
	var thread := Color("e8e2d0", 0.55 * a)
	draw_line(bar + Vector2(-26, 0), Vector2(-14, -74), thread, 1.5)
	draw_line(bar + Vector2(26, 0), Vector2(36, -60), thread, 1.5)
	draw_line(bar, Vector2(0, -114), thread, 1.5)
	draw_rect(Rect2(bar + Vector2(-30, -3), Vector2(60, 6)), Color("8a5a3e", a))
	draw_rect(Rect2(bar + Vector2(-3, -18), Vector2(6, 30)), Color("6a4430", a))
	# Piernas que cuelgan y patalean / Legs that dangle and kick
	for i in 2:
		var x := -7.0 if i == 0 else 7.0
		var swing := sin(_t * 6.4 + _phase + i * PI) * 0.35
		draw_set_transform(offset + Vector2(0, bob - 4) + Vector2(x, -36).rotated(sway) * Vector2(_facing, 1.0), sway + swing * _facing, Vector2(_facing, 1.0))
		Sprites.draw(self, "puppet_leg", mod)
	draw_set_transform(offset + Vector2(0, bob - 4), sway, Vector2(_facing, 1.0))
	# Brazo libre por detrás / Free arm behind
	draw_set_transform(offset + Vector2(0, bob - 4) + Vector2(-14 * _facing, -70), sway + sin(_t * 3.0) * 0.3 * _facing, Vector2(_facing, 1.0))
	Sprites.draw(self, "puppet_arm", mod)
	draw_set_transform(offset + Vector2(0, bob - 4), sway, Vector2(_facing, 1.0))
	Sprites.draw(self, "puppet_body", mod)
	# Brazo-arma: se echa atrás al preparar y golpea hacia delante / Weapon arm: pulls back to wind up, strikes forward
	var ang := 0.5
	match arm:
		"blade", "rod":
			var w: float = 1.0 - _windup / WINDUP[arm] if _windup > 0.0 else 0.0
			ang = 0.6 - 1.8 * w + 0.5 * _swing
		"gun":
			ang = 0.05 - 0.5 * _swing if _aiming > 0.0 or _swing > 0.0 else 0.35
			if _aiming > 0.0:
				ang = atan2(_aim_dir.y, absf(_aim_dir.x))
	draw_set_transform(offset + Vector2(0, bob - 4) + Vector2(12 * _facing, -70), (ang + sway) * _facing, Vector2(_facing, 1.0))
	Sprites.draw(self, "puppet_" + arm, mod)
	if arm == "rod" and (_windup > 0.0 or _swing > 0.0):
		for s in 3:
			var p := Vector2(50 + randf_range(0, 18), randf_range(-8, 8))
			draw_line(p, p + Vector2(randf_range(-10, 10), randf_range(-10, 10)), Color(SPARK, a), 2.0)
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, r: Vector2, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts


func head_top() -> Vector2:
	return Vector2(0, -132)
