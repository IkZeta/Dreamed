class_name Bedroom
extends Node2D
## La habitación de Kroker, escenario del Sueño 1. Vista cenital en 3/4:
## pared del fondo con ventana a la noche estrellada y suelo de madera bañado por la luna.
## Kroker's bedroom, the stage of Dream 1. Top-down 3/4 view: back wall with a
## window onto the starry night, and a wooden floor bathed in moonlight.

## La habitación se dibuja en un lienzo propio de 1920 x 1080 y se coloca reducida en el
## centro de la pantalla, flotando en el cielo del sueño. Todas las constantes de abajo
## están en ese lienzo; usa to_world() / rect_world() para pasarlas a la pantalla.
## The room is drawn on its own 1920 x 1080 canvas and placed, scaled down, in the middle
## of the screen, floating in the dream sky. Constants below are in that canvas; use
## to_world() / rect_world() to convert them to screen space.
const S := 0.72
const OFFSET := Vector2(268.8, 176.0)

const WALL_BOTTOM := 300.0
const FLOOR_BOTTOM := 1040.0
const WALKABLE := Rect2(60, 330, 1800, 690)
const WINDOW := Rect2(800, 46, 320, 214)
const BED := Rect2(150, 236, 200, 262)
const NIGHTSTAND := Rect2(372, 246, 90, 80)
const CHEST := Rect2(500, 262, 150, 82)
const DESK := Rect2(1470, 226, 300, 104)
const SHELF := Rect2(1236, 70, 170, 226)
const RUG_CENTER := Vector2(1010, 700)
const BEDSIDE_RUG := Vector2(450, 560)

## Zonas por las que no se puede pasar / Areas nobody can walk through
const OBSTACLES: Array[Rect2] = [
	Rect2(144, 236, 212, 268),   # cama / bed
	Rect2(372, 246, 90, 88),     # mesilla / nightstand
	Rect2(500, 262, 150, 90),    # baúl de juguetes / toy chest
	Rect2(1470, 226, 300, 112),  # escritorio / desk
	Rect2(1532, 320, 92, 90),    # silla / chair
	Rect2(1800, 290, 70, 80),    # aspiradora en la esquina / vacuum in the corner
	Rect2(30, 300, 110, 70),     # cubos / blocks
]

## Agujeros que se abren en el suelo según avanza el acto (rectángulo en el lienzo de la habitación).
## Holes that open in the floor as the act goes on (rectangle on the room canvas).
const HOLES: Array[Rect2] = [
	Rect2(1300, 560, 170, 74),
	Rect2(250, 840, 160, 66),
	Rect2(1540, 860, 190, 74),
	Rect2(600, 690, 130, 56),
]

## Dónde está cada arma antes de cogerla y desde dónde la coge Kroker.
## Where each weapon rests before he takes it, and where Kroker stands to pick it up.
const PICKUP := {
	"bat": Vector2(700, 400),
	"shield": Vector2(420, 470),
	"book": Vector2(1440, 430),
	"vacuum": Vector2(1780, 440),
}
const WAKE_POINT := Vector2(440, 560)    # donde aterriza al bajar de la cama / where he lands
const START_POINT := Vector2(960, 700)   # donde empieza a jugar / where play begins


static func to_world(p: Vector2) -> Vector2:
	return OFFSET + p * S


static func rect_world(rc: Rect2) -> Rect2:
	return Rect2(to_world(rc.position), rc.size * S)

## Estado de la intro / Intro state
var bed_state := "sleeping"     # "sleeping", "sitting" o "empty"
var outfit := "bat"
var stir := 0.0                 # se revuelve en sueños / tosses in his sleep
var sit := 0.0                  # 0 tumbado → 1 sentado / lying → sitting
var stretch := 0.0              # se estira / stretches
var slide := 0.0                # se desliza hasta el borde de la cama / shuffles to the edge of the bed
var glasses_on_stand := true    # las gafas esperan en la mesilla / glasses wait on the nightstand
var weapon_taken := false
## Lo raro que está la habitación: 0 en el Sueño 1 y sube en cada sueño
## How strange the room is: 0 in Dream 1, rising with each dream
var weird := 0
## Muebles que se han levantado (jefe): no se dibujan ni bloquean el paso
## Furniture that has got up (boss): not drawn and no longer blocking the way
var gone: Array[String] = []
## Grietas generadas al empezar (paredes, muebles y suelo) / Cracks generated at start (walls, furniture, floor)
var _cracks: Array[PackedVector2Array] = []
var _flakes: Array[Dictionary] = []

var _t := 0.0
var _wall_stars: Array[Dictionary] = []
var _window_stars: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
static var _vig: GradientTexture2D


func _ready() -> void:
	z_index = -10
	position = OFFSET
	scale = Vector2(S, S)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Estrellas que proyecta la lamparita sobre la pared / Stars cast on the wall by the night-light
	for i in 46:
		_wall_stars.append({"p": Vector2(rng.randf_range(40, 1880), rng.randf_range(20, 280)),
			"r": rng.randf_range(2.0, 5.0), "ph": rng.randf() * TAU})
	for i in 60:
		_window_stars.append({"p": Vector2(rng.randf(), rng.randf()), "r": rng.randf_range(0.6, 1.8), "ph": rng.randf() * TAU})
	# Estrellitas que flotan por la habitación: el sueño empieza a colarse
	# Little stars floating around the room: the dream is starting to seep in
	for i in 18:
		_floaters.append({"p": Vector2(rng.randf_range(100, 1820), rng.randf_range(340, 1000)),
			"ph": rng.randf() * TAU, "r": rng.randf_range(3.0, 6.0)})
	for i in 40:
		_motes.append({"u": rng.randf(), "v": rng.randf(), "ph": rng.randf() * TAU, "sp": rng.randf_range(0.01, 0.03)})
	_make_cracks()


## Cuántos agujeros hay en el suelo según lo corrupto que está el sueño
## How many floor holes there are depending on how corrupted the dream is
func hole_count() -> int:
	return clampi(weird, 0, HOLES.size())


## Todo lo que no se puede atravesar: muebles y agujeros / Everything you can't walk through: furniture and holes
func blockers() -> Array[Rect2]:
	var out: Array[Rect2] = OBSTACLES.duplicate()
	if gone.has("bed"):
		out.erase(OBSTACLES[0])
	if gone.has("chest"):
		out.erase(OBSTACLES[2])
	for i in hole_count():
		out.append(HOLES[i].grow(-10))
	return out


## Grietas: líneas quebradas que crecen desde un punto. Salen más en cada sueño.
## Cracks: jagged lines growing from a point. More of them in each dream.
func _make_cracks() -> void:
	if weird <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	# Zonas donde pueden salir / Areas where they can appear
	var zones: Array[Rect2] = [
		Rect2(20, 20, 1880, 260),            # pared / wall
		Rect2(BED.position.x, BED.position.y + 90, BED.size.x, BED.size.y - 100),
		Rect2(DESK.position.x, DESK.position.y, DESK.size.x, DESK.size.y),
		Rect2(SHELF.position.x, SHELF.position.y, SHELF.size.x, SHELF.size.y),
		Rect2(60, 340, 1800, 680),           # suelo / floor
	]
	var per_zone := [4, 1, 1, 1, 3]
	for z in zones.size():
		for i in per_zone[z] * weird:
			var zone := zones[z]
			var p := Vector2(rng.randf_range(zone.position.x, zone.end.x), rng.randf_range(zone.position.y, zone.end.y))
			var ang := rng.randf() * TAU
			var line := PackedVector2Array([p])
			var length := rng.randf_range(30, 70) * (1.0 + 0.4 * weird) * (0.6 if z in [1, 2, 3] else 1.0)
			var steps := 6
			for k in steps:
				ang += rng.randf_range(-0.8, 0.8)
				p += Vector2.from_angle(ang) * length / steps
				p = Vector2(clampf(p.x, zone.position.x, zone.end.x), clampf(p.y, zone.position.y, zone.end.y))
				line.append(p)
				# Ramas pequeñas / Little branches
				if rng.randf() < 0.3:
					var b := p + Vector2.from_angle(ang + rng.randf_range(-1.6, 1.6)) * rng.randf_range(8, 20)
					_cracks.append(PackedVector2Array([p, b]))
			_cracks.append(line)
	# Trozos de pared que se desprenden y flotan / Bits of wall breaking off and floating away
	for i in weird * 5:
		_flakes.append({"p": Vector2(rng.randf_range(40, 1880), rng.randf_range(30, 270)),
			"v": rng.randf_range(6, 16), "r": rng.randf() * TAU, "s": rng.randf_range(5, 12), "ph": rng.randf() * 10.0}) 


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	_draw_wall()
	_draw_window()
	if not gone.has("shelf"):
		_draw_shelf()
	_draw_wall_decor()
	_draw_floor()
	_draw_moonbeam()
	_draw_rug()
	_draw_holes()
	# Charco de luz cálida de la lamparita / Warm pool of light from the night-light
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(220, 230, 440, 300), false, Color("ffd2a0", 0.16))
	_draw_bedside_rug()
	_draw_floor_toys()
	if not gone.has("chest"):
		_draw_toy_chest()
	_draw_desk()
	_draw_chair()
	_draw_nightstand()
	_draw_props()
	if not gone.has("bed"):
		_draw_bed()
	_draw_corruption()
	_draw_zzz()
	_draw_motes()
	_draw_dream_stars()
	_draw_floating_things()
	_draw_room_edges()


# --- Pared / Wall -----------------------------------------------------------

func _draw_wall() -> void:
	var w := minf(1.0, weird / 3.0)
	var top := Color("1d2463").lerp(Color("3a1d63"), w)
	var bottom := Color("2c3681").lerp(Color("1f6a7a"), w)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, WALL_BOTTOM), Vector2(0, WALL_BOTTOM)]),
		PackedColorArray([top, top, bottom, bottom]))
	# Papel pintado con rayas suaves / Softly striped wallpaper
	var x := 0.0
	while x < 1920.0:
		draw_rect(Rect2(x, 0, 18, WALL_BOTTOM), Color(1, 1, 1, 0.025))
		x += 48.0
	# Estrellas proyectadas que giran despacio / Projected stars slowly turning
	var drift := Vector2(sin(_t * 0.08) * 30.0, cos(_t * 0.06) * 8.0)
	for s in _wall_stars:
		var a := 0.35 + 0.3 * sin(_t * 1.2 + float(s["ph"]))
		var p := Vector2(s["p"]) + drift
		_star_shape(p, float(s["r"]), Color(UITheme.GOLD, a * 0.55))
	# Rodapié / Skirting board
	draw_rect(Rect2(0, WALL_BOTTOM - 14, 1920, 18), Color("cfc8ec"))
	draw_rect(Rect2(0, WALL_BOTTOM - 14, 1920, 3), Color(1, 1, 1, 0.5))


func _draw_window() -> void:
	var w := WINDOW
	# Luz de luna que entra / Incoming moonlight glow
	draw_texture_rect(DreamBackground.soft_texture(), w.grow(140), false, Color("c6d2ff", 0.22))
	# Cielo / Sky
	var sky_top := Color("0c1240")
	var sky_bot := Color("3a3a96")
	draw_polygon(PackedVector2Array([w.position, Vector2(w.end.x, w.position.y), w.end, Vector2(w.position.x, w.end.y)]),
		PackedColorArray([sky_top, sky_top, sky_bot, sky_bot]))
	for s in _window_stars:
		var p := w.position + Vector2(s["p"]) * w.size
		draw_circle(p, s["r"], Color(UITheme.BONE, 0.5 + 0.4 * sin(_t * 1.7 + float(s["ph"]))))
	var moon := w.position + Vector2(230, 64)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(moon - Vector2(80, 80), Vector2(160, 160)), false, Color("e9eeff", 0.4))
	draw_circle(moon, 26, Color("fbf4e2"))
	draw_circle(moon + Vector2(-8, -6), 5, Color("ece2c8"))
	# En sueños más hondos aparecen más lunas / Deeper dreams show more moons
	for i in mini(weird, 3):
		var m2 := w.position + Vector2(60 + i * 70, 150 - i * 30)
		draw_circle(m2, 12 - i * 2, Color(["f2b8d8", "b9f0ea", "f6d993"][i]))
	# Marco y cruceta / Frame and mullions
	var frame := Color("ece6f6")
	draw_rect(w, frame, false, 10.0)
	draw_line(Vector2(w.get_center().x, w.position.y), Vector2(w.get_center().x, w.end.y), frame, 6.0)
	draw_line(Vector2(w.position.x, w.get_center().y), Vector2(w.end.x, w.get_center().y), frame, 6.0)
	draw_rect(Rect2(w.position.x - 22, w.end.y + 2, w.size.x + 44, 14), Color("f4f0fb"))
	# Cortinas / Curtains
	for side: float in [-1.0, 1.0]:
		var x0 := w.position.x - 70.0 if side < 0 else w.end.x + 6.0
		var sway := sin(_t * 0.7 + side) * 4.0
		var pts := PackedVector2Array([
			Vector2(x0, 20), Vector2(x0 + 64, 20), Vector2(x0 + 64 + sway * side, 270), Vector2(x0 + sway, 278),
		])
		draw_colored_polygon(pts, Color("8a82d6"))
		for k in 3:
			var fx := x0 + 14.0 + k * 18.0
			draw_line(Vector2(fx, 24), Vector2(fx + sway * 0.5, 274), Color(0.2, 0.15, 0.5, 0.25), 3.0)
	draw_rect(Rect2(w.position.x - 90, 14, w.size.x + 180, 8), Color("cfc8ec"))


func _draw_shelf() -> void:
	var r := SHELF
	draw_rect(r, Color("4a4592"))
	draw_rect(r, Color("2c2a66"), false, 4.0)
	var colors := [Color("e3a6c4"), Color("f6d993"), Color("8fb3e8"), Color("b6e0d6"), Color("c9b6f0")]
	for row in 3:
		var y := r.position.y + 70.0 * (row + 1)
		draw_rect(Rect2(r.position.x, y, r.size.x, 6), Color("2c2a66"))
		var x := r.position.x + 10.0
		var i := row * 2
		while x < r.end.x - 20.0:
			var bw := 12.0 + (i % 3) * 4.0
			var bh := 40.0 + (i % 4) * 6.0
			draw_rect(Rect2(x, y - bh, bw, bh), colors[i % colors.size()])
			x += bw + 3.0
			i += 1


# --- Suelo / Floor ------------------------------------------------------------

func _draw_floor() -> void:
	var a := Color("3e3a7c")
	var b := Color("2f2c66")
	draw_polygon(PackedVector2Array([Vector2(0, WALL_BOTTOM), Vector2(1920, WALL_BOTTOM), Vector2(1920, FLOOR_BOTTOM), Vector2(0, FLOOR_BOTTOM)]),
		PackedColorArray([a, a, b, b]))
	# Tablas de madera / Floorboards
	var y := WALL_BOTTOM + 4.0
	var row := 0
	while y < FLOOR_BOTTOM - 40.0:
		if weird > 0:
			# Las tablas se ondulan como si respiraran / The boards ripple as if breathing
			var pts := PackedVector2Array()
			for k in 25:
				var px := k * 80.0
				pts.append(Vector2(px, y + sin(px * 0.006 + _t * 0.8 + row) * 4.0 * weird))
			draw_polyline(pts, Color(0.1, 0.08, 0.3, 0.35), 2.0, true)
		else:
			draw_line(Vector2(0, y), Vector2(1920, y), Color(0.1, 0.08, 0.3, 0.35), 2.0)
		var x := -120.0 + (row % 3) * 140.0
		while x < 1920.0:
			draw_line(Vector2(x, y), Vector2(x, y + 46), Color(0.1, 0.08, 0.3, 0.25), 2.0)
			x += 420.0
		y += 46.0
		row += 1
	# Sombra junto a la pared / Shadow along the wall
	draw_polygon(PackedVector2Array([Vector2(0, WALL_BOTTOM), Vector2(1920, WALL_BOTTOM), Vector2(1920, WALL_BOTTOM + 60), Vector2(0, WALL_BOTTOM + 60)]),
		PackedColorArray([Color(0.05, 0.03, 0.2, 0.45), Color(0.05, 0.03, 0.2, 0.45), Color(0.05, 0.03, 0.2, 0), Color(0.05, 0.03, 0.2, 0)]))


func _draw_moonbeam() -> void:
	var c := Color("d6e0ff")
	draw_polygon(PackedVector2Array([
		Vector2(WINDOW.position.x + 10, WALL_BOTTOM), Vector2(WINDOW.end.x - 10, WALL_BOTTOM),
		Vector2(1330, 980), Vector2(620, 980),
	]), PackedColorArray([Color(c, 0.16), Color(c, 0.16), Color(c, 0.0), Color(c, 0.0)]))
	# Cuadrícula de la ventana proyectada en el suelo / Window grid cast on the floor
	var cx := 975.0
	draw_line(Vector2(cx - 15, WALL_BOTTOM), Vector2(cx - 15, 900), Color(0.1, 0.1, 0.35, 0.10), 10.0)


func _draw_rug() -> void:
	var pts := PackedVector2Array()
	for i in 64:
		var a := TAU * i / 64.0
		pts.append(RUG_CENTER + Vector2(cos(a) * 340.0, sin(a) * 150.0))
	draw_colored_polygon(pts, Color("5a4f9e"))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(RUG_CENTER + (p - RUG_CENTER) * 0.86)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(UITheme.GOLD, 0.35), 3.0, true)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		_star_shape(RUG_CENTER + Vector2(cos(a) * 225.0, sin(a) * 92.0), 9.0, Color(UITheme.GOLD, 0.3))
	# Luna bordada en el centro / Moon stitched in the middle
	draw_arc(RUG_CENTER, 44, PI * 0.35, PI * 1.65, 32, Color(UITheme.GOLD, 0.35), 6.0, true)


# --- Muebles / Furniture -----------------------------------------------------

func _draw_desk() -> void:
	var d := DESK
	draw_rect(Rect2(d.position.x + 10, d.end.y, 14, 40), Color("3a346f"))
	draw_rect(Rect2(d.end.x - 24, d.end.y, 14, 40), Color("3a346f"))
	draw_rect(d, Color("8a7fc4"))
	draw_rect(Rect2(d.position.x, d.end.y - 18, d.size.x, 18), Color("6e64ad"))
	# Un dibujo a medias y las ceras / A half-finished drawing and the crayons
	draw_set_transform(d.position + Vector2(130, 46), 0.08, Vector2.ONE)
	draw_rect(Rect2(-36, -24, 72, 48), Color("f7f3ea"))
	draw_arc(Vector2(-6, 0), 13, 0.8, 5.0, 16, Color("5b67c4"), 3.0, true)
	draw_set_transform(Vector2.ZERO)
	for i in 4:
		var cc: Color = [Color("e85d75"), Color("f6c86a"), Color("5b67c4"), Color("62a9a1")][i]
		var cp := d.position + Vector2(180 + i * 8, 34 + i * 6)
		draw_line(cp, cp + Vector2(22, -6), cc, 4.0)
	# Flexo encendido / Lit desk lamp
	var base := Vector2(d.end.x - 46, d.position.y + 58)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(base - Vector2(120, 110), Vector2(200, 180)), false, Color("ffe1a8", 0.22))
	draw_colored_polygon(_ellipse(base, Vector2(18, 8)), Color("3a346f"))
	draw_line(base, base + Vector2(-10, -40), Color("3a346f"), 4.0)
	draw_line(base + Vector2(-10, -40), base + Vector2(-34, -30), Color("3a346f"), 4.0)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-26, -42), base + Vector2(-48, -20), base + Vector2(-28, -14)]), Color("e3a6c4"))
	# Bola del mundo / Globe
	var gl := Vector2(d.position.x + 230, d.position.y + 30)
	draw_circle(gl, 18, Color("7fb0e0"))
	draw_colored_polygon(PackedVector2Array([gl + Vector2(-8, -10), gl + Vector2(4, -12), gl + Vector2(6, 2), gl + Vector2(-6, 6)]), Color("9fd29a"))
	draw_arc(gl, 22, -2.4, 0.8, 16, Color("cfc8ec"), 2.0, true)


func _draw_nightstand() -> void:
	var n := NIGHTSTAND
	draw_rect(n, Color("9b92d4"))
	draw_rect(Rect2(n.position.x, n.end.y - 30, n.size.x, 30), Color("7d73bd"))
	draw_circle(Vector2(n.get_center().x, n.end.y - 15), 3, Color("f3effc"))
	# Lamparita de estrellas encendida / Glowing star night-light
	var lamp := n.position + Vector2(48, 30)
	var pulse := 0.9 + 0.1 * sin(_t * 2.0)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(lamp - Vector2(110, 110) * pulse, Vector2(220, 220) * pulse), false, Color("ffd89a", 0.35))
	draw_circle(lamp, 16, Color("fff1c9"))
	_star_shape(lamp, 8.0, Color("f6c86a"))
	if glasses_on_stand:
		# Las gafas de Kroker, dobladas junto a la lamparita / Kroker's glasses, folded by the lamp
		var g := n.position + Vector2(20, 64)
		draw_arc(g, 7, 0, TAU, 16, Color("2b2945"), 2.0, true)
		draw_arc(g + Vector2(18, 0), 7, 0, TAU, 16, Color("2b2945"), 2.0, true)
		draw_line(g + Vector2(7, 0), g + Vector2(11, 0), Color("2b2945"), 2.0)
		draw_line(g + Vector2(-2, -6), g + Vector2(28, -7), Color(1, 1, 1, 0.4), 1.0)


func _draw_bed() -> void:
	var b := BED
	# Sombra / Shadow
	draw_rect(Rect2(b.position.x + 12, b.end.y - 6, b.size.x - 4, 16), Color(0.05, 0.03, 0.2, 0.35))
	# Cabecero / Headboard
	draw_rect(Rect2(b.position.x - 8, b.position.y - 36, b.size.x + 16, 60), Color("aab4ea"))
	draw_circle(Vector2(b.position.x - 2, b.position.y - 36), 10, Color("cfd6f6"))
	draw_circle(Vector2(b.end.x + 2, b.position.y - 36), 10, Color("cfd6f6"))
	# Colchón y sábana / Mattress and sheet
	draw_rect(Rect2(b.position.x, b.position.y + 10, b.size.x, b.size.y - 10), Color("e6e2f6"))
	draw_rect(Rect2(b.position.x, b.end.y - 26, b.size.x, 26), Color("bdb5e2"))
	# Almohada / Pillow
	var pillow := Rect2(b.position.x + 24, b.position.y + 24, b.size.x - 48, 58)
	if not (outfit == "shield" and weapon_taken):
		_soft_rect(pillow, Color("f8f6ff"), 26)
	else:
		draw_rect(pillow, Color(0.4, 0.35, 0.7, 0.12))  # hueco de la almohada / where the pillow was

	if bed_state == "sleeping":
		# Se revuelve: la cabeza gira de un lado a otro / Tossing: the head turns side to side
		var turn := sin(stir * TAU * 1.5) * 0.35 * stir
		KrokerArt.draw_sleeping(self, pillow.get_center() + Vector2(0, 6), 0.9, _t, turn)

	var blanket_top := b.position.y + 88.0
	if bed_state == "sitting":
		blanket_top = b.position.y + lerpf(92.0, 120.0, sit) + slide * 50.0
		# Kroker se incorpora poco a poco, sale de debajo del edredón, se estira
		# y después se desliza hasta el borde de la cama.
		# Kroker slowly sits up out from under the quilt, stretches, then shuffles to the edge.
		var s := sitting_scale()
		var feet := sitting_feet()
		var rise := (1.0 - sit) * 90.0
		KrokerArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, Vector2(feet.x - 100 * s, feet.y + rise - 288 * s)),
			outfit, _t, {"armed": false, "glasses": not glasses_on_stand, "stretch": stretch, "yawn": stretch,
				"lean": (1.0 - sit) * -0.3 + slide * 0.12, "facing": 1.0,
				"walk": slide * 6.0, "moving": slide * (1.0 - slide) * 2.0})
	elif bed_state == "empty":
		blanket_top = b.position.y + 170.0

	# Edredón de estrellas / Starry quilt
	var quilt := Rect2(b.position.x - 6, blanket_top, b.size.x + 12, b.end.y - blanket_top + 4)
	draw_rect(quilt, Color("5b67c4"))
	var y := quilt.position.y + 34.0
	var row := 0
	while y < quilt.end.y - 10.0:
		var x := quilt.position.x + (24.0 if row % 2 == 0 else 52.0)
		while x < quilt.end.x - 10.0:
			_star_shape(Vector2(x, y), 5.0, Color(UITheme.GOLD, 0.7))
			x += 56.0
		y += 42.0
		row += 1
	# Embozo doblado / Folded-down top edge
	draw_rect(Rect2(quilt.position.x, quilt.position.y, quilt.size.x, 22), Color("eeeaf8"))
	draw_line(quilt.position + Vector2(0, 22), Vector2(quilt.end.x, quilt.position.y + 22), Color(0.2, 0.2, 0.5, 0.3), 2.0)
	_draw_teddy(Vector2(b.position.x + 34, b.end.y - 44), 0.7)
	if bed_state == "sleeping":
		# Bulto que respira bajo el edredón / Breathing shape under the quilt
		var rise := sin(_t * 1.6) * 3.0
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(b.position.x + 30, blanket_top + 10 - rise, 140, 150), false, Color(1, 1, 1, 0.12))


## Tamaño de Kroker en el lienzo de la habitación, igual que en la partida.
## Kroker's size on the room canvas, matching the one in play.
static func sitting_scale() -> float:
	return Player.ART_SCALE / S


## Dónde están los pies de Kroker sentado en la cama (lienzo de la habitación).
## Where seated Kroker's feet are on the bed (room canvas).
func sitting_feet() -> Vector2:
	var b := BED
	var top := b.position.y + lerpf(92.0, 120.0, sit) + slide * 50.0
	return Vector2(lerpf(b.get_center().x, b.end.x - 18.0, slide), top + 100.0)


## Pies al final del deslizamiento: desde aquí salta al suelo.
## Feet at the end of the shuffle: he hops down from here.
func sitting_feet_end() -> Vector2:
	var b := BED
	return Vector2(b.end.x - 18.0, b.position.y + 120.0 + 50.0 + 100.0)


func _draw_motes() -> void:
	# Motas de luz flotando en el rayo de luna / Light motes floating in the moonbeam
	for m in _motes:
		var v := fposmod(float(m["v"]) - _t * float(m["sp"]), 1.0)
		var y := lerpf(WALL_BOTTOM, 960.0, v)
		var half := lerpf(150.0, 350.0, v)
		var x := 975.0 + (float(m["u"]) - 0.5) * 2.0 * half + sin(_t + float(m["ph"])) * 8.0
		draw_circle(Vector2(x, y), 1.8, Color(UITheme.BONE, 0.5 * sin(v * PI)))


func _draw_dream_stars() -> void:
	for f in _floaters:
		var ph := float(f["ph"])
		var p := Vector2(f["p"]) + Vector2(sin(_t * 0.4 + ph) * 18.0, cos(_t * 0.3 + ph) * 12.0)
		var a := 0.35 + 0.35 * sin(_t * 1.3 + ph)
		DreamBackground.draw_star(self, p, float(f["r"]) * 0.5, Color(UITheme.GOLD, a))


static func _vignette() -> GradientTexture2D:
	if _vig:
		return _vig
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.04, 0.2, 0.0))
	g.set_color(1, Color(0.06, 0.04, 0.2, 0.55))
	g.add_point(0.6, Color(0.06, 0.04, 0.2, 0.0))
	_vig = GradientTexture2D.new()
	_vig.gradient = g
	_vig.fill = GradientTexture2D.FILL_RADIAL
	_vig.fill_from = Vector2(0.5, 0.55)
	_vig.fill_to = Vector2(1.05, 1.05)
	return _vig


# --- Detalles nuevos / New details ------------------------------------------

func _draw_wall_decor() -> void:
	# Guirnalda de estrellas de papel / Paper star garland
	var a := Vector2(420, 40)
	var b := Vector2(740, 30)
	var pts := PackedVector2Array()
	for i in 25:
		var k := i / 24.0
		pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * 46.0))
	draw_polyline(pts, Color("cfc8ec", 0.7), 1.5, true)
	var cols := [Color("f6d993"), Color("e3a6c4"), Color("a9c8f2"), Color("b6e0d6")]
	for i in range(2, 24, 4):
		var p := pts[i]
		var sway := sin(_t * 1.2 + i) * 2.0
		draw_line(p, p + Vector2(sway, 16), Color("cfc8ec", 0.6), 1.0)
		_star_shape(p + Vector2(sway, 26), 10.0, cols[(i / 4) % cols.size()])
	# Dibujo infantil pegado con celo / Child's drawing taped up
	var d := Rect2(560, 92, 110, 84)
	draw_set_transform(d.get_center(), -0.05, Vector2.ONE)
	var dr := Rect2(-d.size / 2.0, d.size)
	draw_rect(dr, Color("f7f3ea"))
	draw_circle(Vector2(26, -18), 12, Color("f6d993"))
	draw_colored_polygon(PackedVector2Array([Vector2(-40, 30), Vector2(-40, 6), Vector2(-24, -8), Vector2(-8, 6), Vector2(-8, 30)]), Color("e3a6c4"))
	draw_line(Vector2(-50, 32), Vector2(50, 32), Color("9fd29a"), 3.0)
	_stick_figure(Vector2(14, 30))
	draw_rect(Rect2(-14, -46, 28, 8), Color(1, 1, 1, 0.5))
	draw_set_transform(Vector2.ZERO)
	# Póster del sistema solar sobre el escritorio / Solar system poster above the desk
	var ps := Rect2(1490, 52, 250, 150)
	draw_rect(ps, Color("141a4a"))
	draw_rect(ps, Color("cfc8ec"), false, 3.0)
	# Estático: el sol a la izquierda y las órbitas recortadas para no salirse del póster
	# Static: sun on the left, orbits trimmed so they stay inside the poster
	var sun := ps.position + Vector2(26, 75)
	draw_circle(sun, 30, Color("f6d993", 0.25))
	draw_circle(sun, 16, Color("f6c86a"))
	var planets := [[42.0, 4.0, Color("cfc8ec"), 0.5], [70.0, 6.0, Color("e3a6c4"), -0.35], [100.0, 7.0, Color("7fb0e0"), 0.2],
		[136.0, 11.0, Color("f0c38f"), -0.25], [176.0, 8.0, Color("b6e0d6"), 0.1]]
	var half_h := ps.size.y / 2.0 - 8.0
	for pl in planets:
		var rr: float = pl[0]
		var span := asin(minf(0.98, half_h / rr))
		draw_arc(sun, rr, -span, span, 24, Color(1, 1, 1, 0.18), 1.0, true)
		draw_circle(sun + Vector2.from_angle(float(pl[3]) * span) * rr, pl[1], pl[2])


func _stick_figure(p: Vector2) -> void:
	var c := Color("5b67c4")
	draw_circle(p + Vector2(0, -24), 5, c)
	draw_line(p + Vector2(0, -19), p + Vector2(0, -8), c, 2.0)
	draw_line(p + Vector2(0, -8), p + Vector2(-5, 0), c, 2.0)
	draw_line(p + Vector2(0, -8), p + Vector2(5, 0), c, 2.0)
	draw_line(p + Vector2(-6, -16), p + Vector2(6, -16), c, 2.0)


func _draw_chair() -> void:
	# Silla metida en el escritorio, mirando hacia él: vemos el respaldo por detrás
	# Chair tucked under the desk, facing it: we see the backrest from behind
	var seat := Rect2(1538, 326, 82, 44)
	for leg in [Vector2(1542, 368), Vector2(1610, 368)]:
		draw_rect(Rect2(leg, Vector2(6, 30)), Color("3a346f"))
	_soft_rect(seat, Color("7d73bd"), 8)
	_soft_rect(Rect2(seat.position + Vector2(8, 4), Vector2(seat.size.x - 16, 18)), Color("e3a6c4"), 8)  # cojín / cushion
	# Respaldo (de espaldas a nosotros) / Backrest (facing away from us)
	var back := Rect2(seat.position.x + 4, seat.end.y - 58, seat.size.x - 8, 50)
	draw_rect(Rect2(back.position.x + 6, back.end.y, 6, 14), Color("4a4592"))
	draw_rect(Rect2(back.end.x - 12, back.end.y, 6, 14), Color("4a4592"))
	_soft_rect(back, Color("5a4f9e"), 10)
	draw_rect(Rect2(back.position + Vector2(10, 10), back.size - Vector2(20, 20)), Color("6a5fae"))


func _draw_toy_chest() -> void:
	var c := CHEST
	# Tapa abierta apoyada en la pared / Open lid resting against the wall
	draw_rect(Rect2(c.position.x + 4, c.position.y - 50, c.size.x - 8, 50), Color("a87fbf"))
	draw_rect(Rect2(c.position.x + 4, c.position.y - 50, c.size.x - 8, 50), Color("7d5a9a"), false, 3.0)
	# Juguetes asomando / Toys peeking out
	draw_circle(c.position + Vector2(40, 8), 18, Color("e3a6c4"))
	draw_arc(c.position + Vector2(40, 8), 18, -1.2, 1.2, 12, Color(1, 1, 1, 0.6), 3.0, true)
	draw_colored_polygon(PackedVector2Array([c.position + Vector2(84, 14), c.position + Vector2(96, -22), c.position + Vector2(108, 14)]), Color("f6d993"))
	draw_circle(c.position + Vector2(96, 0), 4, Color("7fb0e0"))
	draw_rect(Rect2(c.position + Vector2(112, -6), Vector2(20, 20)), Color("9fd29a"))
	# Caja / Chest
	draw_rect(c, Color("c0a0dc"))
	draw_rect(Rect2(c.position.x, c.end.y - 22, c.size.x, 22), Color("9e7fbf"))
	draw_rect(c, Color("7d5a9a"), false, 3.0)
	_star_shape(c.get_center() + Vector2(0, -6), 12.0, Color("f6d993"))


func _draw_floor_toys() -> void:
	# Juguetes ordenados junto a la pared / Toys tidied up against the wall
	# Torre de cubos en la esquina izquierda / Stack of blocks in the left corner
	var cubes := [[Vector2(36, 318), Color("f6d993"), "A"], [Vector2(82, 318), Color("a9c8f2"), "B"], [Vector2(59, 276), Color("e3a6c4"), "C"]]
	var f := UITheme.font("display")
	for cb in cubes:
		var p: Vector2 = cb[0]
		draw_rect(Rect2(p, Vector2(42, 42)), cb[1])
		draw_rect(Rect2(p + Vector2(0, 34), Vector2(42, 8)), Color(0, 0, 0, 0.12))
		draw_string(f, p + Vector2(12, 30), cb[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("3a346f"))
	# Pelota junto a la estantería / Ball by the bookshelf
	var ball := Vector2(1214, 322)
	draw_colored_polygon(_ellipse(ball + Vector2(2, 22), Vector2(22, 6)), Color(0, 0, 0, 0.18))
	draw_circle(ball, 22, Color("f3effc"))
	draw_arc(ball, 22, -0.6, 0.9, 16, Color("e85d75"), 8.0, true)
	draw_arc(ball, 22, 2.4, 3.9, 16, Color("5b67c4"), 8.0, true)


## Alfombrita junto a la cama, donde Kroker pone los pies al levantarse.
## Small bedside rug, where Kroker puts his feet when he gets up.
func _draw_bedside_rug() -> void:
	draw_colored_polygon(_ellipse(BEDSIDE_RUG, Vector2(92, 46), 40), Color("c98fb8"))
	var inner := _ellipse(BEDSIDE_RUG, Vector2(78, 36), 40)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color("f7e6f0", 0.6), 2.0, true)
	_draw_bunny(BEDSIDE_RUG + Vector2(56, -16))


## Objetos que flotan cuando el sueño se vuelve raro / Things that float as the dream gets strange
func _draw_floating_things() -> void:
	var count := mini(12, weird * 4)
	var f := UITheme.font("display")
	for i in count:
		var ph := i * 1.7
		var p := Vector2(fposmod(200.0 + i * 160.0 + _t * (10.0 + i * 2.0), 1920.0),
			420.0 + fposmod(i * 97.0, 500.0) + sin(_t * 0.7 + ph) * 30.0)
		draw_set_transform(p, _t * (0.3 + 0.1 * i) * (1 if i % 2 == 0 else -1), Vector2.ONE)
		match i % 4:
			0:
				draw_rect(Rect2(-18, -18, 36, 36), Color(["f6d993", "a9c8f2", "e3a6c4"][i % 3], 0.75))
				draw_string(f, Vector2(-8, 10), ["A", "B", "C"][i % 3], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("3a346f"))
			1:
				draw_rect(Rect2(-26, -18, 52, 36), Color("3b4fa8", 0.8))
				draw_rect(Rect2(-22, -14, 44, 28), Color("fbf3dc", 0.85))
			2:
				draw_circle(Vector2.ZERO, 18, Color("f3effc", 0.8))
				draw_arc(Vector2.ZERO, 18, -0.6, 0.9, 12, Color("e85d75"), 6.0, true)
			3:
				_star_shape(Vector2.ZERO, 16.0, Color(UITheme.GOLD, 0.7))
		draw_set_transform(Vector2.ZERO)


func _draw_room_edges() -> void:
	# La habitación flota en el cielo: canto del suelo y bordes que se funden con la noche
	# The room floats in the sky: floor edge and sides fading into the night
	draw_rect(Rect2(0, FLOOR_BOTTOM, 1920, 34), Color("1b1846"))
	draw_rect(Rect2(0, FLOOR_BOTTOM, 1920, 3), Color("6a63b8"))
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(-200, FLOOR_BOTTOM - 20, 2320, 160), false, Color("b79be0", 0.12))
	for side: float in [0.0, 1.0]:
		var x := side * 1920.0
		var w := 40.0
		var x0 := x if side == 0.0 else x - w
		var c_in := Color(0.05, 0.03, 0.2, 0.0)
		var c_out := Color(0.05, 0.03, 0.2, 0.45)
		var cols := PackedColorArray([c_out, c_in, c_in, c_out]) if side == 0.0 else PackedColorArray([c_in, c_out, c_out, c_in])
		draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + w, 0), Vector2(x0 + w, FLOOR_BOTTOM + 34), Vector2(x0, FLOOR_BOTTOM + 34)]), cols)


func _draw_teddy(p: Vector2, s: float) -> void:
	# Osito de peluche sentado / Sitting teddy bear
	var fur := Color("c99a78")
	var dark := Color("a87a5c")
	draw_set_transform(p, sin(_t * 0.8) * 0.03, Vector2(s, s))
	draw_circle(Vector2(0, 30), 26, Color(0, 0, 0, 0.1))
	draw_circle(Vector2(-18, 30), 10, dark)
	draw_circle(Vector2(18, 30), 10, dark)
	draw_colored_polygon(_ellipse(Vector2(0, 14), Vector2(22, 24)), fur)
	draw_colored_polygon(_ellipse(Vector2(0, 18), Vector2(12, 14)), Color("e8c9a8"))
	draw_circle(Vector2(-20, 8), 8, dark)
	draw_circle(Vector2(20, 8), 8, dark)
	draw_circle(Vector2(-14, -28), 9, fur)
	draw_circle(Vector2(14, -28), 9, fur)
	draw_circle(Vector2(-14, -28), 4.5, Color("e8c9a8"))
	draw_circle(Vector2(14, -28), 4.5, Color("e8c9a8"))
	draw_circle(Vector2(0, -16), 18, fur)
	draw_colored_polygon(_ellipse(Vector2(0, -10), Vector2(8, 6)), Color("e8c9a8"))
	draw_circle(Vector2(0, -12), 2.5, Color("3a2a30"))
	draw_circle(Vector2(-7, -20), 2, Color("3a2a30"))
	draw_circle(Vector2(7, -20), 2, Color("3a2a30"))
	# Lazo / Bow
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-10, -6), Vector2(-10, 6)]), Color("5b67c4"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(10, -6), Vector2(10, 6)]), Color("5b67c4"))
	draw_set_transform(Vector2.ZERO)


func _draw_bunny(p: Vector2) -> void:
	# Conejo de peluche tumbado en el suelo / Plush bunny lying on the floor
	var fur := Color("eeeaf6")
	var inner := Color("f2b8c8")
	draw_set_transform(p, -0.4, Vector2.ONE)
	draw_colored_polygon(_ellipse(Vector2(4, 30), Vector2(30, 8)), Color(0, 0, 0, 0.12))
	draw_colored_polygon(_ellipse(Vector2(-4, -40), Vector2(7, 20)), fur)
	draw_colored_polygon(_ellipse(Vector2(12, -38), Vector2(7, 20)), fur)
	draw_colored_polygon(_ellipse(Vector2(-4, -40), Vector2(3, 13)), inner)
	draw_colored_polygon(_ellipse(Vector2(12, -38), Vector2(3, 13)), inner)
	draw_colored_polygon(_ellipse(Vector2(4, 10), Vector2(20, 22)), fur)
	draw_circle(Vector2(4, -14), 16, fur)
	draw_circle(Vector2(-2, -16), 2, Color("3a2a30"))
	draw_circle(Vector2(10, -16), 2, Color("3a2a30"))
	draw_circle(Vector2(4, -10), 2, inner)
	draw_set_transform(Vector2.ZERO)


