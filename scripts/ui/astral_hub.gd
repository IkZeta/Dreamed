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
const SHRINK := 2
const PAJAMAS: Array[String] = ["bat", "shield", "book", "vacuum", "finger", "teddy", "ball", "laptop"]

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
	# Aviso de hablar encima de lo que tengas cerca / Talk prompt over whatever is close
	var spot := _world.near_spot()
	_prompt.visible = not spot.is_empty() and _talking.is_empty()
	if _prompt.visible:
		_prompt.text = Settings.controls_text(tr("HUB_TALK" if spot["kind"] == "npc" else "HUB_LOOK"))
		_prompt.reset_size()
		var p: Vector2 = _world.screen_of(spot["pos"] + Vector2(0, -float(spot.get("height", 80.0)))) * SHRINK
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
			_box_hearts.color = HubLayout.ISLES[id]["aura"]
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
	const BRIDGE_HALF := 11.0
	const STEP := 17.0
	const Statue := preload("res://scripts/ui/bestiary.gd").BestiaryPreview
	const STATUE_SIZE := Vector2(44, 58)
	const SPAWN := Vector2(0, 70)
	## Islas que siempre están / Islands that are always there
	const ALWAYS: Array[String] = ["nexus", "wardrobe", "museum"]

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
	var _motes: Array[Vector4] = []
	var _statues: Array[Control] = []

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
		_isles.sort_custom(func(a: String, b: String) -> bool: return _isle_pos(a).y < _isle_pos(b).y)
		for id in _isles:
			if id != "nexus":
				_add_bridge(id)
		_kroker = _prop(SPAWN, _draw_kroker)
		# Dos farolillos a la entrada de cada isla, del color de su dueño
		# Two little lanterns at the entrance of each island, in its owner's colour
		for b in _bridges:
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

	## Puente de piedras flotantes del centro a una isla / Bridge of floating stones from the centre to an island
	func _add_bridge(id: String) -> void:
		var a := _isle_pos("nexus")
		var b := _isle_pos(id)
		var poly_a: PackedVector2Array = _walk_polys["nexus"]
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
		var dir := (p1 - p0).normalized()
		var stones: Array[Vector3] = []
		var n := int(p0.distance_to(p1) / STEP)
		for i in range(1, n + 1):
			var q := p0.lerp(p1, (i - 0.5) / n)
			stones.append(Vector3(q.x, q.y, float((i * 7 + id.length()) % 3)))
		_bridges.append({"id": id, "a": p0 - dir * 14.0, "b": p1 + dir * 14.0, "from": p0, "to": p1, "stones": stones, "aura": HubLayout.ISLES[id]["aura"]})

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

	func _draw_npc(ci: CanvasItem, id: String, offset := Vector2.ZERO, flip := false) -> void:
		var sx := -NPC_SCALE if flip else NPC_SCALE
		var p := offset
		if offset.y > -2.0:
			ci.draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(10, 3)), Color(0, 0, 0, 0.3))
		NpcArt.draw(ci, Transform2D(0.0, Vector2(sx, NPC_SCALE), 0.0, p + Vector2(-100.0 * sx, -288.0 * NPC_SCALE)), id, _t)

	func _shadow(ci: CanvasItem, c: Vector2, r: Vector2, a := 0.28) -> void:
		ci.draw_colored_polygon(_ellipse(c, r), Color(0.03, 0.02, 0.1, a))

	# --- Centro / Centre ---

	func _build_nexus() -> void:
		var c := _isle_pos("nexus")
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

	# --- Armario / Wardrobe ---

	func _build_wardrobe() -> void:
		var c := _isle_pos("wardrobe")
		_piece(c + Vector2(0, -40), "hub_wardrobe", Vector2(64, 10), Vector2(0, -6))
		_piece(c + Vector2(122, -24), "hub_mirror", Vector2(10, 4))
		for i in PAJAMAS.size():
			var o := PAJAMAS[i]
			var at := c + Vector2(-112 + i * 32, 22)
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

	func _build_svinho() -> void:
		var c := _isle_pos("svinho")
		_piece(c + Vector2(128, 12), "hub_goal", Vector2(8, 16), Vector2(4, -10))
		_piece(c + Vector2(-122, -56), "hub_flag")
		_piece(c + Vector2(122, -60), "hub_flag")
		_piece(c + Vector2(-132, 20), "hub_ballbag", Vector2(12, 5))
		_npc_prop("svinho", c + Vector2(-60, 4))
		_ball = _prop(c + Vector2(-48, 4), func(ci: CanvasItem) -> void:
			var h: float = _ball.get_meta("h", 0.0)
			_shadow(ci, Vector2.ZERO, Vector2(4, 1.5), 0.3)
			ci.draw_set_transform(Vector2(0, -3.0 - h).round(), _t * 9.0, Vector2(0.45, 0.45))
			Sprites.draw(ci, "npc_ball")
			ci.draw_set_transform(Vector2.ZERO))

	func _tick_svinho() -> void:
		var c := _isle_pos("svinho")
		var foot := c + Vector2(-48, 4)
		var goal := c + Vector2(134, 0)
		var ph := fmod(_t, 2.8) / 2.8
		var h := 0.0
		var p: Vector2
		if ph < 0.3:
			var k := ph / 0.3
			p = foot.lerp(goal, k)
			h = sin(k * PI) * 26.0
		elif ph < 0.42:
			p = goal + Vector2(4, 0)
		else:
			var k := (ph - 0.42) / 0.58
			p = (goal + Vector2(4, 0)).lerp(foot, k * k * (3.0 - 2.0 * k))
		_ball.position = p
		_ball.set_meta("h", h)

	# --- Stolk: levanta pesas en su gimnasio / lifts weights in his gym ---

	func _build_stolk() -> void:
		var c := _isle_pos("stolk")
		_piece(c + Vector2(-78, -46), "hub_rack", Vector2(24, 5))
		_piece(c + Vector2(64, -38), "hub_bench", Vector2(20, 5))
		_piece(c + Vector2(100, 34), "hub_bag", Vector2(8, 4), Vector2(4, 0))
		var at := c + Vector2(-20, 18)
		_npc_prop("stolk", at)
		# La barra, delante de él / The barbell, in front of him
		_prop(at + Vector2(0, 0.5), func(ci: CanvasItem) -> void:
			var up := sin(_t * 2.4) * 0.5 + 0.5
			var y := roundf(-50.0 - up * 16.0)
			ci.draw_rect(Rect2(-26, y - 1, 52, 2), Color("c9cce0"))
			for sx in [-1.0, 1.0]:
				ci.draw_rect(Rect2(22 * sx - 3, y - 8, 6, 16), Color("2b2945"))
				ci.draw_rect(Rect2(27 * sx - 2, y - 6, 4, 12), Color("d8434f"))
			if up > 0.95 and fmod(_t, 2.6) < 1.3:
				ci.draw_string(UITheme.font("caps"), Vector2(16, -86), "¡30!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ff8f9e")))

	# --- Silly: entre pantallas con código verde / among screens of green code ---

	func _build_silly() -> void:
		var c := _isle_pos("silly")
		var desk := c + Vector2(0, -40)
		_blocks.append({"c": desk + Vector2(0, -6), "r": Vector2(36, 8)})
		_prop(desk, func(ci: CanvasItem) -> void:
			ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-70, -90), Vector2(140, 100)), false, Color("5ff2a0", 0.14))
			Sprites.draw(ci, "hub_monitors")
			for s: Rect2 in [Rect2(-31, -38, 16, 12), Rect2(-8, -44, 16, 14), Rect2(15, -38, 16, 12)]:
				for row in int(s.size.y / 3):
					var n := int(_t * 7.0 + row * 3 + s.position.x)
					var w := 3.0 + float((n * 37) % int(s.size.x - 4))
					ci.draw_rect(Rect2(s.position + Vector2(1, 1 + row * 3), Vector2(w, 1)), Color("5ff2a0", 0.85)))
		for x in [-74.0, 74.0]:
			var at := c + Vector2(x, -44)
			_blocks.append({"c": at, "r": Vector2(8, 3)})
			_prop(at, func(ci: CanvasItem) -> void:
				Sprites.draw(ci, "hub_server")
				for k in 6:
					var on := fmod(_t * 3.0 + k * 1.7 + x, 2.0) < 1.0
					ci.draw_rect(Rect2(Vector2(-4 + (k % 2) * 6, -30 + (k / 2) * 9), Vector2(1, 1)), Color("5ff2a0") if on else Color("1f6a4a")))
		_piece(c + Vector2(40, -12), "hub_gamerchair", Vector2(8, 3))
		_npc_prop("silly", c + Vector2(-6, -10))

	# --- Doc: examina un pie gigante con la lupa / examines a giant foot with the magnifier ---

	func _build_doc() -> void:
		var c := _isle_pos("doc")
		var couch := c + Vector2(46, -24)
		_piece(couch, "hub_couch", Vector2(30, 6), Vector2(0, -6))
		_piece(c + Vector2(-96, -42), "hub_cabinet", Vector2(12, 4))
		_piece(c + Vector2(-46, -50), "hub_poster", Vector2(9, 3))
		_npc_prop("doc", c + Vector2(-6, -8))
		_prop(couch + Vector2(0, 1), func(ci: CanvasItem) -> void:
			var mg := Vector2(4 + sin(_t * 1.3) * 12.0, -30 + cos(_t * 1.7) * 4.0).round()
			ci.draw_arc(mg, 6.0, 0, TAU, 16, Color("8f8fb8"), 2.0)
			ci.draw_circle(mg, 5.0, Color("dfe6ff", 0.35))
			ci.draw_line(mg + Vector2(4, 4), mg + Vector2(9, 9), Color("4a2e22"), 2.0))

	# --- Mr. Ad: sale en todas las teles del escaparate / is on every TV in the window ---

	func _build_ad() -> void:
		var c := _isle_pos("ad")
		var shop := c + Vector2(0, -24)
		_blocks.append({"c": shop + Vector2(0, -8), "r": Vector2(104, 10)})
		_spots.append({"kind": "npc", "id": "ad", "pos": c + Vector2(0, 6), "height": 100.0})
		_prop(shop, func(ci: CanvasItem) -> void:
			Sprites.draw(ci, "hub_shopfront")
			var glitch := fmod(_t, 5.0) < 0.25
			for k in 6:
				var tv := Vector2(-79 + (k % 3) * 56, -67 + (k / 3) * 27)
				var scr := Rect2(tv, Vector2(46, 18))
				ci.draw_rect(scr, Color("2a5a7a") if not glitch else Color("1e3a50"))
				if glitch:
					for s in 4:
						ci.draw_rect(Rect2(tv + Vector2(0, s * 5), Vector2(46, 2)), Color(1, 1, 1, randf() * 0.5))
				else:
					# Mr. Ad pequeñito en cada tele, mirando hacia Kroker / Tiny Mr. Ad on each TV, looking towards Kroker
					var flip := _pos.x < shop.x + tv.x + 23.0
					var s := 0.06
					var sx := -s if flip else s
					var base := tv + Vector2(23, 18)
					NpcArt.draw(ci, Transform2D(0.0, Vector2(sx, s), 0.0, base + Vector2(-100.0 * sx, -300.0 * s)), "ad", _t + k * 0.4)
				ci.draw_rect(Rect2(tv, Vector2(46, 1)), Color(1, 1, 1, 0.12))
			ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-110, -90), Vector2(220, 100)), false, Color("ffb04a", 0.08)))

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
			outfit, _t, {"facing": _facing, "walk": _walk, "moving": _moving, "armed": false})

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
		var dir := Vector2.ZERO
		if not frozen:
			dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var step := dir * SPEED * delta
		var moved := 0.0
		if step != Vector2.ZERO:
			var before := _pos
			if walkable(_pos + step):
				_pos += step
			elif walkable(_pos + Vector2(step.x, 0)):
				_pos.x += step.x
			elif walkable(_pos + Vector2(0, step.y)):
				_pos.y += step.y
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
			var stones: Array = b["stones"]
			# Hilo de luz que une las piedras / Thread of light joining the stones
			ci.draw_line(a0 + Vector2(0, 2), a1 + Vector2(0, 2), Color(col, 0.18), 1.0)
			for i in stones.size():
				var s: Vector3 = stones[i]
				var p := Vector2(s.x, s.y)
				var bob := roundf(sin(_t * 1.5 + i * 0.9) * 1.2)
				var tex := Sprites.tex("hub_step_%d" % int(s.z))
				ci.draw_texture(tex, (p - Vector2(tex.get_width() / 2.0, 4.0) + Vector2(0, bob)).round())
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
