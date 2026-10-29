class_name LivingRoom
extends Bedroom
## El salón de casa, escenario del Acto 2 (sueños 6 a 9). Mismo lienzo y misma zona de
## suelo que la habitación: papel pintado de flores, chimenea de piedra, sillón de la abuela,
## tele antigua y un sofá en medio que tapa a quien pase por detrás.
## En algunos sueños la chimenea está encendida y en ella se pueden sacrificar mejoras a
## cambio de Realidad Fragmentada.
## The family living room, the stage of Act 2 (dreams 6 to 9). Same canvas and floor area as
## the bedroom: floral wallpaper, stone fireplace, grandma's armchair, an old TV and a sofa in
## the middle that hides whoever walks behind it.
## In some dreams the fireplace is lit and upgrades can be sacrificed in it in exchange for
## Fragmented Reality.

const WINDOW_L := Rect2(200, 40, 200, 160)
const FIREBOX := Rect2(870, 180, 180, 120)
## Delante de la chimenea: si Kroker se queda aquí, se carga el sacrificio
## In front of the fireplace: if Kroker stays here, the sacrifice charges up
const HEARTH_ZONE := Rect2(850, 330, 220, 80)
const TV_SCREEN := Rect2(1510, 128, 124, 84)

const OBSTACLES_L: Array[Rect2] = [
	Rect2(70, 280, 110, 60),      # mesita del teléfono / phone table
	Rect2(466, 300, 168, 50),     # sillón / armchair
	Rect2(1350, 310, 60, 34),     # lámpara de pie / floor lamp
	Rect2(1440, 300, 280, 40),    # mueble de la tele / TV cabinet
	Rect2(1790, 290, 90, 60),     # planta / plant
	Rect2(1476, 440, 208, 62),    # mesa de centro / coffee table
	Rect2(1360, 646, 420, 70),    # sofá (se puede pasar por detrás) / sofa (you can walk behind it)
]
const HOLES_L: Array[Rect2] = [
	Rect2(330, 800, 160, 66),
	Rect2(1120, 880, 170, 70),
	Rect2(900, 470, 140, 60),
	Rect2(1650, 900, 150, 66),
]
const WALL_HOLES_L: Array[Rect2] = [
	Rect2(660, 160, 120, 140),
	Rect2(1190, 150, 110, 150),
]
## Muebles del suelo que se ordenan con los personajes (base en el lienzo de la habitación)
## Floor furniture sorted together with the characters (base on the room canvas)
const PROPS := {
	"lroom_table": Vector2(1580, 500),
	"lroom_sofa": Vector2(1570, 712),
}
## Dónde se pone Charo / Where Charo stands
const CHARO_POINT := Vector2(640, 470)
const KIOSK_POINT := Vector2(520, 470)

var fire_lit := false
## Ya se ha sacrificado algo en este sueño: el fuego se ha apagado
## Something was already sacrificed this dream: the fire has gone out
var fire_used := false
## Carga del sacrificio (0 → 1) al quedarse delante del fuego / Sacrifice charge (0 → 1) while standing by the fire
var fire_charge := 0.0
var _flare := 0.0
## La tele se vuelve loca mientras sale El Chef / The TV goes wild while The Chef comes out
var tv_burst := 0.0
var _window_stars_l: Array[Dictionary] = []


func _ready() -> void:
	super()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 30:
		_window_stars_l.append({"p": Vector2(rng.randf(), rng.randf()), "ph": rng.randf() * TAU})


func obstacles_list() -> Array[Rect2]:
	return OBSTACLES_L.duplicate()


func holes_list() -> Array[Rect2]:
	return HOLES_L


func wall_holes_list() -> Array[Rect2]:
	return WALL_HOLES_L


func crack_zones() -> Array[Rect2]:
	return [
		Rect2(20, 20, 1880, 260),
		Rect2(470, 200, 160, 140),     # sillón / armchair
		Rect2(800, 120, 320, 180),     # chimenea / fireplace
		Rect2(1440, 120, 280, 200),    # tele / TV
		Rect2(60, 340, 1800, 680),
	]


## El fuego se aviva al sacrificar y luego se apaga / The fire flares up on a sacrifice, then goes out
func flare() -> void:
	_flare = 1.0
	fire_used = true
	fire_charge = 0.0


func can_sacrifice() -> bool:
	return fire_lit and not fire_used


func _process(delta: float) -> void:
	super(delta)
	_flare = maxf(0.0, _flare - delta * 0.6)
	tv_burst = maxf(0.0, tv_burst - delta * 0.8)


func _draw() -> void:
	Sprites.draw(self, "lroom_wall_%d" % clampi(weird, 0, 3))
	_draw_window_l()
	_draw_wall_holes()
	Sprites.draw(self, "lroom_photos")
	Sprites.draw(self, "lroom_painting")
	Sprites.draw(self, "lroom_floor")
	draw_polygon(PackedVector2Array([Vector2(0, WALL_BOTTOM), Vector2(1920, WALL_BOTTOM), Vector2(1920, WALL_BOTTOM + 60), Vector2(0, WALL_BOTTOM + 60)]),
		PackedColorArray([Color(0.05, 0.03, 0.2, 0.45), Color(0.05, 0.03, 0.2, 0.45), Color(0.05, 0.03, 0.2, 0), Color(0.05, 0.03, 0.2, 0)]))
	# La chimenea va encima del suelo por su losa / The fireplace goes over the floor because of its slab
	Sprites.draw(self, "lroom_fireplace")
	_draw_fire()
	_draw_moonlight()
	Sprites.draw(self, "lroom_rug")
	_draw_holes()
	_draw_wall_hole_floor()
	_draw_fire_light()
	Sprites.draw(self, "lroom_phone_table")
	Sprites.draw(self, "lroom_armchair")
	Sprites.draw(self, "lroom_tv")
	_draw_tv_screen()
	Sprites.draw(self, "lroom_plant")
	Sprites.draw(self, "lroom_lamp")
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(1250, 40, 260, 200), false, Color("ffe1a8", 0.25))
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(1270, 300, 220, 110), false, Color("ffe1a8", 0.12))
	_draw_hearth_charge()
	_draw_corruption()
	_draw_dream_stars()
	_draw_floating_things()
	_draw_room_edges()


func _draw_window_l() -> void:
	var w := WINDOW_L
	draw_texture_rect(DreamBackground.soft_texture(), w.grow(100), false, Color("c6d2ff", 0.18))
	var sky_top := Color("0c1240")
	var sky_bot := Color("4a2a7a")
	draw_polygon(PackedVector2Array([w.position, Vector2(w.end.x, w.position.y), w.end, Vector2(w.position.x, w.end.y)]),
		PackedColorArray([sky_top, sky_top, sky_bot, sky_bot]))
	for s in _window_stars_l:
		var p := w.position + Vector2(s["p"]) * w.size
		draw_rect(Rect2(p - Vector2(1.4, 1.4), Vector2(2.8, 2.8)), Color(UITheme.BONE, 0.5 + 0.4 * sin(_t * 1.7 + float(s["ph"]))))
	# Una luna que se repite en cada sueño más hondo / A moon that repeats with each deeper dream
	for i in 1 + mini(weird, 3):
		var m := w.position + Vector2(150 - i * 38, 46 + i * 26)
		draw_circle(m, 20 - i * 4, Color(["fbf4e2", "f2b8d8", "b9f0ea", "f6d993"][i]))
	Sprites.draw(self, "lroom_window_frame")
	Sprites.draw(self, "lroom_curtain_l", Color.WHITE, Vector2(sin(_t * 0.6 - 1.0) * 1.5, 0))
	Sprites.draw(self, "lroom_curtain_r", Color.WHITE, Vector2(sin(_t * 0.6 + 1.0) * 1.5, 0))
	Sprites.draw(self, "lroom_curtain_rod")


func _draw_moonlight() -> void:
	var c := Color("d6e0ff")
	draw_polygon(PackedVector2Array([
		Vector2(WINDOW_L.position.x + 10, WALL_BOTTOM), Vector2(WINDOW_L.end.x - 10, WALL_BOTTOM),
		Vector2(560, 900), Vector2(160, 900),
	]), PackedColorArray([Color(c, 0.12), Color(c, 0.12), Color(c, 0.0), Color(c, 0.0)]))


## Llamas que bailan dentro del hogar. Apagado solo quedan unas brasas.
## Flames dancing in the firebox. When out, only a few embers are left.
func _draw_fire() -> void:
	var base := Vector2(FIREBOX.get_center().x, FIREBOX.end.y - 14.0)
	if not fire_lit or (fire_used and _flare <= 0.0):
		for i in 5:
			var p := base + Vector2(-40 + i * 20, -4 + sin(i * 2.0) * 3.0)
			draw_circle(p, 3.0, Color("ff8a4a", 0.35 + 0.25 * sin(_t * 2.0 + i)))
		return
	var k := 1.0 + _flare * 0.8
	# Al sacrificar arde violeta un momento / After a sacrifice it burns violet for a moment
	var outer := Color("ff7a3a").lerp(Color("b98aff"), _flare)
	var mid := Color("ffb04a").lerp(Color("e0c8ff"), _flare)
	var inner := Color("fff0a8").lerp(Color("ffffff"), _flare)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(base - Vector2(120, 130) * k, Vector2(240, 170) * k), false, Color(outer, 0.45))
	for layer in 3:
		var col: Color = [outer, mid, inner][layer]
		var w := (64.0 - layer * 18.0) * k
		var h := (70.0 - layer * 18.0) * k
		for f in 5:
			var fx := (f - 2) * w * 0.35
			var flick := sin(_t * (7.0 + f) + f * 1.7 + layer) * 0.18 + sin(_t * 13.0 + f) * 0.08
			var fh := h * (0.75 + 0.25 * cos(f * 1.3)) * (1.0 + flick)
			var fw := w * 0.32
			var tip := base + Vector2(fx + sin(_t * 5.0 + f) * 5.0, -fh)
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(fx - fw, 0), base + Vector2(fx - fw * 0.6, -fh * 0.45),
				tip, base + Vector2(fx + fw * 0.6, -fh * 0.45), base + Vector2(fx + fw, 0),
			]), col)
	# Chispas que suben / Rising sparks
	for i in 6:
		var u := fposmod(_t * 0.6 + i * 0.17, 1.0)
		var p := base + Vector2(sin(i * 3.1 + _t) * 30.0, -20.0 - u * 110.0)
		if p.y > FIREBOX.position.y + 10.0:
			draw_rect(Rect2(p, Vector2(3, 3)), Color(inner, 1.0 - u))


func _draw_fire_light() -> void:
	if not fire_lit or (fire_used and _flare <= 0.0):
		return
	var pulse := 0.85 + 0.15 * sin(_t * 6.0) * sin(_t * 2.3)
	var col := Color("ff9a5a").lerp(Color("b98aff"), _flare)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(560, 250, 800, 380), false, Color(col, 0.22 * pulse))


## Marca en el suelo delante del hogar (el anillo de carga lo dibuja Kroker sobre su cabeza)
## Floor mark in front of the hearth (Kroker draws the charge ring over his head)
func _draw_hearth_charge() -> void:
	if not can_sacrifice():
		return
	var c := HEARTH_ZONE.get_center()
	var a := 0.25 + 0.15 * sin(_t * 3.0) + 0.4 * fire_charge
	draw_colored_polygon(_ellipse(c, Vector2(100, 34)), Color("ffb06a", a * 0.25))
	draw_polyline(_ellipse(c, Vector2(100, 34)) + PackedVector2Array([c + Vector2(100, 0)]), Color("ffb06a", a), 3.0)


## La tele antigua: nieve, rayas y, en los sueños raros, un Foox que asoma
## The old TV: static, stripes and, in strange dreams, a Foox peeking out
func _draw_tv_screen() -> void:
	var r := TV_SCREEN
	draw_texture_rect(DreamBackground.soft_texture(), r.grow(60), false, Color("9fd0ff", 0.2 + 0.05 * sin(_t * 9.0)))
	draw_rect(r, Color("2a3a6a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * 12.0)
	for i in 40:
		var p := r.position + Vector2(rng.randf() * (r.size.x - 4.0), rng.randf() * (r.size.y - 4.0))
		draw_rect(Rect2(p, Vector2(4, 4)), Color(UITheme.BONE, rng.randf_range(0.15, 0.5)))
	var band := fposmod(_t * 30.0, r.size.y)
	draw_rect(Rect2(r.position.x, r.position.y + band, r.size.x, 8), Color(1, 1, 1, 0.12))
	if tv_burst > 0.0:
		draw_rect(r, Color("ff5fd2", 0.35 * tv_burst))
		draw_texture_rect(DreamBackground.soft_texture(), r.grow(160), false, Color("ffd0f0", 0.4 * tv_burst))
	elif weird >= 2 and fposmod(_t, 7.0) < 2.0:
		var c := r.get_center()
		draw_colored_polygon(_ellipse(c + Vector2(0, 10), Vector2(26, 18)), Color("bcd0ff", 0.8))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 0), c + Vector2(-14, -26), c + Vector2(-4, -4)]), Color("bcd0ff", 0.8))
		draw_colored_polygon(PackedVector2Array([c + Vector2(20, 0), c + Vector2(14, -26), c + Vector2(4, -4)]), Color("bcd0ff", 0.8))
		draw_circle(c + Vector2(-8, 8), 3.0, Color("1a1a2e"))
		draw_circle(c + Vector2(8, 8), 3.0, Color("1a1a2e"))


## Mueble del salón que se ordena por altura con los personajes.
## A living-room piece that is depth-sorted with the characters.
class Prop extends Node2D:
	var sprite := ""
	var base := Vector2.ZERO

	func _ready() -> void:
		position = Bedroom.to_world(base)

	func _draw() -> void:
		draw_set_transform(-base * Bedroom.S, 0.0, Vector2(Bedroom.S, Bedroom.S))
		Sprites.draw(self, sprite)
		draw_set_transform(Vector2.ZERO)
