extends Control
## Plano astral (el lobby, al estilo de Hades): Kroker camina por una gran plataforma flotante
## donde viven los personajes que ya conoce, cada uno en su rincón y haciendo lo suyo. Al
## acercarte puedes hablar con ellos (solo charla y lore). También están el armario con los
## pijamas y el museo con las estatuas de los enemigos (sustituye al bestiario).
## Astral plane (the lobby, Hades-style): Kroker walks around a large floating platform where
## the characters he has met live, each in their own corner doing their own thing. Walk up to
## them to chat (just talk and lore). There's also the wardrobe with the pajamas and the museum
## with statues of the enemies (it replaces the bestiary).
##
## El mundo se dibuja a media resolución (PixelView) con coordenadas propias: (0, 0) es el centro.
## The world is drawn at half resolution (PixelView) in its own coordinates: (0, 0) is the centre.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const SHRINK := 2
const SPEED := 150.0
const FLOOR := Rect2(-800, -560, 1600, 1120)
const TALK_RANGE := 46.0
const NPC_SCALE := 0.25
const KROKER_SCALE := 0.25
## Rincón de cada personaje: centro del rincón y dónde está él / Each character's corner: corner centre and where they stand
const ZONES := {
	"svinho": {"at": Vector2(-560, -230), "npc": Vector2(-640, -210)},
	"stolk": {"at": Vector2(-600, 110), "npc": Vector2(-600, 130)},
	"silly": {"at": Vector2(-610, 400), "npc": Vector2(-610, 420)},
	"doc": {"at": Vector2(560, -230), "npc": Vector2(500, -200)},
	"ad": {"at": Vector2(600, 110), "npc": Vector2(600, 196)},   # se le habla desde delante del escaparate / you talk to him from in front of the window
	"pinche": {"at": Vector2(610, 400), "npc": Vector2(610, 420)},
	"charo": {"at": Vector2(-280, -440), "npc": Vector2(-280, -418)},
	"magnus": {"at": Vector2(280, -440), "npc": Vector2(280, -410)},
}
const ZONE_SIZE := Vector2(300, 190)
const WARDROBE := Vector2(0, -250)
const MUSEUM := Vector2(0, 360)
const PAJAMAS: Array[String] = ["bat", "shield", "book", "vacuum", "finger", "teddy", "ball", "laptop"]

var _world: HubWorld
var _prompt: Label
var _hint: Label
var _box: PanelContainer
var _box_title: Label
var _box_role: Label
var _box_text: RichTextLabel
var _box_hearts: FriendHearts
var _talking := {}
var _leaving := false
## Por personaje, qué frase toca la próxima vez / Per character, which line comes next time
var _line_idx := {}


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Audio.play_music("music_astral", 1.0)
	_world = HubWorld.new()
	_world.hub = self
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
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _refresh_hint() -> void:
	if is_instance_valid(_hint):
		_hint.text = Settings.controls_text(tr("HUB_CONTROLS"))


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
	# Aviso de hablar encima de lo que tengas cerca / Talk prompt over whatever is close
	var spot := _world.near_spot()
	_prompt.visible = not spot.is_empty() and _talking.is_empty()
	if _prompt.visible:
		_prompt.text = Settings.controls_text(tr("HUB_TALK" if spot["kind"] == "npc" else "HUB_LOOK"))
		_prompt.reset_size()
		var p: Vector2 = _world.screen_of(spot["pos"] + Vector2(0, -spot.get("height", 80.0))) * SHRINK
		_prompt.position = p - Vector2(_prompt.size.x / 2.0, _prompt.size.y)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_accept"):
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
	_talking = spot
	_world.frozen = true
	var id: String = spot["id"]
	_box_hearts.visible = false
	match spot["kind"]:
		"npc":
			_box_title.text = tr("CHARO_NAME") if id == "charo" else tr("GIVER_%s_NAME" % id.to_upper())
			_box_role.text = tr("CHARS_CHARO_ROLE") if id == "charo" else tr("GIVER_%s_ROLE" % id.to_upper())
			_box_hearts.visible = true
			_box_hearts.color = HubWorld.AURA[id]
			_box_hearts.set_level(Progress.friend_level(id))
			Keywords.set_text(_box_text, _next_line(id))
			Audio.play("giver_" + id, -8.0)
		"pajama":
			var data := GameState.get_character(id)
			if GameState.weapon_unlocked(id):
				_box_title.text = tr(data["name"])
				_box_role.text = tr(data["weapon"])
				Keywords.set_text(_box_text, tr(data["desc"]))
			else:
				_box_title.text = "???"
				_box_role.text = ""
				Keywords.set_text(_box_text, tr("SELECT_UNLOCK_" + id.to_upper()))
			Audio.play("ui_click", -6.0)
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


