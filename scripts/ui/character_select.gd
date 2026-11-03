extends Control
## Selección de personaje: Kroker con cuatro atuendos y cuatro armas.
## Character select: Kroker in four outfits with four weapons.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const RUN_SCENE := "res://scenes/run.tscn"

var _cards: Array[Button] = []
var _portraits := {}
var _start: Button
var _god: Button
var _diff: Button
var _picked := ""
## Páginas de cuatro pijamas, con flechas en pantalla / Pages of four pajamas, with on-screen arrows
const PER_PAGE := 4
var _page := 0
var _prev: Button
var _next: Button
var _page_label: Label


func _ready() -> void:
	theme = UITheme.build()
	Audio.play_music("music_menu")
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	_cards[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go(MAIN_MENU)


func _build() -> void:
	var bg := DreamBackground.new()
	bg.halo = Vector2(0.94, 0.07)
	var bg_px := PixelView.wrap(bg, 2)
	add_child(bg_px)
	bg_px.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 52)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var indent := Control.new()
	indent.custom_minimum_size.x = 76
	title_row.add_child(indent)
	title_row.add_child(UITheme.label("SELECT_TITLE", 70, UITheme.BONE, "display"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	root.add_child(gap)

	# No caben todos a la vez: páginas de cuatro con una flecha a cada lado
	# They don't all fit at once: pages of four with an arrow on each side
	var row := HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	_prev = _arrow("<", -1)
	row.add_child(_prev)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = SIZE_EXPAND_FILL
	cards.size_flags_horizontal = SIZE_EXPAND_FILL
	cards.alignment = BoxContainer.ALIGNMENT_BEGIN
	cards.add_theme_constant_override("separation", 22)
	row.add_child(cards)
	_next = _arrow(">", 1)
	row.add_child(_next)

	var group := ButtonGroup.new()
	for data: Dictionary in GameState.CHARACTERS:
		var card := _make_card(data, group)
		cards.add_child(card)
		_cards.append(card)

	_page_label = UITheme.label("", 18, UITheme.ASH, "caps")
	_page_label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size.x = 140

	var footer := HBoxContainer.new()
	root.add_child(footer)
	var indent2 := Control.new()
	indent2.custom_minimum_size.x = 76
	footer.add_child(indent2)
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(220, 64)
	back.pressed.connect(_go.bind(MAIN_MENU))
	footer.add_child(back)
	# Página actual, junto a Volver / Current page, next to Back
	footer.add_child(_page_label)
	_show_page(0)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(spacer)
	# Modo Dios para probar / God mode for testing
	_god = Button.new()
	_god.custom_minimum_size = Vector2(300, 64)
	_god.pressed.connect(_open_god)
	_god.visible = not Demo.on()   # solo para pruebas / testing only
	footer.add_child(_god)
	_update_god_button()
	var gap2 := Control.new()
	gap2.custom_minimum_size.x = 20
	footer.add_child(gap2)
	# Dificultad: la pesadilla se desbloquea al superar el Acto 1
	# Difficulty: nightmare unlocks after clearing Act 1
	if Progress.any_cleared():
		_diff = Button.new()
		_diff.custom_minimum_size = Vector2(300, 64)
		_diff.pressed.connect(func() -> void:
			GameState.difficulty = "normal" if GameState.difficulty == "nightmare" else "nightmare"
			_update_diff())
		footer.add_child(_diff)
		_update_diff()
		var gap3 := Control.new()
		gap3.custom_minimum_size.x = 20
		footer.add_child(gap3)
	else:
		GameState.difficulty = "normal"
	_start = Button.new()
	_start.text = "BTN_START"
	_start.disabled = true
	_start.custom_minimum_size = Vector2(340, 64)
	_start.pressed.connect(_on_start)
	footer.add_child(_start)


const CARD_W := 396.0
## Alto de la ficha de estadísticas (igual en todas; lo que no cabe se desplaza)
## Height of the stats sheet (the same on all; whatever doesn't fit scrolls)
const PROFILE_H := 244.0


## Flecha para cambiar de página / Arrow to change page
func _arrow(text: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(60, 220)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", UITheme.pixel_size(48))
	b.pressed.connect(func() -> void: _turn(dir))
	return b


func _pages() -> int:
	return int(ceil(_cards.size() / float(PER_PAGE)))


func _turn(dir: int) -> void:
	var p := clampi(_page + dir, 0, _pages() - 1)
	if p == _page:
		return
	Audio.play("ui_click", -6.0)
	_show_page(p)
	# El foco pasa a la primera (o última) carta disponible de la página nueva; si no hay, a la flecha
	# Focus moves to the first (or last) available card of the new page; if none, to the arrow
	var ids := range(p * PER_PAGE, mini((p + 1) * PER_PAGE, _cards.size()))
	if dir < 0:
		ids.reverse()
	for i: int in ids:
		if not _cards[i].disabled:
			_cards[i].grab_focus()
			return
	(_next if dir > 0 else _prev).grab_focus()


## Enseña solo las cartas de esa página y engancha la navegación con teclado o mando a las flechas
## Shows only that page's cards and hooks keyboard/gamepad navigation to the arrows
func _show_page(p: int) -> void:
	_page = p
	var first := p * PER_PAGE
	var last := mini(first + PER_PAGE, _cards.size()) - 1
	for i in _cards.size():
		_cards[i].visible = i >= first and i <= last
		_cards[i].focus_neighbor_left = NodePath()
		_cards[i].focus_neighbor_right = NodePath()
	_cards[first].focus_neighbor_left = _cards[first].get_path_to(_prev)
	_cards[last].focus_neighbor_right = _cards[last].get_path_to(_next)
	_prev.disabled = p == 0
	_next.disabled = p >= _pages() - 1
	_prev.modulate.a = 0.35 if _prev.disabled else 1.0
	_next.modulate.a = 0.35 if _next.disabled else 1.0
	_page_label.text = "%d / %d" % [p + 1, _pages()]


func _make_card(data: Dictionary, group: ButtonGroup) -> Button:
	var locked := not GameState.weapon_unlocked(data["id"])
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.custom_minimum_size = Vector2(CARD_W, 676)
	card.disabled = locked
	# Post-it con los actos superados, como en The Binding of Isaac
	# Post-it with the acts cleared, like in The Binding of Isaac
	var note := PixelView.wrap(PostIt.new(data["id"]), 2)
	note.custom_minimum_size = Vector2(120, 120)
	note.size = Vector2(120, 120)
	note.position = Vector2(CARD_W - 118, -14)
	note.visible = not locked
	note.z_index = 2
	card.add_child(note)
	card.toggled.connect(func(on: bool) -> void: if on: _select(data["id"]))
	card.mouse_entered.connect(card.grab_focus)

	var content := MarginContainer.new()
	content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		content.add_theme_constant_override("margin_" + side, 28)
	content.add_theme_constant_override("margin_top", 22)
	content.add_theme_constant_override("margin_bottom", 26)
	card.add_child(content)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	content.add_child(v)

	v.add_child(UITheme.label("SELECT_LOCKED" if locked else data["tag"], 14, UITheme.ASH if locked else UITheme.GOLD, "caps"))

	var portrait := DreamerPortrait.new()
	portrait.character_id = data["id"]
	var portrait_px := PixelView.wrap(portrait, 3)
	portrait_px.custom_minimum_size = Vector2(0, 176)
	v.add_child(portrait_px)
	_portraits[data["id"]] = portrait
	# Bloqueado: solo la silueta y cómo se consigue / Locked: just the silhouette and how to get it
	if locked:
		portrait_px.modulate = Color(0, 0, 0, 0.8)
		var q := UITheme.label("???", 36, UITheme.ASH, "display")
		q.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		v.add_child(q)
		var hint := UITheme.label("SELECT_UNLOCK_" + str(data["id"]).to_upper(), 20, Color(UITheme.BONE, 0.7), "italic")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
		UITheme.ignore_mouse(content)
		return card

	# El nombre siempre en una línea (si no cabe, más pequeño) para que todas las cartas cuadren
	# The name always on one line (smaller if it doesn't fit) so every card lines up
	var name_size := 36
	if UITheme.font("display").get_string_size(tr(data["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.pixel_size(36)).x > CARD_W - 56:
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

	# La ficha va abajo y mide lo mismo en todas las cartas; si no cabe, se desplaza por dentro
	# The sheet sits at the bottom and is the same size on every card; if it doesn't fit, it scrolls inside
	var push := Control.new()
	push.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(push)
	var profile := _profile(data)
	v.add_child(profile)
	UITheme.ignore_mouse(content)
	for sc: ScrollContainer in profile.find_children("*", "ScrollContainer", true, false):
		sc.mouse_filter = MOUSE_FILTER_PASS
	# Con mando: al seleccionar la carta, la ficha baja sola y el stick derecho la mueve
	# With a gamepad: when the card is selected, the sheet scrolls by itself and the right stick moves it
	for pad: PadScroll in profile.find_children("*", "PadScroll", true, false):
		card.focus_entered.connect(func() -> void: pad.active = true)
		card.focus_exited.connect(func() -> void: pad.active = false)
	return card


## Ficha del pijama: valoraciones con rombos, tipo de arma y todo lo que trae de serie, junto
## Pajama sheet: ratings with diamonds, weapon type and everything it comes with, all together
func _profile(data: Dictionary) -> Control:
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
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	outer.add_child(scroll)
	# Pista para el mando, solo si la ficha no cabe / Gamepad hint, only if the sheet doesn't fit
	var hint := UITheme.label("PAD_SCROLL_HINT", 12, Color(UITheme.ASH, 0.75), "caps")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.visible = false
	outer.add_child(hint)
	var pad := PadScroll.new()
	scroll.add_child(pad)
	var update_hint := func() -> void:
		if is_instance_valid(hint):
			hint.visible = Settings.using_pad and pad.max_scroll() > 1.0
	pad.overflow_changed.connect(func(_o: bool) -> void: update_hint.call())
	Settings.input_device_changed.connect(func(_p: bool) -> void: update_hint.call())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
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
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
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
	flow.add_child(_chip(tr("SELECT_RANGED" if ranged else "SELECT_MELEE"), Color(accent, 1.0), true))
	for perk: Dictionary in GameState.pajama_perks(id):
		flow.add_child(_chip(perk["text"], UITheme.MIST if perk["good"] else UITheme.EMBER, false))
	return panel


## Etiqueta redondeada (con palabras clave) / Rounded tag (with keywords)
func _chip(text: String, color: Color, solid: bool) -> Control:
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


func _pair(key: String, value_key: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var k := UITheme.label(key, 13, UITheme.ASH, "caps")
	k.custom_minimum_size.x = 120
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(k)
	var v := Keywords.label(value_key, 20, color)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(v)
	return row


func _update_diff() -> void:
	_diff.text = "DIFF_BUTTON_" + GameState.difficulty.to_upper()
	_diff.add_theme_color_override("font_color", UITheme.EMBER if GameState.difficulty == "nightmare" else UITheme.ASH)


func _open_god() -> void:
	var panel := GodPanel.new()
	panel.weapon = _picked
	panel.closed.connect(func() -> void:
		_update_god_button()
		_god.grab_focus())
	add_child(panel)


func _update_god_button() -> void:
	_god.text = "GOD_BUTTON_ON" if GameState.god_mode else "GOD_BUTTON"
	_god.add_theme_color_override("font_color", UITheme.GOLD if GameState.god_mode else UITheme.ASH)


func _select(id: String) -> void:
	_picked = id
	GameState.selected_character = id
	for key: String in _portraits:
		_portraits[key].selected = key == id
	_start.disabled = false


func _on_start() -> void:
	if not _start.disabled:
		GameState.start_run()
		_go(RUN_SCENE)


func _go(path: String) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(GameState.change_scene.bind(path))
