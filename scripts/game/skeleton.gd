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
	var mod := Sprites.flash_color(_flash, a) * tint
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	draw_colored_polygon(_ellipse(Vector2(0, 0), Vector2(24, 7)), Color(0.05, 0.02, 0.15, 0.4 * a))
	if _rise <= 0.02:
		_draw_pile(mod, a)
		return
	# Se levanta desde el suelo / Rises from the ground
	var base := Transform2D((1.0 - _rise) * 0.6, Vector2(_facing, _rise), 0.0, offset + Vector2(0, (1.0 - _rise) * 40.0))
	draw_set_transform_matrix(base)
	var walk := sin(_t * 10.0 + _phase)
	# Piernas / Legs
	for side in [-1.0, 1.0]:
		var hip := Vector2(side * 7, -40)
		var knee := hip + Vector2(side * 2 + walk * side * 5, 18)
		_bone(base, hip, knee, mod)
		_bone(base, knee, knee + Vector2(0, 20), mod)
		_bone(base, knee + Vector2(0, 20), knee + Vector2(8, 22), mod)
	draw_set_transform_matrix(base)
	Sprites.draw(self, "skel_pelvis", mod)
	Sprites.draw(self, "skel_ribs", mod)
	# Brazos estirados hacia delante / Arms reaching forward
	for side in [-1.0, 1.0]:
		var sh := Vector2(side * 12, -80)
		var el := sh + Vector2(14, 10 + side * 4)
		_bone(base, sh, el, mod)
		_bone(base, el, el + Vector2(16, -2 + walk * 3.0), mod)
	draw_set_transform_matrix(base)
	Sprites.draw(self, "skel_skull", mod)
	for x in [-3.0, 8.0]:
		draw_rect(Rect2(x - 1.5, -99.5, 3, 3), Color(EYES, a))


## Un hueso de p1 a p2 (el sprite mide 20) / A bone from p1 to p2 (the sprite is 20 long)
func _bone(base: Transform2D, p1: Vector2, p2: Vector2, mod: Color) -> void:
	var d := p2 - p1
	draw_set_transform_matrix(base * Transform2D(d.angle(), Vector2(d.length() / 20.0, 1.0), 0.0, p1))
	Sprites.draw(self, "skel_bone", mod)


func _draw_pile(mod: Color, a: float) -> void:
	# Montón de huesos que tiembla cuando está a punto de levantarse
	# A pile of bones that shakes when it's about to rise again
	var shake := Vector2(randf_range(-2, 2), 0) * (1.0 - clampf(_revive_t / 1.5, 0.0, 1.0))
	draw_set_transform(shake, 0.0, Vector2.ONE)
	Sprites.draw(self, "skel_pile", mod)
	# Cuenta atrás: un anillo que se cierra / Countdown: a ring that closes
	var k := clampf(_revive_t / REVIVE_TIME, 0.0, 1.0)
	draw_arc(Vector2(0, -10), 24.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Color(EYES, 0.7 * a), 2.0)


func _ellipse(c: Vector2, r: Vector2, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts
