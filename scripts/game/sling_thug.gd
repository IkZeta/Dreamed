class_name SlingThug
extends Enemy
## Matón del tirachinas (desde el Sueño 3): poca vida, pero se queda lejos y dispara piedras.
## Avisa antes de disparar tensando la goma.
## Slingshot thug (from Dream 3): low health, but keeps its distance and shoots stones.
## It warns before firing by drawing back the band.

const KEEP_MIN := 300.0
const KEEP_MAX := 460.0
const SHOT_EVERY := 2.4
const AIM_TIME := 0.6
const SHOT_DAMAGE := 3.0

const JACKET := Color("4f5f8f")
const JACKET_DARK := Color("38456d")
const CAP := Color("a34d5f")
const SKIN := Color("b9a3c9")
const EYES := Color("ffcf7a")

var _shot_t := 1.5
var _aiming := 0.0   # 0..1 mientras tensa la goma / while drawing the band
var _aim_dir := Vector2.ZERO   # dirección fijada al empezar a apuntar / direction locked when aiming starts
const SHOT_SPEED := 420.0


func _init() -> void:
	shards = 2
	bestiary_id = "sling"
	max_hp = 18.0
	hp = max_hp
	contact_damage = 2.0
	radius = 22.0
	speed = 90.0
	mass = 1.0
	aim_height = 40.0


## Se mantiene a media distancia / Keeps at mid range
func _desired_velocity() -> Vector2:
	var to_player: Vector2 = run.player.global_position - global_position
	var d := to_player.length()
	var dir := to_player / maxf(d, 0.01)
	var side := Vector2(-dir.y, dir.x) * (1.0 if fmod(_phase, 2.0) > 1.0 else -1.0)
	if _aiming > 0.0:
		return Vector2.ZERO
	if d < KEEP_MIN:
		return (-dir + side * 0.3).normalized() * speed
	if d > KEEP_MAX:
		return dir * speed
	return side * speed * 0.5


func _act(delta: float) -> void:
	if _aiming <= 0.0:
		_facing = signf(run.player.global_position.x - global_position.x) if absf(run.player.global_position.x - global_position.x) > 4.0 else _facing
	_shot_t -= delta * (0.5 if slow_t > 0.0 else 1.0)
	if _shot_t <= AIM_TIME:
		if _aim_dir == Vector2.ZERO:
			# Fija hacia dónde va a disparar y lo avisa / Locks where it will shoot and shows it
			_aim_dir = (run.player.global_position + Vector2(0, -44) - _shot_from()).normalized()
			_facing = signf(_aim_dir.x) if absf(_aim_dir.x) > 0.05 else _facing
		_aiming = 1.0 - maxf(0.0, _shot_t) / AIM_TIME
	if _shot_t <= 0.0:
		_shot_t = SHOT_EVERY + randf_range(-0.3, 0.4)
		_aiming = 0.0
		_fire()


func _draw() -> void:
	if state == State.ALIVE and _aiming > 0.0 and _aim_dir != Vector2.ZERO:
		EnemyShot.draw_warning(self, _shot_from() - global_position, _aim_dir, EnemyShot.reach(run, _shot_from(), _aim_dir, 900.0), 20.0, _aiming)
	super._draw()
	if state == State.ALIVE:
		# Barra de recarga del tirachinas / Slingshot reload bar
		var k := 1.0 - clampf(_shot_t / SHOT_EVERY, 0.0, 1.0)
		var r := Rect2(-24, -aim_height * 2.4 - 8, 48, 4)
		draw_rect(r.grow(1.0), Color(0.05, 0.03, 0.18, 0.55 * _fade))
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color(UITheme.EMBER, 0.8 * _fade))


func _shot_from() -> Vector2:
	return global_position + Vector2(18 * _facing, -60)


func _fire() -> void:
	var from := _shot_from()
	var shot := EnemyShot.new()
	shot.run = run
	shot.position = from
	if _aim_dir == Vector2.ZERO:
		_aim_dir = (run.player.global_position + Vector2(0, -44) - from).normalized()
	shot.velocity = _aim_dir * SHOT_SPEED
	_aim_dir = Vector2.ZERO
	shot.damage = SHOT_DAMAGE
	run.world.add_child(shot)
	Audio.play("shoot", -8.0, 0.1)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	var skin := SKIN.lerp(Color.WHITE, _flash * 0.6) * tint
	draw_colored_polygon(_ellipse(Vector2(0, 0), Vector2(24, 7)), Color(0.05, 0.02, 0.15, 0.4 * a))
	for x in [-8.0, 8.0]:
		Sprites.draw(self, "sling_leg", mod, Vector2(x, sin(_t * 6.0 + x) * 1.5))
	Sprites.draw(self, "sling_body", mod)
	Sprites.draw(self, "sling_head", mod)
	draw_rect(Rect2(5, -99, 3, 3), Color(EYES, a))
	draw_rect(Rect2(-5, -99, 3, 3), Color(EYES, a))
	# Tirachinas: la goma se tensa antes de disparar / Slingshot: the band stretches before firing
	var hand := Vector2(26, -66)
	draw_line(Vector2(14, -74), hand, Color(skin, a), 6.0)
	draw_line(hand, hand + Vector2(4, -16), Color("8a5a3a") * tint, 3.0)
	draw_line(hand, hand + Vector2(12, -12), Color("8a5a3a") * tint, 3.0)
	var pull := Vector2(-14, 4) * _aiming
	draw_polyline(PackedVector2Array([hand + Vector2(4, -16), hand + Vector2(4, -10) + pull, hand + Vector2(12, -12)]), Color("e0cfa8") * tint, 2.0)
	if _aiming > 0.0:
		draw_circle(hand + Vector2(4, -10) + pull, 4.0, Color("cfc6e8", a))
		draw_arc(hand + Vector2(4, -10), 16.0 * (1.0 - _aiming) + 6.0, 0, TAU, 16, Color(EYES, 0.6 * _aiming * a), 2.0)


func _ellipse(c: Vector2, r: Vector2, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts
