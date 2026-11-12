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
var _content: Control
## Con dos armas, para cuál es el don de cada personaje / With two weapons, which one each giver's gift goes to
var _target := {}
## Pantalla de charla con el personaje elegido / Talk screen with the chosen character
var _talk_text: RichTextLabel
var _talk_prompt: Label
var _talk_t := -1.0
var _leaving := false
var _talk_giver := ""
var _talk_buttons: HBoxContainer
var _tip_button: Button
var _hearts: FriendHearts
var _first_talk := false
## Trato que ofrece Magnus, si sale / Deal Magnus offers, if he shows up
var _deal := {}
## Mejora dúo que se ofrece, si sale / Duo upgrade on offer, if there is one
var _duo := ""


func _ready() -> void:
	theme = UITheme.build()
	Audio.play_music("music_astral", 1.5)
	_offer = GameState.pick_offer()
	if "duo" in _offer:
		_duo = GameState.duo_ready()
	# Quedan conocidos para el menú de personajes / They count as met for the characters menu
	for g in _offer:
		Progress.stats["met_" + g] = 1
	Progress.save_progress()
	_build()
	# Sale del destello blanco del final del sueño / Fades out of the end-of-dream flash
	var flash := ColorRect.new()
	flash.color = Color("f7f2ff") if not Settings.reduce_flashes else Color("3a3570")
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(flash.queue_free)
	# Cada personaje se presenta con su propio tema / Each character introduces itself with its own motif
	for i in _offer.size():
		var motif: String = "giver_" + (GameState.DUOS[_duo]["a"] if _offer[i] == "duo" else _offer[i])
		get_tree().create_timer(0.5 + i * 1.1).timeout.connect(Audio.play.bind(motif, -8.0))
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _build() -> void:
	var sky := PixelView.wrap(AstralSky.new(), 2)
	add_child(sky)
	sky.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	_content = margin
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var three := _offer.size() >= 3
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60 if three else 120)
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
		var col := _offer_column(_offer[i], weapon)
		if three:
			col.custom_minimum_size.x = 540
		row.add_child(col)
		# Con tres personajes no queda sitio para Kroker en medio / With three characters there's no room for Kroker in the middle
		if i == 0 and not three:
			# Kroker flota en medio, esperando / Kroker floats in the middle, waiting
			var k := FloatingKroker.new()
			k.outfit = weapon
			var k_px := PixelView.wrap(k, 3)
			k_px.custom_minimum_size = Vector2(260, 0)
			row.add_child(k_px)


