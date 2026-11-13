class_name PactPanel
extends CanvasLayer
## Ventana de la fiebre en la fuente: pactos opcionales que ponen el sueño más difícil a cambio
## de más trozos de estrella y Realidad. Se recuerdan entre partidas.
## Fever window at the fountain: optional pacts that make the dream harder in exchange for more
## star shards and Reality. They're remembered between runs.

signal closed

var _temp: Label
var _bonus: Label
var _first: Control


func _ready() -> void:
	layer = 15
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.86)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.97), Color(UITheme.EMBER, 0.7), Color(UITheme.EMBER, 0.14), 18, 26, 34))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = 760
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UITheme.label("PACT_TITLE", 46, UITheme.BONE, "display")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_temp = UITheme.label("", 40, UITheme.EMBER, "display")
	_temp.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	head.add_child(_temp)
	var sub := UITheme.label("PACT_SUB", 18, Color(UITheme.ASH, 0.9), "italic")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	col.add_child(UITheme.rule(Color(UITheme.LINE, 0.6)))

	for id: String in GameState.PACT_ORDER:
		col.add_child(_pact_row(id))

	col.add_child(UITheme.rule(Color(UITheme.LINE, 0.6)))
	_bonus = UITheme.label("", 20, UITheme.GOLD, "body")
	_bonus.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_bonus)
	var done := Button.new()
	done.text = "PACT_DONE"
	done.custom_minimum_size = Vector2(0, 60)
	done.pressed.connect(_close)
	done.mouse_entered.connect(done.grab_focus)
	col.add_child(done)
	_refresh()
	if _first:
		_first.grab_focus.call_deferred()


func _pact_row(id: String) -> Control:
	var b := CheckButton.new()
	b.button_pressed = id in FeverDaily.pact_pick()
	b.custom_minimum_size = Vector2(0, 58)
	b.mouse_entered.connect(b.grab_focus)
	b.toggled.connect(func(_on: bool) -> void:
		FeverDaily.toggle_pact(id)
		Audio.play("ui_click", -8.0)
		_refresh())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -90
	var deg := UITheme.label("+%d°" % int(GameState.PACTS[id]), 24, UITheme.EMBER, "display")
	deg.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	deg.custom_minimum_size.x = 52
	deg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(deg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UITheme.label("PACT_" + id.to_upper(), 22, UITheme.BONE, "caps"))
	v.add_child(UITheme.label("PACT_" + id.to_upper() + "_DESC", 17, Color(UITheme.ASH, 0.9), "body"))
	for c in v.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _first == null:
		_first = b
	return b


func _refresh() -> void:
	var pick := FeverDaily.pact_pick()
	var f := 0
	for id: String in pick:
		f += int(GameState.PACTS.get(id, 0))
	_temp.text = FeverDaily.fever_temp(f)
	var best := Progress.best_fever(GameState.selected_character)
	_bonus.text = tr("PACT_BONUS") % [roundi(GameState.FEVER_SHARDS * 100.0 * f), 5 * f] \
		+ "\n" + tr("PACT_BEST") % [tr("WEAPON_SHORT_" + GameState.selected_character.to_upper()), FeverDaily.fever_temp(best) if best > 0 else "—"]


func _close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
