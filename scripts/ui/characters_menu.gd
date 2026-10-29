extends Control
## Menú de personajes: Kroker (con sus cuatro pijamas), los personajes del plano astral,
## Mr. Ad y la Kioskera Charo. Cada uno se desbloquea al conocerlo en una partida.
## Characters menu: Kroker (with his four pajamas), the astral plane characters, Mr. Ad
## and Charo the kiosk lady. Each one unlocks when you meet them in a run.

signal closed

const IDS: Array[String] = ["kroker", "svinho", "stolk", "silly", "doc", "ad", "charo"]
const AURA := {"kroker": Color("f6d993"), "svinho": Color("9be38a"), "stolk": Color("ff8f9e"), "silly": Color("5ff2ff"),
	"doc": Color("ffe3a3"), "ad": Color("ffb04a"), "charo": Color("7fe0d0")}

var _list: VBoxContainer
var _preview_holder: Control
var _name: Label
var _role: Label
var _desc: RichTextLabel
var _buttons := {}
var _current := ""
var _first: Button


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.9)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1400, 820)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	panel.add_child(root)
	root.add_child(UITheme.label("CHARS_TITLE", 60, UITheme.BONE, "display"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(row)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size.x = 420
	row.add_child(_list)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(info)
	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 470)
	info.add_child(_preview_holder)
	_name = UITheme.label("", 48, UITheme.GOLD, "display")
	_name.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	info.add_child(_name)
	_role = UITheme.label("", 18, UITheme.ASH, "caps")
	_role.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	info.add_child(_role)
	_desc = RichTextLabel.new()
	_desc.bbcode_enabled = true
	_desc.fit_content = true
	_desc.scroll_active = false
	_desc.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_desc.add_theme_font_override("normal_font", UITheme.font("body"))
	_desc.add_theme_font_size_override("normal_font_size", UITheme.pixel_size(24))
	_desc.add_theme_color_override("default_color", UITheme.BONE)
	_desc.add_theme_constant_override("line_separation", 6)
	info.add_child(_desc)

	for id in IDS:
		var b := Button.new()
		b.text = _title(id) if met(id) else "???"
		b.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 62)
		b.focus_entered.connect(_show.bind(id))
		b.mouse_entered.connect(b.grab_focus)
		_list.add_child(b)
		_buttons[id] = b
		if _first == null:
			_first = b
	var gap := Control.new()
	gap.size_flags_vertical = SIZE_EXPAND_FILL
	_list.add_child(gap)
	var unlock := Button.new()
	unlock.text = "BESTIARY_UNLOCK_ALL"
	unlock.custom_minimum_size = Vector2(0, 56)
	unlock.pressed.connect(_unlock_all)
	_list.add_child(unlock)
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(0, 64)
	back.pressed.connect(_close)
	_list.add_child(back)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_first.grab_focus.call_deferred()


## ¿Ya lo has conocido? Kroker siempre / Have you met them yet? Kroker always
static func met(id: String) -> bool:
	if id == "kroker":
		return true
	if id == "charo" and Progress.stats.has("charo_met"):
		return true
	if id == "ad" and Progress.has_achieved("mr_ad"):
		return true
	return Progress.stats.has("met_" + id)


func _title(id: String) -> String:
	match id:
		"kroker": return "Kroker"
		"charo": return tr("CHARO_NAME")
	return tr("GIVER_%s_NAME" % id.to_upper())


func _role_key(id: String) -> String:
	match id:
		"kroker": return "CHARS_KROKER_ROLE"
		"charo": return "CHARS_CHARO_ROLE"
	return "GIVER_%s_ROLE" % id.to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _unlock_all() -> void:
	for id in IDS:
		Progress.stats["met_" + id] = 1
	Progress.save_progress()
	Audio.play("chime", -4.0)
	for id: String in _buttons:
		_buttons[id].text = _title(id)
	if _current != "":
		_show(_current)


func _show(id: String) -> void:
	_current = id
	for c in _preview_holder.get_children():
		c.queue_free()
	var known := met(id)
	var prev := CharacterPreview.new()
	prev.id = id
	prev.hidden_shape = not known
	prev.aura = AURA[id]
	var px := PixelView.wrap(prev, 3)
	_preview_holder.add_child(px)
	px.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_name.text = _title(id) if known else "???"
	_name.add_theme_color_override("font_color", AURA[id] if known else UITheme.ASH)
	_role.text = tr(_role_key(id)) if known else ""
	_desc.text = tr("CHARS_%s_BIO" % id.to_upper()) if known else tr("CHARS_UNKNOWN")


func _close() -> void:
	closed.emit()
	queue_free()


## Dibujo animado del personaje; Kroker va cambiando de pijama / Animated drawing of the character; Kroker cycles pajamas
class CharacterPreview extends Control:
	const OUTFITS: Array[String] = ["bat", "shield", "book", "vacuum"]
	var id := "kroker"
	var hidden_shape := false
	var aura := Color.WHITE
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := minf(size.x / 200.0, size.y / 320.0) * 0.95
		var origin := Vector2(size.x / 2.0 - 100.0 * s, size.y - 300.0 * s)
		var c := origin + Vector2(100, 170) * s
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(150, 190) * s, Vector2(300, 380) * s), false, Color(aura, 0.2))
		draw_colored_polygon(_ellipse(origin + Vector2(100, 290) * s, Vector2(60, 12) * s), Color(0, 0, 0, 0.3))
		if hidden_shape:
			modulate = Color(0, 0, 0, 0.75)
		var xf := Transform2D(0.0, Vector2(s, s), 0.0, origin)
		if id == "kroker":
			var outfit := OUTFITS[int(_t / 2.5) % OUTFITS.size()]
			KrokerArt.draw(self, xf, outfit, _t, {"lean": sin(_t * 0.9) * 0.04})
		else:
			NpcArt.draw(self, xf, id, _t)

	func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts
