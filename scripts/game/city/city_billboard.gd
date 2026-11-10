class_name CityBillboard
extends Node2D

const T := CityLayout.TILE
## Una valla publicitaria sobre dos postes, con un anuncio que parpadea (sueño 20). Cuando Evil Ad
## se forma, el panel sale volando y quedan los postes con los bordes rotos.
## A billboard on two poles, with a flickering advert (dream 20). When Evil Ad forms, the panel flies
## off and the poles are left with torn edges.

const ADS := 6
const PANEL := Rect2(-130, -330, 260, 140)
var room: Act4Room
var ad := 0
var taken := false
var _t := 0.0

func _ready() -> void:
	scale = Vector2(Bedroom.S, Bedroom.S)
	_t = randf() * 5.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

## Dónde está el panel en el mundo / Where the panel is in the world
func panel_world() -> Vector2:
	return global_position + PANEL.get_center() * Bedroom.S

func take() -> void:
	taken = true

func _draw() -> void:
	if not is_instance_valid(room):
		return
	var dark := Color("0e0e12")
	draw_colored_polygon(room._ellipse(Vector2(10, 4), Vector2(120, 16)), Color(0, 0, 0, 0.28))
	for x in [-90.0, 90.0]:
		draw_rect(Rect2(x - 7, PANEL.end.y - 6, 14, -PANEL.end.y + 6), Color("2a2a30"))
		draw_rect(Rect2(x - 7, PANEL.end.y - 6, 4, -PANEL.end.y + 6), Color("4a4a52"))
		draw_rect(Rect2(x - 14, -8, 28, 10), dark)
	if taken:
		# Bordes arrancados / Torn-off edges
		draw_rect(Rect2(-100, PANEL.end.y - 14, 200, 10), Color("2a2a30"))
		for i in 6:
			draw_colored_polygon(PackedVector2Array([Vector2(-100 + i * 34, PANEL.end.y - 14), Vector2(-84 + i * 34, PANEL.end.y - 30 - (i % 2) * 10), Vector2(-70 + i * 34, PANEL.end.y - 14)]), Color("3a3a42"))
		return
	draw_ad(self, PANEL, ad, _t)

## El anuncio (lo usa también el enjambre) / The advert (also used by the swarm)
static func draw_ad(ci: CanvasItem, r: Rect2, kind: int, t: float) -> void:
	var red := Color("e0303a")
	var cream := Color("e8dcc0")
	var dark := Color("0e0e12")
	var on := 0.35 if fmod(t + kind * 0.9, 4.0) < 0.1 else 1.0
	ci.draw_rect(r.grow(8), dark)
	ci.draw_rect(r, Color("1a0a10"))
	var c := r.get_center()
	var font := UITheme.font("display")   # la letra pixel del juego / the game's pixel font
	match kind:
		0:   # la sonrisa de Evil Ad / Evil Ad's grin
			ci.draw_rect(r.grow(-6), Color(red, 0.25 * on))
			for side in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(side * 40, -22), 18.0, Color(red, on))
				ci.draw_circle(c + Vector2(side * 40, -22), 12.0, dark)
				ci.draw_string(font, c + Vector2(side * 40 - 6, -14), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffd84a", on))
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(c + Vector2(-64 + i * 16, 18 + sin(i / 8.0 * PI) * 16))
			ci.draw_polyline(pts, Color(red, on), 6.0)
		1:
			ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.62), "BUY NOW", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 48, Color(red, on))
		2:
			ci.draw_rect(Rect2(r.position + Vector2(10, 10), r.size - Vector2(20, 20)), Color(cream, 0.9 * on))
			ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.64), "OBEY", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 60, Color(dark, on))
		3:
			ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.45), "SALE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, Color(cream, on))
			ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.85), "-99%", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 48, Color(red, on))
		4:
			for i in 3:
				ci.draw_string(font, c + Vector2(-70 + i * 50, 18), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(red if i != 1 else cream, on))
		5:
			ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.42), "DON'T", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, Color(cream, on))
			ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.82), "WAKE UP", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, Color(red, on))
	# Bombillas del marco / Frame bulbs
	for i in 8:
		var lit := int(t * 6.0 + i) % 2 == 0
		ci.draw_circle(Vector2(lerpf(r.position.x, r.end.x, i / 7.0), r.position.y - 4), 4.0, Color("ffe8b0") if lit else Color("4a4440"))
