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
var _special: Label
var _depth := 1


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
	_refresh_texts()


func start(depth: int) -> void:
	_depth = depth
	var keys := ["RUN_WAVE1_INTRO", "RUN_INTRO_2", "RUN_INTRO_3"]
	_intro_sub.text = keys[depth - 1] if depth <= keys.size() else "RUN_INTRO_DEEP"
	_refresh_texts()
	_intro.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6)
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
		_special.position = Vector2(56, 130)
	_special.text = "RUN_SPECIAL_THROW" if throwing else "RUN_SPECIAL_DEFEND"


func set_hp(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_text.text = "%d / %d" % [ceili(hp), roundi(max_hp)]


func set_time(seconds: float) -> void:
	var s := ceili(maxf(0.0, seconds))
	_timer.text = "%d:%02d" % [s / 60, s % 60]
	_timer.add_theme_color_override("font_color", UITheme.GOLD if s <= 5 else UITheme.BONE)


func _refresh_texts() -> void:
	_dream.text = tr("RUN_DREAM") % _depth
	_intro_title.text = tr("RUN_DREAM") % _depth


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _dream != null:
		_refresh_texts()
