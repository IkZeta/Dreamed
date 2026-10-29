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

## Boquetes que se abren en la pared del fondo, a ras de suelo: se puede tirar a los
## enemigos por ellos. Holes that open in the back wall at floor level: enemies can be
## shoved through them.
const WALL_HOLES: Array[Rect2] = [
	Rect2(646, 172, 124, 128),
	Rect2(1128, 150, 98, 150),
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


func wall_hole_count() -> int:
	return clampi(weird, 0, WALL_HOLES.size())


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
	# Los boquetes rompen también las cortinas / The holes tear through the curtains too
	_draw_wall_holes()
	if not gone.has("shelf"):
		_draw_shelf()
	_draw_wall_decor()
	_draw_floor()
	_draw_moonbeam()
	_draw_rug()
	_draw_holes()
	_draw_wall_hole_floor()
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
	# Pared en pixel art; cambia de color según lo raro que esté el sueño
	# Pixel-art wall; its colour shifts with how strange the dream is
	Sprites.draw(self, "room_wall_%d" % clampi(weird, 0, 3))
	# Estrellas proyectadas que giran despacio / Projected stars slowly turning
	var drift := Vector2(sin(_t * 0.08) * 30.0, cos(_t * 0.06) * 8.0)
	for s in _wall_stars:
		var a := 0.35 + 0.3 * sin(_t * 1.2 + float(s["ph"]))
		var p := Vector2(s["p"]) + drift
		if p.y < WALL_BOTTOM - 20.0:
			_star_shape(p, float(s["r"]), Color(UITheme.GOLD, a * 0.55))

## Boquetes en la pared que dan al vacío estrellado / Holes in the wall onto the starry void
func _draw_wall_holes() -> void:
	for i in wall_hole_count():
		var h := WALL_HOLES[i]
		var pts := PackedVector2Array()
		var inner := PackedVector2Array()
		var n := 18
		# Arco roto por arriba y abierto por abajo, hasta el suelo / Broken arch on top, open at the bottom down to the floor
		for k in n + 1:
			var a := PI + PI * k / n
			var jag := 1.0 + 0.1 * sin(k * 2.7 + i * 3.0) + 0.06 * sin(k * 5.3 + i)
			var p := Vector2(h.get_center().x + cos(a) * h.size.x / 2.0 * jag, h.end.y - h.size.y * 0.35 + sin(a) * h.size.y * 0.65 * jag)
			pts.append(p + (p - Vector2(h.get_center().x, h.end.y)).normalized() * 8.0)
			inner.append(p)
		pts.append(Vector2(h.end.x + 10, h.end.y + 24))
		pts.append(Vector2(h.position.x - 10, h.end.y + 24))
		inner.append(Vector2(h.end.x, h.end.y + 20))
		inner.append(Vector2(h.position.x, h.end.y + 20))
		draw_colored_polygon(pts, Color("3a3378"))
		draw_colored_polygon(inner, Color("07061a"))
		draw_texture_rect(DreamBackground.soft_texture(), h.grow(-10), false, Color("5b4bc4", 0.4))
		for k in 9:
			var sp := h.position + Vector2(fposmod(k * 37.0 + i * 13.0, h.size.x), fposmod(k * 53.0 + i * 29.0, h.size.y))
			if sp.y > h.position.y + h.size.y * 0.2:
				draw_circle(sp, 1.5, Color(UITheme.BONE, 0.4 + 0.4 * sin(_t * 2.0 + k)))
		# Ladrillos y listones sueltos en el borde / Loose bricks and laths on the rim
		for k in 4:
			var a := PI + PI * (k + 0.5) / 4.0
			var p := Vector2(h.get_center().x + cos(a) * h.size.x * 0.55, h.end.y - h.size.y * 0.35 + sin(a) * h.size.y * 0.7)
			draw_line(p, p + Vector2.from_angle(a) * 16.0, Color("cfc8ec", 0.7), 3.0)


## Sombra del boquete sobre el suelo, para que se lea como una salida
## The hole's shadow on the floor, so it reads as an opening
func _draw_wall_hole_floor() -> void:
	for i in wall_hole_count():
		var h := WALL_HOLES[i]
		var c := Vector2(h.get_center().x, WALL_BOTTOM + 22)
		draw_colored_polygon(_ellipse(c, Vector2(h.size.x * 0.55, 20)), Color("07061a", 0.75))
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(h.size.x * 0.6, 26), Vector2(h.size.x * 1.2, 52)), false, Color("5b4bc4", 0.25))


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
		draw_rect(Rect2(p - Vector2(1.4, 1.4), Vector2(2.8, 2.8)), Color(UITheme.BONE, 0.5 + 0.4 * sin(_t * 1.7 + float(s["ph"]))))
	var moon := w.position + Vector2(230, 64)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(moon - Vector2(80, 80), Vector2(160, 160)), false, Color("e9eeff", 0.4))
	draw_circle(moon, 26, Color("fbf4e2"))
	draw_circle(moon + Vector2(-8, -6), 5, Color("ece2c8"))
	# En sueños más hondos aparecen más lunas / Deeper dreams show more moons
	for i in mini(weird, 3):
		var m2 := w.position + Vector2(60 + i * 70, 150 - i * 30)
		draw_circle(m2, 12 - i * 2, Color(["f2b8d8", "b9f0ea", "f6d993"][i]))
	Sprites.draw(self, "room_window_frame")
	# Cortinas que se mecen un poco / Curtains swaying a little
	Sprites.draw(self, "room_curtain_l", Color.WHITE, Vector2(sin(_t * 0.7 - 1.0) * 2.0, 0))
	Sprites.draw(self, "room_curtain_r", Color.WHITE, Vector2(sin(_t * 0.7 + 1.0) * 2.0, 0))
	Sprites.draw(self, "room_curtain_rod")



