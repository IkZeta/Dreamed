class_name BoxDeco
extends Control
## Adornos de las esquinas del recuadro: volutas y rombos del color del que habla
## The box's corner ornaments: scrolls and diamonds in the speaker's colour

var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var dark := Color("140f2e")
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(corner.x * w, corner.y * h)
		var sx := 1.0 if corner.x == 0 else -1.0
		var sy := 1.0 if corner.y == 0 else -1.0
		var q := p + Vector2(sx * 6, sy * 6)
		# Escuadra gruesa por fuera del borde que acaba en voluta / Thick bracket outside the border ending in a scroll
		for arm in [Vector2(sx, 0), Vector2(0, sy)]:
			var end: Vector2 = q + arm * 84.0
			draw_line(q, end, dark, 9.0)
			draw_line(q, end, color, 5.0)
			var side: Vector2 = Vector2(arm.y, arm.x) * Vector2(sx, sy).abs() * Vector2(sx if arm.y != 0 else 1.0, sy if arm.x != 0 else 1.0)
			var curl := PackedVector2Array()
			for k in 10:
				var t := float(k) / 9.0
				var ang := t * PI * 1.5
				curl.append(end + arm * sin(ang) * 10.0 + side * (1.0 - cos(ang)) * 10.0)
			draw_polyline(curl, dark, 8.0)
			draw_polyline(curl, color, 4.0)
		var d := q
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -16), d + Vector2(16, 0), d + Vector2(0, 16), d + Vector2(-16, 0)]), dark)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -12), d + Vector2(12, 0), d + Vector2(0, 12), d + Vector2(-12, 0)]), color)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -5), d + Vector2(5, 0), d + Vector2(0, 5), d + Vector2(-5, 0)]), dark)
	# Rombo en el centro de arriba y de abajo / Diamond at the top and bottom centre
	for y in [14.0, h - 14.0]:
		var d := Vector2(w / 2.0, y)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -12), d + Vector2(18, 0), d + Vector2(0, 12), d + Vector2(-18, 0)]), dark)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -8), d + Vector2(13, 0), d + Vector2(0, 8), d + Vector2(-13, 0)]), color)