func _leave() -> void:
	_leaving = true
	Audio.play("ui_click", -4.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(GameState.change_scene.bind(MAIN_MENU))


# --- El mundo / The world -------------------------------------------------------

class HubWorld extends Control:
	const AURA := {"svinho": Color("9be38a"), "stolk": Color("ff8f9e"), "silly": Color("5ff2ff"), "doc": Color("ffe3a3"),
		"ad": Color("ffb04a"), "pinche": Color("ff9a3a"), "magnus": Color("4fd39a"), "charo": Color("7fe0d0")}
	const Statue := preload("res://scripts/ui/bestiary.gd").BestiaryPreview
	const STATUE_SIZE := Vector2(56, 70)

	var hub: Node
	var frozen := false
	var _pos := Vector2(0, 40)
	var _cam := Vector2(0, 40)
	var _t := 0.0
	var _walk := 0.0
	var _moving := 0.0
	var _facing := 1.0
	var _spots: Array[Dictionary] = []
	var _statues := {}
	var _stone: ShaderMaterial
	var _stars: Array[Vector3] = []

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		clip_contents = true
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 260:
			_stars.append(Vector3(rng.randf_range(-1200, 1200), rng.randf_range(-900, 900), rng.randf_range(0.4, 1.4)))
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.3, 0.59, 0.11));\n\tCOLOR = vec4(vec3(g) * vec3(0.78, 0.8, 0.92) + vec3(0.08, 0.08, 0.12), c.a);\n}"
		_stone = ShaderMaterial.new()
		_stone.shader = sh
		_build_spots()

	## Sitios con los que se puede hablar o mirar / Spots you can talk to or look at
	func _build_spots() -> void:
		for id: String in ZONES:
			if _met(id):
				_spots.append({"kind": "npc", "id": id, "pos": ZONES[id]["npc"], "height": 84.0})
		for i in PAJAMAS.size():
			_spots.append({"kind": "pajama", "id": PAJAMAS[i], "pos": _stand_pos(i), "height": 76.0})
		for i in Progress.BESTIARY.size():
			var id: String = Progress.BESTIARY[i]
			var p := _pedestal_pos(i)
			_spots.append({"kind": "statue", "id": id, "pos": p, "height": 92.0})
			if Progress.has_seen(id):
				var st: Control = Statue.new()
				st.id = id
				st.size = STATUE_SIZE
				st.custom_minimum_size = STATUE_SIZE
				add_child(st)
				_statues[id] = st

	static func _met(id: String) -> bool:
		return preload("res://scripts/ui/characters_menu.gd").met(id)

	func _stand_pos(i: int) -> Vector2:
		return WARDROBE + Vector2(-147 + i * 42, 6)

	func _pedestal_pos(i: int) -> Vector2:
		return MUSEUM + Vector2(-196 + (i % 8) * 56, -40 + (i / 8) * 96)

	func screen_of(p: Vector2) -> Vector2:
		return p - _cam + size / 2.0

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
		var dir := Vector2.ZERO
		if not frozen:
			dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var spd := dir.length() * SPEED
		_pos += dir * SPEED * delta
		_pos = Vector2(clampf(_pos.x, FLOOR.position.x + 20, FLOOR.end.x - 20), clampf(_pos.y, FLOOR.position.y + 40, FLOOR.end.y - 10))
		# No atravesar a los personajes / Don't walk through the characters
		for s in _spots:
			if s["kind"] == "npc":
				var to: Vector2 = _pos - s["pos"]
				if to.length() < 22.0:
					_pos = s["pos"] + to.normalized() * 22.0 if to.length() > 0.01 else _pos + Vector2(22, 0)
		if absf(dir.x) > 0.1:
			_facing = signf(dir.x)
		_moving = move_toward(_moving, clampf(spd / 100.0, 0.0, 1.0), delta * 8.0)
		_walk += spd * delta * 0.09
		_cam = _cam.lerp(_pos + Vector2(0, -30), minf(1.0, delta * 5.0))
		for id: String in _statues:
			var st: Control = _statues[id]
			st.position = screen_of(_pedestal_pos(Progress.BESTIARY.find(id))) - Vector2(STATUE_SIZE.x / 2.0, STATUE_SIZE.y + 10.0)
			var e: Node = st.get("_enemy")
			if e and e.material != _stone:
				e.material = _stone
		queue_redraw()

	# --- Dibujo / Drawing ---

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("120c3a"))
		for s in _stars:
			var p := Vector2(s.x, s.y) - _cam * 0.4 + size / 2.0
			p = Vector2(fposmod(p.x, size.x + 40.0) - 20.0, fposmod(p.y, size.y + 40.0) - 20.0)
			draw_circle(p, s.z, Color(UITheme.BONE, 0.35 + 0.35 * sin(_t * 1.4 + s.x)))
		_draw_floor()
		for id: String in ZONES:
			if _met(id):
				_draw_zone(id)
		_draw_wardrobe()
		_draw_museum()
		_draw_kroker()

	func _draw_floor() -> void:
		var r := Rect2(screen_of(FLOOR.position), FLOOR.size)
		# Canto de la plataforma flotando / Edge of the floating platform
		draw_rect(Rect2(r.position + Vector2(0, r.size.y), Vector2(r.size.x, 26)), Color("2a2a66"))
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.3, r.size.y + 26), r.position + Vector2(r.size.x * 0.5, r.size.y + 120), r.position + Vector2(r.size.x * 0.7, r.size.y + 26)]), Color("2a2a66"))
		draw_rect(r, Color("3e3a86"))
		# Losas / Flagstones
		var tile := 80.0
		for gx in range(int(FLOOR.size.x / tile)):
			for gy in range(int(FLOOR.size.y / tile)):
				var tp := r.position + Vector2(gx, gy) * tile
				if tp.x > size.x or tp.y > size.y or tp.x + tile < 0 or tp.y + tile < 0:
					continue
				var shade := 0.04 * float((gx * 7 + gy * 13) % 3)
				draw_rect(Rect2(tp + Vector2(1, 1), Vector2(tile - 2, tile - 2)), Color(0.27 + shade, 0.25 + shade, 0.55 + shade))
		draw_rect(r, Color("8f86d6", 0.6), false, 2.0)
		# Centro: un círculo de runas donde aparece Kroker / Centre: a rune circle where Kroker appears
		var c := screen_of(Vector2(0, 40))
		draw_arc(c, 46.0, 0, TAU, 40, Color("f6d993", 0.5), 2.0)
		draw_arc(c, 36.0, _t * 0.3, _t * 0.3 + TAU * 0.8, 32, Color("9be3ff", 0.4), 1.5)

	## Suelo de cada rincón / Floor of each corner
	func _patch(id: String, col: Color, edge: Color) -> Rect2:
		var r := Rect2(screen_of(ZONES[id]["at"]) - ZONE_SIZE / 2.0, ZONE_SIZE)
		draw_rect(r, col)
		draw_rect(r, edge, false, 2.0)
		draw_texture_rect(DreamBackground.soft_texture(), r.grow(30), false, Color(AURA[id], 0.08))
		return r

	func _npc(id: String, offset := Vector2.ZERO, flip := false) -> void:
		var p: Vector2 = screen_of(ZONES[id]["npc"]) + offset
		var sx := -NPC_SCALE if flip else NPC_SCALE
		NpcArt.draw(self, Transform2D(0.0, Vector2(sx, NPC_SCALE), 0.0, p + Vector2(-100.0 * sx, -288.0 * NPC_SCALE)), id, _t)

	func _draw_zone(id: String) -> void:
		match id:
			"svinho": _zone_svinho()
			"stolk": _zone_stolk()
			"silly": _zone_silly()
			"doc": _zone_doc()
			"ad": _zone_ad()
			"pinche": _zone_pinche()
			"charo": _zone_charo()
			"magnus": _zone_magnus()

	## Svinho chuta a portería: el balón entra, la red se mueve y vuelve rodando
	## Svinho shoots at goal: the ball goes in, the net ripples and it rolls back
	func _zone_svinho() -> void:
		var r := _patch("svinho", Color("3f9a4a"), Color("f4f1e6"))
		for k in 5:
			draw_rect(Rect2(r.position + Vector2(k * 60, 0), Vector2(30, r.size.y)), Color(1, 1, 1, 0.05))
		draw_line(r.position + Vector2(r.size.x / 2.0, 0), r.position + Vector2(r.size.x / 2.0, r.size.y), Color(1, 1, 1, 0.5), 2.0)
		draw_arc(r.get_center(), 26.0, 0, TAU, 28, Color(1, 1, 1, 0.5), 2.0)
		# Portería a la derecha / Goal on the right
		var g := r.position + Vector2(r.size.x - 34, r.size.y / 2.0 - 34)
		var cycle := 2.6
		var ph := fmod(_t, cycle) / cycle
		var net_k := clampf(1.0 - absf(ph - 0.36) * 8.0, 0.0, 1.0)
		for k in 6:
			draw_line(g + Vector2(4 + k * 5, 0), g + Vector2(4 + k * 5 + net_k * 4.0, 50), Color(1, 1, 1, 0.35), 1.0)
		for k in 6:
			draw_line(g + Vector2(4, k * 10), g + Vector2(30 + net_k * 4.0, k * 10), Color(1, 1, 1, 0.35), 1.0)
		draw_rect(Rect2(g, Vector2(4, 54)), Color("f4f1e6"))
		draw_rect(Rect2(g, Vector2(30, 4)), Color("f4f1e6"))
		_npc("svinho")
		# El balón / The ball
		var foot := screen_of(ZONES["svinho"]["npc"]) + Vector2(14, -4)
		var goal := g + Vector2(18, 30)
		var bp: Vector2
		if ph < 0.32:
			var k := ph / 0.32
			bp = foot.lerp(goal, k) + Vector2(0, -sin(k * PI) * 30.0)
		elif ph < 0.45:
			bp = goal
		else:
			bp = goal.lerp(foot, (ph - 0.45) / 0.55)
		draw_set_transform(bp, _t * 8.0, Vector2(0.5, 0.5))
		Sprites.draw(self, "npc_ball")
		draw_set_transform(Vector2.ZERO)

	## Stolk en el gimnasio levantando pesas / Stolk in the gym lifting weights
	func _zone_stolk() -> void:
		var r := _patch("stolk", Color("3a3a4a"), Color("8a8aa0"))
		for k in 3:
			draw_rect(Rect2(r.position + Vector2(20 + k * 30, 20), Vector2(14, 40)), Color("4a4f72"))
			draw_rect(Rect2(r.position + Vector2(16 + k * 30, 18), Vector2(22, 6)), Color("c9cce0"))
		draw_rect(Rect2(r.position + Vector2(r.size.x - 80, r.size.y - 50), Vector2(60, 12)), Color("8a5a3e"))
		draw_rect(Rect2(r.position + Vector2(r.size.x - 74, r.size.y - 38), Vector2(6, 16)), Color("4a4f72"))
		draw_rect(Rect2(r.position + Vector2(r.size.x - 32, r.size.y - 38), Vector2(6, 16)), Color("4a4f72"))
		_npc("stolk")
		# Barra que sube y baja / Barbell going up and down
		var p := screen_of(ZONES["stolk"]["npc"])
		var up := (sin(_t * 2.4) * 0.5 + 0.5)
		var y := -52.0 - up * 18.0
		draw_line(p + Vector2(-26, y), p + Vector2(26, y), Color("c9cce0"), 3.0)
		for sx in [-1.0, 1.0]:
			draw_rect(Rect2(p + Vector2(22 * sx - 4, y - 9), Vector2(8, 18)), Color("2b2945"))
			draw_rect(Rect2(p + Vector2(28 * sx - 3, y - 7), Vector2(6, 14)), Color("e2434f"))
		if up > 0.95 and fmod(_t, 2.6) < 1.3:
			draw_string(UITheme.font("caps"), p + Vector2(18, -84), "¡30!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ff8f9e"))

	## Silly en su cuarto oscuro, rodeada de pantallas con números verdes
	## Silly in her dark room, surrounded by screens of green numbers
	func _zone_silly() -> void:
		var r := _patch("silly", Color("0b0a1a"), Color("1f6a4a"))
		for k in 4:
			var sp := r.position + Vector2(20 + k * 68, 16)
			draw_rect(Rect2(sp, Vector2(56, 40)), Color("1e1f2e"))
			draw_rect(Rect2(sp + Vector2(3, 3), Vector2(50, 34)), Color("06140c"))
			for row in 5:
				var n := int(_t * 6.0 + row * 3 + k * 7)
				var w := 10.0 + float((n * 37) % 30)
				draw_rect(Rect2(sp + Vector2(6, 6 + row * 6), Vector2(w, 2)), Color("5ff2a0", 0.75))
			draw_texture_rect(DreamBackground.soft_texture(), Rect2(sp - Vector2(10, 10), Vector2(76, 60)), false, Color("5ff2a0", 0.08))
		_npc("silly")

	## Doc en su clínica podológica: un pie gigante en la camilla y la lupa
	## Doc in his podiatry clinic: a giant foot on the couch and the magnifying glass
	func _zone_doc() -> void:
		var r := _patch("doc", Color("e8eaf4"), Color("9aa0c0"))
		for gx in 6:
			draw_line(r.position + Vector2(gx * 50, 0), r.position + Vector2(gx * 50, r.size.y), Color(0.6, 0.62, 0.75, 0.4), 1.0)
		for gy in 4:
			draw_line(r.position + Vector2(0, gy * 50), r.position + Vector2(r.size.x, gy * 50), Color(0.6, 0.62, 0.75, 0.4), 1.0)
		# Camilla y pie / Couch and foot
		var c := r.position + Vector2(r.size.x - 110, r.size.y / 2.0 + 10)
		draw_rect(Rect2(c + Vector2(-40, -6), Vector2(90, 14)), Color("5b9ad6"))
		draw_rect(Rect2(c + Vector2(-36, 8), Vector2(6, 14)), Color("4a4f72"))
		draw_rect(Rect2(c + Vector2(40, 8), Vector2(6, 14)), Color("4a4f72"))
		var foot := PackedVector2Array([c + Vector2(-10, -6), c + Vector2(-10, -30), c + Vector2(4, -32), c + Vector2(30, -14), c + Vector2(30, -6)])
		draw_colored_polygon(foot, Color("f2c9a8"))
		for k in 5:
			draw_circle(c + Vector2(30 - k * 0.5, -16 + k * 2.2 - 6) + Vector2(2, 0), 2.6 - k * 0.3, Color("f2c9a8"))
		_npc("doc")
		var mg := c + Vector2(-26 + sin(_t * 1.3) * 10.0, -30 + cos(_t * 1.7) * 4.0)
		draw_arc(mg, 7.0, 0, TAU, 16, Color("8f8fb8"), 2.0)
		draw_circle(mg, 6.0, Color("dfe6ff", 0.35))
		draw_line(mg + Vector2(5, 5), mg + Vector2(11, 11), Color("4a2e22"), 2.0)

	## Mr. Ad sale en todas las teles del escaparate / Mr. Ad is on every TV in the shop window
	func _zone_ad() -> void:
		var r := _patch("ad", Color("3a2e4a"), Color("ffb04a"))
		var glass := Rect2(r.position + Vector2(16, 10), Vector2(r.size.x - 32, r.size.y - 50))
		draw_rect(glass, Color("1a1438"))
		draw_rect(glass, Color("c9a27a"), false, 3.0)
		var glitch := fmod(_t, 5.0) < 0.25
		for k in 6:
			var tv := glass.position + Vector2(10 + (k % 3) * 86, 10 + (k / 3) * 60)
			draw_rect(Rect2(tv, Vector2(74, 50)), Color("9aa0c0"))
			draw_rect(Rect2(tv + Vector2(4, 4), Vector2(66, 42)), Color("1e3a50"))
			if glitch:
				for s in 6:
					draw_rect(Rect2(tv + Vector2(4, 4 + s * 7), Vector2(66, 3)), Color(1, 1, 1, randf() * 0.5))
			else:
				# Mr. Ad pequeñito en cada tele, mirando hacia Kroker / Tiny Mr. Ad on each TV, looking towards Kroker
				var flip := _pos.x < ZONES["ad"]["npc"].x
				var s := 0.14
				var sx := -s if flip else s
				var base := tv + Vector2(37, 50)
				NpcArt.draw(self, Transform2D(0.0, Vector2(sx, s), 0.0, base + Vector2(-100.0 * sx, -300.0 * s)), "ad", _t + k * 0.4)
		draw_texture_rect(DreamBackground.soft_texture(), glass, false, Color(1, 1, 1, 0.06))

	## El Pinche en una cocina en llamas, corriendo de un lado a otro con el extintor
	## The Kitchen Boy in a kitchen on fire, running back and forth with the extinguisher
	func _zone_pinche() -> void:
		var r := _patch("pinche", Color("d8d0c0"), Color("8a6440"))
		for gx in 10:
			for gy in 7:
				if (gx + gy) % 2 == 0:
					draw_rect(Rect2(r.position + Vector2(gx * 30, gy * 27), Vector2(30, 27)), Color(0, 0, 0, 0.08))
		var counter := Rect2(r.position + Vector2(16, 14), Vector2(r.size.x - 32, 40))
		draw_rect(counter, Color("8a8fb0"))
		draw_rect(Rect2(counter.position, Vector2(counter.size.x, 6)), Color("c9cce0"))
		for k in 3:
			var f := counter.position + Vector2(40 + k * 90, 4)
			for j in 4:
				var h := 14.0 + 8.0 * sin(_t * 10.0 + j * 1.7 + k)
				var x := f.x - 12 + j * 8
				draw_colored_polygon(PackedVector2Array([Vector2(x - 5, f.y), Vector2(x, f.y - h), Vector2(x + 5, f.y)]), Color("ff9a3a"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 2, f.y), Vector2(x, f.y - h * 0.5), Vector2(x + 2, f.y)]), Color("ffe08a"))
			draw_texture_rect(DreamBackground.soft_texture(), Rect2(f - Vector2(40, 40), Vector2(80, 60)), false, Color("ff9a3a", 0.25))
		var run := sin(_t * 1.6)
		_npc("pinche", Vector2(run * 70.0, 0), cos(_t * 1.6) < 0.0)
		# Nubecitas del extintor / Little extinguisher clouds
		if fmod(_t, 1.9) < 0.6:
			var p := screen_of(ZONES["pinche"]["npc"]) + Vector2(run * 70.0, -50)
			for k in 3:
				draw_circle(p + Vector2(k * 9, -k * 4) * (1.0 if cos(_t * 1.6) >= 0.0 else -1.0), 6.0 + k, Color(1, 1, 1, 0.6))

	## Charo teje en su sillón / Charo knitting in her armchair
	func _zone_charo() -> void:
		var r := _patch("charo", Color("5a3a5a"), Color("c9a27a"))
		var c := screen_of(ZONES["charo"]["npc"])
		draw_rect(Rect2(c + Vector2(-40, -70), Vector2(80, 70)), Color("4fa89a"))
		draw_rect(Rect2(c + Vector2(-40, -70), Vector2(80, 8)), Color("6fc8b8"))
		_npc("charo", Vector2(0, -6))
		# Brazos del sillón por delante / Armchair arms in front
		draw_rect(Rect2(c + Vector2(-48, -34), Vector2(16, 36)), Color("3f8a7e"))
		draw_rect(Rect2(c + Vector2(32, -34), Vector2(16, 36)), Color("3f8a7e"))
		draw_rect(Rect2(c + Vector2(-32, -14), Vector2(64, 16)), Color("4fa89a"))
		# Agujas que se cruzan y la bufanda que crece / Clicking needles and the growing scarf
		var k := sin(_t * 7.0) * 4.0
		draw_line(c + Vector2(-6 + k, -48), c + Vector2(10 + k, -36), Color("dfe6ff"), 1.5)
		draw_line(c + Vector2(6 - k, -48), c + Vector2(-10 - k, -36), Color("dfe6ff"), 1.5)
		var scarf := 10.0 + fmod(_t * 3.0, 40.0)
		draw_rect(Rect2(c + Vector2(-4, -38), Vector2(8, scarf * 0.5)), Color("e85d75"))
		var ball := c + Vector2(40, 4)
		draw_circle(ball, 7.0, Color("e85d75"))
		draw_arc(ball, 4.0, _t, _t + 2.0, 8, Color("ff8fb1"), 1.5)
		draw_line(ball, c + Vector2(0, -38 + scarf * 0.5), Color("e85d75"), 1.0)

	## Magnus en su despacho: caja fuerte, cuadro y el teléfono que suena
	## Magnus in his office: safe, painting and the ringing phone
	func _zone_magnus() -> void:
		var r := _patch("magnus", Color("4a1e2a"), Color("c9961e"))
		draw_rect(Rect2(r.position + Vector2(14, 12), Vector2(46, 50)), Color("4a4f72"))
		draw_rect(Rect2(r.position + Vector2(18, 16), Vector2(38, 42)), Color("3a3f5c"))
		draw_circle(r.position + Vector2(37, 37), 8.0, Color("9aa0c0"))
		draw_line(r.position + Vector2(37, 37), r.position + Vector2(37, 37) + Vector2.from_angle(_t * 0.5) * 7.0, Color("2b2945"), 2.0)
		draw_rect(Rect2(r.position + Vector2(r.size.x - 70, 14), Vector2(54, 38)), Color("c9961e"))
		draw_rect(Rect2(r.position + Vector2(r.size.x - 66, 18), Vector2(46, 30)), Color("2f6e4a"))
		draw_string(UITheme.font("caps"), r.position + Vector2(r.size.x - 52, 40), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2c94c"))
		_npc("magnus")
		if fmod(_t, 6.0) < 1.2:
			var p := screen_of(ZONES["magnus"]["npc"]) + Vector2(36, -64)
			draw_string(UITheme.font("caps"), p + Vector2(randf_range(-1, 1), 0), "RING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f2c94c"))

	## El armario con los pijamas en sus maniquíes (los que faltan, el soporte vacío)
	## The wardrobe with the pajamas on their stands (the missing ones, an empty stand)
	func _draw_wardrobe() -> void:
		var c := screen_of(WARDROBE)
		var body := Rect2(c + Vector2(-180, -110), Vector2(360, 130))
		draw_rect(Rect2(body.position + Vector2(-8, -12), body.size + Vector2(16, 18)), Color("5a3a2a"))
		draw_rect(body, Color("2a1e30"))
		draw_rect(Rect2(body.position + Vector2(0, 8), Vector2(body.size.x, 4)), Color("c9a27a"))
		# Puertas abiertas a los lados / Doors open at the sides
		draw_colored_polygon(PackedVector2Array([body.position + Vector2(-8, -12), body.position + Vector2(-40, -2), body.position + Vector2(-40, body.size.y), body.position + Vector2(-8, body.size.y + 6)]), Color("7a5236"))
		draw_colored_polygon(PackedVector2Array([body.end + Vector2(8, -body.size.y - 12), body.end + Vector2(40, -body.size.y - 2), body.end + Vector2(40, 0), body.end + Vector2(8, 6)]), Color("7a5236"))
		for i in PAJAMAS.size():
			var o := PAJAMAS[i]
			var p := screen_of(_stand_pos(i))
			# Soporte / Stand
			draw_rect(Rect2(p + Vector2(-10, -2), Vector2(20, 4)), Color("8a8fb0"))
			draw_rect(Rect2(p + Vector2(-1, -64), Vector2(2, 62)), Color("8a8fb0"))
			draw_line(p + Vector2(-12, -64), p + Vector2(12, -64), Color("8a8fb0"), 2.0)
			if GameState.weapon_unlocked(o):
				var xf := Transform2D(0.0, Vector2(KROKER_SCALE, KROKER_SCALE), 0.0, p + Vector2(-100.0 * KROKER_SCALE, -288.0 * KROKER_SCALE - 4.0))
				draw_set_transform_matrix(xf)
				Sprites.draw(self, "kroker_leg_l_" + o)
				Sprites.draw(self, "kroker_leg_r_" + o)
				Sprites.draw(self, "kroker_arm_l_" + o)
				Sprites.draw(self, "kroker_arm_r_" + o)
				Sprites.draw(self, "kroker_torso_" + o)
				draw_set_transform(Vector2.ZERO)
		draw_string(UITheme.font("caps"), c + Vector2(-40, -128), tr("HUB_WARDROBE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f6d993"))

	## Museo: pedestales con estatuas de los enemigos ya vistos (las estatuas son controles hijos)
	## Museum: pedestals with statues of the enemies already seen (the statues are child controls)
	func _draw_museum() -> void:
		var c := screen_of(MUSEUM)
		var area := Rect2(c + Vector2(-240, -150), Vector2(480, 230))
		draw_rect(area, Color("4a4592"))
		draw_rect(area, Color("cfc8ec", 0.6), false, 2.0)
		draw_string(UITheme.font("caps"), area.position + Vector2(10, 14), tr("HUB_MUSEUM"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f6d993"))
		for i in Progress.BESTIARY.size():
			var p := screen_of(_pedestal_pos(i))
			draw_rect(Rect2(p + Vector2(-18, -10), Vector2(36, 12)), Color("cfc8ec"))
			draw_rect(Rect2(p + Vector2(-20, -14), Vector2(40, 5)), Color("e8e4f6"))
			draw_rect(Rect2(p + Vector2(-16, 2), Vector2(32, 6)), Color("9a94c0"))

	func _draw_kroker() -> void:
		var p := screen_of(_pos)
		draw_colored_polygon(_ellipse(p, Vector2(14, 4)), Color(0, 0, 0, 0.3))
		var outfit := GameState.selected_character if GameState.weapon_unlocked(GameState.selected_character) else "bat"
		KrokerArt.draw(self, Transform2D(0.0, Vector2(KROKER_SCALE, KROKER_SCALE), 0.0, p + Vector2(-100.0 * KROKER_SCALE, -288.0 * KROKER_SCALE)),
			outfit, _t, {"facing": _facing, "walk": _walk, "moving": _moving, "armed": false})

	func _ellipse(c: Vector2, r: Vector2, n := 16) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts
