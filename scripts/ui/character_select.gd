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

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.size_flags_vertical = SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 24)
	root.add_child(cards)

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


func _make_card(data: Dictionary, group: ButtonGroup) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.custom_minimum_size = Vector2(404, 690)
	# Post-it con los actos superados, como en The Binding of Isaac
	# Post-it with the acts cleared, like in The Binding of Isaac
	var note := PixelView.wrap(PostIt.new(data["id"]), 2)
	note.custom_minimum_size = Vector2(120, 120)
	note.size = Vector2(120, 120)
	note.position = Vector2(404 - 118, -14)
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

	v.add_child(UITheme.label(data["tag"], 14, UITheme.GOLD, "caps"))

	var portrait := DreamerPortrait.new()
	portrait.character_id = data["id"]
	var portrait_px := PixelView.wrap(portrait, 3)
	portrait_px.custom_minimum_size = Vector2(0, 230)
	v.add_child(portrait_px)
	_portraits[data["id"]] = portrait

	var who := UITheme.label("Kroker", 14, UITheme.ASH, "caps")
	who.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(who)
	var name_label := UITheme.label(data["name"], 36, UITheme.BONE, "display")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_label)

	var sep := Control.new()
	sep.custom_minimum_size.y = 8
	v.add_child(sep)
	v.add_child(UITheme.rule(Color(UITheme.LINE, 0.9)))
	v.add_child(_pair("SELECT_WEAPON", data["weapon"], UITheme.BONE))
	v.add_child(_pair("SELECT_BONUS", data["bonus"], UITheme.GOLD))

	var desc := UITheme.label(data["desc"], 19, Color(UITheme.BONE, 0.8), "light")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)

	var push := Control.new()  # alinea las estadísticas abajo / pins stats to the bottom
	push.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(push)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 16)
	stats.add_theme_constant_override("v_separation", 8)
	for key: String in data["stats"]:
		var l := UITheme.label(key, 13, UITheme.ASH, "caps")
		l.custom_minimum_size.x = 120
		stats.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 5
		bar.value = data["stats"][key]
		bar.show_percentage = false
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		stats.add_child(bar)
	v.add_child(stats)

	UITheme.ignore_mouse(content)
	return card


func _pair(key: String, value_key: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var k := UITheme.label(key, 13, UITheme.ASH, "caps")
	k.custom_minimum_size.x = 120
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(k)
	var v := UITheme.label(value_key, 20, color)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
