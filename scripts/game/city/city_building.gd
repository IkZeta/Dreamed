class_name CityBuilding
extends Node2D

const T := CityLayout.TILE
## Un edificio visto desde arriba y de frente, como en los juegos de Pokémon: tejado (a dos aguas
## en las casas, azotea con pretil en el resto), fachada con cornisa y zócalo, puerta con escalón,
## cartel en las tiendas y sombra en el suelo. Se transparenta si Kroker pasa por detrás.
## A building seen from above and the front, like in the Pokémon games: roof (pitched on houses,
## a flat roof with a parapet on the rest), facade with cornice and plinth, door with a step, a
## sign on shops and a shadow on the ground. It turns see-through if Kroker walks behind it.

var room: Act4Room
var run: Node
var style := ""
var rect := Rect2()        # huella en el lienzo / footprint on the canvas
var kind := "house"
var seed := 0
var screen_taken := false   # su pantalla se la ha llevado Evil Ad / Evil Ad has taken its screen
var burning := false        # ha estallado: ventanas rotas, fuego y humo / it blew up: broken windows, fire and smoke
var _burn_t := 0.0
var _t := 0.0
var _redraw_t := 0.0
const REDRAW_HZ := 12.0

## Estalla (cinemática del último sueño) / It blows up (last dream's cutscene)
func explode() -> void:
	burning = true
	_burn_t = 0.0
	set_process(true)
	var c := Bedroom.to_world(Vector2(rect.get_center().x, rect.end.y)) + Vector2(0, -Act4Room.FACADE_H * Bedroom.S * 0.6)
	run.fx.ring(c, 120.0, Color("ffd27a"), 0.6, 2.4)
	run.fx.ring(c, 60.0, Color("e0303a"), 0.5, 2.0)
	for i in 5:
		run.fx.dissipate(c + Vector2(randf_range(-rect.size.x, rect.size.x) * Bedroom.S * 0.4, randf_range(-60, 30)), Color("8a8490"))
	run.shake(12.0)
	Audio.play("stomp", -2.0, 0.15)
	Audio.play("crack", -4.0, 0.2)

func _ready() -> void:
	scale = Vector2(Bedroom.S, Bedroom.S)
	_redraw_t = fposmod(seed * 0.013, 1.0 / REDRAW_HZ)
	# Cada ciudad construye a su manera: en la brutalista no hay tejados a dos aguas, en la
	# synthwave las casas son tiendas con neón... / Each city builds its own way: no pitched roofs
	# in the brutalist one, houses are neon shops in the synthwave one...
	if kind == "house":
		match style:
			"brutalist": kind = "apart" if seed % 2 else "block"
			"synthwave": kind = "shop" if seed % 3 == 0 else "house"
			"aero": kind = "pod"

func _process(delta: float) -> void:
	if not is_instance_valid(room):
		return
	_t += delta
	if run == null or not is_instance_valid(run.player):
		return
	# Kroker detrás del edificio (tapado por el tejado): se ve a través / Kroker behind the building (hidden by the roof): see-through
	var p: Vector2 = (run.player.global_position - Bedroom.OFFSET) / Bedroom.S
	var top := rect.position.y - T * 0.5
	var behind := p.x > rect.position.x - 20.0 and p.x < rect.end.x + 20.0 and p.y > top and p.y < rect.end.y + 4.0
	modulate.a = move_toward(modulate.a, 0.45 if behind else 1.0, delta * 4.0)
	if burning:
		_burn_t += delta
	# Solo se vuelve a dibujar lo que se mueve y además está a la vista, y no en cada fotograma: el
	# neón y los brillos se ven igual a 12 por segundo (20 si arde) y cada edificio va a su turno
	# Only what moves and is on screen gets redrawn, and not every frame: neon and glints look the
	# same at 12 a second (20 while burning) and each building takes its own turn
	if kind in ["tower", "shop"] or burning or style in ANIMATED:
		_redraw_t -= delta
		if _redraw_t <= 0.0:
			_redraw_t += 1.0 / (20.0 if burning else REDRAW_HZ)
			if _redraw_t < 0.0:
				_redraw_t = fposmod(seed * 0.013, 1.0 / REDRAW_HZ)
			if _on_screen():
				queue_redraw()


## Estéticas con cosas que se mueven en las fachadas (neón, brillos, focos...)
## Looks with moving things on the facades (neon, glints, searchlights...)
const ANIMATED := ["noir", "synthwave", "aero", "dieselpunk"]


func _on_screen() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var c := cam.get_screen_center_position()
	var w := rect.size.x * Bedroom.S
	var h := (rect.size.y + T * 3.0) * Bedroom.S
	return absf(global_position.x + w * 0.5 - c.x) < 1100.0 + w * 0.5 and global_position.y - h < c.y + 700.0 and global_position.y > c.y - 700.0

func _c(key: String) -> Color:
	return room.look(key)

## Un tono distinto para cada edificio / A slightly different tone for each building
func _tone(c: Color, k := 0.12) -> Color:
	var h := fposmod(seed * 0.37, 1.0)
	return c.lerp(Color.from_hsv(fposmod(c.h + (h - 0.5) * 0.12, 1.0), c.s, c.v), 0.8).lightened((h - 0.5) * k)

func _draw() -> void:
	if not is_instance_valid(room):
		return
	var w := rect.size.x
	var d := rect.size.y
	var fh := facade_h()
	var top := -d - T * 0.5
	var rh := d + T * 0.5 - fh
	var edge := _c("edge")
	# De noche, la luz de los escaparates y ventanas cae en la acera / At night, light from shop windows and windows falls on the pavement
	if style in Act4Room.NIGHT:
		var soft := DreamBackground.soft_texture()
		var wl := Color({"synthwave": "ff5fa0", "steampunk": "ffd27a", "dieselpunk": "ffd27a", "noir": "f0d8a0"}[style])
		var x3 := 40.0
		while x3 < w - 60.0:
			draw_texture_rect(soft, Rect2(x3 - 30, -10, 160, 90), false, Color(wl, 0.22 if kind == "shop" else 0.12))
			x3 += 125.0
	# Sombra en el suelo, hacia la derecha y abajo / Shadow on the ground, to the right and down
	draw_colored_polygon(PackedVector2Array([Vector2(w, -d + 20), Vector2(w + 46, -d + 50), Vector2(w + 46, 30), Vector2(30, 30), Vector2(0, 0), Vector2(w, 0)]), Color(0.05, 0.02, 0.12, 0.28))
	# Tejado / Roof
	if kind == "house":
		_pitched_roof(top, rh, w)
	elif kind == "pod":
		_pod_roof(top, rh, w)
	else:
		_flat_roof(top, rh, w)
	# Fachada en tramos, con el tono del edificio / Facade in sections, in the building's tone
	var fac := "city_%s_%s" % [style, "facade_tall" if kind in ["tower", "apart"] else ("shopfront" if kind == "shop" else "facade")]
	var tint := Color.WHITE.lerp(_tone(Color(0.95, 0.92, 1.0), 0.1), 0.5)
	var x2 := 0.0
	while x2 < w:
		_draw_part(fac, Rect2(x2, -fh, minf(250.0, w - x2), fh), tint)
		x2 += 250.0
	# Cornisa arriba y zócalo abajo / Cornice on top and plinth at the bottom
	draw_rect(Rect2(-6, -fh - 4, w + 12, 16), _tone(_c("curb")).lightened(0.15))
	draw_rect(Rect2(-6, -fh + 12, w + 12, 4), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(0, -22, w, 22), _tone(_c("plinth")).darkened(0.35))
	draw_rect(Rect2(0, -22, w, 4), Color(1, 1, 1, 0.15))
	# Pilares en las esquinas / Corner pillars
	for x in [0.0, w - 14.0]:
		draw_rect(Rect2(x, -fh, 14, fh), Color(0, 0, 0, 0.18))
	# Puerta con escalón y felpudo / Door with a step and a doormat
	var dx := w / 2.0 - 62.5
	draw_rect(Rect2(dx - 10, -6, 145, 14), _c("plinth").lightened(0.2))
	draw_rect(Rect2(dx - 10, 6, 145, 4), Color(0, 0, 0, 0.3))
	Sprites.draw(self, "city_%s_door" % style, Color.WHITE, Vector2(dx, -202.0))
	draw_rect(Rect2(dx + 24, 10, 77, 12), _c("accent").darkened(0.3))
	_style_facade(w, fh, top)
	if kind == "shop":
		_shop_sign(w, fh)
	if kind == "tower":
		_tower_crown(w, fh, top)
	# Contorno oscuro de toda la silueta (pixel art) / Dark outline round the whole silhouette (pixel art)
	if kind != "pod":
		draw_rect(Rect2(0, top, w, d + T * 0.5), edge, false, 4.0)
	else:
		draw_rect(Rect2(0, -fh, w, fh), edge, false, 4.0)
	if style == "noir" and not screen_taken and kind != "house":
		_draw_screen(w, fh)
	if burning:
		_draw_fire(w, fh, top)

## Alto de la fachada: los bloques de pisos y la torre, más altos / Facade height: apartment blocks and the tower, taller
func facade_h() -> float:
	return Act4Room.TOWER_FACADE_H if kind in ["tower", "apart"] else Act4Room.FACADE_H

## Pantalla gigante en la fachada (sueño 20) / A giant screen on the facade (dream 20)
func screen_world() -> Vector2:
	var fh := facade_h()
	return global_position + Vector2(rect.size.x * 0.75, -fh * 0.62) * Bedroom.S

func _draw_screen(w: float, fh: float) -> void:
	var r := Rect2(w * 0.75 - 70, -fh * 0.62 - 48, 140, 96)
	draw_rect(r.grow(8), Color("0e0e12"))
	draw_rect(r, Color("1a0a10"))
	var on := fmod(_t * 0.8 + seed, 3.0)
	if on < 0.12:
		for i in 8:
			draw_rect(Rect2(r.position + Vector2(randf() * 120, randf() * 90), Vector2(16, 3)), Color(1, 1, 1, 0.6))
	else:
		CityBillboard.draw_ad(self, r.grow(-10), (seed + int(_t / 3.0)) % CityBillboard.ADS, _t)

## Fachada reventada: hollín, ventanas con fuego y humo saliendo del tejado
## Blown-out facade: soot, windows on fire and smoke pouring off the roof
func _draw_fire(w: float, fh: float, top: float) -> void:
	var k := minf(1.0, _burn_t * 3.0)
	draw_rect(Rect2(0, -fh, w, fh), Color(0.05, 0.03, 0.04, 0.45 * k))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 13 + 5
	for i in int(w / 70.0):
		var p := Vector2(rng.randf_range(30, w - 50), rng.randf_range(-fh + 40, -60))
		draw_rect(Rect2(p - Vector2(18, 14), Vector2(36, 28)), Color(0.02, 0.01, 0.02, k))
		var fl := 0.7 + 0.3 * sin(_t * 9.0 + i * 1.7)
		for j in 3:
			var fx := p.x - 12 + j * 12
			var h := (22.0 + 10.0 * sin(_t * 11.0 + i + j)) * fl
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 8, p.y + 10), Vector2(fx + 8, p.y + 10), Vector2(fx + sin(_t * 7.0 + j) * 4.0, p.y + 10 - h)]),
				Color(1.0, 0.45 + 0.2 * j, 0.1, 0.9 * k))
	# Humo / Smoke
	for i in 6:
		var ph := fposmod(_t * 0.25 + i / 6.0, 1.0)
		var sp := Vector2(w * (0.2 + 0.6 * fposmod(i * 0.37, 1.0)) + ph * 60.0, top - ph * 260.0)
		draw_circle(sp, 30.0 + ph * 50.0, Color(0.12, 0.1, 0.12, 0.45 * (1.0 - ph) * k))

## Detalles propios de cada ciudad sobre la fachada / Each city's own details on the facade
func _style_facade(w: float, fh: float, top: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 17 + 3
	match style:
		"synthwave":
			# Tubos de neón en la cornisa y en las esquinas, que laten / Neon tubes on the cornice and corners, pulsing
			var g := 0.7 + 0.3 * sin(_t * 2.5 + seed)
			var a := Color(_c("curb"), g)
			var b2 := Color(_c("accent"), g)
			draw_line(Vector2(0, -fh - 10), Vector2(w, -fh - 10), Color(a, 0.25), 14.0)
			draw_line(Vector2(0, -fh - 10), Vector2(w, -fh - 10), a, 4.0)
			for x in [10.0, w - 10.0]:
				draw_line(Vector2(x, -fh), Vector2(x, -30), Color(b2, 0.2), 14.0)
				draw_line(Vector2(x, -fh), Vector2(x, -30), b2, 4.0)
		"steampunk":
			# Tuberías de cobre bajando por la fachada, con juntas y una llave / Copper pipes down the facade, with joints and a valve
			for k in 2:
				var x := w * (0.18 + 0.64 * k) + rng.randf_range(-20, 20)
				draw_rect(Rect2(x, -fh, 12, fh - 24), Color("b87333"))
				draw_rect(Rect2(x, -fh, 4, fh - 24), Color("e8a868"))
				var y := -fh + 40.0
				while y < -40.0:
					draw_rect(Rect2(x - 3, y, 18, 8), Color("8a5428"))
					y += 70.0
				draw_circle(Vector2(x + 6, -fh * 0.45), 11.0, Color("c9961e"))
				draw_circle(Vector2(x + 6, -fh * 0.45), 5.0, Color("5a3a20"))
		"cheese":
			# Queso fundido chorreando desde el tejado / Melted cheese dripping from the roof
			var y0 := -fh - 6.0
			var x := 0.0
			while x < w:
				var dw := rng.randf_range(24, 44)
				var dh := rng.randf_range(10, 46)
				draw_rect(Rect2(x, y0, dw, 12), Color("ffc83a"))
				draw_rect(Rect2(x + dw * 0.3, y0 + 8, dw * 0.4, dh), Color("ffc83a"))
				draw_circle(Vector2(x + dw * 0.5, y0 + 8 + dh), dw * 0.22, Color("ffc83a"))
				draw_rect(Rect2(x + dw * 0.35, y0 + 10, 3, dh * 0.7), Color("fff0a0"))
				x += dw
		"aero":
			# Brillo de cristal que pasa y hojas verdes en las esquinas / A passing glass glint and green leaves at the corners
			var gx := fposmod(_t * 60.0 + seed * 90.0, w + 400.0) - 200.0
			draw_colored_polygon(PackedVector2Array([Vector2(gx, -fh), Vector2(gx + 40, -fh), Vector2(gx - 40, -24), Vector2(gx - 80, -24)]), Color(1, 1, 1, 0.18))
			for x in [26.0, w - 26.0]:
				draw_colored_polygon(room._ellipse(Vector2(x, -fh + 30), Vector2(18, 30)), Color("5fd07a"))
				draw_line(Vector2(x, -fh + 6), Vector2(x, -fh + 56), Color("c8ffd0"), 3.0)
		"solarpunk":
			# Hiedra que cuelga de la cornisa / Ivy hanging from the cornice
			var x := 6.0
			while x < w - 6.0:
				var hang := rng.randf_range(20, fh * 0.55)
				var y := -fh
				while y < -fh + hang:
					draw_circle(Vector2(x + sin(y * 0.08) * 5.0, y), 9.0, Color("3f9a4a") if int(y) % 3 else Color("5fb86a"))
					y += 12.0
				if rng.randf() < 0.4:
					draw_circle(Vector2(x, -fh + hang), 5.0, Color("ffb0c8"))
				x += rng.randf_range(26, 60)
		"dieselpunk":
			# Focos que barren el cielo desde la cornisa (de noche) / Searchlights sweeping the sky from the cornice (at night)
			if kind in ["apart", "tower"]:
				for k in 2:
					var o := Vector2(w * (0.25 + 0.5 * k), -fh - 6)
					var a := -PI / 2.0 + sin(_t * 0.6 + seed + k * 2.0) * 0.6
					var tip := o + Vector2.from_angle(a) * 420.0
					var side := Vector2.from_angle(a + PI / 2.0) * 50.0
					draw_colored_polygon(PackedVector2Array([o, tip + side, tip - side]), Color(1.0, 0.9, 0.6, 0.08))
					draw_circle(o, 10.0, Color("ffd27a"))
		"brutalist":
			# Manchas de lluvia bajo las ventanas y voladizos de hormigón / Rain stains under the windows and concrete overhangs
			for k in int(w / 60.0):
				var x := rng.randf_range(10, w - 20)
				var len := rng.randf_range(30, fh * 0.6)
				draw_rect(Rect2(x, -fh + 20, rng.randf_range(6, 14), len), Color(0.15, 0.17, 0.2, 0.13))
			if kind in ["apart", "block"]:
				var y := -fh + 110.0
				while y < -60.0:
					var x := rng.randf_range(10, w * 0.4)
					var bw := rng.randf_range(90, w * 0.5)
					draw_rect(Rect2(x, y, bw, 14), _tone(_c("plinth")).lightened(0.05))
					draw_rect(Rect2(x, y + 14, bw, 8), Color(0, 0, 0, 0.3))
					y += 120.0

## Suelo de la azotea propio de cada ciudad; true si sustituye a la tela asfáltica
## Each city's own roof surface; true if it replaces the membrane
func _roof_surface(top: float, h: float, w: float, base: Color, rng: RandomNumberGenerator) -> bool:
	var inner := Rect2(18, top + 18, w - 36, h - 36)
	match style:
		"solarpunk":
			# Cubierta verde: césped, caminito de losas y matas / Green roof: lawn, a stepping-stone path and shrubs
			draw_rect(inner, Color("6ab86a"))
			for i in int(inner.size.x * inner.size.y / 1600.0):
				var q := inner.position + Vector2(rng.randf() * inner.size.x, rng.randf() * inner.size.y)
				draw_rect(Rect2(q, Vector2(5, 9)), Color("8fd88a") if i % 2 else Color("4f9a50"))
			var px := inner.position.x + inner.size.x * 0.5
			var yy := inner.position.y + 20.0
			while yy < inner.end.y - 30.0:
				draw_rect(Rect2(px - 22 + sin(yy * 0.02) * 30.0, yy, 44, 26), Color("e8e0c8"))
				yy += 46.0
			for k in 4:
				var q := inner.position + Vector2(rng.randf_range(30, inner.size.x - 30), rng.randf_range(30, inner.size.y - 30))
				draw_circle(q + Vector2(4, 8), 22.0, Color(0, 0, 0, 0.15))
				draw_circle(q, 22.0, Color("3f9a4a"))
				draw_circle(q + Vector2(-6, -6), 9.0, Color("7fcf7a"))
			return true
		"aero":
			# Lucernario de cristal con reflejos / Glass skylight with reflections
			draw_rect(inner, Color("9fd8f4"))
			var x := inner.position.x
			while x < inner.end.x:
				draw_rect(Rect2(x, inner.position.y, 4, inner.size.y), Color("ffffff", 0.8))
				x += 70.0
			var y := inner.position.y
			while y < inner.end.y:
				draw_rect(Rect2(inner.position.x, y, inner.size.x, 4), Color("ffffff", 0.8))
				y += 70.0
			draw_colored_polygon(PackedVector2Array([inner.position + Vector2(40, 0), inner.position + Vector2(140, 0), inner.position + Vector2(40, 140), inner.position + Vector2(0, 140)]), Color(1, 1, 1, 0.3))
			return true
		"synthwave":
			# Rejilla de neón tenue / Dim neon grid
			draw_rect(inner, base.darkened(0.25))
			var g := 0.35 + 0.15 * sin(_t * 1.5 + seed)
			var x := inner.position.x + 30.0
			while x < inner.end.x:
				draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(_c("accent"), g), 2.0)
				x += 60.0
			var y := inner.position.y + 30.0
			while y < inner.end.y:
				draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(_c("curb"), g), 2.0)
				y += 60.0
			return true
		"steampunk":
			# Chapa de cobre con costuras remachadas y pátina / Copper sheet with riveted seams and patina
			draw_rect(inner, Color("a8683a"))
			var x := inner.position.x
			var k := 0
			while x < inner.end.x:
				draw_rect(Rect2(x, inner.position.y, 60, inner.size.y), Color("b87843") if k % 2 else Color("9a5e34"))
				draw_rect(Rect2(x, inner.position.y, 4, inner.size.y), Color("6a3a20"))
				var y := inner.position.y + 10.0
				while y < inner.end.y:
					draw_rect(Rect2(x + 6, y, 3, 3), Color("e8b078"))
					y += 24.0
				x += 60.0
				k += 1
			for i in 4:
				var q := inner.position + Vector2(rng.randf() * inner.size.x, rng.randf() * inner.size.y)
				draw_colored_polygon(room._ellipse(q, Vector2(rng.randf_range(20, 50), rng.randf_range(10, 22))), Color("4f8a7a", 0.55))
			return true
	return false

## Casa cápsula de frutiger aero: tejado redondeado y brillante / Frutiger aero pod house: rounded glossy roof
func _pod_roof(top: float, h: float, w: float) -> void:
	var base := _tone(_c("roof"), 0.1)
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		pts.append(Vector2(w / 2.0 + cos(a) * w / 2.0, top + h + sin(a) * h))
	draw_colored_polygon(pts, base)
	var hi := PackedVector2Array()
	for i in 13:
		var a := PI * 1.1 + PI * 0.45 * i / 12.0
		hi.append(Vector2(w / 2.0 + cos(a) * w * 0.4, top + h + sin(a) * h * 0.8))
	draw_polyline(hi, Color(1, 1, 1, 0.7), 10.0)
	draw_rect(Rect2(-8, top + h - 14, w + 16, 16), base.darkened(0.3))
	draw_rect(Rect2(-8, top + h - 14, w + 16, 4), Color("c8ffd0"))
	draw_circle(Vector2(w * 0.7, top + h * 0.45), 26.0, Color(0.85, 0.97, 1.0, 0.8))
	draw_arc(Vector2(w * 0.7, top + h * 0.45), 26.0, 0, TAU, 20, Color(1, 1, 1, 0.9), 3.0)

