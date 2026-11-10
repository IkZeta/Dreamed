class_name BotcherTurret
extends Enemy
## Torreta de vapor que el Chapuzas monta sobre los tablones de un agujero. No se mueve ni se
## puede empujar; apunta a Kroker (con aviso) y le dispara pernos de latón. Mientras siga en pie,
## el agujero está tapado; al romperla, los tablones se vienen abajo.
## Steam turret the Botcher mounts on the planks over a hole. It can't move or be shoved; it aims
## at Kroker (with a warning) and fires brass bolts at him. While it stands, the hole is covered;
## break it and the planks give way.

const SHOT_EVERY := 2.6
const AIM_TIME := 0.7
const SHOT_SPEED := 520.0
const SHOT_DAMAGE := 3.0
const RANGE := 760.0
const SIZE := 1.35          # se dibuja más grande / drawn larger

var hole := Rect2()
var engineer: Botcher
var _shot_t := 1.6
var _aiming := 0.0
var _aim_dir := Vector2.ZERO
var _barrel := 0.0          # ángulo del cañón / barrel angle
var _recoil := 0.0
var _plank: BotcherPlank


func _init() -> void:
	bestiary_id = "botcher_turret"
	max_hp = 28.0
	hp = max_hp
	contact_damage = 0.0
	radius = 26.0
	speed = 0.0
	mass = 1000.0
	aim_height = 34.0
	shards = 2
	spawn_time = 0.4


func _ready() -> void:
	super._ready()
	_barrel = PI if randf() < 0.5 else 0.0
	_plank = BotcherPlank.new()
	_plank.owner_turret = self
	_plank.rect = hole
	var world: Node = run.fx.get_parent()
	world.add_child(_plank)
	world.move_child(_plank, run.room.get_index() + 1)


func is_dangerous() -> bool:
	return false


func can_fall() -> bool:
	return false


## ¿Tapa este agujero? / Does it cover this hole?
func covers(world_rect: Rect2) -> bool:
	return state != State.DYING and hole.is_equal_approx(world_rect)


## Atornillada a los tablones / Bolted to the planks
func _move(_delta: float) -> void:
	knock = Vector2.ZERO
	external_pull = Vector2.ZERO


func _act(delta: float) -> void:
	_recoil = maxf(0.0, _recoil - delta * 4.0)
	var from := _muzzle_base()
	var to: Vector2 = run.player.global_position + Player.HURT
	var want := (to - from).angle()
	if _aiming <= 0.0:
		_barrel = lerp_angle(_barrel, want, minf(1.0, delta * 5.0))
	_shot_t -= delta
	if from.distance_to(to) > RANGE or not run.view_rect().grow(40.0).has_point(global_position):
		_shot_t = maxf(_shot_t, AIM_TIME)
		_aiming = 0.0
		return
	if _shot_t <= AIM_TIME:
		if _aiming <= 0.0:
			_aim_dir = Vector2.from_angle(want)
			_barrel = want
		_aiming = 1.0 - clampf(_shot_t / AIM_TIME, 0.0, 1.0)
	if _shot_t <= 0.0:
		_shot_t = SHOT_EVERY + randf_range(-0.3, 0.4)
		_aiming = 0.0
		_fire()


func _muzzle_base() -> Vector2:
	return global_position + Vector2(0, -44 * SIZE)


func _fire() -> void:
	var shot := EnemyShot.new()
	shot.cause = bestiary_id
	shot.run = run
	shot.position = _muzzle_base() + _aim_dir * 30.0
	shot.velocity = _aim_dir * SHOT_SPEED
	shot.damage = SHOT_DAMAGE * atk_mult()
	run.world.add_child(shot)
	_recoil = 1.0
	_aim_dir = Vector2.ZERO
	run.fx.ring(_muzzle_base() + Vector2(-8, -18), 12.0, Color(0.95, 0.95, 1.0, 0.7), 0.4, 2.0)
	Audio.play("shoot", -10.0, 0.1)


func _death_sound() -> void:
	Audio.play("crack", -6.0, 0.1)


func _draw() -> void:
	if state == State.ALIVE and _aiming > 0.0 and _aim_dir != Vector2.ZERO:
		var from := _muzzle_base()
		EnemyShot.draw_warning(self, from - global_position, _aim_dir, EnemyShot.reach(run, from, _aim_dir, 900.0), 18.0, _aiming)
	super._draw()
	if state == State.ALIVE:
		var k := 1.0 - clampf(_shot_t / SHOT_EVERY, 0.0, 1.0)
		var r := Rect2(-24, -98, 48, 4)
		draw_rect(r.grow(1.0), Color(0.05, 0.03, 0.18, 0.55 * _fade))
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color(Botcher.BRASS, 0.85 * _fade))


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash, a) * tint
	draw_set_transform(Vector2(offset.x, 0), 0.0, Vector2(SIZE, SIZE))
	var o := Vector2.ZERO
	# Trípode / Tripod
	for x in [-22.0, 22.0]:
		draw_line(o + Vector2(x, 0), o + Vector2(x * 0.3, -22), Botcher.STEEL.darkened(0.3) * mod, 4.0)
	draw_line(o + Vector2(0, 2), o + Vector2(0, -22), Botcher.STEEL.darkened(0.3) * mod, 4.0)
	# Caldera de cobre con remaches / Riveted copper boiler
	draw_rect(Rect2(o + Vector2(-20, -40), Vector2(40, 20)), Botcher.COPPER * mod)
	draw_rect(Rect2(o + Vector2(-20, -40), Vector2(40, 3)), Botcher.COPPER.lightened(0.2) * mod)
	for x in [-15.0, -5.0, 5.0, 15.0]:
		draw_rect(Rect2(o + Vector2(x - 1, -33), Vector2(2, 2)), Botcher.BRASS.lightened(0.3) * mod)
	# Manómetro / Pressure gauge
	var gauge := o + Vector2(-12, -29)
	draw_circle(gauge, 5.0, Color("f0e6cf") * mod)
	var needle := -PI * 0.75 + PI * 1.5 * (1.0 - clampf(_shot_t / SHOT_EVERY, 0.0, 1.0))
	draw_line(gauge, gauge + Vector2.from_angle(needle) * 4.0, Color("c0392b") * mod, 1.5)
	# Cúpula de latón / Brass dome
	var dome := PackedVector2Array()
	for i in 13:
		var ang := PI + PI * i / 12.0
		dome.append(o + Vector2(0, -40) + Vector2(cos(ang) * 18.0, sin(ang) * 14.0))
	draw_colored_polygon(dome, Botcher.BRASS * mod)
	draw_circle(o + Vector2(-6, -48), 3.0, Color(1, 1, 0.9, 0.5 * a))
	# Cañón que apunta / Aiming barrel
	var base := o + Vector2(0, -44)
	var d := Vector2.from_angle(_barrel)
	var n := d.orthogonal()
	var back := 6.0 * _recoil
	var p0 := base - d * back
	var p1 := base + d * (34.0 - back)
	draw_colored_polygon(PackedVector2Array([p0 + n * 5, p1 + n * 4, p1 - n * 4, p0 - n * 5]), Botcher.STEEL * mod)
	draw_line(p1 + n * 6, p1 - n * 6, Botcher.BRASS.darkened(0.1) * mod, 4.0)
	# Chimenea con vapor / Chimney with steam
	draw_rect(Rect2(o + Vector2(10, -62), Vector2(6, 14)), Botcher.STEEL.darkened(0.2) * mod)
	for i in 3:
		var t := fmod(_t * 0.8 + i * 0.33, 1.0)
		draw_circle(o + Vector2(13 + sin(_t * 2.0 + i) * 4.0, -64 - t * 26.0), 3.0 + t * 4.0, Color(0.95, 0.95, 1.0, 0.35 * (1.0 - t) * a))
	draw_set_transform(Vector2.ZERO)


func head_top() -> Vector2:
	return Vector2(0, -88)
