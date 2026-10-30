class_name WeaponChoiceScreen
extends CanvasLayer
## Al vencer a El Chef, Kroker elige una segunda arma, siempre del otro tipo: si su pijama
## lleva un arma cuerpo a cuerpo (bate, almohada u oso), elige una a distancia (libro,
## aspiradora o pistola de dedos), y al revés. Solo salen las que ya están desbloqueadas. La segunda arma flota a su lado y tiene sus propias mejoras.
## After beating The Chef, Kroker picks a second weapon, always of the other kind: if his
## pajama has a melee weapon (bat or pillow) he picks a ranged one (book or vacuum), and vice
## versa. The second weapon floats beside him and has its own upgrades.

signal chosen(id: String)

var _ready_t := 0.5
var _done := false


func build() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.85)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var title := UITheme.label("WEAPON2_TITLE", 66, UITheme.BONE, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var melee := GameState.selected_character in GameState.MELEE
	var sub := UITheme.label("WEAPON2_SUB_RANGED" if melee else "WEAPON2_SUB_MELEE", 24, UITheme.ASH, "italic")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 20
	col.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	col.add_child(row)
	var first: Button = null
	for id in GameState.other_weapons():
		var b := _card(row, id)
		if first == null:
			first = b
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.35)
	Audio.play("chime", -4.0)
	first.grab_focus.call_deferred()


func _card(row: Control, id: String) -> Button:
	var c: Dictionary = GameState.get_character(id)
	var accent: Color = KrokerArt.ACCENT.get(id, UITheme.GOLD)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 520)
	card.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.92), Color(accent, 0.7), Color(accent, 0.16), 20, 18, 26))
	row.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var icon := WeaponIcon.new()
	icon.id = id
	var px := PixelView.wrap(icon, 4)
	px.custom_minimum_size = Vector2(0, 200)
	v.add_child(px)
	var name_l := UITheme.label(c["weapon"], 40, UITheme.BONE, "display")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var desc := Keywords.label(c["desc"], 20, UITheme.ASH, "italic")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b := Button.new()
	b.text = "WEAPON2_PICK"
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(_pick.bind(id))
	b.mouse_entered.connect(b.grab_focus)
	v.add_child(b)
	return b


func _process(delta: float) -> void:
	_ready_t -= delta


func _pick(id: String) -> void:
	if _done or _ready_t > 0.0:
		return
	_done = true
	Audio.play("pickup", -2.0)
	chosen.emit(id)
	queue_free()


## El arma dibujada en grande, flotando / The weapon drawn large, floating
class WeaponIcon extends Control:
	var id := "book"
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, sin(_t * 2.0) * 3.0)
		var col: Color = KrokerArt.ACCENT.get(id, UITheme.GOLD)
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(40, 40), Vector2(80, 80)), false, Color(col, 0.35))
		var s := 0.6
		match id:
			"bat":
				draw_set_transform(c + Vector2(0, 30), 0.5, Vector2(s, s))
				Sprites.draw(self, "weapon_bat")
			"shield":
				draw_set_transform(c, sin(_t) * 0.1, Vector2(s, s))
				Sprites.draw(self, "weapon_pillow")
			"book":
				draw_set_transform(c, sin(_t) * 0.1, Vector2(s, s))
				Sprites.draw(self, "weapon_book")
			"vacuum":
				draw_set_transform(c - Vector2(150, 253) * s, 0.0, Vector2(s, s))
				Sprites.draw(self, "weapon_tank")
				draw_set_transform(c + Vector2(14, -10), -0.5, Vector2(s, s))
				Sprites.draw(self, "weapon_nozzle")
			"finger":
				KrokerArt.finger_gun(self, Transform2D(-0.12, c + Vector2(-6, 6)), Vector2.ZERO, Vector2(1, 0), 0.6 + 0.4 * sin(_t * 3.0), "icon_finger", 1.25)
			"teddy":
				draw_set_transform(c, sin(_t) * 0.1, Vector2(s, s) * 1.4)
				Sprites.draw(self, "weapon_teddy")
		draw_set_transform(Vector2.ZERO)
