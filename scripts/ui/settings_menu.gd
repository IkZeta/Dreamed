extends Control
## Menú de ajustes con pestañas: Sonido, Idioma y Pantalla.
## Settings menu with tabs: Sound, Language and Display.
## Se abre encima de cualquier escena. Los cambios se aplican al momento
## y se guardan al cerrar. / Opens on top of any scene; changes apply live
## and are saved on close.

signal closed

const TABS: Array[String] = ["TAB_SOUND", "TAB_LANGUAGE", "TAB_DISPLAY", "TAB_ACCESS"]

var _tab_buttons: Array[Button] = []
var _pages_holder: VBoxContainer
var _current_tab := 0
var _back: Button


func _ready() -> void:
	theme = UITheme.build()
	process_mode = Node.PROCESS_MODE_ALWAYS  # funciona también en pausa / works while paused
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_tab_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.82)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1080, 720)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 28)
	panel.add_child(root)

	root.add_child(UITheme.label("SETTINGS_TITLE", 60, UITheme.BONE, "display"))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	root.add_child(tabs)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(200, 60)
		b.pressed.connect(_show_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)

	_pages_holder = VBoxContainer.new()
	_pages_holder.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_pages_holder)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	var reset := Button.new()
	reset.text = "BTN_RESET"
	reset.custom_minimum_size = Vector2(260, 68)
	reset.pressed.connect(_on_reset)
	footer.add_child(reset)
	var gap := Control.new()
	gap.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(gap)
	_back = Button.new()
	_back.text = "BTN_BACK"
	_back.custom_minimum_size = Vector2(240, 68)
	_back.pressed.connect(_close)
	footer.add_child(_back)

	_tab_buttons[0].button_pressed = true
	_show_tab(0)


func _show_tab(index: int) -> void:
	_current_tab = index
	for child in _pages_holder.get_children():
		child.queue_free()
	var page: Control
	match index:
		0: page = _build_sound()
		1: page = _build_language()
		2: page = _build_display()
		_: page = _build_access()
	_pages_holder.add_child(page)


# --- Pestaña Sonido / Sound tab --------------------------------------------

func _build_sound() -> Control:
	var page := _page()
	page.add_child(_slider_row("SOUND_MASTER", "Master"))
	page.add_child(_slider_row("SOUND_MUSIC", "Music"))
	page.add_child(_slider_row("SOUND_SFX", "SFX"))
	var mute := CheckButton.new()
	mute.button_pressed = Settings.muted
	mute.toggled.connect(Settings.set_muted)
	page.add_child(_row("SOUND_MUTE", mute))
	return page


func _slider_row(key: String, bus: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = float(Settings.volumes[bus]) * 100.0
	slider.custom_minimum_size = Vector2(380, 40)
	slider.size_flags_vertical = SIZE_SHRINK_CENTER
	var value := UITheme.label("%d%%" % slider.value, 22, UITheme.GOLD, "light")
	value.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	value.custom_minimum_size.x = 80
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % v
		Settings.set_volume(bus, v / 100.0))
	box.add_child(slider)
	box.add_child(value)
	return _row(key, box)


# --- Pestaña Idioma / Language tab -----------------------------------------

func _build_language() -> Control:
	var page := _page()
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 14)
	var group := ButtonGroup.new()
	# Los nombres de idioma se muestran siempre en su propio idioma.
	# Language names always appear in their own language.
	for pair in [["es", "Español"], ["en", "English"]]:
		var b := Button.new()
		b.text = pair[1]
		b.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = Settings.locale == pair[0]
		b.custom_minimum_size = Vector2(220, 68)
		b.pressed.connect(Settings.set_locale.bind(pair[0]))
		choices.add_child(b)
	page.add_child(_row("LANGUAGE_LABEL", choices))
	page.add_child(UITheme.label("LANGUAGE_HINT", 22, UITheme.ASH, "italic"))
	return page


# --- Pestaña Pantalla / Display tab ----------------------------------------

func _build_display() -> Control:
	var page := _page()

	var resolution := OptionButton.new()
	for r in Settings.RESOLUTIONS:
		resolution.add_item("%d × %d" % [r.x, r.y])
	resolution.select(Settings.resolution_index)
	resolution.disabled = Settings.window_mode != Settings.WindowMode.WINDOWED
	resolution.custom_minimum_size.x = 360
	resolution.item_selected.connect(func(i: int) -> void:
		Settings.resolution_index = i
		Settings.apply_display())

	var mode := OptionButton.new()
	for key in ["MODE_WINDOWED", "MODE_FULLSCREEN", "MODE_EXCLUSIVE"]:
		mode.add_item(key)
	mode.select(Settings.window_mode)
	mode.custom_minimum_size.x = 360
	mode.item_selected.connect(func(i: int) -> void:
		Settings.window_mode = i
		resolution.disabled = i != Settings.WindowMode.WINDOWED
		Settings.apply_display())

	var fps := OptionButton.new()
	for f in Settings.FPS_OPTIONS:
		fps.add_item("FPS_UNLIMITED" if f == 0 else str(f))
	fps.select(Settings.fps_index)
	fps.custom_minimum_size.x = 360
	fps.item_selected.connect(func(i: int) -> void:
		Settings.fps_index = i
		Settings.apply_display())

	var vsync := CheckButton.new()
	vsync.button_pressed = Settings.vsync
	vsync.toggled.connect(func(on: bool) -> void:
		Settings.vsync = on
		Settings.apply_display())

	page.add_child(_row("DISPLAY_MODE", mode))
	page.add_child(_row("DISPLAY_RESOLUTION", resolution))
	page.add_child(_row("DISPLAY_VSYNC", vsync))
	page.add_child(_row("DISPLAY_FPS", fps))
	return page


# --- Pestaña Accesibilidad / Accessibility tab --------------------------------

func _build_access() -> Control:
	var page := _page()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = Settings.shake_amount * 100.0
	slider.custom_minimum_size = Vector2(380, 40)
	slider.size_flags_vertical = SIZE_SHRINK_CENTER
	var value := UITheme.label("%d%%" % slider.value, 22, UITheme.GOLD, "light")
	value.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	value.custom_minimum_size.x = 80
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % v
		Settings.shake_amount = v / 100.0
		Settings.screen_shake = v > 0.0)
	box.add_child(slider)
	box.add_child(value)
	page.add_child(_row("DISPLAY_SHAKE", box))
	var cb := CheckButton.new()
	cb.button_pressed = Settings.colorblind
	cb.toggled.connect(func(on: bool) -> void: Settings.colorblind = on)
	page.add_child(_row("ACCESS_COLORBLIND", cb))
	var dn := CheckButton.new()
	dn.button_pressed = Settings.damage_numbers
	dn.toggled.connect(func(on: bool) -> void: Settings.damage_numbers = on)
	page.add_child(_row("ACCESS_DAMAGE_NUMBERS", dn))
	var vib := CheckButton.new()
	vib.button_pressed = Settings.vibration
	vib.toggled.connect(func(on: bool) -> void:
		Settings.vibration = on
		if on:
			Settings.rumble(0.4, 0.4, 0.2))
	page.add_child(_row("ACCESS_VIBRATION", vib))
	page.add_child(UITheme.label("ACCESS_HINT", 22, UITheme.ASH, "italic"))
	return page


# --- Utilidades / Helpers ---------------------------------------------------

func _page() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	return v


func _row(key: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 64
	var l := UITheme.label(key, 26, UITheme.BONE, "light")
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	control.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


func _on_reset() -> void:
	Settings.reset_defaults()
	_show_tab(_current_tab)


func _close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()
