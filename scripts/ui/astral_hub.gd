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
const PAJAMAS: Array[String] = ["bat", "shield", "book", "vacuum", "finger", "teddy", "ball", "laptop", "boots"]

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
var _talking := {}
var _leaving := false
## Carta del pijama del soporte que tienes cerca / Card of the pajama on the stand you're near
var _card_slot: Control
var _card_id := ""
var _card_worn := false
## Ventana de empezar a soñar (en la fuente) / Start-dreaming window (at the fountain)
var _start_panel: Control
var _diff_btn: Button
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
	_card_slot.position = Vector2(1920 - PajamaCard.W - 64, 150)
	if not Progress.any_cleared():
		GameState.difficulty = "normal"
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func _refresh_hint() -> void:
	if is_instance_valid(_hint):
		_hint.text = Settings.controls_text(tr("HUB_CONTROLS"))


func _show_zone(id: String) -> void:
	_zone.text = "·  %s  ·" % tr("HUB_ZONE_" + id.to_upper())
	_zone.reset_size()
	if _zone_tw:
		_zone_tw.kill()
	_zone_tw = create_tween()
	_zone_tw.tween_property(_zone, "modulate:a", 1.0, 0.4)
	_zone_tw.tween_interval(1.8)
	_zone_tw.tween_property(_zone, "modulate:a", 0.0, 0.8)


## Recuadro de charla, abajo / Talk box, at the bottom
func _build_box() -> void:
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.94), Color(UITheme.LINE, 0.8), Color(UITheme.MIST, 0.12), 18, 16, 26))
	add_child(_box)
	_box.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_box.custom_minimum_size = Vector2(1100, 220)
	_box.grow_horizontal = GROW_DIRECTION_BOTH
	_box.grow_vertical = GROW_DIRECTION_BEGIN
	_box.position.y -= 90
	_box.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_box.add_child(v)
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
	_box_text = Keywords.label("", 24, UITheme.BONE, "italic")
	_box_text.custom_minimum_size.x = 1040
	v.add_child(_box_text)
	var next := UITheme.label("", 14, Color(UITheme.ASH, 0.8), "caps")
	next.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next.text = Settings.controls_text(tr("HUB_CLOSE"))
	v.add_child(next)


func _process(_delta: float) -> void:
	# Aviso encima de lo que tengas cerca / Prompt over whatever is close
	var spot := _world.near_spot()
	var busy := not _talking.is_empty() or _start_panel != null
	_update_card(spot if not busy else {})
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
		"pajama":
			if not GameState.weapon_unlocked(spot["id"]):
				return ""
			if GameState.selected_character == spot["id"]:
				return tr("HUB_WORN")
			return Settings.controls_text(tr("HUB_WEAR"))
	return Settings.controls_text(tr("HUB_LOOK"))


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
		if not _talking.is_empty():
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
	_talking = spot
	_world.frozen = true
	_box_hearts.visible = false
	match spot["kind"]:
		"npc":
			_box_title.text = tr("CHARO_NAME") if id == "charo" else tr("GIVER_%s_NAME" % id.to_upper())
			_box_role.text = tr("CHARS_CHARO_ROLE") if id == "charo" else tr("GIVER_%s_ROLE" % id.to_upper())
			_box_hearts.visible = true
			_box_hearts.color = HubLayout.ISLES[id]["aura"]
			_box_hearts.set_level(Progress.friend_level(id))
			Keywords.set_text(_box_text, _next_line(id))
			Audio.play("giver_" + id, -8.0)
		"statue":
			if Progress.has_seen(id):
				_box_title.text = tr("BEST_%s_NAME" % id.to_upper())
				_box_role.text = tr("BESTIARY_DEFEATED") % int(Progress.kills.get(id, 0))
				Keywords.set_text(_box_text, tr("BEST_%s_DESC" % id.to_upper()))
			else:
				_box_title.text = "???"
				_box_role.text = ""
				Keywords.set_text(_box_text, tr("HUB_EMPTY_PEDESTAL"))
			Audio.play("ui_click", -6.0)
	_box.visible = true
	_box.modulate.a = 0.0
	create_tween().tween_property(_box, "modulate:a", 1.0, 0.15)


## Cada vez que hablas con alguien dice otra cosa, de las que ya te ha contado por amistad
## Each time you talk to someone they say something else, from what friendship has unlocked
func _next_line(id: String) -> String:
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
	_world.frozen = false


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
	if _start_panel != null and event.is_action_pressed("ui_cancel") and get_children().filter(func(c: Node) -> bool: return c is GodPanel).is_empty():
		get_viewport().set_input_as_handled()
		_close_start()


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

## Algo que se dibuja en el mundo y se ordena por profundidad (su posición es su pie en el suelo)
## Something drawn in the world and depth-sorted (its position is its foot on the ground)
class Prop extends Node2D:
	var painter: Callable

	func _init(p: Callable) -> void:
		painter = p

	func _draw() -> void:
		painter.call(self)


## Suelo: el resplandor, las islas y los puentes / Ground: the glow, the islands and the bridges
class Ground extends Node2D:
	var world: HubWorld

	func _draw() -> void:
		world.draw_ground(self)


## Fondo: islotes lejanos que se mueven más despacio / Background: far-off islets that move slower
class Far extends Control:
	var world: HubWorld

	func _draw() -> void:
		world.draw_far(self)


## Lucecitas que flotan por encima de todo / Little lights floating above everything
class Motes extends Node2D:
	var world: HubWorld

	func _draw() -> void:
		world.draw_motes(self)


# --- El mundo / The world -------------------------------------------------------

