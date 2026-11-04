class_name Act4Room
extends Bedroom
## Acto 4 (sueños 16 a 20, el final): la Metrópolis. Una ciudad grande que se recorre en todas
## direcciones, como las ciudades centrales de los juegos de Pokémon: avenidas, una gran plaza
## con fuente, parques, un estanque, árboles, setos, farolas y edificios de todos los tamaños con
## la torre de los sueños en medio (plano en CityLayout, tools/make_city_map.py). La cámara sigue a
## Kroker en las dos direcciones. Cada sueño tiene una estética distinta (synthwave, steampunk,
## queso, frutiger aero, solarpunk, dieselpunk o brutalista) y de vez en cuando se derrumba un
## edificio: sus escombros cortan el paso un rato.
## Act 4 (dreams 16 to 20, the final one): the Metropolis. A big city to roam in every direction,
## like the central cities in the Pokémon games: avenues, a big plaza with a fountain, parks, a
## pond, trees, hedges, lamps and buildings of every size with the dream tower in the middle (map
## in CityLayout, tools/make_city_map.py). The camera follows Kroker both ways. Each dream has a
## different look (synthwave, steampunk, cheese, frutiger aero, solarpunk, dieselpunk or
## brutalist), and now and then a building collapses: its rubble blocks the way for a while.

const T := CityLayout.TILE
const MAP_SIZE := Vector2(CityLayout.COLS * T, CityLayout.ROWS * T)
## Escombros que cortan el paso (lienzo) y lo que les queda / Rubble blocking the way (canvas) and the time it has left
const RUBBLE_LIFE := 28.0
const FACADE_H := 250.0
const TOWER_FACADE_H := 375.0

## Colores de cada estética para lo que se dibuja en código / Each look's colours for what's drawn in code
## plinth: acera alrededor de los edificios; curb: bordillo; accent: detalles; roof: tejado de las casas;
## flat: azotea; sign: carteles; haze: neblina del ambiente
## plinth: pavement round the buildings; curb: kerb; accent: details; roof: house roofs; flat: flat roofs;
## sign: signs; haze: ambient haze
const LOOK := {
	"synthwave": {"plinth": "3a2466", "curb": "ff3aa0", "accent": "5ff2ff", "roof": "c8327e", "flat": "2a1850", "sign": "ff3aa0", "haze": "ff3aa0", "edge": "140a2a"},
	"steampunk": {"plinth": "8a6a52", "curb": "c9961e", "accent": "c9961e", "roof": "a8542e", "flat": "5a4636", "sign": "2a1a14", "haze": "e0a45a", "edge": "2a1a14"},
	"cheese": {"plinth": "e8b468", "curb": "7a4520", "accent": "c8402a", "roof": "e8902a", "flat": "f0b83a", "sign": "6a3818", "haze": "fff0a0", "edge": "5a2e14"},
	"aero": {"plinth": "ffffff", "curb": "2cc84a", "accent": "1a9ae0", "roof": "1a9ae0", "flat": "7ccaf0", "sign": "1a7ac8", "haze": "4ac0f0", "edge": "1a4a78"},
	"solarpunk": {"plinth": "f6f0e2", "curb": "4fa85a", "accent": "4fa85a", "roof": "5fb86a", "flat": "e0d8c8", "sign": "3f7a4a", "haze": "fff0c0", "edge": "3a4a3a"},
	"dieselpunk": {"plinth": "6a605a", "curb": "e0b53a", "accent": "e0b53a", "roof": "8a2a22", "flat": "5a4e48", "sign": "1a1210", "haze": "e08a3a", "edge": "140e0c"},
	"noir": {"plinth": "4a4850", "curb": "8a8478", "accent": "e0303a", "roof": "2a2830", "flat": "3a3840", "sign": "141418", "haze": "b0b0c8", "edge": "0a0a0e"},
	"brutalist": {"plinth": "a6a198", "curb": "f2b632", "accent": "f2b632", "roof": "6a6660", "flat": "7e7a74", "sign": "2a2c34", "haze": "6a7080", "edge": "26262a"},
}

var style := "synthwave"
var final := false
var rubble: Array[Rect2] = []
var _rubble_t: Array[float] = []
var _static: Array[Rect2] = []          # edificios, árboles, setos, agua... / buildings, trees, hedges, water...
var _grid := {}                         # cubo (Vector2i) → índices de _static / bucket → indices of _static
var _holes: Array[Rect2] = []
var tower_bases: Array[Rect2] = []      # pies de los rascacielos que se caen / feet of the skyscrapers that fall
var _open := 0
var _near_cache := {}
var _near_frame := -1
const BUCKET := 480.0
## El pilón de la fuente (las baldosas "W" de la plaza) / The fountain basin (the plaza's "W" tiles)
const FOUNTAIN := Rect2(Vector2(20, 13) * T, Vector2(4, 3) * T)
## El estanque del parque del oeste / The west park's pond
const POND := Rect2(Vector2(4, 21) * T, Vector2(6, 4) * T)


func _ready() -> void:
	super._ready()
	_build_static()
	# Más alcantarillas abiertas en cada sueño / More open manholes in each dream
	var spots := CityLayout.HOLES.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(style) + weird
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	for s: Vector2i in spots:
		_holes.append(Rect2(Vector2(s) * T + Vector2(12, 26), Vector2(T - 24, T - 52)))
	_open = mini(_holes.size(), 3 + 2 * weird + (3 if final else 0))
	var amb := CityAmbience.new()
	amb.room = self
	amb.z_index = 60
	add_child(amb)


func walkable() -> Rect2:
	return Rect2(Vector2(T, T), MAP_SIZE - Vector2(T, T) * 2.0)


func follows_camera() -> bool:
	return true


## Ciudad abierta: la cámara sigue también en vertical / Open city: the camera follows vertically too
func open_map() -> bool:
	return true


func start_point() -> Vector2:
	return (Vector2(CityLayout.START) + Vector2(0.5, 0.5)) * T


func map_world_rect() -> Rect2:
	return Bedroom.rect_world(Rect2(Vector2.ZERO, MAP_SIZE))


func hole_count() -> int:
	return _open


func holes_list() -> Array[Rect2]:
	return _holes


func wall_hole_count() -> int:
	return 0


func wall_holes_list() -> Array[Rect2]:
	return []


func crack_zones() -> Array[Rect2]:
	return []


func obstacles_list() -> Array[Rect2]:
	var out: Array[Rect2] = _static.duplicate()
	out.append_array(rubble)
	out.append_array(tower_bases)
	return out


## Lo que estorba cerca de un punto del mundo (rápido: la ciudad tiene cientos de obstáculos)
## What's in the way near a world point (fast: the city has hundreds of obstacles)
func blockers_near(world_p: Vector2) -> Array[Rect2]:
	var frame := Engine.get_physics_frames()
	if frame != _near_frame:
		_near_frame = frame
		_near_cache.clear()
	var c := (world_p - OFFSET) / S
	var key := Vector2i(floori(c.x / BUCKET), floori(c.y / BUCKET))
	if _near_cache.has(key):
		return _near_cache[key]
	var out: Array[Rect2] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for i: int in _grid.get(key + Vector2i(dx, dy), []):
				if not out.has(_static[i]):
					out.append(_static[i])
	out.append_array(rubble)
	out.append_array(tower_bases)
	for i in _open:
		out.append(_holes[i].grow(-10))
	_near_cache[key] = out
	return out


func _build_static() -> void:
	for r in CityLayout.ROWS:
		var row: String = CityLayout.MAP[r]
		for c in CityLayout.COLS:
			var p := Vector2(c, r) * T
			match row[c]:
				"T": _static.append(Rect2(p + Vector2(30, 40), Vector2(60, 70)))
				"h": _static.append(Rect2(p + Vector2(0, 50), Vector2(T, 60)))
				"W":
					# La fuente y el estanque son redondos: se ponen aparte / The fountain and the pond are round: added separately
					if not FOUNTAIN.has_point(p + Vector2(1, 1)) and not POND.has_point(p + Vector2(1, 1)):
						_static.append(Rect2(p, Vector2(T, T)))
				"l": _static.append(Rect2(p + Vector2(48, 70), Vector2(24, 24)))
				"b": _static.append(Rect2(p + Vector2(10, 50), Vector2(100, 40)))
	for b: Array in CityLayout.BUILDINGS:
		_static.append(Rect2(Vector2(b[0], b[1]) * T, Vector2(b[2], b[3]) * T))
	# Fuente y estanque: tiras horizontales que siguen la elipse del pilón y de la orilla
	# Fountain and pond: horizontal strips that follow the ellipse of the basin and the bank
	_add_ellipse(FOUNTAIN.get_center() + Vector2(0, 14), Vector2(FOUNTAIN.size.x * 0.5 - 16.0, FOUNTAIN.size.y * 0.5 - 30.0))
	_add_ellipse(POND.get_center(), POND.size * 0.5 - Vector2(28, 26))
	for i in _static.size():
		var r: Rect2 = _static[i]
		for by in range(floori(r.position.y / BUCKET), floori(r.end.y / BUCKET) + 1):
			for bx in range(floori(r.position.x / BUCKET), floori(r.end.x / BUCKET) + 1):
				var k := Vector2i(bx, by)
				if not _grid.has(k):
					_grid[k] = []
				_grid[k].append(i)


## Sitios para los rascacielos que se caen: baldosa de calle con una franja libre a un lado (donde
## caerán), repartidos por el mapa y lejos de donde empieza Kroker. Devuelve [centro de la franja, lado]
## Spots for the skyscrapers that fall: street paving with a clear strip to one side (where they'll
## fall), spread over the map and away from where Kroker starts. Returns [strip centre, side]
func tower_sites(count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(style) * 7 + weird
	var cands: Array = []
	var start := start_point()
	for r in CityLayout.ROWS:
		for c in CityLayout.COLS:
			if not CityLayout.MAP[r][c] in [".", ":"]:
				continue
			var foot := (Vector2(c, r) + Vector2(0.5, 0.5)) * T
			if foot.distance_to(start) < 520.0 or FOUNTAIN.grow(200.0).has_point(foot):
				continue
			for d in [1.0, -1.0]:
				var center := foot + Vector2(CityFall.LENGTH / 2.0 * d, 0)
				var strip := Rect2(center - Vector2(CityFall.LENGTH / 2.0, CityFall.DEPTH / 2.0), Vector2(CityFall.LENGTH, CityFall.DEPTH))
				if _free(strip.grow(10.0)) and _free(Rect2(foot - Vector2(60, 40), Vector2(120, 60))):
					cands.append([center, d])
	# Barajar y quedarse con los que están separados / Shuffle and keep the ones far apart
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var out: Array = []
	for cand: Array in cands:
		var ok := true
		for o: Array in out:
			if (o[0] as Vector2).distance_to(cand[0]) < 700.0:
				ok = false
				break
		if ok:
			out.append(cand)
			if out.size() >= count:
				break
	return out


## Dónde se apoya Kroker en la cinemática del último sueño: delante de una fachada cerca del
## centro, a un lado de la puerta / Where Kroker leans in the last dream's cutscene: in front of a
## facade near the middle, to one side of the door
func lean_spot() -> Vector2:
	var best := start_point()
	var best_d := INF
	for b: Array in CityLayout.BUILDINGS:
		if b[4] == "tower":
			continue
		var spot := Vector2((b[0] + b[2] * 0.25) * T, (b[1] + b[3]) * T + 44.0)
		if not _free(Rect2(spot - Vector2(40, 30), Vector2(80, 50))):
			continue
		var d := spot.distance_to(start_point())
		if d < best_d:
			best_d = d
			best = spot
	return best


func _free(r: Rect2) -> bool:
	if not walkable().encloses(r):
		return false
	for o in _static:
		if o.intersects(r):
			return false
	for h in _holes:
		if h.intersects(r):
			return false
	for b in tower_bases:
		if b.grow(40.0).intersects(r):
			return false
	return true


## Tapa una elipse con tiras horizontales (para que no haya esquinas invisibles)
## Covers an ellipse with horizontal strips (so there are no invisible corners)
func _add_ellipse(c: Vector2, r: Vector2) -> void:
	var step := 22.0
	var y := -r.y
	while y < r.y:
		var mid := y + step * 0.5
		var hw := r.x * sqrt(maxf(0.0, 1.0 - (mid / r.y) ** 2))
		if hw > 4.0:
			_static.append(Rect2(c + Vector2(-hw, y), Vector2(hw * 2.0, minf(step, r.y - y))))
		y += step


## Un edificio se ha derrumbado: sus escombros cortan el paso un rato / A building has collapsed: its rubble blocks the way for a while
func add_rubble(r: Rect2) -> void:
	rubble.append(r)
	_rubble_t.append(RUBBLE_LIFE)


func _process(delta: float) -> void:
	for i in range(_rubble_t.size() - 1, -1, -1):
		_rubble_t[i] -= delta
		if _rubble_t[i] <= 0.0:
			_rubble_t.remove_at(i)
			rubble.remove_at(i)
	super._process(delta)


## Lo que queda de un escombro (0..1) / What's left of a rubble pile (0..1)
func rubble_left(r: Rect2) -> float:
	var i := rubble.find(r)
	return clampf(_rubble_t[i] / 2.0, 0.0, 1.0) if i >= 0 else 0.0


# --- Dibujo del suelo / Drawing the ground -----------------------------------------------

func _tile(kind: String) -> String:
	return "city_%s_%s" % [style, kind]


## Agua de cada ciudad (como la de sus baldosas) / Each city's water (like its tiles)
func water_color() -> Color:
	return Color({"noir": "1a2030", "cheese": "ff9a3a", "synthwave": "4a2aa8", "steampunk": "3a6a7a", "dieselpunk": "2a4a5a", "brutalist": "5a7a8a"}.get(style, "3a9ad8"))


func look(key: String) -> Color:
	return Color(LOOK[style][key])


static func _hash(c: int, r: int) -> int:
	return hash(Vector2i(c, r) * 7 + Vector2i(13, 5)) & 1023


func _is_grass(c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= CityLayout.COLS or r >= CityLayout.ROWS:
		return true
	return CityLayout.MAP[r][c] in [",", "*", "T", "h"] or POND.has_point(Vector2(c, r) * T + Vector2(1, 1))


func _draw() -> void:
	# Canto de la ciudad flotando en el sueño / Edge of the city floating in the dream
	draw_rect(Rect2(Vector2(0, MAP_SIZE.y), Vector2(MAP_SIZE.x, 60)), Color("1b1846"))
	draw_rect(Rect2(Vector2(0, MAP_SIZE.y), Vector2(MAP_SIZE.x, 6)), Color("6a63b8"))
	# Solo lo que se ve / Only what's visible
	var view := _view_canvas().grow(T)
	var c0 := clampi(floori(view.position.x / T), 0, CityLayout.COLS - 1)
	var c1 := clampi(floori(view.end.x / T), 0, CityLayout.COLS - 1)
	var r0 := clampi(floori(view.position.y / T), 0, CityLayout.ROWS - 1)
	var r1 := clampi(floori(view.end.y / T), 0, CityLayout.ROWS - 1)
	# 1) Baldosas, con un pelín de variación de tono para que no se vea repetido
	# 1) Tiles, with a touch of tone variation so it doesn't look repeated
	for r in range(r0, r1 + 1):
		var row: String = CityLayout.MAP[r]
		for c in range(c0, c1 + 1):
			var ch := row[c]
			var kind := "pave"
			match ch:
				":": kind = "plaza"
				",", "T", "h": kind = "grass"
				"*": kind = "flowers"
				"W": kind = "water"
			if ch == "W" and FOUNTAIN.has_point(Vector2(c, r) * T + Vector2(1, 1)):
				kind = "plaza"
			elif ch == "W" and POND.has_point(Vector2(c, r) * T + Vector2(1, 1)):
				kind = "grass"
			var v := 0.97 + float(_hash(c, r) % 5) * 0.015
			if ch == "T":
				v *= 0.8   # suelo de bosque, más oscuro / forest floor, darker
			Sprites.draw(self, _tile(kind), Color(v, v, v), Vector2(c, r) * T)
	# 2) Dibujo de la plaza alrededor de la fuente / Plaza pattern round the fountain
	_draw_plaza_rings()
	# 3) Bordes: césped con bordillo, agua con piedra / Edges: grass with a kerb, water with stone
	for r in range(r0, r1 + 1):
		var row: String = CityLayout.MAP[r]
		for c in range(c0, c1 + 1):
			var ch := row[c]
			var p := Vector2(c, r) * T
			if ch == "W" and (FOUNTAIN.has_point(p + Vector2(1, 1)) or POND.has_point(p + Vector2(1, 1))):
				continue
			if ch == "W":
				_draw_water_rim(c, r, p)
			elif ch in [",", "*", "T", "h"]:
				_draw_grass_edge(c, r, p)
			else:
				_draw_decal(c, r, p)
	# 4) Acera alrededor de cada edificio (bajo su nodo) / Pavement round each building (under its node)
	for b: Array in CityLayout.BUILDINGS:
		var br := Rect2(Vector2(b[0], b[1]) * T, Vector2(b[2], b[3]) * T)
		if br.grow(40).intersects(view):
			var ring := br.grow(18)
			draw_rect(ring, look("plinth"))
			draw_rect(Rect2(ring.position + Vector2(0, ring.size.y - 6), Vector2(ring.size.x, 6)), look("plinth").darkened(0.25))
			draw_rect(ring, look("curb").darkened(0.2), false, 3.0)
	if POND.grow(T).intersects(view):
		_draw_pond()
	_draw_fountain()
	_draw_holes()
	draw_set_transform(Vector2.ZERO)


## Anillos y radios de baldosa de otro color alrededor de la fuente / Rings and spokes of differently coloured paving round the fountain
func _draw_plaza_rings() -> void:
	var c := FOUNTAIN.get_center()
	var acc := look("accent")
	for i in 12:
		var a := TAU * i / 12.0
		draw_line(c + Vector2.from_angle(a) * 260.0, c + Vector2.from_angle(a) * 560.0, Color(acc, 0.22), 10.0)
	for rr in [300.0, 430.0, 560.0]:
		draw_arc(c, rr, 0.0, TAU, 64, Color(acc, 0.35), 12.0)
		draw_arc(c, rr - 9.0, 0.0, TAU, 64, Color(0, 0, 0, 0.12), 3.0)


## Borde del césped que da a baldosa: hierba más oscura y bordillo / Grass edge facing paving: darker grass and a kerb
func _draw_grass_edge(c: int, r: int, p: Vector2) -> void:
	var curb := look("curb")
	var dark := Color(0.1, 0.25, 0.12, 0.45)
	if not _is_grass(c, r - 1) and not _is_water(c, r - 1):
		draw_rect(Rect2(p, Vector2(T, 10)), curb)
		draw_rect(Rect2(p + Vector2(0, 10), Vector2(T, 6)), dark)
	if not _is_grass(c, r + 1) and not _is_water(c, r + 1):
		draw_rect(Rect2(p + Vector2(0, T - 14), Vector2(T, 14)), curb)
		draw_rect(Rect2(p + Vector2(0, T - 4), Vector2(T, 4)), curb.darkened(0.35))
	if not _is_grass(c - 1, r) and not _is_water(c - 1, r):
		draw_rect(Rect2(p, Vector2(10, T)), curb)
		draw_rect(Rect2(p + Vector2(10, 0), Vector2(6, T)), dark)
	if not _is_grass(c + 1, r) and not _is_water(c + 1, r):
		draw_rect(Rect2(p + Vector2(T - 10, 0), Vector2(10, T)), curb)
		draw_rect(Rect2(p + Vector2(T - 16, 0), Vector2(6, T)), dark)


## Detalles sueltos en el suelo: grietas, hojas, sumideros y charcos / Odd details on the ground: cracks, leaves, drains and puddles
func _draw_decal(c: int, r: int, p: Vector2) -> void:
	var h := _hash(c, r)
	var ink := look("edge")
	match h % 23:
		0, 11:   # grieta / crack
			var q := p + Vector2(20 + h % 60, 30 + h % 50)
			draw_polyline(PackedVector2Array([q, q + Vector2(14, 8), q + Vector2(20, 22), q + Vector2(34, 26)]), Color(ink, 0.45), 3.0)
		3:   # sumidero / drain grate
			var q := p + Vector2(40, 40)
			draw_rect(Rect2(q, Vector2(44, 28)), Color(ink, 0.4))
			for k in 4:
				draw_rect(Rect2(q + Vector2(5 + k * 10, 4), Vector2(5, 20)), Color(0, 0, 0, 0.3))
		5:   # charco con reflejo / puddle with a reflection
			var q := p + Vector2(62, 70)
			draw_colored_polygon(_ellipse(q, Vector2(34, 14)), Color(look("accent"), 0.25))
			draw_rect(Rect2(q + Vector2(-16, -6), Vector2(14, 3)), Color(1, 1, 1, 0.35))
		8, 17:   # hojas o papelitos / leaves or scraps of paper
			for k in 3:
				var q := p + Vector2(18 + (h * (k + 3)) % 84, 16 + (h * (k + 7)) % 84)
				draw_rect(Rect2(q, Vector2(8, 5)), Color(look("curb"), 0.55))


func _view_canvas() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var half := Vector2(960, 540) / cam.zoom.x * 0.5
	return Rect2((cam.global_position - half - OFFSET) / S, half * 2.0 / S)


func _is_water(c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= CityLayout.COLS or r >= CityLayout.ROWS:
		return false
	var q := Vector2(c, r) * T + Vector2(1, 1)
	return CityLayout.MAP[r][c] == "W" and not FOUNTAIN.has_point(q) and not POND.has_point(q)


## Borde de piedra alrededor del agua / Stone kerb round the water
func _draw_water_rim(c: int, r: int, p: Vector2) -> void:
	var stone := Color("c8c4d8")
	var dark := Color("6a6684")
	if not _is_water(c, r - 1):
		draw_rect(Rect2(p + Vector2(0, -6), Vector2(T, 16)), stone)
		draw_rect(Rect2(p + Vector2(0, 10), Vector2(T, 6)), dark)
	if not _is_water(c, r + 1):
		draw_rect(Rect2(p + Vector2(0, T - 14), Vector2(T, 20)), stone)
	if not _is_water(c - 1, r):
		draw_rect(Rect2(p + Vector2(-6, 0), Vector2(14, T)), stone)
	if not _is_water(c + 1, r):
		draw_rect(Rect2(p + Vector2(T - 8, 0), Vector2(14, T)), stone)
	# Brillos que se mueven / Moving glints
	var k := fposmod(_t * 0.4 + c * 0.37 + r * 0.21, 1.0)
	draw_rect(Rect2(p + Vector2(20 + k * 60, 40 + (c % 3) * 18), Vector2(18, 3)), Color(1, 1, 1, 0.35 * sin(k * PI)))


## El estanque: orilla irregular de tierra y piedras, agua con brillos, nenúfares y juncos
## The pond: an irregular bank of earth and stones, glinting water, lily pads and reeds
func _draw_pond() -> void:
	var c := POND.get_center()
	var rad := POND.size * 0.5
	var water := water_color()
	var bank := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var wob := 1.0 + 0.05 * sin(a * 3.0 + 1.0) + 0.04 * sin(a * 5.0)
		bank.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y) * wob)
		inner.append(c + Vector2(cos(a) * (rad.x - 26), sin(a) * (rad.y - 22)) * wob)
	draw_colored_polygon(bank, Color("6a5040"))
	draw_colored_polygon(inner, water.darkened(0.25))
	var deep := PackedVector2Array()
	for q in inner:
		deep.append(c + (q - c) * 0.8 + Vector2(0, 8))
	draw_colored_polygon(deep, water)
	# Piedras de la orilla / Bank stones
	for i in 40:
		if i % 3 == 0:
			draw_colored_polygon(_ellipse(bank[i].lerp(inner[i], 0.4), Vector2(14, 9)), Color("a8a4b8"))
			draw_colored_polygon(_ellipse(bank[i].lerp(inner[i], 0.4) + Vector2(-3, -3), Vector2(7, 4)), Color("d8d4e4"))
	# Brillos y ondas / Glints and ripples
	for k in 6:
		var ph := fposmod(_t * 0.25 + k / 6.0, 1.0)
		var q := c + Vector2(sin(k * 2.1) * rad.x * 0.5, cos(k * 1.3) * rad.y * 0.4)
		draw_rect(Rect2(q + Vector2(ph * 30.0, 0), Vector2(26, 4)), Color(1, 1, 1, 0.35 * sin(ph * PI)))
	# Nenúfares / Lily pads
	for k in 5:
		var q := c + Vector2(cos(k * 1.9) * rad.x * 0.55, sin(k * 1.9) * rad.y * 0.5)
		q.y += sin(_t + k) * 2.0
		draw_colored_polygon(_ellipse(q, Vector2(22, 12)), Color("3f9a4a"))
		draw_colored_polygon(PackedVector2Array([q, q + Vector2(22, -4), q + Vector2(22, 4)]), water)
		if k % 2 == 0:
			draw_circle(q + Vector2(-6, -4), 6.0, Color("ffb0c8"))
			draw_circle(q + Vector2(-6, -4), 2.5, Color("fff0a0"))
	# Juncos / Reeds
	for k in 8:
		var a := 2.3 + k * 0.12
		var q := c + Vector2(cos(a) * (rad.x - 10), sin(a) * (rad.y - 10))
		var sway := sin(_t * 1.5 + k) * 3.0
		draw_line(q, q + Vector2(sway, -40 - (k % 3) * 8), Color("4a7a3a"), 4.0)
		if k % 2:
			draw_rect(Rect2(q + Vector2(sway - 3, -46 - (k % 3) * 8), Vector2(6, 14)), Color("7a4a2a"))


## La fuente de la plaza: pilón redondo de piedra, agua con ondas, dos platos y chorros que suben y caen
## The plaza fountain: a round stone basin, rippling water, two tiers and jets rising and falling
func _draw_fountain() -> void:
	var c := FOUNTAIN.get_center()
	var rx := FOUNTAIN.size.x * 0.5 - 6.0
	var ry := FOUNTAIN.size.y * 0.5 - 20.0
	var stone := look("plinth").lerp(Color("d8d4e4"), 0.5)
	var acc := look("accent")
	var water := water_color()
	# Sombra, borde del pilón (con su cara frontal) y agua / Shadow, basin rim (with its front face) and water
	draw_colored_polygon(_ellipse(c + Vector2(14, 34), Vector2(rx + 10, ry + 8)), Color(0, 0, 0, 0.22))
	draw_colored_polygon(_ellipse(c + Vector2(0, 26), Vector2(rx, ry)), stone.darkened(0.35))
	draw_colored_polygon(_ellipse(c, Vector2(rx, ry)), stone)
	draw_colored_polygon(_ellipse(c, Vector2(rx - 26, ry - 20)), stone.darkened(0.25))
	draw_colored_polygon(_ellipse(c + Vector2(0, 4), Vector2(rx - 30, ry - 24)), water)
	draw_colored_polygon(_ellipse(c + Vector2(0, 10), Vector2(rx - 44, ry - 36)), water.lightened(0.2))
	for k in 16:
		var a := TAU * k / 16.0
		draw_rect(Rect2(c + Vector2(cos(a) * (rx - 13), sin(a) * (ry - 10)) - Vector2(4, 2), Vector2(8, 4)), Color(0, 0, 0, 0.15))
	# Ondas que se abren desde el centro / Ripples spreading from the middle
	for k in 3:
		var ph := fposmod(_t * 0.35 + k / 3.0, 1.0)
		var pts := _ellipse(c + Vector2(0, 10), Vector2(60 + ph * (rx - 110), 22 + ph * (ry - 60)))
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.35 * (1.0 - ph)), 3.0)
	# Pie, plato bajo, columna y plato alto / Base, lower bowl, column and upper bowl
	draw_rect(Rect2(c + Vector2(-22, -40), Vector2(44, 56)), stone.darkened(0.15))
	draw_colored_polygon(_ellipse(c + Vector2(0, -36), Vector2(78, 22)), stone.darkened(0.3))
	draw_colored_polygon(_ellipse(c + Vector2(0, -44), Vector2(78, 22)), stone)
	draw_colored_polygon(_ellipse(c + Vector2(0, -44), Vector2(62, 14)), water.lightened(0.2))
	draw_rect(Rect2(c + Vector2(-12, -110), Vector2(24, 66)), stone.darkened(0.1))
	draw_rect(Rect2(c + Vector2(-12, -110), Vector2(7, 66)), Color(1, 1, 1, 0.25))
	draw_colored_polygon(_ellipse(c + Vector2(0, -108), Vector2(40, 12)), stone.darkened(0.3))
	draw_colored_polygon(_ellipse(c + Vector2(0, -114), Vector2(40, 12)), stone)
	DreamBackground.draw_star(self, c + Vector2(0, -136 + sin(_t * 2.0) * 3.0), 12.0, Color(UITheme.GOLD, 0.9))
	# Cortina de agua que cae del plato bajo / Curtain of water falling off the lower bowl
	for k in 9:
		var x := -66.0 + k * 16.5
		var ph := fposmod(_t * 1.6 + k * 0.37, 1.0)
		draw_line(c + Vector2(x, -36), c + Vector2(x * 1.15, -36 + 40 * ph), Color(0.85, 0.95, 1.0, 0.6 * (1.0 - ph)), 4.0)
	# Chorros desde arriba / Jets from the top
	for i in 12:
		var ph := fposmod(_t * 0.9 + i * 0.083, 1.0)
		var a := TAU * i / 12.0
		var p := c + Vector2(0, -130) + Vector2(cos(a) * 66.0 * ph, sin(a) * 18.0 * ph - sin(ph * PI) * 40.0 + ph * 80.0)
		draw_circle(p, 6.0 * (1.0 - ph * 0.5), Color(0.85, 0.96, 1.0, 0.85 * (1.0 - ph)))


## Alcantarillas abiertas: la tapa a un lado y el vacío del sueño dentro
## Open manholes: the cover to one side and the dream void inside
func _draw_holes() -> void:
	for i in _open:
		var h := _holes[i]
		var c := h.get_center()
		var rr := h.size / 2.0
		draw_colored_polygon(_ellipse(c, rr + Vector2(8, 5)), Color("4a4660"))
		draw_colored_polygon(_ellipse(c, rr), Color("07061a"))
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - rr * 0.8, rr * 1.6), false, Color("5b4bc4", 0.35))
		for k in 5:
			var sp := c + Vector2(sin(k * 2.3 + i) * rr.x * 0.6, cos(k * 1.7 + i) * rr.y * 0.5)
			draw_circle(sp, 1.6, Color(UITheme.BONE, 0.4 + 0.4 * sin(_t * 2.0 + k)))
		# Tapa apartada / Cover pushed aside
		draw_colored_polygon(_ellipse(c + Vector2(rr.x + 22, rr.y * 0.4), Vector2(30, 12)), Color("5a5670"))
		draw_arc(c + Vector2(rr.x + 22, rr.y * 0.4), 18.0, 0.0, TAU, 16, Color("8a86a0"), 3.0)


# --- Cosas con altura, ordenadas con los personajes / Things with height, sorted with the characters ---

## Edificios, árboles, setos, farolas y bancos, cada uno con su nodo (se ordenan por altura con los personajes)
## Buildings, trees, hedges, lamps and benches, each with its own node (sorted by height with the characters)
func make_props(run_node: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for r in CityLayout.ROWS:
		var row: String = CityLayout.MAP[r]
		for c in CityLayout.COLS:
			var sprite := ""
			var base := Vector2(0.5, 0.85)
			match row[c]:
				"T": sprite = "tree"
				"h": sprite = "hedge"; base = Vector2(0.5, 0.8)
				"l": sprite = "lamp"; base = Vector2(0.5, 0.75)
				"b": sprite = "bench"; base = Vector2(0.5, 0.7)
			if sprite == "":
				continue
			var p := CityProp.new()
			p.sprite = _tile(sprite)
			p.position = Bedroom.to_world((Vector2(c, r) + base) * T)
			p.sway = sprite == "tree"
			out.append(p)
	for i in CityLayout.BUILDINGS.size():
		var b: Array = CityLayout.BUILDINGS[i]
		var bl := CityBuilding.new()
		bl.room = self
		bl.run = run_node
		bl.style = style
		bl.rect = Rect2(Vector2(b[0], b[1]) * T, Vector2(b[2], b[3]) * T)
		bl.kind = b[4]
		bl.seed = i
		bl.position = Bedroom.to_world(Vector2(bl.rect.position.x, bl.rect.end.y))
		out.append(bl)
		# Delante de cada edificio: jardineras en las esquinas y una papelera o máquina junto a la puerta
		# In front of each building: planters at the corners and a bin or vending machine by the door
		var front := bl.rect.end.y + 34.0
		var door := bl.rect.get_center().x
		var deco := [["planter", Vector2(bl.rect.position.x + 50, front)], ["planter", Vector2(bl.rect.end.x - 50, front)],
				["vending" if i % 2 else "bin", Vector2(door + 120.0 * (1 if i % 3 else -1), front - 6.0)]]
		for d: Array in deco:
			var pr := CityProp.new()
			pr.sprite = _tile(d[0])
			pr.position = Bedroom.to_world(d[1])
			out.append(pr)
	# Último sueño: la ciudad está llena de vallas publicitarias / Last dream: the city is full of billboards
	if style == "noir":
		var spots: Array[Vector2] = []
		for r in range(1, CityLayout.ROWS - 1):
			for c in range(1, CityLayout.COLS - 1):
				if not CityLayout.MAP[r][c] in [".", ":", ","]:
					continue
				var p := (Vector2(c, r) + Vector2(0.5, 0.6)) * T
				if FOUNTAIN.grow(120.0).has_point(p) or p.distance_to(start_point()) < 260.0:
					continue
				if not _free(Rect2(p - Vector2(90, 30), Vector2(180, 40))):
					continue
				var ok := true
				for q in spots:
					if q.distance_to(p) < 430.0:
						ok = false
						break
				if ok:
					spots.append(p)
		var k := 0
		for p in spots:
			var bb := CityBillboard.new()
			bb.room = self
			bb.ad = k % CityBillboard.ADS
			bb.position = Bedroom.to_world(p)
			out.append(bb)
			k += 1
	return out


## Una valla publicitaria sobre dos postes, con un anuncio que parpadea (sueño 20). Cuando Evil Ad
## se forma, el panel sale volando y quedan los postes con los bordes rotos.
## A billboard on two poles, with a flickering advert (dream 20). When Evil Ad forms, the panel flies
## off and the poles are left with torn edges.
class CityBillboard extends Node2D:
	const ADS := 6
	const PANEL := Rect2(-130, -330, 260, 140)
	var room: Act4Room
	var ad := 0
	var taken := false
	var _t := 0.0

	func _ready() -> void:
		scale = Vector2(Bedroom.S, Bedroom.S)
		_t = randf() * 5.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	## Dónde está el panel en el mundo / Where the panel is in the world
	func panel_world() -> Vector2:
		return global_position + PANEL.get_center() * Bedroom.S

	func take() -> void:
		taken = true

	func _draw() -> void:
		if not is_instance_valid(room):
			return
		var dark := Color("0e0e12")
		draw_colored_polygon(room._ellipse(Vector2(10, 4), Vector2(120, 16)), Color(0, 0, 0, 0.28))
		for x in [-90.0, 90.0]:
			draw_rect(Rect2(x - 7, PANEL.end.y - 6, 14, -PANEL.end.y + 6), Color("2a2a30"))
			draw_rect(Rect2(x - 7, PANEL.end.y - 6, 4, -PANEL.end.y + 6), Color("4a4a52"))
			draw_rect(Rect2(x - 14, -8, 28, 10), dark)
		if taken:
			# Bordes arrancados / Torn-off edges
			draw_rect(Rect2(-100, PANEL.end.y - 14, 200, 10), Color("2a2a30"))
			for i in 6:
				draw_colored_polygon(PackedVector2Array([Vector2(-100 + i * 34, PANEL.end.y - 14), Vector2(-84 + i * 34, PANEL.end.y - 30 - (i % 2) * 10), Vector2(-70 + i * 34, PANEL.end.y - 14)]), Color("3a3a42"))
			return
		draw_ad(self, PANEL, ad, _t)

	## El anuncio (lo usa también el enjambre) / The advert (also used by the swarm)
	static func draw_ad(ci: CanvasItem, r: Rect2, kind: int, t: float) -> void:
		var red := Color("e0303a")
		var cream := Color("e8dcc0")
		var dark := Color("0e0e12")
		var on := 0.35 if fmod(t + kind * 0.9, 4.0) < 0.1 else 1.0
		ci.draw_rect(r.grow(8), dark)
		ci.draw_rect(r, Color("1a0a10"))
		var c := r.get_center()
		var font := ThemeDB.fallback_font
		match kind:
			0:   # la sonrisa de Evil Ad / Evil Ad's grin
				ci.draw_rect(r.grow(-6), Color(red, 0.25 * on))
				for side in [-1.0, 1.0]:
					ci.draw_circle(c + Vector2(side * 40, -22), 18.0, Color(red, on))
					ci.draw_circle(c + Vector2(side * 40, -22), 12.0, dark)
					ci.draw_string(font, c + Vector2(side * 40 - 6, -14), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd84a", on))
				var pts := PackedVector2Array()
				for i in 9:
					pts.append(c + Vector2(-64 + i * 16, 18 + sin(i / 8.0 * PI) * 16))
				ci.draw_polyline(pts, Color(red, on), 6.0)
			1:
				ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.62), "BUY NOW", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 46, Color(red, on))
			2:
				ci.draw_rect(Rect2(r.position + Vector2(10, 10), r.size - Vector2(20, 20)), Color(cream, 0.9 * on))
				ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.64), "OBEY", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 60, Color(dark, on))
			3:
				ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.45), "SALE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color(cream, on))
				ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.85), "-99%", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 44, Color(red, on))
			4:
				for i in 3:
					ci.draw_string(font, c + Vector2(-70 + i * 50, 18), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(red if i != 1 else cream, on))
			5:
				ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.42), "DON'T", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color(cream, on))
				ci.draw_string(font, r.position + Vector2(0, r.size.y * 0.82), "WAKE UP", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38, Color(red, on))
		# Bombillas del marco / Frame bulbs
		for i in 8:
			var lit := int(t * 6.0 + i) % 2 == 0
			ci.draw_circle(Vector2(lerpf(r.position.x, r.end.x, i / 7.0), r.position.y - 4), 4.0, Color("ffe8b0") if lit else Color("4a4440"))


## Lo que forma a Evil Ad: vallas y teles que suben al cielo, giran cada vez más cerca y se juntan
## What forms Evil Ad: billboards and TVs that rise into the sky, spin closer and closer and merge
class AdSwarm extends Node2D:
	signal formed
	const TIME := 4.6
	var center := Vector2.ZERO          # en el mundo / in the world
	var _pieces: Array[Dictionary] = []
	var _t := 0.0
	var _done := false

	func add_piece(from: Vector2, kind: String, ad: int, delay: float) -> void:
		var a := (from - center).angle()
		_pieces.append({"from": from, "kind": kind, "ad": ad, "delay": delay, "a": a, "r0": maxf(200.0, from.distance_to(center)), "spin": randf_range(-3.0, 3.0)})

	func _ready() -> void:
		z_index = 50

	func _process(delta: float) -> void:
		_t += delta
		if not _done and _t >= TIME:
			_done = true
			formed.emit()
		if _t > TIME + 0.6:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(-global_position)
		var fade := clampf((TIME + 0.6 - _t) / 0.6, 0.0, 1.0)
		# Remolino de estática en el centro / A whirl of static in the middle
		var core := clampf(_t / TIME, 0.0, 1.0)
		for i in int(40 * core):
			var p := center + Vector2.from_angle(randf() * TAU) * randf() * 160.0 * core
			draw_rect(Rect2(p, Vector2(8, 4)), Color(1, 1, 1, randf() * 0.6 * fade))
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(center - Vector2(300, 300) * core, Vector2(600, 600) * core), false, Color("e0303a", 0.35 * core * fade))
		for pc in _pieces:
			var k := clampf((_t - float(pc["delay"])) / (TIME - float(pc["delay"])), 0.0, 1.0)
			if k <= 0.0:
				continue
			# Primero sube; luego gira alrededor del centro, cada vez más cerca / First it rises; then it circles the centre, closer and closer
			var up := clampf(k / 0.3, 0.0, 1.0)
			var orbit := clampf((k - 0.15) / 0.85, 0.0, 1.0)
			var ang: float = float(pc["a"]) + orbit * orbit * 7.0
			var rad: float = lerpf(float(pc["r0"]), 20.0, orbit * orbit)
			var circ: Vector2 = center + Vector2(cos(ang), sin(ang) * 0.55) * rad
			var rise: Vector2 = (pc["from"] as Vector2) + Vector2(0, -260.0 * up)
			var p := rise.lerp(circ, smoothstep(0.0, 1.0, orbit))
			var sc := lerpf(0.75, 0.25, orbit) * fade
			var rot := float(pc["spin"]) * k * 3.0
			draw_set_transform(p - global_position, rot, Vector2(sc, sc))
			if pc["kind"] == "board":
				CityBillboard.draw_ad(self, Rect2(-130, -70, 260, 140), int(pc["ad"]), _t * 3.0)
			else:
				draw_rect(Rect2(-60, -44, 120, 88), Color("0e0e12"))
				draw_rect(Rect2(-52, -36, 104, 72), Color("8a1420"))
				for j in 5:
					draw_rect(Rect2(randf_range(-50, 30), randf_range(-34, 30), 20, 4), Color(1, 1, 1, 0.6))
		draw_set_transform(Vector2.ZERO)


## Árbol, seto, farola o banco / A tree, hedge, lamp or bench
class CityProp extends Node2D:
	var sprite := ""
	var sway := false
	var _t := 0.0

	func _ready() -> void:
		scale = Vector2(Bedroom.S, Bedroom.S)
		_t = randf() * 5.0
		set_process(sway)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, sin(_t * 1.3) * 0.02 if sway else 0.0, Vector2.ONE)
		Sprites.draw(self, sprite)