## Tejado a dos aguas con tejas / Pitched roof with tiles
func _pitched_roof(top: float, h: float, w: float) -> void:
	var base := _tone(_c("roof"), 0.16)
	var ridge := top + h * 0.38
	draw_rect(Rect2(0, top, w, ridge - top), base.lightened(0.12))
	draw_rect(Rect2(0, ridge, w, top + h - ridge), base.darkened(0.08))
	# Filas de tejas al tresbolillo / Staggered rows of tiles
	var y := top + 10.0
	var row := 0
	while y < top + h - 8.0:
		draw_rect(Rect2(0, y, w, 4), Color(0, 0, 0, 0.18))
		var x := 18.0 if row % 2 else 0.0
		while x < w:
			draw_rect(Rect2(x, y - 16, 4, 16), Color(0, 0, 0, 0.12))
			x += 36.0
		y += 22.0
		row += 1
	# Cumbrera y alero / Ridge and eaves
	draw_rect(Rect2(0, ridge - 6, w, 12), base.lightened(0.3))
	draw_rect(Rect2(-10, top + h - 12, w + 20, 14), base.darkened(0.35))
	draw_rect(Rect2(-10, top + h - 12, w + 20, 4), base.lightened(0.2))
	# Chimenea / Chimney
	var cx := w * (0.2 + fposmod(seed * 0.31, 0.5))
	draw_rect(Rect2(cx, top - 26, 40, 58), _tone(_c("plinth")).darkened(0.3))
	draw_rect(Rect2(cx - 5, top - 30, 50, 10), _tone(_c("plinth")).darkened(0.5))
	draw_rect(Rect2(cx, top - 26, 8, 58), Color(1, 1, 1, 0.15))
	# Cada ciudad le pone lo suyo / Each city adds its own touch
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7 + 1
	match style:
		"synthwave":
			var g := 0.7 + 0.3 * sin(_t * 2.0 + seed)
			draw_line(Vector2(0, ridge), Vector2(w, ridge), Color(_c("accent"), 0.25 * g), 16.0)
			draw_line(Vector2(0, ridge), Vector2(w, ridge), Color(_c("accent"), g), 4.0)
		"steampunk", "dieselpunk":
			# Buhardillas con ventana encendida / Dormers with a lit window
			var n := maxi(1, int(w / 220.0))
			for k in n:
				var dx := w * (k + 0.5) / n - 30.0
				var dy := ridge + 20.0
				draw_rect(Rect2(dx, dy, 60, 56), base.darkened(0.25))
				draw_colored_polygon(PackedVector2Array([Vector2(dx - 8, dy), Vector2(dx + 68, dy), Vector2(dx + 30, dy - 30)]), base.darkened(0.4))
				draw_rect(Rect2(dx + 14, dy + 12, 32, 34), Color("2a1a14"))
				draw_rect(Rect2(dx + 17, dy + 15, 26, 28), Color("ffd27a"))
				draw_rect(Rect2(dx + 29, dy + 15, 2, 28), Color("2a1a14"))
			draw_rect(Rect2(0, ridge - 6, w, 12), Color("4f8a7a") if style == "steampunk" else Color("c9961e"))
		"cheese":
			for k in int(w / 90.0):
				var q := Vector2(rng.randf_range(30, w - 30), rng.randf_range(top + 20, top + h - 30))
				var rr := rng.randf_range(10, 22)
				draw_colored_polygon(room._ellipse(q, Vector2(rr, rr * 0.7)), base.darkened(0.25))
				draw_colored_polygon(room._ellipse(q + Vector2(0, 3), Vector2(rr * 0.7, rr * 0.45)), base.darkened(0.4))
		"solarpunk":
			# Tejado verde con hierba y flores / Green roof with grass and flowers
			for k in int(w * h / 1400.0):
				var q := Vector2(rng.randf_range(8, w - 12), rng.randf_range(top + 6, top + h - 20))
				draw_rect(Rect2(q, Vector2(6, 10)), Color("7fcf7a") if k % 2 else Color("3f9a4a"))
				if k % 9 == 0:
					draw_circle(q, 5.0, Color("ffd060") if k % 2 else Color("ff8fb0"))
			# Placas solares en un faldón / Solar panels on one slope
			for k in maxi(1, int(w / 180.0)):
				var q := Vector2(30 + k * 170.0, ridge + 24.0)
				if q.x + 130.0 < w:
					draw_rect(Rect2(q, Vector2(130, 60)), Color("2a4a8a"))
					draw_rect(Rect2(q, Vector2(130, 60)), Color("8fb8f0"), false, 3.0)
					draw_line(q + Vector2(65, 0), q + Vector2(65, 60), Color("8fb8f0"), 2.0)

