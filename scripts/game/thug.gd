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
	bestiary_id = "thug"
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
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	# Sombra / Shadow
	draw_colored_polygon(_ellipse(Vector2(0, 0), Vector2(36, 9)), Color(0.05, 0.02, 0.15, 0.4 * a))
	# Vaqueros anchos y zapatillas, pisando fuerte / Baggy jeans and trainers, stomping
	for x in [-14.0, 14.0]:
		var lift := maxf(0.0, sin(_t * 4.0 + _phase + (PI if x > 0.0 else 0.0))) * 4.0
		Sprites.draw(self, "thug_leg", mod, Vector2(x, -lift))
	Sprites.draw(self, "thug_body", mod)
	# Puños apretados saliendo de las mangas / Clenched fists poking out of the sleeves
	Sprites.draw(self, "thug_fist", mod, Vector2(-44, -52 + sin(_t * 4.0) * 2.0))
	Sprites.draw(self, "thug_fist", mod, Vector2(44, -52 - sin(_t * 4.0) * 2.0))
	Sprites.draw(self, "thug_head", mod)
	# Dentro de la capucha solo se ven los ojos, que brillan con el ceño fruncido
	# Inside the hood only the eyes show, glowing with a frown
	for x in [-7.0, 7.0]:
		draw_line(Vector2(x - 4, -124 + (1 if x < 0 else -1) * 2), Vector2(x + 4, -124 - (1 if x < 0 else -1) * 2), Color(EYES, a), 3.0)


func _ellipse(c: Vector2, r: Vector2, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts


func head_top() -> Vector2:
	return Vector2(0, -160)
