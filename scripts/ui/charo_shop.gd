class_name CharoShop
extends CanvasLayer
## El kiosco de Charo: aparece al acabar algunos sueños del Acto 2. Vende tres cosas a cambio
## de Realidad Fragmentada. Funciona con el juego en pausa.
## Charo's kiosk: shows up at the end of some Act 2 dreams. Sells three things in exchange for
## Fragmented Reality. Works while the game is paused.

signal bought(id: String)
signal closed

var _wares: Array[String] = []
var _sold := {}
var _buttons := {}
var _count: Label
var _line: Label
var _leave: Button
var _ready_t := 0.4
var _done := false


func build() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wares = GameState.roll_wares()
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.82)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	# Charo con su carrito y lo que dice / Charo with her cart and what she says
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(top)
	var portrait := CharoDialogue.CharoPortrait.new()
	portrait.with_kiosk = true
	var px := PixelView.wrap(portrait, 3)
	px.custom_minimum_size = Vector2(420, 300)
	top.add_child(px)
	var talk := VBoxContainer.new()
	talk.alignment = BoxContainer.ALIGNMENT_CENTER
	talk.add_theme_constant_override("separation", 8)
	talk.custom_minimum_size.x = 640
	top.add_child(talk)
	talk.add_child(UITheme.label("SHOP_TITLE", 60, UITheme.BONE, "display"))
	_line = UITheme.label("SHOP_HELLO", 24, Color("7fe0d0"), "italic")
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk.add_child(_line)
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 10)
	talk.add_child(wallet)
	var icon := RealityIcon.new()
	icon.custom_minimum_size = Vector2(40, 40)
	wallet.add_child(icon)
	_count = UITheme.label("", 36, RealityIcon.COLOR, "display")
	_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	wallet.add_child(_count)
	wallet.add_child(UITheme.label("REALITY_NAME", 18, UITheme.ASH, "caps"))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	for id in _wares:
		row.add_child(_card(id))

	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	col.add_child(gap)
	_leave = Button.new()
	_leave.text = "SHOP_LEAVE"
	_leave.custom_minimum_size = Vector2(440, 60)
	_leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave.pressed.connect(_close)
	_leave.mouse_entered.connect(_leave.grab_focus)
	col.add_child(_leave)
	_refresh()

	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	Audio.play("giver_charo", -3.0)
	var first: Button = null
	for id in _wares:
		if not _buttons[id].disabled:
			first = _buttons[id]
			break
	(first if first else _leave).grab_focus.call_deferred()


func _card(id: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(340, 330)
	card.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.92), Color("4fa89a", 0.6), Color("4fa89a", 0.12), 16, 18, 22))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var icon := WareIcon.new()
	icon.ware = id
	var icon_px := PixelView.wrap(icon, 4)
	icon_px.custom_minimum_size = Vector2(0, 100)
	v.add_child(icon_px)
	var name_l := UITheme.label("WARE_%s_NAME" % id.to_upper(), 26, UITheme.BONE, "display")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var desc := UITheme.label("WARE_%s_DESC" % id.to_upper(), 18, UITheme.ASH, "italic")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.pressed.connect(_buy.bind(id))
	b.mouse_entered.connect(b.grab_focus)
	v.add_child(b)
	_buttons[id] = b
	return card


func _refresh() -> void:
	_count.text = str(GameState.reality)
	for id in _wares:
		var b: Button = _buttons[id]
		var cost: int = GameState.WARES[id]
		if _sold.has(id):
			b.text = tr("SHOP_SOLD")
			b.disabled = true
		elif GameState.reality < cost:
			b.text = tr("SHOP_SHORT").format({"n": cost - GameState.reality})
			b.disabled = true
		else:
			b.text = tr("SHOP_BUY").format({"cost": cost})
			b.disabled = false


func _process(delta: float) -> void:
	_ready_t -= delta


