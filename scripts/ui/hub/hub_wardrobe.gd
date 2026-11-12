class_name HubWardrobe
extends RefCounted
## La isla del armario: la tiendecita de pijamas del plano astral.
## The wardrobe island: the astral plane's little pajama shop.
## Se separa de hub_world.gd para que no crezca sin fin; dibuja con los datos del mundo (hub).
## Split out of hub_world.gd so it doesn't grow forever; it draws using the world's data (hub).

var hub: HubWorld


func _init(world: HubWorld) -> void:
	hub = world


func build() -> void:
	var c := hub._isle_pos("wardrobe")
	# Alfombra de pasillo de tienda, de la entrada al armario / Boutique runner rug, from the entrance to the wardrobe
	hub._prop(c + Vector2(0, -120), func(ci: CanvasItem) -> void:
		_draw_wardrobe_rug(ci, Vector2(0, 120)))
	# El armario, abierto, con un resplandor y perchas que flotan encima
	# The wardrobe, open, with a glow and hangers floating above it
	hub._prop(c + Vector2(0, -41), func(ci: CanvasItem) -> void:
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-90, -130), Vector2(180, 130)), false, Color("c9b8ff", 0.18 + 0.05 * sin(hub._t * 1.5)))
		for k in 4:
			var ph := hub._t * 0.6 + k * 1.7
			var hp := Vector2(-48 + k * 32 + sin(ph) * 5.0, -104 + sin(ph * 1.3) * 4.0)
			_hanger(ci, hp, sin(ph * 0.8) * 0.25, Color(1, 1, 1, 0.55)))
	hub._piece(c + Vector2(0, -40), "hub_wardrobe", Vector2(64, 10), Vector2(0, -6))
	# Biombo para cambiarse, con un pijama colgado / Folding screen for changing, with pajamas thrown over it
	var scr := c + Vector2(-104, -52)
	hub._blocks.append({"c": scr, "r": Vector2(26, 5)})
	hub._prop(scr, _draw_changing_screen)
	# Espejo de cuerpo entero que refleja a Kroker con el pijama que lleve
	# Full-length mirror reflecting Kroker in whatever pajamas he's wearing
	var mir := c + Vector2(104, -50)
	hub._blocks.append({"c": mir, "r": Vector2(10, 4)})
	hub._prop(mir, func(ci: CanvasItem) -> void: _draw_mirror(ci, mir))
	# Los pijamas en dos filas en uve, a los lados del pasillo, con sus zapatillas y un foco cada uno
	# The pajamas in two V-shaped rows either side of the aisle, each with its slippers and a spotlight
	var n := hub.PAJAMAS.size()
	var half := int(ceil(n / 2.0))
	for i in n:
		var o := hub.PAJAMAS[i]
		var side := -1.0 if i < half else 1.0
		var k := i if i < half else i - half
		var ax := 46.0 + k * 27.0
		var at := c + Vector2(side * ax, 8.0 + (ax - 46.0) * 0.14)
		hub._blocks.append({"c": at, "r": Vector2(7, 3)})
		hub._spots.append({"kind": "pajama", "id": o, "pos": at, "height": 70.0})
		hub._prop(at, func(ci: CanvasItem) -> void: _draw_pajama_stand(ci, o, side))
	# Cesto de ropa y perchero de sombreros junto a la entrada / Laundry basket and hat stand by the entrance
	hub._prop(c + Vector2(-100, 64), func(ci: CanvasItem) -> void: _draw_laundry(ci))
	hub._blocks.append({"c": c + Vector2(-100, 64), "r": Vector2(12, 4)})
	hub._prop(c + Vector2(100, 64), func(ci: CanvasItem) -> void: _draw_hat_stand(ci))
	hub._blocks.append({"c": c + Vector2(100, 64), "r": Vector2(5, 3)})


func _draw_wardrobe_rug(ci: CanvasItem, off: Vector2) -> void:
	var pts := PackedVector2Array([off + Vector2(-20, -30), off + Vector2(20, -30), off + Vector2(28, 92), off + Vector2(-28, 92)])
	ci.draw_colored_polygon(pts, Color("5a3a7a"))
	var inner := PackedVector2Array([off + Vector2(-16, -26), off + Vector2(16, -26), off + Vector2(23, 88), off + Vector2(-23, 88)])
	ci.draw_colored_polygon(inner, Color("7a52a0"))
	ci.draw_polyline(inner + PackedVector2Array([inner[0]]), Color("e0b860", 0.8), 1.0)
	# Estrellitas bordadas / Embroidered little stars
	for k in 7:
		var y := -18.0 + k * 15.0
		var p := off + Vector2(sin(k * 1.7) * 6.0, y)
		ci.draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), Color("f6d993", 0.8))
		ci.draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), Color("f6d993", 0.8))


## Percha / Hanger
func _hanger(ci: CanvasItem, p: Vector2, rot: float, col: Color) -> void:
	var r := Transform2D(rot, p)
	ci.draw_set_transform_matrix(r)
	ci.draw_arc(Vector2(0, -4), 2.5, PI, TAU + 1.2, 6, col, 1.0)
	ci.draw_line(Vector2(0, -2), Vector2(-9, 4), col, 1.0)
	ci.draw_line(Vector2(0, -2), Vector2(9, 4), col, 1.0)
	ci.draw_line(Vector2(-9, 4), Vector2(9, 4), col, 1.0)
	ci.draw_set_transform(Vector2.ZERO)


func _draw_changing_screen(ci: CanvasItem) -> void:
	hub._shadow(ci, Vector2(0, 0), Vector2(30, 5))
	var frame := Color("6a4a32")
	var cloth := [Color("8a6ac0"), Color("7458a8"), Color("8a6ac0")]
	for k in 3:
		var x0 := -27.0 + k * 18.0
		var skew := -3.0 if k == 1 else 0.0
		var poly := PackedVector2Array([Vector2(x0, -52 + skew), Vector2(x0 + 18, -52 - skew), Vector2(x0 + 18, -2 - skew), Vector2(x0, -2 + skew)])
		ci.draw_colored_polygon(poly, frame)
		var inner := PackedVector2Array([poly[0] + Vector2(2, 3), poly[1] + Vector2(-2, 3), poly[2] + Vector2(-2, -3), poly[3] + Vector2(2, -3)])
		ci.draw_colored_polygon(inner, cloth[k])
		# Lunas y estrellas pintadas / Painted moons and stars
		var mid := (inner[0] + inner[2]) * 0.5
		if k == 1:
			ci.draw_circle(mid + Vector2(0, -6), 4.0, Color("f6d993"))
			ci.draw_circle(mid + Vector2(2, -7), 3.4, cloth[k])
		else:
			ci.draw_rect(Rect2(mid + Vector2(-1, -10), Vector2(2, 2)), Color("f6d993"))
			ci.draw_rect(Rect2(mid + Vector2(3, 4), Vector2(1, 1)), Color("f6d993"))
	# Un pijama colgado por encima, que se mece / A pajama top draped over, swaying
	var sway := sin(hub._t * 1.2) * 1.5
	var pj: Dictionary = KrokerArt.PAJAMAS.get(GameState.selected_character, KrokerArt.PAJAMAS["bat"])
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-14, -54), Vector2(4, -54), Vector2(6 + sway, -36), Vector2(-2 + sway, -38), Vector2(-12, -46)]), pj["base"])
	ci.draw_line(Vector2(-14, -54), Vector2(4, -54), pj["piping"], 1.0)


func _draw_mirror(ci: CanvasItem, at: Vector2) -> void:
	hub._shadow(ci, Vector2.ZERO, Vector2(12, 3))
	Sprites.draw(ci, "hub_mirror")
	# El reflejo de Kroker, si está cerca / Kroker's reflection, if he's close
	var d := hub._pos - at
	if absf(d.x) < 130.0 and d.y > -10.0 and d.y < 120.0:
		var glass := Rect2(-9, -40, 18, 34)
		var k := 1.0 - clampf(absf(d.x) / 130.0, 0.0, 1.0)
		var outfit := GameState.selected_character if GameState.weapon_unlocked(GameState.selected_character) else "bat"
		var s := hub.KROKER_SCALE * 0.5
		var fx := clampf(d.x * 0.05, -5.0, 5.0)
		ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, Vector2(fx - 100.0 * s, -8.0 - 288.0 * s)))
		KrokerArt.draw(ci, Transform2D(0.0, Vector2(s, s), 0.0, Vector2(fx - 100.0 * s, -8.0 - 288.0 * s)), outfit, hub._t,
			{"facing": -hub._facing, "walk": hub._walk, "moving": hub._moving, "armed": false, "flash": 0.2})
		ci.draw_set_transform(Vector2.ZERO)
		ci.draw_rect(glass, Color("bfe0ff", 0.25 * (1.0 - k) + 0.12))
	# Brillo que cruza el cristal / A glint crossing the glass
	var g := fposmod(hub._t * 0.4, 2.0)
	if g < 1.0:
		var y := -40.0 + g * 34.0
		ci.draw_line(Vector2(-8, y + 4), Vector2(8, y - 4), Color(1, 1, 1, 0.35), 1.0)


