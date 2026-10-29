extends Control
## Bestiario: los enemigos que has visto, con su dibujo, lo que hacen y cuántos has
## derrotado. Los que aún no has visto salen como «???». Se abre desde el menú principal.
## Bestiary: the enemies you've seen, with their drawing, what they do and how many you've
## defeated. Unseen ones show as "???". Opened from the main menu.

signal closed

var _list: VBoxContainer
var _preview_holder: Control
var _name: Label
var _desc: Label
var _count: Label
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
	root.add_child(UITheme.label("BESTIARY_TITLE", 60, UITheme.BONE, "display"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(row)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size.x = 420
	row.add_child(_list)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(info)
	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 360)
	info.add_child(_preview_holder)
	_name = UITheme.label("", 48, UITheme.GOLD, "display")
	_name.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	info.add_child(_name)
	_desc = UITheme.label("", 24, UITheme.BONE, "body")
	_desc.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_desc)
	_count = UITheme.label("", 24, UITheme.ASH, "caps")
	_count.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	info.add_child(_count)

	for id in Progress.BESTIARY:
		var b := Button.new()
		b.text = tr("BEST_%s_NAME" % id.to_upper()) if Progress.has_seen(id) else "???"
		b.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 62)
		b.focus_entered.connect(_show.bind(id))
		b.mouse_entered.connect(b.grab_focus)
		_list.add_child(b)
		if _first == null:
			_first = b
	var gap := Control.new()
	gap.size_flags_vertical = SIZE_EXPAND_FILL
	_list.add_child(gap)
	var back := Button.new()
	back.text = "BTN_BACK"
	back.custom_minimum_size = Vector2(0, 64)
	back.pressed.connect(_close)
	_list.add_child(back)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _show(id: String) -> void:
	for c in _preview_holder.get_children():
		c.queue_free()
	var seen := Progress.has_seen(id)
	var prev := BestiaryPreview.new()
	prev.id = id
	prev.hidden_shape = not seen
	var px := PixelView.wrap(prev, 3)
	_preview_holder.add_child(px)
	px.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_name.text = tr("BEST_%s_NAME" % id.to_upper()) if seen else "???"
	_desc.text = tr("BEST_%s_DESC" % id.to_upper()) if seen else tr("BESTIARY_UNSEEN")
	_count.text = (tr("BESTIARY_DEFEATED") % int(Progress.kills.get(id, 0))) if seen else ""


func _close() -> void:
	closed.emit()
	queue_free()


## Dibuja un enemigo del bestiario, animado / Draws a bestiary enemy, animated
class BestiaryPreview extends Control:
	var id := "foox"
	var hidden_shape := false
	var _enemy: Node2D
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		if id.begins_with("boss_"):
			return
		var e: Enemy
		match id:
			"thug": e = Thug.new()
			"sling": e = SlingThug.new()
			"skeleton": e = Skeleton.new()
			"golden_foox": e = GoldenFoox.new()
			_: e = Foox.new()
		if id == "elite":
			e.elite = true
			e.elite_power = "split"
		e.preview = true
		e.state = Enemy.State.ALIVE
		e._fade = 1.0
		add_child(e)
		e.set_physics_process(false)
		e.scale = Vector2.ONE * (1.3 if id == "elite" else 1.0) * 0.9
		if hidden_shape:
			e.modulate = Color(0, 0, 0, 0.75)
		_enemy = e

	func _process(delta: float) -> void:
		_t += delta
		if _enemy:
			_enemy.set("_t", _t)
			_enemy.position = Vector2(size.x / 2.0, size.y * 0.82)
			_enemy.queue_redraw()
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y * 0.82)
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(90, 120), Vector2(180, 160)), false, Color(UITheme.MIST, 0.15))
		if id.begins_with("boss_"):
			var sprite := {"boss_bed": "boss_bed", "boss_shelf": "boss_shelf", "boss_chest": "boss_chest_box"}[id] as String
			var mod := Color(0, 0, 0, 0.75) if hidden_shape else Color.WHITE
			draw_set_transform(c, 0.0, Vector2.ONE * 0.62)
			Sprites.draw(self, sprite, mod)
			if id == "boss_chest":
				Sprites.draw(self, "boss_chest_lid", mod, Vector2(0, -66))
			draw_set_transform(Vector2.ZERO)
