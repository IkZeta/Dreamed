class_name CharoDialogue
extends CanvasLayer
## Cuadro de diálogo de la Kioskera Charo: su retrato en pixel art, su nombre y el texto que
## va saliendo letra a letra. Se avanza con clic, Intro, Espacio o el botón A del mando.
## Kiosk lady Charo's dialogue box: her pixel-art portrait, her name and the text typing out
## letter by letter. Advance with a click, Enter, Space or the gamepad A button.

signal finished

## Velocidad de escritura en letras por segundo / Typing speed in letters per second
const CPS := 48.0

var _lines: Array[String] = []
var _index := -1
var _text: RichTextLabel
var _prompt: Label
var _box: PanelContainer
var _t := 0.0
var _closing := false


## Empieza con una lista de claves de traducción / Starts with a list of translation keys
func build(keys: Array[String]) -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in keys:
		_lines.append(k)
	var root := Control.new()
	root.theme = UITheme.build()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.95), Color("4fa89a", 0.9), Color("4fa89a", 0.2), 18, 14, 24))
	root.add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_bottom = -48
	_box.custom_minimum_size = Vector2(1500, 220)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_box.add_child(row)
	var portrait := PixelView.wrap(CharoPortrait.new(), 3)
	portrait.custom_minimum_size = Vector2(190, 200)
	row.add_child(portrait)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	row.add_child(v)
	v.add_child(UITheme.label("CHARO_NAME", 36, Color("7fe0d0"), "display"))
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.add_theme_font_override("normal_font", UITheme.font("italic"))
	_text.add_theme_font_size_override("normal_font_size", UITheme.pixel_size(36))
	_text.add_theme_color_override("default_color", UITheme.BONE)
	_text.add_theme_constant_override("line_separation", 6)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_prompt = UITheme.label("DIALOGUE_NEXT", 14, Color(UITheme.ASH, 0.8), "caps")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_prompt)

	_box.modulate.a = 0.0
	create_tween().tween_property(_box, "modulate:a", 1.0, 0.25)
	_next()


## Resalta "Realidad Fragmentada" en su color / Highlights "Fragmented Reality" in its colour
static func highlight(text: String) -> String:
	var hex := RealityIcon.COLOR.to_html(false)
	for word: String in ["Realidad Fragmentada", "Fragmented Reality"]:
		text = text.replace(word, "[color=#%s]%s[/color]" % [hex, word])
	return text


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
		return
	_text.text = highlight(tr(_lines[_index]))
	_text.visible_ratio = 0.0
	_t = 0.0
	Audio.play("ui_hover", -10.0, 0.05)


func _process(delta: float) -> void:
	if _closing or _index < 0 or _index >= _lines.size():
		return
	var total := maxi(1, _text.get_total_character_count())
	_t += delta
	_text.visible_ratio = minf(1.0, _t * CPS / total)
	# Un "bip" suave de vez en cuando mientras habla / A soft blip now and then while she talks
	if _text.visible_ratio < 1.0 and int(_t * 12.0) != int((_t - delta) * 12.0):
		Audio.play("ui_hover", -22.0, 0.15)
	_prompt.modulate.a = (0.5 + 0.5 * sin(_t * 5.0)) if _text.visible_ratio >= 1.0 else 0.0


func _input(event: InputEvent) -> void:
	if _closing:
		return
	var press: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not press:
		return
	get_viewport().set_input_as_handled()
	if _text.visible_ratio < 1.0:
		_t = 1000.0
		_text.visible_ratio = 1.0
	else:
		_next()


func _close() -> void:
	_closing = true
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())


## Charo de medio cuerpo para el cuadro de diálogo y el kiosco / Charo from the waist up for the dialogue and the kiosk
class CharoPortrait extends Control:
	var with_kiosk := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if with_kiosk:
			# Charo de cuerpo entero detrás del carrito / Full-body Charo behind her cart
			var s := minf(size.x / 400.0, size.y / 300.0)
			var o := Vector2(size.x / 2.0 - 210.0 * s, size.y - 296.0 * s)
			draw_texture_rect(DreamBackground.soft_texture(), Rect2(o + Vector2(0, 20) * s, Vector2(420, 280) * s), false, Color("4fa89a", 0.18))
			NpcArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, o), "charo", _t)
			draw_set_transform(o, 0.0, Vector2(s, s))
			Sprites.draw(self, "npc_kiosk")
			draw_set_transform(Vector2.ZERO)
		else:
			# Recortada a la altura del pecho / Cropped at chest height
			var s := size.x / 150.0
			var o := Vector2(size.x / 2.0 - 100.0 * s, -30.0 * s)
			draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2.ZERO, size), false, Color("4fa89a", 0.22))
			NpcArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, o), "charo", _t)
