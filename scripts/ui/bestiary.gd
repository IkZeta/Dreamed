extends Control
## Bestiario: los enemigos que has visto, con su dibujo, lo que hacen y cuántos has
## derrotado. Los que aún no has visto salen como «???». Se abre desde el menú principal.
## Bestiary: the enemies you've seen, with their drawing, what they do and how many you've
## defeated. Unseen ones show as "???". Opened from the main menu.

signal closed

var _list: VBoxContainer
var _preview_holder: Control
var _name: Label
var _desc: RichTextLabel
var _buttons := {}
var _current := ""
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
	_list.custom_minimum_size.x = 560
	row.add_child(_list)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(info)
	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 470)
	info.add_child(_preview_holder)
	_name = UITheme.label("", 48, UITheme.GOLD, "display")
	_name.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	info.add_child(_name)
	# Texto con colores (la entrada del élite explica cada color) / Coloured text (the elite entry explains each colour)
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
	_count = UITheme.label("", 24, UITheme.ASH, "caps")
	_count.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	info.add_child(_count)

	# Dos columnas para que quepan todas las entradas / Two columns so every entry fits
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	for id in Progress.BESTIARY:
		var b := Button.new()
		b.text = tr("BEST_%s_NAME" % id.to_upper()) if Progress.has_seen(id) else "???"
		b.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.clip_text = true
		b.focus_entered.connect(_show.bind(id))
		b.mouse_entered.connect(b.grab_focus)
		grid.add_child(b)
		_buttons[id] = b
		if _first == null:
			_first = b
	var gap := Control.new()
	gap.size_flags_vertical = SIZE_EXPAND_FILL
	_list.add_child(gap)
	# Desbloquear todo (para probar) / Unlock everything (for testing)
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _unlock_all() -> void:
	for id in Progress.BESTIARY:
		if not Progress.has_seen(id):
			Progress.kills[id] = 0
	Progress.save_progress()
	Audio.play("chime", -4.0)
	for id: String in _buttons:
		_buttons[id].text = tr("BEST_%s_NAME" % id.to_upper())
	if _current != "":
		_show(_current)


func _show(id: String) -> void:
	_current = id
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
	var text := tr("BEST_%s_DESC" % id.to_upper()) if seen else tr("BESTIARY_UNSEEN")
	if seen and id == "elite":
		# Una línea por color con lo que hace / One line per colour with what it does
		for power in ["split", "puddle", "haste"]:
			text += "\n[color=#%s]■ %s[/color]" % [Enemy.ELITE_COLORS[power].to_html(false), tr("BEST_ELITE_" + power.to_upper())]
	_desc.text = text
	_count.text = (tr("BESTIARY_DEFEATED") % int(Progress.kills.get(id, 0))) if seen else ""


func _close() -> void:
	closed.emit()
	queue_free()


## Dibuja un enemigo del bestiario, animado / Draws a bestiary enemy, animated
class BestiaryPreview extends Control:
	var id := "foox"
	var hidden_shape := false
	var power := "split"
	var _enemy: Node2D
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		if id.begins_with("boss_") and id != "boss_chef":
			return
		var e: Enemy
		match id:
			"thug": e = Thug.new()
			"sling": e = SlingThug.new()
			"skeleton": e = Skeleton.new()
			"nest": e = Nest.new()
			"mosquito": e = Mosquito.new()
			"cyber": e = Cyberpunk.new()
			"boss_chef": e = Chef.new()
			"golden_foox": e = GoldenFoox.new()
			_: e = Foox.new()
		if id == "elite":
			e.elite = true
			e.elite_power = power
		e.preview = true
		e.state = Enemy.State.ALIVE
		e._fade = 1.0
		add_child(e)
		e.set_physics_process(false)
		e.scale = Vector2.ONE * (1.3 if id == "elite" else 1.0) * _fit()
		if hidden_shape:
			e.modulate = Color(0, 0, 0, 0.75)
		_enemy = e

	## Alto de cada dibujo (con cuernos y aura) / Height of each drawing (with horns and aura)
	const HEIGHTS := {"foox": 70.0, "golden_foox": 70.0, "elite": 70.0, "thug": 170.0, "sling": 130.0, "skeleton": 130.0, "nest": 60.0, "mosquito": 70.0, "cyber": 150.0, "boss_chef": 290.0,
		"boss_bed": 200.0, "boss_shelf": 190.0, "boss_chest": 130.0}

	## Escala para que quepa entero en el hueco / Scale so it fits whole in the space
	func _fit() -> float:
		var h: float = HEIGHTS.get(id, 120.0) * (1.3 if id == "elite" else 1.0)
		return minf(1.6, size.y * 0.74 / h)

	func _process(delta: float) -> void:
		_t += delta
		# El élite va cambiando de color cada 2 s / The elite changes colour every 2 s
		if id == "elite" and _enemy and _t > 2.0:
			_t = 0.0
			var powers := ["split", "puddle", "haste"]
			power = powers[(powers.find(power) + 1) % 3]
			_enemy.queue_free()
			_enemy = null
			_ready()
			return
		if _enemy:
			_enemy.set("_t", _t)
			_enemy.position = Vector2(size.x / 2.0, size.y * 0.84)
			_enemy.scale = Vector2.ONE * (1.3 if id == "elite" else 1.0) * _fit()
			_enemy.queue_redraw()
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y * 0.84)
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(90, 120), Vector2(180, 160)), false, Color(UITheme.MIST, 0.15))
		if id.begins_with("boss_") and id != "boss_chef":
			var sprite := {"boss_bed": "boss_bed", "boss_shelf": "boss_shelf", "boss_chest": "boss_chest_box"}[id] as String
			var mod := Color(0, 0, 0, 0.75) if hidden_shape else Color.WHITE
			draw_set_transform(c, 0.0, Vector2.ONE * _fit())
			Sprites.draw(self, sprite, mod)
			if id == "boss_chest":
				Sprites.draw(self, "boss_chest_lid", mod, Vector2(0, -66))
			draw_set_transform(Vector2.ZERO)
