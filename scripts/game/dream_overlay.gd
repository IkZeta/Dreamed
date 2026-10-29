class_name DreamOverlay
extends CanvasLayer
## Pantalla superpuesta para pausa, victoria y derrota. Funciona con el juego en pausa.
## Overlay screen for pause, win and lose. Works while the game is paused.

signal closed

## Qué hacer al pulsar Esc (opcional) / What Esc does (optional)
var on_cancel: Callable
var _first_button: Button
var _row: HBoxContainer


func _unhandled_input(event: InputEvent) -> void:
	if on_cancel.is_valid() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		on_cancel.call()
var _root: Control


## buttons: Array de [clave_texto, Callable]. extra_lines: textos ya traducidos o claves.
func build(title_key: String, subtitle_key: String, buttons: Array, extra_lines: Array = []) -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UITheme.build()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.86)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 72)
	center.add_child(_row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = 640
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(col)

	var title := UITheme.label(title_key, 88, UITheme.BONE, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	if subtitle_key != "":
		var sub := UITheme.label(subtitle_key, 28, UITheme.ASH, "italic")
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(sub)
	for line: String in extra_lines:
		var l := UITheme.label(line, 15, UITheme.GOLD, "caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)

	var rule_row := CenterContainer.new()
	rule_row.custom_minimum_size.y = 40
	rule_row.add_child(UITheme.rule(Color(UITheme.GOLD, 0.6), 90))
	col.add_child(rule_row)

	for def: Array in buttons:
		var b := Button.new()
		b.text = def[0]
		b.custom_minimum_size = Vector2(420, 64)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(def[1])
		b.mouse_entered.connect(b.grab_focus)
		col.add_child(b)
		if _first_button == null:
			_first_button = b

	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.35)
	_first_button.grab_focus.call_deferred()


## Añade un panel al lado de los botones (el resumen de la pausa) / Adds a panel beside the buttons (the pause summary)
func add_side(panel: Control) -> void:
	_row.add_child(panel)


func refocus() -> void:
	if _first_button:
		_first_button.grab_focus()


func close() -> void:
	closed.emit()
	queue_free()