func _offer_column(giver: String, weapon: String) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(540, 0)
	col.add_theme_constant_override("separation", 6)

	var fig := GiverFigure.new()
	fig.who = giver
	fig.duo = _duo
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

	if giver == "duo":
		_duo_card(v, fig)
		return col
	# Si el nombre es largo, el papel baja a la línea siguiente / If the name is long, the role drops to the next line
	var name_row := HFlowContainer.new()
	name_row.add_theme_constant_override("h_separation", 12)
	var giver_name := UITheme.label("GIVER_%s_NAME" % giver.to_upper(), 40, UITheme.BONE, "display")
	giver_name.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(giver_name)
	name_row.add_child(UITheme.label("GIVER_%s_ROLE" % giver.to_upper(), 14, GiverFigure.AURA[giver], "caps"))
	v.add_child(name_row)
	var line := UITheme.label("GIVER_%s_LINE" % giver.to_upper(), 20, UITheme.ASH, "italic")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(line)
	# Amistad con este personaje / Friendship with this character
	v.add_child(FriendHearts.new(Progress.friend_level(giver), GiverFigure.AURA[giver], 14.0))
	v.add_child(UITheme.rule(Color(UITheme.LINE, 0.5)))
	if giver == "magnus":
		_deal_card(v, fig)
		return col

	# Con dos armas, pestañas para elegir a cuál va el don / With two weapons, tabs to pick which one gets the gift
	var weapons := GameState.weapons()
	_target[giver] = weapon
	for w in weapons:
		if GameState.level(giver, w) < GameState.max_level(giver, w):
			_target[giver] = w
			break
	var up_row := HBoxContainer.new()
	var up_name := UITheme.label("", 26, UITheme.GOLD)
	up_name.size_flags_horizontal = SIZE_EXPAND_FILL
	up_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	up_name.custom_minimum_size.x = 1
	up_row.add_child(up_name)
	var lvl_label := UITheme.label("", 14, UITheme.ASH, "caps")
	lvl_label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	up_row.add_child(lvl_label)
	var desc := Keywords.label("", 19, Color(UITheme.BONE, 0.85), "light")
	desc.custom_minimum_size.y = 84
	# Si al cogerla se completa un combo, se avisa / If taking it completes a combo, say so
	var combo := Keywords.label("", 17, Color("ff9ad0"), "caps")
	var refresh := func() -> void:
		var w: String = _target[giver]
		var done := GameState.combos_completed_by(giver, w)
		combo.visible = not done.is_empty()
		if not done.is_empty():
			var names := PackedStringArray()
			for id in done:
				names.append(tr("COMBO_%s_NAME" % id.to_upper()))
			Keywords.set_text(combo, "» " + tr("COMBO_HINT").format({"names": ", ".join(names)}))
		var lvl := GameState.level(giver, w)
		var legend := lvl + 1 >= GameState.LEGEND_LEVEL
		up_name.text = tr(GameState.upgrade_key(giver, w, "NAME"))
		lvl_label.text = tr("UP_LEGEND") if legend else tr("UP_LEVEL") % (lvl + 1)
		lvl_label.add_theme_color_override("font_color", UITheme.GOLD if legend else UITheme.ASH)
		up_name.add_theme_color_override("font_color", Color("ffd36a") if legend else UITheme.GOLD)
		Keywords.set_text(desc, GameState.upgrade_desc(giver, w, lvl + 1))
	if weapons.size() > 1:
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 8)
		var group := ButtonGroup.new()
		for w in weapons:
			var t := Button.new()
			t.toggle_mode = true
			t.button_group = group
			t.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
			var lvl_w := GameState.level(giver, w)
			# En dos líneas (arma y nivel) y sin ensanchar la tarjeta: con nombres largos como
			# «Botas Propulsoras» las tres tarjetas se salían de la pantalla
			# On two lines (weapon and level) without widening the card: with long names such as
			# "Botas Propulsoras" the three cards spilled off the screen
			t.text = "%s\n%s" % [tr("WEAPON_SHORT_" + w.to_upper()), tr("UP_LEVEL") % lvl_w if lvl_w > 0 else tr("ASTRAL_NEW")]
			t.size_flags_horizontal = SIZE_EXPAND_FILL
			t.size_flags_stretch_ratio = 1.0
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			t.custom_minimum_size = Vector2(1, 64)
			t.disabled = lvl_w >= GameState.max_level(giver, w)
			t.button_pressed = w == _target[giver]
			t.toggled.connect(func(on: bool) -> void:
				if on:
					_target[giver] = w
					refresh.call())
			t.mouse_entered.connect(t.grab_focus)
			tabs.add_child(t)
		v.add_child(tabs)
	v.add_child(up_row)
	v.add_child(desc)
	v.add_child(combo)
	refresh.call()
	if giver == "stolk":
		v.add_child(UITheme.label(tr("UP_STOLK_COST") % int(GameState.STOLK_HP_COST), 16, UITheme.EMBER, "caps"))

	var b := Button.new()
	b.text = "ASTRAL_ACCEPT"
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(_choose.bind(giver))
	Keywords.on_focus(b, desc)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func() -> void: fig.highlight = true)
	b.focus_exited.connect(func() -> void: fig.highlight = false)
	v.add_child(b)
	_buttons.append(b)
	return col


## Magnus no da mejora: propone un trato / Magnus gives no upgrade: he proposes a deal
func _deal_card(v: VBoxContainer, fig: GiverFigure) -> void:
	_deal = MagnusDeals.roll_deal()
	var up_row := HBoxContainer.new()
	var title := UITheme.label("INVEST_TITLE", 26, UITheme.GOLD)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	up_row.add_child(title)
	v.add_child(up_row)
	# Las mejoras que da, una por línea / The boosts it gives, one per line
	var boosts := Keywords.label("", 18, GiverFigure.AURA["magnus"], "caps")
	Keywords.set_text(boosts, MagnusDeals.deal_boosts_text(_deal, "\n"))
	v.add_child(boosts)
	var desc := Keywords.label("", 19, Color(UITheme.BONE, 0.85), "light")
	desc.custom_minimum_size.y = 84
	Keywords.set_text(desc, tr("INVEST_DESC").format({
		"cost": _deal["cost"], "payout": _deal["payout"], "goal": MagnusDeals.deal_goal_text(_deal),
		"n": _deal["boosts"].size()}))
	v.add_child(desc)
	var b := Button.new()
	b.text = tr("INVEST_ACCEPT").format({"cost": _deal["cost"]})
	b.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(_choose.bind("magnus"))
	Keywords.on_focus(b, desc)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func() -> void: fig.highlight = true)
	b.focus_exited.connect(func() -> void: fig.highlight = false)
	v.add_child(b)
	_buttons.append(b)


## Mejora dúo: los dos personajes juntos y su mejora compartida / Duo upgrade: both characters together and their shared upgrade
func _duo_card(v: VBoxContainer, fig: GiverFigure) -> void:
	var d: Dictionary = GameState.DUOS[_duo]
	var name_row := HFlowContainer.new()
	name_row.add_theme_constant_override("h_separation", 12)
	var names := UITheme.label("%s & %s" % [tr("GIVER_%s_NAME" % String(d["a"]).to_upper()), tr("GIVER_%s_NAME" % String(d["b"]).to_upper())], 36, UITheme.BONE, "display")
	names.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(names)
	name_row.add_child(UITheme.label("DUO_ROLE", 14, GiverFigure.AURA["duo"], "caps"))
	v.add_child(name_row)
	var line := UITheme.label("DUO_%s_LINE" % _duo.to_upper(), 20, UITheme.ASH, "italic")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(line)
	v.add_child(UITheme.rule(Color(UITheme.LINE, 0.5)))
	var up_row := HBoxContainer.new()
	var up_name := UITheme.label("DUO_%s_NAME" % _duo.to_upper(), 26, UITheme.GOLD)
	up_name.size_flags_horizontal = SIZE_EXPAND_FILL
	up_row.add_child(up_name)
	var tag := UITheme.label("DUO_TAG", 14, GiverFigure.AURA["duo"], "caps")
	up_row.add_child(tag)
	v.add_child(up_row)
	var desc := Keywords.label("", 19, Color(UITheme.BONE, 0.85), "light")
	desc.custom_minimum_size.y = 84
	Keywords.set_text(desc, GameState.duo_desc(_duo))
	v.add_child(desc)
	var b := Button.new()
	b.text = "ASTRAL_ACCEPT"
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(_choose.bind("duo"))
	Keywords.on_focus(b, desc)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func() -> void: fig.highlight = true)
	b.focus_exited.connect(func() -> void: fig.highlight = false)
	v.add_child(b)
	_buttons.append(b)


func _choose(giver: String) -> void:
	if _chosen:
		return
	_chosen = true
	if giver == "magnus":
		MagnusDeals.sign_deal(_deal)
	elif giver == "duo":
		GameState.add_duo(_duo)
	else:
		GameState.add_upgrade(giver, _target.get(giver, ""))
	GameState.check_combos()
	GameState.dream_depth += 1
	# Suena su leitmotiv, claro: la música baja un momento para dejarle sitio (en el dúo, los dos)
	# Their leitmotif plays, clearly: the music dips for a moment to make room for it (for a duo, both)
	if giver == "duo":
		Audio.leitmotif(GameState.DUOS[_duo]["a"])
		get_tree().create_timer(1.3).timeout.connect(Audio.play.bind("giver_" + GameState.DUOS[_duo]["b"], 1.0))
	else:
		Audio.leitmotif(giver)
	get_tree().create_timer(1.6).timeout.connect(Audio.play.bind("astral", -10.0))
	for b in _buttons:
		b.disabled = true
	# Se van los demás y queda solo el elegido, que te habla
	# The others fade away and only the chosen one is left, talking to you
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_talk_scene.bind(giver))


## Pantalla de charla: el personaje grande a un lado y lo que dice al otro. Lo que cuenta depende
## de la amistad, y se le puede dar propina con Realidad Fragmentada para subirla.
## Talk screen: the character large on one side and what they say on the other. What they tell
## you depends on friendship, which you can raise by tipping them Fragmented Reality.
func _talk_scene(giver: String) -> void:
	_content.visible = false
	var aura: Color = GiverFigure.AURA[giver]
	var talk := Control.new()
	talk.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(talk)
	talk.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var fig := GiverFigure.new()
	fig.who = giver
	fig.duo = _duo
	fig.highlight = true
	var fig_px := PixelView.wrap(fig, 4)
	talk.add_child(fig_px)
	fig_px.position = Vector2(140, 110)
	fig_px.size = Vector2(640, 860)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	talk.add_child(col)
	col.position = Vector2(860, 250)
	col.size = Vector2(920, 560)
	var is_duo := giver == "duo"
	var name_l: Label
	if is_duo:
		var d: Dictionary = GameState.DUOS[_duo]
		name_l = UITheme.label("%s & %s" % [tr("GIVER_%s_NAME" % String(d["a"]).to_upper()), tr("GIVER_%s_NAME" % String(d["b"]).to_upper())], 64, aura, "display")
		name_l.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	else:
		name_l = UITheme.label("GIVER_%s_NAME" % giver.to_upper(), 84, aura, "display")
	col.add_child(name_l)
	col.add_child(UITheme.label("DUO_ROLE" if is_duo else "GIVER_%s_ROLE" % giver.to_upper(), 24, UITheme.ASH, "caps"))
	col.add_child(UITheme.rule(Color(aura, 0.5)))
	var weapon: String = _target.get(giver, GameState.selected_character)
	var gift_text: String
	if giver == "magnus":
		gift_text = tr("INVEST_SIGNED").format({"goal": MagnusDeals.deal_goal_text(_deal)})
	elif is_duo:
		gift_text = tr("DUO_GIFT").format({"up": tr("DUO_%s_NAME" % _duo.to_upper())})
	else:
		gift_text = tr("ASTRAL_GIFT").format({"up": tr(GameState.upgrade_key(giver, weapon, "NAME")), "lvl": GameState.level(giver, weapon)})
		# Con dos armas se dice para cuál es / With two weapons, say which one it's for
		if GameState.weapons().size() > 1:
			gift_text += " · " + tr("WEAPON_SHORT_" + weapon.to_upper())
	var gift := UITheme.label(gift_text, 24, UITheme.GOLD, "caps")
	gift.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(gift)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.92), Color(aura, 0.8), Color(aura, 0.16), 18, 14, 28))
	box.custom_minimum_size = Vector2(920, 240)
	col.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	_talk_text = RichTextLabel.new()
	_talk_text.bbcode_enabled = true
	_talk_text.fit_content = true
	_talk_text.scroll_active = false
	_talk_text.size_flags_vertical = SIZE_EXPAND_FILL
	_talk_text.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_talk_text.add_theme_font_override("normal_font", UITheme.font("italic"))
	_talk_text.add_theme_font_size_override("normal_font_size", UITheme.pixel_size(36))
	_talk_text.add_theme_color_override("default_color", UITheme.BONE)
	_talk_text.add_theme_constant_override("line_separation", 8)
	_talk_text.mouse_filter = MOUSE_FILTER_IGNORE
	_talk_giver = giver
	# Primera vez: presentación y sin propina. Luego, lo que toque según la amistad.
	# First time: introduction and no tip. After that, whatever friendship calls for.
	_first_talk = false if is_duo else Progress.first_talk(giver)
	if is_duo:
		_set_talk(tr("DUO_%s_TALK" % _duo.to_upper()))
	elif _first_talk:
		_set_talk(tr("TALK_%s_INTRO" % giver.to_upper()))
		Progress.mark_talked(giver)
	else:
		_set_talk(tr("TALK_%s_%d" % [giver.to_upper(), Progress.friend_level(giver)]))
	_talk_text.visible_ratio = 0.0
	v.add_child(_talk_text)
	_talk_prompt = UITheme.label("DIALOGUE_NEXT", 14, Color(UITheme.ASH, 0.8), "caps")
	_talk_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_talk_prompt.modulate.a = 0.0
	v.add_child(_talk_prompt)

	# Amistad y propina / Friendship and tip
	var friend_row := HBoxContainer.new()
	friend_row.add_theme_constant_override("separation", 14)
	col.add_child(friend_row)
	var fl := UITheme.label("FRIENDSHIP", 18, UITheme.ASH, "caps")
	fl.size_flags_vertical = SIZE_SHRINK_CENTER
	friend_row.add_child(fl)
	_hearts = FriendHearts.new(Progress.friend_level(giver), aura, 22.0)
	friend_row.add_child(_hearts)
	friend_row.visible = not is_duo
	_talk_buttons = HBoxContainer.new()
	_talk_buttons.add_theme_constant_override("separation", 20)
	_talk_buttons.modulate.a = 0.0
	col.add_child(_talk_buttons)
	_tip_button = Button.new()
	_tip_button.custom_minimum_size = Vector2(450, 60)
	_tip_button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_tip_button.pressed.connect(_tip)
	_tip_button.mouse_entered.connect(_tip_button.grab_focus)
	_tip_button.visible = GameState.reality_on() and not _first_talk and not is_duo
	_talk_buttons.add_child(_tip_button)
	var go := Button.new()
	go.text = "TALK_CONTINUE"
	go.custom_minimum_size = Vector2(300, 60)
	go.pressed.connect(func() -> void: if not _leaving: _leave())
	go.mouse_entered.connect(go.grab_focus)
	_talk_buttons.add_child(go)
	_refresh_tip()

	talk.modulate.a = 0.0
	create_tween().tween_property(talk, "modulate:a", 1.0, 0.4)
	_talk_t = 0.0


