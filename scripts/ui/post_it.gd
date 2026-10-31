class_name PostIt
extends Control
## Post-it en la carta de cada pijama con los actos superados (como en The Binding of Isaac):
## una fila por acto, con una estrella si se superó en normal y una luna si fue en pesadilla.
## Post-it on each pajama card with the acts cleared (like in The Binding of Isaac):
## one row per act, with a star if cleared on normal and a moon if on nightmare.

var weapon := "bat"


func _init(p_weapon := "bat") -> void:
	weapon = p_weapon


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size.x / 60.0
	draw_set_transform(Vector2(size.x / 2.0, size.y / 2.0), 0.08, Vector2(s, s))
	# Papel amarillo con sombra y celo / Yellow paper with a shadow and tape
	draw_rect(Rect2(-24, -22, 50, 48), Color(0.05, 0.02, 0.15, 0.35))
	draw_rect(Rect2(-26, -25, 50, 48), Color("f6e27a"))
	draw_rect(Rect2(-26, 17, 50, 6), Color("e3c95a"))
	draw_rect(Rect2(-10, -29, 20, 8), Color(1, 1, 1, 0.55))
	# Una fila por acto: número, estrella (normal) y luna (pesadilla)
	# One row per act: number, star (normal) and moon (nightmare)
	var f := UITheme.font("body")
	var off := Color(0.42, 0.36, 0.18, 0.25)
	for act: int in [1, 2, 3]:
		var y := -13.0 + (act - 1) * 13.0
		draw_string(f, Vector2(-23, y + 4), ["I", "II", "III"][act - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("6b5a2a"))
		_star(Vector2(3, y), 5.0, Color("e8a33a") if Progress.has_cleared(weapon, "normal", act) else off)
		_moon(Vector2(16, y), 4.6, Color("6a55c8") if Progress.has_cleared(weapon, "nightmare", act) else off)
		if act < 3:
			draw_line(Vector2(-22, y + 6.5), Vector2(20, y + 6.5), Color("c8ad48"), 1.0)
	draw_set_transform(Vector2.ZERO)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


## Luna creciente: un círculo tapado por otro del color del papel / Crescent: a circle covered by one in the paper colour
func _moon(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col)
	draw_circle(c + Vector2(3.0, -1.5), r * 0.8, Color("f6e27a"))
