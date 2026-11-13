class_name HubLunaDummy
extends RefCounted
## La práctica de la isla de Luna: un marciano hinchable de juguete. Kroker lo empuja al andar
## contra él y, con la gravedad baja, sale flotando a saltitos lentos; rebota en los bordes de la
## isla y en las cosas, y si cae dentro de un cráter se hunde girando con un «plof», Luna lo cuenta
## por radio y a los dos segundos el muñeco sale disparado de vuelta a su sitio. Lleva la cuenta
## de las veces (Progress.stats["luna_dummy"]).
## Luna's island practice: a toy inflatable Martian. Kroker pushes it by walking into it and, with
## the low gravity, it drifts off in slow little hops; it bounces off the island's edges and the
## props, and if it lands inside a crater it sinks spinning with a "plop", Luna counts it over the
## radio and two seconds later the dummy shoots back out to its spot. It keeps count of the times
## (Progress.stats["luna_dummy"]).

## Cráteres del suelo (de tools/make_hub.py floor_moon): centro en el suelo y radios de la elipse
## Floor craters (from tools/make_hub.py floor_moon): centre on the floor and ellipse radii
const CRATERS := [
	[Vector2(-52, 30), Vector2(30, 15)],
	[Vector2(34, 10), Vector2(11, 6.5)],
	[Vector2(96, -18), Vector2(8, 4.7)],
	[Vector2(-6, -44), Vector2(7, 4.1)],
	[Vector2(66, 44), Vector2(7, 4.1)],
	[Vector2(-112, 26), Vector2(6, 3.5)],
]
## Los props van unos 18 px más abajo que el dibujo del suelo / Props sit about 18 px below the floor drawing
const FLOOR_TO_PROP := Vector2(0, 18)
const HOME := Vector2(-30, 8)
const GRAVITY := 170.0
const PUSH := 125.0
const HOP := 55.0
const TOUCH := 20.0
const BODY := Color("8fe07a")
const BODY_DARK := Color("4fae4a")
const INK := Color("1a1024")

var hub: HubWorld
var prop: Node2D
var _c := Vector2.ZERO
var _vel := Vector2.ZERO
var _h := 0.0
var _vh := 0.0
var _spin := 0.0
var _state := 0           # 0 suelto, 1 cayendo, 2 dentro / 0 loose, 1 falling, 2 inside
var _st := 0.0
var _crater := Vector2.ZERO
var _last_k := Vector2.INF
var _say := ""
var _say_t := 0.0


func _init(world: HubWorld, centre: Vector2) -> void:
	hub = world
	_c = centre
	prop = hub._prop(centre + HOME, paint)


func tick(delta: float) -> void:
	_say_t = maxf(0.0, _say_t - delta)
	var kv := Vector2.ZERO
	if _last_k != Vector2.INF:
		kv = (hub._pos - _last_k) / maxf(delta, 0.0001)
	_last_k = hub._pos
	match _state:
		1:
			# Se hunde en el cráter girando / Sinks into the crater, spinning
			_st += delta
			prop.position = prop.position.lerp(_crater, minf(1.0, delta * 10.0))
			_spin += delta * 14.0
			if _st > 0.55:
				_state = 2
				_st = 0.0
		2:
			# Dentro; al rato sale disparado hacia casa / Inside; after a while it shoots out towards home
			_st += delta
			if _st > 1.6:
				_state = 0
				var home := _c + HOME
				_h = 1.0
				_vh = 230.0
				_vel = (home - prop.position) / (2.0 * _vh / GRAVITY)
				_spin = 0.0
				Audio.play("puff", -10.0, 0.1, 1.2)
		_:
			_loose(delta, kv)


func _loose(delta: float, kv: Vector2) -> void:
	var p := prop.position
	# Empujón al chocar Kroker contra él / A shove when Kroker bumps into it
	if _h < 14.0 and hub._pos.distance_to(p) < TOUCH and kv.length() > 30.0:
		var away := (p - hub._pos).normalized()
		if away == Vector2.ZERO:
			away = kv.normalized()
		_vel = (away * 0.6 + kv.normalized() * 0.4).normalized() * PUSH
		_vh = HOP
		_h = maxf(_h, 0.5)
		Audio.play("rubber", -14.0, 0.15, 1.4)
	# Vuelo lento por la gravedad baja / Slow flight in the low gravity
	if _h > 0.0 or _vh > 0.0:
		_vh -= GRAVITY * delta
		_h += _vh * delta
		if _h <= 0.0:
			_h = 0.0
			if absf(_vh) > 60.0:
				# Rebotito al tocar el suelo / A little bounce on landing
				_vh = -_vh * 0.35
				_h = 0.01
			else:
				_vh = 0.0
	var drag := 0.5 if _h > 0.0 else 3.2
	_vel *= exp(-drag * delta)
	if _vel.length() < 4.0 and _h <= 0.0:
		_vel = Vector2.ZERO
	_spin += _vel.x * delta * 0.02
	_spin = lerpf(_spin, 0.0, minf(1.0, delta * (1.0 if _h > 0.0 else 4.0)))
	if _vel != Vector2.ZERO:
		var next := p + _vel * delta
		if _free(next):
			p = next
		else:
			# Rebota en el borde o en la cosa / Bounces off the edge or the prop
			var nx := Vector2(next.x, p.y)
			var ny := Vector2(p.x, next.y)
			if _free(nx):
				_vel.y = -_vel.y * 0.6
				p = nx
			elif _free(ny):
				_vel.x = -_vel.x * 0.6
				p = ny
			else:
				_vel = -_vel * 0.6
		prop.position = p
	# ¿Ha caído en un cráter? / Did it land in a crater?
	if _h < 3.0:
		for cr: Array in CRATERS:
			var cc: Vector2 = _c + Vector2(cr[0]) + FLOOR_TO_PROP
			var rr: Vector2 = cr[1]
			if ((p - cc) / rr).length() < 1.0:
				_fall(cc)
				return


