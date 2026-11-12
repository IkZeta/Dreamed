class_name Exam
extends Enemy
## Examen suspenso (Acto 3, desde el Sueño 12; poco común): un folio volador con un cero enorme en
## rojo. Se esconde detrás de los demás enemigos y, de vez en cuando, le lanza a Kroker un borrón de
## tinta roja: si le da, Kroker queda marcado con un cero encima de la cabeza y recibe más daño
## hasta que le pegue al examen (o lo tire por un agujero). Tiene poca vida y huye.
## Failed Exam (Act 3, from Dream 12; uncommon): a flying sheet with a huge red zero. It hides
## behind the other enemies and, now and then, flings a blot of red ink at Kroker: if it lands,
## Kroker is marked with a zero over his head and takes more damage until he hits the exam (or
## throws it down a hole). It has little health and runs away.

## Daño extra que recibe Kroker marcado / Extra damage a marked Kroker takes
const MARK_MULT := 1.25
const MARK_EVERY := 6.0
const AIM_TIME := 0.7
const INK_SPEED := 520.0
const KEEP := 360.0
const RED := Color("e0303a")

var _mark_cd := 2.5
var _aim := 0.0


func _init() -> void:
	bestiary_id = "exam"
	max_hp = 14.0
	hp = max_hp
	contact_damage = 0.0
	radius = 18.0
	speed = 120.0
	mass = 0.5
	aim_height = 30.0
	shards = 3


## Se coloca detrás del enemigo más cercano a él (visto desde Kroker); si no hay ninguno, a distancia
## Hides behind its nearest enemy (as seen from Kroker); if there isn't one, keeps its distance
func _desired_velocity() -> Vector2:
	if _aim > 0.0:
		return Vector2.ZERO
	var me := global_position
	var p: Vector2 = run.player.global_position
	var goal := Vector2.INF
	var best := 520.0
	for n: Node in run.foes():
		if n == self or not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e == null or not e.is_targetable() or e is Exam:
			continue
		var d := me.distance_to(e.global_position)
		if d < best:
			best = d
			goal = e.global_position + (e.global_position - p).normalized() * 110.0
	if goal == Vector2.INF or goal.distance_to(p) < 200.0:
		var away := (me - p).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		goal = p + away.rotated(sin(_t * 0.6 + _phase) * 0.8) * KEEP
	var to := goal - me
	if to.length() < 12.0:
		return Vector2.ZERO
	# Revolotea: un vaivén de lado, como un papel al viento / Flutters: a sideways sway, like paper in the wind
	var dir := to.normalized()
	return (dir + dir.orthogonal() * sin(_t * 3.0 + _phase) * 0.5).normalized() * speed * minf(1.0, to.length() / 80.0)


func _act(delta: float) -> void:
	var p: Vector2 = run.player.global_position
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0:
			_fling()
		return
	_mark_cd -= delta * (0.5 if slow_t > 0.0 else 1.0)
	if _mark_cd <= 0.0 and not run.player.marked() and global_position.distance_to(p) < 620.0:
		_aim = AIM_TIME
		_mark_cd = MARK_EVERY
		_facing = signf(p.x - global_position.x) if absf(p.x - global_position.x) > 4.0 else _facing


func _fling() -> void:
	var from := global_position + Vector2(0, -60)
	var ink := InkBlot.new()
	ink.exam = self
	ink.run = run
	ink.position = from
	ink.velocity = (run.player.global_position + Player.HURT - from).normalized() * INK_SPEED
	run.world.add_child(ink)
	Audio.play("paper", -10.0, 0.1)


## Si le pegan, se acaba la marca: ¡recuperación aprobada! / If it gets hit, the mark ends: retake passed!
func hit(amount: float, impulse := Vector2.ZERO) -> void:
	super.hit(amount, impulse)
	clear_mark()


func die(counted: bool) -> void:
	clear_mark()
	super.die(counted)


func _start_fall(to: Vector2) -> void:
	clear_mark()
	super._start_fall(to)


func clear_mark() -> void:
	if not is_instance_valid(run) or run.player.exam_mark != self:
		return
	run.player.exam_mark = null
	run.fx.text(run.player.global_position + Vector2(0, -150), tr("EXAM_PASSED"), UITheme.GOLD, 22)
	Audio.play("chime", -12.0, 0.0, 1.2)


func _death_sound() -> void:
	Audio.play("paper", -6.0, 0.15)


func head_top() -> Vector2:
	return Vector2(0, -96)


func aim_point() -> Vector2:
	return global_position + Vector2(0, -60)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash, a) * tint
	var lift := -60.0 + sin(_t * 2.4 + _phase) * 6.0
	# Sombra en el suelo, pequeña porque flota / A small shadow on the floor, since it floats
	draw_set_transform(Vector2(offset.x, 0), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 16.0, Color(0.05, 0.02, 0.15, 0.25 * a))
	# Al apuntar se pone tieso y tiembla; si no, ondea / While aiming it goes stiff and trembles; otherwise it waves
	var aiming := _aim > 0.0
	var wave := 0.0 if aiming else sin(_t * 4.0 + _phase) * 0.18
	var jitter := Vector2(randf_range(-1.5, 1.5), 0) if aiming else Vector2.ZERO
	draw_set_transform_matrix(Transform2D(sin(_t * 1.7 + _phase) * 0.12, Vector2(_facing * (1.0 - absf(wave) * 0.6), 1.0), wave, offset + Vector2(0, lift) + jitter))
	Sprites.draw(self, "exam_body", mod)
	draw_set_transform(Vector2.ZERO)
	if aiming:
		var k := 1.0 - _aim / AIM_TIME
		draw_circle(offset + Vector2(0, lift + 10), 6.0 + 14.0 * k, Color(RED, 0.25 * k * a))


## Borrón de tinta roja: si toca a Kroker, le marca con un cero / Red ink blot: if it touches Kroker, it marks him with a zero
class InkBlot extends Node2D:
	var run: Node
	var exam: Exam
	var velocity := Vector2.ZERO
	var life := 2.2
	var _t := 0.0

	func _ready() -> void:
		z_index = 30

	func _physics_process(delta: float) -> void:
		life -= delta
		_t += delta
		position += velocity * delta
		var player: Player = run.player
		if run.running and global_position.distance_to(player.global_position + Player.HURT) < 14.0 + Player.HURT_R:
			if is_instance_valid(exam) and exam.is_targetable() and player.alive:
				player.exam_mark = exam
				run.fx.text(player.global_position + Vector2(0, -160), tr("EXAM_MARKED"), Exam.RED, 24)
				Audio.play("exam_stamp", -4.0, 0.05)
				run.shake(2.0)
				Progress.tip("exam")
			queue_free()
			return
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := 8.0 + sin(_t * 20.0) * 1.0
		draw_circle(Vector2.ZERO, r + 3.0, Color(Exam.RED, 0.3))
		draw_circle(Vector2.ZERO, r, Exam.RED)
		for i in 3:
			var p := -velocity.normalized() * (10.0 + i * 8.0)
			draw_circle(p, 4.0 - i, Color(Exam.RED, 0.6 - i * 0.18))
