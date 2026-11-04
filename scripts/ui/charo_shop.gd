class_name CharoShop
extends CanvasLayer
## El kiosco de Charo: aparece al acabar algunos sueños. Vende cosas a cambio de Realidad
## Fragmentada; en cada acto, mejores y más caras. La amistad con Charo da cambios gratis del
## mostrador, ofertas a mitad de precio y más huecos. Funciona con el juego en pausa.
## Charo's kiosk: shows up at the end of some dreams. Sells things in exchange for Fragmented
## Reality; better and pricier with each act. Friendship with Charo gives free counter rerolls,
## half-price offers and more slots. Works while the game is paused.

signal bought(id: String)
signal closed

## Por hueco del mostrador: artículo, si está de oferta y si se ha vendido
## Per counter slot: ware, whether it's on offer and whether it's been sold
var _wares: Array[String] = []
var _offer: Array[bool] = []
var _sold: Array[bool] = []
var _buttons: Array[Button] = []
var _row: HBoxContainer
var _count: Label
var _line: Label
var _perks: Label
var _leave: Button
var _reroll: Button
var _tip: Button
var _hearts: FriendHearts
var _free_rerolls := 0
var _paid_rerolls := 0
var _bought_n := 0

var _ready_t := 0.4
var _done := false


func build() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_free_rerolls = GameState.shop_free_rerolls()
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
	talk.custom_minimum_size.x = 700
	top.add_child(talk)
	talk.add_child(UITheme.label("SHOP_TITLE", 60, UITheme.BONE, "display"))
	# Saluda según la amistad / Greets you according to friendship
	_line = UITheme.label(_hello_key(), 24, Color("7fe0d0"), "italic")
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
	# Amistad con Charo y propina / Friendship with Charo and tip
	var friend := HBoxContainer.new()
	friend.add_theme_constant_override("separation", 14)
	talk.add_child(friend)
	var fl := UITheme.label("FRIENDSHIP", 18, UITheme.ASH, "caps")
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	friend.add_child(fl)
	_hearts = FriendHearts.new(Progress.friend_level("charo"), Color("7fe0d0"), 20.0)
	_hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	friend.add_child(_hearts)
	_tip = Button.new()
	_tip.custom_minimum_size = Vector2(330, 50)
	_tip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tip.pressed.connect(_give_tip)
	_tip.mouse_entered.connect(_tip.grab_focus)
	friend.add_child(_tip)
	# Lo que da ahora la amistad / What friendship gives right now
	_perks = UITheme.label("", 18, Color("7fe0d0", 0.8), "body")
	_perks.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_perks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk.add_child(_perks)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 22)
	col.add_child(_row)
	_stock(GameState.roll_wares(GameState.shop_slots()))

	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	col.add_child(gap)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 24)
	col.add_child(bottom)
	_reroll = Button.new()
	_reroll.custom_minimum_size = Vector2(380, 60)
	_reroll.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_reroll.pressed.connect(_do_reroll)
	_reroll.mouse_entered.connect(_reroll.grab_focus)
	bottom.add_child(_reroll)
	_leave = Button.new()
	_leave.text = "SHOP_LEAVE"
	_leave.custom_minimum_size = Vector2(440, 60)
	_leave.pressed.connect(_close)
	_leave.mouse_entered.connect(_leave.grab_focus)
	bottom.add_child(_leave)
	_refresh()

	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	Audio.leitmotif("charo")
	_focus_first()


## Llena el mostrador (los huecos vendidos se quedan como están) / Fills the counter (sold slots stay as they are)
func _stock(wares: Array[String]) -> void:
	var fresh := wares.duplicate()
	var n := GameState.shop_slots()
	var new_wares: Array[String] = []
	var new_offer: Array[bool] = []
	var new_sold: Array[bool] = []
	for i in n:
		if i < _wares.size() and _sold[i]:
			new_wares.append(_wares[i])
			new_offer.append(_offer[i])
			new_sold.append(true)
		elif not fresh.is_empty():
			new_wares.append(fresh.pop_front())
			new_offer.append(GameState.roll_offer())
			new_sold.append(false)
	_wares = new_wares
	_offer = new_offer
	_sold = new_sold
	for c in _row.get_children():
		c.queue_free()
	_buttons.clear()
	var w := 340.0 if _wares.size() <= 3 else (300.0 if _wares.size() == 4 else 270.0)
	for i in _wares.size():
		_row.add_child(_card(i, w))


func _card(i: int, width: float) -> Control:
	var id := _wares[i]
	var tier: int = GameState.WARES[id]["tier"]
	var edge: Color = [Color("4fa89a"), Color("7fb8ff"), Color("ffd27a"), Color("ff7ad0")][tier - 1]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 340)
	card.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.92), Color(edge, 0.6), Color(edge, 0.12), 16, 18, 22))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	# Oferta: cinta arriba / Offer: ribbon on top
	var tag := UITheme.label("SHOP_OFFER" if _offer[i] else " ", 18, Color("ff8fb1"), "caps")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var icon := WareIcon.new()
	icon.ware = id
	var icon_px := PixelView.wrap(icon, 4)
	icon_px.custom_minimum_size = Vector2(0, 92)
	v.add_child(icon_px)
	var name_l := UITheme.label("WARE_%s_NAME" % id.to_upper(), 24, UITheme.BONE, "display")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var desc := Keywords.label("WARE_%s_DESC" % id.to_upper(), 18, UITheme.ASH, "italic")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b := Button.new()
	Keywords.on_focus(b, desc)
	b.custom_minimum_size = Vector2(0, 58)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.pressed.connect(_buy.bind(i))
	b.mouse_entered.connect(b.grab_focus)
	v.add_child(b)
	_buttons.append(b)
	return card


func _price(i: int) -> int:
	var base := GameState.ware_price(_wares[i])
	return maxi(1, roundi(base * GameState.OFFER_MULT)) if _offer[i] else base


func _hello_key() -> String:
	var lvl := Progress.friend_level("charo")
	return "SHOP_HELLO" if lvl == 0 else "SHOP_HELLO_%d" % lvl


## Propina a Charo (una por partida): sube la amistad / Tip for Charo (one per run): raises friendship
func _give_tip() -> void:
	if _done or _ready_t > 0.0 or GameState.tipped.has("charo") or not Progress.can_tip("charo"):
		return
	var cost := Progress.tip_cost("charo")
	if GameState.reality < cost:
		return
	var before_free := GameState.shop_free_rerolls()
	var before_slots := GameState.shop_slots()
	GameState.add_reality(-cost)
	Progress.add_friend("charo")
	GameState.tipped["charo"] = true
	_hearts.set_level(Progress.friend_level("charo"))
	# Las ventajas nuevas valen ya / The new perks count right away
	_free_rerolls += GameState.shop_free_rerolls() - before_free
	if GameState.shop_slots() > before_slots:
		var have: Array[String] = []
		have.assign(_wares)
		_stock(_unsold_wares() + GameState.roll_wares(GameState.shop_slots() - _wares.size(), have))
	# Solo da las gracias; el saludo nuevo, la próxima vez / She just thanks you; the new greeting comes next time
	_line.text = "SHOP_TIP_THANKS"
	Audio.play("reality", -2.0)
	Audio.play("giver_charo", -4.0)
	_ready_t = 0.2
	_refresh()
	_leave.grab_focus()


func _unsold_wares() -> Array[String]:
	var out: Array[String] = []
	for i in _wares.size():
		if not _sold[i]:
			out.append(_wares[i])
	return out


## Cambia lo que no se ha vendido / Rerolls what hasn't been sold
func _do_reroll() -> void:
	if _done or _ready_t > 0.0 or _unsold_wares().is_empty():
		return
	if _free_rerolls <= 0:
		var cost := GameState.reroll_price(_paid_rerolls)
		if GameState.reality < cost:
			return
		GameState.add_reality(-cost)
		_paid_rerolls += 1
	else:
		_free_rerolls -= 1
	var have: Array[String] = []
	have.assign(_wares)
	var unsold := _unsold_wares().size()
	_stock(GameState.roll_wares(unsold, have))
	Audio.play("shuffle", -4.0, 0.1)
	Audio.play("reality", -10.0, 0.2)
	_ready_t = 0.2
	_refresh()
	_focus_first()


func _refresh() -> void:
	_count.text = str(GameState.reality)
	if not Progress.can_tip("charo"):
		_tip.text = tr("TIP_MAX")
		_tip.disabled = true
	elif GameState.tipped.has("charo"):
		_tip.text = tr("TIP_DONE")
		_tip.disabled = true
	elif GameState.reality < Progress.tip_cost("charo"):
		_tip.text = tr("TIP_SHORT").format({"n": Progress.tip_cost("charo") - GameState.reality})
		_tip.disabled = true
	else:
		_tip.text = tr("TIP_BUTTON").format({"cost": Progress.tip_cost("charo")})
		_tip.disabled = false
	for i in _wares.size():
		var b := _buttons[i]
		var cost := _price(i)
		if _sold[i]:
			b.text = tr("SHOP_SOLD")
			b.disabled = true
		elif GameState.reality < cost:
			b.text = tr("SHOP_SHORT").format({"n": cost - GameState.reality})
			b.disabled = true
		elif _offer[i]:
			b.text = tr("SHOP_BUY_OFFER").format({"cost": cost, "old": GameState.ware_price(_wares[i])})
			b.disabled = false
		else:
			b.text = tr("SHOP_BUY").format({"cost": cost})
			b.disabled = false
	# Cambiar el mostrador / Reroll the counter
	if _unsold_wares().is_empty():
		_reroll.text = tr("SHOP_REROLL").format({"cost": "-"})
		_reroll.disabled = true
	elif _free_rerolls > 0:
		_reroll.text = tr("SHOP_REROLL_FREE").format({"n": _free_rerolls})
		_reroll.disabled = false
	else:
		var rc := GameState.reroll_price(_paid_rerolls)
		_reroll.text = tr("SHOP_REROLL").format({"cost": rc})
		_reroll.disabled = GameState.reality < rc
	# Ventajas de la amistad / Friendship perks
	var parts: Array[String] = []
	if GameState.shop_free_rerolls() > 0:
		parts.append(tr("SHOP_PERK_REROLLS").format({"n": GameState.shop_free_rerolls()}))
	if GameState.shop_offer_chance() > 0.0:
		parts.append(tr("SHOP_PERK_OFFERS").format({"n": int(GameState.shop_offer_chance())}))
	if GameState.shop_slots() > 3:
		parts.append(tr("SHOP_PERK_SLOTS").format({"n": GameState.shop_slots()}))
	_perks.text = tr("SHOP_PERKS_NONE") if parts.is_empty() else " · ".join(parts)


func _process(delta: float) -> void:
	_ready_t -= delta


func _focus_first() -> void:
	for b in _buttons:
		if not b.disabled:
			b.grab_focus.call_deferred()
			return
	_leave.grab_focus.call_deferred()


func _buy(i: int) -> void:
	if _done or _ready_t > 0.0 or i >= _wares.size() or _sold[i]:
		return
	var cost := _price(i)
	if GameState.reality < cost:
		return
	GameState.add_reality(-cost)
	_sold[i] = true
	_bought_n += 1
	GameState.apply_ware(_wares[i])
	bought.emit(_wares[i])
	Audio.play("reality", -2.0)
	Audio.play("pickup", -6.0)
	_line.text = "SHOP_THANKS_3" if _unsold_wares().is_empty() else ["SHOP_THANKS_1", "SHOP_THANKS_2"][(_bought_n - 1) % 2]
	_ready_t = 0.2
	_refresh()
	# El foco pasa a otro botón que siga activo / Focus moves to another button that's still active
	_focus_first()


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
			"batteries":
				for k in 2:
					var o := c + Vector2(-8 + k * 16, k * 2)
					draw_rect(Rect2(o + Vector2(-5, -10), Vector2(10, 20)), Color("ffd27a"))
					draw_rect(Rect2(o + Vector2(-2, -13), Vector2(4, 3)), Color("cfc8ec"))
					draw_rect(Rect2(o + Vector2(-5, 2), Vector2(10, 8)), Color("e85d75"))
					draw_rect(Rect2(o + Vector2(-3, -8), Vector2(2, 8)), Color(1, 1, 1, 0.5))
			"sneakers":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 6), c + Vector2(-12, -4), c + Vector2(-4, -6), c + Vector2(2, 0), c + Vector2(13, 2), c + Vector2(13, 6)]), Color("7fb8ff"))
				draw_rect(Rect2(c + Vector2(-13, 6), Vector2(26, 3)), Color("fbf8ff"))
				for k in 3:
					draw_circle(c + Vector2(-9 + k * 9, 8), 1.4, [Color("ff5f7a"), Color("ffd27a"), Color("7fe0d0")][k] if fmod(_t * 4.0 + k, 3.0) < 1.5 else Color(1, 1, 1, 0.4))
				draw_line(c + Vector2(-6, -3), c + Vector2(0, -1), Color("fbf8ff"), 1.5)
			"plasters":
				for k in 2:
					var rot := 0.5 if k == 0 else -0.5
					var xf := Transform2D(rot, c)
					var pts := PackedVector2Array([Vector2(-13, -4), Vector2(13, -4), Vector2(13, 4), Vector2(-13, 4)])
					draw_colored_polygon(xf * pts, Color("f2c4a8"))
					draw_colored_polygon(xf * PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]), Color("e6d0c0"))
			"soda":
				draw_rect(Rect2(c + Vector2(-7, -11), Vector2(14, 22)), Color("e85d75"))
				draw_rect(Rect2(c + Vector2(-7, -12), Vector2(14, 3)), Color("cfc8ec"))
				draw_rect(Rect2(c + Vector2(-7, -3), Vector2(14, 6)), Color("fbf8ff"))
				for k in 3:
					var y := fposmod(_t * 14.0 + k * 8.0, 20.0)
					draw_circle(c + Vector2(-3 + k * 3, -14 - y), 1.3, Color(1, 1, 1, 0.6 * (1.0 - y / 20.0)))
			"stickers", "gold_sticker":
				var gold := ware == "gold_sticker"
				draw_rect(Rect2(c + Vector2(-11, -12), Vector2(18, 22)), Color("cfc8ec"))
				draw_rect(Rect2(c + Vector2(-7, -10), Vector2(18, 22)), Color("ffd27a") if gold else Color("fbf8ff"))
				draw_rect(Rect2(c + Vector2(-5, -8), Vector2(14, 12)), Color("e0a93a") if gold else Color("7fb8ff"))
				draw_circle(c + Vector2(2, -3), 3.0, Color("f1cfbb"))
				draw_rect(Rect2(c + Vector2(-1, 0), Vector2(6, 4)), Color("2f9e5b"))
				if gold:
					var a := fmod(_t * 2.0, TAU)
					draw_circle(c + Vector2(cos(a) * 12.0, sin(a) * 12.0), 1.5, Color(1, 1, 1, 0.8))
			"sandwich":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 2), c + Vector2(-10, -6), c + Vector2(10, -6), c + Vector2(14, 2)]), Color("e0a95a"))
				draw_rect(Rect2(c + Vector2(-14, 2), Vector2(28, 3)), Color("c9534a"))
				draw_rect(Rect2(c + Vector2(-13, 5), Vector2(26, 2)), Color("8fd17a"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 7), c + Vector2(14, 7), c + Vector2(12, 11), c + Vector2(-12, 11)]), Color("e0a95a"))
				for k in 3:
					draw_line(c + Vector2(-7 + k * 7, -4), c + Vector2(-5 + k * 7, -2), Color("fbe6c0"), 1.0)
			"cake":
				draw_rect(Rect2(c + Vector2(0, 4) + Vector2(-12, -2), Vector2(24, 12)), Color("f2b8d8"))
				draw_rect(Rect2(c + Vector2(0, 4) + Vector2(-12, -4), Vector2(24, 4)), Color("fbf8ff"))
				for k in 4:
					draw_circle(c + Vector2(0, 4) + Vector2(-9 + k * 6, -1), 1.6, Color("fbf8ff"))
				draw_rect(Rect2(c + Vector2(0, 4) + Vector2(-1, -12), Vector2(2, 8)), Color("7fb8ff"))
				var fl := 1.0 + sin(_t * 9.0) * 0.3
				draw_circle(c + Vector2(0, 4) + Vector2(0, -14), 2.2 * fl, Color("ffd27a"))
				draw_circle(c + Vector2(0, 4) + Vector2(0, -14), 1.0 * fl, Color("fbf8ff"))
			"coin":
				var sx := absf(cos(_t * 2.0))
				draw_set_transform(c, 0.0, Vector2(maxf(sx, 0.15), 1.0))
				draw_circle(Vector2.ZERO, 11.0, Color("e0a93a"))
				draw_circle(Vector2.ZERO, 8.5, Color("ffd27a"))
				for k in 4:
					var a := k * TAU / 4.0 + PI / 4.0
					draw_circle(Vector2(cos(a), sin(a)) * 3.0, 2.6, Color("2f9e5b"))
				draw_set_transform(Vector2.ZERO)
			"energy_drink":
				draw_rect(Rect2(c + Vector2(-7, -13), Vector2(14, 25)), Color("2a2a3a"))
				draw_rect(Rect2(c + Vector2(-7, -14), Vector2(14, 3)), Color("cfc8ec"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(2, -9), c + Vector2(-4, 1), c + Vector2(0, 1), c + Vector2(-2, 9), c + Vector2(4, -2), c + Vector2(0, -2)]), Color("9cff5a"))
				draw_rect(Rect2(c + Vector2(-5, -11), Vector2(2, 20)), Color(1, 1, 1, 0.25))
			"lucky_cat":
				var wave := sin(_t * 5.0) * 0.4
				draw_circle(c + Vector2(0, 4), 10.0, Color("fbf8ff"))
				draw_circle(c + Vector2(0, -6), 8.0, Color("fbf8ff"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -10), c + Vector2(-5, -17), c + Vector2(-2, -12)]), Color("fbf8ff"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(7, -10), c + Vector2(5, -17), c + Vector2(2, -12)]), Color("fbf8ff"))
				draw_line(c + Vector2(-4, -7), c + Vector2(-2, -7), ink, 1.5)
				draw_line(c + Vector2(2, -7), c + Vector2(4, -7), ink, 1.5)
				draw_line(c + Vector2(-8, 2), c + Vector2(8, 2), Color("e85d75"), 2.0)
				draw_circle(c + Vector2(0, 5), 2.5, Color("ffd27a"))
				var paw := c + Vector2(9, -4) + Vector2(0, -6).rotated(wave)
				draw_line(c + Vector2(9, -2), paw, Color("fbf8ff"), 4.0)
				draw_circle(paw, 3.0, Color("fbf8ff"))
			"first_aid":
				draw_rect(Rect2(c + Vector2(-13, -9), Vector2(26, 19)), Color("fbf8ff"))
				draw_rect(Rect2(c + Vector2(-5, -13), Vector2(10, 4)), Color("cfc8ec"))
				draw_rect(Rect2(c + Vector2(-2, -6), Vector2(4, 13)), Color("e85d75"))
				draw_rect(Rect2(c + Vector2(-6, -2), Vector2(12, 4)), Color("e85d75"))
			"comic":
				draw_rect(Rect2(c + Vector2(-11, -13), Vector2(22, 26)), Color("7fb8ff"))
				draw_rect(Rect2(c + Vector2(-9, -11), Vector2(18, 6)), Color("ffd27a"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(6, 9), c + Vector2(-6, 9)]), Color("e85d75"))
				draw_string(ThemeDB.fallback_font, c + Vector2(-4, 8), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fbf8ff"))
				var a2 := fmod(_t * 2.0, TAU)
				draw_circle(c + Vector2(cos(a2) * 15.0, sin(a2) * 15.0), 1.5, Color(1, 1, 1, 0.8))
			"encyclopedia":
				for k in 3:
					draw_rect(Rect2(c + Vector2(-13 + k * 9, -12), Vector2(8, 24)), [Color("7a2e4a"), Color("2f5e9e"), Color("2f9e5b")][k])
					draw_rect(Rect2(c + Vector2(-12 + k * 9, -8), Vector2(6, 2)), Color("ffd27a"))
					draw_rect(Rect2(c + Vector2(-12 + k * 9, 6), Vector2(6, 2)), Color("ffd27a"))
			"sunday_paper":
				draw_rect(Rect2(c + Vector2(-10, -12), Vector2(24, 20)), Color("d8ceb8"))
				draw_rect(Rect2(c + Vector2(-14, -8), Vector2(24, 20)), Color("f4ecdc"))
				draw_rect(Rect2(c + Vector2(-12, -6), Vector2(20, 3)), ink)
				draw_rect(Rect2(c + Vector2(-12, -1), Vector2(9, 8)), Color("ffd27a"))
				for k in 3:
					draw_rect(Rect2(c + Vector2(-1, -1 + k * 3), Vector2(9, 1)), Color(ink, 0.6))
