class_name Botcher
extends Enemy
## Chapuzas (desde el Sueño 7): un topo ingeniero steampunk que va corriendo al agujero más
## cercano, lo tapa con tablones y monta encima una torreta de latón. Mientras la torreta siga
## en pie, por ese agujero no cae nadie; al romperla, los tablones se vienen abajo. Él no ataca:
## huye de Kroker y, al rato, va a montar otra. No se le puede tirar por los agujeros (se agarra
## con las garras): hay que acabar con él a golpes.
## Botcher (from Dream 7): a steampunk mole engineer who runs to the nearest hole, boards it up
## and mounts a brass turret on top. While the turret stands, nobody falls down that hole; break
## it and the planks give way. He doesn't attack: he flees from Kroker and, after a while, goes
## off to build another. He can't be thrown down holes (he hangs on with his claws): you have to
## beat him down.

const WORK_TIME := 1.6       # trabajo hasta montar la torreta / work until the turret is up
const REBUILD := 7.0         # descanso entre torreta y torreta / rest between turrets
const MAX_OWN := 2           # torretas suyas a la vez / his turrets at once
const MAX_ALL := 3           # torretas en total / turrets in total
const KEEP_AWAY := 260.0
const FUR := Color("5a4636")
const SKIN := Color("f2a0b4")
const LEATHER := Color("8a5a34")
const BRASS := Color("d9a441")
const COPPER := Color("b8673a")
const STEEL := Color("9aa3b8")
const WOOD := Color("b98552")

## Agujero en el que trabaja (en el mundo) / Hole he's working on (in the world)
var hole := Rect2()
var turrets: Array[BotcherTurret] = []
var _work := 0.0
var _swing := 0.0
var _rest := 0.0


func _init() -> void:
	bestiary_id = "botcher"
	max_hp = 40.0
	hp = max_hp
	contact_damage = 0.0
	radius = 22.0
	speed = 120.0
	mass = 1.6
	aim_height = 30.0
	shards = 4


func is_dangerous() -> bool:
	return false


## Se agarra al borde con las garras: no cae / Grips the edge with his claws: doesn't fall
func can_fall() -> bool:
	return false


func _alive_turrets() -> int:
	var n := 0
	for t in turrets:
		if is_instance_valid(t) and t.state != State.DYING:
			n += 1
	return n


func _wants_to_build() -> bool:
	return _rest <= 0.0 and _alive_turrets() < MAX_OWN and run.count_turrets() < MAX_ALL


func _desired_velocity() -> Vector2:
	var me := global_position
	var to_player: Vector2 = me - run.player.global_position
	var flee := to_player.normalized() * speed * 0.85 if to_player.length() < KEEP_AWAY else Vector2.ZERO
	if not _wants_to_build():
		hole = Rect2()
		return flee
	if hole.size == Vector2.ZERO or run.hole_covered(hole):
		hole = _pick_hole()
		_work = 0.0
	if hole.size == Vector2.ZERO:
		return flee
	var spot := _work_spot()
	if me.distance_to(spot) < 16.0:
		return Vector2.ZERO
	return (spot - me).normalized() * speed


## Se pone al lado del agujero / Stands at the side of the hole
func _work_spot() -> Vector2:
	var c := hole.get_center()
	var side := 1.0 if global_position.x >= c.x else -1.0
	return Vector2(c.x + side * (hole.size.x * 0.5 + radius + 8.0), c.y + 6.0)


func _pick_hole() -> Rect2:
	var best := Rect2()
	var list: Array[Rect2] = run.room.holes_list()
	var view: Rect2 = run.view_rect().grow(-30.0)
	for i in run.room.hole_count():
		var rc := Bedroom.rect_world(list[i])
		if not view.has_point(rc.get_center()) or run.hole_covered(rc) or run.hole_claimed(rc, self):
			continue
		if best.size == Vector2.ZERO or rc.get_center().distance_to(global_position) < best.get_center().distance_to(global_position):
			best = rc
	return best


func _act(delta: float) -> void:
	_swing = maxf(0.0, _swing - delta * 4.0)
	_rest = maxf(0.0, _rest - delta)
	if hole.size == Vector2.ZERO or not _wants_to_build():
		return
	if global_position.distance_to(_work_spot()) > 20.0:
		_work = maxf(0.0, _work - delta)
		return
	_facing = signf(hole.get_center().x - global_position.x)
	var before := int(_work / 0.4)
	_work += delta
	if int(_work / 0.4) > before:
		_swing = 1.0
		Audio.play("pin", -12.0, 0.15)
		run.fx.text(global_position + Vector2(_facing * 30.0, -80.0), tr("BOTCHER_TAP"), BRASS, 16)
	if _work >= WORK_TIME:
		_build()


