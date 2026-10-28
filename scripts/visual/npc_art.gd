class_name NpcArt
extends RefCounted
## Dibuja a los personajes del plano astral: Svinho, Stolk y Silly.
## Mismo lienzo que Kroker (200 x 300, pies en y = 288) y la misma luz suave.
## Draws the astral plane characters: Svinho, Stolk and Silly.
## Same canvas as Kroker (200 x 300, feet at y = 288) and the same soft light.

const RIM := Color("cbd6ff")
const SHADE := Color(0.12, 0.08, 0.32, 0.22)

static var _ci: CanvasItem
static var _xf: Transform2D


static func draw(ci: CanvasItem, xf: Transform2D, who: String, t: float) -> void:
	_ci = ci
	var breath := 1.0 + sin(t * 1.6) * 0.01
	_xf = xf * Transform2D(0.0, Vector2(1.0, breath), 0.0, Vector2(0, 288.0 * (1.0 - breath)))
	_ci.draw_set_transform_matrix(_xf)
	match who:
		"svinho": _svinho(t)
		"stolk": _stolk(t)
		"silly": _silly(t)
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Svinho: futbolista brasileño / Brazilian footballer ----------------------

static func _svinho(t: float) -> void:
	var skin := Color("b97c56")
	var shade := Color("8f5c45")
	# Piernas, medias y botas / Legs, socks and boots
	for x in [82.0, 104.0]:
		_ci.draw_rect(Rect2(x, 196, 16, 40), skin)
		_ci.draw_rect(Rect2(x - 1, 232, 18, 44), Color("f4f1ea"))
		_ci.draw_rect(Rect2(x - 1, 240, 18, 4), Color("2f9e5b"))
		_ci.draw_colored_polygon(_ellipse(Vector2(x + 9, 282), Vector2(13, 6)), Color("1e1f2e"))
	# Pantalón azul / Blue shorts
	_shape(PackedVector2Array([Vector2(74, 168), Vector2(126, 168), Vector2(128, 204), Vector2(102, 204), Vector2(100, 190), Vector2(98, 204), Vector2(72, 204)]), Color("2b4fa8"))
	# Brazos / Arms
	_shape(PackedVector2Array([Vector2(62, 104), Vector2(76, 108), Vector2(72, 168), Vector2(58, 166)]), skin)
	_shape(PackedVector2Array([Vector2(138, 104), Vector2(124, 108), Vector2(128, 168), Vector2(142, 166)]), shade)
	_ci.draw_colored_polygon(_ellipse(Vector2(65, 172), Vector2(7, 8)), skin)
	_ci.draw_colored_polygon(_ellipse(Vector2(135, 172), Vector2(7, 8)), shade)
	# Camiseta amarilla con el 10 / Yellow shirt with number 10
	var shirt := PackedVector2Array([Vector2(82, 96), Vector2(118, 96), Vector2(140, 106), Vector2(136, 130), Vector2(128, 128), Vector2(128, 172), Vector2(72, 172), Vector2(72, 128), Vector2(64, 130), Vector2(60, 106)])
	_shape(shirt, Color("f6d24a"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(112, 100), Vector2(140, 106), Vector2(136, 130), Vector2(128, 128), Vector2(128, 172), Vector2(112, 172)]), SHADE)
	_ci.draw_polyline(PackedVector2Array([Vector2(88, 97), Vector2(100, 110), Vector2(112, 97)]), Color("2f9e5b"), 4.0, true)
	_ci.draw_line(Vector2(60, 106), Vector2(64, 130), Color("2f9e5b"), 3.0)
	_ci.draw_line(Vector2(140, 106), Vector2(136, 130), Color("2f9e5b"), 3.0)
	_ci.draw_string(UITheme.font("caps"), Vector2(87, 152), "10", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("2f9e5b"))
	# Cabeza / Head
	_ci.draw_rect(Rect2(93, 82, 14, 16), shade)
	_shape(_ellipse(Vector2(100, 60), Vector2(22, 26)), skin)
	# Pelo rizado / Curly hair
	for p in [Vector2(82, 44), Vector2(92, 36), Vector2(104, 34), Vector2(116, 40), Vector2(122, 52), Vector2(78, 56), Vector2(98, 40), Vector2(110, 44)]:
		_ci.draw_circle(p, 9, Color("1d1620"))
	_face(skin, Color("2a1d22"), 1)
	# Balón botando / Bouncing ball
	var bounce := absf(sin(t * 3.2))
	var ball := Vector2(150, 274 - bounce * 40.0)
	_ci.draw_colored_polygon(_ellipse(Vector2(150, 286), Vector2(12 - bounce * 4.0, 3)), Color(0, 0, 0, 0.25))
	_ci.draw_circle(ball, 13, Color("f7f3ea"))
	_ci.draw_colored_polygon(_pentagon(ball, 5.0, t * 3.0), Color("1e1f2e"))


