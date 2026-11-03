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
		margin.add_theme_constant_override("margin_" + side, 110)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 52)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(UITheme.label("SELECT_TITLE", 70, UITheme.BONE, "display"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	root.add_child(gap)

	# Seis pijamas no caben a la vez: fila desplazable que sigue al foco
	# Six pajamas don't fit at once: a scrolling row that follows the focus
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	root.add_child(scroll)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 22)
	scroll.add_child(cards)

	var group := ButtonGroup.new()
	for data: Dictionary in GameState.CHARACTERS:
		var card := _make_card(data, group)
		cards.add_child(card)
		_cards.append(card)

	var footer := HBoxContainer.new()
	root.add_child(footer)
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(220, 64)
	back.pressed.connect(_go.bind(MAIN_MENU))
	footer.add_child(back)
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
## Alto del hueco de la descripción (4 líneas; si hay más, se desplaza) / Height of the description box (4 lines; more scrolls)
const DESC_H := 120.0


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

	# Descripción en un hueco de alto fijo: si no cabe, se desplaza con la rueda del ratón.
	# Así la ficha empieza a la misma altura en todas las cartas.
	# Description in a fixed-height box: if it doesn't fit, it scrolls with the mouse wheel.
	# That way the sheet starts at the same height on every card.
	var desc_scroll := ScrollContainer.new()
	desc_scroll.custom_minimum_size.y = DESC_H
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(desc_scroll)
	var desc := UITheme.label(data["desc"], 18, Color(UITheme.BONE, 0.8), "light")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = SIZE_EXPAND_FILL
	desc_scroll.add_child(desc)

	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	v.add_child(gap)
	v.add_child(_profile(data))
	UITheme.ignore_mouse(content)
	desc_scroll.mouse_filter = MOUSE_FILTER_PASS
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
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
