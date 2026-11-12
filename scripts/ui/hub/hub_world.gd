class_name HubWorld
extends Control


const PAJAMAS := AstralHubData.PAJAMAS

signal zone_entered(id: String)

const SPEED := 150.0
const TALK_RANGE := 40.0
const NPC_SCALE := 0.25
const KROKER_SCALE := 0.25
const BRIDGE_HALF := 17.0
const STEP := 15.0
const Statue := preload("res://scripts/ui/enemy_statue.gd")
const STATUE_SIZE := Vector2(44, 58)
const SPAWN := Vector2(0, 70)
## Islas que siempre están / Islands that are always there
const ALWAYS: Array[String] = ["nexus", "wardrobe", "museum", "training"]
## Orden de las islas alrededor del centro (para los pasillos entre vecinas) / Order of the islands around the centre (for the walkways between neighbours)
const RING: Array[String] = ["wardrobe", "magnus", "doc", "ad", "pinche", "museum", "silly", "stolk", "svinho", "charo"]
## Islas lejanas: de dónde sale su puente (la primera que esté; Lil Key, de todas)
## Far islands: where their bridge comes from (the first one present; Lil Key, from all of them)
const FAR := {"training": ["wardrobe"], "superk": ["magnus", "wardrobe"], "lilkey": ["svinho", "stolk"], "lynx": ["doc", "ad"], "luna": ["superk", "training", "wardrobe"]}

var frozen := false
var _pos := SPAWN
var _cam := SPAWN
var _t := 0.0
var _walk := 0.0
var _still := 0.0
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
var _wardrobe: HubWardrobe
var _museum: HubMuseum
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
	# Piedra tallada. Cada estatua se pinta una vez a triple tamaño en su propia textura; aquí se
	# reduce promediando (así los bordes y las formas salen limpios) y se esculpe: el relieve sale
	# de la forma (luz de arriba a la izquierda, sombra en los huecos y abajo), el color del enemigo
	# solo deja un poco de detalle, y todo pasa a cinco tonos de piedra gris lila con contorno.
	# Carved stone. Each statue is painted once at triple size into its own texture; here it's
	# shrunk by averaging (so edges and shapes come out clean) and sculpted: the relief comes from the
	# shape (light from the top left, shadow in hollows and lower down), the enemy's colours only leave
	# a little detail, and everything becomes five tones of lilac-grey stone with an outline.
	sh.code = """shader_type canvas_item;
const int SS = 3;
const vec3 RAMP[5] = vec3[](vec3(0.20, 0.17, 0.34), vec3(0.36, 0.33, 0.56), vec3(0.55, 0.52, 0.72), vec3(0.74, 0.72, 0.86), vec3(0.92, 0.90, 0.95));
vec4 cell(sampler2D t, vec2 uv, vec2 tx) {
	vec4 acc = vec4(0.0);
	for (int y = 0; y < SS; y++) {
		for (int x = 0; x < SS; x++) {
			vec4 c = texture(t, uv + (vec2(float(x), float(y)) - 1.0) * tx);
			acc += vec4(c.rgb * c.a, c.a);
		}
	}
	return acc / float(SS * SS);
}
float A(sampler2D t, vec2 uv, vec2 tx) { return cell(t, uv, tx).a; }
void fragment() {
	vec2 tx = TEXTURE_PIXEL_SIZE;
	vec2 px = tx * float(SS);
	vec4 c = cell(TEXTURE, UV, tx);
	float a = c.a;
	float n = max(max(A(TEXTURE, UV + vec2(px.x, 0.0), tx), A(TEXTURE, UV - vec2(px.x, 0.0), tx)),
		max(A(TEXTURE, UV + vec2(0.0, px.y), tx), A(TEXTURE, UV - vec2(0.0, px.y), tx)));
	if (a < 0.45) {
		if (n >= 0.45) { COLOR = vec4(0.09, 0.06, 0.15, 1.0); } else { discard; }
	} else {
		float lum = dot(c.rgb / max(a, 0.001), vec3(0.3, 0.59, 0.11));
		// Relieve por la forma: cuánto "aire" hay arriba a la izquierda y abajo a la derecha
		// Relief from the shape: how much "air" there is to the top left and to the bottom right
		float r = 2.0;
		float tl = 1.0 - A(TEXTURE, UV - px * r, tx);
		float br = 1.0 - A(TEXTURE, UV + px * r, tx);
		float near = 1.0 - min(min(A(TEXTURE, UV + vec2(px.x, 0.0) * 1.5, tx), A(TEXTURE, UV - vec2(px.x, 0.0) * 1.5, tx)),
			min(A(TEXTURE, UV + vec2(0.0, px.y) * 1.5, tx), A(TEXTURE, UV - vec2(0.0, px.y) * 1.5, tx)));
		// Detalle: lo que el color tiene de más claro u oscuro que su alrededor (ojos, bocas, pliegues)
		// Detail: how much lighter or darker the colour is than its surroundings (eyes, mouths, folds)
		float avg = 0.0;
		float wsum = 0.0;
		for (int i = 0; i < 4; i++) {
			vec2 o = vec2(i == 0 ? 1.0 : (i == 1 ? -1.0 : 0.0), i == 2 ? 1.0 : (i == 3 ? -1.0 : 0.0)) * px * 1.5;
			vec4 q = cell(TEXTURE, UV + o, tx);
			if (q.a > 0.45) { avg += dot(q.rgb / q.a, vec3(0.3, 0.59, 0.11)); wsum += 1.0; }
		}
		float detail = wsum > 0.0 ? clamp(lum - avg / wsum, -0.18, 0.18) : 0.0;
		float g = 0.55 + (pow(lum, 0.6) - 0.5) * 0.30 + detail * 1.1 + tl * 0.36 - br * 0.32 - near * 0.08;
		g -= UV.y * 0.10;
		int k = int(clamp(g, 0.0, 0.999) * 5.0);
		COLOR = vec4(RAMP[k], 1.0);
	}
}"""
	_stone = ShaderMaterial.new()
	_stone.shader = sh
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 70:
		_motes.append(Vector4(rng.randf_range(-900, 900), rng.randf_range(-700, 800), rng.randf_range(0.0, TAU), rng.randf_range(0.5, 1.0)))
	_build()

static func _met(id: String) -> bool:
	return Progress.met(id)

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
		if id != "nexus" and not FAR.has(id):
			_add_bridge("nexus", id)
	# Las islas lejanas se alcanzan desde sus vecinas (el tatami desde el armario...)
	# The far islands are reached from their neighbours (the training mat from the wardrobe...)
	for id: String in FAR:
		if not _isles.has(id):
			continue
		var done := 0
		for from: String in FAR[id]:
			if _isles.has(from) and (done == 0 or id == "lilkey" or id == "lynx"):
				_add_bridge(from, id)
				done += 1
		if done == 0:
			_add_bridge("nexus", id)
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
	_wardrobe = HubWardrobe.new(self)
	_wardrobe.build()
	_museum = HubMuseum.new(self)
	_museum.build()
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
			"superk": _build_superk()
			"lilkey": _build_lilkey()
			"lynx": _build_lynx()
			"luna": _build_luna()
	_plan_visits()

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

# --- Visitas: con amistad 3, algunos personajes van a ver a otro y charlan / Visits: at friendship 3, some characters go and see another and chat ---

const VISIT_FRIEND := 3
## [visitante, anfitrión]. Solo visitan los que se dibujan enteros (Silly y Mr. Ad reciben)
## [visitor, host]. Only those drawn in full visit (Silly and Mr. Ad receive visitors)
const CHATS := [["svinho", "stolk"], ["stolk", "superk"], ["doc", "pinche"], ["pinche", "charo"], ["charo", "doc"],
	["magnus", "silly"], ["superk", "lilkey"], ["lilkey", "svinho"], ["lynx", "ad"]]
## Quién está de visita fuera de su isla / Who is away visiting
var _away := {}
var _drawing_guest := false

func _plan_visits() -> void:
	var ok := []
	for c: Array in CHATS:
		if _isles.has(c[0]) and _isles.has(c[1]) and Progress.friend_level(c[0]) >= VISIT_FRIEND:
			ok.append(c)
	ok.shuffle()
	# Casi siempre hay alguna visita; con muchos amigos, a veces dos / There's almost always a visit; with many friends, sometimes two
	var n := 0 if randf() < 0.25 else (2 if ok.size() >= 4 and randf() < 0.4 else 1)
	var used := {}
	for c: Array in ok:
		if n <= 0:
			break
		if used.has(c[0]) or used.has(c[1]):
			continue
		if _add_visit(c[0], c[1]):
			used[c[0]] = true
			used[c[1]] = true
			n -= 1

func _add_visit(guest: String, host: String) -> bool:
	var hs := {}
	for s in _spots:
		if s["kind"] == "npc" and s["id"] == host:
			hs = s
	if hs.is_empty():
		return false
	# Se va de su isla: sin dibujo, sin charla y sin estorbar / Leaves their island: no drawing, no chat and not in the way
	for s in _spots.duplicate():
		if s["kind"] == "npc" and s["id"] == guest:
			_spots.erase(s)
			for b in _blocks.duplicate():
				if (b["c"] as Vector2).distance_to(s["pos"]) < 1.0:
					_blocks.erase(b)
	_away[guest] = true
	var centre := _isle_pos(host)
	var hp: Vector2 = hs["pos"]
	var side := 1.0 if hp.x <= centre.x else -1.0
	var at := hp + Vector2(side * 40.0, 10.0)
	var poly: PackedVector2Array = _walk_polys[host]
	var tries := 0
	while not Geometry2D.is_point_in_polygon(at, poly) and tries < 40:
		at = at.move_toward(centre, 3.0)
		tries += 1
	at = at.round()
	_blocks.append({"c": at, "r": Vector2(10, 5)})
	var key := "CHAT_%s_%s" % [guest.to_upper(), host.to_upper()]
	var lines := []
	for i in 4:
		lines.append([guest if i % 2 == 0 else host, "%s_%d" % [key, i + 1]])
	_spots.append({"kind": "chat", "id": guest, "host": host, "lines": lines, "i": 0, "pos": at, "height": 84.0})
	var flip := side > 0.0   # mira hacia el anfitrión / faces the host
	_prop(at, func(ci: CanvasItem) -> void:
		_drawing_guest = true
		_draw_npc(ci, guest, Vector2.ZERO, flip)
		_drawing_guest = false
		# Bocadillos que se turnan encima de los dos / Speech bubbles taking turns above the two
		var ph := fmod(_t + at.x * 0.01, 5.0)
		if ph < 2.2:
			_bubble(ci, Vector2(0, -98))
		elif ph > 2.5 and ph < 4.7:
			_bubble(ci, hp - at + Vector2(0, -98)))
	return true

func _bubble(ci: CanvasItem, p: Vector2) -> void:
	var r := Rect2(p - Vector2(14, 9), Vector2(28, 16))
	ci.draw_rect(r.grow(1), Color(0.1, 0.08, 0.2, 0.6))
	ci.draw_rect(r, Color("fbf8ff"))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 7), p + Vector2(3, 7), p + Vector2(-2, 12)]), Color("fbf8ff"))
	for k in 3:
		var up := absf(sin(_t * 5.0 - k * 0.7)) * 2.0
		ci.draw_rect(Rect2(p + Vector2(-8 + k * 6, -2 - up), Vector2(3, 3)), Color("4a4592"))

func _draw_npc(ci: CanvasItem, id: String, offset := Vector2.ZERO, flip := false, opts := {}) -> void:
	if _away.has(id) and not _drawing_guest:
		return
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

var _cat_news := false


func _build_nexus() -> void:
	var c := _isle_pos("nexus")
	_cat_news = CatAdvice.has_new()
	# La fuente: aquí se empieza a soñar / The fountain: this is where dreaming starts
	_spots.append({"kind": "fountain", "id": "fountain", "pos": c + Vector2(0, 22), "height": 96.0})
	_prop(c + Vector2(0, 2), _draw_fountain)
	_blocks.append({"c": c + Vector2(0, -2), "r": Vector2(38, 14)})
	# El Gato Siniestro, sentado en el borde de la fuente: da consejos / The Sinister Cat, sitting on the
	# fountain's rim: gives advice
	var cat := c + Vector2(-34, 6)
	_spots.append({"kind": "npc", "id": "cat", "pos": cat + Vector2(-22, 16), "height": 62.0})
	_prop(cat, func(ci: CanvasItem) -> void:
		_draw_npc(ci, "cat", Vector2(0, -12), false, {"fade": true})
		# «!» cuando tiene un consejo nuevo / "!" when he has new advice
		if _cat_news:
			var up := absf(sin(_t * 3.0)) * 3.0
			var r := Rect2(Vector2(-6, -72 - up), Vector2(12, 16))
			ci.draw_rect(r.grow(1), Color(0.1, 0.08, 0.2, 0.7))
			ci.draw_rect(r, Color("fbf8ff"))
			ci.draw_rect(Rect2(r.position + Vector2(5, 3), Vector2(2, 7)), NpcArt.CAT_AURA.darkened(0.3))
			ci.draw_rect(Rect2(r.position + Vector2(5, 11), Vector2(2, 2)), NpcArt.CAT_AURA.darkened(0.3)))
	# Atril con el álbum de pegatinas del diario, junto a la fuente / Lectern with the diary's sticker album, by the fountain
	var lec := c + Vector2(140, 6)
	_blocks.append({"c": lec, "r": Vector2(12, 4)})
	_spots.append({"kind": "album", "id": "album", "pos": lec + Vector2(0, 10), "height": 64.0})
	_prop(lec, func(ci: CanvasItem) -> void:
		_shadow(ci, Vector2.ZERO, Vector2(14, 4))
		ci.draw_rect(Rect2(-3, -30, 6, 30), Color("8a6a4a"))
		ci.draw_rect(Rect2(-10, -2, 20, 3), Color("6a4e36"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-16, -34), Vector2(16, -34), Vector2(13, -28), Vector2(-13, -28)]), Color("6a4e36"))
		# Libreta abierta con pegatinas / Open notebook with stickers
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-15, -44), Vector2(0, -41), Vector2(0, -33), Vector2(-15, -36)]), Color("efe6cf"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(15, -44), Vector2(0, -41), Vector2(0, -33), Vector2(15, -36)]), Color("e6dcc0"))
		ci.draw_circle(Vector2(-8, -39), 2.5, Color("ff9ad0"))
		ci.draw_circle(Vector2(7, -39), 2.5, Color("e0a93a"))
		var tw := 0.5 + 0.5 * sin(_t * 2.0)
		ci.draw_circle(Vector2(0, -50 - tw * 3.0), 1.5, Color(1, 1, 1, 0.4 + 0.4 * tw)))
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

# --- Armario y museo: hub_wardrobe.gd y hub_museum.gd / Wardrobe and museum: hub_wardrobe.gd and hub_museum.gd ---

# --- Svinho: practica tiros a portería / practises shots at goal ---

## Portería en la línea de fondo del medio campo; Svinho, de espaldas, tira desde la media luna
## Goal on the half-pitch's goal line; Svinho, from behind, shoots from the arc
const GOAL := Vector2(0, -63)
const SV_AT := Vector2(40, 34)
const SV_FOOT := Vector2(44, 25)
const SHOT := 2.8           # segundos entre tiro y tiro / seconds between shots
var _goal: Prop
var _net_hit := Vector2.ZERO   # dónde dio el balón en la red / where the ball hit the net
var _net_t := -9.0             # cuándo / when

func _build_svinho() -> void:
	var c := _isle_pos("svinho")
	_blocks.append({"c": c + GOAL + Vector2(0, -4), "r": Vector2(30, 6)})
	_goal = _prop(c + GOAL, _draw_goal)
	_piece(c + Vector2(-131, -61), "hub_flag")
	_piece(c + Vector2(131, -61), "hub_flag")
	# Carro de balones y conos para los regates, fuera de las bandas
	# Ball cart and cones for dribbling drills, beyond the touchlines
	_piece(c + Vector2(-112, 50), "hub_ballbag", Vector2(14, 5))
	for i in 4:
		_piece(c + Vector2(62 + i * 16, 36 - i * 4), "hub_cone")
	var sv := _npc_prop("svinho", c + SV_AT)
	# Chuta justo cuando sale el balón / He kicks just as the ball leaves
	sv.painter = func(ci: CanvasItem) -> void:
		var ph := fmod(_t, SHOT) / SHOT
		var k := clampf(1.0 - minf(ph + 0.03, 1.03 - ph) / 0.07, 0.0, 1.0)
		_draw_npc(ci, "svinho", Vector2.ZERO, false, {"kick": k * k * (3.0 - 2.0 * k), "back": true})
	_ball = _prop(c + SV_FOOT, func(ci: CanvasItem) -> void:
		if not _ball.get_meta("in_goal", false):
			_paint_ball(ci, Vector2.ZERO))

func _paint_ball(ci: CanvasItem, at: Vector2) -> void:
	var h: float = _ball.get_meta("h", 0.0)
	_shadow(ci, at, Vector2(4, 1.5), 0.3)
	ci.draw_set_transform((at + Vector2(0, -3.0 - h)).round(), _t * 9.0 * float(_ball.get_meta("spin", 1.0)), Vector2(0.36, 0.36))
	Sprites.draw(ci, "npc_ball")
	ci.draw_set_transform(Vector2.ZERO)

## La portería: el fondo, la red (que se hincha donde da el balón), el balón si está dentro y el marco
## The goal: the back, the net (which bulges where the ball hits), the ball if it's inside, and the frame
func _draw_goal(ci: CanvasItem) -> void:
	Sprites.draw(ci, "hub_goal_back")
	var dt := _t - _net_t
	var push := 0.0
	if dt >= 0.0 and dt < 1.2:
		push = 7.0 * exp(-dt * 3.0) * (0.6 + 0.4 * cos(dt * 18.0))
	var net := Color("c8c4d8", 0.55)
	var bulge := func(q: Vector2) -> Vector2:
		var d2 := q.distance_squared_to(_net_hit)
		var f := exp(-d2 / 110.0) * push
		return q + Vector2((q.x - _net_hit.x) * 0.06 * f, -f)
	# Red del fondo: rejilla deformada / Back net: a warped grid
	for x in range(-20, 22, 4):
		var pts := PackedVector2Array()
		for y in range(-34, -9, 2):
			pts.append((bulge.call(Vector2(x, y)) as Vector2).round())
		ci.draw_polyline(pts, net, 1.0)
	for y in range(-30, -10, 4):
		var pts := PackedVector2Array()
		for x in range(-22, 23, 2):
			pts.append((bulge.call(Vector2(x, y)) as Vector2).round())
		ci.draw_polyline(pts, net, 1.0)
	# Red del techo y de los lados (el balón también la sacude un poco) / Roof and side netting (the ball shakes it a little too)
	var wob := push * 0.25
	for k in range(1, 4):
		var fx := 1.25 * k
		ci.draw_line(Vector2(-27 + fx, -k * 2.5), Vector2(-27 + fx - wob, -27 - k * 1.75), net)
		ci.draw_line(Vector2(27 - fx, -k * 2.5), Vector2(27 - fx + wob, -27 - k * 1.75), net)
	for k in range(1, 5):
		var y := -27.0 - k * 1.4
		ci.draw_line(Vector2(-27 + k * 1.25, y - wob * 0.5), Vector2(27 - k * 1.25, y - wob * 0.5), net)
	if is_instance_valid(_ball) and _ball.get_meta("in_goal", false):
		_paint_ball(ci, _ball.position - _goal.position)
	Sprites.draw(ci, "hub_goal_front")

func _tick_svinho() -> void:
	var c := _isle_pos("svinho")
	var foot := c + SV_FOOT
	# Si Svinho está de visita, el balón se queda quieto en el césped
	# If Svinho is out visiting, the ball rests still on the grass
	if _away.has("svinho"):
		_ball.position = foot
		_ball.set_meta("h", 0.0)
		_ball.set_meta("spin", 0.0)
		_ball.set_meta("in_goal", false)
		return
	var n := int(_t / SHOT)
	var ph := fmod(_t, SHOT) / SHOT
	# Cada tiro a un sitio: a un palo, al otro, por arriba... / Each shot somewhere else: one post, the other, up high...
	var aim_x: float = [-13.0, 11.0, -4.0, 15.0, 2.0, -16.0][n % 6]
	var aim_h: float = [3.0, 7.0, 9.0, 2.0, 6.0, 8.0][n % 6]
	var hit := c + GOAL + Vector2(aim_x, -9)
	var h := 0.0
	var p: Vector2
	var spin := 1.0
	var in_goal := false
	if ph < 0.2:
		# Vuela hacia la red / Flies towards the net
		var k := ph / 0.2
		p = foot.lerp(hit, k)
		h = lerpf(0.0, aim_h, k) + sin(k * PI) * 10.0
		spin = 2.0
		in_goal = p.y < c.y + GOAL.y + 1.0
		_net_hit = Vector2(aim_x, -9.0 - aim_h)
		_net_t = _t - (ph - 0.2) * SHOT
	elif ph < 0.34:
		# Se queda en la red y cae al suelo / Sits in the net and drops to the ground
		var k := (ph - 0.2) / 0.14
		p = hit + Vector2(0, 2.0 * k)
		h = aim_h * (1.0 - k * k)
		in_goal = true
		spin = 0.3
	else:
		# Vuelve rodando al pie de Svinho / Rolls back to Svinho's foot
		var k := (ph - 0.34) / 0.66
		k = k * k * (3.0 - 2.0 * k)
		p = (hit + Vector2(0, 2)).lerp(foot, k)
		in_goal = p.y < c.y + GOAL.y + 1.0
		spin = -1.0
	_ball.position = p
	_ball.set_meta("h", h)
	_ball.set_meta("spin", spin)
	_ball.set_meta("in_goal", in_goal)

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

## Fuegos de la cocina (relativos a la isla); el Pinche va de uno a otro con el extintor
## Kitchen fires (relative to the island); the Kitchen Boy goes from one to the next with the extinguisher
const FIRES: Array[Vector2] = [Vector2(-96, 12), Vector2(72, 34), Vector2(-40, 46), Vector2(-46, -66), Vector2(30, -66)]
const PINCHE_RUN := 0.9      # segundos corriendo hasta el siguiente fuego / seconds running to the next fire
const PINCHE_SPRAY := 2.3    # segundos echando espuma / seconds spraying foam
var _fire_k: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]
var _pinche_side := 1.0
var _pinche_spray := 0.0     # 0..1 cuánto echa ahora / 0..1 how much he's spraying now
var _pinche_fire := 0

func _build_pinche() -> void:
	var c := _isle_pos("pinche")
	var stove := c + Vector2(-8, -38)
	_blocks.append({"c": stove + Vector2(0, -8), "r": Vector2(62, 10)})
	_prop(stove, func(ci: CanvasItem) -> void:
		Sprites.draw(ci, "hub_stove")
		for i in 3:
			var x := [-38.0, 0.0, 38.0][i] as float
			# Los fuegos de los lados se pueden apagar; el del medio, no / The side burners can be put out; the middle one can't
			var k := _fire_k[3] if i == 0 else (_fire_k[4] if i == 2 else 1.0)
			_flames(ci, Vector2(x, -30), k, x))
	_piece(c + Vector2(86, -40), "hub_fridge", Vector2(12, 4))
	for i in 3:
		var at := c + FIRES[i]
		var idx := i
		_prop(at, func(ci: CanvasItem) -> void: _flames(ci, Vector2.ZERO, 0.85 * _fire_k[idx], at.x))
	# El soplete, tirado en el suelo y aún encendido: de ahí sale todo / The blowtorch, dropped on the floor and still lit: that's how it all started
	var torch := c + Vector2(18, 54)
	_prop(torch, func(ci: CanvasItem) -> void:
		Sprites.draw(ci, "hub_torch")
		var tip := Vector2(17, -5)
		var flick := 1.0 + 0.25 * sin(_t * 23.0) + 0.15 * sin(_t * 37.0)
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(tip - Vector2(10, 10), Vector2(20, 20)), false, Color("ff9a3a", 0.35))
		ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -2), tip + Vector2(9 * flick, 0), tip + Vector2(0, 2)]), Color("ff9a3a", 0.9))
		ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -1), tip + Vector2(5 * flick, 0), tip + Vector2(0, 1)]), Color("8fd8ff", 0.95)))
	_pinche = _npc_prop("pinche", c + FIRES[0] + Vector2(-30, 6))
	_blocks.pop_back()   # corre de un lado a otro: no estorba / he runs back and forth: he doesn't block
	_pinche.painter = func(ci: CanvasItem) -> void:
		_draw_npc(ci, "pinche", Vector2.ZERO, _pinche_side < 0.0, {"ext": true})
		# Chorro de espuma desde la boquilla hasta el fuego / Foam jet from the nozzle to the fire
		if _pinche_spray > 0.0:
			var s := _pinche_side
			var nozzle := Vector2(26 * s, -32)
			var target: Vector2 = _isle_pos("pinche") + FIRES[_pinche_fire] - _pinche.position + Vector2(0, -8)
			for k in 9:
				var ph := fposmod(_t * 2.6 + k / 9.0, 1.0)
				var p := nozzle.lerp(target, ph) + Vector2(0, -sin(ph * PI) * 6.0 + sin(_t * 9.0 + k) * 1.5)
				ci.draw_circle(p, (2.0 + ph * 5.0) * _pinche_spray, Color(1, 1, 1, (0.85 - ph * 0.45) * _pinche_spray))

func _tick_pinche() -> void:
	var c := _isle_pos("pinche")
	var cycle := PINCHE_RUN + PINCHE_SPRAY
	var n := int(_t / cycle)
	var ph := fmod(_t, cycle)
	var order := [0, 3, 2, 4, 1]
	var cur: int = order[n % order.size()]
	var prev: int = order[(n + order.size() - 1) % order.size()]
	# Se pone al lado del fuego, mirándolo / He stands beside the fire, facing it
	var stand := func(i: int) -> Vector2:
		var f: Vector2 = FIRES[i]
		var side := 1.0 if f.x > -10.0 else -1.0
		if f.y < -40.0:
			return c + Vector2(f.x - 22.0 * side, -18.0)   # delante de los fogones / in front of the hob
		return c + f + Vector2(-34.0 * side, 6.0)
	var from: Vector2 = stand.call(prev)
	var to: Vector2 = stand.call(cur)
	var at: Vector2
	if ph < PINCHE_RUN:
		var k := ph / PINCHE_RUN
		k = k * k * (3.0 - 2.0 * k)
		at = from.lerp(to, k)
		if absf(to.x - from.x) > 2.0:
			_pinche_side = signf(to.x - from.x)
		_pinche_spray = 0.0
	else:
		at = to
		_pinche_side = signf((c + FIRES[cur]).x - at.x)
		var u := (ph - PINCHE_RUN) / PINCHE_SPRAY
		_pinche_spray = clampf(minf(u, 1.0 - u) * 8.0, 0.0, 1.0)
	_pinche_fire = cur
	_pinche.position = at
	# El que apaga se encoge; los demás vuelven a prender poco a poco
	# The one he's spraying shrinks; the others slowly flare up again
	var dt := get_process_delta_time()
	for i in _fire_k.size():
		if i == cur and _pinche_spray > 0.5:
			_fire_k[i] = maxf(0.25, _fire_k[i] - dt * 0.6)
		else:
			_fire_k[i] = minf(1.0, _fire_k[i] + dt * 0.12)
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

# --- SuperK: en su azotea; de vez en cuando despega, da una vuelta a la isla y aterriza ---
# --- SuperK: on his rooftop; now and then he takes off, loops round the island and lands ---

const SK_PAD := Vector2(10, 4)
const SK_CYCLE := 8.0
const SK_FLIGHT := 2.6

func _build_superk() -> void:
	var c := _isle_pos("superk")
	_piece(c + Vector2(-96, -38), "hub_tank", Vector2(18, 5))
	_piece(c + Vector2(100, -46), "hub_antenna", Vector2(6, 3))
	_piece(c + Vector2(92, 30), "hub_vent", Vector2(11, 4))
	_piece(c + Vector2(-110, 22), "hub_vent", Vector2(11, 4))
	var sk := _npc_prop("superk", c + SK_PAD)
	sk.painter = func(ci: CanvasItem) -> void:
		var ph := fmod(_t, SK_CYCLE)
		var fly := ph - (SK_CYCLE - SK_FLIGHT)
		if fly < 0.0:
			_draw_npc(ci, "superk", Vector2.ZERO, false, {"hover": true})
			return
		# Vuelta a la isla en el aire / A loop round the island in the air
		var k := fly / SK_FLIGHT
		var a := k * TAU
		var r := Vector2(120, 50) * sin(k * PI)
		var p := Vector2(sin(a) * r.x, -cos(a) * r.y + r.y) + Vector2(0, -sin(k * PI) * 40.0)
		var dir := cos(a)
		ci.draw_colored_polygon(_ellipse(Vector2(p.x, p.y + sin(k * PI) * 40.0), Vector2(8, 2.5)), Color(0, 0, 0, 0.2))
		_draw_npc(ci, "superk", p + Vector2(0, -2.5), dir < 0.0, {"fly": k > 0.08 and k < 0.92})
	# Ráfaga al despegar y al aterrizar / A gust on take-off and landing
	_prop(c + SK_PAD + Vector2(0, 1), func(ci: CanvasItem) -> void:
		var fly := fmod(_t, SK_CYCLE) - (SK_CYCLE - SK_FLIGHT)
		for edge in [0.0, SK_FLIGHT]:
			var d := absf(fly - edge)
			if fly > -0.2 and d < 0.35:
				var k := d / 0.35
				ci.draw_arc(Vector2.ZERO, 8.0 + k * 22.0, 0.0, TAU, 20, Color(1, 1, 1, 0.5 * (1.0 - k)), 1.0))

# --- Lil Key: dando un concierto en su escenario / giving a gig on his stage ---

func _build_lilkey() -> void:
	var c := _isle_pos("lilkey")
	_piece(c + Vector2(-86, -30), "hub_speaker", Vector2(10, 4))
	_piece(c + Vector2(86, -30), "hub_speaker", Vector2(10, 4))
	_piece(c + Vector2(-118, -46), "hub_truss", Vector2(6, 3))
	_piece(c + Vector2(118, -46), "hub_truss", Vector2(6, 3))
	_piece(c + Vector2(-24, -14), "hub_micstand")
	var lk := _npc_prop("lilkey", c + Vector2(8, -6))
	lk.painter = func(ci: CanvasItem) -> void:
		_draw_npc(ci, "lilkey", Vector2.ZERO, false, {"dance": 1.0})
	# Haces de luz de colores que barren el escenario / Coloured light beams sweeping the stage
	_prop(c + Vector2(0, -60), func(ci: CanvasItem) -> void:
		for i in 3:
			var col := Color(["ff6a8a", "8fe0ff", "f6d993"][i], 0.12)
			var from := Vector2([-118.0, 118.0, 0.0][i], -10.0)
			var to := Vector2(sin(_t * (0.9 + i * 0.3) + i * 2.0) * 90.0, 70.0)
			var side := (to - from).orthogonal().normalized() * 14.0
			ci.draw_colored_polygon(PackedVector2Array([from, to + side, to - side]), col))

# --- D. Lynx: en su plató, entre telones rojos, con la cámara y los focos / on his film set, between red curtains, with the camera and the lights ---

func _build_lynx() -> void:
	var c := _isle_pos("lynx")
	_piece(c + Vector2(-118, -40), "hub_curtain", Vector2(16, 4))
	_piece(c + Vector2(118, -40), "hub_curtain", Vector2(16, 4))
	_piece(c + Vector2(-58, 14), "hub_filmcam", Vector2(10, 4))
	_piece(c + Vector2(84, 22), "hub_spotlight", Vector2(8, 3))
	_piece(c + Vector2(-92, 30), "hub_spotlight", Vector2(8, 3))
	_piece(c + Vector2(40, -20), "hub_dirchair", Vector2(9, 3))
	_piece(c + Vector2(-20, 30), "hub_clapper")
	var lx := _npc_prop("lynx", c + Vector2(10, -8))
	lx.painter = func(ci: CanvasItem) -> void:
		# De vez en cuando levanta el megáfono / Now and then he raises the megaphone
		var ph := fmod(_t, 9.0)
		var shout := clampf(minf(ph - 6.0, 8.2 - ph) * 3.0, 0.0, 1.0)
		_draw_npc(ci, "lynx", Vector2.ZERO, false, {"shout": shout})
	# Haz de los focos hacia el centro / The spotlights' beams towards the middle
	_prop(c + Vector2(0, -40), func(ci: CanvasItem) -> void:
		for src: Vector2 in [Vector2(84, 30), Vector2(-92, 38)]:
			var to := Vector2(10 + sin(_t * 0.4) * 6.0, 34)
			var side: Vector2 = (to - src).orthogonal().normalized() * 18.0
			ci.draw_colored_polygon(PackedVector2Array([src, to + side, to - side]), Color(1.0, 0.95, 0.8, 0.08)))

## La luna de Luna: un cohete de cartón con su ventanita, una bandera con la luna cosida, una antena
## que pita con la lucecita y un tirachinas de cráter (los cráteres del suelo son agujeros de práctica)
## Luna's moon: a cardboard rocket with its little window, a flag with a sewn-on moon, a beeping
## antenna with its light, and the craters on the floor (practice holes)
const INK := Color("1a1024")
const LUNA_PAD := Vector2(-88, -2)
const LUNA_CRATER := Vector2(-52, 50)
## Cuenta atrás del cohete: cada LUNA_LAUNCH s, «3, 2, 1...» y casi despega
## The rocket's countdown: every LUNA_LAUNCH s, "3, 2, 1..." and it almost takes off
const LUNA_LAUNCH := 16.0
var _rover: Prop

## La base lunar de Luna / Luna's moon base
func _build_luna() -> void:
	var c := _isle_pos("luna")
	_build_luna_rocket(c + LUNA_PAD)
	_build_luna_dome(c + Vector2(80, -36))
	_build_luna_flag(c + Vector2(36, -48))
	_build_luna_scope(c + Vector2(98, 26))
	_build_luna_dish(c + Vector2(-116, 18))
	_build_luna_earth(c + Vector2(-20, -80))
	# Rover de juguete dando vueltas al cráter / A toy rover circling the crater
	_rover = _prop(c + LUNA_CRATER, func(ci: CanvasItem) -> void: _paint_rover(ci))
	# Piedrecitas que flotan por la gravedad baja / Pebbles floating in the low gravity
	_prop(c + Vector2(0, -70), func(ci: CanvasItem) -> void:
		for i in 12:
			var bx := sin(i * 7.3) * 120.0
			var by := 70.0 + cos(i * 3.1) * 50.0
			var ph := fposmod(_t * 0.18 + i * 0.29, 1.0)
			var p := Vector2(bx + sin(_t * 0.7 + i) * 3.0, by - sin(ph * PI) * 26.0 - 4.0)
			var r := 1.2 + (i % 3) * 0.6
			ci.draw_circle(Vector2(bx, by), r + 0.6, Color(0, 0, 0, 0.12 * sin(ph * PI)))
			ci.draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), INK)
			ci.draw_rect(Rect2(p - Vector2(r, r) + Vector2(0.6, 0.6), Vector2(r, r) * 2.0 - Vector2(1.2, 1.2)), Color("c9c7da")))
	var ln := _npc_prop("luna", c + Vector2(4, -6))
	ln.painter = func(ci: CanvasItem) -> void:
		_draw_npc(ci, "luna", Vector2.ZERO, false)


## Cohete de cartón en su plataforma: tubo de cartón con cinta, ojos de buey (en uno asoma un peluche),
## morro de gorro de cumpleaños a rayas, aletas de caja de cereales y tobera de vaso de yogur con
## papel de plata. Al lado, una torre de palitos de helado con una luz. Cada pocos segundos hace la
## cuenta atrás, tiembla, echa humo y chispas, se levanta un palmo... y vuelve a bajar.
## A cardboard rocket on its pad: a taped cardboard tube, portholes (a teddy peeks out of one), a
## striped party-hat nose cone, cereal-box fins and a yoghurt-pot nozzle wrapped in foil. Beside it,
## a tower of lolly sticks with a light. Every few seconds it counts down, shakes, smokes and sparks,
## lifts a hand's breadth... and settles back down.
func _build_luna_rocket(at: Vector2) -> void:
	_blocks.append({"c": at, "r": Vector2(22, 9)})
	_prop(at, func(ci: CanvasItem) -> void:
		var k := fposmod(_t, LUNA_LAUNCH)
		var count := k - (LUNA_LAUNCH - 4.0)          # -..0..4: 3, 2, 1 y despegue / 3, 2, 1 and lift-off
		var lift := 0.0
		var shake := 0.0
		if count > 3.0:
			var f := count - 3.0
			lift = sin(f * PI) * 10.0
			shake = 1.0
		elif count > 2.0:
			shake = 0.6
		_shadow(ci, Vector2.ZERO, Vector2(18.0 - lift * 0.4, 4.0))
		# Torre de palitos de helado / Lolly-stick tower
		var tw := Vector2(26, 2)
		for x: float in [tw.x - 5.0, tw.x + 5.0]:
			ci.draw_line(Vector2(x, tw.y), Vector2(x, -70), INK, 3.0)
			ci.draw_line(Vector2(x, tw.y), Vector2(x, -70), Color("e8c890"), 1.5)
		for y in range(-6, -70, -8):
			ci.draw_line(Vector2(tw.x - 5.0, y), Vector2(tw.x + 5.0, y - 4), Color("c8a070"), 1.2)
		ci.draw_line(Vector2(tw.x - 5.0, -52), Vector2(12, -52), INK, 3.0)
		ci.draw_line(Vector2(tw.x - 5.0, -52), Vector2(12, -52), Color("e8c890"), 1.5)
		var blink := fmod(_t, 1.0) < 0.5 or count > 0.0
		ci.draw_circle(Vector2(tw.x, -73), 3.0, INK)
		ci.draw_circle(Vector2(tw.x, -73), 2.0, Color("ff6a6a") if blink else Color("6a2a3a"))
		# Humo y chispas al despegar / Smoke and sparks at lift-off
		if count > 1.5:
			var power := clampf(count - 1.5, 0.0, 1.0)
			for i in 9:
				var ph := fposmod(_t * 2.2 + i * 0.11, 1.0)
				var side := -1.0 if i % 2 == 0 else 1.0
				ci.draw_circle(Vector2(side * ph * 26.0 + sin(i * 3.0) * 4.0, -2.0 - ph * 6.0), (3.0 + ph * 7.0) * power, Color(0.95, 0.94, 1.0, 0.65 * (1.0 - ph) * power))
		var j := Vector2(sin(_t * 60.0), cos(_t * 47.0)) * shake
		ci.draw_set_transform(Vector2(0, -lift) + j)
		if count > 2.5:
			var fl := 8.0 + sin(_t * 40.0) * 3.0 + (count - 2.5) * 6.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -8), Vector2(6, -8), Vector2(0, -8 + fl * 1.6)]), Color(1.0, 0.55, 0.3, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, -8), Vector2(3, -8), Vector2(0, -8 + fl)]), Color(1.0, 0.95, 0.65))
		# Tobera de vaso de yogur con papel de plata / Yoghurt-pot nozzle wrapped in foil
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, -18), Vector2(9, -18), Vector2(7, -7), Vector2(-7, -7)]), INK)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, -17), Vector2(8, -17), Vector2(6, -8), Vector2(-6, -8)]), Color("c8ccdc"))
		ci.draw_line(Vector2(-4, -16), Vector2(-3, -9), Color("f4f6ff"), 1.2)
		# Aletas de caja de cereales / Cereal-box fins
		for side: float in [-1.0, 1.0]:
			var fin := PackedVector2Array([Vector2(side * 11, -46), Vector2(side * 25, -24), Vector2(side * 25, -10), Vector2(side * 11, -20)])
			var out := PackedVector2Array()
			for q in fin:
				out.append(q + Vector2(side * 1.2, 0) + (Vector2(0, 1.2) if q.y > -30 else Vector2(0, -1.2)))
			ci.draw_colored_polygon(out, INK)
			ci.draw_colored_polygon(fin, Color("e85d3a") if side < 0.0 else Color("c8482c"))
			ci.draw_line(Vector2(side * 15, -32), Vector2(side * 22, -20), Color("f6d993"), 1.5)
		# Cuerpo: tubo de cartón con cinta adhesiva y estrellas de cera / Body: cardboard tube with tape and crayon stars
		ci.draw_rect(Rect2(-13, -86, 26, 72), INK)
		ci.draw_rect(Rect2(-12, -85, 24, 70), Color("d2a878"))
		ci.draw_rect(Rect2(4, -85, 8, 70), Color("b48a5c"))
		ci.draw_rect(Rect2(-12, -85, 3, 70), Color("e6c496"))
		for y: float in [-70.0, -40.0]:
			ci.draw_rect(Rect2(-12, y, 24, 4), Color("e8e0c8", 0.9))
		for sp: Vector2 in [Vector2(-6, -28), Vector2(5, -50), Vector2(-4, -76)]:
			_crayon_star(ci, sp, Color("ffe36a"))
		# Ojos de buey: el de arriba con un peluche que asoma / Portholes: the top one with a teddy peeking out
		for py: float in [-60.0, -32.0]:
			ci.draw_circle(Vector2(0, py), 6.5, INK)
			ci.draw_circle(Vector2(0, py), 5.5, Color("c8ccdc"))
			ci.draw_circle(Vector2(0, py), 4.2, Color("2a3a6a"))
		ci.draw_circle(Vector2(0, -59), 3.0, Color("b07a4a"))
		ci.draw_circle(Vector2(-2.2, -61.5), 1.2, Color("b07a4a"))
		ci.draw_circle(Vector2(2.2, -61.5), 1.2, Color("b07a4a"))
		ci.draw_rect(Rect2(-1.2, -59.5, 0.9, 0.9), INK)
		ci.draw_rect(Rect2(0.6, -59.5, 0.9, 0.9), INK)
		ci.draw_arc(Vector2(0, -32), 3.2, -2.4, -1.4, 6, Color(1, 1, 1, 0.7), 1.2)
		# Morro: gorro de cumpleaños a rayas con pompón / Nose cone: a striped party hat with a pompom
		var cone := PackedVector2Array([Vector2(-14, -85), Vector2(14, -85), Vector2(0, -116)])
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-15.5, -84), Vector2(15.5, -84), Vector2(0, -118.5)]), INK)
		ci.draw_colored_polygon(cone, Color("f4f1ea"))
		for b in 3:
			var y0 := -85.0 - b * 10.0
			var w0 := 14.0 * (1.0 - (y0 + 85.0) / -31.0)
			var w1 := 14.0 * (1.0 - (y0 - 5.0 + 85.0) / -31.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-w0, y0), Vector2(w0, y0), Vector2(w1, y0 - 5.0), Vector2(-w1, y0 - 5.0)]), Color("e85d75"))
		ci.draw_circle(Vector2(0, -118), 3.6, INK)
		ci.draw_circle(Vector2(0, -118), 2.6, Color("ffe36a"))
		ci.draw_set_transform(Vector2.ZERO)
		# Cuenta atrás / Countdown
		if count > 0.0 and count < 3.0:
			var num := str(3 - int(count))
			var f := fposmod(count, 1.0)
			var font := UITheme.font("display")
			var sz := int(22.0 + 8.0 * (1.0 - f))
			ci.draw_string_outline(font, Vector2(-7, -128 - f * 6.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 5, INK)
			ci.draw_string(font, Vector2(-7, -128 - f * 6.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("fff6c0")))


## La cúpula donde duerme Luna: medio balón de playa forrado de papel de plata, con un ojo de buey
## que brilla cálido, una portezuela de tela, un panel solar de caja de bombones y su nombre en cera
## The dome where Luna sleeps: half a beach ball lined with tin foil, a porthole glowing warm, a
## fabric flap door, a solar panel made of a chocolate box and her name in crayon
func _build_luna_dome(at: Vector2) -> void:
	_blocks.append({"c": at, "r": Vector2(30, 11)})
	_prop(at, func(ci: CanvasItem) -> void:
		_shadow(ci, Vector2.ZERO, Vector2(34, 7))
		# Panel solar al lado / Solar panel beside it
		ci.draw_line(Vector2(34, 0), Vector2(34, -18), INK, 3.0)
		ci.draw_line(Vector2(34, 0), Vector2(34, -18), Color("9aa0c0"), 1.5)
		var sp := PackedVector2Array([Vector2(24, -30), Vector2(46, -26), Vector2(44, -14), Vector2(22, -18)])
		var spo := PackedVector2Array([Vector2(22.5, -31.5), Vector2(47.5, -27), Vector2(45.5, -12.5), Vector2(20.5, -17)])
		ci.draw_colored_polygon(spo, INK)
		ci.draw_colored_polygon(sp, Color("3a4aa8"))
		for q in 3:
			ci.draw_line(sp[0].lerp(sp[3], (q + 1) / 4.0), sp[1].lerp(sp[2], (q + 1) / 4.0), Color("8fa2ff"), 1.0)
		ci.draw_line(sp[0].lerp(sp[1], 0.5), sp[3].lerp(sp[2], 0.5), Color("8fa2ff"), 1.0)
		var gl := fposmod(_t * 0.3, 1.0)
		ci.draw_line(sp[0].lerp(sp[1], gl), sp[3].lerp(sp[2], gl), Color(1, 1, 1, 0.5), 2.0)
		# Cúpula / Dome
		var dome := PackedVector2Array()
		var dome_o := PackedVector2Array()
		for q in 17:
			var a := PI + PI * q / 16.0
			dome.append(Vector2(cos(a) * 30.0, sin(a) * 34.0))
			dome_o.append(Vector2(cos(a) * 31.5, sin(a) * 35.5))
		dome_o.append(Vector2(31.5, 1.5))
		dome_o.append(Vector2(-31.5, 1.5))
		ci.draw_colored_polygon(dome_o, INK)
		ci.draw_colored_polygon(dome, Color("d8dcea"))
		# Gajos del balón: franjas de papel de plata arrugado / The ball's panels: strips of crinkled foil
		for q in 5:
			var a0 := PI + PI * (q * 0.2 + 0.1)
			var pts := PackedVector2Array([Vector2(0, -34)])
			for r in 6:
				var aa := a0 + 0.12 * sin(r * 1.7)
				pts.append(Vector2(cos(aa) * 30.0 * (r + 1) / 6.0 * 1.0, -34.0 + (sin(aa) * 34.0 + 34.0) * (r + 1) / 6.0))
			ci.draw_polyline(pts, Color("a8aec4"), 1.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-26, -14), Vector2(-20, -26), Vector2(-10, -32), Vector2(-14, -22)]), Color("f4f6ff"))
		# Portezuela de tela con cremallera / Fabric flap door with a zip
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-9, -18), Vector2(0, -22), Vector2(9, -18), Vector2(12, 0)]), INK)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-10.5, 0), Vector2(-8, -16.5), Vector2(0, -20.5), Vector2(8, -16.5), Vector2(10.5, 0)]), Color("5f6fd6"))
		ci.draw_line(Vector2(0, -20), Vector2(0, 0), Color("bcc8ff"), 1.0)
		# Ojo de buey con luz cálida / Porthole with warm light
		var warm := 0.85 + 0.15 * sin(_t * 3.0) * sin(_t * 1.7)
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(17, -21) - Vector2(16, 16), Vector2(32, 32)), false, Color("ffd27a", 0.35 * warm))
		ci.draw_circle(Vector2(17, -21), 6.0, INK)
		ci.draw_circle(Vector2(17, -21), 5.0, Color("c8ccdc"))
		ci.draw_circle(Vector2(17, -21), 3.8, Color("ffd27a", warm))
		# Una luna y dos estrellas pintadas con cera / A moon and two stars in crayon
		ci.draw_arc(Vector2(-20, -16), 4.0, 0.9, 5.4, 10, Color("e85d75"), 1.6)
		_crayon_star(ci, Vector2(-14, -24), Color("e85d75"))
		_crayon_star(ci, Vector2(-25, -7), Color("5f6fd6")))


## Bandera clavada: tela azul noche con una luna y una estrella cosidas, que ondea despacio
## A planted flag: midnight-blue cloth with a sewn moon and star, waving slowly
func _build_luna_flag(at: Vector2) -> void:
	_blocks.append({"c": at, "r": Vector2(4, 3)})
	_prop(at, func(ci: CanvasItem) -> void:
		_shadow(ci, Vector2.ZERO, Vector2(7, 2))
		ci.draw_line(Vector2(0, 1), Vector2(0, -66), INK, 4.0)
		ci.draw_line(Vector2.ZERO, Vector2(0, -65), Color("cdd0e0"), 2.0)
		ci.draw_line(Vector2(-1, -64), Vector2(36, -64), INK, 3.0)
		ci.draw_line(Vector2(-1, -64), Vector2(36, -64), Color("cdd0e0"), 1.2)
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for q in 9:
			var f := q / 8.0
			var w := sin(_t * 1.8 - f * 4.0) * 2.5 * f
			top.append(Vector2(f * 36.0, -63.0 + w))
			bot.append(Vector2(f * 36.0, -40.0 + w * 1.4))
		var cloth := PackedVector2Array(top)
		var rev := bot.duplicate()
		rev.reverse()
		cloth.append_array(rev)
		var outline := PackedVector2Array()
		for q in cloth:
			outline.append(q + (q - Vector2(18, -52)).normalized() * 1.4)
		ci.draw_colored_polygon(outline, INK)
		ci.draw_colored_polygon(cloth, Color("2a2a6e"))
		for q in 8:
			var f := (q + 0.5) / 8.0
			var shade := sin(_t * 1.8 - f * 4.0 + 1.2)
			if shade > 0.3:
				ci.draw_line(top[q].lerp(top[q + 1], 0.5) + Vector2(0, 2), bot[q].lerp(bot[q + 1], 0.5) - Vector2(0, 2), Color(1, 1, 1, 0.08 * shade), 4.0)
		var mid := top[4].lerp(bot[4], 0.5)
		ci.draw_circle(mid + Vector2(-2, 0), 6.0, Color("f6d993"))
		ci.draw_circle(mid + Vector2(0.5, -1), 5.0, Color("2a2a6e"))
		_crayon_star(ci, mid + Vector2(8, -4), Color("ff9fc8"))
		# Puntadas del borde / Edge stitches
		for q in range(0, 9, 2):
			ci.draw_rect(Rect2(bot[q] + Vector2(-0.6, -2.5), Vector2(1.2, 1.2)), Color("f6d993")))


## Estrellita pintada con cera: una cruz de píxeles / A little crayon star: a cross of pixels
func _crayon_star(ci: CanvasItem, p: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(p + Vector2(-2.5, -0.75), Vector2(5, 1.5)), col)
	ci.draw_rect(Rect2(p + Vector2(-0.75, -2.5), Vector2(1.5, 5)), col)


## Telescopio en trípode, mirando la Tierra; de vez en cuando se gira un poco
## A telescope on a tripod, looking at the Earth; now and then it turns a little
func _build_luna_scope(at: Vector2) -> void:
	_blocks.append({"c": at, "r": Vector2(9, 4)})
	_prop(at, func(ci: CanvasItem) -> void:
		_shadow(ci, Vector2.ZERO, Vector2(12, 3))
		for lx: float in [-10.0, 0.0, 10.0]:
			ci.draw_line(Vector2(lx, 2.0 if lx == 0.0 else 0.0), Vector2(0, -22), INK, 3.0)
			ci.draw_line(Vector2(lx, 2.0 if lx == 0.0 else 0.0), Vector2(0, -22), Color("b48a5c"), 1.5)
		var aim := -2.55 + sin(_t * 0.4) * 0.12
		ci.draw_set_transform(Vector2(0, -24), aim)
		ci.draw_rect(Rect2(-6, -4.5, 30, 9), INK)
		ci.draw_rect(Rect2(-5, -3.5, 28, 7), Color("5f6fd6"))
		ci.draw_rect(Rect2(-5, -3.5, 28, 2), Color("8fa2ff"))
		ci.draw_rect(Rect2(20, -5.5, 6, 11), INK)
		ci.draw_rect(Rect2(21, -4.5, 4, 9), Color("f6d993"))
		ci.draw_rect(Rect2(-11, -2.5, 6, 5), INK)
		ci.draw_rect(Rect2(-10, -1.5, 4, 3), Color("9aa0c0"))
		ci.draw_set_transform(Vector2.ZERO)
		ci.draw_circle(Vector2(0, -24), 2.5, INK))


## Antena parabólica hecha con un colador, en un trípode de palos de escoba; pita y se gira
## A satellite dish made from a colander, on a broomstick tripod; it beeps and turns
func _build_luna_dish(at: Vector2) -> void:
	_blocks.append({"c": at, "r": Vector2(10, 4)})
	_prop(at, func(ci: CanvasItem) -> void:
		_shadow(ci, Vector2.ZERO, Vector2(14, 3))
		for lx: float in [-11.0, 0.0, 11.0]:
			ci.draw_line(Vector2(lx, 2.0 if lx == 0.0 else 0.0), Vector2(0, -20), INK, 3.0)
			ci.draw_line(Vector2(lx, 2.0 if lx == 0.0 else 0.0), Vector2(0, -20), Color("c8a070"), 1.5)
		ci.draw_line(Vector2(0, -18), Vector2(0, -36), INK, 4.0)
		ci.draw_line(Vector2(0, -18), Vector2(0, -36), Color("b8bccf"), 2.0)
		var turn := sin(_t * 0.5) * 0.3
		ci.draw_set_transform(Vector2(0, -40), turn - 0.4)
		var dish := PackedVector2Array()
		var dish_o := PackedVector2Array()
		for q in 13:
			var a := PI * q / 12.0
			dish.append(Vector2(cos(a) * 18.0, sin(a) * 9.0))
			dish_o.append(Vector2(cos(a) * 19.5, sin(a) * 10.5))
		dish_o.append(Vector2(-19.5, -1.0))
		dish_o.append(Vector2(19.5, -1.0))
		ci.draw_colored_polygon(dish_o, INK)
		ci.draw_colored_polygon(dish, Color("e4e6f0"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(14, 3), Vector2(-14, 3)]), Color("ff8a5c"))
		for hx: float in [-10.0, -5.0, 0.0, 5.0, 10.0]:
			ci.draw_circle(Vector2(hx, 4.5 + absf(hx) * -0.15), 1.0, Color("8c90a8"))
		ci.draw_line(Vector2.ZERO, Vector2(0, -14), INK, 3.0)
		ci.draw_line(Vector2.ZERO, Vector2(0, -14), Color("8c90a8"), 1.5)
		var on := fmod(_t, 1.2) < 0.25
		ci.draw_circle(Vector2(0, -15), 3.0, INK)
		ci.draw_circle(Vector2(0, -15), 2.2, Color("ff6a6a") if on else Color("6a2a3a"))
		if on:
			for q in 3:
				ci.draw_arc(Vector2(0, -15), 6.0 + q * 5.0, -PI * 0.8, -PI * 0.2, 8, Color(1, 0.7, 0.7, 0.6 - q * 0.15), 1.2)
		ci.draw_set_transform(Vector2.ZERO))


## La Tierra flotando detrás de la base, girando despacio, con la casita de Kroker encima (con la
## ventana de su cuarto encendida). Es lo que mira el telescopio.
## The Earth floating behind the base, turning slowly, with Kroker's little house on top (his
## bedroom window lit). It's what the telescope looks at.
func _build_luna_earth(at: Vector2) -> void:
	_prop(at, func(ci: CanvasItem) -> void:
		var c := Vector2(0, -92 + sin(_t * 0.6) * 4.0)
		var r := 30.0
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color("7fb8ff", 0.22))
		ci.draw_circle(c, r + 1.8, INK)
		ci.draw_circle(c, r, Color("3f7fd8"))
		# Continentes que pasan (se recortan al borde de la esfera) / Continents drifting past (clipped to the sphere's edge)
		for q in 5:
			var lon := fposmod(_t * 0.04 + q * 0.21, 1.0) * 2.0 - 1.0
			var lat := sin(q * 2.3) * 0.55
			var p := c + Vector2(lon * r, lat * r)
			var shrink := sqrt(maxf(0.0, 1.0 - lon * lon))
			if shrink <= 0.05:
				continue
			var blob := PackedVector2Array()
			for k in 9:
				var a := TAU * k / 9.0
				var rr := (7.0 + 4.0 * sin(a * 3.0 + q)) * (0.8 + 0.2 * (q % 2))
				var v := p + Vector2(cos(a) * rr * shrink, sin(a) * rr * 0.8)
				if v.distance_to(c) > r - 1.0:
					v = c + (v - c).normalized() * (r - 1.0)
				blob.append(v)
			ci.draw_colored_polygon(blob, Color("5fbf6a"))
		# Nubes / Clouds
		for q in 3:
			var lon2 := fposmod(_t * 0.07 + q * 0.37, 1.0) * 2.0 - 1.0
			var cy := c.y + (q - 1) * 13.0
			var w := 10.0 * sqrt(maxf(0.0, 1.0 - lon2 * lon2))
			ci.draw_line(Vector2(c.x + lon2 * (r - 4.0) - w, cy), Vector2(c.x + lon2 * (r - 4.0) + w, cy), Color(1, 1, 1, 0.75), 3.0)
		# Sombra del lado de la noche y brillo / Night-side shade and a glint
		var night := PackedVector2Array()
		for k in 17:
			var a := -PI * 0.5 + PI * k / 16.0
			night.append(c + Vector2(cos(a), sin(a)) * r)
		for k in 17:
			var a := PI * 0.5 - PI * k / 16.0
			night.append(c + Vector2(cos(a) * r * 0.45, sin(a) * r))
		ci.draw_colored_polygon(night, Color(0.05, 0.03, 0.2, 0.35))
		ci.draw_arc(c, r - 5.0, -2.6, -1.9, 8, Color(1, 1, 1, 0.6), 3.0)
		# La casa de Kroker encima, con la luz de su cuarto / Kroker's house on top, his bedroom light on
		var h := c + Vector2(0, -r + 2.0)
		ci.draw_rect(Rect2(h + Vector2(-9, -12), Vector2(18, 13)), INK)
		ci.draw_rect(Rect2(h + Vector2(-8, -11), Vector2(16, 12)), Color("f4e6d0"))
		ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-12, -11), h + Vector2(12, -11), h + Vector2(0, -22)]), INK)
		ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-10, -12), h + Vector2(10, -12), h + Vector2(0, -20)]), Color("c84a4a"))
		var lamp := 0.8 + 0.2 * sin(_t * 2.0)
		ci.draw_rect(Rect2(h + Vector2(-5, -8), Vector2(4, 4)), Color("ffd27a", lamp))
		ci.draw_rect(Rect2(h + Vector2(2, -6), Vector2(3, 7)), Color("6a4a3a"))
		ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(h + Vector2(-11, -14), Vector2(12, 12)), false, Color("ffd27a", 0.3 * lamp)))


## Rover de juguete: coche teledirigido con antena y faro, dando vueltas al cráter grande
## A toy rover: a radio-controlled car with an antenna and a headlight, circling the big crater
func _tick_luna() -> void:
	var a := _t * 0.45
	var c := _isle_pos("luna") + LUNA_CRATER
	_rover.position = c + Vector2(cos(a) * 37.0, sin(a) * 20.0)
	_rover.set_meta("dir", Vector2(-sin(a) * 37.0, cos(a) * 20.0).normalized())


func _paint_rover(ci: CanvasItem) -> void:
	var dir: Vector2 = _rover.get_meta("dir", Vector2.RIGHT) if is_instance_valid(_rover) else Vector2.RIGHT
	var face := signf(dir.x) if absf(dir.x) > 0.05 else 1.0
	var bump := absf(sin(_t * 9.0)) * 0.8
	_shadow(ci, Vector2.ZERO, Vector2(11, 3))
	ci.draw_set_transform(Vector2(0, -bump), 0.0, Vector2(face, 1.0))
	for wx: float in [-7.0, 0.0, 7.0]:
		ci.draw_circle(Vector2(wx, -3), 3.4, INK)
		ci.draw_circle(Vector2(wx, -3), 2.4, Color("4a4a62"))
		var sp := _t * 12.0 + wx
		ci.draw_line(Vector2(wx, -3), Vector2(wx, -3) + Vector2(cos(sp), sin(sp)) * 2.0, Color("9aa0c0"), 1.0)
	ci.draw_rect(Rect2(-11, -12, 22, 7), INK)
	ci.draw_rect(Rect2(-10, -11, 20, 5), Color("f4f1ea"))
	ci.draw_rect(Rect2(-10, -8, 20, 2), Color("ff8a5c"))
	ci.draw_rect(Rect2(-4, -17, 9, 6), INK)
	ci.draw_rect(Rect2(-3, -16, 7, 4), Color("5f6fd6"))
	ci.draw_line(Vector2(-8, -12), Vector2(-10, -24), INK, 2.0)
	ci.draw_line(Vector2(-8, -12), Vector2(-10, -24), Color("cdd0e0"), 1.0)
	var on := fmod(_t, 0.8) < 0.4
	ci.draw_circle(Vector2(-10, -25), 1.6, Color("7fe08a") if on else Color("2a5a3a"))
	ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(10, -16), Vector2(18, 10)), false, Color("fff4c0", 0.35))
	ci.draw_rect(Rect2(9, -10, 2, 3), Color("fff4c0"))
	ci.draw_set_transform(Vector2.ZERO)



# --- Kroker ---

## En la base de Luna hay poca gravedad: Kroker anda dando saltos lentos y levanta polvo al caer
## On Luna's base gravity is low: Kroker walks in slow bounces and kicks up dust as he lands
var _dust: Array[Vector3] = []     # x, y, edad / x, y, age
var _moon_k := 0.0

func _on_moon() -> bool:
	return _walk_polys.has("luna") and Geometry2D.is_point_in_polygon(_pos, _walk_polys["luna"])

func _draw_kroker(ci: CanvasItem) -> void:
	for d in _dust:
		var k := d.z / 0.7
		for q in 3:
			var off := Vector2((q - 1) * 5.0 * (0.6 + k), -k * 6.0 - absf(q - 1) * 1.0)
			ci.draw_circle(Vector2(d.x, d.y) - _pos + off, 2.0 + k * 3.0, Color(0.85, 0.84, 0.92, 0.55 * (1.0 - k)))
	var hop := _moon_k * (absf(sin(_walk * 0.5)) * 12.0 * _moving + (1.0 - _moving) * (2.0 + sin(_t * 1.6) * 2.0))
	ci.draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(11.0 - hop * 0.3, 3)), Color(0, 0, 0, 0.3))
	var outfit := GameState.selected_character if GameState.weapon_unlocked(GameState.selected_character) else "bat"
	KrokerArt.draw(ci, Transform2D(0.0, Vector2(KROKER_SCALE, KROKER_SCALE), 0.0, Vector2(-100.0 * KROKER_SCALE, -288.0 * KROKER_SCALE - hop)),
		outfit, _t, {"facing": _facing, "walk": _walk * (1.0 - _moon_k * 0.5), "moving": _moving, "armed": true})
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
	var step_before := int(_walk / PI)
	_walk += moved * delta * 0.09
	# Con el yoyó, si se queda quieto, hace la vuelta al mundo / With the yo-yo, standing still he does around the world
	_still = _still + delta if _moving < 0.1 else 0.0
	KrokerArt.yoyo_idle = move_toward(KrokerArt.yoyo_idle, 1.0 if _still > 1.5 else 0.0, delta * 3.0)
	# Pisadas suaves sobre la piedra del plano astral / Soft footsteps on the astral plane's stone
	_moon_k = move_toward(_moon_k, 1.0 if _on_moon() else 0.0, delta * 3.0)
	if _moon_k > 0.5:
		# En la luna, un saltito cada dos pasos: al caer, polvo y un «puf» blando
		# On the moon, a hop every two steps: on landing, dust and a soft "poof"
		if int(_walk / TAU) != int((_walk - moved * delta * 0.09) / TAU) and _moving > 0.5:
			_dust.append(Vector3(_pos.x, _pos.y, 0.0))
			Audio.play("step", -20.0, 0.12, 0.7)
	elif int(_walk / PI) != step_before and _moving > 0.5:
		Audio.play("step", -22.0, 0.12, 0.92)
	for q in range(_dust.size() - 1, -1, -1):
		_dust[q].z += delta
		if _dust[q].z > 0.7:
			_dust.remove_at(q)
	_cam = _cam.lerp(_pos + Vector2(0, -24), minf(1.0, delta * 4.0))
	_kroker.position = _pos
	if is_instance_valid(_ball):
		_tick_svinho()
	if is_instance_valid(_pinche):
		_tick_pinche()
	if is_instance_valid(_silly):
		_tick_silly()
	if is_instance_valid(_rover):
		_tick_luna()
	_check_zone()
	var off := _offset()
	_ground.position = off
	_sort.position = off
	_motes_node.position = off
	for p in _props:
		p.queue_redraw()
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


func _exit_tree() -> void:
	KrokerArt.yoyo_idle = 0.0
