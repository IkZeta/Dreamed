extends Control
## Plano astral (el lobby, al estilo de Hades): un archipiélago de islas flotantes de piedra
## astral. En el centro está el cruce de los sueños, con su fuente de estrellas; a su alrededor,
## una isla por cada personaje que Kroker ya conoce, con un trozo de su mundo encima y él
## haciendo lo suyo. Se llega por puentes de piedras flotantes. Siempre están el armario con
## los pijamas y el museo con las estatuas de los enemigos (sustituye al bestiario).
## Astral plane (the lobby, Hades-style): an archipelago of floating islands of astral stone.
## In the middle is the dream crossing, with its star fountain; around it, one island per
## character Kroker has met, with a piece of their world on top and them doing their thing.
## You reach them over bridges of floating stones. The wardrobe with the pajamas and the
## museum with the enemy statues (it replaces the bestiary) are always there.
##
## El mundo se dibuja a media resolución (PixelView): un píxel del arte es un píxel de la
## pantalla de 960 x 540. Las islas salen de tools/make_hub.py y los muebles de tools/hub_props.py.
## The world is drawn at half resolution (PixelView): one art pixel is one pixel of the
## 960 x 540 screen. Islands come from tools/make_hub.py and furniture from tools/hub_props.py.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const RUN_SCENE := "res://scenes/run.tscn"
const SHRINK := 2
const PAJAMAS := AstralHubData.PAJAMAS

var _world: HubWorld
var _prompt: Label
var _hint: Label
var _zone: Label
var _zone_tw: Tween
var _box: PanelContainer
var _box_title: Label
var _box_role: Label
var _box_text: RichTextLabel
var _box_hearts: FriendHearts
var _portrait: TalkPortrait
var _portrait_view: PixelView
var _portrait_frame: PanelContainer
var _box_style: StyleBoxFlat
var _box_deco: BoxDeco
var _box_next: Label
var _typing := false
var _type_t := 0.0
const TYPE_SPEED := 55.0   # letras por segundo / letters per second
var _talking := {}
var _leaving := false
## Carta del pijama del soporte que tienes cerca / Card of the pajama on the stand you're near
var _card_slot: Control
var _card_id := ""
var _card_worn := false
## Ventana de empezar a soñar (en la fuente) / Start-dreaming window (at the fountain)
var _start_panel: Control
var _diff_btn: Button
var _pact_btn: Button
var _god_btn: Button
## Por personaje, qué frase toca la próxima vez / Per character, which line comes next time
var _line_idx := {}


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Audio.play_music("music_astral", 1.0)
	_world = HubWorld.new()
	_world.zone_entered.connect(_show_zone)
	var px := PixelView.wrap(_world, SHRINK)
	add_child(px)
	px.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Aviso para hablar, encima de quien tengas cerca / Talk prompt, above whoever is close
	_prompt = UITheme.label("", 18, UITheme.GOLD, "caps")
	_prompt.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)

	var title := UITheme.label("HUB_TITLE", 40, UITheme.BONE, "display")
	add_child(title)
	title.position = Vector2(56, 36)
	# Nombre del sitio al entrar en cada isla / Name of the place when entering each island
	_zone = UITheme.label("", 30, UITheme.BONE, "display")
	_zone.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone.modulate.a = 0.0
	add_child(_zone)
	_zone.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_zone.grow_horizontal = GROW_DIRECTION_BOTH
	_zone.position.y = 48
	_hint = UITheme.label("", 18, Color(UITheme.ASH, 0.9), "light")
	_hint.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = GROW_DIRECTION_BOTH
	_hint.position.y -= 44
	_refresh_hint()
	Settings.input_device_changed.connect(func(_p: bool) -> void: _refresh_hint())

	_build_box()
	_card_slot = Control.new()
	_card_slot.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_card_slot)
	if not Progress.any_cleared():
		GameState.difficulty = "normal"
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func _refresh_hint() -> void:
	if is_instance_valid(_hint):
		_hint.text = Settings.controls_text(tr("HUB_CONTROLS"))


