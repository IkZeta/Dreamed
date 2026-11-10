class_name Botcher
extends Enemy
## Chapuzas (desde el Sueño 7): un obrero de sueño con casco que va corriendo al agujero más
## cercano y lo tapa con un tablón mal clavado. Mientras siga en pie, por ese agujero no cae
## nadie. No ataca y huye de Kroker sin alejarse de su obra. Tiene poca vida, y se le puede
## tirar por OTRO agujero: entonces el tablón se suelta.
## Botcher (from Dream 7): a hard-hatted dream worker who runs to the nearest hole and covers it
## with a badly nailed plank. While he stands, nobody falls down that hole. He doesn't attack and
## flees from Kroker without straying from his work. Low health, and he can be shoved down
## ANOTHER hole: then the plank comes loose.

const WORK_TIME := 1.4       # martillazos hasta tapar el agujero / hammering until the hole is covered
const KEEP_AWAY := 260.0
const LEASH := 170.0         # cuánto se aleja de su tablón / how far he strays from his plank
const HAT := Color("ffc93a")
const VEST := Color("ff7a3a")
const FUR := Color("8b7bb8")
const WOOD := Color("b98552")

## Agujero que tapa (en el mundo) / Hole he covers (in the world)
var hole := Rect2()
var covered := false
var _work := 0.0
var _hammer := 0.0
var _plank: BotcherPlank


func _init() -> void:
	bestiary_id = "botcher"
	max_hp = 26.0
	hp = max_hp
	contact_damage = 0.0
	radius = 22.0
	speed = 120.0
	mass = 1.2
	aim_height = 30.0
	shards = 3


func is_dangerous() -> bool:
	return false


## ¿Está tapando este agujero? / Is he covering this hole?
func covers(world_rect: Rect2) -> bool:
	return covered and state == State.ALIVE and hole.is_equal_approx(world_rect)


func _desired_velocity() -> Vector2:
	var me := global_position
	var to_player: Vector2 = me - run.player.global_position
	if covered:
		# Huye de Kroker sin alejarse mucho de su tablón / Flees Kroker without straying far from the plank
		var c := hole.get_center()
		var v := Vector2.ZERO
		if to_player.length() < KEEP_AWAY:
			v += to_player.normalized()
		if me.distance_to(c) > LEASH:
			v += (c - me).normalized() * 1.2
		return v.normalized() * speed * 0.8 if v != Vector2.ZERO else Vector2.ZERO
	if hole.size == Vector2.ZERO or run.hole_covered(hole):
		hole = _pick_hole()
		_work = 0.0
	if hole.size == Vector2.ZERO:
		return to_player.normalized() * speed * 0.6 if to_player.length() < KEEP_AWAY else Vector2.ZERO
	var spot := _work_spot()
	if me.distance_to(spot) < 16.0:
		return Vector2.ZERO
	return (spot - me).normalized() * speed


## Se pone al lado del agujero que da hacia él / Stands at the side of the hole facing him
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
	_hammer = maxf(0.0, _hammer - delta * 4.0)
	if covered or hole.size == Vector2.ZERO:
		return
	if global_position.distance_to(_work_spot()) > 20.0:
		_work = maxf(0.0, _work - delta)
		return
	_facing = signf(hole.get_center().x - global_position.x)
	var before := int(_work / 0.35)
	_work += delta
	if int(_work / 0.35) > before:
		_hammer = 1.0
		Audio.play("pin", -12.0, 0.15)
		run.fx.text(global_position + Vector2(_facing * 30.0, -70.0), tr("BOTCHER_TAP"), WOOD, 16)
	if _work >= WORK_TIME:
		_cover()


func _cover() -> void:
	covered = true
	_plank = BotcherPlank.new()
	_plank.owner_botcher = self
	_plank.rect = hole
	run.fx.get_parent().add_child(_plank)
	run.fx.get_parent().move_child(_plank, run.room.get_index() + 1)
	run.fx.ring(hole.get_center(), 50.0, WOOD, 0.4, 2.4)
	Audio.play("pan_clang", -10.0, 0.1)


func _death_sound() -> void:
	Audio.play("pan_clang", -8.0, 0.15)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash, a) * tint
	draw_colored_polygon(_oval(Vector2.ZERO, Vector2(24, 7)), Color(0.05, 0.02, 0.15, 0.35 * a))
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	var bob := absf(sin(_t * 10.0)) * 3.0 if not covered else 0.0
	var o := Vector2(0, -bob)
	# Tablón a la espalda mientras no lo ha puesto / Plank on his back until he's put it down
	if not covered:
		_px(Rect2(-34, -66, 14, 58) , WOOD.darkened(0.15), mod, o)
		_px(Rect2(-32, -62, 10, 4), WOOD.lightened(0.2), mod, o)
		_px(Rect2(-32, -30, 10, 4), WOOD.lightened(0.2), mod, o)
	# Patas y cuerpo de peluche / Legs and plush body
	_px(Rect2(-14, -12, 10, 12), FUR.darkened(0.3), mod, o)
	_px(Rect2(4, -12, 10, 12), FUR.darkened(0.3), mod, o)
	_px(Rect2(-20, -44, 40, 34), FUR, mod, o)
	# Chaleco con banda reflectante / Vest with a reflective stripe
	_px(Rect2(-20, -40, 40, 22), VEST, mod, o)
	_px(Rect2(-20, -30, 40, 4), Color("fff3c0"), mod, o)
	# Cabeza, hocico y ojo / Head, snout and eye
	_px(Rect2(-16, -66, 34, 24), FUR.lightened(0.1), mod, o)
	_px(Rect2(14, -56, 10, 10), Color("e9b6c8"), mod, o)
	_px(Rect2(6, -60, 4, 4), Color("1a1430"), mod, o)
	# Casco / Hard hat
	_px(Rect2(-18, -76, 36, 12), HAT, mod, o)
	_px(Rect2(-22, -66, 44, 4), HAT.darkened(0.2), mod, o)
	_px(Rect2(-4, -80, 8, 4), HAT.lightened(0.25), mod, o)
	# Martillo que golpea / Hammer that strikes
	var ang := -0.9 + _hammer * 1.4
	draw_set_transform(offset + o + Vector2(18 * _facing, -34).rotated(0.0), 0.0, Vector2(_facing, 1.0))
	var rot := Transform2D(ang, Vector2.ZERO)
	var handle := PackedVector2Array([rot * Vector2(-2, 0), rot * Vector2(2, 0), rot * Vector2(2, -26), rot * Vector2(-2, -26)])
	draw_colored_polygon(handle, WOOD.darkened(0.3) * mod)
	var head := PackedVector2Array([rot * Vector2(-8, -24), rot * Vector2(10, -24), rot * Vector2(10, -32), rot * Vector2(-8, -32)])
	draw_colored_polygon(head, Color("9aa3b8") * mod)
	draw_set_transform(Vector2.ZERO)


func _px(r: Rect2, col: Color, mod: Color, o: Vector2) -> void:
	draw_rect(Rect2(r.position + o, r.size), col * mod)


func head_top() -> Vector2:
	return Vector2(0, -84)


func _oval(c: Vector2, r: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts
