class_name SacrificeScreen
extends CanvasLayer
## La chimenea del salón: eliges una de tus mejoras para echarla al fuego. Pierde un nivel
## y ganas Realidad Fragmentada. Funciona con el juego en pausa.
## The living-room fireplace: pick one of your upgrades to throw into the fire. It loses a
## level and you gain Fragmented Reality. Works while the game is paused.

signal chosen(giver: String)
signal cancelled

var _ready_t := 0.4
var _done := false


func build() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color("1a0c1e", 0.8)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 900
	center.add_child(col)

	var title := UITheme.label("SAC_TITLE", 66, Color("ffb06a"), "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UITheme.label(tr("SAC_SUB").format({"n": GameState.REALITY_SACRIFICE}), 24, UITheme.ASH, "italic")
	sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	col.add_child(gap)

	var first: Button = null
	var weapon := GameState.selected_character
	for g in GameState.GIVERS:
		var lvl := GameState.level(g)
		if lvl <= 0:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(900, 72)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.text = tr("SAC_ROW").format({
			"giver": tr("GIVER_%s_NAME" % g.to_upper()),
			"up": tr(GameState.upgrade_key(g, weapon, "NAME")),
			"from": lvl, "to": lvl - 1, "n": GameState.REALITY_SACRIFICE,
		})
		b.pressed.connect(_pick.bind(g))
		b.mouse_entered.connect(b.grab_focus)
		col.add_child(b)
		if first == null:
			first = b
	if first == null:
		var none := UITheme.label("SAC_NONE", 24, UITheme.BONE, "italic")
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(none)
	var cancel := Button.new()
	cancel.text = "SAC_CANCEL"
	cancel.custom_minimum_size = Vector2(380, 58)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_cancel)
	cancel.mouse_entered.connect(cancel.grab_focus)
	col.add_child(cancel)

	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	(first if first else cancel).grab_focus.call_deferred()


func _process(delta: float) -> void:
	_ready_t -= delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


func _pick(giver: String) -> void:
	if _done or _ready_t > 0.0:
		return
	_done = true
	chosen.emit(giver)
	queue_free()


func _cancel() -> void:
	if _done or _ready_t > 0.0:
		return
	_done = true
	cancelled.emit()
	queue_free()
