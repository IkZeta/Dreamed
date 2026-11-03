class_name PajamaCard
extends RefCounted
## Carta de un pijama: retrato, nombre, arma, descripción y la ficha con estadísticas y lo que
## trae de serie. Se enseña en el armario del plano astral al acercarte a un soporte.
## A pajama's card: portrait, name, weapon, description and the sheet with stats and what it
## comes with. Shown in the astral plane's wardrobe when you walk up to a stand.

const W := 396.0
const H := 676.0
## Alto de la ficha de estadísticas (igual en todas; lo que no cabe se desplaza)
## Height of the stats sheet (the same on all; whatever doesn't fit scrolls)
const PROFILE_H := 244.0


## "worn": es el que lleva puesto Kroker (la carta se ve marcada)
## "worn": it's the one Kroker is wearing (the card shows as picked)
static func build(data: Dictionary, worn := false) -> Control:
	var locked := not GameState.weapon_unlocked(data["id"])
	# Fondo opaco que crece con lo que lleve dentro / Opaque backdrop that grows with its contents
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(W, 0)
	var edge := UITheme.GOLD if worn else (UITheme.ASH if locked else UITheme.LINE)
	panel.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.97), Color(edge, 0.9), Color(edge, 0.14), 16, 12, 0))
	card.add_child(panel)
	panel.resized.connect(func() -> void: card.size = panel.size)
	# Post-it con los actos superados, como en The Binding of Isaac
	# Post-it with the acts cleared, like in The Binding of Isaac
	var note := PixelView.wrap(PostIt.new(data["id"]), 2)
	note.custom_minimum_size = Vector2(120, 120)
	note.size = Vector2(120, 120)
	note.position = Vector2(W - 118, -14)
	note.visible = not locked
	note.z_index = 2
	card.add_child(note)

	var content := MarginContainer.new()
	for side in ["left", "right"]:
		content.add_theme_constant_override("margin_" + side, 28)
	content.add_theme_constant_override("margin_top", 22)
	content.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(content)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	content.add_child(v)

	var tag := UITheme.label("SELECT_LOCKED" if locked else data["tag"], 14, UITheme.ASH if locked else UITheme.GOLD, "caps")
	v.add_child(tag)

	var portrait := DreamerPortrait.new()
	portrait.character_id = data["id"]
	portrait.selected = worn
	var portrait_px := PixelView.wrap(portrait, 3)
	portrait_px.custom_minimum_size = Vector2(0, 176)
	v.add_child(portrait_px)
	# Bloqueado: solo la silueta y cómo se consigue / Locked: just the silhouette and how to get it
	if locked:
		portrait_px.modulate = Color(0, 0, 0, 0.8)
		var q := UITheme.label("???", 36, UITheme.ASH, "display")
		q.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		v.add_child(q)
		var hint := UITheme.label("SELECT_UNLOCK_" + str(data["id"]).to_upper(), 20, Color(UITheme.BONE, 0.7), "italic")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
		UITheme.ignore_mouse(content)
		return card

	# El nombre siempre en una línea (si no cabe, más pequeño) / The name always on one line (smaller if it doesn't fit)
	var name_size := 36
	if UITheme.font("display").get_string_size(_t(data["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.pixel_size(36)).x > W - 56:
		name_size = 24
	var name_label := UITheme.label(data["name"], name_size, UITheme.BONE, "display")
	name_label.custom_minimum_size.y = 44
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(name_label)

	var sep := Control.new()
	sep.custom_minimum_size.y = 2
	v.add_child(sep)
	v.add_child(UITheme.rule(Color(UITheme.LINE, 0.9)))
	v.add_child(_pair("SELECT_WEAPON", data["weapon"], UITheme.BONE))

	var desc := UITheme.label(data["desc"], 18, Color(UITheme.BONE, 0.8), "light")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Como mucho 5 líneas, para que la ficha de abajo no se salga de la carta
	# At most 5 lines, so the sheet below never spills out of the card
	desc.max_lines_visible = 5
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(desc)

	# La ficha mide lo mismo en todas las cartas; si no cabe, se desplaza sola, sin barra
	# The sheet is the same size on every card; if it doesn't fit, it scrolls by itself, with no bar
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	v.add_child(gap)
	var profile := _profile(data)
	v.add_child(profile)
	UITheme.ignore_mouse(content)
	for sc: ScrollContainer in profile.find_children("*", "ScrollContainer", true, false):
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
	# La ficha baja sola (y con mando, el stick derecho la mueve) / The sheet scrolls by itself (and with a gamepad, the right stick moves it)
	for pad: PadScroll in profile.find_children("*", "PadScroll", true, false):
		pad.always = true
		pad.active = true
	return card


## Ficha del pijama: valoraciones con rombos, tipo de arma y todo lo que trae de serie, junto
## Pajama sheet: ratings with diamonds, weapon type and everything it comes with, all together
static func _profile(data: Dictionary) -> Control:
	var id: String = data["id"]
	var pj: Dictionary = KrokerArt.PAJAMAS.get(id, KrokerArt.PAJAMAS[""])
	# El color más claro del pijama / The pajama's lightest colour
	var accent: Color = pj["pattern"] if Color(pj["pattern"]).get_luminance() > Color(pj["piping"]).get_luminance() else pj["piping"]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.INK, 0.55)
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.border_color = Color(accent, 0.8)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.y = PROFILE_H
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	# Pista para el mando, solo si la ficha no cabe / Gamepad hint, only if the sheet doesn't fit
	var hint := UITheme.label("PAD_SCROLL_HINT", 12, Color(UITheme.ASH, 0.75), "caps")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.visible = false
	outer.add_child(hint)
	var pad := PadScroll.new()
	scroll.add_child(pad)
	pad.overflow_changed.connect(func(o: bool) -> void:
		if is_instance_valid(hint):
			hint.visible = Settings.using_pad and o)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	# Valoraciones de 1 a 5, en dos columnas / Ratings 1 to 5, in two columns
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for key: String in data["stats"]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(UITheme.label(key, 12, UITheme.ASH, "caps"))
		var pips := Pips.new()
		pips.value = int(data["stats"][key])
		pips.color = UITheme.GOLD
		cell.add_child(pips)
		grid.add_child(cell)
	v.add_child(UITheme.rule(Color(UITheme.LINE, 0.4)))
	# Tipo de arma y lo de serie, como etiquetas / Weapon type and the built-ins, as tags
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	var ranged := id in GameState.RANGED
	flow.add_child(_chip(_t("SELECT_RANGED" if ranged else "SELECT_MELEE"), Color(accent, 1.0), true))
	for perk: Dictionary in GameState.pajama_perks(id):
		flow.add_child(_chip(perk["text"], UITheme.MIST if perk["good"] else UITheme.EMBER, false))
	return panel


## Etiqueta redondeada (con palabras clave) / Rounded tag (with keywords)
static func _chip(text: String, color: Color, solid: bool) -> Control:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.85 if solid else 0.14)
	sb.border_color = Color(color, 0.7)
	sb.set_border_width_all(0 if solid else 1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", sb)
	var l := Keywords.label(text, 15, UITheme.INK if solid else color.lightened(0.35), "body")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.fit_content = true
	chip.add_child(l)
	return chip


static func _pair(key: String, value_key: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var k := UITheme.label(key, 13, UITheme.ASH, "caps")
	k.custom_minimum_size.x = 120
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(k)
	var v := Keywords.label(value_key, 20, color)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	return row


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


## Cinco rombos, rellenos hasta el valor / Five diamonds, filled up to the value
class Pips extends Control:
	var value := 0
	var color := Color.WHITE

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 18)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := 7.0
		var step := minf(22.0, (size.x - r * 2.0) / 4.0)
		for i in 5:
			var c := Vector2(r + i * step, size.y / 2.0)
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			if i < value:
				draw_colored_polygon(pts, color)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.5, -r * 0.5), c + Vector2(0, 0), c + Vector2(-r * 0.5, -r * 0.5)]), Color(1, 1, 1, 0.35))
			else:
				pts.append(pts[0])
				draw_polyline(pts, Color(color, 0.3), 1.5)