func _draw_pajama_stand(ci: CanvasItem, o: String, side: float) -> void:
	var unlocked := GameState.weapon_unlocked(o)
	var worn := GameState.selected_character == o
	# Foco desde arriba / Spotlight from above
	var pj: Dictionary = KrokerArt.PAJAMAS.get(o, KrokerArt.PAJAMAS["bat"])
	if unlocked:
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-18, -70), Vector2(36, 76)), false, Color(pj["pattern"], 0.12 + (0.1 if worn else 0.0)))
	hub._shadow(ci, Vector2.ZERO, Vector2(9, 3))
	Sprites.draw(ci, "hub_stand")
	var xf := Transform2D(0.0, Vector2(hub.KROKER_SCALE * -side, hub.KROKER_SCALE), 0.0, Vector2(100.0 * hub.KROKER_SCALE * side, -288.0 * hub.KROKER_SCALE - 6.0))
	if worn:
		# Lo lleva puesto: percha vacía con chispas / He's wearing it: an empty hanger with sparkles
		_hanger(ci, Vector2(0, -50), sin(hub._t * 2.0) * 0.1, Color("e0d8ff"))
		for k in 3:
			var ph := fposmod(hub._t * 0.7 + k * 0.33, 1.0)
			ci.draw_rect(Rect2(Vector2(sin(k * 2.0 + hub._t) * 8.0, -30.0 - ph * 24.0), Vector2(1, 1)), Color(1, 1, 1, 1.0 - ph))
	elif unlocked:
		ci.draw_set_transform_matrix(xf)
		for part in ["kroker_leg_l_", "kroker_leg_r_", "kroker_arm_l_", "kroker_arm_r_", "kroker_torso_"]:
			Sprites.draw(ci, part + o)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		# Aún no es tuyo: silueta oscura con una etiqueta «?» / Not yours yet: a dark silhouette with a "?" tag
		ci.draw_set_transform_matrix(xf)
		for part in ["kroker_leg_l_", "kroker_leg_r_", "kroker_arm_l_", "kroker_arm_r_", "kroker_torso_"]:
			Sprites.draw(ci, part + o, Color(0.08, 0.05, 0.16, 0.85))
		ci.draw_set_transform(Vector2.ZERO)
		ci.draw_rect(Rect2(-4, -40, 8, 9), Color("efe6cf"))
		ci.draw_rect(Rect2(-1, -38, 2, 3), Color("4a3a6a"))
		ci.draw_rect(Rect2(-1, -34, 2, 1), Color("4a3a6a"))
	# Zapatillas a juego delante del soporte / Matching slippers in front of the stand
	if unlocked and not worn:
		for x in [-4.0, 3.0]:
			ci.draw_rect(Rect2(x - 2.5, 1, 5, 2), Color(pj["slippers"]).darkened(0.3))
			ci.draw_rect(Rect2(x - 2.5, 0, 4, 2), pj["slippers"])


func _draw_laundry(ci: CanvasItem) -> void:
	hub._shadow(ci, Vector2.ZERO, Vector2(14, 4))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, -18), Vector2(12, -18), Vector2(10, 0), Vector2(-10, 0)]), Color("b89060"))
	for y in [-14.0, -9.0, -4.0]:
		ci.draw_line(Vector2(-11, y), Vector2(11, y), Color("8a6a44"), 1.0)
	# Ropa asomando: un calcetín y una manga / Clothes peeking out: a sock and a sleeve
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, -18), Vector2(-4, -24), Vector2(-1, -22), Vector2(-3, -18)]), Color("e85d75"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(2, -18), Vector2(6, -23 + sin(hub._t * 1.5)), Vector2(10, -21), Vector2(8, -18)]), Color("8fd8ff"))


func _draw_hat_stand(ci: CanvasItem) -> void:
	hub._shadow(ci, Vector2.ZERO, Vector2(8, 3))
	ci.draw_rect(Rect2(-1, -56, 2, 56), Color("6a4a32"))
	ci.draw_rect(Rect2(-6, -2, 12, 2), Color("6a4a32"))
	for k in 3:
		var a := -PI * 0.5 + (k - 1) * 0.9
		ci.draw_line(Vector2(0, -52), Vector2(0, -52) + Vector2.from_angle(a) * 8.0, Color("6a4a32"), 1.5)
	# Gorro de dormir con borla / Nightcap with a tassel
	var sw := sin(hub._t * 1.3) * 1.5
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -56), Vector2(6, -56), Vector2(10 + sw, -42), Vector2(4, -48)]), Color("5a6ad0"))
	ci.draw_circle(Vector2(10 + sw, -41), 2.0, Color("f4ecdc"))
	ci.draw_rect(Rect2(-6, -57, 12, 2), Color("f4ecdc"))


