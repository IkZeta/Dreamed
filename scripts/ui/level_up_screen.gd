class_name LevelUpScreen
extends CanvasLayer
## Pantalla de subida de nivel: tres mejoras de estadística con su rareza (de común a
## legendaria). Funciona con el juego en pausa.
## Level-up screen: three stat upgrades with their rarity (common to legendary).
## Works while the game is paused.

signal chosen(choice: Dictionary)

const RARITY_COLOR: Array[Color] = [Color("bcc0ea"), Color("9be38a"), Color("7fb8ff"), Color("c79bff"), Color("ffc26a")]

var _choices: Array[Dictionary] = []
var _ready_t := 0.4
var _done := false
var _buttons: Array[Button] = []
var _first: Button
var _row: HBoxContainer
var _reroll: Button
## Cada vez que cambias las opciones pierdes esta suerte / Each reroll costs this much luck
const REROLL_LUCK := 2.0


func build(choices: Array[Dictionary], level: int) -> void:
	_choices = choices
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.8)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var lvl := UITheme.label(tr("HUD_LEVEL") % level, 18, UITheme.GOLD, "caps")
	lvl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lvl)
	var title := UITheme.label("LEVELUP_TITLE", 72, UITheme.BONE, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UITheme.label("LEVELUP_SUB", 24, UITheme.ASH, "italic")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	col.add_child(gap)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 32)
	col.add_child(_row)
	_fill_cards()

	# Cambiar las opciones a cambio de suerte / Reroll the options in exchange for luck
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 12
	col.add_child(gap2)
	_reroll = Button.new()
	_reroll.custom_minimum_size = Vector2(520, 58)
	_reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_reroll.pressed.connect(_do_reroll)
	_reroll.mouse_entered.connect(_reroll.grab_focus)
	col.add_child(_reroll)
	_update_reroll()

	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	Audio.play("chime", -4.0)
	_first.grab_focus.call_deferred()


func _fill_cards() -> void:
	for c in _row.get_children():
		c.queue_free()
	_first = null
	_buttons.clear()
	for i in _choices.size():
		_row.add_child(_card(_choices[i], i))
	_wire_focus.call_deferred()


## Con mando o teclado: izquierda y derecha pasan de carta en carta (sin saltarse la del medio),
## abajo va a «Cambiar» y desde ahí arriba vuelve a la carta del centro
## With a gamepad or keyboard: left and right go card by card (without skipping the middle one),
## down goes to "Reroll" and up from there returns to the middle card
func _wire_focus() -> void:
	if _buttons.is_empty() or not is_instance_valid(_reroll):
		return
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.focus_neighbor_left = b.get_path_to(_buttons[(i - 1 + _buttons.size()) % _buttons.size()])
		b.focus_neighbor_right = b.get_path_to(_buttons[(i + 1) % _buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(_reroll)
		b.focus_neighbor_top = b.get_path()
	var mid: Button = _buttons[_buttons.size() / 2]
	_reroll.focus_neighbor_top = _reroll.get_path_to(mid)
	_reroll.focus_neighbor_left = _reroll.get_path()
	_reroll.focus_neighbor_right = _reroll.get_path()


func _update_reroll() -> void:
	_reroll.text = tr("LEVELUP_REROLL").format({"cost": int(REROLL_LUCK), "luck": roundi(GameState.stat("luck"))})


func _do_reroll() -> void:
	if _done or _ready_t > 0.0:
		return
	GameState.stat_bonus["luck"] = float(GameState.stat_bonus.get("luck", 0.0)) - REROLL_LUCK
	_choices = GameState.roll_level_choices()
	_fill_cards()
	_update_reroll()
	Audio.play("glitch", -6.0)
	_ready_t = 0.25
	_reroll.grab_focus()


func _card(choice: Dictionary, index: int) -> Control:
	var r: int = choice["rarity"]
	var color := RARITY_COLOR[r]
	var id: String = choice["stat"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 430)
	card.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.92), Color(color, 0.7), Color(color, 0.14 + 0.06 * r), 18 + r * 4, 18, 26))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var rarity := UITheme.label("RARITY_" + GameState.RARITIES[r].to_upper(), 15, color, "caps")
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rarity)
	var icon := RarityStar.new()
	icon.color = color
	icon.rarity = r
	icon.stat = id
	var icon_px := PixelView.wrap(icon, 3)
	icon_px.custom_minimum_size = Vector2(0, 150)
	v.add_child(icon_px)
	var name_l := UITheme.label("STAT_NAME_" + id.to_upper(), 32, UITheme.BONE, "display")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var value := UITheme.label(GameState.stat_value_text(id, float(choice["value"])), 22, color, "body")
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(value)
	var desc := Keywords.label("STAT_DESC_" + id.to_upper(), 18, UITheme.ASH, "italic")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b := Button.new()
	Keywords.on_focus(b, desc)
	b.text = "LEVELUP_PICK"
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(_pick.bind(index))
	b.mouse_entered.connect(b.grab_focus)
	v.add_child(b)
	if _first == null:
		_first = b
	_buttons.append(b)
	return card


func _process(delta: float) -> void:
	_ready_t -= delta


func _pick(index: int) -> void:
	if _done or _ready_t > 0.0:
		return
	_done = true
	Audio.play("pickup", -2.0)
	chosen.emit(_choices[index])
	queue_free()


## El icono de la estadística, con un resplandor y unos destellos que crecen con la rareza
## The stat's icon, with a glow and sparkles that grow with the rarity
class RarityStar extends Control:
	var color := Color.WHITE
	var rarity := 0
	var stat := ""
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var pulse := 0.85 + 0.15 * sin(_t * 2.5)
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(70, 70) * pulse, Vector2(140, 140) * pulse), false, Color(color, 0.25 + 0.08 * rarity))
		# Más rara = más destellos girando alrededor / Rarer = more sparkles circling around
		for i in rarity * 2:
			var a := _t * 0.8 + i * TAU / maxf(1.0, rarity * 2.0)
			DreamBackground.draw_star(self, c + Vector2(cos(a) * 46.0, sin(a) * 30.0), 2.5, Color(color, 0.8))
		# Peana de la rareza y el icono encima, flotando / Rarity plinth with the icon floating on top
		var bob := roundf(sin(_t * 2.0) * 1.5)
		var base := c + Vector2(0, 19)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-16, 0), base + Vector2(16, 0), base + Vector2(12, 4), base + Vector2(-12, 4)]), Color(color, 0.55))
		draw_rect(Rect2(base + Vector2(-16, -1), Vector2(32, 2)), color)
		for i in rarity + 1:
			draw_rect(Rect2(base + Vector2(-((rarity + 1) * 4 - 1) / 2.0 + i * 4.0, 6), Vector2(2, 2)), color)
		if stat != "" and SpriteRects.RECTS.has("icon_" + stat):
			Sprites.draw(self, "icon_" + stat, Color.WHITE, c + Vector2(0, bob - 4))
		else:
			DreamBackground.draw_star(self, c, 12.0, color)