## Azotea con pretil: tela asfáltica en placas, gravilla, manchas, y encima máquinas, placas solares,
## helipuerto o el detalle propio de cada estética
## Flat roof with a parapet: membrane in panels, gravel, stains, and on top machines, solar panels,
## a helipad or each look's own detail
func _flat_roof(top: float, h: float, w: float) -> void:
	var base := _tone(_c("flat"), 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + 7
	draw_rect(Rect2(0, top, w, h), base)
	var y := top + 16.0
	var row := 0
	if _roof_surface(top, h, w, base, rng):
		y = INF   # sin placas de tela / no membrane panels
	# Placas de la tela, al tresbolillo / Membrane panels, staggered
	while y < top + h - 16.0:
		draw_rect(Rect2(16, y, w - 32, 3), base.darkened(0.12))
		var x := 16.0 + (60.0 if row % 2 else 0.0)
		while x < w - 16.0:
			draw_rect(Rect2(x, y, 3, minf(70.0, top + h - 16.0 - y)), base.darkened(0.08))
			x += 120.0
		y += 70.0
		row += 1
	# Gravilla y manchas de agua / Gravel and water stains
	for i in int(w * h / 900.0):
		var q := Vector2(rng.randf_range(20, w - 24), rng.randf_range(top + 20, top + h - 24))
		draw_rect(Rect2(q, Vector2(4, 4)), base.lightened(0.12) if i % 2 else base.darkened(0.15))
	for i in 2:
		var q := Vector2(rng.randf_range(60, w - 60), rng.randf_range(top + 50, top + h - 50))
		draw_colored_polygon(room._ellipse(q, Vector2(rng.randf_range(30, 60), rng.randf_range(14, 24))), Color(0, 0, 0, 0.07))
	# Pretil: borde claro con cara interior en sombra / Parapet: light rim with a shaded inner face
	var lip := base.lightened(0.3)
	draw_rect(Rect2(0, top, w, 18), lip)
	draw_rect(Rect2(0, top, 18, h), lip)
	draw_rect(Rect2(w - 18, top, 18, h), lip)
	draw_rect(Rect2(0, top + h - 18, w, 18), lip.darkened(0.08))
	draw_rect(Rect2(0, top, w, 5), lip.lightened(0.25))
	draw_rect(Rect2(18, top + 18, w - 36, 12), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(18, top + 18, 10, h - 36), Color(0, 0, 0, 0.15))
	# Lo que hay encima, en una rejilla para que no se pisen / What's on top, in a grid so nothing overlaps
	var inner := Rect2(40, top + 44, w - 80, h - 88)
	var cols := maxi(1, int(inner.size.x / 190.0))
	var rows := maxi(1, int(inner.size.y / 150.0))
	var cw := inner.size.x / cols
	var ch := inner.size.y / rows
	var big := kind == "apart" and cols >= 3 and rows >= 2
	for r in rows:
		for c in cols:
			var cell := Rect2(inner.position + Vector2(c * cw, r * ch), Vector2(cw, ch))
			if big and r == 0 and c == cols - 1:
				continue
			if rng.randf() < 0.3:
				continue
			var at := cell.position + Vector2(rng.randf_range(4, maxf(5, cw - 150)), rng.randf_range(4, maxf(5, ch - 110)))
			var pool: Array = ROOF_THINGS[style]
			_roof_thing(pool[rng.randi() % pool.size()], at, base, rng)
	if big:
		var hc := Vector2(inner.end.x - cw * 0.5, inner.position.y + ch * 0.5)
		var hr := minf(cw, ch) * 0.42
		match style:
			"steampunk": _big_gear(hc, hr)
			"cheese": _cheese_wedge(hc, hr)
			"solarpunk": _turbine(hc + Vector2(0, hr * 0.6), hr * 1.1)
			"dieselpunk", "noir": _mooring_mast(hc + Vector2(0, hr * 0.5), hr)
			_: _helipad(hc, hr)
	_style_roof(Rect2(0, top, w, h), base)

## Qué hay en las azoteas de cada ciudad (0-6 comunes, 7+ propias) / What's on each city's roofs (0-6 common, 7+ its own)
const ROOF_THINGS := {
	"synthwave": [0, 2, 7, 7, 8, 6],
	"steampunk": [2, 3, 9, 9, 10, 5],
	"cheese": [3, 11, 11, 12, 2],
	"aero": [13, 13, 14, 6, 4],
	"solarpunk": [4, 4, 15, 15, 14, 2],
	"dieselpunk": [16, 16, 17, 20, 21, 21],
	"brutalist": [18, 18, 19, 1, 3],
	"noir": [16, 16, 20, 17, 21, 0],
}

func _roof_thing(k: int, at: Vector2, base: Color, rng: RandomNumberGenerator) -> void:
	if k >= 20:
		_deco(k, at, base)
		return
	if k >= 7:
		_style_thing(k, at, base)
		return
	var x := at.x
	var yy := at.y
	var shade := Color(0, 0, 0, 0.25)
	match k:
		0, 1:   # aires acondicionados / AC units
			for j in (2 if k == 1 else 1):
				var o := Vector2(j * 96, 0)
				draw_rect(Rect2(at + o + Vector2(8, 58), Vector2(88, 14)), shade)
				draw_rect(Rect2(at + o, Vector2(88, 62)), Color("a6acc8"))
				draw_rect(Rect2(at + o, Vector2(88, 10)), Color("d4d8ea"))
				draw_rect(Rect2(at + o + Vector2(0, 54), Vector2(88, 8)), Color("6a708c"))
				var fc := at + o + Vector2(44, 32)
				draw_circle(fc, 20.0, Color("4a4f6a"))
				draw_circle(fc, 20.0, Color("2a2e44"), false, 3.0)
				var a := _t * 6.0 + j
				draw_line(fc - Vector2.from_angle(a) * 17, fc + Vector2.from_angle(a) * 17, Color("9aa0c0"), 4.0)
				draw_line(fc - Vector2.from_angle(a + 1.57) * 17, fc + Vector2.from_angle(a + 1.57) * 17, Color("9aa0c0"), 4.0)
		2:   # depósito de agua sobre patas / water tank on legs
			var tc := _c("accent").darkened(0.35)
			draw_colored_polygon(room._ellipse(at + Vector2(58, 100), Vector2(54, 14)), shade)
			for lx in [14.0, 50.0, 86.0]:
				draw_rect(Rect2(at + Vector2(lx, 58), Vector2(8, 40)), Color("4a3a30"))
			draw_colored_polygon(room._ellipse(at + Vector2(54, 64), Vector2(48, 16)), tc.darkened(0.2))
			draw_rect(Rect2(at + Vector2(6, 0), Vector2(96, 64)), tc)
			for b in 3:
				draw_rect(Rect2(at + Vector2(6, 14 + b * 18), Vector2(96, 4)), tc.darkened(0.3))
			draw_rect(Rect2(at + Vector2(16, 0), Vector2(10, 64)), Color(1, 1, 1, 0.15))
			draw_colored_polygon(room._ellipse(at + Vector2(54, 0), Vector2(48, 16)), tc.lightened(0.2))
			draw_colored_polygon(PackedVector2Array([at + Vector2(6, 0), at + Vector2(54, -34), at + Vector2(102, 0)]), tc.darkened(0.15))
		3:   # caseta de la escalera / stairwell hut
			draw_rect(Rect2(at + Vector2(10, 74), Vector2(116, 16)), shade)
			draw_rect(Rect2(at + Vector2(0, 0), Vector2(116, 22)), base.lightened(0.35))
			draw_rect(Rect2(at + Vector2(0, 22), Vector2(116, 62)), base.darkened(0.15))
			draw_rect(Rect2(at + Vector2(40, 36), Vector2(36, 48)), _c("edge"))
			draw_rect(Rect2(at + Vector2(44, 40), Vector2(28, 44)), _c("accent").darkened(0.5))
			draw_circle(at + Vector2(66, 62), 3.0, _c("curb"))
			draw_rect(Rect2(at + Vector2(-4, -4), Vector2(124, 8)), base.lightened(0.5))
		4:   # placas solares / solar panels
			for j in 3:
				var o := at + Vector2(j * 46, 0)
				draw_rect(Rect2(o + Vector2(6, 70), Vector2(40, 10)), shade)
				draw_rect(Rect2(o, Vector2(40, 74)), Color("c8ccd8"))
				draw_rect(Rect2(o + Vector2(3, 3), Vector2(34, 68)), Color("24306a"))
				for g in 3:
					draw_rect(Rect2(o + Vector2(3, 3 + g * 23), Vector2(34, 2)), Color("6a7ad0"))
				draw_line(o + Vector2(20, 3), o + Vector2(20, 71), Color("6a7ad0"), 2.0)
				draw_rect(Rect2(o + Vector2(6, 6), Vector2(8, 18)), Color(1, 1, 1, 0.3))
		5:   # chimeneas de ventilación / ventilation stacks
			for j in 3:
				var o := at + Vector2(j * 34, (j % 2) * 20)
				draw_colored_polygon(room._ellipse(o + Vector2(16, 56), Vector2(16, 6)), shade)
				draw_rect(Rect2(o, Vector2(28, 54)), Color("8a8ea6"))
				draw_rect(Rect2(o, Vector2(8, 54)), Color(1, 1, 1, 0.2))
				draw_rect(Rect2(o + Vector2(-5, -6), Vector2(38, 10)), Color("5a5e76"))
		6:   # claraboyas / skylights
			for j in 2:
				var o := at + Vector2(j * 70, 0)
				draw_rect(Rect2(o + Vector2(4, 54), Vector2(62, 10)), shade)
				draw_rect(Rect2(o, Vector2(62, 58)), _c("edge"))
				draw_rect(Rect2(o + Vector2(5, 5), Vector2(52, 48)), Color("8fd8ff").lerp(_c("accent"), 0.2))
				draw_line(o + Vector2(31, 5), o + Vector2(31, 53), _c("edge"), 4.0)
				draw_line(o + Vector2(10, 46), o + Vector2(26, 10), Color(1, 1, 1, 0.55), 4.0)

func _style_thing(k: int, at: Vector2, base: Color) -> void:
	var shade := Color(0, 0, 0, 0.25)
	var acc := _c("accent")
	match k:
		7:   # antena parabólica de neón / neon satellite dish
			var c := at + Vector2(50, 40)
			draw_colored_polygon(room._ellipse(c + Vector2(6, 40), Vector2(40, 10)), shade)
			draw_line(c + Vector2(0, 40), c, Color("2a1850"), 8.0)
			draw_colored_polygon(room._ellipse(c + Vector2(0, -10), Vector2(44, 30)), Color("3a2466"))
			draw_colored_polygon(room._ellipse(c + Vector2(4, -12), Vector2(34, 22)), Color("5a3a8a"))
			var pts := room._ellipse(c + Vector2(0, -10), Vector2(44, 30))
			pts.append(pts[0])
			draw_polyline(pts, Color(_c("curb"), 0.6 + 0.4 * sin(_t * 3.0 + at.x)), 4.0)
			draw_line(c + Vector2(4, -12), c + Vector2(26, -44), Color("5ff2ff"), 3.0)
			draw_circle(c + Vector2(26, -44), 6.0, Color("5ff2ff", 0.6 + 0.4 * sin(_t * 5.0)))
		8:   # pirámide de holograma / hologram pyramid
			var c := at + Vector2(50, 70)
			draw_rect(Rect2(c + Vector2(-40, -8), Vector2(80, 18)), Color("2a1850"))
			draw_rect(Rect2(c + Vector2(-40, -8), Vector2(80, 4)), Color("5ff2ff"))
			var h := 70.0 + sin(_t * 2.0) * 6.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -8), c + Vector2(34, -8), c + Vector2(0, -8 - h)]), Color(0.37, 0.95, 1.0, 0.25))
			draw_polyline(PackedVector2Array([c + Vector2(-34, -8), c + Vector2(0, -8 - h), c + Vector2(34, -8)]), Color(1.0, 0.36, 0.63, 0.8), 3.0)
			for j in 3:
				var yy := fposmod(_t * 30.0 + j * 22.0, h)
				var hw := 34.0 * (1.0 - yy / h)
				draw_line(c + Vector2(-hw, -8 - yy), c + Vector2(hw, -8 - yy), Color(0.37, 0.95, 1.0, 0.5), 2.0)
		9:   # caldera de latón con manómetro / brass boiler with a gauge
			draw_colored_polygon(room._ellipse(at + Vector2(64, 92), Vector2(60, 12)), shade)
			draw_rect(Rect2(at + Vector2(10, 20), Vector2(110, 70)), Color("8a5a24"))
			draw_colored_polygon(room._ellipse(at + Vector2(10, 55), Vector2(16, 35)), Color("a8742a"))
			draw_colored_polygon(room._ellipse(at + Vector2(120, 55), Vector2(16, 35)), Color("c9961e"))
			for j in 4:
				draw_rect(Rect2(at + Vector2(30 + j * 24, 20), Vector2(5, 70)), Color("5a3a18"))
			draw_rect(Rect2(at + Vector2(10, 24), Vector2(110, 8)), Color(1, 0.9, 0.6, 0.3))
			draw_circle(at + Vector2(66, 10), 16.0, Color("c9961e"))
			draw_circle(at + Vector2(66, 10), 12.0, Color("f6eedc"))
			var a := -2.4 + sin(_t * 1.7) * 0.8
			draw_line(at + Vector2(66, 10), at + Vector2(66, 10) + Vector2.from_angle(a) * 10.0, Color("c83a2a"), 2.0)
			var ph := fposmod(_t * 0.8, 1.0)
			draw_circle(at + Vector2(104 + ph * 20, -2 - ph * 50), 8.0 + ph * 14.0, Color(1, 1, 1, 0.5 * (1.0 - ph)))
			draw_rect(Rect2(at + Vector2(98, -6), Vector2(12, 28)), Color("6a3a24"))
		10:   # engranajes que giran / turning gears
			_gear(at + Vector2(40, 40), 34.0, _t * 0.8, Color("c9961e"))
			_gear(at + Vector2(96, 64), 24.0, -_t * 1.13 + 0.3, Color("a8742a"))
		11:   # cuña de queso pequeña / small cheese wedge
			_cheese_wedge(at + Vector2(60, 50), 48.0)
		12:   # lata de galletas / biscuit tin
			draw_colored_polygon(room._ellipse(at + Vector2(52, 70), Vector2(50, 14)), shade)
			draw_rect(Rect2(at + Vector2(6, 20), Vector2(92, 50)), Color("c8402a"))
			draw_colored_polygon(room._ellipse(at + Vector2(52, 70), Vector2(46, 12)), Color("a83020"))
			draw_colored_polygon(room._ellipse(at + Vector2(52, 20), Vector2(46, 14)), Color("e8b468"))
			for j in 5:
				draw_circle(at + Vector2(22 + j * 15, 20), 2.5, Color("b07a3a"))
			draw_rect(Rect2(at + Vector2(6, 40), Vector2(92, 8)), Color("f2c83a"))
		13:   # burbuja de cristal con planta / glass bubble with a plant
			var c := at + Vector2(54, 50)
			draw_colored_polygon(room._ellipse(c + Vector2(6, 38), Vector2(44, 10)), shade)
			draw_colored_polygon(room._ellipse(c + Vector2(0, 30), Vector2(40, 10)), Color("2cc84a"))
			draw_circle(c + Vector2(-6, 18), 12.0, Color("3cd060"))
			draw_circle(c + Vector2(10, 14), 10.0, Color("5ae07a"))
			draw_circle(c, 44.0, Color(0.7, 0.92, 1.0, 0.35))
			draw_arc(c, 44.0, 0.0, TAU, 32, Color(1, 1, 1, 0.85), 3.0)
			draw_arc(c, 34.0, 3.6, 4.6, 12, Color(1, 1, 1, 0.9), 6.0)
			draw_circle(c + Vector2(18, -22), 5.0, Color.WHITE)
		14:   # mini aerogenerador blanco / small white wind turbine
			_turbine(at + Vector2(50, 90), 70.0)
		15:   # bancal del huerto / garden bed
			draw_rect(Rect2(at + Vector2(6, 64), Vector2(130, 12)), shade)
			draw_rect(Rect2(at, Vector2(130, 66)), Color("7a5a3a"))
			draw_rect(Rect2(at + Vector2(6, 6), Vector2(118, 54)), Color("4a3424"))
			for j in 6:
				for r in 2:
					var q := at + Vector2(18 + j * 19, 20 + r * 24)
					draw_circle(q, 9.0, Color("4fa85a").lightened(0.1 * ((j + r) % 2)))
					if (j + r) % 3 == 0:
						draw_circle(q + Vector2(2, -2), 4.0, Color("ff5a4a"))
		16:   # foco antiaéreo que barre el cielo / searchlight sweeping the sky
			var c := at + Vector2(50, 60)
			var a := -PI / 2 + sin(_t * 0.7 + at.x) * 0.7
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.16) * 340.0, c + Vector2.from_angle(a + 0.16) * 340.0]), Color(1.0, 0.9, 0.6, 0.1))
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.07) * 340.0, c + Vector2.from_angle(a + 0.07) * 340.0]), Color(1.0, 0.95, 0.75, 0.16))
			draw_colored_polygon(room._ellipse(c + Vector2(4, 22), Vector2(36, 10)), shade)
			draw_rect(Rect2(c + Vector2(-24, 0), Vector2(48, 22)), Color("3a363c"))
			draw_circle(c, 22.0, Color("58505a"))
			draw_circle(c + Vector2.from_angle(a) * 8.0, 15.0, Color("fff0c0"))
		17:   # torre de radio / radio mast
			var c := at + Vector2(50, 100)
			draw_line(c + Vector2(-24, 0), c + Vector2(0, -110), Color("1a1618"), 4.0)
			draw_line(c + Vector2(24, 0), c + Vector2(0, -110), Color("1a1618"), 4.0)
			for j in 4:
				var y := -20.0 - j * 24.0
				var hw := 24.0 * (1.0 + y / 110.0)
				draw_line(c + Vector2(-hw, y), c + Vector2(hw, y), Color("1a1618"), 3.0)
			draw_circle(c + Vector2(0, -114), 6.0, Color(1, 0.2, 0.15, 0.5 + 0.5 * sin(_t * 3.0)))
		18:   # bloque de hormigón con franja amarilla / concrete block with a yellow stripe
			draw_rect(Rect2(at + Vector2(10, 70), Vector2(110, 14)), shade)
			draw_rect(Rect2(at, Vector2(110, 76)), base.lightened(0.12))
			draw_rect(Rect2(at, Vector2(110, 14)), base.lightened(0.28))
			draw_rect(Rect2(at + Vector2(0, 64), Vector2(110, 12)), base.darkened(0.2))
			for j in 5:
				draw_colored_polygon(PackedVector2Array([at + Vector2(j * 22, 40), at + Vector2(j * 22 + 12, 40), at + Vector2(j * 22 + 22, 52), at + Vector2(j * 22 + 10, 52)]), acc)
			draw_rect(Rect2(at + Vector2(20, 22), Vector2(4, 4)), base.darkened(0.3))
			draw_rect(Rect2(at + Vector2(86, 22), Vector2(4, 4)), base.darkened(0.3))
		19:   # tiro de ventilación con rejilla / ventilation shaft with a grille
			draw_rect(Rect2(at + Vector2(8, 70), Vector2(80, 12)), shade)
			draw_rect(Rect2(at, Vector2(80, 74)), base.darkened(0.08))
			draw_rect(Rect2(at + Vector2(10, 10), Vector2(60, 46)), Color("1e2026"))
			for j in 5:
				draw_rect(Rect2(at + Vector2(10, 14 + j * 9), Vector2(60, 3)), base.lightened(0.1))
			draw_rect(Rect2(at + Vector2(0, 62), Vector2(80, 6)), acc)

