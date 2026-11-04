class_name StickerAlbum
extends ColorRect
## El álbum de pegatinas del diario de Kroker, en el museo del plano astral: una pegatina por cada
## combo descubierto, cada mejora dúo y cada mejora legendaria conseguidas. Las que faltan salen
## en gris con una pista.
## The sticker album from Kroker's diary, in the astral plane's museum: one sticker for every combo
## discovered and every duo and legendary upgrade obtained. Missing ones show in grey with a hint.

signal closed

const PAPER := Color("efe6cf")
const INK := Color("2a2440")
const COMBO_PINK := Color("ff9ad0")

var _name: Label
var _desc: RichTextLabel
var _first: Button


static func make() -> StickerAlbum:
	var a := StickerAlbum.new()
	a._build()
	return a


## Todas las pegatinas: [[tipo, id], ...] / Every sticker: [[kind, id], ...]
static func all() -> Array:
	var out := []
	for id: String in GameState.COMBOS:
		out.append(["combo", id])
	for id: String in GameState.DUOS:
		out.append(["duo", id])
	for g: String in GameState.GIVERS:
		out.append(["legend", g])
	return out


static func got_count() -> int:
	var n := 0
	for s: Array in all():
		if Progress.has_sticker(s[0], s[1]):
			n += 1
	return n


static func sticker_name(kind: String, id: String) -> String:
	match kind:
		"combo": return tr_s("COMBO_%s_NAME" % id.to_upper())
		"duo": return tr_s("DUO_%s_NAME" % id.to_upper())
	return tr_s("STICKER_LEGEND_NAME").format({"who": tr_s("GIVER_%s_NAME" % id.to_upper())})


static func tr_s(key: String) -> String:
	return TranslationServer.translate(key)


func _build() -> void:
	color = Color(UITheme.INK, 0.7)
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var book := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.set_corner_radius_all(6)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_offset = Vector2(10, 12)
	st.content_margin_left = 48
	st.content_margin_right = 48
	st.content_margin_top = 30
	st.content_margin_bottom = 28
	book.add_theme_stylebox_override("panel", st)
	center.add_child(book)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size.x = 1180
	book.add_child(v)
	var head := HBoxContainer.new()
	var title := UITheme.label("ALBUM_TITLE", 44, DreamDiary.RED, "display")
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	var count := UITheme.label("", 22, Color(INK, 0.7), "caps")
	count.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	count.text = "%d / %d" % [got_count(), all().size()]
	count.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(count)
	v.add_child(head)
	var sub := UITheme.label("ALBUM_SUB", 18, Color(INK, 0.65), "italic")
	v.add_child(sub)
	for section in [["combo", "ALBUM_COMBOS"], ["duo", "ALBUM_DUOS"], ["legend", "ALBUM_LEGENDS"]]:
		v.add_child(UITheme.label(section[1], 20, Color(INK, 0.85), "caps"))
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		v.add_child(grid)
		for s: Array in all():
			if s[0] == section[0]:
				grid.add_child(_tile(s[0], s[1]))
	v.add_child(UITheme.rule(Color(INK, 0.25)))
	_name = UITheme.label("", 26, INK, "display")
	_name.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(_name)
	_desc = Keywords.label("", 20, Color(INK, 0.85), "body")
	_desc.custom_minimum_size = Vector2(1080, 56)
	v.add_child(_desc)
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(260, 54)
	back.size_flags_horizontal = SIZE_SHRINK_END
	back.pressed.connect(func() -> void: closed.emit())
	v.add_child(back)
	if _first:
		_first.ready.connect(_first.grab_focus)
		_show(_first.get_meta("kind"), _first.get_meta("id"))


