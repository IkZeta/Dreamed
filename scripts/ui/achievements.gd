extends Control
## Logros: lista con su progreso. Los que tienen dibujo lo muestran (aparece en la pared de
## la habitación al conseguirlos). Se abre desde el menú principal.
## Achievements: a list with their progress. Those with a drawing show it (it appears on the
## bedroom wall once unlocked). Opened from the main menu.

signal closed

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
	panel.custom_minimum_size = Vector2(1500, 900)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := UITheme.label("ACH_TITLE", 60, UITheme.BONE, "display")
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	var got := 0
	for a in Progress.ACHIEVEMENTS:
		if Progress.has_achieved(a["id"]):
			got += 1
	var count := UITheme.label(tr("ACH_COUNT") % [got, Progress.ACHIEVEMENTS.size()], 24, UITheme.GOLD, "caps")
	count.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	count.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for a in Progress.ACHIEVEMENTS:
		grid.add_child(_row(a))

	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(300, 64)
	back.size_flags_horizontal = SIZE_SHRINK_END
	back.pressed.connect(_close)
	root.add_child(back)
	_first = back
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_first.grab_focus.call_deferred()


func _row(a: Dictionary) -> Control:
	var done := Progress.has_achieved(a["id"])
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(700, 128)
	box.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.SLATE, 0.6 if done else 0.25),
		Color(UITheme.GOLD, 0.7) if done else Color(UITheme.LINE, 0.3), 2, 10, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	box.add_child(h)
	var icon := AchievementIcon.new()
	icon.drawing = a.get("drawing", "")
	icon.done = done
	var icon_px := PixelView.wrap(icon, 2)
	icon_px.custom_minimum_size = Vector2(110, 100)
	h.add_child(icon_px)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	var id := String(a["id"]).to_upper()
	v.add_child(UITheme.label("ACH_%s_NAME" % id, 24, UITheme.GOLD if done else UITheme.BONE, "display"))
	var desc := UITheme.label("ACH_%s_DESC" % id, 24, UITheme.ASH, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	if a.has("drawing"):
		v.add_child(UITheme.label("ACH_DRAWING", 24, Color(UITheme.ROSE, 0.9 if done else 0.5), "italic"))
	var p := Progress.achievement_progress(a)
	if int(p[1]) > 1:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = p[1]
		bar.value = p[0]
		bar.custom_minimum_size = Vector2(0, 8)
		bar.add_theme_stylebox_override("fill", UITheme.bar(UITheme.GOLD, 3.0))
		bar.add_theme_stylebox_override("background", UITheme.bar(Color(UITheme.LINE, 0.4), 3.0))
		v.add_child(bar)
		var num := UITheme.label("%d / %d" % [p[0], p[1]], 24, UITheme.ASH, "caps")
		num.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		v.add_child(num)
	return box


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()


## Icono del logro: su dibujo, o una estrella si no tiene / Achievement icon: its drawing, or a star if it has none
class AchievementIcon extends Control:
	var drawing := ""
	var done := false

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var mod := Color.WHITE if done else Color(0.25, 0.25, 0.4, 0.7)
		if drawing != "":
			var r: Rect2 = SpriteRects.RECTS["room_draw_" + drawing]
			var k := minf(size.x / r.size.x, size.y / r.size.y) * 0.9
			draw_set_transform(c - r.get_center() * k, 0.0, Vector2(k, k))
			Sprites.draw(self, "room_draw_" + drawing, mod)
			draw_set_transform(Vector2.ZERO)
		else:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (18.0 if i % 2 == 0 else 8.0))
			draw_colored_polygon(pts, UITheme.GOLD if done else Color(0.35, 0.35, 0.55))