func _deco(k: int, at: Vector2, base: Color) -> void:
	var gold := Color("e0b53a")
	var shade := Color(0, 0, 0, 0.25)
	if k == 20:   # aguja art déco escalonada / stepped art deco spire
		var c := at + Vector2(60, 100)
		draw_colored_polygon(room._ellipse(c + Vector2(10, 4), Vector2(56, 12)), shade)
		for j in 4:
			var hw := 50.0 - j * 11.0
			var y := -j * 28.0
			draw_rect(Rect2(c + Vector2(-hw, y - 28), Vector2(hw * 2, 28)), base.lightened(0.1 + j * 0.06))
			draw_rect(Rect2(c + Vector2(-hw, y - 28), Vector2(hw * 2, 4)), gold)
			draw_rect(Rect2(c + Vector2(-hw, y - 28), Vector2(6, 28)), Color(1, 1, 1, 0.12))
		draw_line(c + Vector2(0, -112), c + Vector2(0, -170), gold, 5.0)
		draw_circle(c + Vector2(0, -172), 6.0, Color(1, 0.3, 0.2, 0.5 + 0.5 * sin(_t * 2.5 + at.x)))
	else:   # depósito remachado sobre patas / riveted tank on legs
		var c := at + Vector2(56, 40)
		draw_colored_polygon(room._ellipse(c + Vector2(8, 64), Vector2(50, 12)), shade)
		for lx in [-34.0, 0.0, 34.0]:
			draw_line(c + Vector2(lx, 30), c + Vector2(lx * 1.2, 62), Color("2a2220"), 6.0)
		draw_line(c + Vector2(-40, 50), c + Vector2(40, 50), Color("2a2220"), 3.0)
		draw_rect(Rect2(c + Vector2(-42, -26), Vector2(84, 58)), Color("6a3a2a"))
		draw_colored_polygon(room._ellipse(c + Vector2(0, 32), Vector2(42, 10)), Color("5a2e22"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-46, -26), c + Vector2(46, -26), c + Vector2(0, -56)]), Color("4a2a20"))
		for j in 3:
			for i in 7:
				draw_circle(c + Vector2(-36 + i * 12, -16 + j * 20), 2.0, Color("a8745a"))
		draw_rect(Rect2(c + Vector2(-42, -4), Vector2(84, 10)), gold.darkened(0.2))
		draw_rect(Rect2(c + Vector2(-34, -26), Vector2(8, 58)), Color(1, 1, 1, 0.12))

