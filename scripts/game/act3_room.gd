class_name Act3Room
extends Bedroom
## Escenario PROVISIONAL del Acto 3 (sueños 11 a 13), para probar las dos armas.
## Un sueño "en obras": suelo de baldosas que flota en el cielo, puertas y escaleras que no
## llevan a ningún sitio y un cartel que avisa de que esto aún se está construyendo.
## Mismo lienzo y misma zona de suelo que la habitación.
## PLACEHOLDER Act 3 stage (dreams 11 to 13), to try out the two weapons.
## A dream "under construction": a tiled floor floating in the sky, doors and stairs leading
## nowhere and a sign warning that this is still being built.
## Same canvas and floor area as the bedroom.

const CONES: Array[Rect2] = [
	Rect2(640, 300, 54, 44),
	Rect2(1226, 300, 54, 44),
]


func obstacles_list() -> Array[Rect2]:
	return CONES.duplicate()


func wall_holes_list() -> Array[Rect2]:
	return []


func crack_zones() -> Array[Rect2]:
	return [Rect2(20, 20, 1880, 260), Rect2(60, 340, 1800, 680), Rect2(60, 340, 1800, 680), Rect2(60, 340, 1800, 680), Rect2(60, 340, 1800, 680)]


func _draw() -> void:
	_draw_sky_wall()
	_draw_floor_tiles()
	_draw_holes()
	_draw_sign()
	for c in CONES:
		_draw_cone(Vector2(c.get_center().x, c.end.y))
	_draw_corruption()
	_draw_dream_stars()
	_draw_floating_things()
	_draw_room_edges()


## En vez de pared, cielo con puertas y escaleras flotando / Instead of a wall, sky with floating doors and stairs
func _draw_sky_wall() -> void:
	var top := Color("1a0f3a")
	var bot := Color("2b5a6e")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, WALL_BOTTOM), Vector2(0, WALL_BOTTOM)]),
		PackedColorArray([top, top, bot, bot]))
	for s in _wall_stars:
		var p: Vector2 = s["p"]
		draw_rect(Rect2(p, Vector2(3, 3)), Color(UITheme.BONE, 0.3 + 0.3 * sin(_t * 1.4 + float(s["ph"]))))
	# Puertas que flotan / Floating doors
	for i in 3:
		var p := Vector2(220 + i * 620, 70 + sin(_t * 0.7 + i * 2.0) * 10.0)
		draw_set_transform(p, sin(_t * 0.4 + i) * 0.08, Vector2.ONE)
		draw_rect(Rect2(-36, -10, 72, 130), Color("5a3a2a"))
		draw_rect(Rect2(-30, -4, 60, 118), Color(["8a5a3e", "5b67c4", "c9475a"][i]))
		draw_circle(Vector2(20, 56), 5.0, Color("e0b860"))
		draw_set_transform(Vector2.ZERO)
	# Escalera que no lleva a ningún sitio / Stairs leading nowhere
	for k in 6:
		var x := 1500.0 + k * 34.0
		var y := 240.0 - k * 26.0 + sin(_t * 0.5) * 6.0
		draw_rect(Rect2(x, y, 40, 14), Color("cfc8ec", 0.85))
		draw_rect(Rect2(x, y + 14, 40, 6), Color("8a84b8", 0.85))
	draw_rect(Rect2(0, WALL_BOTTOM - 6, 1920, 8), Color("cfc8ec", 0.5))


## Baldosas de ajedrez que tiemblan un poco / Chequered tiles that wobble a little
func _draw_floor_tiles() -> void:
	draw_rect(Rect2(0, WALL_BOTTOM, 1920, FLOOR_BOTTOM - WALL_BOTTOM), Color("2a2050"))
	var w := 120.0
	var h := 62.0
	var row := 0
	var y := WALL_BOTTOM
	while y < FLOOR_BOTTOM:
		var x := 0.0
		var col := 0
		while x < 1920.0:
			if (row + col) % 2 == 0:
				var lift := sin(_t * 0.8 + col * 0.7 + row * 1.3) * 2.0 * minf(1.0, weird)
				draw_rect(Rect2(x + 2, y + 2 + lift, w - 4, h - 4), Color("4a3a7a"))
				draw_rect(Rect2(x + 2, y + 2 + lift, w - 4, 4), Color("6a5aa8", 0.6))
			x += w
			col += 1
		y += h
		row += 1
	# Sombra junto al cielo / Shadow along the sky edge
	draw_polygon(PackedVector2Array([Vector2(0, WALL_BOTTOM), Vector2(1920, WALL_BOTTOM), Vector2(1920, WALL_BOTTOM + 60), Vector2(0, WALL_BOTTOM + 60)]),
		PackedColorArray([Color(0.05, 0.03, 0.2, 0.45), Color(0.05, 0.03, 0.2, 0.45), Color(0.05, 0.03, 0.2, 0), Color(0.05, 0.03, 0.2, 0)]))


## Cartel de «en obras» / "Under construction" sign
func _draw_sign() -> void:
	var c := Vector2(960, 150)
	for x in [-170.0, 170.0]:
		draw_rect(Rect2(c.x + x - 8, c.y + 30, 16, 140), Color("6a4430"))
	draw_rect(Rect2(c.x - 240, c.y - 60, 480, 110), Color("f6d24a"))
	for k in 12:
		var x := c.x - 240 + k * 40.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, c.y + 50), Vector2(x + 20, c.y + 50), Vector2(x + 40, c.y + 36), Vector2(x + 20, c.y + 36)]), Color("2b2945"))
	var f := UITheme.font("display")
	draw_string(f, Vector2(c.x - 220, c.y - 4), tr("ACT3_PLACEHOLDER"), HORIZONTAL_ALIGNMENT_CENTER, 440, 36, Color("2b2945"))


func _draw_cone(base: Vector2) -> void:
	draw_colored_polygon(_ellipse(base, Vector2(30, 9)), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(base.x - 30, base.y - 8, 60, 10), Color("e8743a"))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-22, -8), base + Vector2(22, -8), base + Vector2(4, -70), base + Vector2(-4, -70)]), Color("ff8a3a"))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-15, -32), base + Vector2(15, -32), base + Vector2(11, -46), base + Vector2(-11, -46)]), Color("fbf8ff"))
