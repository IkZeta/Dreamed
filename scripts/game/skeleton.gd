class_name Skeleton
extends Enemy
## Esqueleto (desde el Sueño 4): poca vida pero muchísimo daño. Al caer deja un montón de
## huesos que vuelve a levantarse si no lo rematas a tiempo.
## Skeleton (from Dream 4): low health but very high damage. When it falls it leaves a
## pile of bones that gets back up unless you finish it off in time.

const REVIVE_TIME := 4.0
const PILE_HP := 3.0
const BONE := Color("e8e2d4")
const BONE_SHADE := Color("b9b0a0")
const EYES := Color("7ff2e0")

var _pile := false
var _revive_t := 0.0
var _rise := 1.0   # 0 = montón, 1 = de pie / 0 = pile, 1 = standing


func _init() -> void:
	shards = 3
	max_hp = 6.0
	hp = max_hp
	contact_damage = 6.0
	radius = 20.0
	speed = 118.0
	mass = 0.8
	aim_height = 44.0


func _desired_velocity() -> Vector2:
	if _pile or _rise < 1.0:
		return Vector2.ZERO
	# Avanza a trompicones / Lurches forward
	var dir: Vector2 = (run.player.global_position - global_position).normalized()
	return dir * speed * (0.6 + 0.6 * absf(sin(_t * 5.0 + _phase)))


func is_dangerous() -> bool:
	return not _pile and _rise >= 1.0


func aim_point() -> Vector2:
	return global_position + Vector2(0, -12 if _pile else -aim_height)


func _act(delta: float) -> void:
	if _pile:
		_revive_t -= delta
		if _revive_t <= 0.0:
			_pile = false
			hp = max_hp * 0.6
			Audio.play("revive", -6.0, 0.1)
			run.fx.ring(global_position + Vector2(0, -10), 30.0, EYES, 0.6, 2.0)
	_rise = move_toward(_rise, 0.0 if _pile else 1.0, delta * 2.5)


func die(counted: bool) -> void:
	# Primera vez: se desmorona. Si ya era un montón (o se acaba el sueño), muere de verdad.
	# First time: it collapses. If it was already a pile (or the dream ends), it truly dies.
	if counted and not _pile and state == State.ALIVE:
		_pile = true
		_revive_t = REVIVE_TIME
		hp = PILE_HP
		knock = Vector2.ZERO
		Audio.play("bone", -6.0, 0.1)
		run.fx.text(global_position + Vector2(0, -40), tr("ENEMY_FINISH_IT"), EYES, 18)
		return
	super.die(counted)


func _death_sound() -> void:
	Audio.play("bone", -4.0, 0.05)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var bone := BONE.lerp(Color.WHITE, _flash) * tint
	var shade := BONE_SHADE * tint
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	draw_colored_polygon(_ellipse(Vector2(0, 0), Vector2(24, 7)), Color(0.05, 0.02, 0.15, 0.4 * a))
	if _rise <= 0.02:
		_draw_pile(bone, shade, a)
		return
	# Se levanta desde el suelo / Rises from the ground
	draw_set_transform(offset + Vector2(0, (1.0 - _rise) * 40.0), (1.0 - _rise) * 0.6, Vector2(_facing, _rise))
	var walk := sin(_t * 10.0 + _phase)
	# Piernas / Legs
	for side in [-1.0, 1.0]:
		var hip := Vector2(side * 7, -40)
		var knee := hip + Vector2(side * 2 + walk * side * 5, 18)
		draw_line(hip, knee, Color(bone, a), 4.0, true)
		draw_line(knee, knee + Vector2(0, 20), Color(bone, a), 4.0, true)
		draw_line(knee + Vector2(0, 20), knee + Vector2(8, 22), Color(bone, a), 4.0, true)
	# Pelvis y columna / Pelvis and spine
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -46), Vector2(12, -46), Vector2(8, -38), Vector2(-8, -38)]), Color(bone, a))
	draw_line(Vector2(0, -46), Vector2(0, -82), Color(shade, a), 4.0)
	# Costillas / Ribs
	for i in 4:
		var y := -78.0 + i * 8.0
		draw_arc(Vector2(0, y), 13.0 - i * 1.5, PI * 0.15, PI * 0.85, 10, Color(bone, a), 3.0, true)
		draw_arc(Vector2(0, y), 13.0 - i * 1.5, PI * 1.15, PI * 1.85, 10, Color(bone, a), 3.0, true)
	# Brazos estirados hacia delante / Arms reaching forward
	for side in [-1.0, 1.0]:
		var sh := Vector2(side * 12, -80)
		var el := sh + Vector2(14, 10 + side * 4)
		draw_line(sh, el, Color(bone, a), 3.5, true)
		draw_line(el, el + Vector2(16, -2 + walk * 3.0), Color(bone, a), 3.5, true)
	# Calavera / Skull
	draw_colored_polygon(_ellipse(Vector2(2, -98), Vector2(15, 14)), Color(bone, a))
	draw_rect(Rect2(-6, -88, 16, 8), Color(bone, a))
	for x in [-3.0, 8.0]:
		draw_circle(Vector2(x, -98), 4.5, Color(0.08, 0.05, 0.15, a))
		draw_circle(Vector2(x, -98), 2.0, Color(EYES, a))
	for i in 3:
		draw_line(Vector2(-3 + i * 5, -88), Vector2(-3 + i * 5, -82), Color(0.08, 0.05, 0.15, a), 1.5)


func _draw_pile(bone: Color, shade: Color, a: float) -> void:
	# Montón de huesos que tiembla cuando está a punto de levantarse
	# A pile of bones that shakes when it's about to rise again
	var shake := Vector2(randf_range(-2, 2), 0) * (1.0 - clampf(_revive_t / 1.5, 0.0, 1.0))
	draw_set_transform(shake, 0.0, Vector2.ONE)
	for i in 6:
		var ang := i * 1.1 + _phase
		var c := Vector2(cos(ang) * 14.0, -4 + sin(ang) * 4.0)
		draw_line(c - Vector2.from_angle(ang * 2.0) * 10.0, c + Vector2.from_angle(ang * 2.0) * 10.0, Color(bone if i % 2 else shade, a), 4.0, true)
	draw_colored_polygon(_ellipse(Vector2(4, -12), Vector2(11, 10)), Color(bone, a))
	draw_circle(Vector2(1, -12), 3.0, Color(0.08, 0.05, 0.15, a))
	draw_circle(Vector2(8, -12), 3.0, Color(0.08, 0.05, 0.15, a))
	# Cuenta atrás: un anillo que se cierra / Countdown: a ring that closes
	var k := clampf(_revive_t / REVIVE_TIME, 0.0, 1.0)
	draw_arc(Vector2(0, -10), 24.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Color(EYES, 0.7 * a), 2.0, true)


func _ellipse(c: Vector2, r: Vector2, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts
