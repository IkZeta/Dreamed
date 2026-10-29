extends Control
## Plano astral: entre un sueño y el siguiente aparecen dos de los tres personajes
## (Svinho, Stolk y Silly) y cada uno ofrece una mejora para el arma de Kroker.
## Astral plane: between one dream and the next, two of the three characters
## (Svinho, Stolk and Silly) appear and each offers an upgrade for Kroker's weapon.

const RUN_SCENE := "res://scenes/run.tscn"

var _offer: Array[String] = []
var _buttons: Array[Button] = []
var _figures: Array[Control] = []
var _chosen := false


func _ready() -> void:
	theme = UITheme.build()
	Audio.play_music("music_astral", 1.5)
	_offer = GameState.pick_offer()
	_build()
	# Sale del destello blanco del final del sueño / Fades out of the end-of-dream flash
	var flash := ColorRect.new()
	flash.color = Color("f7f2ff")
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(flash.queue_free)
	# Cada personaje se presenta con su propio tema / Each character introduces itself with its own motif
	for i in _offer.size():
		get_tree().create_timer(0.5 + i * 1.1).timeout.connect(Audio.play.bind("giver_" + _offer[i], -4.0))
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _build() -> void:
	var sky := PixelView.wrap(AstralSky.new(), 2)
	add_child(sky)
	sky.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 120)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var title := UITheme.label("ASTRAL_TITLE", 64, UITheme.BONE, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var sub := UITheme.label("ASTRAL_SUBTITLE", 26, UITheme.ASH, "italic")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	root.add_child(row)

	var weapon := GameState.selected_character
	for i in _offer.size():
		row.add_child(_offer_column(_offer[i], weapon))
		if i == 0:
			# Kroker flota en medio, esperando / Kroker floats in the middle, waiting
			var k := FloatingKroker.new()
			k.outfit = weapon
			var k_px := PixelView.wrap(k, 5)
			k_px.custom_minimum_size = Vector2(260, 0)
			row.add_child(k_px)


func _offer_column(giver: String, weapon: String) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(540, 0)
	col.add_theme_constant_override("separation", 6)

	var fig := GiverFigure.new()
	fig.who = giver
	var fig_px := PixelView.wrap(fig, 3)
	fig_px.custom_minimum_size = Vector2(0, 380)
	fig_px.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(fig_px)
	_figures.append(fig)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.8), Color(UITheme.LINE, 0.45), Color(GiverFigure.AURA[giver], 0.18), 22, 18, 28))
	col.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var name_row := HBoxContainer.new()
	var giver_name := UITheme.label("GIVER_%s_NAME" % giver.to_upper(), 40, UITheme.BONE, "display")
	giver_name.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(giver_name)
	name_row.add_child(UITheme.label("GIVER_%s_ROLE" % giver.to_upper(), 14, GiverFigure.AURA[giver], "caps"))
	v.add_child(name_row)
	var line := UITheme.label("GIVER_%s_LINE" % giver.to_upper(), 20, UITheme.ASH, "italic")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(line)
	v.add_child(UITheme.rule(Color(UITheme.LINE, 0.5)))

	var lvl := GameState.level(giver)
	var up_row := HBoxContainer.new()
	var up_name := UITheme.label(GameState.upgrade_key(giver, weapon, "NAME"), 26, UITheme.GOLD)
	up_name.size_flags_horizontal = SIZE_EXPAND_FILL
	up_row.add_child(up_name)
	var lvl_label := UITheme.label(tr("UP_LEVEL") % (lvl + 1), 14, UITheme.ASH, "caps")
	lvl_label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	up_row.add_child(lvl_label)
	v.add_child(up_row)
	var desc := UITheme.label(GameState.upgrade_desc(giver, weapon, lvl + 1), 19, Color(UITheme.BONE, 0.85), "light")
	desc.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 84
	v.add_child(desc)
	if giver == "stolk":
		v.add_child(UITheme.label(tr("UP_STOLK_COST") % int(GameState.STOLK_HP_COST), 16, UITheme.EMBER, "caps"))

	var b := Button.new()
	b.text = "ASTRAL_ACCEPT"
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(_choose.bind(giver))
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func() -> void: fig.highlight = true)
	b.focus_exited.connect(func() -> void: fig.highlight = false)
	v.add_child(b)
	_buttons.append(b)
	return col


func _choose(giver: String) -> void:
	if _chosen:
		return
	_chosen = true
	GameState.add_upgrade(giver)
	GameState.dream_depth += 1
	Audio.play("giver_" + giver, -1.0)
	Audio.play("pickup", -4.0)
	Audio.play("astral", -2.0)
	var flash := ColorRect.new()
	flash.color = Color("f7f2ff")
	flash.modulate.a = 0.0
	add_child(flash)
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 1.0, 0.45)
	tw.tween_callback(GameState.change_scene.bind(RUN_SCENE))


# --- Piezas visuales / Visual pieces ------------------------------------------

## Personaje sobre una roca flotante / A character standing on a floating rock
class GiverFigure extends Control:
	const AURA := {"svinho": Color("9be38a"), "stolk": Color("ff8f9e"), "silly": Color("5ff2ff"), "doc": Color("ffe3a3")}
	var who := "svinho"
	var highlight := false
	var _t := 0.0
	var _glow := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		_t = randf() * 5.0

	func _process(delta: float) -> void:
		_t += delta
		_glow = move_toward(_glow, 1.0 if highlight else 0.0, delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		var s := minf(size.x / 200.0, size.y / 340.0) * 0.95
		var float_y := sin(_t * 1.1) * 8.0
		var origin := Vector2(size.x / 2.0 - 100.0 * s, size.y - 385.0 * s + float_y)
		var aura: Color = AURA[who]
		var c := origin + Vector2(100, 170) * s
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(150, 190) * s, Vector2(300, 380) * s), false, Color(aura, 0.12 + 0.18 * _glow))
		# Roca flotante con cristales / Floating rock with crystals
		var rock_c := origin + Vector2(100, 296) * s
		var top := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			top.append(rock_c + Vector2(cos(a) * 92.0, sin(a) * 18.0) * s)
		var under := PackedVector2Array([rock_c + Vector2(-92, 0) * s, rock_c + Vector2(-50, 40) * s, rock_c + Vector2(-10, 70) * s,
			rock_c + Vector2(20, 52) * s, rock_c + Vector2(60, 36) * s, rock_c + Vector2(92, 0) * s])
		draw_colored_polygon(under, Color("2a2a66"))
		draw_colored_polygon(PackedVector2Array([rock_c + Vector2(-20, 30) * s, rock_c + Vector2(-8, 82) * s, rock_c + Vector2(4, 30) * s]), Color(aura, 0.7))
		draw_colored_polygon(top, Color("4a4592"))
		draw_polyline(top + PackedVector2Array([top[0]]), Color(aura, 0.5), 1.5, true)
		NpcArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, origin), who, _t)


## Kroker flotando en el centro, con su arma / Kroker floating in the middle, with his weapon
class FloatingKroker extends Control:
	var outfit := "bat"
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := minf(size.x / 200.0, size.y / 380.0) * 1.1
		var y := size.y * 0.42 + sin(_t * 1.3) * 10.0
		var origin := Vector2(size.x / 2.0 - 100.0 * s, y - 150.0 * s)
		for i in 3:
			var a := _t * 0.8 + i * TAU / 3.0
			DreamBackground.draw_star(self, Vector2(size.x / 2.0, y) + Vector2(cos(a) * 90.0, sin(a) * 30.0), 2.5, Color(UITheme.GOLD, 0.8))
		KrokerArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, origin), outfit, _t, {"lean": sin(_t * 0.9) * 0.05})


## Cielo del plano astral: violeta y turquesa, cintas de nebulosa y fragmentos flotando
## Astral sky: violet and teal, nebula ribbons and floating shards
class AstralSky extends Control:
	var _t := 0.0
	var _shards: Array[Dictionary] = []
	var _stars: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		for i in 22:
			_shards.append({"p": Vector2(rng.randf(), rng.randf()), "s": rng.randf_range(6, 22), "r": rng.randf() * TAU,
				"v": rng.randf_range(-0.5, 0.5), "c": [Color("9be38a"), Color("ff8f9e"), Color("5ff2ff"), Color("f6d993")][i % 4]})
		for i in 260:
			_stars.append({"p": Vector2(rng.randf(), rng.randf()), "r": rng.randf_range(0.5, 2.0), "ph": rng.randf() * TAU})

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var top := Color("120c3a")
		var bot := Color("0d3a52")
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, bot, bot]))
		var soft := DreamBackground.soft_texture()
		# Cintas de nebulosa girando despacio / Slowly turning nebula ribbons
		for i in 3:
			draw_set_transform(Vector2(w * 0.5, h * 0.55), _t * 0.03 * (1 + i) + i * 1.3, Vector2.ONE)
			draw_texture_rect(soft, Rect2(-w * 0.7, -h * 0.08, w * 1.4, h * 0.16), false, Color([Color("8a5bd6"), Color("3fc1c9"), Color("e8a6d8")][i], 0.16))
		draw_set_transform(Vector2.ZERO)
		for s in _stars:
			var p: Vector2 = s["p"]
			draw_circle(Vector2(p.x * w, p.y * h), s["r"], Color(UITheme.BONE, 0.4 + 0.4 * sin(_t * 1.5 + float(s["ph"]))))
		# Fragmentos de sueño flotando / Floating dream shards
		for sh in _shards:
			var p: Vector2 = sh["p"]
			var pos := Vector2(p.x * w, fposmod(p.y * h - _t * 12.0, h + 40.0) - 20.0)
			var r := float(sh["r"]) + _t * float(sh["v"])
			var sz := float(sh["s"])
			var pts := PackedVector2Array([pos + Vector2.from_angle(r) * sz, pos + Vector2.from_angle(r + 2.2) * sz * 0.6, pos + Vector2.from_angle(r + 3.6) * sz * 0.8])
			draw_colored_polygon(pts, Color(sh["c"], 0.35))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(sh["c"], 0.6), 1.0, true)
