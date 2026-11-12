class_name HubMuseum
extends RefCounted
## La isla del museo: las estatuas de piedra de todas las pesadillas que has visto.
## The museum island: the stone statues of every nightmare you have seen.
## Se separa de hub_world.gd para que no crezca sin fin; dibuja con los datos del mundo (hub).
## Split out of hub_world.gd so it doesn't grow forever; it draws using the world's data (hub).

var hub: HubWorld


func _init(world: HubWorld) -> void:
	hub = world


func build() -> void:
	var c := hub._isle_pos("museum")
	# Columnas a los lados de la tarima / Columns beside the dais
	for p: Vector2 in [Vector2(-226, -70), Vector2(226, -70)]:
		hub._piece(c + p, "hub_column", Vector2(10, 4))
	# Arco de la entrada con el cartel «Museo de las pesadillas» / Entrance arch with the "Museum of nightmares" sign
	hub._prop(c + Vector2(0, 124), _draw_museum_banner)
	# Haces de luz sobre los jefes / Beams of light on the bosses
	for i in 6:
		var bx := -150.0 + i * 60.0
		hub._prop(c + Vector2(bx, -80.0), func(ci: CanvasItem) -> void:
			var a := 0.12 + 0.03 * sin(hub._t * 1.3 + bx)
			var top := Color(1.0, 0.96, 0.82, 0.0)
			var low := Color(1.0, 0.96, 0.82, a)
			ci.draw_polygon(PackedVector2Array([Vector2(-9, -96), Vector2(9, -96), Vector2(24, 4), Vector2(-24, 4)]), PackedColorArray([top, top, low, low]))
			ci.draw_polygon(PackedVector2Array([Vector2(-3, -96), Vector2(3, -96), Vector2(12, 4), Vector2(-12, 4)]), PackedColorArray([top, top, low, low])))
	# Bancos de terciopelo para mirar las estatuas / Velvet benches to look at the statues
	for bx in [-128.0, 150.0]:
		var at := c + Vector2(bx, 112)
		hub._blocks.append({"c": at, "r": Vector2(26, 5)})
		hub._prop(at, func(ci: CanvasItem) -> void:
			hub._shadow(ci, Vector2.ZERO, Vector2(28, 4))
			for lx in [-22.0, 20.0]:
				ci.draw_rect(Rect2(lx, -8, 3, 8), Color("5a3a24"))
			ci.draw_rect(Rect2(-26, -14, 52, 7), Color("1a1024"))
			ci.draw_rect(Rect2(-25, -13, 50, 5), Color("8a2438"))
			ci.draw_rect(Rect2(-25, -13, 50, 1), Color("b84a5e"))
			for k in 4:
				ci.draw_rect(Rect2(-18 + k * 12, -11, 1, 1), Color("d6a84a")))
	# Caballete con el cartel de la exposición, a la entrada / Easel with the exhibition poster, at the entrance
	var easel := c + Vector2(-196, 108)
	hub._blocks.append({"c": easel, "r": Vector2(10, 4)})
	hub._prop(easel, func(ci: CanvasItem) -> void:
		hub._shadow(ci, Vector2.ZERO, Vector2(12, 3))
		ci.draw_line(Vector2(-9, 0), Vector2(-3, -40), Color("6a4e36"), 2.0)
		ci.draw_line(Vector2(9, 0), Vector2(3, -40), Color("6a4e36"), 2.0)
		ci.draw_rect(Rect2(-14, -44, 28, 32), Color("1a1024"))
		ci.draw_rect(Rect2(-13, -43, 26, 30), Color("efe6cf"))
		# Silueta de un Foox y una luna / A Foox silhouette and a moon
		ci.draw_circle(Vector2(6, -36), 3.0, Color("e0a93a"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, -18), Vector2(-7, -26), Vector2(-4, -23), Vector2(2, -24), Vector2(5, -28), Vector2(6, -22), Vector2(9, -18)]), Color("4a3f7a"))
		ci.draw_rect(Rect2(-10, -16, 20, 1), Color("a8304a")))
	# Macetas con plantas de sueño junto a las columnas / Pots with dream plants by the columns
	for px in [-200.0, 200.0]:
		var at := c + Vector2(px, -58)
		hub._blocks.append({"c": at, "r": Vector2(7, 3)})
		hub._prop(at, func(ci: CanvasItem) -> void:
			hub._shadow(ci, Vector2.ZERO, Vector2(8, 2))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -10), Vector2(6, -10), Vector2(4, 0), Vector2(-4, 0)]), Color("b8673a"))
			ci.draw_rect(Rect2(-7, -12, 14, 3), Color("d6844e"))
			for k in 5:
				var ang := -PI * 0.5 + (k - 2) * 0.45 + sin(hub._t * 1.2 + k + px) * 0.05
				var tip := Vector2(0, -12) + Vector2.from_angle(ang) * (16.0 + (k % 2) * 6.0)
				ci.draw_line(Vector2(0, -12), tip, Color("5aa88a"), 2.0)
				ci.draw_circle(tip, 2.0, Color("9be3ff") if k % 2 else Color("c9b8ff")))
	# Postes con cordón de terciopelo a los lados del pasillo / Posts with a velvet rope along the aisle
	for side in [-1.0, 1.0]:
		for k in 4:
			var post := c + Vector2(side * 30.0, -36.0 + k * 40.0)
			hub._blocks.append({"c": post, "r": Vector2(4, 2)})
			var last := k == 3
			hub._prop(post, func(ci: CanvasItem) -> void:
				hub._shadow(ci, Vector2.ZERO, Vector2(5, 2))
				ci.draw_rect(Rect2(-4, -2, 8, 3), Color("8a6a2a"))
				ci.draw_rect(Rect2(-1.5, -22, 3, 20), Color("d6a84a"))
				ci.draw_rect(Rect2(-1.5, -22, 1, 20), Color("f2d488"))
				ci.draw_circle(Vector2(0, -23), 3.0, Color("f2d488"))
				if not last:
					# Cordón que cuelga hasta el siguiente poste / Rope sagging to the next post
					var pts := PackedVector2Array()
					for i in 9:
						var f := i / 8.0
						pts.append(Vector2(0, -19).lerp(Vector2(0, 21), f) + Vector2(sin(f * PI) * 5.0 * side, sin(f * PI) * 4.0))
					ci.draw_polyline(pts, Color("1a1024"), 3.0)
					ci.draw_polyline(pts, Color("a8304a"), 2.0))
	# Pesadillas a los dos lados del pasillo y jefes en la tarima del fondo
	# Nightmares on both sides of the aisle and bosses on the dais at the back
	var minor: Array[String] = []
	var bosses: Array[String] = []
	for id: String in Progress.BESTIARY:
		# El élite y el Foox dorado son variantes: no tienen estatua propia
		# The elite and the golden Foox are variants: they don't get a statue of their own
		if id == "elite" or id == "golden_foox":
			continue
		(bosses if id.begins_with("boss_") else minor).append(id)
	for i in minor.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		var j := i / 2
		var at := c + Vector2(side * (68.0 + (j % 4) * 50.0), -12.0 + (j / 4) * 70.0)
		_statue(minor[i], at, false)
	for i in bosses.size():
		_statue(bosses[i], c + Vector2(-150.0 + i * 60.0, -78.0), true)


## Cartel de tela colgado entre las dos columnas / Cloth banner hung between the two columns
func _draw_museum_banner(ci: CanvasItem) -> void:
	var f := UITheme.font("caps")
	var txt := tr("HUB_MUSEUM_BANNER").to_upper()
	var fs := 9
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := maxf(46.0, w * 0.5 + 10.0)
	# Dos postes de latón / Two brass posts
	for x in [-h, h]:
		hub._shadow(ci, Vector2(x, 0), Vector2(6, 2))
		ci.draw_rect(Rect2(x - 3, -66, 6, 66), Color("1a1024"))
		ci.draw_rect(Rect2(x - 2, -66, 4, 66), Color("d6a84a"))
		ci.draw_rect(Rect2(x - 2, -66, 1, 66), Color("f2d488"))
		ci.draw_circle(Vector2(x, -68), 4.0, Color("f2d488"))
	# Cartel de tela granate con letras doradas / Burgundy cloth sign with gold letters
	var sway := sin(hub._t * 0.9) * 1.0
	var pts := PackedVector2Array([Vector2(-h - 2, -64), Vector2(h + 2, -64), Vector2(h + 2, -46 + sway), Vector2(0, -40 + sway), Vector2(-h - 2, -46 + sway)])
	ci.draw_colored_polygon(pts, Color("1a1024"))
	var inner := PackedVector2Array([Vector2(-h, -62), Vector2(h, -62), Vector2(h, -47 + sway), Vector2(0, -42 + sway), Vector2(-h, -47 + sway)])
	ci.draw_colored_polygon(inner, Color("7a2034"))
	ci.draw_line(Vector2(-h, -60), Vector2(h, -60), Color("d6a84a"), 1.0)
	ci.draw_string(f, Vector2(-w * 0.5, -50 + sway * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f2d488"))


## Un pedestal (más grande y con placa dorada para los jefes) y, si ya lo has visto, su estatua
## A pedestal (bigger and with a gold plaque for bosses) and, if you've seen it, its statue
func _statue(id: String, at: Vector2, boss: bool) -> void:
	var k := 1.3 if boss else 1.0
	hub._blocks.append({"c": at + Vector2(0, -6), "r": Vector2(15, 6) * k})
	hub._spots.append({"kind": "statue", "id": id, "pos": at + Vector2(0, 6 * k), "height": 86.0 * k})
	hub._prop(at, func(ci: CanvasItem) -> void:
		hub._shadow(ci, Vector2(0, -2), Vector2(16, 4) * k)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		Sprites.draw(ci, "hub_pedestal")
		ci.draw_set_transform(Vector2.ZERO))
	if not Progress.has_seen(id):
		# Sin ver: una estatua tapada con una sábana y una etiqueta con «?» / Not seen yet: a statue covered with a sheet and a "?" tag
		hub._prop(at + Vector2(0, 0.5), func(ci: CanvasItem) -> void:
			var top := -19.0 * k
			var h := 34.0 * k
			var w := 13.0 * k
			var sway := sin(hub._t * 0.8 + at.x) * 0.6
			var sheet := PackedVector2Array([Vector2(-w - 2, top), Vector2(-w + 1, top - h * 0.55), Vector2(-w * 0.45 + sway, top - h * 0.92),
				Vector2(0, top - h), Vector2(w * 0.5 + sway, top - h * 0.9), Vector2(w - 1, top - h * 0.5), Vector2(w + 2, top),
				Vector2(w * 0.5, top - 2), Vector2(0, top + 1), Vector2(-w * 0.5, top - 2)])
			var ink := PackedVector2Array()
			for p in sheet:
				ink.append(p * Vector2(1.08, 1.0) + Vector2(0, 0.5))
			ci.draw_colored_polygon(ink, Color("1a1024"))
			ci.draw_colored_polygon(sheet, Color("cfc8e6"))
			# Pliegues / Folds
			ci.draw_line(Vector2(-w * 0.35, top - h * 0.8), Vector2(-w * 0.55, top - 2), Color("a49cc8"), 1.5)
			ci.draw_line(Vector2(w * 0.2, top - h * 0.85), Vector2(w * 0.35, top - 2), Color("a49cc8"), 1.5)
			ci.draw_line(Vector2(-w * 0.6, top - h * 0.55), Vector2(-w * 0.2, top - h * 0.75), Color("eeeaf8"), 1.0)
			# Etiqueta colgada con «?» / Hanging tag with "?"
			var tag := Vector2(w * 0.55, top - h * 0.45)
			ci.draw_line(tag + Vector2(-3, -6), tag + Vector2(0, -1), Color("6a4e36"), 1.0)
			ci.draw_rect(Rect2(tag + Vector2(-5, -1), Vector2(10, 11)), Color("1a1024"))
			ci.draw_rect(Rect2(tag + Vector2(-4, 0), Vector2(8, 9)), Color("f2d488"))
			var f := UITheme.font("caps")
			ci.draw_string(f, tag + Vector2(-2.5, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("7a2034")))
		return
	# La estatua va en su propio nodo, justo delante del pedestal / The statue goes in its own node, just in front of the pedestal
	var holder := Node2D.new()
	holder.position = at + Vector2(0, 0.5)
	hub._sort.add_child(holder)
	var top := Node2D.new()
	top.position = Vector2(0, -19 * k)
	# Los jefes son enormes: en estatua, más pequeños / Bosses are huge: as statues, smaller
	# Los jefes, en un hueco más grande para que se lean bien / Bosses get a bigger space so they read well
	var size := hub.STATUE_SIZE * (1.35 if boss else 1.0)
	holder.add_child(top)
	# Se pinta una vez en su propia textura y se congela: es piedra, no se mueve
	# Painted once into its own texture and frozen: it's stone, it doesn't move
	var vp := SubViewport.new()
	const SS := 3
	vp.size = (Vector2i(size) + Vector2i(4, 4)) * SS
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	var st: Control = HubWorld.Statue.new()
	st.id = id
	st.size = size * SS
	st.custom_minimum_size = size * SS
	st.position = Vector2(2, 2) * SS
	vp.add_child(st)
	var spr := Sprite2D.new()
	spr.texture = vp.get_texture()
	spr.centered = false
	spr.scale = Vector2.ONE / SS
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = Vector2(-size.x / 2.0 - 2.0, -size.y * 0.84 - 2.0)
	spr.material = hub._stone
	top.add_child(spr)
	hub._statues.append(st)
	hub.get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			st.process_mode = Node.PROCESS_MODE_DISABLED)

