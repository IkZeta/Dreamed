class_name Mosquito
extends Enemy
## Mosquito: diminuto, con muy poca vida y muy rápido. Sale a montones de los nidos del
## salón mientras no se rompan. Zumba en zigzag alrededor de Kroker.
## Mosquito: tiny, very little health and very fast. Pours out of the living-room nests
## for as long as they aren't broken. Buzzes around Kroker in a zigzag.

var nest: Node   # nido del que salió / nest it came from


func _init() -> void:
	bestiary_id = "mosquito"
	max_hp = 3.0
	hp = max_hp
	contact_damage = 1.0
	radius = 10.0
	speed = 230.0
	mass = 0.6
	aim_height = 30.0
	# Solo a veces suelta un trozo de estrella y casi nunca objetos / Only sometimes drops a shard, and items almost never
	shards = 1 if randf() < 0.35 else 0
	drop_mult = 0.2


## Va a por Kroker en zigzag, a tirones / Goes for Kroker in a jerky zigzag
func _desired_velocity() -> Vector2:
	var dir: Vector2 = (run.player.global_position + Vector2(0, -20) - global_position).normalized()
	var side := Vector2(-dir.y, dir.x) * (sin(_t * 9.0 + _phase) * 0.9 + sin(_t * 3.1 + _phase * 2.0) * 0.5)
	var burst := 0.75 + 0.35 * maxf(0.0, sin(_t * 5.0 + _phase))
	return (dir + side).normalized() * speed * burst


func _death_sound() -> void:
	Audio.play("hit", -16.0, 0.2)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash, a) * tint
	# Sombrita en el suelo, porque vuela / Tiny shadow on the floor, since it flies
	draw_set_transform(Vector2(offset.x, 0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.25 * a))
	var buzz := Vector2(sin(_t * 31.0 + _phase), cos(_t * 27.0)) * 1.5
	draw_set_transform(offset + buzz, 0.0, Vector2(_facing, 1.0))
	# Alas que baten muy deprisa / Wings beating very fast
	var flap := absf(sin(_t * 40.0 + _phase))
	for side in [-1.0, 1.0]:
		var w := PackedVector2Array()
		for i in 12:
			var ang := TAU * i / 12.0
			w.append(Vector2(-2 + side * 2.0, -40 + 2.0 * side) + Vector2(cos(ang) * 8.0, sin(ang) * (3.0 + 4.0 * flap)))
		draw_colored_polygon(w, Color(Color("dfe6ff"), 0.45 * a) * tint)
	Sprites.draw(self, "mosquito_body", mod)
	draw_set_transform(Vector2.ZERO)


func head_top() -> Vector2:
	return Vector2(8 * _facing, -40)