func _draw_shelf() -> void:
	Sprites.draw(self, "room_shelf")


func _draw_floor() -> void:
	Sprites.draw(self, "room_floor")
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
	Sprites.draw(self, "room_rug")


func _draw_desk() -> void:
	Sprites.draw(self, "room_desk")
	# Luz del flexo / Desk lamp light
	var base := Vector2(DESK.end.x - 46, DESK.position.y + 58)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(base - Vector2(120, 110), Vector2(200, 180)), false, Color("ffe1a8", 0.22))



func _draw_nightstand() -> void:
	Sprites.draw(self, "room_nightstand")
	# Lamparita de estrellas encendida / Glowing star night-light
	var lamp := NIGHTSTAND.position + Vector2(48, 30)
	var pulse := 0.9 + 0.1 * sin(_t * 2.0)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(lamp - Vector2(110, 110) * pulse, Vector2(220, 220) * pulse), false, Color("ffd89a", 0.35))
	if glasses_on_stand:
		# Las gafas de Kroker, dobladas junto a la lamparita / Kroker's glasses, folded by the lamp
		Sprites.draw(self, "room_glasses")



func _draw_bed() -> void:
	var b := BED
	# Cabecero, colchón y sábana / Headboard, mattress and sheet
	Sprites.draw(self, "room_bed")
	# Almohada / Pillow
	var pillow := Rect2(b.position.x + 24, b.position.y + 24, b.size.x - 48, 58)
	if not (outfit == "shield" and weapon_taken):
		Sprites.draw(self, "room_bed_pillow")
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

	# Edredón de estrellas: se ve desde el embozo hasta los pies de la cama
	# Starry quilt: shown from its folded edge down to the foot of the bed
	Sprites.draw_top(self, "room_quilt", blanket_top - 2.0, b.end.y + 6.0)
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
	# Kroker es bajito: los pies quedan más arriba para que asome del edredón
	# Kroker is short: his feet sit higher so he shows above the quilt
	return Vector2(lerpf(b.get_center().x, b.end.x - 18.0, slide), top + 48.0)


## Pies al final del deslizamiento: desde aquí salta al suelo.
## Feet at the end of the shuffle: he hops down from here.
func sitting_feet_end() -> Vector2:
	var b := BED
	return Vector2(b.end.x - 18.0, b.position.y + 120.0 + 50.0 + 48.0)


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
	# Dibujo infantil y póster del sistema solar / Child's drawing and solar system poster
	Sprites.draw(self, "room_drawing")
	Sprites.draw(self, "room_poster")
	# Cuaderno de dibujos: uno nuevo en la pared por cada logro con dibujo
	# Drawing book: a new one on the wall for each achievement with a drawing
	for ach: Dictionary in Progress.ACHIEVEMENTS:
		if ach.has("drawing") and Progress.has_achieved(ach["id"]):
			Sprites.draw(self, "room_draw_" + String(ach["drawing"]))


func _stick_figure(p: Vector2) -> void:
	var c := Color("5b67c4")
	draw_circle(p + Vector2(0, -24), 5, c)
	draw_line(p + Vector2(0, -19), p + Vector2(0, -8), c, 2.0)
	draw_line(p + Vector2(0, -8), p + Vector2(-5, 0), c, 2.0)
	draw_line(p + Vector2(0, -8), p + Vector2(5, 0), c, 2.0)
	draw_line(p + Vector2(-6, -16), p + Vector2(6, -16), c, 2.0)


func _draw_chair() -> void:
	# Silla metida en el escritorio, de espaldas a nosotros / Chair tucked under the desk, facing away from us
	Sprites.draw(self, "room_chair")



func _draw_toy_chest() -> void:
	Sprites.draw(self, "room_toy_chest")



func _draw_floor_toys() -> void:
	# Torre de cubos en la esquina y pelota junto a la estantería
	# Stack of blocks in the corner and a ball by the bookshelf
	Sprites.draw(self, "room_blocks")
	Sprites.draw(self, "room_ball")

## Alfombrita junto a la cama, donde Kroker pone los pies al levantarse.
## Small bedside rug, where Kroker puts his feet when he gets up.
func _draw_bedside_rug() -> void:
	Sprites.draw(self, "room_bedside_rug")
	Sprites.draw(self, "room_bunny")

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
	# Osito de peluche sentado (el sprite ya está a 0,7) / Sitting teddy bear (the sprite is already at 0.7)
	draw_set_transform(p, sin(_t * 0.8) * 0.03, Vector2.ONE * s / 0.7)
	Sprites.draw(self, "room_teddy")
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
	# Bate apoyado en la pared; si la pared se ha roto ahí, junto a la estantería
	# Bat leaning on the wall; if the wall broke there, by the bookshelf
	if not (outfit == "bat" and weapon_taken):
		Sprites.draw(self, "room_bat", Color.WHITE, Vector2(700, 300) if wall_hole_count() == 0 else Vector2(1436, 300))
	# Libro de cuentos sobre el escritorio / Storybook on the desk
	if not (outfit == "book" and weapon_taken):
		Sprites.draw(self, "room_book")
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(1470, 220, 116, 100), false, Color(UITheme.GOLD, 0.2 + 0.1 * sin(_t * 2.0)))
	# Aspiradora en la esquina / Vacuum in the corner
	if not (outfit == "vacuum" and weapon_taken):
		Sprites.draw(self, "room_vacuum")


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
