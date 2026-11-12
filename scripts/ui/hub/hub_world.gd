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
func _build_luna() -> void:
	var c := _isle_pos("luna")
	# Cohete de cartón / Cardboard rocket
	var rk := c + Vector2(-96, -10)
	_blocks.append({"c": rk, "r": Vector2(16, 6)})
	_prop(rk, func(ci: CanvasItem) -> void:
		_shadow(ci, Vector2.ZERO, Vector2(20, 4))
		var shake := Vector2(sin(_t * 30.0) * 0.6, 0) if fmod(_t, 7.0) > 6.2 else Vector2.ZERO
		ci.draw_set_transform(shake)
		for side in [-1.0, 1.0]:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(side * 9, -10), Vector2(side * 18, 0), Vector2(side * 9, -24)]), Color("c83a3a"))
		ci.draw_rect(Rect2(-10, -66, 20, 60), Color("1a1024"))
		ci.draw_rect(Rect2(-9, -65, 18, 58), Color("c9a27a"))
		ci.draw_rect(Rect2(2, -65, 7, 58), Color("a8845e"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, -66), Vector2(10, -66), Vector2(0, -88)]), Color("c83a3a"))
		ci.draw_circle(Vector2(0, -48), 5.0, Color("1a1024"))
		ci.draw_circle(Vector2(0, -48), 4.0, Color("8fe0ff"))
		ci.draw_line(Vector2(-7, -30), Vector2(6, -30), Color("1a1024"), 1.0)
		ci.draw_line(Vector2(-7, -24), Vector2(4, -24), Color("1a1024"), 1.0)
		# A ratos echa humo, como si fuera a despegar / Now and then it puffs smoke, as if about to take off
		if fmod(_t, 7.0) > 6.2:
			for i in 5:
				var ph := fposmod(_t * 3.0 + i * 0.2, 1.0)
				ci.draw_circle(Vector2(sin(i * 2.0) * 8.0 * ph, ph * 10.0), 3.0 + ph * 5.0, Color(0.95, 0.95, 1.0, 0.6 * (1.0 - ph)))
		ci.draw_set_transform(Vector2.ZERO))
	# Bandera con la luna cosida / Flag with the sewn-on moon
	var fl := c + Vector2(92, -24)
	_blocks.append({"c": fl, "r": Vector2(4, 3)})
	_prop(fl, func(ci: CanvasItem) -> void:
		_shadow(ci, Vector2.ZERO, Vector2(6, 2))
		ci.draw_line(Vector2(0, 1), Vector2(0, -55), Color("1a1024"), 4.0)
		ci.draw_line(Vector2.ZERO, Vector2(0, -54), Color("b8bccf"), 2.0)
		var pts := PackedVector2Array()
		for i in 7:
			var f := i / 6.0
			pts.append(Vector2(f * 28.0, -52.0 + sin(_t * 2.0 + f * 4.0) * 2.0 * f))
		for i in range(6, -1, -1):
			var f := i / 6.0
			pts.append(Vector2(f * 28.0, -34.0 + sin(_t * 2.0 + f * 4.0) * 2.0 * f))
		ci.draw_colored_polygon(pts, Color("3a3480"))
		ci.draw_circle(Vector2(14, -43 + sin(_t * 2.0 + 2.0)), 5.0, Color("f6d993"))
		ci.draw_circle(Vector2(16, -44 + sin(_t * 2.0 + 2.0)), 4.0, Color("3a3480")))
	# Antena que pita / Beeping antenna
	var an := c + Vector2(60, 40)
	_blocks.append({"c": an, "r": Vector2(6, 3)})
	_prop(an, func(ci: CanvasItem) -> void:
		_shadow(ci, Vector2.ZERO, Vector2(12, 3))
		# Trípode de palos de escoba y una antena parabólica hecha con un colador
		# A tripod of broomsticks and a satellite dish made out of a colander
		for lx: float in [-9.0, 0.0, 9.0]:
			ci.draw_line(Vector2(lx, 2.0 if lx == 0.0 else 0.0), Vector2(0, -16), Color("1a1024"), 3.0)
			ci.draw_line(Vector2(lx, 2.0 if lx == 0.0 else 0.0), Vector2(0, -16), Color("8c90a8"), 1.5)
		ci.draw_line(Vector2(0, -14), Vector2(0, -30), Color("1a1024"), 4.0)
		ci.draw_line(Vector2(0, -14), Vector2(0, -30), Color("b8bccf"), 2.0)
		var turn := sin(_t * 0.5) * 0.25
		ci.draw_set_transform(Vector2(0, -34), turn - 0.35)
		var dish := PackedVector2Array()
		for i in 11:
			var a := PI * i / 10.0
			dish.append(Vector2(cos(a) * 14.0, sin(a) * 7.0))
		ci.draw_colored_polygon(dish, Color("1a1024"))
		dish.clear()
		for i in 11:
			var a := PI * i / 10.0
			dish.append(Vector2(cos(a) * 12.5, sin(a) * 5.8))
		ci.draw_colored_polygon(dish, Color("e4e6f0"))
		for hx: float in [-5.0, 0.0, 5.0]:
			ci.draw_circle(Vector2(hx, 2.5), 1.0, Color("8c90a8"))
		ci.draw_line(Vector2.ZERO, Vector2(0, -10), Color("8c90a8"), 1.5)
		var on := fmod(_t, 1.2) < 0.25
		ci.draw_circle(Vector2(0, -11), 2.5, Color("ff6a6a") if on else Color("6a2a3a"))
		if on:
			for k in 2:
				ci.draw_arc(Vector2(0, -11), 6.0 + k * 5.0, -PI * 0.8, -PI * 0.2, 8, Color(1, 0.6, 0.6, 0.6), 1.0)
		ci.draw_set_transform(Vector2.ZERO))
	var ln := _npc_prop("luna", c + Vector2(4, -6))
	ln.painter = func(ci: CanvasItem) -> void:
		_draw_npc(ci, "luna", Vector2.ZERO, false)


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
	var step_before := int(_walk / PI)
	_walk += moved * delta * 0.09
	# Con el yoyó, si se queda quieto, hace la vuelta al mundo / With the yo-yo, standing still he does around the world
	_still = _still + delta if _moving < 0.1 else 0.0
	KrokerArt.yoyo_idle = move_toward(KrokerArt.yoyo_idle, 1.0 if _still > 1.5 else 0.0, delta * 3.0)
	# Pisadas suaves sobre la piedra del plano astral / Soft footsteps on the astral plane's stone
	if int(_walk / PI) != step_before and _moving > 0.5:
		Audio.play("step", -22.0, 0.12, 0.92)
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
