class_name Cyberpunk
extends Enemy
## El Cyberpunk (salón, desde el Sueño 8): se acerca a base de dashes que avisa con una
## franja en el suelo y, si te pilla cerca, te hackea: te baja una estadística al azar
## hasta que lo matas. Cada Cyberpunk solo te hackea una vez.
## The Cyberpunk (living room, from Dream 8): closes in with dashes it warns about with a
## strip on the floor and, if it catches you nearby, hacks you: lowers a random stat until
## you kill it. Each Cyberpunk only hacks you once.

const DASH_EVERY := 3.4
const DASH_AIM := 0.45
const DASH_TIME := 0.28
const DASH_SPEED := 1000.0
const HACK_RANGE := 330.0
const HACK_TIME := 0.9
const NEON := Color("5ff2ff")
const NEON2 := Color("ff5fd2")
## Qué puede bajar el hackeo y cuánto / What the hack can lower and by how much
const HACK_STATS := {"attack": -25.0, "attack_speed": -25.0, "speed": -20.0, "range": -25.0, "defense": -2.0, "luck": -15.0}

var _dash_t := 2.0
var _aim := 0.0              # 0..1 mientras apunta el dash / while aiming the dash
var _dash_dir := Vector2.ZERO
var _dashing := 0.0
var _hack_t := 0.0           # 0..1 mientras te hackea / while hacking you
var _hack_cd := 1.5
var _hacked := false         # ya te ha hackeado / it has already hacked you


func _init() -> void:
	bestiary_id = "cyber"
	max_hp = 26.0
	hp = max_hp
	contact_damage = 2.0
	radius = 22.0
	speed = 115.0
	aim_height = 44.0
	shards = 4


func _desired_velocity() -> Vector2:
	if _dashing > 0.0:
		return _dash_dir * DASH_SPEED
	if _aim > 0.0 or _hack_t > 0.0:
		return Vector2.ZERO
	var to_player: Vector2 = run.player.global_position - global_position
	var dir := to_player.normalized()
	var side := Vector2(-dir.y, dir.x) * sin(_t * 1.3 + _phase) * 0.5
	return (dir + side).normalized() * speed


func _act(delta: float) -> void:
	var k := 0.5 if slow_t > 0.0 else 1.0
	var to_player: Vector2 = run.player.global_position - global_position
	if _dashing > 0.0:
		_dashing -= delta
		if fmod(_dashing, 0.06) < delta:
			run.fx.ring(global_position + Vector2(0, -40), 10.0, NEON, 0.25, 2.0)
		if _dashing <= 0.0:
			_dash_dir = Vector2.ZERO
		return
	# Hackeo: se queda quieto conectado a Kroker / Hack: stands still, linked to Kroker
	if _hack_t > 0.0:
		_hack_t += delta * k / HACK_TIME
		if to_player.length() > HACK_RANGE * 1.25:
			_hack_t = 0.0   # te has alejado a tiempo / you got away in time
			_hack_cd = 2.0
		elif _hack_t >= 1.0:
			_hack_t = 0.0
			_apply_hack()
		return
	_hack_cd -= delta * k
	if not _hacked and _hack_cd <= 0.0 and _aim <= 0.0 and to_player.length() < HACK_RANGE:
		_hack_t = 0.01
		Audio.play("hack", -8.0, 0.1)
		return
	# Dash avisado / Telegraphed dash
	_dash_t -= delta * k
	if _dash_t <= DASH_AIM:
		if _dash_dir == Vector2.ZERO:
			_dash_dir = to_player.normalized()
			_facing = signf(_dash_dir.x) if absf(_dash_dir.x) > 0.05 else _facing
		_aim = 1.0 - maxf(0.0, _dash_t) / DASH_AIM
	if _dash_t <= 0.0:
		_dash_t = DASH_EVERY + randf_range(-0.5, 0.6)
		_aim = 0.0
		_dashing = DASH_TIME
		Audio.play("dash", -6.0, 0.1)


## Mientras va de dash hace más daño / It hits harder while dashing
func _touch_player() -> void:
	var base := contact_damage
	if _dashing > 0.0:
		contact_damage = base * 1.5
	super._touch_player()
	contact_damage = base


func _apply_hack() -> void:
	_hacked = true
	var ids := HACK_STATS.keys()
	var id: String = ids[randi() % ids.size()]
	GameState.hacks[get_instance_id()] = {"stat": id, "value": HACK_STATS[id]}
	run.player.refresh_stats()
	run.hud.set_hp(run.player.hp, run.player.max_hp)
	run.hud.set_hacks()
	Audio.play("glitch", -2.0)
	run.fx.text(run.player.global_position + Vector2(0, -120), tr("HACKED").format({"stat": tr("STAT_NAME_" + id.to_upper())}), NEON2, 24)
	run.fx.ring(run.player.global_position + Vector2(0, -40), 30.0, NEON, 0.5, 2.6)


## Al morir (o caer por un agujero) se acaba su hackeo / Dying (or falling down a hole) ends its hack
func _clear_hack() -> void:
	if not GameState.hacks.has(get_instance_id()):
		return
	GameState.hacks.erase(get_instance_id())
	if run and is_instance_valid(run.player):
		run.player.refresh_stats()
		run.hud.set_hp(run.player.hp, run.player.max_hp)
		if is_instance_valid(run.hud):
			run.hud.set_hacks()
		if run.running:
			run.fx.text(run.player.global_position + Vector2(0, -120), tr("HACK_CLEARED"), NEON, 20)


func die(counted: bool) -> void:
	_clear_hack()
	super.die(counted)


func _start_fall(to: Vector2) -> void:
	_clear_hack()
	super._start_fall(to)


func _exit_tree() -> void:
	_clear_hack()


func _draw() -> void:
	if not preview and state == State.ALIVE:
		if _aim > 0.0 and _dash_dir != Vector2.ZERO:
			EnemyShot.draw_warning(self, Vector2(0, -6), _dash_dir, DASH_SPEED * DASH_TIME, 40.0, _aim)
		var to: Vector2 = run.player.global_position + Vector2(0, -60) - global_position
		if _hack_t > 0.0:
			_glitch_line(Vector2(0, -70), to, _hack_t)
		elif _hacked:
			_glitch_line(Vector2(0, -70), to, 0.25)
	super._draw()


## Rayo de datos que tiembla hasta Kroker / Shaky data beam to Kroker
func _glitch_line(from: Vector2, to: Vector2, k: float) -> void:
	var pts := PackedVector2Array()
	var n := 10
	var side := (to - from).normalized().orthogonal()
	for i in n + 1:
		var u := float(i) / n
		var j := 0.0 if i == 0 or i == n else randf_range(-8.0, 8.0) * (0.5 + k)
		pts.append(from.lerp(to, u) + side * j)
	draw_polyline(pts, Color(NEON2, 0.25 + 0.5 * k), 4.0)
	draw_polyline(pts, Color(NEON, 0.4 + 0.5 * k), 1.5)
	if k < 1.0 and k > 0.3:
		draw_arc(to, 30.0 * (1.0 - k) + 10.0, 0, TAU, 16, Color(NEON, 0.7 * k), 2.0)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(22, 7)), Color(0.05, 0.02, 0.15, 0.4 * a))
	# Estela de neón durante el dash / Neon trail while dashing
	if _dashing > 0.0:
		for i in 3:
			Sprites.draw(self, "cyber_body", Color(NEON, 0.25 * a), Vector2(-(i + 1) * 14.0, 0))
	var step := sin(_t * 9.0) * 3.0 if _dashing <= 0.0 else 0.0
	Sprites.draw(self, "cyber_leg", mod, Vector2(-7, step))
	Sprites.draw(self, "cyber_leg", mod, Vector2(7, -step))
	Sprites.draw(self, "cyber_body", mod)
	# Brazo con el ciberdeck que brilla al hackear / Arm with the cyberdeck, glowing while hacking
	draw_set_transform(offset + Vector2(18 * _facing, -84), (-1.2 if _hack_t > 0.0 else 0.2) * _facing, Vector2(_facing, 1.0))
	Sprites.draw(self, "cyber_arm", mod)
	draw_rect(Rect2(-6, 30, 12, 8), Color(NEON2 if _hack_t > 0.0 else Color("1a1830"), a) * tint)
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	Sprites.draw(self, "cyber_head", mod)
	# Visor que parpadea / Flickering visor
	var vis := 0.6 + 0.4 * sin(_t * 8.0 + _phase)
	draw_rect(Rect2(-12, -106, 26, 3), Color(NEON, vis * a) * tint)
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, r: Vector2, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts


func head_top() -> Vector2:
	return Vector2(0, -122)