## Mástil de amarre de zepelines, con su baliza / Zeppelin mooring mast, with its beacon
func _mooring_mast(base_p: Vector2, r: float) -> void:
	var gold := Color("e0b53a")
	var h := r * 2.4
	draw_colored_polygon(room._ellipse(base_p + Vector2(10, 6), Vector2(r * 0.8, r * 0.22)), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(base_p + Vector2(-r * 0.6, -16), Vector2(r * 1.2, 20)), Color("3a3230"))
	draw_rect(Rect2(base_p + Vector2(-r * 0.6, -16), Vector2(r * 1.2, 4)), gold)
	for side in [-1.0, 1.0]:
		draw_line(base_p + Vector2(side * r * 0.45, -16), base_p + Vector2(side * 8.0, -h), Color("2a2220"), 6.0)
	for j in 6:
		var y := -16.0 - (h - 16.0) * (j + 1) / 7.0
		var hw := lerpf(r * 0.45, 8.0, (j + 1) / 7.0)
		draw_line(base_p + Vector2(-hw, y), base_p + Vector2(hw, y), Color("2a2220"), 3.0)
		draw_line(base_p + Vector2(-hw, y), base_p + Vector2(hw * 0.8, y - 14), Color("2a2220"), 2.0)
	draw_circle(base_p + Vector2(0, -h), 14.0, gold)
	draw_circle(base_p + Vector2(0, -h - 4), 8.0, Color(1, 0.3, 0.2, 0.5 + 0.5 * sin(_t * 3.0)))
	draw_circle(base_p + Vector2(0, -h - 4), 26.0 * (0.5 + 0.5 * sin(_t * 3.0)), Color(1, 0.3, 0.2, 0.12))

func _gear(c: Vector2, r: float, a: float, col: Color) -> void:
	draw_colored_polygon(room._ellipse(c + Vector2(6, r * 0.8), Vector2(r, r * 0.3)), Color(0, 0, 0, 0.2))
	for j in 10:
		var d := Vector2.from_angle(a + TAU * j / 10.0)
		draw_line(c + d * r * 0.8, c + d * (r + 8.0), col, 10.0)
	draw_circle(c, r, col)
	draw_circle(c, r * 0.72, col.darkened(0.2))
	draw_circle(c, r * 0.3, col.lightened(0.3))
	for j in 4:
		var d := Vector2.from_angle(a + TAU * j / 4.0)
		draw_line(c + d * r * 0.3, c + d * r * 0.72, col, 6.0)

func _big_gear(c: Vector2, r: float) -> void:
	_gear(c, r, _t * 0.4, Color("c9961e"))
	_gear(c + Vector2(r * 1.05, r * 0.6), r * 0.45, -_t * 0.9, Color("a8742a"))

func _cheese_wedge(c: Vector2, r: float) -> void:
	var top := PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, -r * 0.2), c + Vector2(r * 0.2, -r * 0.7)])
	draw_colored_polygon(room._ellipse(c + Vector2(8, r * 0.5), Vector2(r * 1.1, r * 0.25)), Color(0, 0, 0, 0.22))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, -r * 0.2), c + Vector2(r, r * 0.3), c + Vector2(-r, r * 0.5)]), Color("f0a828"))
	draw_colored_polygon(top, Color("ffd85a"))
	draw_polyline(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, -r * 0.2), c + Vector2(r, r * 0.3), c + Vector2(-r, r * 0.5), c + Vector2(-r, 0), c + Vector2(r * 0.2, -r * 0.7), c + Vector2(r, -r * 0.2)]), Color("8a5a10"), 3.0)
	for q in [Vector2(-0.5, 0.2), Vector2(0.3, 0.12), Vector2(0.7, 0.05)]:
		draw_colored_polygon(room._ellipse(c + q * r, Vector2(r * 0.12, r * 0.09)), Color("c8801a"))

func _turbine(base_p: Vector2, h: float) -> void:
	draw_colored_polygon(room._ellipse(base_p + Vector2(8, 4), Vector2(h * 0.3, h * 0.08)), Color(0, 0, 0, 0.22))
	draw_line(base_p, base_p + Vector2(0, -h), Color("e8eef4"), 7.0)
	draw_line(base_p, base_p + Vector2(0, -h), Color("b8c4d0"), 2.0)
	var hub := base_p + Vector2(0, -h)
	for j in 3:
		var d := Vector2.from_angle(_t * 2.0 + TAU * j / 3.0)
		draw_colored_polygon(PackedVector2Array([hub, hub + d * h * 0.55 + d.orthogonal() * 6.0, hub + d * h * 0.6]), Color.WHITE)
	draw_circle(hub, 7.0, Color("d8e0e8"))

func _helipad(c: Vector2, r: float) -> void:
	draw_colored_polygon(room._ellipse(c + Vector2(0, 8), Vector2(r, r * 0.8)), Color(0, 0, 0, 0.2))
	draw_colored_polygon(room._ellipse(c, Vector2(r, r * 0.8)), Color("3a3a48"))
	var pts := room._ellipse(c, Vector2(r - 8, r * 0.8 - 7))
	pts.append(pts[0])
	draw_polyline(pts, Color("f0e060"), 5.0)
	var hw := r * 0.32
	var hh := r * 0.42
	for x in [-hw, hw - 12.0]:
		draw_rect(Rect2(c + Vector2(x, -hh), Vector2(12, hh * 2)), Color.WHITE)
	draw_rect(Rect2(c + Vector2(-hw, -6), Vector2(hw * 2, 12)), Color.WHITE)
	for k in 8:
		var a := TAU * k / 8.0 + 0.4
		draw_circle(c + Vector2(cos(a) * (r - 4), sin(a) * (r * 0.8 - 4)), 4.0, Color(_c("accent"), 0.5 + 0.5 * sin(_t * 4.0 + k)))

