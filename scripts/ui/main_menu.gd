extends Control
## Menú principal: Jugar, Ajustes y Salir. / Main menu: Play, Settings and Quit.

const SETTINGS_SCENE := preload("res://scenes/settings_menu.tscn")
const CHARACTER_SELECT := "res://scenes/character_select.tscn"

const BESTIARY_SCENE := preload("res://scripts/ui/bestiary.gd")
const ACHIEVEMENTS_SCENE := preload("res://scripts/ui/achievements.gd")
const CHARACTERS_SCENE := preload("res://scripts/ui/characters_menu.gd")

var _play: Button
var _settings: Button
var _bestiary: Button
var _unlock: Button
var _unlock_armed := false
var _achievements: Button
var _characters: Button
var _quitting := false


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
	var bg_px := PixelView.wrap(bg, 2)
	add_child(bg_px)
	bg_px.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Kroker, de pie bajo el halo / Kroker, standing under the halo
	var kroker := PixelView.wrap(DreamerPortrait.new(), 6)
	add_child(kroker)
	kroker.anchor_left = 0.62
	kroker.anchor_right = 0.84
	kroker.anchor_top = 0.42
	kroker.anchor_bottom = 0.93

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 180)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 90)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var title := UITheme.label("DREAMED", 150, UITheme.BONE, "display")
	title.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(title)

	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	col.add_child(gap)
	var rule := UITheme.rule(Color(UITheme.GOLD, 0.6), 90)
	rule.size_flags_horizontal = SIZE_SHRINK_BEGIN
	col.add_child(rule)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 34
	col.add_child(gap2)

	# Continuar la partida guardada / Continue the saved run
	if GameState.has_saved_run():
		var info := GameState.saved_run_info()
		var cont := _entry(col, "", _on_continue)
		cont.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		cont.text = tr("MENU_CONTINUE") % int(info.get("depth", 1))
		_play = cont
		_entry(col, "MENU_PLAY", _on_play)
	else:
		_play = _entry(col, "MENU_PLAY", _on_play)
	_characters = _entry(col, "MENU_CHARACTERS", _on_characters)
	_bestiary = _entry(col, "MENU_BESTIARY", _on_bestiary)
	_achievements = _entry(col, "MENU_ACHIEVEMENTS", _on_achievements)
	_settings = _entry(col, "MENU_SETTINGS", _on_settings)
	# Solo para pruebas: la demo no lo lleva / Testing only: not in the demo
	if not Demo.on():
		_unlock = _entry(col, "MENU_UNLOCK_ALL", _on_unlock_all)
	_entry(col, "MENU_QUIT", _on_quit)

	var version := UITheme.label("V 1.4" + (" DEMO" if Demo.on() else ""), 16, Color(UITheme.ASH, 0.6), "caps")
	version.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	add_child(version)
	version.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT, PRESET_MODE_MINSIZE, 40)
	version.position.x = 180


## Entrada de menú: una línea dorada crece a su izquierda al enfocarla.
## Menu entry: a gold line grows to its left when focused.
func _entry(parent: Container, key: String, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	var line := ColorRect.new()
	line.color = UITheme.GOLD
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(line)
	var b := Button.new()
	b.theme_type_variation = "MenuEntry"
	b.text = key
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 64)
	b.pressed.connect(callback)
	row.add_child(b)

	var show_line := func(on: bool) -> void:
		var tw := line.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(line, "custom_minimum_size:x", 48.0 if on else 0.0, 0.25)
		row.add_theme_constant_override("separation", 22 if on else 0)
	b.focus_entered.connect(show_line.bind(true))
	b.focus_exited.connect(show_line.bind(false))
	b.mouse_entered.connect(b.grab_focus)
	return b


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
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(GameState.change_scene.bind(CHARACTER_SELECT))


func _on_continue() -> void:
	if not GameState.load_run():
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(GameState.change_scene.bind("res://scenes/run.tscn"))


func _on_characters() -> void:
	var c := CHARACTERS_SCENE.new()
	add_child(c)
	c.closed.connect(func() -> void: _characters.grab_focus())


func _on_bestiary() -> void:
	var b := BESTIARY_SCENE.new()
	add_child(b)
	b.closed.connect(func() -> void: _bestiary.grab_focus())


func _on_achievements() -> void:
	var a := ACHIEVEMENTS_SCENE.new()
	add_child(a)
	a.closed.connect(func() -> void: _achievements.grab_focus())


func _on_settings() -> void:
	var menu := SETTINGS_SCENE.instantiate()
	add_child(menu)
	menu.closed.connect(func() -> void: _settings.grab_focus())


## Salir cierra el juego tras un fundido corto. / Quit closes the game after a short fade.
func _on_quit() -> void:
	if _quitting:
		return
	_quitting = true
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.BLACK, 0.4)
	tw.tween_callback(Audio.quit_game)
