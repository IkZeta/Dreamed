class_name GodPanel
extends CanvasLayer
## Panel del modo Dios (para probar): elegir el sueño en el que empezar, las mejoras del
## plano astral y las estadísticas de nivel. Se aplica al empezar a soñar.
## God mode panel (for testing): choose the starting dream, the astral plane upgrades and
## the level stats. Applied when you start dreaming.

signal closed

## Arma elegida en la selección ("" si aún no hay) / Weapon picked on the select screen ("" if none yet)
var weapon := ""
var _refreshers: Array[Callable] = []
var _first: Control


func _ready() -> void:
	layer = 15
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.88)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.96), Color(UITheme.GOLD, 0.55), Color(UITheme.GOLD, 0.12), 20, 18, 36))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var title := UITheme.label("GOD_TITLE", 54, UITheme.GOLD, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UITheme.label("GOD_SUB", 20, UITheme.ASH, "italic")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	col.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size.x = 620
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size.x = 620
	cols.add_child(right)

	# Activar / Enable
	var enable := CheckButton.new()
	enable.button_pressed = GameState.god_mode
	enable.toggled.connect(func(on: bool) -> void: GameState.god_mode = on)
	left.add_child(_row("GOD_ENABLE", enable))
	_first = enable

	# Sueño inicial / Starting dream
	left.add_child(_section("GOD_DREAM"))
	left.add_child(_stepper("", func() -> String:
		var d := GameState.god_depth
		return tr("GOD_BOSS") % d if GameState.wave_for(d).get("boss", false) else tr("RUN_DREAM") % d,
		func(dir: int) -> void: GameState.god_depth = clampi(GameState.god_depth + dir, 1, GameState.WAVES.size())))

	# Mejoras / Upgrades
	left.add_child(_section("GOD_UPGRADES"))
	if weapon == "":
		var hint := UITheme.label("GOD_PICK_WEAPON", 15, UITheme.ASH, "italic")
		left.add_child(hint)
	for g in GameState.GIVERS:
		left.add_child(_stepper("GIVER_%s_NAME" % g.to_upper(), _giver_text.bind(g), _giver_step.bind(g)))

	# Estadísticas / Stats
	right.add_child(_section("GOD_STATS"))
	for s in GameState.STATS:
		right.add_child(_stepper("STAT_NAME_" + s.to_upper(), _stat_text.bind(s), _stat_step.bind(s)))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	col.add_child(buttons)
	var reset := Button.new()
	reset.text = "GOD_RESET"
	reset.custom_minimum_size = Vector2(240, 58)
	reset.pressed.connect(func() -> void:
		GameState.god_depth = 1
		GameState.god_upgrades = {}
		GameState.god_stats = {}
		_refresh())
	buttons.add_child(reset)
	var done := Button.new()
	done.text = "GOD_CLOSE"
	done.custom_minimum_size = Vector2(240, 58)
	done.pressed.connect(close)
	buttons.add_child(done)

	_refresh()
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	_first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _giver_text(g: String) -> String:
	var lvl := int(GameState.god_upgrades.get(g, 0))
	if lvl <= 0:
		return "—"
	var txt := tr("UP_LEVEL") % lvl
	if weapon != "":
		txt += " · " + tr(GameState.upgrade_key(g, weapon, "NAME"))
	return txt


func _giver_step(dir: int, g: String) -> void:
	var lvl := clampi(int(GameState.god_upgrades.get(g, 0)) + dir, 0, GameState.MAX_UPGRADE_LEVEL)
	if lvl == 0:
		GameState.god_upgrades.erase(g)
	else:
		GameState.god_upgrades[g] = lvl


func _stat_text(s: String) -> String:
	var v := float(GameState.god_stats.get(s, 0.0))
	return "—" if v <= 0.0 else GameState.stat_value_text(s, v)


## Cada pulsación suma el valor de una mejora común / Each press adds one common upgrade's value
func _stat_step(dir: int, s: String) -> void:
	var step := float(GameState.STAT_STEPS[s][0])
	var v := maxf(0.0, float(GameState.god_stats.get(s, 0.0)) + step * dir)
	if v <= 0.0:
		GameState.god_stats.erase(s)
	else:
		GameState.god_stats[s] = v


func _refresh() -> void:
	for r in _refreshers:
		r.call()


func _section(key: String) -> Control:
	var l := UITheme.label(key, 15, UITheme.GOLD, "caps")
	l.custom_minimum_size.y = 34
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _row(key: String, control: Control) -> Control:
	var box := HBoxContainer.new()
	var l := UITheme.label(key, 22, UITheme.BONE, "body")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(l)
	box.add_child(control)
	return box


## Fila con − valor + / Row with − value +
func _stepper(key: String, text: Callable, step: Callable) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	if key != "":
		var l := UITheme.label(key, 20, UITheme.BONE, "body")
		l.custom_minimum_size.x = 210
		box.add_child(l)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(52, 46)
	box.add_child(minus)
	var value := UITheme.label("", 18, UITheme.GOLD, "body")
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	box.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(52, 46)
	box.add_child(plus)
	var update := func() -> void: value.text = text.call()
	_refreshers.append(update)
	minus.pressed.connect(func() -> void:
		step.call(-1)
		Audio.play("click", -8.0)
		_refresh())
	plus.pressed.connect(func() -> void:
		step.call(1)
		Audio.play("click", -8.0)
		_refresh())
	return box