## El detalle propio de cada ciudad en la azotea / Each city's own rooftop detail
func _style_roof(r: Rect2, base: Color) -> void:
	var p := r.position + Vector2(r.size.x * (0.25 + fposmod(seed * 0.23, 0.5)), 60)
	match style:
		"noir":   # rótulo de neón rojo en la azotea, que parpadea / red neon rooftop sign, flickering
			var on := 0.25 if fmod(_t + seed * 0.7, 5.0) < 0.12 else 1.0
			draw_rect(Rect2(p + Vector2(-100, -66), Vector2(200, 60)), Color("0e0e12"))
			for k in 6:
				draw_rect(Rect2(p + Vector2(-86 + k * 30, -54), Vector2(20, 36)), Color("e0303a", on))
				draw_rect(Rect2(p + Vector2(-82 + k * 30, -50), Vector2(12, 6)), Color(1, 0.7, 0.7, on))
			draw_line(p + Vector2(-80, -6), p + Vector2(-80, 30), Color("0e0e12"), 6.0)
			draw_line(p + Vector2(80, -6), p + Vector2(80, 30), Color("0e0e12"), 6.0)
			draw_texture_rect(DreamBackground.soft_texture(), Rect2(p + Vector2(-140, -110), Vector2(280, 150)), false, Color("e0303a", 0.18 * on))
		"synthwave":   # valla de neón / neon billboard
			draw_rect(Rect2(p + Vector2(-80, -60), Vector2(160, 70)), _c("edge"))
			draw_rect(Rect2(p + Vector2(-74, -54), Vector2(148, 58)), Color("2a0a3a"))
			var g := 0.6 + 0.4 * sin(_t * 5.0 + seed)
			draw_arc(p + Vector2(0, -6), 26.0, PI, TAU, 16, Color(_c("sign"), g), 5.0)
			for k in 4:
				draw_line(p + Vector2(-60, -14 + k * 5), p + Vector2(60, -14 + k * 5), Color(_c("accent"), g * 0.8), 2.0)
			draw_line(p + Vector2(-60, 10), p + Vector2(-60, 30), _c("edge"), 6.0)
			draw_line(p + Vector2(60, 10), p + Vector2(60, 30), _c("edge"), 6.0)
		"steampunk":   # tubos de latón y chimenea con humo / brass pipes and a smoking chimney
			draw_line(r.position + Vector2(30, r.size.y - 50), r.position + Vector2(r.size.x - 30, r.size.y - 50), Color("c9961e"), 10.0)
			draw_line(r.position + Vector2(30, r.size.y - 50), r.position + Vector2(r.size.x - 30, r.size.y - 50), Color("f0c860"), 3.0)
			draw_rect(Rect2(p + Vector2(-20, -70), Vector2(40, 90)), Color("6a3a24"))
			draw_rect(Rect2(p + Vector2(-26, -78), Vector2(52, 12)), Color("c9961e"))
			for k in 4:
				var ph := fposmod(_t * 0.5 + k * 0.25, 1.0)
				draw_circle(p + Vector2(ph * 50.0, -90 - ph * 90.0), 14.0 + ph * 18.0, Color(0.85, 0.82, 0.8, 0.45 * (1.0 - ph)))
		"cheese":   # agujeros de queso / cheese holes
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			for k in 5:
				var q := Vector2(rng.randf_range(r.position.x + 50, r.end.x - 50), rng.randf_range(r.position.y + 50, r.end.y - 50))
				var rad := rng.randf_range(14, 30)
				draw_colored_polygon(room._ellipse(q, Vector2(rad, rad * 0.75)), base.darkened(0.3))
				draw_colored_polygon(room._ellipse(q + Vector2(0, 3), Vector2(rad * 0.8, rad * 0.55)), base.darkened(0.45))
		"aero":   # cúpula de cristal / glass dome
			draw_colored_polygon(room._ellipse(p + Vector2(6, 20), Vector2(70, 22)), Color(0, 0, 0, 0.15))
			draw_colored_polygon(room._ellipse(p, Vector2(64, 52)), Color(0.6, 0.9, 1.0, 0.55))
			draw_arc(p, 64.0, PI, TAU, 24, Color(1, 1, 1, 0.8), 3.0)
			draw_rect(Rect2(p + Vector2(-30, -36), Vector2(16, 30)), Color(1, 1, 1, 0.6))
		"solarpunk":   # huerto en la azotea / rooftop garden
			for k in 2:
				var o := r.position + Vector2(40 + k * (r.size.x - 200), r.size.y - 110)
				draw_rect(Rect2(o, Vector2(120, 56)), Color("7a5a3a"))
				draw_rect(Rect2(o + Vector2(6, 6), Vector2(108, 44)), Color("4a3a24"))
				for j in 5:
					draw_circle(o + Vector2(18 + j * 21, 22), 11.0, Color("4fa85a").lightened(0.1 * (j % 2)))
					draw_circle(o + Vector2(18 + j * 21, 18), 3.0, Color("ffd060") if j % 2 else Color("ff7a9a"))
		"dieselpunk":   # chimenea de fábrica / factory stack
			draw_rect(Rect2(p + Vector2(-24, -120), Vector2(48, 150)), Color("5a2a24"))
			for k in 4:
				draw_rect(Rect2(p + Vector2(-24, -100 + k * 30), Vector2(48, 4)), Color("3a1a14"))
			draw_rect(Rect2(p + Vector2(-30, -128), Vector2(60, 12)), Color("2a2224"))
			for k in 4:
				var ph := fposmod(_t * 0.4 + k * 0.25, 1.0)
				draw_circle(p + Vector2(ph * 40.0, -140 - ph * 110.0), 16.0 + ph * 24.0, Color(0.2, 0.18, 0.2, 0.5 * (1.0 - ph)))
		"brutalist":   # bloques de hormigón / concrete blocks
			for k in 3:
				var o := p + Vector2(-90 + k * 64, -30 + (k % 2) * 30)
				draw_rect(Rect2(o + Vector2(8, 50), Vector2(56, 12)), Color(0, 0, 0, 0.25))
				draw_rect(Rect2(o, Vector2(56, 56)), base.lightened(0.15))
				draw_rect(Rect2(o, Vector2(56, 10)), base.lightened(0.3))
				draw_rect(Rect2(o + Vector2(0, 46), Vector2(56, 10)), base.darkened(0.2))

## Cartel luminoso de la tienda, con su "nombre" en bloques de píxeles / The shop's lit sign, with its "name" in pixel blocks
func _shop_sign(w: float, fh: float) -> void:
	var sw := minf(w - 60.0, 360.0)
	var r := Rect2(w / 2.0 - sw / 2.0, -fh + 20.0, sw, 52.0)
	draw_rect(r.grow(6), _c("edge"))
	draw_rect(r, _c("sign"))
	var glow := 0.75 + 0.25 * sin(_t * 3.0 + seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var x := r.position.x + 18.0
	while x < r.end.x - 30.0:
		var lw := rng.randf_range(10.0, 22.0)
		draw_rect(Rect2(x, r.position.y + 14, lw, 24), Color(_c("accent").lightened(0.3), glow))
		x += lw + 8.0
		if rng.randf() < 0.2:
			x += 14.0

## La torre de los sueños: remate escalonado, antena con baliza y cartel de estrellas
## The dream tower: stepped crown, antenna with a beacon and a sign of stars
func _tower_crown(w: float, fh: float, top: float) -> void:
	var base := _tone(_c("flat"))
	var inner := Rect2(w * 0.2, top + 40, w * 0.6, 140)
	draw_rect(Rect2(inner.position + Vector2(10, inner.size.y), Vector2(inner.size.x, 14)), Color(0, 0, 0, 0.3))
	draw_rect(inner, base.lightened(0.2))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 14)), base.lightened(0.4))
	var ant := Vector2(w / 2.0, inner.position.y + 40)
	draw_line(ant, ant + Vector2(0, -180), _c("edge"), 8.0)
	draw_line(ant + Vector2(-30, -110), ant + Vector2(30, -110), _c("edge"), 5.0)
	var blink := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(ant + Vector2(0, -186), 12.0, Color(_c("accent"), 0.5 + 0.5 * blink))
	draw_circle(ant + Vector2(0, -186), 28.0 * blink, Color(_c("accent"), 0.15))
	var c := Vector2(w / 2.0, -fh - 60.0)
	draw_rect(Rect2(c - Vector2(160, 36), Vector2(320, 72)), _c("edge"))
	draw_rect(Rect2(c - Vector2(152, 28), Vector2(304, 56)), _c("sign"))
	for i in 5:
		DreamBackground.draw_star(self, c + Vector2(-110 + i * 55, sin(_t * 2.0 + i) * 4.0), 13.0, Color(UITheme.GOLD, 0.7 + 0.3 * sin(_t * 3.0 + i)))

## Dibuja un trozo del sprite (para no estirarlo al final del edificio) / Draws part of the sprite (so it isn't stretched at the building's end)
func _draw_part(sprite: String, dst: Rect2, mod: Color) -> void:
	var tex := Sprites.tex(sprite)
	var r: Rect2 = SpriteRects.RECTS[sprite]
	var src := Rect2(0, 0, tex.get_width() * dst.size.x / r.size.x, tex.get_height() * dst.size.y / r.size.y)
	draw_texture_rect_region(tex, dst, src, mod)