# --- Stolk: el matón del colegio / The school bully ---------------------------

static func _stolk(t: float) -> void:
	var skin := Color("f0c4aa")
	var shade := Color("c99a8e")
	# Piernas y zapatillas / Legs and trainers
	for x in [74.0, 104.0]:
		_shape(_rect(Rect2(x, 186, 24, 90)), Color("3b4a7a"))
		_ci.draw_colored_polygon(_ellipse(Vector2(x + 12, 282), Vector2(17, 7)), Color("e9e6f2"))
	_ci.draw_colored_polygon(_rect(Rect2(104, 186, 24, 90)), SHADE)
	# Sudadera roja ancha / Wide red hoodie
	var hoodie := PackedVector2Array([Vector2(78, 94), Vector2(122, 94), Vector2(150, 108), Vector2(146, 190), Vector2(54, 190), Vector2(50, 108)])
	_shape(hoodie, Color("b9474f"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(118, 96), Vector2(150, 108), Vector2(146, 190), Vector2(118, 190)]), SHADE)
	_ci.draw_rect(Rect2(54, 178, 92, 12), Color("8f343c"))
	# Capucha detrás del cuello / Hood behind the neck
	_ci.draw_colored_polygon(_ellipse(Vector2(100, 96), Vector2(30, 10)), Color("8f343c"))
	# Brazos cruzados / Crossed arms
	_shape(PackedVector2Array([Vector2(52, 112), Vector2(70, 110), Vector2(130, 140), Vector2(128, 156), Vector2(60, 140)]), Color("c4545c"))
	_shape(PackedVector2Array([Vector2(148, 112), Vector2(130, 110), Vector2(70, 146), Vector2(74, 160), Vector2(142, 140)]), Color("a83e46"))
	_ci.draw_circle(Vector2(130, 148), 9, skin)
	_ci.draw_circle(Vector2(70, 152), 9, shade)
	# Cabeza con pelo rapado / Head with a buzz cut
	_ci.draw_rect(Rect2(90, 80, 20, 16), shade)
	_shape(_ellipse(Vector2(100, 58), Vector2(25, 27)), skin)
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(76, 52), Vector2(80, 38), Vector2(94, 30), Vector2(108, 30), Vector2(120, 38), Vector2(124, 52), Vector2(116, 44), Vector2(84, 44)]), Color("8a6a52"))
	_face(skin, Color("3a2a30"), 2)
	# Tirita en la mejilla / Plaster on the cheek
	_ci.draw_set_transform_matrix(_xf * Transform2D(-0.4, Vector2(114, 72)))
	_ci.draw_rect(Rect2(-8, -3, 16, 6), Color("f2d4a6"))
	_ci.draw_set_transform_matrix(_xf)
	# Aura roja que late / Pulsing red aura
	_ci.draw_arc(Vector2(100, 150), 90 + sin(t * 3.0) * 4.0, 0, TAU, 48, Color("ff7a8a", 0.12), 3.0, true)


# --- Silly: la hacker / The hacker ---------------------------------------------