## Cada isla con personaje tiene su tema; el resto del plano suena a plano astral
## Each island with a character has its own theme; the rest of the plane sounds astral
const THEMED := ["svinho", "stolk", "silly", "doc", "ad", "pinche", "charo", "magnus", "superk", "lilkey", "lynx"]


func _show_zone(id: String) -> void:
	Audio.play_music("music_" + id if id in THEMED else "music_astral", 2.0)
	_zone.text = "·  %s  ·" % tr("HUB_ZONE_" + id.to_upper())
	_zone.reset_size()
	if _zone_tw:
		_zone_tw.kill()
	_zone_tw = create_tween()
	_zone_tw.tween_property(_zone, "modulate:a", 1.0, 0.4)
	_zone_tw.tween_interval(1.8)
	_zone_tw.tween_property(_zone, "modulate:a", 0.0, 0.8)


## Recuadro de charla, abajo, al estilo de Celeste: marco con adornos en las esquinas, el texto
## que va saliendo letra a letra y, a la derecha, la cara del que habla en un marco cuadrado
## Talk box at the bottom, Celeste style: a frame with corner ornaments, text that appears letter
## by letter and, on the right, the speaker's face in a square frame
func _build_box() -> void:
	_box = PanelContainer.new()
	_box_style = UITheme.glow_box(Color("140f2e", 0.96), Color(UITheme.LINE, 0.9), Color(0, 0, 0, 0.35), 10, 4, 22)
	_box_style.border_width_left = 3
	_box_style.border_width_right = 3
	_box_style.border_width_top = 3
	_box_style.border_width_bottom = 3
	_box.add_theme_stylebox_override("panel", _box_style)
	add_child(_box)
	_box.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_box.custom_minimum_size = Vector2(1180, 236)
	_box.grow_horizontal = GROW_DIRECTION_BOTH
	_box.grow_vertical = GROW_DIRECTION_BEGIN
	_box.position.y -= 100
	_box.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_box.add_child(row)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	_box_title = UITheme.label("", 34, UITheme.BONE, "display")
	_box_title.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	head.add_child(_box_title)
	_box_role = UITheme.label("", 16, UITheme.ASH, "caps")
	_box_role.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_box_role.size_flags_vertical = SIZE_SHRINK_CENTER
	_box_role.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(_box_role)
	_box_hearts = FriendHearts.new(0, UITheme.GOLD, 16.0)
	_box_hearts.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(_box_hearts)
	v.add_child(UITheme.rule(Color(UITheme.LINE, 0.5)))
	_box_text = Keywords.label("", 30, UITheme.BONE, "body")
	_box_text.custom_minimum_size.x = 860
	_box_text.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(_box_text)
	_box_next = UITheme.label("", 14, Color(UITheme.ASH, 0.8), "caps")
	_box_next.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_box_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box_next.text = Settings.controls_text(tr("HUB_CLOSE"))
	v.add_child(_box_next)
	# La cara del que habla, en su marco / The speaker's face, in its frame
	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(192, 192)
	_portrait_frame.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(_portrait_frame)
	_portrait = TalkPortrait.new()
	_portrait_view = PixelView.wrap(_portrait, 3)
	_portrait_frame.add_child(_portrait_view)
	# Adornos de las esquinas, por encima del recuadro / Corner ornaments, over the box
	_box_deco = BoxDeco.new()
	_box_deco.mouse_filter = MOUSE_FILTER_IGNORE
	_box_deco.visible = false
	add_child(_box_deco)


## Pone el texto y lo va escribiendo / Sets the text and starts typing it out
func _type(text: String) -> void:
	Keywords.set_text(_box_text, text)
	_box_text.visible_characters = 0
	_type_t = 0.0
	_type_speed = Progress.REPEAT_SPEED if Progress.line_seen(text) else 1.0
	_typing = true
	_box_next.modulate.a = 0.0


var _type_speed := 1.0


