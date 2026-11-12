extends Control
## Menú principal: Kroker cae dormido a través de sus sueños (MenuFall) bajo el logo, y abajo, en un
## panel, seguir la partida guardada, empezar, y una fila de botones con icono (logros, ajustes,
## créditos y salir). Arriba a la derecha, cómo va el sueño; abajo, en qué acto está cayendo.
## Main menu: Kroker falls asleep through his dreams (MenuFall) under the logo, and below, in a
## panel, continuing the saved run, starting, and a row of icon buttons (achievements, settings,
## credits and quit). Top right, how the dream is going; at the bottom, which act he's falling through.

const SETTINGS_SCENE := preload("res://scenes/settings_menu.tscn")
## Jugar lleva al plano astral: allí se elige pijama y se empieza a soñar en la fuente
## Play takes you to the astral plane: there you pick a pajama and start dreaming at the fountain
const HUB := "res://scenes/astral_hub.tscn"
const ACHIEVEMENTS_SCENE := preload("res://scripts/ui/achievements.gd")
const PANEL_W := 620.0

var _play: Button
var _settings: Button
var _achievements: Button
var _credits: Button
var _unlock: Button
var _unlock_armed := false
var _reset: Button
var _reset_step := 0
var _quitting := false
var _fall: MenuFall
var _fall_px: PixelView
var _ui: Control
var _caption: Label
var _par := Vector2.ZERO


func _ready() -> void:
	theme = UITheme.build()
	Audio.play_music("music_menu")
	_build()
	_play.grab_focus()


func _build() -> void:
	# El sueño: Kroker cayendo entre los trozos de sus sueños / The dream: Kroker falling among the pieces of his dreams
	_fall = MenuFall.new()
	_fall.outfit = _outfit()
	_fall_px = PixelView.wrap(_fall, 2)
	add_child(_fall_px)
	_fall_px.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_fall.act_changed.connect(_on_act_changed)

	# Velos arriba y abajo para que se lean el logo y el panel / Veils top and bottom so the logo and the panel read well
	_veil(0.0, 0.3, Color(UITheme.INK, 0.55), Color(UITheme.INK, 0.0))
	_veil(0.55, 1.0, Color(UITheme.INK, 0.0), Color(UITheme.INK, 0.7))

	_ui = Control.new()
	_ui.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_ui)
	_ui.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Logo y lema, centrados arriba / Logo and tagline, centred at the top
	var top := VBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 0)
	_ui.add_child(top)
	top.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	top.grow_horizontal = GROW_DIRECTION_BOTH
	top.offset_top = 14
	var title := DreamTitle.new()
	title.size_flags_horizontal = SIZE_SHRINK_CENTER
	top.add_child(title)
	var tagline := UITheme.label("MENU_TAGLINE", 20, Color(UITheme.ASH, 0.9), "caps")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(tagline)
	_appear(tagline, 0.9)

	# Panel de abajo / Bottom panel
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.84), Color(UITheme.LINE, 0.45), Color(UITheme.MIST, 0.16), 26, 20, 26))
	_ui.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BEGIN
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_bottom = -92
	_appear(panel, 0.7, 24.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	if GameState.has_saved_run():
		var info := GameState.saved_run_info()
		var depth := int(info.get("depth", 1))
		var cont := _big(col, tr("MENU_CONTINUE") % depth, "menu_continue", _on_continue)
		cont.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		var sub := UITheme.label("%s  ·  %s" % [_act_name(GameState.act_of(depth) if depth < 20 else 5), tr("CHAR_%s_NAME" % String(info.get("weapon", "bat")).to_upper())], 16, Color(UITheme.MIST, 0.9), "caps")
		sub.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sub)
		col.move_child(sub, col.get_child_count() - 1)
		_play = cont
		_big(col, "MENU_PLAY", "menu_play", _on_play, true)
	else:
		_play = _big(col, "MENU_PLAY", "menu_play", _on_play)

	var rule := UITheme.rule(Color(UITheme.GOLD, 0.35), 260)
	rule.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(rule)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_achievements = _tile(row, "MENU_ACHIEVEMENTS", "menu_trophy", _on_achievements,
		"%d/%d" % [Progress.achieved.size(), Progress.ACHIEVEMENTS.size()])
	_settings = _tile(row, "MENU_SETTINGS", "menu_gear", _on_settings)
	_credits = _tile(row, "MENU_CREDITS", "menu_film", _on_credits)
	_tile(row, "MENU_QUIT", "menu_door", _on_quit)

	# Abajo a la izquierda: el acto por el que cae y, discretas, desbloquear todo y borrar partida
	# Bottom left: the act he's falling through and, discreetly, unlock everything and delete save
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	_ui.add_child(left)
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.grow_vertical = GROW_DIRECTION_BEGIN
	left.offset_left = 44
	left.offset_bottom = -26
	_caption = UITheme.label(_act_name(_fall.current_act()), 18, Color(UITheme.BONE, 0.75), "caps")
	_caption.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	left.add_child(_caption)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 28)
	left.add_child(tools)
	_unlock = _small(tools, "MENU_UNLOCK_ALL", _on_unlock_all)
	_reset = _small(tools, "MENU_RESET", _on_reset)
	_appear(left, 1.2)

	# Abajo a la derecha, sobre la versión: cómo va el sueño de Kroker / Bottom right, above the version: how Kroker's dream is going
	var best := int(Progress.stats.get("best_depth", 0))
	if best > 0:
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 34)
		_ui.add_child(stats)
		stats.anchor_left = 1.0
		stats.anchor_right = 1.0
		stats.anchor_top = 1.0
		stats.anchor_bottom = 1.0
		stats.grow_horizontal = GROW_DIRECTION_BEGIN
		stats.grow_vertical = GROW_DIRECTION_BEGIN
		stats.offset_right = -44
		stats.offset_bottom = -64
		_stat(stats, str(best), "MENU_STAT_DEPTH")
		_stat(stats, "%d/%d" % [GameState.GIVERS.filter(func(gv: String) -> bool: return Progress.met(gv)).size(), GameState.GIVERS.size()], "MENU_STAT_FRIENDS")
		_stat(stats, str(Progress.kills.values().reduce(func(acc: int, v: Variant) -> int: return acc + int(v), 0)), "MENU_STAT_KILLS")
		_appear(stats, 1.3)

	# Abajo a la derecha: la versión / Bottom right: the version
	var version := UITheme.label("%s %s%s" % [tr("MENU_VERSION"), ProjectSettings.get_setting("application/config/version", "1.0"), " DEMO" if Demo.on() else ""], 16, Color(UITheme.BONE, 0.55), "caps")
	version.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_ui.add_child(version)
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.grow_horizontal = GROW_DIRECTION_BEGIN
	version.grow_vertical = GROW_DIRECTION_BEGIN
	version.offset_right = -44
	version.offset_bottom = -30
	_appear(version, 1.3)


## Pijama con el que sueña: el de la partida guardada, si no el de la última, si no el bate
## The pajama he dreams in: the saved run's, else the last run's, else the bat
func _outfit() -> String:
	if GameState.has_saved_run():
		return String(GameState.saved_run_info().get("weapon", "bat"))
	return String(Progress.stats.get("last_run", {}).get("weapon", "bat"))


func _act_name(act: int) -> String:
	return tr("MENU_ACT_%d" % act)


func _on_act_changed(act: int) -> void:
	var tw := _caption.create_tween()
	tw.tween_property(_caption, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _caption.text = _act_name(act))
	tw.tween_property(_caption, "modulate:a", 1.0, 0.8)


func _veil(from: float, to: float, a: Color, b: Color) -> void:
	var veil := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	veil.texture = gt
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.anchor_right = 1.0
	veil.anchor_top = from
	veil.anchor_bottom = to


## Botón grande, a lo ancho del panel, con su icono / A big button, across the panel, with its icon
func _big(parent: Container, key: String, icon: String, callback: Callable, quiet := false) -> Button:
	var b := Button.new()
	b.text = key
	b.icon = Sprites.tex(icon)
	b.add_theme_constant_override("icon_max_width", 48)
	b.add_theme_constant_override("h_separation", 18)
	b.add_theme_font_override("font", UITheme.font("display"))
	b.add_theme_font_size_override("font_size", UITheme.pixel_size(30 if quiet else 38))
	b.custom_minimum_size = Vector2(0, 58 if quiet else 72)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if quiet:
		b.add_theme_color_override("font_color", Color(UITheme.ASH, 0.9))
	b.pressed.connect(callback)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(_focus_pop.bind(b))
	parent.add_child(b)
	return b


## Botón cuadrado con el icono encima y el nombre debajo; "badge" en dorado, pequeño
## A square button with the icon above and the name below; "badge" small, in gold
func _tile(parent: Container, key: String, icon: String, callback: Callable, badge := "") -> Button:
	var b := Button.new()
	b.text = key
	b.icon = Sprites.tex(icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_override("font", UITheme.font("caps"))
	b.add_theme_font_size_override("font_size", UITheme.pixel_size(15))
	b.add_theme_color_override("font_color", Color(UITheme.ASH, 0.9))
	b.custom_minimum_size = Vector2(120, 94)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(_focus_pop.bind(b))
	parent.add_child(b)
	if badge != "":
		var tag := UITheme.label(badge, 14, UITheme.GOLD, "caps")
		tag.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		tag.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(tag)
		tag.anchor_left = 1.0
		tag.anchor_right = 1.0
		tag.grow_horizontal = GROW_DIRECTION_BEGIN
		tag.offset_right = -8
		tag.offset_top = 4
	return b


## Al enfocar, el botón da un saltito / On focus, the button does a little hop
func _focus_pop(b: Button) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.scale = Vector2(0.96, 0.96)
	tw.tween_property(b, "scale", Vector2.ONE, 0.22)
	Audio.play("ui_hover", -22.0, 0.1)


## Un dato del rincón: el número grande y dorado, el nombre debajo
## A corner figure: the big gold number, its name underneath
func _stat(parent: Container, value: String, key: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	parent.add_child(v)
	var n := UITheme.label(value, 30, UITheme.GOLD, "display")
	n.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(n)
	var l := UITheme.label(key, 13, Color(UITheme.ASH, 0.85), "caps")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(l)


## Botón pequeño y discreto (para lo que no se usa a menudo) / A small, discreet button (for rarely used things)
func _small(parent: Container, key: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.flat = true
	b.focus_mode = FOCUS_ALL
	b.add_theme_font_override("font", UITheme.font("caps"))
	b.add_theme_font_size_override("font_size", UITheme.pixel_size(15))
	b.add_theme_color_override("font_color", Color(UITheme.ASH, 0.5))
	b.add_theme_color_override("font_hover_color", UITheme.BONE)
	b.add_theme_color_override("font_focus_color", UITheme.GOLD)
	b.add_theme_color_override("font_pressed_color", UITheme.GOLD)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(callback)
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b


## Aparece con un fundido (y, si "rise", subiendo un poco) / Fades in (and, with "rise", sliding up a little)
func _appear(node: Control, at: float, rise := 0.0) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_interval(at)
	tw.tween_property(node, "modulate:a", 1.0, 0.5)
	if rise > 0.0:
		var to := node.offset_bottom
		node.offset_bottom = to + rise
		node.offset_top += rise
		var tw2 := node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw2.tween_interval(at)
		tw2.tween_property(node, "offset_bottom", to, 0.6)
		tw2.parallel().tween_property(node, "offset_top", node.offset_top - rise, 0.6)


func _process(delta: float) -> void:
	# Paralaje suave con el ratón / Gentle parallax with the mouse
	var target := Vector2.ZERO
	if size.x > 0.0:
		target = ((get_local_mouse_position() / size) - Vector2(0.5, 0.5)) * 2.0
		target = target.clamp(Vector2(-1, -1), Vector2(1, 1))
	_par = _par.lerp(target, minf(1.0, delta * 2.0))
	if is_instance_valid(_fall):
		_fall.parallax = _par


## Borrar partida: hay que pulsarlo tres veces (aviso, confirmación y borrado). Borra el progreso
## (amistades, logros, bestiario, actos superados) y la partida a medias; los ajustes se quedan.
## Delete save: it has to be pressed three times (warning, confirmation and delete). Deletes progress
## (friendships, achievements, bestiary, acts cleared) and any run in progress; settings stay.
func _on_reset() -> void:
	_reset_step += 1
	Audio.play("ui_click", -6.0)
	if _reset_step == 1:
		_reset.text = "MENU_RESET_SURE"
		return
	if _reset_step == 2:
		_reset.text = "MENU_RESET_LAST"
		return
	Progress.reset_all()
	GameState.clear_saved_run()
	Audio.play("chime", -2.0)
	get_tree().reload_current_scene()


## Desbloquear todo: hay que pulsarlo dos veces para que no se haga sin querer
## Unlock everything: it has to be pressed twice so it isn't done by accident
func _on_unlock_all() -> void:
	if not _unlock_armed:
		_unlock_armed = true
		_unlock.text = "MENU_UNLOCK_CONFIRM"
		Audio.play("ui_click", -6.0)
		return
	Progress.unlock_everything()
	_unlock.text = "MENU_UNLOCK_DONE"
	_unlock.disabled = true
	Audio.play("chime", -2.0)


func _on_play() -> void:
	_dive(HUB)


func _on_continue() -> void:
	if not GameState.load_run():
		return
	_dive("res://scenes/run.tscn")


func _on_achievements() -> void:
	var a := ACHIEVEMENTS_SCENE.new()
	add_child(a)
	a.closed.connect(func() -> void: _achievements.grab_focus())


func _on_credits() -> void:
	var c := CreditsRoll.make()
	add_child(c)
	c.closed.connect(func() -> void:
		Audio.play_music("music_menu", 1.2)
		_credits.grab_focus())


func _on_settings() -> void:
	var menu := SETTINGS_SCENE.instantiate()
	add_child(menu)
	menu.closed.connect(func() -> void: _settings.grab_focus())


## Al empezar, Kroker se hunde en el sueño: todo pasa a toda velocidad y acaba en un fogonazo
## On starting, Kroker sinks into the dream: everything rushes past and ends in a flash
func _dive(scene: String) -> void:
	set_process_input(false)
	mouse_filter = MOUSE_FILTER_STOP
	_ui.mouse_filter = MOUSE_FILTER_STOP
	Audio.play("astral", -8.0)
	create_tween().tween_property(_ui, "modulate:a", 0.0, 0.3)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_fall, "dive", 1.0, 1.0)
	tw.tween_callback(GameState.change_scene.bind(scene))


## Salir cierra el juego tras un fundido corto. / Quit closes the game after a short fade.
func _on_quit() -> void:
	if _quitting:
		return
	_quitting = true
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.BLACK, 0.4)
	tw.tween_callback(Audio.quit_game)
