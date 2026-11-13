class_name CityLive
extends RefCounted
## Lo que se mueve en el suelo de la ciudad, dibujado en la capa viva de Act4Room (30 veces por
## segundo): el estanque, la fuente de la plaza y las alcantarillas abiertas (con las de color).
## What moves on the city floor, drawn on Act4Room's live layer (30 times a second): the pond,
## the plaza fountain and the open manholes (coloured ones included).


## El estanque: orilla irregular de tierra y piedras, agua con brillos, nenúfares y juncos
## The pond: an irregular bank of earth and stones, glinting water, lily pads and reeds
static func pond(ci: CanvasItem, room: Act4Room) -> void:
	var c := Act4Room.POND.get_center()
	var rad := Act4Room.POND.size * 0.5
	var water := room.water_color()
	var bank := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var wob := 1.0 + 0.05 * sin(a * 3.0 + 1.0) + 0.04 * sin(a * 5.0)
		bank.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * wob)
		inner.append(c + Vector2(cos(a) * (rad.x - 26), sin(a) * (rad.y - 22)) * wob)
	ci.draw_colored_polygon(bank, Color("6a5040"))
	ci.draw_colored_polygon(inner, water.darkened(0.25))
	var deep := PackedVector2Array()
	for q in inner:
		deep.append(c + (q - c) * 0.8 + Vector2(0, 8))
	ci.draw_colored_polygon(deep, water)
	# Piedras de la orilla / Bank stones
	for i in 40:
		if i % 3 == 0:
			ci.draw_colored_polygon(room._ellipse(bank[i].lerp(inner[i], 0.4), Vector2(14, 9)), Color("a8a4b8"))
			ci.draw_colored_polygon(room._ellipse(bank[i].lerp(inner[i], 0.4) + Vector2(-3, -3), Vector2(7, 4)), Color("d8d4e4"))
	# Brillos y ondas / Glints and ripples
	for k in 6:
		var ph := fposmod(room._t * 0.25 + k / 6.0, 1.0)
		var q := c + Vector2(sin(k * 2.1) * rad.x * 0.5, cos(k * 1.3) * rad.y * 0.4)
		ci.draw_rect(Rect2(q + Vector2(ph * 30.0, 0), Vector2(26, 4)), Color(1, 1, 1, 0.35 * sin(ph * PI)))
	# Nenúfares / Lily pads
	for k in 5:
		var q := c + Vector2(cos(k * 1.9) * rad.x * 0.55, sin(k * 1.9) * rad.y * 0.5)
		q.y += sin(room._t + k) * 2.0
		ci.draw_colored_polygon(room._ellipse(q, Vector2(22, 12)), Color("3f9a4a"))
		ci.draw_colored_polygon(PackedVector2Array([q, q + Vector2(22, -4), q + Vector2(22, 4)]), water)
		if k % 2 == 0:
			ci.draw_circle(q + Vector2(-6, -4), 6.0, Color("ffb0c8"))
			ci.draw_circle(q + Vector2(-6, -4), 2.5, Color("fff0a0"))
	# Juncos / Reeds
	for k in 8:
		var a := 2.3 + k * 0.12
		var q := c + Vector2(cos(a) * (rad.x - 10), sin(a) * (rad.y - 10))
		var sway := sin(room._t * 1.5 + k) * 3.0
		ci.draw_line(q, q + Vector2(sway, -40 - (k % 3) * 8), Color("4a7a3a"), 4.0)
		if k % 2:
			ci.draw_rect(Rect2(q + Vector2(sway - 3, -46 - (k % 3) * 8), Vector2(6, 14)), Color("7a4a2a"))



## La fuente de la plaza: pilón redondo de piedra, agua con ondas, dos platos y chorros que suben y caen
## The plaza fountain: a round stone basin, rippling water, two tiers and jets rising and falling
static func fountain(ci: CanvasItem, room: Act4Room) -> void:
	var c := Act4Room.FOUNTAIN.get_center()
	var rx := Act4Room.FOUNTAIN.size.x * 0.5 - 6.0
	var ry := Act4Room.FOUNTAIN.size.y * 0.5 - 20.0
	var stone := room.look("plinth").lerp(Color("d8d4e4"), 0.5)
	var acc := room.look("accent")
	var water := room.water_color()
	# Sombra, borde del pilón (con su cara frontal) y agua / Shadow, basin rim (with its front face) and water
	ci.draw_colored_polygon(room._ellipse(c + Vector2(14, 34), Vector2(rx + 10, ry + 8)), Color(0, 0, 0, 0.22))
	ci.draw_colored_polygon(room._ellipse(c + Vector2(0, 26), Vector2(rx, ry)), stone.darkened(0.35))
	ci.draw_colored_polygon(room._ellipse(c, Vector2(rx, ry)), stone)
	ci.draw_colored_polygon(room._ellipse(c, Vector2(rx - 26, ry - 20)), stone.darkened(0.25))
	ci.draw_colored_polygon(room._ellipse(c + Vector2(0, 4), Vector2(rx - 30, ry - 24)), water)
	ci.draw_colored_polygon(room._ellipse(c + Vector2(0, 10), Vector2(rx - 44, ry - 36)), water.lightened(0.2))
	for k in 16:
		var a := TAU * k / 16.0
		ci.draw_rect(Rect2(c + Vector2(cos(a) * (rx - 13), sin(a) * (ry - 10)) - Vector2(4, 2), Vector2(8, 4)), Color(0, 0, 0, 0.15))
	# Ondas que se abren desde el centro / Ripples spreading from the middle
	for k in 3:
		var ph := fposmod(room._t * 0.35 + k / 3.0, 1.0)
		var pts := room._ellipse(c + Vector2(0, 10), Vector2(60 + ph * (rx - 110), 22 + ph * (ry - 60)))
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(1, 1, 1, 0.35 * (1.0 - ph)), 3.0)
	# Pie, plato bajo, columna y plato alto / Base, lower bowl, column and upper bowl
	ci.draw_rect(Rect2(c + Vector2(-22, -40), Vector2(44, 56)), stone.darkened(0.15))
	ci.draw_colored_polygon(room._ellipse(c + Vector2(0, -36), Vector2(78, 22)), stone.darkened(0.3))
	ci.draw_colored_polygon(room._ellipse(c + Vector2(0, -44), Vector2(78, 22)), stone)
	ci.draw_colored_polygon(room._ellipse(c + Vector2(0, -44), Vector2(62, 14)), water.lightened(0.2))
	ci.draw_rect(Rect2(c + Vector2(-12, -110), Vector2(24, 66)), stone.darkened(0.1))
	ci.draw_rect(Rect2(c + Vector2(-12, -110), Vector2(7, 66)), Color(1, 1, 1, 0.25))
	ci.draw_colored_polygon(room._ellipse(c + Vector2(0, -108), Vector2(40, 12)), stone.darkened(0.3))
	ci.draw_colored_polygon(room._ellipse(c + Vector2(0, -114), Vector2(40, 12)), stone)
	DreamBackground.draw_star(ci, c + Vector2(0, -136 + sin(room._t * 2.0) * 3.0), 12.0, Color(UITheme.GOLD, 0.9))
	# Cortina de agua que cae del plato bajo / Curtain of water falling off the lower bowl
	for k in 9:
		var x := -66.0 + k * 16.5
		var ph := fposmod(room._t * 1.6 + k * 0.37, 1.0)
		ci.draw_line(c + Vector2(x, -36), c + Vector2(x * 1.15, -36 + 40 * ph), Color(0.85, 0.95, 1.0, 0.6 * (1.0 - ph)), 4.0)
	# Chorros desde arriba / Jets from the top
	for i in 12:
		var ph := fposmod(room._t * 0.9 + i * 0.083, 1.0)
		var a := TAU * i / 12.0
		var p := c + Vector2(0, -130) + Vector2(cos(a) * 66.0 * ph, sin(a) * 18.0 * ph - sin(ph * PI) * 40.0 + ph * 80.0)
		ci.draw_circle(p, 6.0 * (1.0 - ph * 0.5), Color(0.85, 0.96, 1.0, 0.85 * (1.0 - ph)))