func _buy(id: String) -> void:
	if _done or _ready_t > 0.0 or _sold.has(id):
		return
	var cost: int = GameState.WARES[id]
	if GameState.reality < cost:
		return
	GameState.add_reality(-cost)
	_sold[id] = true
	GameState.apply_ware(id)
	bought.emit(id)
	Audio.play("reality", -2.0)
	Audio.play("pickup", -6.0)
	_line.text = ["SHOP_THANKS_1", "SHOP_THANKS_2", "SHOP_THANKS_3"][_sold.size() - 1]
	_ready_t = 0.2
	_refresh()
	# El foco pasa a otro botón que siga activo / Focus moves to another button that's still active
	for w in _wares:
		if not _buttons[w].disabled:
			_buttons[w].grab_focus()
			return
	_leave.grab_focus()


func _close() -> void:
	if _done or _ready_t > 0.0:
		return
	_done = true
	closed.emit()
	queue_free()


## Dibujito de cada artículo / Little drawing of each ware
class WareIcon extends Control:
	var ware := "milk"
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, sin(_t * 2.0) * 1.5)
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(26, 22), Vector2(52, 44)), false, Color("4fa89a", 0.3))
		var ink := Color(UITheme.INK)
		match ware:
			"milk":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -10), c + Vector2(7, -10), c + Vector2(6, 10), c + Vector2(-6, 10)]), Color("f2b8d8"))
				draw_rect(Rect2(c + Vector2(-7, -12), Vector2(14, 3)), Color("fbf8ff"))
				draw_line(c + Vector2(3, -12), c + Vector2(7, -19), Color("e85d75"), 2.0)
				draw_rect(Rect2(c + Vector2(-4, -6), Vector2(2, 12)), Color(1, 1, 1, 0.5))
			"candy":
				draw_circle(c, 7.0, Color("f6c86a"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-14, -6), c + Vector2(-14, 6)]), Color("e85d75"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(7, 0), c + Vector2(14, -6), c + Vector2(14, 6)]), Color("e85d75"))
				draw_arc(c, 4.0, 0.0, PI, 8, Color(1, 1, 1, 0.7), 1.5)
			"gum":
				var r := 9.0 + sin(_t * 1.5) * 2.0
				draw_circle(c, r, Color("f2a6c8"))
				draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.7))
				draw_rect(Rect2(c + Vector2(-6, r - 2), Vector2(12, 5)), Color("e3a6c4"))
			"glasses":
				draw_arc(c + Vector2(-7, 0), 6.0, 0, TAU, 16, Color("7a2e4a"), 2.5)
				draw_arc(c + Vector2(7, 0), 6.0, 0, TAU, 16, Color("7a2e4a"), 2.5)
				draw_circle(c + Vector2(-7, 0), 4.5, Color("dfe6ff", 0.5))
				draw_circle(c + Vector2(7, 0), 4.5, Color("dfe6ff", 0.5))
				draw_line(c + Vector2(-1, 0), c + Vector2(1, 0), Color("7a2e4a"), 2.0)
			"newspaper":
				draw_rect(Rect2(c + Vector2(-12, -9), Vector2(24, 18)), Color("f4ecdc"))
				draw_rect(Rect2(c + Vector2(-10, -7), Vector2(20, 3)), ink)
				draw_rect(Rect2(c + Vector2(-10, -2), Vector2(9, 8)), Color("7fb8ff"))
				for k in 3:
					draw_rect(Rect2(c + Vector2(1, -2 + k * 3), Vector2(9, 1)), Color(ink, 0.6))
			"battery":
				draw_rect(Rect2(c + Vector2(-6, -11), Vector2(12, 22)), Color("4fa89a"))
				draw_rect(Rect2(c + Vector2(-3, -14), Vector2(6, 3)), Color("cfc8ec"))
				draw_rect(Rect2(c + Vector2(-6, 1), Vector2(12, 10)), Color("f6d993"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(1, -8), c + Vector2(-3, 0), c + Vector2(0, 0), c + Vector2(-1, 7), c + Vector2(3, -1), c + Vector2(0, -1)]), Color("fbf8ff"))
