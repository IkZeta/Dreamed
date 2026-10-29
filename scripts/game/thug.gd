class_name Thug
extends Enemy
## Matón (desde el Sueño 2): la pesadilla de un abusón del colegio. Grande, lento,
## con mucha vida y golpes fuertes. Cuesta empujarlo.
## Thug (from Dream 2): the nightmare of a school bully. Big, slow, lots of health
## and heavy hits. Hard to push around.

const HOODIE := Color("7a3a58")
const HOODIE_DARK := Color("5a2742")
const SKIN := Color("b9a3c9")
const EYES := Color("ffcf7a")


func _init() -> void:
	shards = 3
	max_hp = 45.0
	hp = max_hp
	contact_damage = 4.0
	radius = 30.0
	speed = 62.0
	mass = 2.2
	aim_height = 48.0


func _death_sound() -> void:
	Audio.play("hurt", -8.0, 0.1)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var stomp := absf(sin(_t * 4.0 + _phase))
	draw_set_transform(offset + Vector2(0, -stomp * 3.0), sin(_t * 4.0 + _phase) * 0.04, Vector2(_facing, 1.0))
	var hood := HOODIE.lerp(Color.WHITE, _flash * 0.6) * tint
	var dark := HOODIE_DARK.lerp(Color.WHITE, _flash * 0.6) * tint
	var skin := SKIN.lerp(Color.WHITE, _flash * 0.6) * tint
	# Sombra / Shadow
	draw_colored_polygon(_ellipse(Vector2(0, 0), Vector2(36, 9)), Color(0.05, 0.02, 0.15, 0.4 * a))
	# Piernas que se deshacen en humo / Legs dissolving into smoke
	for x in [-14.0, 14.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 11, -44), Vector2(x + 11, -44), Vector2(x + 9, -8), Vector2(x - 9, -8)]), Color(dark, a))
		for i in 3:
			var y := -6.0 + fposmod(_t * 18.0 + i * 4.0 + x, 10.0)
			draw_circle(Vector2(x + sin(_t * 3.0 + i) * 3.0, y), 6.0 - i * 1.5, Color(dark, a * 0.5))
	# Cuerpo ancho / Wide body
	var body := PackedVector2Array([Vector2(-30, -104), Vector2(30, -104), Vector2(40, -88), Vector2(36, -42), Vector2(-36, -42), Vector2(-40, -88)])
	draw_colored_polygon(body, Color(hood, a))
	draw_colored_polygon(PackedVector2Array([Vector2(12, -104), Vector2(30, -104), Vector2(40, -88), Vector2(36, -42), Vector2(12, -42)]), Color(0, 0, 0, 0.18 * a))
	draw_rect(Rect2(-36, -50, 72, 8), Color(dark, a))
	# Puños apretados / Clenched fists
	draw_circle(Vector2(-40, -54 + sin(_t * 4.0) * 3.0), 11, Color(skin, a))
	draw_circle(Vector2(40, -54 - sin(_t * 4.0) * 3.0), 11, Color(skin, a))
	# Cabeza con la capucha puesta / Head with hood up
	draw_colored_polygon(_ellipse(Vector2(0, -124), Vector2(27, 26)), Color(dark, a))
	draw_colored_polygon(_ellipse(Vector2(0, -120), Vector2(19, 19)), Color(skin * Color(0.55, 0.5, 0.65), a))
	# Ojos que brillan con el ceño fruncido / Glowing eyes with a frown
	for x in [-7.0, 7.0]:
		draw_circle(Vector2(x, -122), 7.0, Color(EYES, 0.2 * a))
		draw_line(Vector2(x - 4, -124 + (1 if x < 0 else -1) * 2), Vector2(x + 4, -124 - (1 if x < 0 else -1) * 2), Color(EYES, a), 3.0, true)
	draw_line(Vector2(-6, -110), Vector2(6, -111), Color(0.1, 0.05, 0.15, a), 2.0)


func _ellipse(c: Vector2, r: Vector2, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts
