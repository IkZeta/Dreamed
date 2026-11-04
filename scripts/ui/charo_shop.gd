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
	var icon_px := PixelView.wrap(icon, 3)
	icon_px.custom_minimum_size = Vector2(0, 126)
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
		var c := (size / 2.0 + Vector2(0, roundf(sin(_t * 2.0) * 1.5))).round()
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(30, 26), Vector2(60, 52)), false, Color("4fa89a", 0.3))
		Sprites.draw(self, "ware_" + ware, Color.WHITE, c + Vector2(0, 2))
		# La pegatina dorada y el cómic llevan un destello que gira / The gold sticker and the comic have a circling sparkle
		if ware == "gold_sticker" or ware == "comic":
			var a := fmod(_t * 2.0, TAU)
			draw_rect(Rect2(c + Vector2(cos(a) * 17.0, sin(a) * 17.0).round(), Vector2(2, 2)), Color(1, 1, 1, 0.85))
