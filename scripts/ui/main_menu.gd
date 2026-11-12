extends Control
## Menú principal: Jugar, Ajustes y Salir. / Main menu: Play, Settings and Quit.

const SETTINGS_SCENE := preload("res://scenes/settings_menu.tscn")
## Jugar lleva al plano astral: allí se elige pijama y se empieza a soñar en la fuente
## Play takes you to the astral plane: there you pick a pajama and start dreaming at the fountain
const HUB := "res://scenes/astral_hub.tscn"

const ACHIEVEMENTS_SCENE := preload("res://scripts/ui/achievements.gd")

var _play: Button
var _settings: Button
var _unlock: Button
var _unlock_armed := false
var _reset: Button
var _reset_step := 0
var _achievements: Button
var _credits: Button
var _quitting := false
var _bg: Control
var _dream: MenuDream
var _par := Vector2.ZERO


func _ready() -> void:
	theme = UITheme.build()
	Audio.play_music("music_menu")
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	_play.grab_focus()



func _build() -> void:
	var bg := DreamBackground.new()
	bg.halo = Vector2(0.86, 0.17)
	_bg = PixelView.wrap(bg, 2)
	add_child(_bg)
	_bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# La cama voladora de Kroker con sus conocidos en órbita / Kroker's flying bed with his acquaintances in orbit
	_dream = MenuDream.new()
	var dream_px := PixelView.wrap(_dream, 2)
	add_child(dream_px)
	dream_px.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Velo oscuro a la izquierda para que el menú se lea bien sobre las estrellas
	# A dark veil on the left so the menu reads well over the stars
	var veil := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(UITheme.INK, 0.72))
	g.set_color(1, Color(UITheme.INK, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	veil.texture = gt
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.anchor_right = 0.55
	veil.anchor_bottom = 1.0

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 150)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 120)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)

	col.add_child(DreamTitle.new())
	var tagline := UITheme.label("MENU_TAGLINE", 20, Color(UITheme.ASH, 0.85), "caps")
	col.add_child(tagline)
	_appear(tagline, 0.9)
	var gap := Control.new()
	gap.custom_minimum_size.y = 22
	col.add_child(gap)
	var rule := UITheme.rule(Color(UITheme.GOLD, 0.6), 90)
	rule.size_flags_horizontal = SIZE_SHRINK_BEGIN
	col.add_child(rule)
	_appear(rule, 1.0)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 22
	col.add_child(gap2)

	# Continuar la partida guardada, con dónde se quedó / Continue the saved run, with where it was left
	var delay := 1.1
	if GameState.has_saved_run():
		var info := GameState.saved_run_info()
		var depth := int(info.get("depth", 1))
		var cont := _entry(col, "", _on_continue, delay)
		cont.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		cont.text = tr("MENU_CONTINUE") % depth
		var sub := UITheme.label("%s  ·  %s" % [tr("MENU_ACT_%d" % GameState.act_of(depth)), tr("CHAR_%s_NAME" % String(info.get("weapon", "bat")).to_upper())], 17, Color(UITheme.MIST, 0.9), "caps")
		sub.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		var sub_box := MarginContainer.new()
		sub_box.add_theme_constant_override("margin_bottom", 10)
		sub_box.add_child(sub)
		col.add_child(sub_box)
		_appear(sub_box, delay + 0.05)
		_play = cont
		delay += 0.07
		_entry(col, "MENU_PLAY", _on_play, delay)
	else:
		_play = _entry(col, "MENU_PLAY", _on_play, delay)
	_achievements = _entry(col, "MENU_ACHIEVEMENTS", _on_achievements, delay + 0.07,
		"%d/%d" % [Progress.achieved.size(), Progress.ACHIEVEMENTS.size()])
	_credits = _entry(col, "MENU_CREDITS", _on_credits, delay + 0.14)
	_settings = _entry(col, "MENU_SETTINGS", _on_settings, delay + 0.21)
	_entry(col, "MENU_QUIT", _on_quit, delay + 0.28)

	# Abajo a la izquierda, discretas: desbloquear todo (también en la demo) y borrar el guardado
	# Bottom left, discreet: unlock everything (in the demo too) and delete the save
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 34)
	add_child(tools)
	tools.anchor_top = 1.0
	tools.anchor_bottom = 1.0
	tools.offset_top = -84
	tools.offset_left = 150
	_unlock = _small(tools, "MENU_UNLOCK_ALL", _on_unlock_all)
	_reset = _small(tools, "MENU_RESET", _on_reset)
	_appear(tools, delay + 0.45)

	# Abajo a la derecha: cómo va el sueño de Kroker y la versión / Bottom right: how Kroker's dream is going, and the version
	var corner := VBoxContainer.new()
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.add_theme_constant_override("separation", 10)
	add_child(corner)
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.anchor_top = 1.0
	corner.anchor_bottom = 1.0
	corner.grow_horizontal = GROW_DIRECTION_BEGIN
	corner.grow_vertical = GROW_DIRECTION_BEGIN
	corner.offset_right = -60
	corner.offset_bottom = -40
	var best := int(Progress.stats.get("best_depth", 0))
	if best > 0:
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 40)
		stats.alignment = BoxContainer.ALIGNMENT_END
		corner.add_child(stats)
		_stat(stats, str(best), "MENU_STAT_DEPTH")
		_stat(stats, "%d/%d" % [GameState.GIVERS.filter(func(gv: String) -> bool: return Progress.met(gv)).size(), GameState.GIVERS.size()], "MENU_STAT_FRIENDS")
		_stat(stats, str(Progress.kills.values().reduce(func(acc: int, v: Variant) -> int: return acc + int(v), 0)), "MENU_STAT_KILLS")
	var version := UITheme.label("%s %s%s" % [tr("MENU_VERSION"), ProjectSettings.get_setting("application/config/version", "1.0"), " DEMO" if Demo.on() else ""], 18, Color(UITheme.BONE, 0.6), "caps")
	version.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(version)
	_appear(corner, delay + 0.5)


## Un dato del rincón: el número grande y dorado, el nombre debajo
## A corner figure: the big gold number, its name underneath
func _stat(parent: Container, value: String, key: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	parent.add_child(v)
	var n := UITheme.label(value, 34, UITheme.GOLD, "display")
	n.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(n)
	var l := UITheme.label(key, 14, Color(UITheme.ASH, 0.8), "caps")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(l)


## Botón pequeño y discreto (para lo que no se usa a menudo) / A small, discreet button (for rarely used things)
func _small(parent: Container, key: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.flat = true
	b.focus_mode = FOCUS_ALL
	b.add_theme_font_override("font", UITheme.font("caps"))
	b.add_theme_font_size_override("font_size", UITheme.pixel_size(17))
	b.add_theme_color_override("font_color", Color(UITheme.ASH, 0.55))
	b.add_theme_color_override("font_hover_color", UITheme.BONE)
	b.add_theme_color_override("font_focus_color", UITheme.GOLD)
	b.add_theme_color_override("font_pressed_color", UITheme.GOLD)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(callback)
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b


## Aparece con un fundido y un leve desliz desde la izquierda / Fades in with a slight slide from the left
func _appear(node: CanvasItem, at: float) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_interval(at)
	tw.tween_property(node, "modulate:a", 1.0, 0.45)


func _process(delta: float) -> void:
	# Paralaje suave con el ratón / Gentle parallax with the mouse
	var target := Vector2.ZERO
	if size.x > 0.0:
		target = ((get_local_mouse_position() / size) - Vector2(0.5, 0.5)) * 2.0
		target = target.clamp(Vector2(-1, -1), Vector2(1, 1))
	_par = _par.lerp(target, minf(1.0, delta * 2.0))
	if is_instance_valid(_dream):
		_dream.parallax = _par
	if is_instance_valid(_bg):
		_bg.position = -_par * Vector2(8.0, 5.0)


## Entrada de menú: una línea dorada crece a su izquierda al enfocarla; "badge" va a su derecha en pequeño.
## Menu entry: a gold line grows to its left when focused; "badge" goes small on its right.
func _entry(parent: Container, key: String, callback: Callable, at := 0.0, badge := "") -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	var line := ColorRect.new()
	line.color = UITheme.GOLD
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(line)
	var b := Button.new()
	b.theme_type_variation = "MenuEntry"
	b.text = key
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 62)
	b.pressed.connect(callback)
	row.add_child(b)
	if badge != "":
		var tag := UITheme.label(badge, 18, Color(UITheme.GOLD, 0.75), "caps")
		tag.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		tag.size_flags_vertical = SIZE_SHRINK_CENTER
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 18)
		pad.add_theme_constant_override("margin_top", 8)
		pad.add_child(tag)
		row.add_child(pad)
	_appear(row, at)

	var show_line := func(on: bool) -> void:
		var tw := line.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(line, "custom_minimum_size:x", 48.0 if on else 0.0, 0.25)
		row.add_theme_constant_override("separation", 22 if on else 0)
	b.focus_entered.connect(show_line.bind(true))
	b.focus_exited.connect(show_line.bind(false))
	b.mouse_entered.connect(b.grab_focus)
	return b


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
	_dive()
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(GameState.change_scene.bind(HUB))


func _on_continue() -> void:
	if not GameState.load_run():
		return
	_dive()
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(GameState.change_scene.bind("res://scenes/run.tscn"))




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


## Al empezar, la cama se acerca: Kroker se zambulle en el sueño
## On starting, the bed comes closer: Kroker dives into the dream
func _dive() -> void:
	set_process_input(false)
	mouse_filter = MOUSE_FILTER_STOP
	Audio.play("astral", -8.0)
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).tween_property(_dream, "dive", 1.0, 0.65)


## Salir cierra el juego tras un fundido corto. / Quit closes the game after a short fade.
func _on_quit() -> void:
	if _quitting:
		return
	_quitting = true
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.BLACK, 0.4)
	tw.tween_callback(Audio.quit_game)