func _free(p: Vector2) -> bool:
	if not hub._walk_polys.has("luna") or not Geometry2D.is_point_in_polygon(p, hub._walk_polys["luna"]):
		return false
	for b: Dictionary in hub._blocks:
		if ((p - Vector2(b["c"])) / Vector2(b["r"])).length() < 1.0:
			return false
	return true


func _fall(at: Vector2) -> void:
	_state = 1
	_st = 0.0
	_crater = at
	_vel = Vector2.ZERO
	_h = 0.0
	_vh = 0.0
	Audio.play("hole_fall", -10.0, 0.08)
	var n := int(Progress.stats.get("luna_dummy", 0)) + 1
	Progress.stats["luna_dummy"] = n
	Progress.save_progress()
	_say = tr("HUB_LUNA_DUMMY") % n
	_say_t = 2.4


func paint(ci: CanvasItem) -> void:
	# Cuenta de Luna por radio / Luna's radio count
	if _say_t > 0.0:
		var a := minf(1.0, _say_t * 2.0)
		var at := Vector2(0, -64) if _state != 0 else Vector2(0, -64 - _h)
		var font := UITheme.font()
		var w := font.get_string_size(_say, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		UITheme.ink_text(ci, font, at + Vector2(-w * 0.5, 0), _say, 12, Color(Color("c9d4ff"), a), 1, Color(INK, a))
	if _state == 2:
		# Solo asoman las antenas temblando / Only the antennae poke out, trembling
		var wob := sin(_st * 20.0) * 1.5
		for side: float in [-1.0, 1.0]:
			var tip := Vector2(side * 4.0 + wob, -9.0 - minf(1.0, _st * 2.0) * 4.0)
			ci.draw_line(Vector2(side * 2.0, -1), tip, INK, 2.0)
			ci.draw_circle(tip, 2.6, INK)
			ci.draw_circle(tip, 1.8, Color("ffd36b"))
		return
	var shrink := 1.0 - (_st / 0.55) * 0.85 if _state == 1 else 1.0
	# Sombra que se aleja con la altura / Shadow shrinking with height
	var sk := clampf(1.0 - _h / 120.0, 0.4, 1.0) * shrink
	ci.draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(11, 3.5) * sk), Color(0, 0, 0, 0.28 * sk))
	ci.draw_set_transform(Vector2(0, -_h).round(), _spin, Vector2.ONE * shrink)
	var sq := 1.0 + clampf(-_vh / 600.0, -0.12, 0.12)
	# Cuerpo de pera hinchable con costura / Pear-shaped inflatable body with a seam
	var body := _pear(sq)
	var out := PackedVector2Array()
	for q in body:
		out.append(q * 1.12 + Vector2(0, 1.5))
	ci.draw_colored_polygon(out, INK)
	ci.draw_colored_polygon(body, BODY)
	ci.draw_colored_polygon(_ellipse(Vector2(3, -6), Vector2(5, 7)), BODY_DARK)
	ci.draw_colored_polygon(_ellipse(Vector2(-4, -17), Vector2(3, 4)), Color(1, 1, 1, 0.45))
	ci.draw_line(Vector2(0, -24 * sq), Vector2(0, -1), Color(BODY_DARK, 0.7), 1.0)
	# Tres ojos de botón y una sonrisa / Three button eyes and a smile
	for e: Vector2 in [Vector2(-5, -15), Vector2(5, -15), Vector2(0, -20)]:
		ci.draw_circle(e * Vector2(1, sq), 3.0, INK)
		ci.draw_circle(e * Vector2(1, sq), 2.2, Color("f7f2ea"))
		ci.draw_circle(e * Vector2(1, sq) + Vector2(0.6, 0.4), 1.0, INK)
	ci.draw_arc(Vector2(0, -9 * sq), 4.0, 0.3, PI - 0.3, 6, INK, 1.2)
	# Antenas con bolitas / Antennae with bobbles
	var wob := sin(hub._t * 6.0) * 1.5 + _vel.x * 0.01
	for side: float in [-1.0, 1.0]:
		var base := Vector2(side * 4.0, -25.0 * sq)
		var tip := base + Vector2(side * 4.0 + wob, -8.0)
		ci.draw_line(base, tip, INK, 2.0)
		ci.draw_circle(tip, 2.6, INK)
		ci.draw_circle(tip, 1.8, Color("ffd36b"))
	# Válvula de hinchar / The inflation valve
	ci.draw_rect(Rect2(7, -6, 3, 3), INK)
	ci.draw_rect(Rect2(7.5, -5.5, 2, 2), Color("f2f0f8"))
	ci.draw_set_transform(Vector2.ZERO)


func _pear(sq: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		var r := 11.0 - 3.5 * maxf(0.0, -sin(a))
		pts.append(Vector2(cos(a) * r, -13.0 * sq + sin(a) * 13.0 * sq))
	return pts


static func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