## Alcantarillas abiertas: la tapa a un lado y el vacío del sueño dentro
## Open manholes: the cover to one side and the dream void inside
static func holes(ci: CanvasItem, room: Act4Room) -> void:
	for i in room._open:
		var h := room._holes[i]
		var c := h.get_center()
		var rr := h.size / 2.0
		ci.draw_colored_polygon(room._ellipse(c, rr + Vector2(8, 5)), Color("4a4660"))
		ci.draw_colored_polygon(room._ellipse(c, rr), Color("07061a"))
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - rr * 0.8, rr * 1.6), false, Color("5b4bc4", 0.35))
		for k in 5:
			var sp := c + Vector2(sin(k * 2.3 + i) * rr.x * 0.6, cos(k * 1.7 + i) * rr.y * 0.5)
			ci.draw_circle(sp, 1.6, Color(UITheme.BONE, 0.4 + 0.4 * sin(room._t * 2.0 + k)))
		# Tapa apartada / Cover pushed aside
		ci.draw_colored_polygon(room._ellipse(c + Vector2(rr.x + 22, rr.y * 0.4), Vector2(30, 12)), Color("5a5670"))
		ci.draw_arc(c + Vector2(rr.x + 22, rr.y * 0.4), 18.0, 0.0, TAU, 16, Color("8a86a0"), 3.0)
		if room._kinds.has(i):
			hole_kind(ci, room, c, rr, room._kinds[i], i)


## Un agujero de color: borde que late, luz que sube del fondo y su símbolo flotando encima
## A coloured hole: a pulsing rim, light rising from the depths and its symbol floating above
static func hole_kind(ci: CanvasItem, room: Act4Room, c: Vector2, rr: Vector2, kind: String, i: int) -> void:
	var col: Color = Act4Room.HOLE_COLOURS[kind]
	var pulse := 0.5 + 0.5 * sin(room._t * 3.0 + i)
	# Halo grande en el suelo y luz que sale del fondo / A wide halo on the floor and light rising from the depths
	ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - rr * 2.6, rr * 5.2), false, Color(col, 0.3 + 0.15 * pulse))
	ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - rr * 0.9, rr * 1.8), false, Color(col, 0.7))
	var ring := PackedVector2Array(room._ellipse(c, rr + Vector2(14, 9)))
	ring.append(ring[0])
	ci.draw_polyline(ring, Color(col.darkened(0.5), 0.9), 14.0)
	ci.draw_polyline(ring, Color(col, 0.75 + 0.25 * pulse), 8.0)
	# Motas de su color que suben / Motes in its colour drifting up
	for k in 6:
		var ph := fposmod(room._t * 0.6 + k / 6.0 + i * 0.13, 1.0)
		var p := c + Vector2(sin(k * 2.1 + i) * rr.x * 0.7, -ph * 150.0)
		ci.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(col, (1.0 - ph) * 0.95))
	# Símbolo / Symbol
	var top := c + Vector2(0, -rr.y - 110.0 + sin(room._t * 2.0 + i) * 10.0)
	ci.draw_circle(top, 40.0, Color(0.05, 0.03, 0.15, 0.75))
	ci.draw_arc(top, 40.0, 0.0, TAU, 28, col, 6.0)
	match kind:
		"gold":
			DreamBackground.draw_star(ci, top, 22.0, col)
		"green":
			ci.draw_rect(Rect2(top - Vector2(8, 24), Vector2(16, 48)), col)
			ci.draw_rect(Rect2(top - Vector2(24, 8), Vector2(48, 16)), col)
		"violet":
			ci.draw_colored_polygon(PackedVector2Array([top + Vector2(0, -26), top + Vector2(18, 0), top + Vector2(0, 26), top + Vector2(-18, 0)]), col)
		"red":
			ci.draw_arc(top, 20.0, -PI * 0.5, PI * 1.1, 20, col, 7.0)
			ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-4, -34), top + Vector2(14, -21), top + Vector2(-4, -8)]), col)