func _build() -> void:
	var t := BotcherTurret.new()
	t.setup(run)
	t.elite = false
	t.hole = hole
	t.engineer = self
	t.position = hole.get_center() + Vector2(0, 8)
	run.enemies.add_child(t)
	turrets.append(t)
	run.fx.ring(hole.get_center(), 50.0, BRASS, 0.4, 2.4)
	Audio.play("pan_clang", -10.0, 0.1)
	hole = Rect2()
	_work = 0.0
	_rest = REBUILD


func _death_sound() -> void:
	Audio.play("pan_clang", -8.0, 0.15)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash, a) * tint
	draw_colored_polygon(_oval(Vector2.ZERO, Vector2(24, 7)), Color(0.05, 0.02, 0.15, 0.35 * a))
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	var moving := _work <= 0.0
	var bob := absf(sin(_t * 10.0)) * 3.0 if moving else 0.0
	var o := Vector2(0, -bob)
	var step := sin(_t * 10.0) * 3.0 if moving else 0.0
	# Mochila de latón con chimenea / Brass backpack with a little chimney
	_px(Rect2(-30, -64, 14, 30), COPPER, mod, o)
	_px(Rect2(-28, -60, 10, 4), BRASS, mod, o)
	_px(Rect2(-27, -76, 6, 12), STEEL.darkened(0.2), mod, o)
	# Piernas con botas / Legs with boots
	_px(Rect2(-12, -16 + step * 0.3, 9, 12), LEATHER.darkened(0.35), mod, o)
	_px(Rect2(4, -16 - step * 0.3, 9, 12), LEATHER.darkened(0.35), mod, o)
	_px(Rect2(-14, -6, 13, 6), Color("2a1c14"), mod, o)
	_px(Rect2(2, -6, 13, 6), Color("2a1c14"), mod, o)
	# Cuerpo peludo y delantal de cuero / Furry body and leather apron
	_px(Rect2(-18, -50, 36, 36), FUR, mod, o)
	_px(Rect2(-12, -46, 26, 32), LEATHER, mod, o)
	_px(Rect2(-12, -40, 26, 3), LEATHER.darkened(0.3), mod, o)
	_px(Rect2(-2, -32, 6, 6), BRASS, mod, o)      # hebilla / buckle
	# Cabeza de topo: hocico largo y nariz rosa / Mole head: long snout and pink nose
	_px(Rect2(-14, -72, 30, 24), FUR.lightened(0.08), mod, o)
	_px(Rect2(14, -62, 12, 9), FUR.lightened(0.18), mod, o)
	_px(Rect2(24, -63, 7, 7), SKIN, mod, o)
	_px(Rect2(6, -64, 3, 2), Color("1a1430"), mod, o)   # ojillo entornado / squinting little eye
	# Gorra de cuero con gafas de latón / Leather cap with brass goggles
	_px(Rect2(-14, -80, 28, 10), LEATHER.darkened(0.15), mod, o)
	_px(Rect2(-16, -72, 32, 3), LEATHER.darkened(0.35), mod, o)
	_px(Rect2(-4, -80, 20, 3), Color("3a2a20"), mod, o)
	draw_circle(o + Vector2(2, -79), 5.0, BRASS * mod)
	draw_circle(o + Vector2(2, -79), 3.0, Color("8fe3ff") * mod)
	draw_circle(o + Vector2(12, -79), 5.0, BRASS * mod)
	draw_circle(o + Vector2(12, -79), 3.0, Color("8fe3ff") * mod)
	# Garras / Claws
	_px(Rect2(-22, -36 + step * 0.4, 6, 10), FUR, mod, o)
	for i in 3:
		_px(Rect2(-23 + i * 2, -26 + step * 0.4, 2, 5), Color("efe6d6"), mod, o)
	# Llave inglesa que golpea / Wrench that strikes
	var ang := -1.0 + _swing * 1.5
	draw_set_transform(offset + Vector2(18 * _facing, -36) + o * Vector2(_facing, 1.0), 0.0, Vector2(_facing, 1.0))
	var rot := Transform2D(ang, Vector2.ZERO)
	var handle := PackedVector2Array([rot * Vector2(-2, 0), rot * Vector2(2, 0), rot * Vector2(2, -24), rot * Vector2(-2, -24)])
	draw_colored_polygon(handle, STEEL * mod)
	var jaw := PackedVector2Array([rot * Vector2(-7, -22), rot * Vector2(7, -22), rot * Vector2(7, -32), rot * Vector2(3, -32),
		rot * Vector2(3, -27), rot * Vector2(-3, -27), rot * Vector2(-3, -32), rot * Vector2(-7, -32)])
	draw_colored_polygon(jaw, STEEL.lightened(0.15) * mod)
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	_px(Rect2(14, -40 + step * 0.4, 7, 8), FUR, mod, o)   # mano que agarra / gripping hand
	draw_set_transform(Vector2.ZERO)


func _px(r: Rect2, col: Color, mod: Color, o: Vector2) -> void:
	draw_rect(Rect2(r.position + o, r.size), col * mod)


func head_top() -> Vector2:
	return Vector2(0, -88)


func _oval(c: Vector2, r: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts
