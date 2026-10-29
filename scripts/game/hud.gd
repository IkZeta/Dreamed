class_name HUD
extends CanvasLayer
## Interfaz de la partida: vida, tiempo del sueño y Foox disipados.
## In-game interface: health, dream timer and Foox dispelled.

var _hp_bar: ProgressBar
var _hp_text: Label
var _dream: Label
var _timer: Label
var _intro: Control
var _intro_title: Label
var _hint: Label
var _intro_sub: Label
var _intro_new: Label
var _boss_bar: ProgressBar
var _boss_name: Label
var _special: Label
var _god: Label
var _event: Label
var _xp_bar: ProgressBar
var _lvl: Label
var _depth := 1
var _reality_row: HBoxContainer
var _reality: Label
var _fire: Label


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.theme = UITheme.build()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Vida (arriba a la izquierda) / Health (top left)
	var hp_box := VBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 8)
	root.add_child(hp_box)
	hp_box.position = Vector2(56, 44)
	var who := UITheme.label("Kroker", 14, UITheme.ASH, "caps")
	who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hp_box.add_child(who)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(320, 6)
	_hp_bar.add_theme_stylebox_override("fill", UITheme.bar(UITheme.EMBER, 3.0))
	_hp_bar.add_theme_stylebox_override("background", UITheme.bar(Color(UITheme.LINE, 0.7), 3.0))
	hp_box.add_child(_hp_bar)
	_hp_text = UITheme.label("", 20, UITheme.BONE, "light")
	_hp_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hp_box.add_child(_hp_text)
	# Nivel y trozos de estrella / Level and star shards
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 12)
	hp_box.add_child(xp_row)
	_lvl = UITheme.label("", 13, UITheme.GOLD, "caps")
	_lvl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_lvl.custom_minimum_size.x = 52
	xp_row.add_child(_lvl)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(256, 4)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.add_theme_stylebox_override("fill", UITheme.bar(UITheme.GOLD, 2.0))
	_xp_bar.add_theme_stylebox_override("background", UITheme.bar(Color(UITheme.LINE, 0.5), 2.0))
	xp_row.add_child(_xp_bar)
	set_xp()
	# Realidad Fragmentada (desde el Acto 2) / Fragmented Reality (from Act 2)
	_reality_row = HBoxContainer.new()
	_reality_row.add_theme_constant_override("separation", 8)
	hp_box.add_child(_reality_row)
	var r_icon := RealityIcon.new()
	r_icon.custom_minimum_size = Vector2(30, 30)
	_reality_row.add_child(r_icon)
	_reality = UITheme.label("", 24, RealityIcon.COLOR, "display")
	_reality.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_reality_row.add_child(_reality)
	set_reality()

	# Aviso del modo Dios (arriba en el centro) / God mode notice (top centre)
	var god_box := VBoxContainer.new()
	god_box.add_theme_constant_override("separation", 2)
	root.add_child(god_box)
	god_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	god_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	god_box.offset_top = 40
	_god = UITheme.label("", 16, UITheme.GOLD, "caps")
	_god.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	god_box.add_child(_god)
	var keys := UITheme.label("GOD_HUD_KEYS", 14, Color(UITheme.ASH, 0.8), "light")
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	god_box.add_child(keys)
	god_box.visible = GameState.god_mode
	set_god()

	# Sueño y tiempo (arriba en el centro) / Dream and timer (top center)
	# Arriba a la derecha, para no tapar la ventana / Top right, clear of the window
	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 0)
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	center.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	center.offset_left = -260
	center.offset_right = -56
	center.offset_top = 36
	_dream = UITheme.label("", 14, UITheme.GOLD, "caps")
	_dream.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_dream.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center.add_child(_dream)
	_timer = UITheme.label("0:30", 54, UITheme.BONE, "display")
	_timer.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center.add_child(_timer)
	# Evento del sueño (apagón, suelo inclinado, Foox dorado) / Dream event
	_event = UITheme.label("", 14, UITheme.ROSE, "caps")
	_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_event.visible = false
	center.add_child(_event)
	_fire = UITheme.label("EVENT_FIRE", 14, Color("ffb06a"), "caps")
	_fire.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fire.visible = false
	center.add_child(_fire)

	# Ayuda de controles / Controls hint
	_hint = UITheme.label("RUN_CONTROLS", 18, Color(UITheme.ASH, 0.9), "light")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y -= 44

	# Presentación del sueño / Dream intro
	_intro = VBoxContainer.new()
	(_intro as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_intro)
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_title = UITheme.label("", 110, UITheme.BONE, "display")
	_intro_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(_intro_title)
	var sub := UITheme.label("RUN_WAVE1_INTRO", 30, UITheme.ASH, "italic")
	_intro_sub = sub
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(sub)
	_intro_new = UITheme.label("", 18, UITheme.GOLD, "caps")
	_intro_new.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(_intro_new)
	_refresh_texts()


func start(depth: int) -> void:
	_depth = depth
	# Solo el título del sueño, sin subtítulos / Only the dream title, no subtitles
	_intro_sub.visible = false
	_intro_new.visible = false
	_timer.visible = not GameState.wave_for(depth).get("boss", false)
	_refresh_texts()
	_intro.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(_intro, "modulate:a", 0.0, 0.9)
	var hint_tw := create_tween()
	hint_tw.tween_interval(7.0)
	hint_tw.tween_property(_hint, "modulate:a", 0.0, 1.5)


## Muestra la tecla del modo especial (almohada de Svinho) / Shows the special-mode key (Svinho's pillow)
func set_special_mode(throwing: bool) -> void:
	if _special == null:
		_special = UITheme.label("", 16, UITheme.GOLD, "caps")
		get_child(0).add_child(_special)
		_special.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_special.position = Vector2(56, 206)
	_special.text = "RUN_SPECIAL_THROW" if throwing else "RUN_SPECIAL_DEFEND"


## Barra de vida del jefe abajo en el centro / Boss health bar, bottom centre
func show_boss(name_key: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	get_child(0).add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -110
	box.offset_bottom = -60
	_boss_name = UITheme.label(name_key, 16, UITheme.EMBER, "caps")
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(720, 10)
	_boss_bar.add_theme_stylebox_override("fill", UITheme.bar(UITheme.EMBER, 5.0))
	_boss_bar.add_theme_stylebox_override("background", UITheme.bar(Color(UITheme.LINE, 0.4), 5.0))
	box.add_child(_boss_bar)
	_hint.visible = false


func hide_boss() -> void:
	if _boss_bar:
		_boss_bar.get_parent().visible = false


func set_boss_part(name_key: String) -> void:
	if _boss_name:
		_boss_name.text = tr("BOSS_NAME") + "  ·  " + tr(name_key)


func set_boss_hp(hp: float, max_hp: float) -> void:
	if _boss_bar:
		_boss_bar.max_value = max_hp
		_boss_bar.value = hp


func set_hp(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_text.text = "%d / %d" % [ceili(hp), roundi(max_hp)]


func show_event(id: String) -> void:
	_event.visible = id != ""
	if id != "":
		_event.text = "EVENT_" + id.to_upper()


## La chimenea del salón está encendida / The living-room fireplace is lit
func show_fire(on: bool) -> void:
	_fire.visible = on


func set_reality() -> void:
	_reality_row.visible = GameState.reality_on()
	var old := _reality.text
	_reality.text = str(GameState.reality)
	if old != "" and old != _reality.text:
		_reality_row.pivot_offset = Vector2(0, 15)
		var tw := create_tween()
		tw.tween_property(_reality_row, "scale", Vector2(1.25, 1.25), 0.08)
		tw.tween_property(_reality_row, "scale", Vector2.ONE, 0.2)


## Rótulo grande en el centro (p. ej. el final de un acto) / Big centred caption (e.g. the end of an act)
func banner(key: String, sub_key := "") -> void:
	_intro_title.text = tr(key)
	_intro_sub.text = sub_key
	_intro_sub.visible = sub_key != ""
	_intro.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.8)
	tw.tween_property(_intro, "modulate:a", 0.0, 0.7)


func set_god() -> void:
	_god.text = "GOD_HUD_INVULN" if GameState.god_invuln else "GOD_HUD_VULN"
	_god.add_theme_color_override("font_color", UITheme.GOLD if GameState.god_invuln else UITheme.EMBER)


func set_xp() -> void:
	_xp_bar.max_value = GameState.xp_needed()
	_xp_bar.value = GameState.xp
	_lvl.text = tr("HUD_LEVEL") % GameState.plevel


func set_time(seconds: float) -> void:
	var s := ceili(maxf(0.0, seconds))
	_timer.text = "%d:%02d" % [s / 60, s % 60]
	_timer.add_theme_color_override("font_color", UITheme.GOLD if s <= 5 else UITheme.BONE)


func _refresh_texts() -> void:
	_dream.text = tr("RUN_DREAM") % _depth
	_intro_title.text = tr("RUN_DREAM") % _depth
	if _lvl:
		_lvl.text = tr("HUD_LEVEL") % GameState.plevel


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _dream != null:
		_refresh_texts()
