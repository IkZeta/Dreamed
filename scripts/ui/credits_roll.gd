class_name CreditsRoll
extends Control
## Créditos: suben despacio sobre el cielo del sueño, con el reparto (solo los personajes que ya
## conoces, para no destripar a nadie) y las pesadillas que has visto. Se abren desde el menú y,
## la primera vez, al terminar el sueño 20. Cualquier tecla los acelera; Esc los cierra.
## Credits: they rise slowly over the dream sky, with the cast (only the characters you've met, so
## nobody is spoiled) and the nightmares you've seen. Opened from the menu and, the first time,
## after finishing dream 20. Any key speeds them up; Esc closes them.

signal closed

const SPEED := 46.0          # px/s
const FAST := 6.0            # multiplicador al mantener / multiplier while held
const CAST: Array[String] = ["cat", "charo", "svinho", "stolk", "silly", "doc", "ad", "pinche", "magnus", "superk", "lilkey", "lynx", "luna"]

var _col: VBoxContainer
var _scroll := 0.0
var _hold := false
var _ending := false


static func make() -> CreditsRoll:
	return CreditsRoll.new()


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var bg := DreamBackground.new()
	bg.halo = Vector2(0.86, 0.17)
	var bg_px := PixelView.wrap(bg, 2)
	add_child(bg_px)
	bg_px.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(UITheme.INK, 0.45)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_col = VBoxContainer.new()
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_col.add_theme_constant_override("separation", 14)
	_col.custom_minimum_size.x = 1100
	_col.z_index = 1
	add_child(_col)
	_fill()

	var hint := UITheme.label("CREDITS_HINT", 18, Color(UITheme.ASH, 0.7), "caps")
	add_child(hint)
	hint.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT, PRESET_MODE_MINSIZE, 30)

	Audio.play_music("music_credits", 1.2)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	_scroll = get_viewport_rect().size.y + 40.0
	_place()


func _fill() -> void:
	var title := UITheme.label("DREAMED", 130, UITheme.BONE, "display")
	title.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_center(title)
	_line("CREDITS_BY", 30, UITheme.GOLD, "italic")
	_space(90)

	_heading("CREDITS_DREAMER")
	var kroker := PixelView.wrap(DreamerPortrait.new(), 4)
	kroker.custom_minimum_size = Vector2(240, 300)
	kroker.size_flags_horizontal = SIZE_SHRINK_CENTER
	_col.add_child(kroker)
	_line("CREDITS_KROKER", 26, UITheme.BONE, "body")
	_space(70)

	_heading("CREDITS_CAST")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 80)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = SIZE_SHRINK_CENTER
	_col.add_child(grid)
	var hidden := 0
	for id in CAST:
		if not Progress.met(id):
			hidden += 1
			continue
		grid.add_child(_cast_row(id))
	if hidden > 0:
		_line(tr("CREDITS_UNMET") % hidden, 20, Color(UITheme.ASH, 0.75), "italic", false)
	_space(70)

	_heading("CREDITS_NIGHTMARES")
	var names: Array[String] = []
	for id in Progress.BESTIARY:
		if Progress.has_seen(id):
			names.append(tr("BEST_%s_NAME" % id.to_upper()).replace(" ", "\u00a0"))
	var nm := UITheme.label(" · ".join(names) if not names.is_empty() else "…", 22, UITheme.ASH, "body")
	nm.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size.x = 900
	_center(nm)
	_space(70)

	_heading("CREDITS_MADE")
	_line("CREDITS_ENGINE", 24, UITheme.BONE, "body")
	_line("CREDITS_SOUND", 24, UITheme.BONE, "body")
	_space(160)
	_line("CREDITS_THANKS", 44, UITheme.GOLD, "display")
	_space(40)


func _cast_row(id: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.custom_minimum_size.x = 420
	h.add_child(FaceBadge.make(id, 64))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var name_key := "CHARO_NAME" if id == "charo" else "GIVER_%s_NAME" % id.to_upper()
	var role_key := "CREDITS_CHARO_ROLE" if id == "charo" else "GIVER_%s_ROLE" % id.to_upper()
	v.add_child(UITheme.label(name_key, 26, UITheme.BONE, "caps"))
	v.add_child(UITheme.label(role_key, 18, Color(UITheme.ASH, 0.85), "italic"))
	return h


func _heading(key: String) -> void:
	_line(key, 22, UITheme.GOLD, "caps")
	var r := UITheme.rule(Color(UITheme.GOLD, 0.5), 70)
	r.size_flags_horizontal = SIZE_SHRINK_CENTER
	_col.add_child(r)


func _line(key: String, fs: int, col: Color, role: String, translate := true) -> void:
	var l := UITheme.label(key, fs, col, role)
	if not translate:
		l.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center(l)


func _center(c: Control) -> void:
	c.size_flags_horizontal = SIZE_SHRINK_CENTER
	_col.add_child(c)


func _space(h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = h
	_col.add_child(s)


func _place() -> void:
	var vw := get_viewport_rect().size
	_col.size = Vector2(_col.custom_minimum_size.x, 0)
	_col.reset_size()
	_col.position = Vector2((vw.x - _col.size.x) * 0.5, _scroll)


func _process(delta: float) -> void:
	_scroll -= delta * SPEED * (FAST if _hold else 1.0)
	_place()
	if not _ending and _scroll + _col.size.y < get_viewport_rect().size.y * 0.45:
		_close()


func _close() -> void:
	if _ending:
		return
	_ending = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
		return
	if event.is_echo():
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton)
	if pressed:
		_hold = event.is_pressed()
		get_viewport().set_input_as_handled()