## Un edificio visto desde arriba y de frente, como en los juegos de Pokémon: tejado (a dos aguas
## en las casas, azotea con pretil en el resto), fachada con cornisa y zócalo, puerta con escalón,
## cartel en las tiendas y sombra en el suelo. Se transparenta si Kroker pasa por detrás.
## A building seen from above and the front, like in the Pokémon games: roof (pitched on houses,
## a flat roof with a parapet on the rest), facade with cornice and plinth, door with a step, a
## sign on shops and a shadow on the ground. It turns see-through if Kroker walks behind it.
class CityBuilding extends Node2D:
	var room: Act4Room
	var run: Node
	var style := ""
	var rect := Rect2()        # huella en el lienzo / footprint on the canvas
	var kind := "house"
	var seed := 0
	var screen_taken := false   # su pantalla se la ha llevado Evil Ad / Evil Ad has taken its screen
	var burning := false        # ha estallado: ventanas rotas, fuego y humo / it blew up: broken windows, fire and smoke
	var _burn_t := 0.0
	var _t := 0.0

	## Estalla (cinemática del último sueño) / It blows up (last dream's cutscene)
	func explode() -> void:
		burning = true
		_burn_t = 0.0
		set_process(true)
		var c := Bedroom.to_world(Vector2(rect.get_center().x, rect.end.y)) + Vector2(0, -FACADE_H * Bedroom.S * 0.6)
		run.fx.ring(c, 120.0, Color("ffd27a"), 0.6, 2.4)
		run.fx.ring(c, 60.0, Color("e0303a"), 0.5, 2.0)
		for i in 5:
			run.fx.dissipate(c + Vector2(randf_range(-rect.size.x, rect.size.x) * Bedroom.S * 0.4, randf_range(-60, 30)), Color("8a8490"))
		run.shake(12.0)
		Audio.play("stomp", -2.0, 0.15)
		Audio.play("crack", -4.0, 0.2)

	func _ready() -> void:
		scale = Vector2(Bedroom.S, Bedroom.S)

	func _process(delta: float) -> void:
		if not is_instance_valid(room):
			return
		_t += delta
		if run == null or not is_instance_valid(run.player):
			return
		# Kroker detrás del edificio (tapado por el tejado): se ve a través / Kroker behind the building (hidden by the roof): see-through
		var p: Vector2 = (run.player.global_position - Bedroom.OFFSET) / Bedroom.S
		var top := rect.position.y - T * 0.5
		var behind := p.x > rect.position.x - 20.0 and p.x < rect.end.x + 20.0 and p.y > top and p.y < rect.end.y + 4.0
		modulate.a = move_toward(modulate.a, 0.45 if behind else 1.0, delta * 4.0)
		if burning:
			_burn_t += delta
		if kind in ["tower", "shop"] or burning or style == "noir":
			queue_redraw()

	func _c(key: String) -> Color:
		return room.look(key)

	## Un tono distinto para cada edificio / A slightly different tone for each building
	func _tone(c: Color, k := 0.12) -> Color:
		var h := fposmod(seed * 0.37, 1.0)
		return c.lerp(Color.from_hsv(fposmod(c.h + (h - 0.5) * 0.12, 1.0), c.s, c.v), 0.8).lightened((h - 0.5) * k)

	func _draw() -> void:
		if not is_instance_valid(room):
			return
		var w := rect.size.x
		var d := rect.size.y
		var fh := TOWER_FACADE_H if kind == "tower" else FACADE_H
		var top := -d - T * 0.5
		var rh := d + T * 0.5 - fh
		var edge := _c("edge")
		# Sombra en el suelo, hacia la derecha y abajo / Shadow on the ground, to the right and down
		draw_colored_polygon(PackedVector2Array([Vector2(w, -d + 20), Vector2(w + 46, -d + 50), Vector2(w + 46, 30), Vector2(30, 30), Vector2(0, 0), Vector2(w, 0)]), Color(0.05, 0.02, 0.12, 0.28))
		# Tejado / Roof
		if kind == "house":
			_pitched_roof(top, rh, w)
		else:
			_flat_roof(top, rh, w)
		# Fachada en tramos, con el tono del edificio / Facade in sections, in the building's tone
		var fac := "city_%s_%s" % [style, "facade_tall" if kind == "tower" else ("shopfront" if kind == "shop" else "facade")]
		var tint := Color.WHITE.lerp(_tone(Color(0.95, 0.92, 1.0), 0.1), 0.5)
		var x2 := 0.0
		while x2 < w:
			_draw_part(fac, Rect2(x2, -fh, minf(250.0, w - x2), fh), tint)
			x2 += 250.0
		# Cornisa arriba y zócalo abajo / Cornice on top and plinth at the bottom
		draw_rect(Rect2(-6, -fh - 4, w + 12, 16), _tone(_c("curb")).lightened(0.15))
		draw_rect(Rect2(-6, -fh + 12, w + 12, 4), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(0, -22, w, 22), _tone(_c("plinth")).darkened(0.35))
		draw_rect(Rect2(0, -22, w, 4), Color(1, 1, 1, 0.15))
		# Pilares en las esquinas / Corner pillars
		for x in [0.0, w - 14.0]:
			draw_rect(Rect2(x, -fh, 14, fh), Color(0, 0, 0, 0.18))
		# Puerta con escalón y felpudo / Door with a step and a doormat
		var dx := w / 2.0 - 62.5
		draw_rect(Rect2(dx - 10, -6, 145, 14), _c("plinth").lightened(0.2))
		draw_rect(Rect2(dx - 10, 6, 145, 4), Color(0, 0, 0, 0.3))
		Sprites.draw(self, "city_%s_door" % style, Color.WHITE, Vector2(dx, -202.0))
		draw_rect(Rect2(dx + 24, 10, 77, 12), _c("accent").darkened(0.3))
		if kind == "shop":
			_shop_sign(w, fh)
		if kind == "tower":
			_tower_crown(w, fh, top)
		# Contorno oscuro de toda la silueta (pixel art) / Dark outline round the whole silhouette (pixel art)
		draw_rect(Rect2(0, top, w, d + T * 0.5), edge, false, 4.0)
		if style == "noir" and not screen_taken and kind != "house":
			_draw_screen(w, fh)
		if burning:
			_draw_fire(w, fh, top)

	## Pantalla gigante en la fachada (sueño 20) / A giant screen on the facade (dream 20)
	func screen_world() -> Vector2:
		var fh := TOWER_FACADE_H if kind == "tower" else FACADE_H
		return global_position + Vector2(rect.size.x * 0.75, -fh * 0.62) * Bedroom.S

	func _draw_screen(w: float, fh: float) -> void:
		var r := Rect2(w * 0.75 - 70, -fh * 0.62 - 48, 140, 96)
		draw_rect(r.grow(8), Color("0e0e12"))
		draw_rect(r, Color("1a0a10"))
		var on := fmod(_t * 0.8 + seed, 3.0)
		if on < 0.12:
			for i in 8:
				draw_rect(Rect2(r.position + Vector2(randf() * 120, randf() * 90), Vector2(16, 3)), Color(1, 1, 1, 0.6))
		else:
			CityBillboard.draw_ad(self, r.grow(-10), (seed + int(_t / 3.0)) % CityBillboard.ADS, _t)

	## Fachada reventada: hollín, ventanas con fuego y humo saliendo del tejado
	## Blown-out facade: soot, windows on fire and smoke pouring off the roof
	func _draw_fire(w: float, fh: float, top: float) -> void:
		var k := minf(1.0, _burn_t * 3.0)
		draw_rect(Rect2(0, -fh, w, fh), Color(0.05, 0.03, 0.04, 0.45 * k))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 13 + 5
		for i in int(w / 70.0):
			var p := Vector2(rng.randf_range(30, w - 50), rng.randf_range(-fh + 40, -60))
			draw_rect(Rect2(p - Vector2(18, 14), Vector2(36, 28)), Color(0.02, 0.01, 0.02, k))
			var fl := 0.7 + 0.3 * sin(_t * 9.0 + i * 1.7)
			for j in 3:
				var fx := p.x - 12 + j * 12
				var h := (22.0 + 10.0 * sin(_t * 11.0 + i + j)) * fl
				draw_colored_polygon(PackedVector2Array([Vector2(fx - 8, p.y + 10), Vector2(fx + 8, p.y + 10), Vector2(fx + sin(_t * 7.0 + j) * 4.0, p.y + 10 - h)]),
					Color(1.0, 0.45 + 0.2 * j, 0.1, 0.9 * k))
		# Humo / Smoke
		for i in 6:
			var ph := fposmod(_t * 0.25 + i / 6.0, 1.0)
			var sp := Vector2(w * (0.2 + 0.6 * fposmod(i * 0.37, 1.0)) + ph * 60.0, top - ph * 260.0)
			draw_circle(sp, 30.0 + ph * 50.0, Color(0.12, 0.1, 0.12, 0.45 * (1.0 - ph) * k))

	## Tejado a dos aguas con tejas / Pitched roof with tiles
	func _pitched_roof(top: float, h: float, w: float) -> void:
		var base := _tone(_c("roof"), 0.16)
		var ridge := top + h * 0.38
		draw_rect(Rect2(0, top, w, ridge - top), base.lightened(0.12))
		draw_rect(Rect2(0, ridge, w, top + h - ridge), base.darkened(0.08))
		# Filas de tejas al tresbolillo / Staggered rows of tiles
		var y := top + 10.0
		var row := 0
		while y < top + h - 8.0:
			draw_rect(Rect2(0, y, w, 4), Color(0, 0, 0, 0.18))
			var x := 18.0 if row % 2 else 0.0
			while x < w:
				draw_rect(Rect2(x, y - 16, 4, 16), Color(0, 0, 0, 0.12))
				x += 36.0
			y += 22.0
			row += 1
		# Cumbrera y alero / Ridge and eaves
		draw_rect(Rect2(0, ridge - 6, w, 12), base.lightened(0.3))
		draw_rect(Rect2(-10, top + h - 12, w + 20, 14), base.darkened(0.35))
		draw_rect(Rect2(-10, top + h - 12, w + 20, 4), base.lightened(0.2))
		# Chimenea / Chimney
		var cx := w * (0.2 + fposmod(seed * 0.31, 0.5))
		draw_rect(Rect2(cx, top - 26, 40, 58), _tone(_c("plinth")).darkened(0.3))
		draw_rect(Rect2(cx - 5, top - 30, 50, 10), _tone(_c("plinth")).darkened(0.5))
		draw_rect(Rect2(cx, top - 26, 8, 58), Color(1, 1, 1, 0.15))

	## Azotea con pretil: tela asfáltica en placas, gravilla, manchas, y encima máquinas, placas solares,
	## helipuerto o el detalle propio de cada estética
	## Flat roof with a parapet: membrane in panels, gravel, stains, and on top machines, solar panels,
	## a helipad or each look's own detail
	func _flat_roof(top: float, h: float, w: float) -> void:
		var base := _tone(_c("flat"), 0.12)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 31 + 7
		draw_rect(Rect2(0, top, w, h), base)
		# Placas de la tela, al tresbolillo / Membrane panels, staggered
		var y := top + 16.0
		var row := 0
		while y < top + h - 16.0:
			draw_rect(Rect2(16, y, w - 32, 3), base.darkened(0.12))
			var x := 16.0 + (60.0 if row % 2 else 0.0)
			while x < w - 16.0:
				draw_rect(Rect2(x, y, 3, minf(70.0, top + h - 16.0 - y)), base.darkened(0.08))
				x += 120.0
			y += 70.0
			row += 1
		# Gravilla y manchas de agua / Gravel and water stains
		for i in int(w * h / 900.0):
			var q := Vector2(rng.randf_range(20, w - 24), rng.randf_range(top + 20, top + h - 24))
			draw_rect(Rect2(q, Vector2(4, 4)), base.lightened(0.12) if i % 2 else base.darkened(0.15))
		for i in 2:
			var q := Vector2(rng.randf_range(60, w - 60), rng.randf_range(top + 50, top + h - 50))
			draw_colored_polygon(room._ellipse(q, Vector2(rng.randf_range(30, 60), rng.randf_range(14, 24))), Color(0, 0, 0, 0.07))
		# Pretil: borde claro con cara interior en sombra / Parapet: light rim with a shaded inner face
		var lip := base.lightened(0.3)
		draw_rect(Rect2(0, top, w, 18), lip)
		draw_rect(Rect2(0, top, 18, h), lip)
		draw_rect(Rect2(w - 18, top, 18, h), lip)
		draw_rect(Rect2(0, top + h - 18, w, 18), lip.darkened(0.08))
		draw_rect(Rect2(0, top, w, 5), lip.lightened(0.25))
		draw_rect(Rect2(18, top + 18, w - 36, 12), Color(0, 0, 0, 0.22))
		draw_rect(Rect2(18, top + 18, 10, h - 36), Color(0, 0, 0, 0.15))
		# Lo que hay encima, en una rejilla para que no se pisen / What's on top, in a grid so nothing overlaps
		var inner := Rect2(40, top + 44, w - 80, h - 88)
		var cols := maxi(1, int(inner.size.x / 190.0))
		var rows := maxi(1, int(inner.size.y / 150.0))
		var cw := inner.size.x / cols
		var ch := inner.size.y / rows
		var big := kind == "apart" and cols >= 3 and rows >= 2
		for r in rows:
			for c in cols:
				var cell := Rect2(inner.position + Vector2(c * cw, r * ch), Vector2(cw, ch))
				if big and r == 0 and c == cols - 1:
					continue
				if rng.randf() < 0.3:
					continue
				var at := cell.position + Vector2(rng.randf_range(4, maxf(5, cw - 150)), rng.randf_range(4, maxf(5, ch - 110)))
				var pool: Array = ROOF_THINGS[style]
				_roof_thing(pool[rng.randi() % pool.size()], at, base, rng)
		if big:
			var hc := Vector2(inner.end.x - cw * 0.5, inner.position.y + ch * 0.5)
			var hr := minf(cw, ch) * 0.42
			match style:
				"steampunk": _big_gear(hc, hr)
				"cheese": _cheese_wedge(hc, hr)
				"solarpunk": _turbine(hc + Vector2(0, hr * 0.6), hr * 1.1)
				"dieselpunk", "noir": _mooring_mast(hc + Vector2(0, hr * 0.5), hr)
				_: _helipad(hc, hr)
		_style_roof(Rect2(0, top, w, h), base)

	## Qué hay en las azoteas de cada ciudad (0-6 comunes, 7+ propias) / What's on each city's roofs (0-6 common, 7+ its own)
	const ROOF_THINGS := {
		"synthwave": [0, 2, 7, 7, 8, 6],
		"steampunk": [2, 3, 9, 9, 10, 5],
		"cheese": [3, 11, 11, 12, 2],
		"aero": [13, 13, 14, 6, 4],
		"solarpunk": [4, 4, 15, 15, 14, 2],
		"dieselpunk": [16, 16, 17, 20, 21, 21],
		"brutalist": [18, 18, 19, 1, 3],
		"noir": [16, 16, 20, 17, 21, 0],
	}

	func _roof_thing(k: int, at: Vector2, base: Color, rng: RandomNumberGenerator) -> void:
		if k >= 20:
			_deco(k, at, base)
			return
		if k >= 7:
			_style_thing(k, at, base)
			return
		var x := at.x
		var yy := at.y
		var shade := Color(0, 0, 0, 0.25)
		match k:
			0, 1:   # aires acondicionados / AC units
				for j in (2 if k == 1 else 1):
					var o := Vector2(j * 96, 0)
					draw_rect(Rect2(at + o + Vector2(8, 58), Vector2(88, 14)), shade)
					draw_rect(Rect2(at + o, Vector2(88, 62)), Color("a6acc8"))
					draw_rect(Rect2(at + o, Vector2(88, 10)), Color("d4d8ea"))
					draw_rect(Rect2(at + o + Vector2(0, 54), Vector2(88, 8)), Color("6a708c"))
					var fc := at + o + Vector2(44, 32)
					draw_circle(fc, 20.0, Color("4a4f6a"))
					draw_circle(fc, 20.0, Color("2a2e44"), false, 3.0)
					var a := _t * 6.0 + j
					draw_line(fc - Vector2.from_angle(a) * 17, fc + Vector2.from_angle(a) * 17, Color("9aa0c0"), 4.0)
					draw_line(fc - Vector2.from_angle(a + 1.57) * 17, fc + Vector2.from_angle(a + 1.57) * 17, Color("9aa0c0"), 4.0)
			2:   # depósito de agua sobre patas / water tank on legs
				var tc := _c("accent").darkened(0.35)
				draw_colored_polygon(room._ellipse(at + Vector2(58, 100), Vector2(54, 14)), shade)
				for lx in [14.0, 50.0, 86.0]:
					draw_rect(Rect2(at + Vector2(lx, 58), Vector2(8, 40)), Color("4a3a30"))
				draw_colored_polygon(room._ellipse(at + Vector2(54, 64), Vector2(48, 16)), tc.darkened(0.2))
				draw_rect(Rect2(at + Vector2(6, 0), Vector2(96, 64)), tc)
				for b in 3:
					draw_rect(Rect2(at + Vector2(6, 14 + b * 18), Vector2(96, 4)), tc.darkened(0.3))
				draw_rect(Rect2(at + Vector2(16, 0), Vector2(10, 64)), Color(1, 1, 1, 0.15))
				draw_colored_polygon(room._ellipse(at + Vector2(54, 0), Vector2(48, 16)), tc.lightened(0.2))
				draw_colored_polygon(PackedVector2Array([at + Vector2(6, 0), at + Vector2(54, -34), at + Vector2(102, 0)]), tc.darkened(0.15))
			3:   # caseta de la escalera / stairwell hut
				draw_rect(Rect2(at + Vector2(10, 74), Vector2(116, 16)), shade)
				draw_rect(Rect2(at + Vector2(0, 0), Vector2(116, 22)), base.lightened(0.35))
				draw_rect(Rect2(at + Vector2(0, 22), Vector2(116, 62)), base.darkened(0.15))
				draw_rect(Rect2(at + Vector2(40, 36), Vector2(36, 48)), _c("edge"))
				draw_rect(Rect2(at + Vector2(44, 40), Vector2(28, 44)), _c("accent").darkened(0.5))
				draw_circle(at + Vector2(66, 62), 3.0, _c("curb"))
				draw_rect(Rect2(at + Vector2(-4, -4), Vector2(124, 8)), base.lightened(0.5))
			4:   # placas solares / solar panels
				for j in 3:
					var o := at + Vector2(j * 46, 0)
					draw_rect(Rect2(o + Vector2(6, 70), Vector2(40, 10)), shade)
					draw_rect(Rect2(o, Vector2(40, 74)), Color("c8ccd8"))
					draw_rect(Rect2(o + Vector2(3, 3), Vector2(34, 68)), Color("24306a"))
					for g in 3:
						draw_rect(Rect2(o + Vector2(3, 3 + g * 23), Vector2(34, 2)), Color("6a7ad0"))
					draw_line(o + Vector2(20, 3), o + Vector2(20, 71), Color("6a7ad0"), 2.0)
					draw_rect(Rect2(o + Vector2(6, 6), Vector2(8, 18)), Color(1, 1, 1, 0.3))
			5:   # chimeneas de ventilación / ventilation stacks
				for j in 3:
					var o := at + Vector2(j * 34, (j % 2) * 20)
					draw_colored_polygon(room._ellipse(o + Vector2(16, 56), Vector2(16, 6)), shade)
					draw_rect(Rect2(o, Vector2(28, 54)), Color("8a8ea6"))
					draw_rect(Rect2(o, Vector2(8, 54)), Color(1, 1, 1, 0.2))
					draw_rect(Rect2(o + Vector2(-5, -6), Vector2(38, 10)), Color("5a5e76"))
			6:   # claraboyas / skylights
				for j in 2:
					var o := at + Vector2(j * 70, 0)
					draw_rect(Rect2(o + Vector2(4, 54), Vector2(62, 10)), shade)
					draw_rect(Rect2(o, Vector2(62, 58)), _c("edge"))
					draw_rect(Rect2(o + Vector2(5, 5), Vector2(52, 48)), Color("8fd8ff").lerp(_c("accent"), 0.2))
					draw_line(o + Vector2(31, 5), o + Vector2(31, 53), _c("edge"), 4.0)
					draw_line(o + Vector2(10, 46), o + Vector2(26, 10), Color(1, 1, 1, 0.55), 4.0)

	func _style_thing(k: int, at: Vector2, base: Color) -> void:
		var shade := Color(0, 0, 0, 0.25)
		var acc := _c("accent")
		match k:
			7:   # antena parabólica de neón / neon satellite dish
				var c := at + Vector2(50, 40)
				draw_colored_polygon(room._ellipse(c + Vector2(6, 40), Vector2(40, 10)), shade)
				draw_line(c + Vector2(0, 40), c, Color("2a1850"), 8.0)
				draw_colored_polygon(room._ellipse(c + Vector2(0, -10), Vector2(44, 30)), Color("3a2466"))
				draw_colored_polygon(room._ellipse(c + Vector2(4, -12), Vector2(34, 22)), Color("5a3a8a"))
				var pts := room._ellipse(c + Vector2(0, -10), Vector2(44, 30))
				pts.append(pts[0])
				draw_polyline(pts, Color(_c("curb"), 0.6 + 0.4 * sin(_t * 3.0 + at.x)), 4.0)
				draw_line(c + Vector2(4, -12), c + Vector2(26, -44), Color("5ff2ff"), 3.0)
				draw_circle(c + Vector2(26, -44), 6.0, Color("5ff2ff", 0.6 + 0.4 * sin(_t * 5.0)))
			8:   # pirámide de holograma / hologram pyramid
				var c := at + Vector2(50, 70)
				draw_rect(Rect2(c + Vector2(-40, -8), Vector2(80, 18)), Color("2a1850"))
				draw_rect(Rect2(c + Vector2(-40, -8), Vector2(80, 4)), Color("5ff2ff"))
				var h := 70.0 + sin(_t * 2.0) * 6.0
				draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -8), c + Vector2(34, -8), c + Vector2(0, -8 - h)]), Color(0.37, 0.95, 1.0, 0.25))
				draw_polyline(PackedVector2Array([c + Vector2(-34, -8), c + Vector2(0, -8 - h), c + Vector2(34, -8)]), Color(1.0, 0.36, 0.63, 0.8), 3.0)
				for j in 3:
					var yy := fposmod(_t * 30.0 + j * 22.0, h)
					var hw := 34.0 * (1.0 - yy / h)
					draw_line(c + Vector2(-hw, -8 - yy), c + Vector2(hw, -8 - yy), Color(0.37, 0.95, 1.0, 0.5), 2.0)
			9:   # caldera de latón con manómetro / brass boiler with a gauge
				draw_colored_polygon(room._ellipse(at + Vector2(64, 92), Vector2(60, 12)), shade)
				draw_rect(Rect2(at + Vector2(10, 20), Vector2(110, 70)), Color("8a5a24"))
				draw_colored_polygon(room._ellipse(at + Vector2(10, 55), Vector2(16, 35)), Color("a8742a"))
				draw_colored_polygon(room._ellipse(at + Vector2(120, 55), Vector2(16, 35)), Color("c9961e"))
				for j in 4:
					draw_rect(Rect2(at + Vector2(30 + j * 24, 20), Vector2(5, 70)), Color("5a3a18"))
				draw_rect(Rect2(at + Vector2(10, 24), Vector2(110, 8)), Color(1, 0.9, 0.6, 0.3))
				draw_circle(at + Vector2(66, 10), 16.0, Color("c9961e"))
				draw_circle(at + Vector2(66, 10), 12.0, Color("f6eedc"))
				var a := -2.4 + sin(_t * 1.7) * 0.8
				draw_line(at + Vector2(66, 10), at + Vector2(66, 10) + Vector2.from_angle(a) * 10.0, Color("c83a2a"), 2.0)
				var ph := fposmod(_t * 0.8, 1.0)
				draw_circle(at + Vector2(104 + ph * 20, -2 - ph * 50), 8.0 + ph * 14.0, Color(1, 1, 1, 0.5 * (1.0 - ph)))
				draw_rect(Rect2(at + Vector2(98, -6), Vector2(12, 28)), Color("6a3a24"))
			10:   # engranajes que giran / turning gears
				_gear(at + Vector2(40, 40), 34.0, _t * 0.8, Color("c9961e"))
				_gear(at + Vector2(96, 64), 24.0, -_t * 1.13 + 0.3, Color("a8742a"))
			11:   # cuña de queso pequeña / small cheese wedge
				_cheese_wedge(at + Vector2(60, 50), 48.0)
			12:   # lata de galletas / biscuit tin
				draw_colored_polygon(room._ellipse(at + Vector2(52, 70), Vector2(50, 14)), shade)
				draw_rect(Rect2(at + Vector2(6, 20), Vector2(92, 50)), Color("c8402a"))
				draw_colored_polygon(room._ellipse(at + Vector2(52, 70), Vector2(46, 12)), Color("a83020"))
				draw_colored_polygon(room._ellipse(at + Vector2(52, 20), Vector2(46, 14)), Color("e8b468"))
				for j in 5:
					draw_circle(at + Vector2(22 + j * 15, 20), 2.5, Color("b07a3a"))
				draw_rect(Rect2(at + Vector2(6, 40), Vector2(92, 8)), Color("f2c83a"))
			13:   # burbuja de cristal con planta / glass bubble with a plant
				var c := at + Vector2(54, 50)
				draw_colored_polygon(room._ellipse(c + Vector2(6, 38), Vector2(44, 10)), shade)
				draw_colored_polygon(room._ellipse(c + Vector2(0, 30), Vector2(40, 10)), Color("2cc84a"))
				draw_circle(c + Vector2(-6, 18), 12.0, Color("3cd060"))
				draw_circle(c + Vector2(10, 14), 10.0, Color("5ae07a"))
				draw_circle(c, 44.0, Color(0.7, 0.92, 1.0, 0.35))
				draw_arc(c, 44.0, 0.0, TAU, 32, Color(1, 1, 1, 0.85), 3.0)
				draw_arc(c, 34.0, 3.6, 4.6, 12, Color(1, 1, 1, 0.9), 6.0)
				draw_circle(c + Vector2(18, -22), 5.0, Color.WHITE)
			14:   # mini aerogenerador blanco / small white wind turbine
				_turbine(at + Vector2(50, 90), 70.0)
			15:   # bancal del huerto / garden bed
				draw_rect(Rect2(at + Vector2(6, 64), Vector2(130, 12)), shade)
				draw_rect(Rect2(at, Vector2(130, 66)), Color("7a5a3a"))
				draw_rect(Rect2(at + Vector2(6, 6), Vector2(118, 54)), Color("4a3424"))
				for j in 6:
					for r in 2:
						var q := at + Vector2(18 + j * 19, 20 + r * 24)
						draw_circle(q, 9.0, Color("4fa85a").lightened(0.1 * ((j + r) % 2)))
						if (j + r) % 3 == 0:
							draw_circle(q + Vector2(2, -2), 4.0, Color("ff5a4a"))
			16:   # foco antiaéreo que barre el cielo / searchlight sweeping the sky
				var c := at + Vector2(50, 60)
				var a := -PI / 2 + sin(_t * 0.7 + at.x) * 0.7
				draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.16) * 340.0, c + Vector2.from_angle(a + 0.16) * 340.0]), Color(1.0, 0.9, 0.6, 0.1))
				draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.07) * 340.0, c + Vector2.from_angle(a + 0.07) * 340.0]), Color(1.0, 0.95, 0.75, 0.16))
				draw_colored_polygon(room._ellipse(c + Vector2(4, 22), Vector2(36, 10)), shade)
				draw_rect(Rect2(c + Vector2(-24, 0), Vector2(48, 22)), Color("3a363c"))
				draw_circle(c, 22.0, Color("58505a"))
				draw_circle(c + Vector2.from_angle(a) * 8.0, 15.0, Color("fff0c0"))
			17:   # torre de radio / radio mast
				var c := at + Vector2(50, 100)
				draw_line(c + Vector2(-24, 0), c + Vector2(0, -110), Color("1a1618"), 4.0)
				draw_line(c + Vector2(24, 0), c + Vector2(0, -110), Color("1a1618"), 4.0)
				for j in 4:
					var y := -20.0 - j * 24.0
					var hw := 24.0 * (1.0 + y / 110.0)
					draw_line(c + Vector2(-hw, y), c + Vector2(hw, y), Color("1a1618"), 3.0)
				draw_circle(c + Vector2(0, -114), 6.0, Color(1, 0.2, 0.15, 0.5 + 0.5 * sin(_t * 3.0)))
			18:   # bloque de hormigón con franja amarilla / concrete block with a yellow stripe
				draw_rect(Rect2(at + Vector2(10, 70), Vector2(110, 14)), shade)
				draw_rect(Rect2(at, Vector2(110, 76)), base.lightened(0.12))
				draw_rect(Rect2(at, Vector2(110, 14)), base.lightened(0.28))
				draw_rect(Rect2(at + Vector2(0, 64), Vector2(110, 12)), base.darkened(0.2))
				for j in 5:
					draw_colored_polygon(PackedVector2Array([at + Vector2(j * 22, 40), at + Vector2(j * 22 + 12, 40), at + Vector2(j * 22 + 22, 52), at + Vector2(j * 22 + 10, 52)]), acc)
				draw_rect(Rect2(at + Vector2(20, 22), Vector2(4, 4)), base.darkened(0.3))
				draw_rect(Rect2(at + Vector2(86, 22), Vector2(4, 4)), base.darkened(0.3))
			19:   # tiro de ventilación con rejilla / ventilation shaft with a grille
				draw_rect(Rect2(at + Vector2(8, 70), Vector2(80, 12)), shade)
				draw_rect(Rect2(at, Vector2(80, 74)), base.darkened(0.08))
				draw_rect(Rect2(at + Vector2(10, 10), Vector2(60, 46)), Color("1e2026"))
				for j in 5:
					draw_rect(Rect2(at + Vector2(10, 14 + j * 9), Vector2(60, 3)), base.lightened(0.1))
				draw_rect(Rect2(at + Vector2(0, 62), Vector2(80, 6)), acc)

	func _deco(k: int, at: Vector2, base: Color) -> void:
		var gold := Color("e0b53a")
		var shade := Color(0, 0, 0, 0.25)
		if k == 20:   # aguja art déco escalonada / stepped art deco spire
			var c := at + Vector2(60, 100)
			draw_colored_polygon(room._ellipse(c + Vector2(10, 4), Vector2(56, 12)), shade)
			for j in 4:
				var hw := 50.0 - j * 11.0
				var y := -j * 28.0
				draw_rect(Rect2(c + Vector2(-hw, y - 28), Vector2(hw * 2, 28)), base.lightened(0.1 + j * 0.06))
				draw_rect(Rect2(c + Vector2(-hw, y - 28), Vector2(hw * 2, 4)), gold)
				draw_rect(Rect2(c + Vector2(-hw, y - 28), Vector2(6, 28)), Color(1, 1, 1, 0.12))
			draw_line(c + Vector2(0, -112), c + Vector2(0, -170), gold, 5.0)
			draw_circle(c + Vector2(0, -172), 6.0, Color(1, 0.3, 0.2, 0.5 + 0.5 * sin(_t * 2.5 + at.x)))
		else:   # depósito remachado sobre patas / riveted tank on legs
			var c := at + Vector2(56, 40)
			draw_colored_polygon(room._ellipse(c + Vector2(8, 64), Vector2(50, 12)), shade)
			for lx in [-34.0, 0.0, 34.0]:
				draw_line(c + Vector2(lx, 30), c + Vector2(lx * 1.2, 62), Color("2a2220"), 6.0)
			draw_line(c + Vector2(-40, 50), c + Vector2(40, 50), Color("2a2220"), 3.0)
			draw_rect(Rect2(c + Vector2(-42, -26), Vector2(84, 58)), Color("6a3a2a"))
			draw_colored_polygon(room._ellipse(c + Vector2(0, 32), Vector2(42, 10)), Color("5a2e22"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-46, -26), c + Vector2(46, -26), c + Vector2(0, -56)]), Color("4a2a20"))
			for j in 3:
				for i in 7:
					draw_circle(c + Vector2(-36 + i * 12, -16 + j * 20), 2.0, Color("a8745a"))
			draw_rect(Rect2(c + Vector2(-42, -4), Vector2(84, 10)), gold.darkened(0.2))
			draw_rect(Rect2(c + Vector2(-34, -26), Vector2(8, 58)), Color(1, 1, 1, 0.12))

	## Mástil de amarre de zepelines, con su baliza / Zeppelin mooring mast, with its beacon
	func _mooring_mast(base_p: Vector2, r: float) -> void:
		var gold := Color("e0b53a")
		var h := r * 2.4
		draw_colored_polygon(room._ellipse(base_p + Vector2(10, 6), Vector2(r * 0.8, r * 0.22)), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(base_p + Vector2(-r * 0.6, -16), Vector2(r * 1.2, 20)), Color("3a3230"))
		draw_rect(Rect2(base_p + Vector2(-r * 0.6, -16), Vector2(r * 1.2, 4)), gold)
		for side in [-1.0, 1.0]:
			draw_line(base_p + Vector2(side * r * 0.45, -16), base_p + Vector2(side * 8.0, -h), Color("2a2220"), 6.0)
		for j in 6:
			var y := -16.0 - (h - 16.0) * (j + 1) / 7.0
			var hw := lerpf(r * 0.45, 8.0, (j + 1) / 7.0)
			draw_line(base_p + Vector2(-hw, y), base_p + Vector2(hw, y), Color("2a2220"), 3.0)
			draw_line(base_p + Vector2(-hw, y), base_p + Vector2(hw * 0.8, y - 14), Color("2a2220"), 2.0)
		draw_circle(base_p + Vector2(0, -h), 14.0, gold)
		draw_circle(base_p + Vector2(0, -h - 4), 8.0, Color(1, 0.3, 0.2, 0.5 + 0.5 * sin(_t * 3.0)))
		draw_circle(base_p + Vector2(0, -h - 4), 26.0 * (0.5 + 0.5 * sin(_t * 3.0)), Color(1, 0.3, 0.2, 0.12))

	func _gear(c: Vector2, r: float, a: float, col: Color) -> void:
		draw_colored_polygon(room._ellipse(c + Vector2(6, r * 0.8), Vector2(r, r * 0.3)), Color(0, 0, 0, 0.2))
		for j in 10:
			var d := Vector2.from_angle(a + TAU * j / 10.0)
			draw_line(c + d * r * 0.8, c + d * (r + 8.0), col, 10.0)
		draw_circle(c, r, col)
		draw_circle(c, r * 0.72, col.darkened(0.2))
		draw_circle(c, r * 0.3, col.lightened(0.3))
		for j in 4:
			var d := Vector2.from_angle(a + TAU * j / 4.0)
			draw_line(c + d * r * 0.3, c + d * r * 0.72, col, 6.0)

	func _big_gear(c: Vector2, r: float) -> void:
		_gear(c, r, _t * 0.4, Color("c9961e"))
		_gear(c + Vector2(r * 1.05, r * 0.6), r * 0.45, -_t * 0.9, Color("a8742a"))

	func _cheese_wedge(c: Vector2, r: float) -> void:
		var top := PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, -r * 0.2), c + Vector2(r * 0.2, -r * 0.7)])
		draw_colored_polygon(room._ellipse(c + Vector2(8, r * 0.5), Vector2(r * 1.1, r * 0.25)), Color(0, 0, 0, 0.22))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, -r * 0.2), c + Vector2(r, r * 0.3), c + Vector2(-r, r * 0.5)]), Color("f0a828"))
		draw_colored_polygon(top, Color("ffd85a"))
		draw_polyline(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, -r * 0.2), c + Vector2(r, r * 0.3), c + Vector2(-r, r * 0.5), c + Vector2(-r, 0), c + Vector2(r * 0.2, -r * 0.7), c + Vector2(r, -r * 0.2)]), Color("8a5a10"), 3.0)
		for q in [Vector2(-0.5, 0.2), Vector2(0.3, 0.12), Vector2(0.7, 0.05)]:
			draw_colored_polygon(room._ellipse(c + q * r, Vector2(r * 0.12, r * 0.09)), Color("c8801a"))

	func _turbine(base_p: Vector2, h: float) -> void:
		draw_colored_polygon(room._ellipse(base_p + Vector2(8, 4), Vector2(h * 0.3, h * 0.08)), Color(0, 0, 0, 0.22))
		draw_line(base_p, base_p + Vector2(0, -h), Color("e8eef4"), 7.0)
		draw_line(base_p, base_p + Vector2(0, -h), Color("b8c4d0"), 2.0)
		var hub := base_p + Vector2(0, -h)
		for j in 3:
			var d := Vector2.from_angle(_t * 2.0 + TAU * j / 3.0)
			draw_colored_polygon(PackedVector2Array([hub, hub + d * h * 0.55 + d.orthogonal() * 6.0, hub + d * h * 0.6]), Color.WHITE)
		draw_circle(hub, 7.0, Color("d8e0e8"))

	func _helipad(c: Vector2, r: float) -> void:
		draw_colored_polygon(room._ellipse(c + Vector2(0, 8), Vector2(r, r * 0.8)), Color(0, 0, 0, 0.2))
		draw_colored_polygon(room._ellipse(c, Vector2(r, r * 0.8)), Color("3a3a48"))
		var pts := room._ellipse(c, Vector2(r - 8, r * 0.8 - 7))
		pts.append(pts[0])
		draw_polyline(pts, Color("f0e060"), 5.0)
		var hw := r * 0.32
		var hh := r * 0.42
		for x in [-hw, hw - 12.0]:
			draw_rect(Rect2(c + Vector2(x, -hh), Vector2(12, hh * 2)), Color.WHITE)
		draw_rect(Rect2(c + Vector2(-hw, -6), Vector2(hw * 2, 12)), Color.WHITE)
		for k in 8:
			var a := TAU * k / 8.0 + 0.4
			draw_circle(c + Vector2(cos(a) * (r - 4), sin(a) * (r * 0.8 - 4)), 4.0, Color(_c("accent"), 0.5 + 0.5 * sin(_t * 4.0 + k)))

	## El detalle propio de cada ciudad en la azotea / Each city's own rooftop detail
	func _style_roof(r: Rect2, base: Color) -> void:
		var p := r.position + Vector2(r.size.x * (0.25 + fposmod(seed * 0.23, 0.5)), 60)
		match style:
			"noir":   # rótulo de neón rojo en la azotea, que parpadea / red neon rooftop sign, flickering
				var on := 0.25 if fmod(_t + seed * 0.7, 5.0) < 0.12 else 1.0
				draw_rect(Rect2(p + Vector2(-100, -66), Vector2(200, 60)), Color("0e0e12"))
				for k in 6:
					draw_rect(Rect2(p + Vector2(-86 + k * 30, -54), Vector2(20, 36)), Color("e0303a", on))
					draw_rect(Rect2(p + Vector2(-82 + k * 30, -50), Vector2(12, 6)), Color(1, 0.7, 0.7, on))
				draw_line(p + Vector2(-80, -6), p + Vector2(-80, 30), Color("0e0e12"), 6.0)
				draw_line(p + Vector2(80, -6), p + Vector2(80, 30), Color("0e0e12"), 6.0)
				draw_texture_rect(DreamBackground.soft_texture(), Rect2(p + Vector2(-140, -110), Vector2(280, 150)), false, Color("e0303a", 0.18 * on))
			"synthwave":   # valla de neón / neon billboard
				draw_rect(Rect2(p + Vector2(-80, -60), Vector2(160, 70)), _c("edge"))
				draw_rect(Rect2(p + Vector2(-74, -54), Vector2(148, 58)), Color("2a0a3a"))
				var g := 0.6 + 0.4 * sin(_t * 5.0 + seed)
				draw_arc(p + Vector2(0, -6), 26.0, PI, TAU, 16, Color(_c("sign"), g), 5.0)
				for k in 4:
					draw_line(p + Vector2(-60, -14 + k * 5), p + Vector2(60, -14 + k * 5), Color(_c("accent"), g * 0.8), 2.0)
				draw_line(p + Vector2(-60, 10), p + Vector2(-60, 30), _c("edge"), 6.0)
				draw_line(p + Vector2(60, 10), p + Vector2(60, 30), _c("edge"), 6.0)
			"steampunk":   # tubos de latón y chimenea con humo / brass pipes and a smoking chimney
				draw_line(r.position + Vector2(30, r.size.y - 50), r.position + Vector2(r.size.x - 30, r.size.y - 50), Color("c9961e"), 10.0)
				draw_line(r.position + Vector2(30, r.size.y - 50), r.position + Vector2(r.size.x - 30, r.size.y - 50), Color("f0c860"), 3.0)
				draw_rect(Rect2(p + Vector2(-20, -70), Vector2(40, 90)), Color("6a3a24"))
				draw_rect(Rect2(p + Vector2(-26, -78), Vector2(52, 12)), Color("c9961e"))
				for k in 4:
					var ph := fposmod(_t * 0.5 + k * 0.25, 1.0)
					draw_circle(p + Vector2(ph * 50.0, -90 - ph * 90.0), 14.0 + ph * 18.0, Color(0.85, 0.82, 0.8, 0.45 * (1.0 - ph)))
			"cheese":   # agujeros de queso / cheese holes
				var rng := RandomNumberGenerator.new()
				rng.seed = seed
				for k in 5:
					var q := Vector2(rng.randf_range(r.position.x + 50, r.end.x - 50), rng.randf_range(r.position.y + 50, r.end.y - 50))
					var rad := rng.randf_range(14, 30)
					draw_colored_polygon(room._ellipse(q, Vector2(rad, rad * 0.75)), base.darkened(0.3))
					draw_colored_polygon(room._ellipse(q + Vector2(0, 3), Vector2(rad * 0.8, rad * 0.55)), base.darkened(0.45))
			"aero":   # cúpula de cristal / glass dome
				draw_colored_polygon(room._ellipse(p + Vector2(6, 20), Vector2(70, 22)), Color(0, 0, 0, 0.15))
				draw_colored_polygon(room._ellipse(p, Vector2(64, 52)), Color(0.6, 0.9, 1.0, 0.55))
				draw_arc(p, 64.0, PI, TAU, 24, Color(1, 1, 1, 0.8), 3.0)
				draw_rect(Rect2(p + Vector2(-30, -36), Vector2(16, 30)), Color(1, 1, 1, 0.6))
			"solarpunk":   # huerto en la azotea / rooftop garden
				for k in 2:
					var o := r.position + Vector2(40 + k * (r.size.x - 200), r.size.y - 110)
					draw_rect(Rect2(o, Vector2(120, 56)), Color("7a5a3a"))
					draw_rect(Rect2(o + Vector2(6, 6), Vector2(108, 44)), Color("4a3a24"))
					for j in 5:
						draw_circle(o + Vector2(18 + j * 21, 22), 11.0, Color("4fa85a").lightened(0.1 * (j % 2)))
						draw_circle(o + Vector2(18 + j * 21, 18), 3.0, Color("ffd060") if j % 2 else Color("ff7a9a"))
			"dieselpunk":   # chimenea de fábrica / factory stack
				draw_rect(Rect2(p + Vector2(-24, -120), Vector2(48, 150)), Color("5a2a24"))
				for k in 4:
					draw_rect(Rect2(p + Vector2(-24, -100 + k * 30), Vector2(48, 4)), Color("3a1a14"))
				draw_rect(Rect2(p + Vector2(-30, -128), Vector2(60, 12)), Color("2a2224"))
				for k in 4:
					var ph := fposmod(_t * 0.4 + k * 0.25, 1.0)
					draw_circle(p + Vector2(ph * 40.0, -140 - ph * 110.0), 16.0 + ph * 24.0, Color(0.2, 0.18, 0.2, 0.5 * (1.0 - ph)))
			"brutalist":   # bloques de hormigón / concrete blocks
				for k in 3:
					var o := p + Vector2(-90 + k * 64, -30 + (k % 2) * 30)
					draw_rect(Rect2(o + Vector2(8, 50), Vector2(56, 12)), Color(0, 0, 0, 0.25))
					draw_rect(Rect2(o, Vector2(56, 56)), base.lightened(0.15))
					draw_rect(Rect2(o, Vector2(56, 10)), base.lightened(0.3))
					draw_rect(Rect2(o + Vector2(0, 46), Vector2(56, 10)), base.darkened(0.2))

	## Cartel luminoso de la tienda, con su "nombre" en bloques de píxeles / The shop's lit sign, with its "name" in pixel blocks
	func _shop_sign(w: float, fh: float) -> void:
		var sw := minf(w - 60.0, 360.0)
		var r := Rect2(w / 2.0 - sw / 2.0, -fh + 20.0, sw, 52.0)
		draw_rect(r.grow(6), _c("edge"))
		draw_rect(r, _c("sign"))
		var glow := 0.75 + 0.25 * sin(_t * 3.0 + seed)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var x := r.position.x + 18.0
		while x < r.end.x - 30.0:
			var lw := rng.randf_range(10.0, 22.0)
			draw_rect(Rect2(x, r.position.y + 14, lw, 24), Color(_c("accent").lightened(0.3), glow))
			x += lw + 8.0
			if rng.randf() < 0.2:
				x += 14.0

	## La torre de los sueños: remate escalonado, antena con baliza y cartel de estrellas
	## The dream tower: stepped crown, antenna with a beacon and a sign of stars
	func _tower_crown(w: float, fh: float, top: float) -> void:
		var base := _tone(_c("flat"))
		var inner := Rect2(w * 0.2, top + 40, w * 0.6, 140)
		draw_rect(Rect2(inner.position + Vector2(10, inner.size.y), Vector2(inner.size.x, 14)), Color(0, 0, 0, 0.3))
		draw_rect(inner, base.lightened(0.2))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 14)), base.lightened(0.4))
		var ant := Vector2(w / 2.0, inner.position.y + 40)
		draw_line(ant, ant + Vector2(0, -180), _c("edge"), 8.0)
		draw_line(ant + Vector2(-30, -110), ant + Vector2(30, -110), _c("edge"), 5.0)
		var blink := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(ant + Vector2(0, -186), 12.0, Color(_c("accent"), 0.5 + 0.5 * blink))
		draw_circle(ant + Vector2(0, -186), 28.0 * blink, Color(_c("accent"), 0.15))
		var c := Vector2(w / 2.0, -fh - 60.0)
		draw_rect(Rect2(c - Vector2(160, 36), Vector2(320, 72)), _c("edge"))
		draw_rect(Rect2(c - Vector2(152, 28), Vector2(304, 56)), _c("sign"))
		for i in 5:
			DreamBackground.draw_star(self, c + Vector2(-110 + i * 55, sin(_t * 2.0 + i) * 4.0), 13.0, Color(UITheme.GOLD, 0.7 + 0.3 * sin(_t * 3.0 + i)))

	## Dibuja un trozo del sprite (para no estirarlo al final del edificio) / Draws part of the sprite (so it isn't stretched at the building's end)
	func _draw_part(sprite: String, dst: Rect2, mod: Color) -> void:
		var tex := Sprites.tex(sprite)
		var r: Rect2 = SpriteRects.RECTS[sprite]
		var src := Rect2(0, 0, tex.get_width() * dst.size.x / r.size.x, tex.get_height() * dst.size.y / r.size.y)
		draw_texture_rect_region(tex, dst, src, mod)


## Ambiente de cada ciudad por encima de todo: neblina de su color y partículas (neón, humo, migas
## de queso, burbujas, pétalos, ascuas o lluvia)
## Each city's ambience over everything: haze in its colour and particles (neon, smoke, cheese
## crumbs, bubbles, petals, embers or rain)
class CityAmbience extends Node2D:
	var room: Act4Room
	var _t := 0.0
	var _p: Array[Vector4] = []   # x, y, fase, tamaño / x, y, phase, size
	const N := 70
	const BOX := Vector2(2900, 1700)

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in N:
			_p.append(Vector4(rng.randf() * BOX.x, rng.randf() * BOX.y, rng.randf() * TAU, rng.randf_range(0.6, 1.4)))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var view := room._view_canvas()
		var haze := room.look("haze")
		draw_rect(view.grow(40), Color(haze, 0.06))
		if room.style == "noir":
			# Relámpago de vez en cuando / Lightning now and then
			var fl := fmod(_t, 9.0)
			if fl < 0.08 or (fl > 0.16 and fl < 0.22):
				draw_rect(view.grow(40), Color(1, 1, 1, 0.22))
		if room.style == "dieselpunk" or room.style == "noir":
			# La sombra de un zepelín que cruza despacio la ciudad / A zeppelin's shadow slowly crossing the city
			var zx := fposmod(_t * 60.0, MAP_SIZE.x + 1600.0) - 800.0
			var zc := Vector2(zx, MAP_SIZE.y * 0.45 + sin(_t * 0.05) * 600.0)
			draw_colored_polygon(room._ellipse(zc, Vector2(420, 120)), Color(0.05, 0.02, 0.0, 0.18))
			draw_colored_polygon(PackedVector2Array([zc + Vector2(-380, 0), zc + Vector2(-520, -90), zc + Vector2(-500, 90)]), Color(0.05, 0.02, 0.0, 0.18))
			draw_rect(Rect2(zc + Vector2(-60, 90), Vector2(120, 40)), Color(0.05, 0.02, 0.0, 0.14))
		var vel := Vector2.ZERO
		match room.style:
			"synthwave", "aero": vel = Vector2(6, -40)
			"steampunk": vel = Vector2(30, -14)
			"dieselpunk": vel = Vector2(14, -50)
			"cheese", "solarpunk": vel = Vector2(16, 34)
			"brutalist", "noir": vel = Vector2(-140, 620)
		for i in N:
			var q := _p[i]
			var pos := Vector2(q.x, q.y) + vel * _t * q.w + Vector2(sin(_t * 0.8 + q.z) * 30.0, 0)
			pos = Vector2(fposmod(pos.x - view.position.x, BOX.x), fposmod(pos.y - view.position.y, BOX.y)) + view.position - (BOX - view.size) * 0.5
			var tw := 0.5 + 0.5 * sin(_t * 2.0 + q.z)
			match room.style:
				"synthwave":
					var col := room.look("curb") if i % 2 else room.look("accent")
					draw_rect(Rect2(pos, Vector2(7, 7) * q.w), Color(col, 0.35 + 0.4 * tw))
				"steampunk":
					draw_circle(pos, 18.0 * q.w, Color(0.9, 0.85, 0.78, 0.08 + 0.06 * tw))
					if i % 6 == 0:
						draw_rect(Rect2(pos, Vector2(4, 4)), Color(1.0, 0.75, 0.3, 0.6 * tw))
				"cheese":
					draw_rect(Rect2(pos, Vector2(8, 6) * q.w), Color(1.0, 0.85, 0.3, 0.6))
				"aero":
					var br := (10.0 + 10.0 * float(i % 3)) * q.w
					draw_circle(pos, br, Color(0.75, 0.95, 1.0, 0.12))
					draw_arc(pos, br, 0, TAU, 18, Color(1, 1, 1, 0.6), 2.0)
					draw_arc(pos, br * 0.7, 3.6, 4.6, 8, Color(1, 1, 1, 0.8), 3.0)
				"solarpunk":
					draw_set_transform(pos, _t * 1.5 + q.z, Vector2.ONE)
					draw_colored_polygon(room._ellipse(Vector2.ZERO, Vector2(7, 4) * q.w), Color("ffb0c8") if i % 3 else Color("fff8e0"))
					draw_set_transform(Vector2.ZERO)
				"dieselpunk":
					draw_rect(Rect2(pos, Vector2(5, 5) * q.w), Color(1.0, 0.55, 0.2, 0.3 + 0.5 * tw) if i % 3 else Color(0.5, 0.48, 0.5, 0.4))
				"brutalist":
					draw_line(pos, pos + Vector2(-6, 34) * q.w, Color(0.75, 0.8, 0.9, 0.35), 2.0)
				"noir":
					# Lluvia fuerte, con salpicones / Heavy rain, with splashes
					draw_line(pos, pos + Vector2(-8, 46) * q.w, Color(0.8, 0.82, 0.9, 0.4), 2.0)
					draw_line(pos + Vector2(140, 300), pos + Vector2(132, 346) * Vector2(1, 1), Color(0.8, 0.82, 0.9, 0.3), 2.0)