func _tile(kind: String, id: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(84, 84)
	b.focus_mode = FOCUS_ALL
	b.set_meta("kind", kind)
	b.set_meta("id", id)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	var art := Sticker.new()
	art.kind = kind
	art.id = id
	art.got = Progress.has_sticker(kind, id)
	art.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(art)
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	b.focus_entered.connect(func() -> void:
		art.selected = true
		_show(kind, id))
	b.focus_exited.connect(func() -> void: art.selected = false)
	b.mouse_entered.connect(b.grab_focus)
	if _first == null:
		_first = b
	return b


func _show(kind: String, id: String) -> void:
	var got := Progress.has_sticker(kind, id)
	if got:
		_name.text = sticker_name(kind, id)
		var desc := ""
		match kind:
			"combo": desc = tr("COMBO_%s_DESC" % id.to_upper())
			"duo": desc = GameState.duo_desc(id)
			_: desc = tr("STICKER_LEGEND_DESC").format({"who": tr("GIVER_%s_NAME" % id.to_upper())})
		Keywords.set_text(_desc, desc)
		return
	_name.text = "???"
	match kind:
		"combo":
			Keywords.set_text(_desc, tr("ALBUM_HINT_COMBO"))
		"duo":
			var d: Dictionary = GameState.DUOS[id]
			Keywords.set_text(_desc, tr("ALBUM_HINT_DUO").format({"a": tr("GIVER_%s_NAME" % String(d["a"]).to_upper()), "b": tr("GIVER_%s_NAME" % String(d["b"]).to_upper()),
				"weapon": tr("WEAPON_SHORT_" + String(d["weapon"]).to_upper())}))
		_:
			Keywords.set_text(_desc, tr("ALBUM_HINT_LEGEND").format({"who": tr("GIVER_%s_NAME" % id.to_upper()), "lvl": GameState.LEGEND_FRIEND}))


## Una pegatina: estrella rosa (combo), dos caras (dúo) o medalla dorada con una cara (legendaria);
## en gris con una interrogación si falta. Las caras van recortadas dentro del círculo.
## A sticker: pink star (combo), two faces (duo) or gold medal with a face (legendary); grey with a
## question mark if missing. The faces are clipped inside the circle.
class Sticker extends Control:
	const FACE := {"svinho": Vector2(100, 62), "stolk": Vector2(100, 60), "silly": Vector2(100, 70), "doc": Vector2(100, 66),
		"ad": Vector2(100, 64), "pinche": Vector2(100, 60), "magnus": Vector2(100, 72), "superk": Vector2(100, 58),
		"lilkey": Vector2(100, 62), "lynx": Vector2(100, 58)}
	const R := 34.0
	var kind := "combo"
	var id := ""
	var got := false
	var selected := false:
		set(v):
			selected = v
			scale = Vector2.ONE * (1.08 if v else 1.0)
			queue_redraw()
			if _over:
				_over.queue_redraw()
	var _mask: Control
	var _over: Control

	func _ready() -> void:
		rotation = randf_range(-0.12, 0.12)
		pivot_offset = Vector2(42, 42)
		if got and kind != "combo":
			_mask = Control.new()
			_mask.mouse_filter = MOUSE_FILTER_IGNORE
			_mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			add_child(_mask)
			_mask.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			_mask.draw.connect(_draw_mask)
			var faces := Control.new()
			faces.mouse_filter = MOUSE_FILTER_IGNORE
			_mask.add_child(faces)
			faces.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			faces.draw.connect(_draw_faces.bind(faces))
		_over = Control.new()
		_over.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_over)
		_over.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_over.draw.connect(_draw_over)

	func _draw() -> void:
		var c := Vector2(42, 42)
		draw_circle(c + Vector2(3, 4), R, Color(0, 0, 0, 0.18))
		if not got:
			_dashed(c, R, Color(StickerAlbum.INK, 0.35))
			draw_circle(c, R - 3.0, Color(StickerAlbum.INK, 0.06))
			draw_string(UITheme.font("display"), c + Vector2(-9, 12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(StickerAlbum.INK, 0.35))
			return
		if kind == "combo":
			var pts := PackedVector2Array()
			for k in 16:
				var a := -PI / 2.0 + k * TAU / 16.0
				pts.append(c + Vector2(cos(a), sin(a)) * (R if k % 2 == 0 else R * 0.72))
			draw_colored_polygon(pts, Color.WHITE)
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(c + (p - c) * 0.86)
			draw_colored_polygon(inner, StickerAlbum.COMBO_PINK)
			# Los colores de quienes forman el combo / The colours of whoever makes the combo
			var cols := _combo_colors()
			for i in cols.size():
				var at := c + Vector2((i - (cols.size() - 1) / 2.0) * 18.0, 0)
				draw_circle(at, 9.0, Color.WHITE)
				draw_circle(at, 7.0, cols[i])
		else:
			draw_circle(c, R, Color.WHITE)

	func _draw_mask() -> void:
		var c := Vector2(42, 42)
		var col := Color("f6d993") if kind == "duo" else ((HubLayout.ISLES[id]["aura"] as Color).darkened(0.35) if HubLayout.ISLES.has(id) else Color("7a5a20"))
		_mask.draw_circle(c, R - (3.0 if kind == "duo" else 8.0), col)

	func _draw_faces(ci: Control) -> void:
		var c := Vector2(42, 42)
		if kind == "duo":
			var d: Dictionary = GameState.DUOS[id]
			_face(ci, String(d["a"]), c + Vector2(-13, 6), 0.34)
			_face(ci, String(d["b"]), c + Vector2(13, 6), 0.34, true)
		else:
			_face(ci, id, c + Vector2(0, 8), 0.42)

	func _draw_over() -> void:
		var c := Vector2(42, 42)
		if got and kind == "duo":
			_over.draw_arc(c, R - 3.0, 0, TAU, 32, Color("c9962a"), 3.0)
		elif got and kind == "legend":
			_over.draw_arc(c, R - 5.5, 0, TAU, 32, Color("e0a93a"), 5.0)
			for k in 12:
				var a := k * TAU / 12.0
				_over.draw_circle(c + Vector2(cos(a), sin(a)) * (R - 5.5), 1.4, Color("fff2b0"))
		if selected:
			_over.draw_arc(c, R + 4.0, 0, TAU, 36, Color(StickerAlbum.INK, 0.6), 2.0)

	## La cara de un personaje centrada en "at" / A character's face centred on "at"
	func _face(ci: CanvasItem, who: String, at: Vector2, s: float, flip := false) -> void:
		var f: Vector2 = FACE.get(who, Vector2(100, 64))
		var sx := -s if flip else s
		NpcArt.draw(ci, Transform2D(0.0, Vector2(sx, s), 0.0, at - Vector2(f.x * sx, f.y * s)), who, 0.0)
		ci.draw_set_transform(Vector2.ZERO)

	func _combo_colors() -> Array:
		var out := []
		for n: Dictionary in GameState.COMBOS[id]["needs"]:
			if n.has("g"):
				var g: String = n["g"]
				out.append(HubLayout.ISLES[g]["aura"] if HubLayout.ISLES.has(g) else Color("4fd39a"))
			elif n.has("weapon"):
				out.append(KrokerArt.ACCENT.get(n["weapon"], Color.WHITE))
			else:
				out.append(UITheme.GOLD)
		return out

	func _dashed(c: Vector2, r: float, col: Color) -> void:
		for k in 16:
			var a := k * TAU / 16.0
			draw_arc(c, r, a, a + TAU / 32.0, 4, col, 2.0)