class HubWorld extends Control:
	signal zone_entered(id: String)

	const SPEED := 150.0
	const TALK_RANGE := 40.0
	const NPC_SCALE := 0.25
	const KROKER_SCALE := 0.25
	const BRIDGE_HALF := 17.0
	const STEP := 15.0
	const Statue := preload("res://scripts/ui/bestiary.gd").BestiaryPreview
	const STATUE_SIZE := Vector2(44, 58)
	const SPAWN := Vector2(0, 70)
	## Islas que siempre están / Islands that are always there
	const ALWAYS: Array[String] = ["nexus", "wardrobe", "museum", "training"]
	## Orden de las islas alrededor del centro (para los pasillos entre vecinas) / Order of the islands around the centre (for the walkways between neighbours)
	const RING: Array[String] = ["wardrobe", "magnus", "doc", "ad", "pinche", "museum", "silly", "stolk", "svinho", "charo"]

	var frozen := false
	var _pos := SPAWN
	var _cam := SPAWN
	var _t := 0.0
	var _walk := 0.0
	var _moving := 0.0
	var _facing := 1.0
	var _zone := ""
	var _isles: Array[String] = []
	var _walk_polys := {}
	var _rims := {}
	var _bridges: Array[Dictionary] = []
	var _blocks: Array[Dictionary] = []     # {"c": Vector2, "r": Vector2}
	var _spots: Array[Dictionary] = []
	var _props: Array[Prop] = []
	var _stone: ShaderMaterial
	var _ground: Ground
	var _far: Far
	var _sort: Node2D
	var _motes_node: Motes
	var _kroker: Prop
	var _pinche: Prop
	var _ball: Prop
	var _silly: Prop
	var _silly_chair: Prop
	var _motes: Array[Vector4] = []
	var _statues: Array[Control] = []
	var _stones: Array[Vector4] = []
	var _poof_t := 0.0     # x, y, sprite, fase / x, y, sprite, phase

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		clip_contents = true
		var sky := DreamBackground.new()
		sky.star_count = 260
		sky.halo = Vector2(0.82, 0.16)
		add_child(sky)
		sky.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_far = Far.new()
		_far.world = self
		_far.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_far)
		_far.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_ground = Ground.new()
		_ground.world = self
		add_child(_ground)
		_sort = Node2D.new()
		_sort.y_sort_enabled = true
		add_child(_sort)
		_motes_node = Motes.new()
		_motes_node.world = self
		add_child(_motes_node)
		var sh := Shader.new()
		# Piedra: gris lila en cuatro tonos, como tallado en pixel art / Stone: lilac grey in four tones, like carved pixel art
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tif (c.a < 0.4) discard;\n\tfloat g = dot(c.rgb, vec3(0.3, 0.59, 0.11));\n\tg = floor(clamp(g * 1.15 + 0.1, 0.0, 0.999) * 4.0) / 3.0;\n\tvec3 dark = vec3(0.30, 0.27, 0.44);\n\tvec3 lite = vec3(0.93, 0.89, 0.80);\n\tCOLOR = vec4(mix(dark, lite, g), 1.0);\n}"
		_stone = ShaderMaterial.new()
		_stone.shader = sh
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 70:
			_motes.append(Vector4(rng.randf_range(-900, 900), rng.randf_range(-700, 800), rng.randf_range(0.0, TAU), rng.randf_range(0.5, 1.0)))
		_build()

	static func _met(id: String) -> bool:
		return preload("res://scripts/ui/characters_menu.gd").met(id)

	func _isle_pos(id: String) -> Vector2:
		return HubLayout.ISLES[id]["pos"]

	# --- Montaje / Building ---

	func _build() -> void:
		for id: String in HubLayout.ISLES:
			if ALWAYS.has(id) or _met(id):
				_isles.append(id)
				var poly := PackedVector2Array()
				for p: Vector2 in HubLayout.ISLES[id]["walk"]:
					poly.append(p + _isle_pos(id))
				_walk_polys[id] = poly
				# Borde de verdad de la isla, algo agrandado: ahí no se ponen piedras de puente
				# The island's real edge, slightly grown: no bridge stones go there
				var rim := PackedVector2Array()
				for p: Vector2 in HubLayout.ISLES[id]["rim"]:
					rim.append(p + _isle_pos(id))
				var grown := Geometry2D.offset_polygon(rim, 7.0)
				_rims[id] = grown[0] if not grown.is_empty() else rim
		_isles.sort_custom(func(a: String, b: String) -> bool: return _isle_pos(a).y < _isle_pos(b).y)
		for id in _isles:
			if id != "nexus" and id != "training":
				_add_bridge("nexus", id)
		# El tatami de entrenamiento se alcanza desde el armario / The training mat is reached from the wardrobe
		_add_bridge("wardrobe", "training")
		# Pasillos entre islas vecinas, para no tener que volver siempre al centro
		# Walkways between neighbouring islands, so you don't always have to go back to the centre
		var ring: Array[String] = []
		for id: String in RING:
			if _isles.has(id):
				ring.append(id)
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			if ring.size() > 2 or i == 0:
				_add_bridge(a, b, false)
		# Piedras ordenadas por altura para que las de delante tapen a las de detrás
		# Stones sorted by height so the ones in front cover the ones behind
		for br in _bridges:
			var stones: Array = br["stones"]
			for i in stones.size():
				var st: Vector3 = stones[i]
				_stones.append(Vector4(st.x, st.y, st.z, i * 0.45))
		_stones.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.y < b.y)
		_kroker = _prop(SPAWN, _draw_kroker)
		# Dos farolillos a la entrada de cada isla, del color de su dueño
		# Two little lanterns at the entrance of each island, in its owner's colour
		for b in _bridges:
			if not b["lanterns"]:
				continue
			var to: Vector2 = b["to"]
			var dir: Vector2 = (to - Vector2(b["from"])).normalized()
			var col: Color = b["aura"]
			var poly: PackedVector2Array = _walk_polys[b["id"]]
			var centre := _isle_pos(b["id"])
			for side in [-1.0, 1.0]:
				var at: Vector2 = to + dir * 6.0 + dir.orthogonal() * 18.0 * side
				# Que quede dentro de la isla / Keep it inside the island
				var tries := 0
				while not Geometry2D.is_point_in_polygon(at, poly) and tries < 40:
					at = at.move_toward(centre, 2.0)
					tries += 1
				at = (at + (centre - at).normalized() * 4.0).round()
				_blocks.append({"c": at, "r": Vector2(5, 3)})
				_prop(at, func(ci: CanvasItem) -> void:
					ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-20, -64), Vector2(40, 40)), false, Color(col, 0.3 + 0.08 * sin(_t * 2.2 + at.y)))
					Sprites.draw(ci, "hub_lantern", Color.WHITE)
					ci.draw_rect(Rect2(-3, -44, 6, 8), col))
		_build_nexus()
		_build_wardrobe()
		_build_museum()
		_build_training()
		# Al volver de un sueño o del entrenamiento, Kroker aparece donde toca
		# Coming back from a dream or from training, Kroker appears where it belongs
		if GameState.hub_spawn == "training":
			_pos = _isle_pos("training") + Vector2(-90, 40)
		GameState.hub_spawn = ""
		_cam = _pos + Vector2(0, -24)
		_kroker.position = _pos
		for id in _isles:
			match id:
				"svinho": _build_svinho()
				"stolk": _build_stolk()
				"silly": _build_silly()
				"doc": _build_doc()
				"ad": _build_ad()
				"pinche": _build_pinche()
				"charo": _build_charo()
				"magnus": _build_magnus()

	## Puente de piedras flotantes de una isla a otra / Bridge of floating stones from one island to another
	func _add_bridge(from_id: String, id: String, lanterns := true) -> void:
		var a := _isle_pos(from_id)
		var b := _isle_pos(id)
		var poly_a: PackedVector2Array = _walk_polys[from_id]
		var poly_b: PackedVector2Array = _walk_polys[id]
		var exit_t := 0.0
		var enter_t := 1.0
		var k := 0.0
		while k <= 1.0:
			var p := a.lerp(b, k)
			if Geometry2D.is_point_in_polygon(p, poly_a):
				exit_t = k
			k += 0.002
		k = 1.0
		while k >= 0.0:
			if Geometry2D.is_point_in_polygon(a.lerp(b, k), poly_b):
				enter_t = k
			k -= 0.002
		var p0 := a.lerp(b, exit_t)
		var p1 := a.lerp(b, enter_t)
		# Un pasillo entre vecinas no puede cruzar por encima de otra isla / A walkway between neighbours can't cross over another island
		if not lanterns:
			for other: String in _walk_polys:
				if other == from_id or other == id:
					continue
				for k2 in 21:
					if Geometry2D.is_point_in_polygon(p0.lerp(p1, k2 / 20.0), _walk_polys[other]):
						return
		var dir := (p1 - p0).normalized()
		var stones: Array[Vector3] = []
		var n := maxi(1, int(p0.distance_to(p1) / STEP))
		var side := dir.orthogonal()
		for i in range(1, n + 1):
			# Dos filas de piedras al tresbolillo: el camino es ancho / Two staggered rows of stones: a wide path
			var q := p0.lerp(p1, (i - 0.5) / n)
			for r in [-1.0, 1.0]:
				var off: Vector2 = side * r * 7.0 + dir * (3.5 if r > 0.0 else -3.5)
				var sp := q + off
				if _on_island(sp):
					continue
				stones.append(Vector3(sp.x, sp.y, float((i * 7 + int(r) + id.length()) % 3)))
		_bridges.append({"id": id, "a": p0 - dir * 16.0, "b": p1 + dir * 16.0, "from": p0, "to": p1, "stones": stones,
			"aura": HubLayout.ISLES[id]["aura"], "lanterns": lanterns})

	## ¿Este punto cae encima de alguna isla? / Does this point land on top of an island?
	func _on_island(p: Vector2) -> bool:
		for id: String in _rims:
			if Geometry2D.is_point_in_polygon(p, _rims[id]):
				return true
		return false

	func _prop(at: Vector2, painter: Callable) -> Prop:
		var p := Prop.new(painter)
		p.position = at
		_sort.add_child(p)
		_props.append(p)
		return p

	## Un mueble con su sprite; "block" son los radios de la zona que no se puede pisar
	## A piece of furniture with its sprite; "block" is the radii of the area you can't step on
	func _piece(at: Vector2, sprite: String, block := Vector2.ZERO, block_off := Vector2.ZERO) -> Prop:
		if block != Vector2.ZERO:
			_blocks.append({"c": at + block_off, "r": block})
		return _prop(at, func(ci: CanvasItem) -> void: Sprites.draw(ci, sprite))

	func _npc_prop(id: String, at: Vector2, offset := Vector2.ZERO) -> Prop:
		_blocks.append({"c": at, "r": Vector2(11, 6)})
		_spots.append({"kind": "npc", "id": id, "pos": at, "height": 84.0 - offset.y})
		return _prop(at, func(ci: CanvasItem) -> void: _draw_npc(ci, id, offset))

	func _draw_npc(ci: CanvasItem, id: String, offset := Vector2.ZERO, flip := false, opts := {}) -> void:
		var sx := -NPC_SCALE if flip else NPC_SCALE
		var p := offset
		if offset.y > -2.0:
			ci.draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(10, 3)), Color(0, 0, 0, 0.3))
		NpcArt.draw(ci, Transform2D(0.0, Vector2(sx, NPC_SCALE), 0.0, p + Vector2(-100.0 * sx, -288.0 * NPC_SCALE)), id, _t, opts)

	## De coordenadas del mundo al lienzo de un personaje que está en "at" / From world coordinates to the canvas of a character standing at "at"
	func _to_canvas(world: Vector2, at: Vector2) -> Vector2:
		return (world - at) / NPC_SCALE + Vector2(100, 288)

	func _shadow(ci: CanvasItem, c: Vector2, r: Vector2, a := 0.28) -> void:
		ci.draw_colored_polygon(_ellipse(c, r), Color(0.03, 0.02, 0.1, a))

	# --- Centro / Centre ---

	func _build_nexus() -> void:
		var c := _isle_pos("nexus")
		# La fuente: aquí se empieza a soñar / The fountain: this is where dreaming starts
		_spots.append({"kind": "fountain", "id": "fountain", "pos": c + Vector2(0, 22), "height": 96.0})
		_prop(c + Vector2(0, 2), _draw_fountain)
		_blocks.append({"c": c + Vector2(0, -2), "r": Vector2(38, 14)})
		for p: Vector2 in [Vector2(-150, -62), Vector2(150, -62), Vector2(-178, 62), Vector2(178, 62)]:
			var at := c + p
			_blocks.append({"c": at, "r": Vector2(6, 3)})
			_prop(at, func(ci: CanvasItem) -> void:
				ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-22, -66), Vector2(44, 44)), false, Color("9be3ff", 0.28 + 0.06 * sin(_t * 2.0 + at.x)))
				Sprites.draw(ci, "hub_lantern"))

	## Fuente de estrellas: chorro de chispas que suben y caen / Star fountain: a spray of sparks rising and falling
	func _draw_fountain(ci: CanvasItem) -> void:
		_shadow(ci, Vector2(0, -2), Vector2(38, 10))
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-60, -100), Vector2(120, 110)), false, Color("f6d993", 0.16))
		Sprites.draw(ci, "hub_fountain")
		for i in 14:
			var ph := fmod(_t * 0.7 + i * 0.37, 1.0)
			var ang := (i * 2.4)
			var vx := cos(ang) * 16.0
			var p := Vector2(vx * ph, -56.0 - 34.0 * ph + 60.0 * ph * ph)
			if p.y > -12.0:
				continue
			var col := Color("f6d993") if i % 3 else Color("9be3ff")
			ci.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(col, 1.0 - ph * 0.6))
		# Ondas en el agua / Ripples on the water
		var r := fmod(_t * 8.0, 20.0)
		ci.draw_arc(Vector2(0, -10), 6.0 + r, 0, TAU, 24, Color("9be3ff", 0.35 * (1.0 - r / 20.0)), 1.0)

	# --- Tatami de entrenamiento / Training mat ---

	func _build_training() -> void:
		var c := _isle_pos("training")
		var at := c + Vector2(30, -6)
		_blocks.append({"c": at, "r": Vector2(14, 5)})
		_spots.append({"kind": "training", "id": "training", "pos": at + Vector2(0, 12), "height": 100.0})
		_prop(at, func(ci: CanvasItem) -> void:
			_shadow(ci, Vector2.ZERO, Vector2(18, 4))
			ci.draw_set_transform(Vector2.ZERO, sin(_t * 1.3) * 0.03, Vector2(0.5, 0.5))
			Sprites.draw(ci, "dummy")
			ci.draw_set_transform(Vector2.ZERO))
		for x in [-150.0, 150.0]:
			_piece(c + Vector2(x, -70), "hub_lantern", Vector2(6, 3))

	## Nubecita al cambiarse de pijama / Little puff when changing pajamas
	func poof() -> void:
		_poof_t = 0.5

	# --- Armario / Wardrobe ---

	func _build_wardrobe() -> void:
		var c := _isle_pos("wardrobe")
		_piece(c + Vector2(0, -40), "hub_wardrobe", Vector2(64, 10), Vector2(0, -6))
		_piece(c + Vector2(122, -24), "hub_mirror", Vector2(10, 4))
		for i in PAJAMAS.size():
			var o := PAJAMAS[i]
			var at := c + Vector2(-112 + i * 28, 22)
			_blocks.append({"c": at, "r": Vector2(7, 3)})
			_spots.append({"kind": "pajama", "id": o, "pos": at, "height": 70.0})
			_prop(at, func(ci: CanvasItem) -> void:
				_shadow(ci, Vector2.ZERO, Vector2(9, 3))
				Sprites.draw(ci, "hub_stand")
				if GameState.weapon_unlocked(o):
					var xf := Transform2D(0.0, Vector2(KROKER_SCALE, KROKER_SCALE), 0.0, Vector2(-100.0 * KROKER_SCALE, -288.0 * KROKER_SCALE - 6.0))
					ci.draw_set_transform_matrix(xf)
					for part in ["kroker_leg_l_", "kroker_leg_r_", "kroker_arm_l_", "kroker_arm_r_", "kroker_torso_"]:
						Sprites.draw(ci, part + o)
					ci.draw_set_transform(Vector2.ZERO))

	# --- Museo / Museum ---

	func _build_museum() -> void:
		var c := _isle_pos("museum")
		for p: Vector2 in [Vector2(-246, -62), Vector2(246, -62), Vector2(-262, 52), Vector2(262, 52)]:
			_piece(c + p, "hub_column", Vector2(10, 4))
		for i in Progress.BESTIARY.size():
			var id: String = Progress.BESTIARY[i]
			var at := c + Vector2(-182 + (i % 8) * 52, -46 + (i / 8) * 92)
			_blocks.append({"c": at + Vector2(0, -6), "r": Vector2(15, 6)})
			_spots.append({"kind": "statue", "id": id, "pos": at + Vector2(0, 6), "height": 86.0})
			_prop(at, func(ci: CanvasItem) -> void:
				_shadow(ci, Vector2(0, -2), Vector2(16, 4))
				Sprites.draw(ci, "hub_pedestal"))
			if Progress.has_seen(id):
				# La estatua va en su propio nodo, justo delante del pedestal / The statue goes in its own node, just in front of the pedestal
				var holder := Node2D.new()
				holder.position = at + Vector2(0, 0.5)
				_sort.add_child(holder)
				var top := Node2D.new()
				top.position = Vector2(0, -19)
				# Los jefes son enormes: en estatua, más pequeños / Bosses are huge: as statues, smaller
				if id.begins_with("boss_"):
					top.scale = Vector2.ONE * (0.55 if id == "boss_ufo" else 0.72)
				holder.add_child(top)
				var st: Control = Statue.new()
				st.id = id
				st.size = STATUE_SIZE
				st.custom_minimum_size = STATUE_SIZE
				st.position = Vector2(-STATUE_SIZE.x / 2.0, -STATUE_SIZE.y * 0.84)
				st.material = _stone
				top.add_child(st)
				_statues.append(st)

	# --- Svinho: practica tiros a portería / practises shots at goal ---

	const GOAL := Vector2(40, -60)

	func _build_svinho() -> void:
		var c := _isle_pos("svinho")
		# Portería al fondo del campo, de frente / Goal at the far end of the pitch, face-on
		_piece(c + GOAL, "hub_goal", Vector2(30, 6), Vector2(0, -4))
		_piece(c + Vector2(-122, -56), "hub_flag")
		_piece(c + Vector2(122, -60), "hub_flag")
		_piece(c + Vector2(-132, 20), "hub_ballbag", Vector2(12, 5))
		var sv := _npc_prop("svinho", c + Vector2(-14, 30))
		# Chuta justo cuando sale el balón / He kicks just as the ball leaves
		sv.painter = func(ci: CanvasItem) -> void:
			var ph := fmod(_t, 2.8) / 2.8
			var k := clampf(1.0 - minf(ph + 0.03, 1.03 - ph) / 0.07, 0.0, 1.0)
			_draw_npc(ci, "svinho", Vector2.ZERO, false, {"kick": k * k * (3.0 - 2.0 * k)})
		_ball = _prop(c + Vector2(-2, 30), func(ci: CanvasItem) -> void:
			var h: float = _ball.get_meta("h", 0.0)
			_shadow(ci, Vector2.ZERO, Vector2(4, 1.5), 0.3)
			ci.draw_set_transform(Vector2(0, -3.0 - h).round(), _t * 9.0, Vector2(0.45, 0.45))
			Sprites.draw(ci, "npc_ball")
			ci.draw_set_transform(Vector2.ZERO))

	func _tick_svinho() -> void:
		var c := _isle_pos("svinho")
		var foot := c + Vector2(-2, 30)
		var goal := c + GOAL + Vector2(0, -4)
		var ph := fmod(_t, 2.8) / 2.8
		var h := 0.0
		var p: Vector2
		if ph < 0.3:
			var k := ph / 0.3
			p = foot.lerp(goal, k)
			h = sin(k * PI) * 26.0
		elif ph < 0.42:
			p = goal + Vector2(0, -6)
		else:
			var k := (ph - 0.42) / 0.58
			p = (goal + Vector2(0, -6)).lerp(foot, k * k * (3.0 - 2.0 * k))
		_ball.position = p
		_ball.set_meta("h", h)

	# --- Stolk: levanta pesas en su gimnasio / lifts weights in his gym ---

	func _build_stolk() -> void:
		var c := _isle_pos("stolk")
		_piece(c + Vector2(-78, -46), "hub_rack", Vector2(24, 5))
		_piece(c + Vector2(64, -38), "hub_bench", Vector2(20, 5))
		_piece(c + Vector2(100, 34), "hub_bag", Vector2(8, 4), Vector2(4, 0))
		var at := c + Vector2(-20, 18)
		var st := _npc_prop("stolk", at)
		# Levanta la barra con los brazos y cuenta las repeticiones / Presses the bar with his arms and counts the reps
		st.painter = func(ci: CanvasItem) -> void:
			var ph := fmod(_t, 2.6) / 2.6
			var up := 0.5 - 0.5 * cos(ph * TAU)
			up = up * up * (3.0 - 2.0 * up)
			_draw_npc(ci, "stolk", Vector2.ZERO, false, {"lift": up})
			if up > 0.9:
				var reps := 27 + int(_t / 2.6) % 4
				ci.draw_string(UITheme.font("caps"), Vector2(16, -90), "¡%d!" % reps, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ff8f9e"))

	# --- Silly: entre pantallas con código verde / among screens of green code ---

	func _build_silly() -> void:
		var c := _isle_pos("silly")
		var desk := c + Vector2(0, -40)
		_blocks.append({"c": desk + Vector2(0, -6), "r": Vector2(36, 8)})
		_prop(desk, func(ci: CanvasItem) -> void:
			ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-70, -90), Vector2(140, 100)), false, Color("5ff2a0", 0.14))
			Sprites.draw(ci, "hub_monitors")
			var active := _silly_screen()
			var screens: Array[Rect2] = [Rect2(-31, -38, 16, 12), Rect2(-8, -44, 16, 14), Rect2(15, -38, 16, 12)]
			for i in 3:
				var sc := screens[i]
				var on := i == active
				if on:
					ci.draw_rect(sc, Color("0c2a1a"))
				var speed := 14.0 if on else 3.0
				for row in int(sc.size.y / 3):
					var n := int(_t * speed + row * 3 + sc.position.x)
					var w := 3.0 + float((n * 37) % int(sc.size.x - 4))
					ci.draw_rect(Rect2(sc.position + Vector2(1, 1 + row * 3), Vector2(w, 1)), Color("7dffb0" if on else "2f9a6a", 0.9 if on else 0.6))
				if on and fmod(_t, 2.4) > 1.9:
					ci.draw_rect(Rect2(sc.position + Vector2(2, sc.size.y / 2.0 - 2), Vector2(sc.size.x - 4, 4)), Color("5ff2a0"))
					ci.draw_rect(Rect2(sc.position + Vector2(3, sc.size.y / 2.0 - 1), Vector2(sc.size.x - 6, 2)), Color("0c2a1a")))
		for x in [-74.0, 74.0]:
			var at := c + Vector2(x, -44)
			_blocks.append({"c": at, "r": Vector2(8, 3)})
			_prop(at, func(ci: CanvasItem) -> void:
				Sprites.draw(ci, "hub_server")
				for k in 6:
					var on := fmod(_t * 3.0 + k * 1.7 + x, 2.0) < 1.0
					ci.draw_rect(Rect2(Vector2(-4 + (k % 2) * 6, -30 + (k / 2) * 9), Vector2(1, 1)), Color("5ff2a0") if on else Color("1f6a4a")))
		# Silly, de espaldas en su silla, rueda de un monitor a otro / Silly, back to us in her chair, rolls from one monitor to another
		_blocks.append({"c": desk + Vector2(0, 30), "r": Vector2(30, 7)})
		_spots.append({"kind": "npc", "id": "silly", "pos": desk + Vector2(0, 46), "height": 70.0})
		_silly = _prop(desk + Vector2(0, 30), func(ci: CanvasItem) -> void:
			var s2 := NPC_SCALE
			var bob := roundf(absf(sin(_t * 9.0)) * 0.6)
			var tilt := sin(_t * 0.7) * 0.03
			ci.draw_set_transform_matrix(Transform2D(tilt, Vector2(s2, s2), 0.0, Vector2(-100.0 * s2, -288.0 * s2 - 7.0 + bob)))
			Sprites.draw(ci, "npc_silly_back")
			ci.draw_set_transform(Vector2.ZERO))
		_silly_chair = _prop(desk + Vector2(0, 36), func(ci: CanvasItem) -> void:
			_shadow(ci, Vector2(0, -1), Vector2(13, 3))
			Sprites.draw(ci, "hub_gamerchair_back"))

	## Qué monitor está usando Silly (cambia cada poco) / Which monitor Silly is using (changes every so often)
	func _silly_screen() -> int:
		return [1, 0, 1, 2, 0, 2][int(_t / 2.4) % 6]

	func _tick_silly() -> void:
		var desk := _isle_pos("silly") + Vector2(0, -40)
		var target: float = [-22.0, 0.0, 22.0][_silly_screen()]
		var x := move_toward(_silly.position.x - desk.x, target, 40.0 * get_process_delta_time())
		_silly.position.x = roundf(desk.x + x)
		_silly_chair.position.x = _silly.position.x

	# --- Doc: examina un pie gigante con la lupa / examines a giant foot with the magnifier ---

	func _build_doc() -> void:
		var c := _isle_pos("doc")
		var couch := c + Vector2(46, -24)
		_piece(couch, "hub_couch", Vector2(30, 6), Vector2(0, -6))
		_piece(c + Vector2(-96, -42), "hub_cabinet", Vector2(12, 4))
		_piece(c + Vector2(-46, -50), "hub_poster", Vector2(9, 3))
		var at := couch + Vector2(-28, 3)
		var dc := _npc_prop("doc", at)
		# Va pasando la lupa por el pie: tobillo, empeine, dedos y talón / He runs the magnifier over the foot: ankle, instep, toes and heel
		dc.painter = func(ci: CanvasItem) -> void:
			var pts: Array[Vector2] = [Vector2(-12, -34), Vector2(2, -30), Vector2(14, -25), Vector2(22, -21), Vector2(-18, -22)]
			var u := _t / 1.6
			var i := int(u) % pts.size()
			var k := clampf((fmod(u, 1.0) - 0.55) / 0.45, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var tgt := pts[i].lerp(pts[(i + 1) % pts.size()], k) + Vector2(sin(_t * 5.0), cos(_t * 4.0)) * 0.6
			_draw_npc(ci, "doc", Vector2.ZERO, false, {"lens": _to_canvas(couch + tgt, at)})
			if i == 3 and k == 0.0:
				ci.draw_string(UITheme.font("caps"), Vector2(-12, -76), "¿Hmm?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffe3a3"))

	# --- Mr. Ad: sale en todas las teles del escaparate / is on every TV in the window ---

	func _build_ad() -> void:
		var c := _isle_pos("ad")
		var shop := c + Vector2(0, -24)
		_blocks.append({"c": shop + Vector2(0, -8), "r": Vector2(104, 10)})
		_spots.append({"kind": "npc", "id": "ad", "pos": c + Vector2(0, 6), "height": 100.0})
		_prop(shop, func(ci: CanvasItem) -> void:
			Sprites.draw(ci, "hub_shopfront")
			for k in 3:
				_ad_tv(ci, k, Rect2(-80 + k * 57, -67, 46, 38), 1.0)
			ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-110, -90), Vector2(220, 100)), false, Color("ffb04a", 0.08)))
		for k in 2:
			var at := c + Vector2(-132 + k * 264, 16)
			_blocks.append({"c": at + Vector2(0, -4), "r": Vector2(12, 4)})
			_prop(at, func(ci: CanvasItem) -> void:
				_shadow(ci, Vector2(0, -1), Vector2(12, 3))
				Sprites.draw(ci, "hub_tv")
				_ad_tv(ci, 3 + k, Rect2(-9, -29, 16, 13), 0.42))

	## En qué tele está Mr. Ad en el trozo de tiempo "n" (nunca dos veces seguidas en la misma)
	## Which TV Mr. Ad is on during time slice "n" (never twice in a row on the same one)
	func _ad_screen(n: int) -> int:
		var s := absi(hash(n * 7919 + 13)) % 5
		if s == absi(hash((n - 1) * 7919 + 13)) % 5:
			s = (s + 1) % 5
		return s

	## Una tele del escaparate: Mr. Ad salta de una a otra, hiperactivo, con la cara en primer plano
	## One TV in the window: Mr. Ad hops from one to the next, hyperactive, his face in close-up
	func _ad_tv(ci: CanvasItem, idx: int, scr: Rect2, zoom: float) -> void:
		const SLICE := 0.55
		var n := int(_t / SLICE)
		var u := fmod(_t, SLICE) / SLICE
		var here := _ad_screen(n) == idx
		ci.draw_rect(scr, Color("1e3a50"))
		if here:
			ci.draw_rect(scr, Color("2a5a7a"))
			# Entra de golpe por un lado, tiembla y a veces se acerca muchísimo
			# He bursts in from one side, shakes, and sometimes gets really close
			var side := 1.0 if hash(n) % 2 == 0 else -1.0
			var slide := maxf(0.0, 1.0 - u / 0.16)
			var z := zoom * (1.55 if n % 4 == 0 else 1.0) * (1.0 + 0.06 * sin(_t * 30.0))
			var jit := Vector2(sin(_t * 47.0), cos(_t * 39.0)).round()
			var cpos := scr.get_center() + Vector2(side * slide * scr.size.x, 0) + jit + Vector2(0, scr.size.y * 0.08)
			_ad_face(ci, scr, cpos, z)
		elif _ad_screen(n - 1) == idx and u < 0.3:
			# Nieve de la tele que acaba de dejar / Static on the TV he just left
			var rng := RandomNumberGenerator.new()
			rng.seed = int(_t * 40.0) + idx
			for i in int(scr.size.x * scr.size.y / 10.0):
				ci.draw_rect(Rect2(scr.position + Vector2(rng.randi_range(0, int(scr.size.x) - 1), rng.randi_range(0, int(scr.size.y) - 1)), Vector2(1, 1)), Color(1, 1, 1, rng.randf_range(0.3, 0.8)))
		else:
			# Mientras, un anuncio: «$» que parpadea / Meanwhile, an advert: a blinking "$"
			if fmod(_t * 2.0 + idx, 2.0) < 1.2 and scr.size.x > 20.0:
				ci.draw_string(UITheme.font("caps"), scr.get_center() + Vector2(-4, 4), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffb04a", 0.8))
		var line := fposmod(_t * 20.0 + idx * 7.0, scr.size.y)
		ci.draw_rect(Rect2(scr.position + Vector2(0, roundf(line)), Vector2(scr.size.x, 1)), Color(1, 1, 1, 0.08))
		ci.draw_rect(Rect2(scr.position, Vector2(scr.size.x, 1)), Color(1, 1, 1, 0.14))

	## La cabeza de Mr. Ad (del sprite) recortada a la pantalla / Mr. Ad's head (from the sprite) clipped to the screen
	func _ad_face(ci: CanvasItem, scr: Rect2, centre: Vector2, zoom: float) -> void:
		const SRC := Rect2(11, 1, 27, 37)
		var fr := Rect2(centre - SRC.size * zoom / 2.0, SRC.size * zoom)
		var d := fr.intersection(scr)
		if d.size.x <= 0.5 or d.size.y <= 0.5:
			return
		var src := Rect2(SRC.position + (d.position - fr.position) / zoom, d.size / zoom)
		ci.draw_texture_rect_region(Sprites.tex("npc_ad"), d, src)

	# --- El Pinche: apaga su cocina en llamas / puts out his kitchen on fire ---

	func _build_pinche() -> void:
		var c := _isle_pos("pinche")
		var stove := c + Vector2(-8, -38)
		_blocks.append({"c": stove + Vector2(0, -8), "r": Vector2(62, 10)})
		_prop(stove, func(ci: CanvasItem) -> void:
			Sprites.draw(ci, "hub_stove")
			for x in [-38.0, 0.0, 38.0]:
				_flames(ci, Vector2(x, -30), 1.0, x))
		_piece(c + Vector2(86, -40), "hub_fridge", Vector2(12, 4))
		for p: Vector2 in [Vector2(-96, 12), Vector2(72, 34), Vector2(-40, 46)]:
			var at := c + p
			_prop(at, func(ci: CanvasItem) -> void: _flames(ci, Vector2.ZERO, 0.6, at.x))
		_pinche = _npc_prop("pinche", c + Vector2(0, -2))
		_blocks.pop_back()   # corre de un lado a otro: no estorba / he runs back and forth: he doesn't block
		_pinche.painter = func(ci: CanvasItem) -> void:
			var dir := cos(_t * 1.6)
			_draw_npc(ci, "pinche", Vector2.ZERO, dir < 0.0)
			# Nubecitas del extintor / Little extinguisher clouds
			if fmod(_t, 1.9) < 0.7:
				var s := 1.0 if dir >= 0.0 else -1.0
				for k in 4:
					var r := 3.0 + k + fmod(_t * 6.0, 2.0)
					ci.draw_circle(Vector2((12 + k * 8) * s, -28 - k * 3), r, Color(1, 1, 1, 0.65 - k * 0.12))

	func _tick_pinche() -> void:
		var c := _isle_pos("pinche")
		var at := c + Vector2(sin(_t * 1.6) * 64.0, -2)
		_pinche.position = at
		for s in _spots:
			if s["id"] == "pinche":
				s["pos"] = at

	func _flames(ci: CanvasItem, at: Vector2, size: float, seed_x: float) -> void:
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(at - Vector2(26, 32) * size, Vector2(52, 44) * size), false, Color("ff9a3a", 0.3))
		for j in 4:
			var h := (10.0 + 6.0 * sin(_t * 11.0 + j * 1.7 + seed_x)) * size
			var x := at.x + (-6 + j * 4) * size
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3 * size, at.y), Vector2(x, at.y - h), Vector2(x + 3 * size, at.y)]), Color("ff7a2a"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 1.5 * size, at.y), Vector2(x, at.y - h * 0.55), Vector2(x + 1.5 * size, at.y)]), Color("ffe08a"))
		# Humo que sube / Rising smoke
		var ph := fmod(_t * 0.5 + seed_x * 0.01, 1.0)
		ci.draw_circle(at + Vector2(sin(ph * 6.0) * 3.0, -18.0 * size - ph * 30.0), (3.0 + ph * 5.0) * size, Color(0.25, 0.22, 0.3, 0.35 * (1.0 - ph)))

	# --- Charo: teje en su sillón / knits in her armchair ---

	func _build_charo() -> void:
		var c := _isle_pos("charo")
		var chair := c + Vector2(0, 0)
		_blocks.append({"c": chair + Vector2(0, -2), "r": Vector2(24, 8)})
		_spots.append({"kind": "npc", "id": "charo", "pos": chair + Vector2(0, 12), "height": 76.0})
		_piece(chair, "hub_chair_back")
		_prop(chair + Vector2(0, 2), func(ci: CanvasItem) -> void: _draw_npc(ci, "charo", Vector2(0, -6)))
		_prop(chair + Vector2(0, 6), func(ci: CanvasItem) -> void:
			Sprites.draw(ci, "hub_chair_front", Color.WHITE, Vector2(0, -6))
			# Agujas que se cruzan y la bufanda que crece / Clicking needles and the growing scarf
			var k := roundf(sin(_t * 7.0) * 3.0)
			ci.draw_line(Vector2(-5 + k, -34), Vector2(8 + k, -26), Color("dfe6ff"), 1.0)
			ci.draw_line(Vector2(5 - k, -34), Vector2(-8 - k, -26), Color("dfe6ff"), 1.0)
			var scarf := roundf(4.0 + fmod(_t * 2.0, 18.0))
			ci.draw_rect(Rect2(-3, -28, 6, scarf), Color("e85d75"))
			for y in range(0, int(scarf), 3):
				ci.draw_rect(Rect2(-3, -28 + y, 6, 1), Color("ff8fb1")))
		_piece(c + Vector2(-46, -8), "hub_floorlamp", Vector2(6, 3))
		_prop(c + Vector2(-46, -8.5), func(ci: CanvasItem) -> void:
			ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-40, -80), Vector2(80, 80)), false, Color("ffd8a0", 0.18)))
		_piece(c + Vector2(40, 8), "hub_basket", Vector2(10, 4))

	# --- Magnus: en su despacho, con el teléfono que no para / in his office, the phone never stops ---

	func _build_magnus() -> void:
		var c := _isle_pos("magnus")
		_piece(c + Vector2(0, -14), "hub_bigchair")
		_npc_prop("magnus", c + Vector2(0, -8))
		_blocks.append({"c": c + Vector2(0, 2), "r": Vector2(40, 8)})
		for s in _spots:
			if s["id"] == "magnus":
				s["pos"] = c + Vector2(0, 22)
		_prop(c + Vector2(0, 12), func(ci: CanvasItem) -> void:
			Sprites.draw(ci, "hub_desk")
			if fmod(_t, 6.0) < 1.2:
				var j := Vector2(randf_range(-1, 1), 0).round()
				ci.draw_rect(Rect2(Vector2(18, -29) + j, Vector2(10, 5)), Color("2b2945"))
				ci.draw_string(UITheme.font("caps"), Vector2(16, -40) + j, "RING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f2c94c")))
		_piece(c + Vector2(-92, -40), "hub_safe", Vector2(12, 4))
		_piece(c + Vector2(88, -44), "hub_chart", Vector2(9, 3))
		_piece(c + Vector2(-124, -6), "hub_plant", Vector2(7, 3))
		_piece(c + Vector2(124, -6), "hub_plant", Vector2(7, 3))

	# --- Kroker ---

	func _draw_kroker(ci: CanvasItem) -> void:
		ci.draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(11, 3)), Color(0, 0, 0, 0.3))
		var outfit := GameState.selected_character if GameState.weapon_unlocked(GameState.selected_character) else "bat"
		KrokerArt.draw(ci, Transform2D(0.0, Vector2(KROKER_SCALE, KROKER_SCALE), 0.0, Vector2(-100.0 * KROKER_SCALE, -288.0 * KROKER_SCALE)),
			outfit, _t, {"facing": _facing, "walk": _walk, "moving": _moving, "armed": true})
		# Nubecita de cambiarse / Changing puff
		if _poof_t > 0.0:
			var k := 1.0 - _poof_t / 0.5
			for i in 8:
				var a := i * TAU / 8.0
				ci.draw_circle(Vector2(cos(a) * (8.0 + k * 18.0), -36.0 + sin(a) * (10.0 + k * 22.0)), 6.0 * (1.0 - k) + 2.0, Color(1, 1, 1, 0.8 * (1.0 - k)))

	# --- Movimiento / Movement ---

	func walkable(p: Vector2) -> bool:
		var ok := false
		for id: String in _walk_polys:
			if Geometry2D.is_point_in_polygon(p, _walk_polys[id]):
				ok = true
				break
		if not ok:
			for b in _bridges:
				var q := Geometry2D.get_closest_point_to_segment(p, b["a"], b["b"])
				if q.distance_to(p) < BRIDGE_HALF:
					ok = true
					break
		if not ok:
			return false
		for b in _blocks:
			var d: Vector2 = (p - b["c"]) / b["r"]
			if d.length_squared() < 1.0:
				return false
		return true

	## Si el paso choca, prueba a desviarlo un poco hacia los lados (resbala por los bordes y sigue los puentes)
	## If the step bumps into something, try turning it a little to either side (slides along edges and follows the bridges)
	func _slide(step: Vector2) -> Vector2:
		if walkable(_pos + step):
			return step
		# En un puente, avanza a lo largo de él / On a bridge, move along it
		for br in _bridges:
			var q := Geometry2D.get_closest_point_to_segment(_pos, br["a"], br["b"])
			if q.distance_to(_pos) < BRIDGE_HALF + 2.0:
				var along: Vector2 = (Vector2(br["b"]) - Vector2(br["a"])).normalized()
				var s := along * step.dot(along)
				if s.length() > step.length() * 0.2 and walkable(_pos + s):
					return s
		for ang in [0.35, -0.35, 0.7, -0.7, 1.1, -1.1]:
			var s: Vector2 = step.rotated(ang) * cos(ang)
			if walkable(_pos + s):
				return s
		return Vector2.ZERO

	func screen_of(p: Vector2) -> Vector2:
		return p + _offset()

	func _offset() -> Vector2:
		return (size / 2.0 - _cam).round()

	## Lo más cercano con lo que se puede hablar / The closest thing you can talk to
	func near_spot() -> Dictionary:
		var best := {}
		var best_d := TALK_RANGE
		for s in _spots:
			var d := _pos.distance_to(s["pos"])
			if d < best_d:
				best_d = d
				best = s
		return best

	func _process(delta: float) -> void:
		_t += delta
		_poof_t = maxf(0.0, _poof_t - delta)
		var dir := Vector2.ZERO
		if not frozen:
			dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var step := dir * SPEED * delta
		var moved := 0.0
		if step != Vector2.ZERO:
			var before := _pos
			_pos += _slide(step)
			moved = _pos.distance_to(before) / maxf(delta, 0.0001)
		if absf(dir.x) > 0.1:
			_facing = signf(dir.x)
		_moving = move_toward(_moving, clampf(moved / 100.0, 0.0, 1.0), delta * 8.0)
		_walk += moved * delta * 0.09
		_cam = _cam.lerp(_pos + Vector2(0, -24), minf(1.0, delta * 4.0))
		_kroker.position = _pos
		if is_instance_valid(_ball):
			_tick_svinho()
		if is_instance_valid(_pinche):
			_tick_pinche()
		if is_instance_valid(_silly):
			_tick_silly()
		_check_zone()
		var off := _offset()
		_ground.position = off
		_sort.position = off
		_motes_node.position = off
		for p in _props:
			p.queue_redraw()
		for st in _statues:
			var e: CanvasItem = st.get("_enemy")
			if e and e.material != _stone:
				e.material = _stone
		_ground.queue_redraw()
		_far.queue_redraw()
		_motes_node.queue_redraw()

	func _check_zone() -> void:
		var here := ""
		for id: String in _walk_polys:
			if Geometry2D.is_point_in_polygon(_pos, _walk_polys[id]):
				here = id
				break
		if here != "" and here != _zone:
			_zone = here
			call_deferred("emit_signal", "zone_entered", here)

	# --- Dibujo / Drawing ---

	## Islotes lejanos, que van más despacio (parece que están más lejos) / Far islets, slower (they seem further away)
	func draw_far(ci: CanvasItem) -> void:
		var far := [[Vector2(-520, -260), 0, 0.25], [Vector2(420, -300), 1, 0.2], [Vector2(-80, -420), 3, 0.15],
			[Vector2(640, 200), 2, 0.3], [Vector2(-700, 260), 1, 0.25], [Vector2(150, 380), 3, 0.18], [Vector2(-300, 520), 0, 0.3]]
		for f: Array in far:
			var k: float = f[2]
			var p: Vector2 = Vector2(f[0]) - _cam * k + size / 2.0 + Vector2(0, sin(_t * 0.4 + float(f[1]) * 2.0) * 3.0)
			var tex := Sprites.tex("hub_far_%d" % int(f[1]))
			var sc := 0.5 + k
			var tint := Color(0.42, 0.4, 0.75, 0.55 + k)
			ci.draw_texture_rect(tex, Rect2((p - tex.get_size() * sc / 2.0).round(), (tex.get_size() * sc).round()), false, tint)

	func draw_ground(ci: CanvasItem) -> void:
		var soft := DreamBackground.soft_texture()
		# Resplandor bajo cada isla / Glow beneath each island
		for id in _isles:
			var d: Dictionary = HubLayout.ISLES[id]
			var r: Vector2 = d["r"]
			var c: Vector2 = d["pos"] + Vector2(0, r.y * 0.9)
			ci.draw_texture_rect(soft, Rect2(c - r * 1.5, r * 3.0), false, Color(d["aura"], 0.13 + 0.03 * sin(_t * 0.8 + c.x)))
		for id in _isles:
			var d: Dictionary = HubLayout.ISLES[id]
			var tex := Sprites.tex("hub_isle_" + id)
			var bob := roundf(sin(_t * 0.6 + float(id.length())) * 0.0)
			ci.draw_texture(tex, d["pos"] + d["offset"] + Vector2(0, bob))
		# Puentes: piedras que flotan y un hilo de luz / Bridges: floating stones and a thread of light
		for b in _bridges:
			var col: Color = b["aura"]
			var a0: Vector2 = b["from"]
			var a1: Vector2 = b["to"]
			# Hilo de luz que une las piedras / Thread of light joining the stones
			ci.draw_line(a0 + Vector2(0, 2), a1 + Vector2(0, 2), Color(col, 0.18), 1.0)
		# Todas las piedras de todos los puentes, de atrás adelante / Every stone of every bridge, back to front
		for s in _stones:
			var bob := roundf(sin(_t * 1.5 + s.w) * 1.2)
			var tex := Sprites.tex("hub_step_%d" % int(s.z))
			ci.draw_texture(tex, (Vector2(s.x, s.y) - Vector2(tex.get_width() / 2.0, 4.0) + Vector2(0, bob)).round())
		for b in _bridges:
			var col: Color = b["aura"]
			var a0: Vector2 = b["from"]
			var a1: Vector2 = b["to"]
			# Chispa que recorre el puente / Spark running along the bridge
			var ph := fmod(_t * 0.35 + float(b["id"].length()) * 0.13, 1.0)
			var sp := a0.lerp(a1, ph) + Vector2(0, -4)
			ci.draw_texture_rect(soft, Rect2(sp - Vector2(8, 8), Vector2(16, 16)), false, Color(col, 0.55))
			ci.draw_rect(Rect2(sp.round(), Vector2(1, 1)), Color(1, 1, 1, 0.9))

	## Polvo de estrellas que flota y titila / Floating, twinkling stardust
	func draw_motes(ci: CanvasItem) -> void:
		for m in _motes:
			var y := fposmod(m.y - _t * 6.0 * m.w + 900.0, 1600.0) - 800.0
			var p := Vector2(m.x + sin(_t * 0.5 + m.z) * 8.0, y)
			var a := (0.4 + 0.4 * sin(_t * 2.0 + m.z)) * m.w
			ci.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(0.85, 0.9, 1.0, a))

	func _ellipse(c: Vector2, r: Vector2, n := 16) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts
