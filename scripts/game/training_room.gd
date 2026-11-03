class_name TrainingRoom
extends Bedroom
## El tatami de entrenamiento del plano astral: la misma isla flotante que se ve detrás del
## armario, sin agujeros ni muebles, con el muñeco de pruebas en medio.
## The astral plane's training mat: the same floating island seen behind the wardrobe, with no
## holes or furniture, and the practice dummy in the middle.

## Centro del tatami en el lienzo de la habitación / Centre of the mat on the room canvas
const CENTER := Vector2(960, 560)
const WALK := Rect2(CENTER - Vector2(440, 200), Vector2(880, 400))
## Un píxel de la isla es un píxel de la pantalla pequeña / One island pixel is one small-screen pixel
const K := 2.0 / Bedroom.S
const DUMMY_AT := CENTER + Vector2(120, -20)
const START_AT := CENTER + Vector2(-260, 70)


func _ready() -> void:
	z_index = -10
	position = OFFSET
	scale = Vector2(S, S)


func walkable() -> Rect2:
	return WALK


func hole_count() -> int:
	return 0


func wall_hole_count() -> int:
	return 0


func obstacles_list() -> Array[Rect2]:
	return []


func holes_list() -> Array[Rect2]:
	return []


func wall_holes_list() -> Array[Rect2]:
	return []


func crack_zones() -> Array[Rect2]:
	return []


func _draw() -> void:
	var isle: Dictionary = HubLayout.ISLES["training"]
	var r: Vector2 = isle["r"]
	# Resplandor bajo la isla / Glow under the island
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(CENTER - Vector2(r.x, 0) * K * 1.4, Vector2(r.x * 2.8, r.y * 3.2) * K), false, Color(isle["aura"], 0.16))
	var tex := Sprites.tex("hub_isle_training")
	var off: Vector2 = isle["offset"]
	draw_texture_rect(tex, Rect2(CENTER + off * K, tex.get_size() * K), false)
	# Dos farolillos al fondo / Two little lanterns at the back
	for x in [-1.0, 1.0]:
		var p := CENTER + Vector2(x * 150.0, -84.0) * K
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(p + Vector2(-22, -66) * K, Vector2(44, 44) * K), false, Color(isle["aura"], 0.3 + 0.06 * sin(_t * 2.0 + x)))
		draw_set_transform(p, 0.0, Vector2(K, K))
		Sprites.draw(self, "hub_lantern")
		draw_rect(Rect2(-3, -44, 6, 8), isle["aura"])
		draw_set_transform(Vector2.ZERO)
