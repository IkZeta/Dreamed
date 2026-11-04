class_name NoirIntro
extends CanvasLayer
## Lo que se ve por encima del juego en la cinemática del último sueño: franjas negras de cine,
## los pensamientos de Kroker en recuadros de papel como en un cómic negro (salen letra a letra),
## y el cartel del jefe final.
## What shows over the game in the last dream's cutscene: black cinema bars, Kroker's thoughts in
## paper captions like in a noir comic (typed letter by letter), and the final boss's title card.

signal line_done
signal finished

const BAR_H := 130.0
const TYPE_SPEED := 38.0
const PAPER := Color("e6dcc4")
const INK := Color("16141a")

var _top: ColorRect
var _bottom: ColorRect
var _box: PanelContainer
var _text: RichTextLabel
var _hint: Label
var _lines: Array[String] = []
var _i := -1
var _type_t := 0.0
var _typing := false
var _wait := 0.0
var _skipped := false


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_top = ColorRect.new()
	_top.color = Color.BLACK
	add_child(_top)
	_bottom = ColorRect.new()
	_bottom.color = Color.BLACK
	add_child(_bottom)
	for r in [_top, _bottom]:
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = Vector2(1920, 0)
	_bottom.position.y = 1080
	_box = PanelContainer.new()
	var st := UITheme.box(PAPER, INK, 4, 2, 22.0)
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_size = 0
	st.shadow_offset = Vector2(8, 8)
	_box.add_theme_stylebox_override("panel", st)
	_box.custom_minimum_size = Vector2(760, 0)
	_box.visible = false
	add_child(_box)
	_text = Keywords.label("", 28, INK, "italic")
	_text.custom_minimum_size.x = 716
	_box.add_child(_text)
	_hint = UITheme.label("", 15, Color(UITheme.BONE, 0.7), "caps")
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.text = Settings.controls_text(tr("NOIR_HINT"))
	_hint.position = Vector2(1460, 1080 - BAR_H + 50)
	_hint.modulate.a = 0.0
	add_child(_hint)


## Entran (o salen) las franjas de cine / The cinema bars slide in (or out)
func bars(show: bool, secs := 0.8) -> void:
	var tw := create_tween().set_parallel()
	var h := BAR_H if show else 0.0
	tw.tween_property(_top, "size:y", h, secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bottom, "size:y", h, secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bottom, "position:y", 1080.0 - h, secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_hint, "modulate:a", 1.0 if show else 0.0, secs)


## Muestra los pensamientos uno tras otro; "finished" al acabar / Shows the thoughts one after another; "finished" at the end
func monologue(keys: Array[String]) -> void:
	_lines = keys
	_i = -1
	_next()


func _next() -> void:
	_i += 1
	if _i >= _lines.size() or _skipped:
		var tw := create_tween()
		tw.tween_property(_box, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			_box.visible = false
			finished.emit())
		return
	Keywords.set_text(_text, tr(_lines[_i]))
	_text.visible_characters = 0
	_type_t = 0.0
	_typing = true
	_box.visible = true
	_box.reset_size()
	# Los recuadros van cambiando de sitio, como en las viñetas / The captions move around, like in comic panels
	var spots := [Vector2(90, BAR_H + 40), Vector2(1920 - 760 - 90, BAR_H + 60), Vector2(130, 1080 - BAR_H - 260)]
	_box.position = spots[_i % spots.size()]
	_box.modulate.a = 0.0
	_box.rotation = [-0.015, 0.012, -0.008][_i % 3]
	create_tween().tween_property(_box, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	if _typing:
		_type_t += delta
		var total := _text.get_total_character_count()
		var n := mini(total, int(_type_t * TYPE_SPEED))
		if n != _text.visible_characters:
			if n % 2 == 0:
				Audio.play("ui_click", -30.0, 0.25)
			_text.visible_characters = n
		if n >= total:
			_finish_line()
	elif _box.visible and _i >= 0 and _i < _lines.size():
		# Pasa sola si no tocas nada / Moves on by itself if you don't press anything
		_wait -= delta
		if _wait <= 0.0:
			_next()


func _finish_line() -> void:
	_typing = false
	_text.visible_characters = -1
	_wait = 1.8 + _text.get_total_character_count() * 0.035


func _unhandled_input(event: InputEvent) -> void:
	if not _box.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skipped = true
		_typing = false
		_next()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		if _typing:
			_finish_line()
		else:
			_next()


## El cartel del jefe: nombre enorme en rojo y una frase / The boss card: a huge red name and a line
func title_card(name_key: String, sub_key: String) -> void:
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 6)
	add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var title := UITheme.label(name_key, 120, Color("e0303a"), "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color("16020a"))
	holder.add_child(title)
	var sub := UITheme.label(sub_key, 30, UITheme.BONE, "italic")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(sub)
	holder.reset_size()
	holder.position = Vector2(960 - holder.size.x / 2.0, 1080 - BAR_H - 40 - holder.size.y)
	holder.modulate.a = 0.0
	holder.scale = Vector2(1.3, 1.3)
	holder.pivot_offset = holder.size / 2.0
	var tw := create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(holder, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(holder, "modulate:a", 0.0, 0.5)
	tw.tween_callback(holder.queue_free)