var _talk_speed := 1.0


func _process(delta: float) -> void:
	if _talk_t < 0.0 or _leaving:
		return
	_talk_t += delta
	var total := maxi(1, _talk_text.get_total_character_count())
	var before := _talk_text.visible_ratio
	_talk_text.visible_ratio = minf(1.0, _talk_t * CharoDialogue.CPS * _talk_speed / total)
	if _talk_text.visible_ratio < 1.0 and int(_talk_t * 12.0) != int((_talk_t - delta) * 12.0) and before < 1.0:
		Audio.play("ui_hover", -22.0, 0.15)
	_talk_prompt.modulate.a = 0.0
	# Al acabar de hablar aparecen los botones / When they finish talking the buttons appear
	if _talk_text.visible_ratio >= 1.0 and _talk_buttons.modulate.a < 1.0:
		if _talk_buttons.modulate.a == 0.0:
			var first: Button = _tip_button if _tip_button.visible and not _tip_button.disabled else _talk_buttons.get_child(1)
			first.grab_focus()
		_talk_buttons.modulate.a = minf(1.0, _talk_buttons.modulate.a + delta * 4.0)


func _input(event: InputEvent) -> void:
	if _talk_t < 0.3 or _leaving:
		return
	var press: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not press:
		return
	# Con el texto entero, mandan los botones / With the full text shown, the buttons are in charge
	if _talk_text.visible_ratio >= 1.0:
		return
	get_viewport().set_input_as_handled()
	_talk_t = 1000.0
	_talk_text.visible_ratio = 1.0


## Pone lo que dice el personaje; los textos largos (como el binario de Silly) van con letra más pequeña para que quepan
## Sets what the character says; long texts (like Silly's binary) use a smaller font so they fit
func _set_talk(text: String) -> void:
	_talk_text.text = text
	_talk_speed = Progress.REPEAT_SPEED if Progress.line_seen(text) else 1.0
	var n := text.length()
	var px := 36 if n <= 150 else (28 if n <= 230 else 20)
	_talk_text.add_theme_font_size_override("normal_font_size", UITheme.pixel_size(px))


func _refresh_tip() -> void:
	var g := _talk_giver
	if not Progress.can_tip(g):
		_tip_button.text = tr("TIP_MAX")
		_tip_button.disabled = true
	elif GameState.tipped.has(g):
		_tip_button.text = tr("TIP_DONE")
		_tip_button.disabled = true
	elif GameState.reality < Progress.tip_cost(g):
		_tip_button.text = tr("TIP_SHORT").format({"n": Progress.tip_cost(g) - GameState.reality})
		_tip_button.disabled = true
	else:
		_tip_button.text = tr("TIP_BUTTON").format({"cost": Progress.tip_cost(g)})
		_tip_button.disabled = false


## Propina (una por personaje y partida): sube la amistad y te da las gracias. Lo nuevo que
## tenga que contarte lo dirá la próxima vez que lo veas.
## Tip (one per character per run): raises friendship and they thank you. Whatever new thing
## they have to tell you, they'll say it the next time you meet.
func _tip() -> void:
	var g := _talk_giver
	if _first_talk or GameState.tipped.has(g) or _leaving or not Progress.can_tip(g) or GameState.reality < Progress.tip_cost(g):
		return
	GameState.add_reality(-Progress.tip_cost(g))
	Progress.add_friend(g)
	GameState.tipped[g] = true
	_hearts.set_level(Progress.friend_level(g))
	Audio.play("reality", -2.0)
	Audio.play("giver_" + g, -3.0)
	_set_talk(tr("TALK_%s_THANKS" % g.to_upper()))
	_talk_text.visible_ratio = 0.0
	_talk_t = 0.0
	_talk_buttons.modulate.a = 0.0
	_refresh_tip()


## Destello y al siguiente sueño / Flash, then on to the next dream
func _leave() -> void:
	_leaving = true
	Audio.play("astral", -4.0)
	var flash := ColorRect.new()
	flash.color = Color("f7f2ff") if not Settings.reduce_flashes else Color("3a3570")
	flash.modulate.a = 0.0
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 1.0, 0.45)
	tw.tween_callback(GameState.change_scene.bind(RUN_SCENE))


# --- Piezas visuales / Visual pieces ------------------------------------------

## Personaje sobre una roca flotante / A character standing on a floating rock
class GiverFigure extends Control:
	const AURA := {"svinho": Color("9be38a"), "stolk": Color("ff8f9e"), "silly": Color("5ff2ff"), "doc": Color("ffe3a3"), "ad": Color("ffb04a"), "pinche": Color("ff9a3a"), "magnus": Color("4fd39a"), "superk": Color("b48cff"), "lilkey": Color("ff6a8a"), "lynx": Color("e0303a"), "luna": Color("c9d4ff"), "duo": Color("f6d993")}
	var who := "svinho"
	var duo := ""
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
		if who == "duo" and duo != "":
			# Los dos juntos, un poco más pequeños, sobre la misma roca / Both together, a bit smaller, on the same rock
			var d: Dictionary = GameState.DUOS[duo]
			var k := s * 0.78
			for i in 2:
				var o := rock_c + Vector2((-46.0 if i == 0 else 46.0) * s, -2.0 * s) - Vector2(100, 288) * k
				var bob := sin(_t * 1.1 + i * 1.7) * 3.0 * s
				var g: String = d["a"] if i == 0 else d["b"]
				draw_texture_rect(DreamBackground.soft_texture(), Rect2(o + Vector2(-20, 40) * k, Vector2(240, 300) * k), false, Color(AURA[g], 0.12 + 0.12 * _glow))
				NpcArt.draw(self, Transform2D(0.0, Vector2(k * (-1.0 if i == 1 else 1.0), k), 0.0, o + Vector2(200.0 * k if i == 1 else 0.0, bob)), g, _t)
			return
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
		KrokerArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, origin), outfit, _t, {"lean": sin(_t * 0.9) * 0.05, "hires": true})


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
