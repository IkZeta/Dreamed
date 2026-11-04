class_name Police
extends Enemy
## Policía de la Unidad Especial (Acto 4): baja de la furgo voladora o aparece por la calle. Tiene
## poca vida, se queda a media distancia y dispara ráfagas de tres balas con su fusil de asalto;
## cada bala que te da hace sangrar. Su uniforme cambia con la estética de la ciudad.
## Special Unit officer (Act 4): drops from the flying van or turns up in the street. Low health,
## keeps at mid range and fires three-round bursts with its assault rifle; each bullet that hits
## makes you bleed. Its uniform changes with the city's look.

const KEEP_MIN := 260.0
const KEEP_MAX := 430.0
const BURST_EVERY := 2.8
const AIM_TIME := 0.55
const BURST := 3
const BURST_GAP := 0.12
const SHOT_SPEED := 620.0
const SHOT_DAMAGE := 1.5
const SHOT_BLEED := 1.5

var style := "brutalist"
var _shot_t := 1.6
var _aiming := 0.0
var _aim_dir := Vector2.ZERO
var _burst_left := 0
var _burst_t := 0.0
var _drop := 0.0           # bajando de la furgo (cuerda) / coming down from the van (rope)


func _init() -> void:
	bestiary_id = "police"
	max_hp = 12.0
	hp = max_hp
	contact_damage = 1.0
	radius = 18.0
	speed = 120.0
	mass = 0.9
	aim_height = 56.0
	shards = 1


func _ready() -> void:
	super._ready()
	if run and run.room is Act4Room:
		style = (run.room as Act4Room).style


func _desired_velocity() -> Vector2:
	if _drop > 0.0 or _aiming > 0.0 or _burst_left > 0:
		return Vector2.ZERO
	var to_player: Vector2 = run.player.global_position - global_position
	var d := to_player.length()
	var dir := to_player / maxf(d, 0.01)
	var side := Vector2(-dir.y, dir.x) * (1.0 if fmod(_phase, 2.0) > 1.0 else -1.0)
	if d < KEEP_MIN:
		return (-dir + side * 0.4).normalized() * speed
	if d > KEEP_MAX:
		return dir * speed
	return side * speed * 0.6


func _physics_process(delta: float) -> void:
	_drop = maxf(0.0, _drop - delta * 1.6)
	super._physics_process(delta)


func _act(delta: float) -> void:
	if _drop > 0.0:
		return
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = BURST_GAP
			_burst_left -= 1
			_fire()
			if _burst_left == 0:
				_aim_dir = Vector2.ZERO
		return
	if _aiming <= 0.0 and absf(run.player.global_position.x - global_position.x) > 4.0:
		_facing = signf(run.player.global_position.x - global_position.x)
	_shot_t -= delta * (0.5 if slow_t > 0.0 else 1.0)
	if _shot_t <= AIM_TIME:
		if _aim_dir == Vector2.ZERO:
			_aim_dir = (run.player.global_position + Player.HURT - _shot_from()).normalized()
			_facing = signf(_aim_dir.x) if absf(_aim_dir.x) > 0.05 else _facing
		_aiming = 1.0 - maxf(0.0, _shot_t) / AIM_TIME
	if _shot_t <= 0.0:
		_shot_t = BURST_EVERY + randf_range(-0.4, 0.5)
		_aiming = 0.0
		_burst_left = BURST
		_burst_t = 0.0


func _shot_from() -> Vector2:
	return global_position + Vector2(54 * _facing, -74)


func _fire() -> void:
	var shot := EnemyShot.new()
	shot.cause = bestiary_id
	shot.run = run
	shot.kind = "bullet"
	shot.radius = 6.0
	shot.position = _shot_from()
	shot.velocity = _aim_dir.rotated(randf_range(-0.06, 0.06)) * SHOT_SPEED
	shot.damage = SHOT_DAMAGE * atk_mult()
	shot.bleed = SHOT_BLEED
	run.world.add_child(shot)
	Audio.play("burst", -12.0, 0.15)


func _death_sound() -> void:
	Audio.play("hit", -8.0, 0.1)


func _draw() -> void:
	if state == State.ALIVE and _aiming > 0.0 and _aim_dir != Vector2.ZERO:
		EnemyShot.draw_warning(self, _shot_from() - global_position, _aim_dir, EnemyShot.reach(run, _shot_from(), _aim_dir, 700.0), 14.0, _aiming)
	# Cuerda desde la furgo / Rope from the van
	if _drop > 0.0:
		draw_line(Vector2(0, -60 - 200.0 * _drop), Vector2(0, -400), Color("2b2945", 0.8), 2.0)
	super._draw()


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var lift := -200.0 * _drop * _drop
	draw_set_transform(offset + Vector2(0, lift), 0.0, Vector2(_facing, 1.0))
	draw_colored_polygon(_ellipse(Vector2(0, -lift), Vector2(22, 6)), Color(0.05, 0.02, 0.15, 0.4 * a))
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	Sprites.draw(self, "police_" + style, mod, Vector2(0, -sin(_t * 8.0 + _phase) * 1.5 if _burst_left == 0 else 0.0))
	# Fogonazo del fusil / Muzzle flash
	if _burst_left > 0 and _burst_t > BURST_GAP * 0.5:
		draw_circle(Vector2(56, -76), 7.0, Color("ffe08a", a))
	draw_set_transform(Vector2.ZERO)


func head_top() -> Vector2:
	return Vector2(0, -150)


func _ellipse(c: Vector2, r: Vector2, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