static func _silly(t: float) -> void:
	var skin := Color("f4d2c0")
	var shade := Color("caa8b4")
	# Piernas con mallas y zapatillas / Legs in leggings and trainers
	for x in [82.0, 102.0]:
		_shape(_rect(Rect2(x, 186, 16, 90)), Color("272a48"))
		_ci.draw_colored_polygon(_ellipse(Vector2(x + 8, 282), Vector2(12, 6)), Color("5ff2ff"))
	# Sudadera enorme con código que brilla / Oversized hoodie with glowing code
	var hoodie := PackedVector2Array([Vector2(80, 96), Vector2(120, 96), Vector2(144, 110), Vector2(142, 196), Vector2(58, 196), Vector2(56, 110)])
	_shape(hoodie, Color("2b2f5a"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(116, 98), Vector2(144, 110), Vector2(142, 196), Vector2(116, 196)]), SHADE)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 6.0)
	for row in 7:
		var y := 118.0 + row * 10.0
		var x := 66.0 + rng.randf_range(0, 10)
		while x < 132.0:
			var w := rng.randf_range(4, 12)
			_ci.draw_line(Vector2(x, y), Vector2(x + w, y), Color("7dffb0", rng.randf_range(0.2, 0.7)), 2.0)
			x += w + rng.randf_range(3, 8)
	# Portátil abierto que le ilumina la cara / Open laptop lighting up her face
	_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(40, 60, 120, 140), false, Color("5ff2ff", 0.18))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(66, 150), Vector2(134, 150), Vector2(128, 168), Vector2(72, 168)]), Color("3c4170"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(70, 120), Vector2(130, 120), Vector2(134, 150), Vector2(66, 150)]), Color("1a1d38"))
	_ci.draw_colored_polygon(PackedVector2Array([Vector2(74, 124), Vector2(126, 124), Vector2(129, 146), Vector2(71, 146)]), Color("5ff2ff", 0.55 + 0.15 * sin(t * 5.0)))
	# Manos sobre el teclado / Hands on the keyboard
	_ci.draw_circle(Vector2(82, 160 + sin(t * 18.0) * 1.5), 7, skin)
	_ci.draw_circle(Vector2(118, 160 + cos(t * 17.0) * 1.5), 7, shade)
	# Cabeza / Head
	_ci.draw_rect(Rect2(93, 82, 14, 16), shade)
	_shape(_ellipse(Vector2(100, 62), Vector2(22, 26)), skin)
	# Melena corta morada con flequillo / Short purple bob with bangs
	var hair := PackedVector2Array([Vector2(74, 80), Vector2(74, 50), Vector2(84, 36), Vector2(100, 31), Vector2(116, 36), Vector2(126, 50), Vector2(126, 80),
		Vector2(118, 80), Vector2(118, 56), Vector2(110, 54), Vector2(100, 58), Vector2(90, 54), Vector2(82, 58), Vector2(82, 80)])
	_ci.draw_colored_polygon(hair, Color("8a5bd6"))
	_ci.draw_polyline(PackedVector2Array([Vector2(84, 42), Vector2(98, 36)]), Color("c7a6ff"), 2.0, true)
	_face(skin, Color("2a2238"), 3)
	# Cascos al cuello / Headphones around her neck
	_ci.draw_arc(Vector2(100, 96), 18, 0.2, PI - 0.2, 16, Color("5ff2ff"), 4.0, true)
	_ci.draw_circle(Vector2(82, 98), 7, Color("3c4170"))
	_ci.draw_circle(Vector2(118, 98), 7, Color("3c4170"))


# --- Utilidades / Helpers -----------------------------------------------------

## Cara: 1 sonrisa abierta, 2 ceño fruncido y media sonrisa, 3 sonrisa pícara
## Face: 1 open smile, 2 frown and smirk, 3 cheeky smile
static func _face(skin: Color, ink: Color, mood: int) -> void:
	var blink := fposmod(Time.get_ticks_msec() / 1000.0 + mood, 4.1) < 0.12
	for x in [91.0, 109.0]:
		if blink:
			_ci.draw_line(Vector2(x - 3, 62), Vector2(x + 3, 62), ink, 1.8)
		else:
			_ci.draw_colored_polygon(_ellipse(Vector2(x, 62), Vector2(2.6, 3.2), 12), ink)
			_ci.draw_circle(Vector2(x - 0.8, 61), 0.9, Color(1, 1, 1, 0.9))
	match mood:
		1:
			_ci.draw_line(Vector2(85, 53), Vector2(96, 52), ink, 2.0)
			_ci.draw_line(Vector2(104, 52), Vector2(115, 53), ink, 2.0)
			_ci.draw_colored_polygon(PackedVector2Array([Vector2(92, 74), Vector2(108, 74), Vector2(100, 81)]), Color("7d4a5e"))
		2:
			_ci.draw_line(Vector2(84, 52), Vector2(96, 56), ink, 2.6)
			_ci.draw_line(Vector2(104, 56), Vector2(116, 52), ink, 2.6)
			_ci.draw_polyline(PackedVector2Array([Vector2(92, 77), Vector2(102, 77), Vector2(108, 74)]), Color("8a5662"), 2.0, true)
		3:
			_ci.draw_line(Vector2(86, 54), Vector2(96, 55), ink, 1.8)
			_ci.draw_line(Vector2(104, 54), Vector2(114, 52), ink, 1.8)
			_ci.draw_polyline(PackedVector2Array([Vector2(94, 76), Vector2(100, 78), Vector2(107, 74)]), Color("a3687a"), 1.8, true)
	_ci.draw_line(Vector2(101, 64), Vector2(102, 70), Color(skin.darkened(0.25), 0.8), 1.5)


static func _shape(pts: PackedVector2Array, fill: Color) -> void:
	_ci.draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2(-1.6, -1.0)))
	_ci.draw_colored_polygon(pts, Color(RIM, 0.55))
	_ci.draw_set_transform_matrix(_xf)
	_ci.draw_colored_polygon(pts, fill)


static func _rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


static func _pentagon(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(c + Vector2.from_angle(rot + TAU * i / 5.0) * r)
	return pts