## Las armas en su sitio antes de que Kroker las coja / The weapons in place before Kroker takes them
func _draw_props() -> void:
	# Bate apoyado en la pared / Bat leaning against the wall
	if not (outfit == "bat" and weapon_taken):
		draw_set_transform(Vector2(700, 300), 0.2, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(7, -96), Vector2(0, -106), Vector2(-7, -96)]), Color("c99a68"))
		draw_rect(Rect2(-4, -16, 8, 16), Color("3a3355"))
		draw_set_transform(Vector2.ZERO)
	# Libro de cuentos sobre el escritorio / Storybook on the desk
	if not (outfit == "book" and weapon_taken):
		var bk := Rect2(1500, 250, 56, 40)
		draw_rect(bk, Color("3b4fa8"))
		draw_rect(Rect2(bk.position + Vector2(4, 4), bk.size - Vector2(8, 8)), Color("fbf3dc"))
		draw_line(Vector2(bk.get_center().x, bk.position.y), Vector2(bk.get_center().x, bk.end.y), Color("3b4fa8"), 3.0)
		draw_texture_rect(DreamBackground.soft_texture(), bk.grow(30), false, Color(UITheme.GOLD, 0.2 + 0.1 * sin(_t * 2.0)))
	# Aspiradora en la esquina / Vacuum in the corner
	if not (outfit == "vacuum" and weapon_taken):
		var v := Vector2(1835, 330)
		draw_colored_polygon(_ellipse(v + Vector2(0, 30), Vector2(26, 8)), Color(0, 0, 0, 0.2))
		draw_colored_polygon(_ellipse(v, Vector2(22, 30)), Color("e9e3f3"))
		draw_colored_polygon(_ellipse(v + Vector2(-2, -8), Vector2(10, 12)), Color(KrokerArt.ACCENT["vacuum"], 0.5))
		draw_polyline(PackedVector2Array([v + Vector2(-16, -10), v + Vector2(-40, -40), v + Vector2(-30, -80)]), Color("4a4f86"), 5.0, true)
		draw_rect(Rect2(v + Vector2(-44, -92), Vector2(26, 12)), Color("4a4f86"))


func _draw_zzz() -> void:
	if bed_state != "sleeping":
		return
	var f := UITheme.font("italic")
	var head := Vector2(BED.get_center().x + 14, BED.position.y + 36)
	for i in 3:
		var k := fposmod(_t * 0.4 + i / 3.0, 1.0)
		var p := head + Vector2(20 + k * 50 + sin(k * 6.0) * 6, -k * 90)
		draw_string(f, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 + k * 18), Color(UITheme.BONE, 0.8 * sin(k * PI)))


# --- Corrupción del sueño / Dream corruption ---------------------------------

func _draw_holes() -> void:
	for i in hole_count():
		var h := HOLES[i]
		var c := h.get_center()
		var rr := h.size / 2.0
		# Borde roto: la forma tiembla un poco / Broken rim: the shape wobbles slightly
		var rim := PackedVector2Array()
		var inner := PackedVector2Array()
		for k in 28:
			var a := TAU * k / 28.0
			var jag := 1.0 + 0.12 * sin(a * 5.0 + i * 2.0) + 0.06 * sin(a * 11.0 + i)
			rim.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * (jag + 0.12))
			inner.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * jag)
		draw_colored_polygon(rim, Color("2a2350"))
		# Dentro se ve el vacío estrellado / Inside you can see the starry void
		draw_colored_polygon(inner, Color("07061a"))
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - rr * 0.8, rr * 1.6), false, Color("5b4bc4", 0.35))
		for k in 7:
			var sp := c + Vector2(sin(k * 2.3 + i) * rr.x * 0.6, cos(k * 1.7 + i) * rr.y * 0.5)
			draw_circle(sp, 1.4, Color(UITheme.BONE, 0.4 + 0.4 * sin(_t * 2.0 + k)))
		# Astillas de las tablas / Floorboard splinters
		for k in 6:
			var a := TAU * k / 6.0 + i
			var p0 := c + Vector2(cos(a) * rr.x, sin(a) * rr.y)
			draw_line(p0, p0 + Vector2(cos(a) * 14.0, sin(a) * 6.0), Color("4a4592"), 3.0)


func _draw_corruption() -> void:
	if weird <= 0:
		return
	for line in _cracks:
		draw_polyline(line, Color(0.03, 0.02, 0.1, 0.85), 3.0, true)
		draw_polyline(line, Color("8d7ff0", 0.25), 1.0, true)
	# Luz que se cuela por las grietas más grandes / Light leaking through the bigger cracks
	for i in range(0, _cracks.size(), 4):
		var line: PackedVector2Array = _cracks[i]
		if line.size() > 3:
			var mid := line[line.size() / 2]
			draw_texture_rect(DreamBackground.soft_texture(), Rect2(mid - Vector2(18, 18), Vector2(36, 36)), false, Color("8d7ff0", 0.18 + 0.08 * sin(_t * 2.0 + i)))
	for f in _flakes:
		var p := Vector2(f["p"]) + Vector2(sin(_t * 0.5 + float(f["ph"])) * 10.0, -fposmod(_t * float(f["v"]) + float(f["ph"]) * 20.0, 120.0))
		var sz := float(f["s"])
		var rot := float(f["r"]) + _t * 0.4
		draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(rot) * sz, p + Vector2.from_angle(rot + 2.1) * sz * 0.7,
			p + Vector2.from_angle(rot + 3.9) * sz * 0.9]), Color("2c3681", 0.8))


# --- Utilidades / Helpers ---------------------------------------------------

func _ellipse(c: Vector2, rr: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
	return pts


func _soft_rect(r: Rect2, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.shadow_color = Color(0.2, 0.15, 0.5, 0.25)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(3, 4)
	draw_style_box(sb, r)


func _star_shape(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, color)