func _update_typing(delta: float) -> void:
	if not _typing:
		return
	_type_t += delta
	var total := _box_text.get_total_character_count()
	var n := mini(total, int(_type_t * TYPE_SPEED * _type_speed))
	if n != _box_text.visible_characters:
		if n % 3 == 0 and not _talking.is_empty() and _talking["kind"] in ["npc", "chat"]:
			Audio.play("ui_click", -30.0, 0.2)
		_box_text.visible_characters = n
	_portrait.talking = true
	if n >= total:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_box_text.visible_characters = -1
	_portrait.talking = false
	# En una charla con más frases, «Seguir»; si no, «Cerrar» / In a chat with more lines, "Next"; otherwise "Close"
	var more: bool = not _talking.is_empty() and _talking["kind"] == "chat" and int(_talking["i"]) < (_talking["lines"] as Array).size() - 1
	_box_next.text = Settings.controls_text(tr("HUB_NEXT" if more else "HUB_CLOSE"))
	create_tween().tween_property(_box_next, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	_update_typing(delta)
	if _box_deco.visible:
		_box_deco.position = _box.position - Vector2(14, 14)
		_box_deco.size = _box.size + Vector2(28, 28)
	# Aviso encima de lo que tengas cerca / Prompt over whatever is close
	var spot := _world.near_spot()
	var busy := not _talking.is_empty() or _start_panel != null
	_update_card(spot if not busy else {})
	_place_card(spot)
	var text := _prompt_text(spot)
	_prompt.visible = not spot.is_empty() and not busy and text != ""
	if _prompt.visible:
		_prompt.text = text
		_prompt.reset_size()
		var p: Vector2 = _world.screen_of(spot["pos"] + Vector2(0, -float(spot.get("height", 80.0)))) * SHRINK
		_prompt.position = p - Vector2(_prompt.size.x / 2.0, _prompt.size.y)


## Qué dice el aviso según lo que tengas cerca / What the prompt says depending on what's close
func _prompt_text(spot: Dictionary) -> String:
	if spot.is_empty():
		return ""
	match spot["kind"]:
		"npc": return Settings.controls_text(tr("HUB_TALK"))
		"fountain": return Settings.controls_text(tr("HUB_DREAM"))
		"training": return Settings.controls_text(tr("HUB_TRAIN"))
		"album": return Settings.controls_text(tr("HUB_OPEN_ALBUM"))
		"chat": return Settings.controls_text(tr("HUB_LISTEN"))
		"pajama":
			if not GameState.weapon_unlocked(spot["id"]):
				return ""
			if GameState.selected_character == spot["id"]:
				return tr("HUB_WORN")
			return Settings.controls_text(tr("HUB_WEAR"))
	return Settings.controls_text(tr("HUB_LOOK"))


## La carta va al lado del soporte (a la derecha o, si no cabe, a la izquierda)
## The card sits beside the stand (to the right or, if it doesn't fit, to the left)
func _place_card(spot: Dictionary) -> void:
	if _card_id == "" or spot.is_empty() or _card_slot.get_child_count() == 0:
		return
	var card: Control = _card_slot.get_child(_card_slot.get_child_count() - 1)
	var at: Vector2 = _world.screen_of(spot["pos"]) * SHRINK
	var x := at.x + 70.0
	if x + PajamaCard.W > size.x - 16.0:
		x = at.x - 70.0 - PajamaCard.W
	var y := clampf(at.y - card.size.y * 0.62, 16.0, size.y - card.size.y - 16.0)
	_card_slot.position = Vector2(x, y).round()


## La carta del pijama sale al acercarte a su soporte / The pajama card appears when you walk up to its stand
func _update_card(spot: Dictionary) -> void:
	var id: String = spot["id"] if not spot.is_empty() and spot["kind"] == "pajama" else ""
	var worn := id != "" and GameState.selected_character == id
	if id == _card_id and worn == _card_worn:
		return
	_card_id = id
	_card_worn = worn
	for c in _card_slot.get_children():
		c.queue_free()
	if id == "":
		return
	var card := PajamaCard.build(GameState.get_character(id), worn)
	_card_slot.add_child(card)
	card.modulate.a = 0.0
	card.position.x = 30
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.tween_property(card, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _start_panel != null:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _typing:
			_finish_typing()
		elif not _talking.is_empty():
			# En una charla entre dos, la F pasa a la siguiente frase / In a two-person chat, F moves to the next line
			if _talking["kind"] == "chat" and int(_talking["i"]) < (_talking["lines"] as Array).size() - 1:
				_talking["i"] = int(_talking["i"]) + 1
				_chat_line()
			else:
				_close_box()
		else:
			var spot := _world.near_spot()
			if not spot.is_empty():
				_open(spot)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _talking.is_empty():
			_close_box()
		else:
			_leave()


## Abre la charla con un personaje, un pijama o una estatua / Opens the chat with a character, a pajama or a statue
func _open(spot: Dictionary) -> void:
	var id: String = spot["id"]
	match spot["kind"]:
		"pajama":
			_wear(id)
			return
		"fountain":
			_open_start()
			return
		"training":
			_go_training()
			return
		"album":
			_open_album()
			return
	_talking = spot
	_world.frozen = true
	_box_hearts.visible = false
	match spot["kind"]:
		"npc":
			_speaker(id)
			_type(_next_line(id))
			Audio.play("giver_" + id, -8.0)
		"chat":
			spot["i"] = 0
			Audio.play("giver_" + String(spot["host"]), -10.0)
			_chat_line()
		"statue":
			if Progress.has_seen(id):
				_box_title.text = tr("BEST_%s_NAME" % id.to_upper())
				_box_role.text = tr("BESTIARY_DEFEATED") % int(Progress.kills.get(id, 0))
				_type(tr("BEST_%s_DESC" % id.to_upper()))
			else:
				_box_title.text = "???"
				_box_role.text = ""
				_type(tr("HUB_EMPTY_PEDESTAL"))
			Audio.play("ui_click", -6.0)
	if not spot["kind"] in ["npc", "chat"]:
		_portrait_frame.visible = false
		_box_style.border_color = Color(UITheme.LINE, 0.9)
		_box_deco.color = UITheme.LINE
	_box.visible = true
	_box_deco.visible = true
	_box.modulate.a = 0.0
	_box_deco.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_box, "modulate:a", 1.0, 0.15)
	tw.tween_property(_box_deco, "modulate:a", 1.0, 0.15)


## Pone el recuadro a nombre de quien habla: nombre, papel, corazones, cara y color
## Sets the box to whoever is speaking: name, role, hearts, face and colour
func _speaker(id: String) -> void:
	_box_title.text = tr("CHARO_NAME") if id == "charo" else tr("GIVER_%s_NAME" % id.to_upper())
	_box_role.text = tr("CHARS_CHARO_ROLE") if id == "charo" else tr("GIVER_%s_ROLE" % id.to_upper())
	_box_hearts.visible = true
	_box_hearts.color = HubLayout.ISLES[id]["aura"]
	_box_hearts.set_level(Progress.friend_level(id))
	var aura: Color = HubLayout.ISLES[id]["aura"]
	_portrait.who = id
	_portrait.aura = aura
	_portrait.pop()
	_portrait_frame.visible = true
	_portrait_frame.add_theme_stylebox_override("panel", UITheme.box(aura.darkened(0.7), aura, 3, 4, 0.0))
	_box_style.border_color = Color(aura, 0.85)
	_box_deco.color = aura


## La frase que toca de una charla entre dos personajes / The current line of a chat between two characters
func _chat_line() -> void:
	var line: Array = (_talking["lines"] as Array)[int(_talking["i"])]
	_speaker(line[0])
	_type(tr(line[1]))


## Cada vez que hablas con alguien dice otra cosa, de las que ya te ha contado por amistad
## Each time you talk to someone they say something else, from what friendship has unlocked
func _next_line(id: String) -> String:
	# Primero, qué tal fue el último sueño / First, how the last dream went
	var react := Progress.run_reaction(id)
	if react != "":
		Progress.save_progress()
		return react
	var lines: Array[String] = []
	var lvl := Progress.friend_level(id)
	if id == "charo":
		lines.append("SHOP_HELLO")
		for i in range(1, lvl + 1):
			lines.append("SHOP_HELLO_%d" % i)
	else:
		lines.append("TALK_%s_INTRO" % id.to_upper())
		for i in range(0, lvl + 1):
			lines.append("TALK_%s_%d" % [id.to_upper(), i])
	var i: int = int(_line_idx.get(id, randi() % lines.size())) % lines.size()
	_line_idx[id] = i + 1
	return tr(lines[i])


func _close_box() -> void:
	_talking = {}
	_box.visible = false
	_box_deco.visible = false
	_typing = false
	_world.frozen = false


## El álbum de pegatinas del diario, en el atril junto a la fuente / The diary's sticker album, on the lectern by the fountain
func _open_album() -> void:
	_world.frozen = true
	Audio.play("fluff", -6.0)
	var album := StickerAlbum.make()
	add_child(album)
	_start_panel = album
	album.closed.connect(_close_start)


## Ponerse un pijama del armario / Put on a pajama from the wardrobe
func _wear(id: String) -> void:
	if not GameState.weapon_unlocked(id) or GameState.selected_character == id:
		return
	GameState.selected_character = id
	Audio.play("pickup", -6.0)
	Audio.play("fluff", -10.0)
	_world.poof()


## La fuente: ventana para empezar a soñar con el pijama puesto, la dificultad y el modo Dios
## The fountain: window to start dreaming in the pajama you're wearing, the difficulty and god mode
func _open_start() -> void:
	_world.frozen = true
	Audio.play("chime", -8.0)
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_start_panel = dim
	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.96), Color(UITheme.GOLD, 0.7), Color(UITheme.GOLD, 0.12), 18, 28, 34))
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size.x = 640
	box.add_child(v)
	v.add_child(UITheme.label("HUB_START_TITLE", 44, UITheme.BONE, "display"))
	var data := GameState.get_character(GameState.selected_character)
	var who := UITheme.label("", 22, UITheme.GOLD, "caps")
	who.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	who.text = "%s  ·  %s" % [tr(data["name"]), tr(data["weapon"])]
	v.add_child(who)
	var change := UITheme.label("HUB_START_CHANGE", 18, Color(UITheme.ASH, 0.85), "italic")
	change.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(change)
	v.add_child(UITheme.rule(Color(UITheme.LINE, 0.6)))
	var buttons: Array[Button] = []
	# Dificultad: la pesadilla se desbloquea al superar el Acto 1 / Difficulty: nightmare unlocks after clearing Act 1
	if Progress.any_cleared():
		_diff_btn = Button.new()
		_diff_btn.custom_minimum_size = Vector2(0, 60)
		_diff_btn.pressed.connect(func() -> void:
			GameState.difficulty = "normal" if GameState.difficulty == "nightmare" else "nightmare"
			_update_start_buttons())
		v.add_child(_diff_btn)
		buttons.append(_diff_btn)
	# Fiebre (pactos) y sueño del día: tras superar el Acto 1 / Fever (pacts) and daily dream: after clearing Act 1
	if GameState.pacts_unlocked():
		_pact_btn = Button.new()
		_pact_btn.custom_minimum_size = Vector2(0, 60)
		_pact_btn.pressed.connect(func() -> void:
			var panel := PactPanel.new()
			panel.closed.connect(func() -> void:
				_update_start_buttons()
				_pact_btn.grab_focus())
			add_child(panel))
		v.add_child(_pact_btn)
		buttons.append(_pact_btn)
		var d := GameState.daily_setup()
		var daily := Button.new()
		daily.custom_minimum_size = Vector2(0, 60)
		daily.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		var names: Array[String] = []
		for id: String in d["pacts"]:
			names.append(tr("PACT_" + id.to_upper()))
		var best := Progress.daily_best(d["date"])
		daily.text = tr("DAILY_BUTTON") % [tr("WEAPON_SHORT_" + str(d["weapon"]).to_upper()), ", ".join(names)] \
			+ ("" if best <= 0 else "  ·  " + tr("DAILY_BEST") % best)
		daily.add_theme_color_override("font_color", UITheme.MIST)
		daily.pressed.connect(_start_daily)
		v.add_child(daily)
		buttons.append(daily)
	# Modo Dios para probar (no en la demo) / God mode for testing (not in the demo)
	if not Demo.on():
		_god_btn = Button.new()
		_god_btn.custom_minimum_size = Vector2(0, 60)
		_god_btn.pressed.connect(func() -> void:
			var panel := GodPanel.new()
			panel.weapon = GameState.selected_character
			panel.closed.connect(func() -> void:
				_update_start_buttons()
				_god_btn.grab_focus())
			add_child(panel))
		v.add_child(_god_btn)
		buttons.append(_god_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var cancel := Button.new()
	cancel.text = "SAC_CANCEL"
	cancel.custom_minimum_size = Vector2(240, 64)
	cancel.pressed.connect(_close_start)
	row.add_child(cancel)
	var go := Button.new()
	go.text = "BTN_START"
	go.custom_minimum_size = Vector2(0, 64)
	go.size_flags_horizontal = SIZE_EXPAND_FILL
	go.pressed.connect(_start_dream)
	row.add_child(go)
	for b in buttons + [cancel, go]:
		b.mouse_entered.connect(b.grab_focus)
	_update_start_buttons()
	go.grab_focus.call_deferred()


func _update_start_buttons() -> void:
	if is_instance_valid(_pact_btn):
		var f := 0
		for id: String in GameState.pact_pick():
			f += int(GameState.PACTS.get(id, 0))
		_pact_btn.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		_pact_btn.text = tr("PACT_BUTTON") % GameState.fever_temp(f) if f > 0 else tr("PACT_BUTTON_OFF")
		_pact_btn.add_theme_color_override("font_color", UITheme.EMBER if f > 0 else UITheme.ASH)
	if is_instance_valid(_diff_btn):
		_diff_btn.text = "DIFF_BUTTON_" + GameState.difficulty.to_upper()
		_diff_btn.add_theme_color_override("font_color", UITheme.EMBER if GameState.difficulty == "nightmare" else UITheme.ASH)
	if is_instance_valid(_god_btn):
		_god_btn.text = "GOD_BUTTON_ON" if GameState.god_mode else "GOD_BUTTON"
		_god_btn.add_theme_color_override("font_color", UITheme.GOLD if GameState.god_mode else UITheme.ASH)


func _close_start() -> void:
	if _start_panel:
		_start_panel.queue_free()
		_start_panel = null
	_world.frozen = false


func _input(event: InputEvent) -> void:
	# Con la ventana de la fuente abierta, Esc la cierra / With the fountain window open, Esc closes it
	if _start_panel != null and event.is_action_pressed("ui_cancel") and get_children().filter(func(c: Node) -> bool: return c is GodPanel or c is PactPanel).is_empty():
		get_viewport().set_input_as_handled()
		_close_start()


## Sueño del día: pijama, pactos y semilla de hoy / Daily dream: today's pajama, pacts and seed
func _start_daily() -> void:
	_leaving = true
	GameState.start_daily()
	Audio.play("astral", -4.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(GameState.change_scene.bind(RUN_SCENE))


func _start_dream() -> void:
	_leaving = true
	GameState.start_run()
	Audio.play("astral", -4.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(GameState.change_scene.bind(RUN_SCENE))


## El muñeco de pruebas: una partida de entrenamiento con el pijama puesto
## The practice dummy: a training run in the pajama you're wearing
func _go_training() -> void:
	_leaving = true
	GameState.reset_run()
	GameState.training = true
	Audio.play("astral", -6.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(GameState.change_scene.bind(RUN_SCENE))


func _leave() -> void:
	_leaving = true
	Audio.play("ui_click", -4.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(GameState.change_scene.bind(MAIN_MENU))


# --- Piezas / Pieces -------------------------------------------------------------
