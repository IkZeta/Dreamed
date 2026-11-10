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

## La calzada de cada ciudad: asfalto, marcas y bordillo / Each city's roadway: asphalt, markings and kerb
const ROAD := {
	"synthwave": {"road": "1a1030", "line": "5ff2ff", "glow": true},
	"steampunk": {"road": "4a3a30", "line": "c9961e", "rails": true},
	"cheese": {"road": "c8783a", "line": "fff6e0"},
	"aero": {"road": "5a9ac8", "line": "ffffff", "glow": true},
	"solarpunk": {"road": "8a9a78", "line": "f6e2a0", "median": true},
	"dieselpunk": {"road": "2a2624", "line": "e0b53a"},
	"brutalist": {"road": "5e5c58", "line": "f2f2ea"},
	"noir": {"road": "121216", "line": "d8d0c0", "wet": true},
}
## Avenidas con coches (columnas/filas de baldosa); en medio, la plaza
## Avenues with cars (tile columns/rows); in the middle, the plaza
const ROAD_H := Rect2i(2, 13, 40, 4)
const ROAD_V := Rect2i(19, 2, 6, 26)
const PLAZA_CORE := Rect2i(16, 10, 12, 10)
## Pasos de cebra: en la avenida horizontal (columnas) y en la vertical (filas)
## Zebra crossings: on the horizontal avenue (columns) and on the vertical one (rows)
const CROSS_COLS := [9, 15, 28, 34]
const CROSS_ROWS := [9, 20, 25]
## Estéticas de noche: farolas y ventanas iluminan el suelo / Night looks: lamps and windows light the ground
const NIGHT := ["synthwave", "steampunk", "dieselpunk", "noir"]
## Coches aparcados: [x en baldosas, lado (0 arriba, 1 abajo), variante] / Parked cars: [x in tiles, side (0 top, 1 bottom), variant]
var parked: Array = []

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
	# Coches aparcados junto al bordillo, lejos de agujeros y pasos de cebra
	# Cars parked by the kerb, away from holes and zebra crossings
	var crng := RandomNumberGenerator.new()
	crng.seed = hash(style) + 31
	for side in 2:
		var x := float(ROAD_H.position.x) + 0.8
		while x < ROAD_H.end.x - 1.0:
			var ok := not (x > PLAZA_CORE.position.x - 1.6 and x < PLAZA_CORE.end.x + 0.6)
			for cc: int in CROSS_COLS:
				if absf(x - (cc + 0.5)) < 1.6:
					ok = false
			var row := ROAD_H.position.y + (0 if side == 0 else ROAD_H.size.y - 1)
			for h: Vector2i in CityLayout.HOLES:
				if h.y == row and absf(x - (h.x + 0.5)) < 1.8:
					ok = false
			if ok and crng.randf() < 0.42:
				parked.append([x, side, crng.randi() % 2])
				var cy := (row + (0.62 if side == 0 else 0.78)) * T
				_static.append(Rect2(Vector2(x * T - 80.0, cy - 34.0), Vector2(160, 40)))
				x += 2.2
			else:
				x += 1.0
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
	# En el último sueño, nada de rascacielos cerca de donde Kroker se apoya y llega Evil Ad
	# In the last dream, no skyscrapers near where Kroker leans and Evil Ad arrives
	var lean := lean_spot() if style == "noir" else Vector2.INF
	for r in CityLayout.ROWS:
		for c in CityLayout.COLS:
			if not CityLayout.MAP[r][c] in [".", ":"] or is_road(c, r):
				continue
			var foot := (Vector2(c, r) + Vector2(0.5, 0.5)) * T
			if foot.distance_to(start) < 520.0 or FOUNTAIN.grow(200.0).has_point(foot):
				continue
			if lean != Vector2.INF and (foot.distance_to(lean) < 900.0 or foot.distance_to(lean + Vector2(500, 55)) < 900.0):
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
			if is_road(c, r):
				_draw_road_tile(c, r)
				continue
			# Variación de tono suave y a gran escala (nada de baldosas sueltas más claras u oscuras)
			# Soft, large-scale tone variation (no odd lighter or darker tiles)
			var v := 1.0 + 0.025 * sin(c * 0.55 + r * 0.31) * cos(r * 0.47 - c * 0.18)
			Sprites.draw(self, _tile(kind), Color(v, v, v), Vector2(c, r) * T)
	# 2) Dibujo de la plaza alrededor de la fuente y marcas de la calzada
	# 2) Plaza pattern round the fountain and road markings
	_draw_plaza_rings()
	_draw_road_marks(view)
	# 3) Bordes: césped con bordillo, agua con piedra / Edges: grass with a kerb, water with stone
	for r in range(r0, r1 + 1):
		var row: String = CityLayout.MAP[r]
		for c in range(c0, c1 + 1):
			var ch := row[c]
			var p := Vector2(c, r) * T
			if ch == "W" and (FOUNTAIN.has_point(p + Vector2(1, 1)) or POND.has_point(p + Vector2(1, 1))):
				continue
			if is_road(c, r):
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
	if style in NIGHT:
		_draw_lamp_light(r0, r1, c0, c1)
	if POND.grow(T).intersects(view):
		_draw_pond()
	_draw_fountain()
	_draw_holes()
	draw_set_transform(Vector2.ZERO)


## ¿Es calzada? Los brazos de las avenidas, fuera de la plaza central y de los edificios
## Is it roadway? The avenue arms, outside the central plaza and the buildings
func is_road(c: int, r: int) -> bool:
	var q := Vector2i(c, r)
	if not (ROAD_H.has_point(q) or ROAD_V.has_point(q)) or PLAZA_CORE.has_point(q):
		return false
	return CityLayout.MAP[r][c] in [":", "o"]


func _road(key: String) -> Variant:
	return ROAD[style].get(key, false)


## Una baldosa de asfalto con su grano, parches y alguna grieta / An asphalt tile with its grain, patches and the odd crack
func _draw_road_tile(c: int, r: int) -> void:
	var p := Vector2(c, r) * T
	var base := Color(_road("road"))
	var v := 1.0 + 0.04 * sin(c * 0.9 + r * 0.4)
	draw_rect(Rect2(p, Vector2(T, T)), Color(base.r * v, base.g * v, base.b * v))
	var h := _hash(c, r)
	if style == "steampunk":
		# Adoquines grandes / Big setts
		for yy in 5:
			var off := 12.0 if yy % 2 else 0.0
			for xx in 5:
				var q := p + Vector2(off + xx * 25.0 - 6.0, yy * 25.0)
				var k := 0.9 + float((h + xx * 7 + yy * 13) % 5) * 0.05
				draw_rect(Rect2(q + Vector2(1, 1), Vector2(22, 22)), Color(base.r * k * 1.25, base.g * k * 1.25, base.b * k * 1.25))
		return
	if style == "cheese":
		# Caramelo con burbujitas / Caramel with little bubbles
		for k in 3:
			var q := p + Vector2(15 + (h * (k + 3)) % 95, 15 + (h * (k + 5)) % 95)
			draw_colored_polygon(_ellipse(q, Vector2(7, 5)), base.lightened(0.18))
			draw_rect(Rect2(q + Vector2(-3, -3), Vector2(3, 2)), Color(1, 1, 1, 0.5))
		return
	# Grano del asfalto / Asphalt grain
	for k in 9:
		var q := p + Vector2((h * (k + 2) * 7) % 120, (h * (k + 5) * 11) % 120)
		draw_rect(Rect2(q, Vector2(4, 4)), base.lightened(0.1) if k % 2 else base.darkened(0.15))
	match h % 17:
		0:   # parche / patch
			draw_rect(Rect2(p + Vector2(20, 30), Vector2(70, 46)), base.darkened(0.05))
			draw_rect(Rect2(p + Vector2(20, 30), Vector2(70, 46)), base.darkened(0.12), false, 2.0)
		5:   # grieta / crack
			var q := p + Vector2(30, 40)
			draw_polyline(PackedVector2Array([q, q + Vector2(16, 10), q + Vector2(24, 30), q + Vector2(46, 36)]), base.darkened(0.35), 3.0)
		9:   # mancha de aceite / oil stain
			draw_colored_polygon(_ellipse(p + Vector2(60, 64), Vector2(30, 14)), Color(0, 0, 0, 0.18))
			if style == "noir" or style == "synthwave":
				draw_rect(Rect2(p + Vector2(46, 58), Vector2(16, 3)), Color(Color(_road("line")), 0.35))


## Marcas de la calzada: bordillos, líneas, pasos de cebra; raíles en la ciudad steampunk y
## mediana con césped en la solarpunk / Road markings: kerbs, lines, zebra crossings; rails in the
## steampunk city and a grassy median in the solarpunk one
func _draw_road_marks(view: Rect2) -> void:
	var line := Color(_road("line"))
	var curb := look("curb")
	var glow: bool = _road("glow")
	var h0 := Vector2(ROAD_H.position) * T
	var h1 := Vector2(ROAD_H.end) * T
	var v0 := Vector2(ROAD_V.position) * T
	var v1 := Vector2(ROAD_V.end) * T
	var core0 := Vector2(PLAZA_CORE.position) * T
	var core1 := Vector2(PLAZA_CORE.end) * T
	# Tramos: [desde, hasta] de la avenida horizontal (x) y de la vertical (y)
	# Stretches: [from, to] of the horizontal avenue (x) and of the vertical one (y)
	var hs := [[h0.x, core0.x], [core1.x, h1.x]]
	var vs := [[v0.y, core0.y], [core1.y, v1.y]]
	var hw := h1.y - h0.y
	var vw := v1.x - v0.x
	# Bordillos con su sombra / Kerbs with their shadow
	for st: Array in hs:
		for y in [h0.y, h1.y]:
			draw_rect(Rect2(Vector2(st[0], y - 7), Vector2(st[1] - st[0], 14)), curb)
			draw_rect(Rect2(Vector2(st[0], y + (7 if y == h0.y else -13)), Vector2(st[1] - st[0], 6)), Color(0, 0, 0, 0.25))
	for st: Array in vs:
		for x in [v0.x, v1.x]:
			draw_rect(Rect2(Vector2(x - 7, st[0]), Vector2(14, st[1] - st[0])), curb)
			draw_rect(Rect2(Vector2(x + (7 if x == v0.x else -13), st[0]), Vector2(6, st[1] - st[0])), Color(0, 0, 0, 0.25))
	var cy := h0.y + hw / 2.0
	var cx := v0.x + vw / 2.0
	if _road("rails"):
		# Raíles del tranvía con traviesas / Tram rails with sleepers
		for st: Array in hs:
			for ry in [cy - 70.0, cy + 70.0]:
				var x := float(st[0])
				while x < float(st[1]):
					draw_rect(Rect2(Vector2(x, ry - 22), Vector2(14, 44)), Color("3a2a20"))
					x += 34.0
				for o in [-16.0, 16.0]:
					draw_rect(Rect2(Vector2(st[0], ry + o - 3), Vector2(st[1] - st[0], 6)), Color("8a8078"))
					draw_rect(Rect2(Vector2(st[0], ry + o - 3), Vector2(st[1] - st[0], 2)), Color("d8d0c0"))
		for st: Array in vs:
			for rx in [cx - 110.0, cx + 110.0]:
				var y := float(st[0])
				while y < float(st[1]):
					draw_rect(Rect2(Vector2(rx - 22, y), Vector2(44, 14)), Color("3a2a20"))
					y += 34.0
				for o in [-16.0, 16.0]:
					draw_rect(Rect2(Vector2(rx + o - 3, st[0]), Vector2(6, st[1] - st[0])), Color("8a8078"))
	elif _road("median"):
		# Mediana con césped y flores / Grassy median with flowers
		for st: Array in hs:
			draw_rect(Rect2(Vector2(st[0], cy - 22), Vector2(st[1] - st[0], 44)), curb)
			draw_rect(Rect2(Vector2(st[0], cy - 16), Vector2(st[1] - st[0], 32)), Color("5fb86a"))
			var x := float(st[0]) + 30.0
			while x < float(st[1]) - 20.0:
				draw_circle(Vector2(x, cy - 2), 9.0, Color("3f9a4a"))
				draw_circle(Vector2(x + 2, cy - 6), 3.0, Color("ffd060") if int(x) % 3 else Color("ff8fb0"))
				x += 46.0
		for st: Array in vs:
			draw_rect(Rect2(Vector2(cx - 30, st[0]), Vector2(60, st[1] - st[0])), curb)
			draw_rect(Rect2(Vector2(cx - 24, st[0]), Vector2(48, st[1] - st[0])), Color("5fb86a"))
			var y := float(st[0]) + 40.0
			while y < float(st[1]) - 30.0:
				draw_circle(Vector2(cx, y), 14.0, Color("3f9a4a"))
				draw_circle(Vector2(cx - 4, y - 4), 5.0, Color("7fcf7a"))
				y += 80.0
		# Carril bici / Bike lane
		for st: Array in hs:
			draw_rect(Rect2(Vector2(st[0], h1.y - 70), Vector2(st[1] - st[0], 50)), Color(0.35, 0.65, 0.4, 0.35))
	else:
		# Doble línea en medio y discontinuas entre carriles / Double centre line and dashes between lanes
		for st: Array in hs:
			_line(Vector2(st[0], cy - 9), Vector2(st[1], cy - 9), line, 6.0, glow)
			_line(Vector2(st[0], cy + 9), Vector2(st[1], cy + 9), line, 6.0, glow)
			for ly in [h0.y + hw * 0.25, h0.y + hw * 0.75]:
				var x := float(st[0]) + 20.0
				while x < float(st[1]) - 40.0:
					_line(Vector2(x, ly), Vector2(x + 50.0, ly), Color(line, 0.8), 5.0, glow)
					x += 100.0
		for st: Array in vs:
			_line(Vector2(cx - 9, st[0]), Vector2(cx - 9, st[1]), line, 6.0, glow)
			_line(Vector2(cx + 9, st[0]), Vector2(cx + 9, st[1]), line, 6.0, glow)
			for lx in [v0.x + vw / 6.0, v0.x + vw * 2.0 / 6.0, v0.x + vw * 4.0 / 6.0, v0.x + vw * 5.0 / 6.0]:
				var y := float(st[0]) + 20.0
				while y < float(st[1]) - 40.0:
					_line(Vector2(lx, y), Vector2(lx, y + 50.0), Color(line, 0.8), 5.0, glow)
					y += 100.0
	# Pasos de cebra / Zebra crossings
	var zebra := Color(line, 0.9) if style != "cheese" else Color("fff6e0")
	for c: int in CROSS_COLS:
		var x := c * T
		draw_rect(Rect2(Vector2(x, h0.y + 8), Vector2(T, hw - 16)), Color(0, 0, 0, 0.12))
		var y := h0.y + 16.0
		while y < h1.y - 20.0:
			draw_rect(Rect2(Vector2(x + 14, y), Vector2(T - 28, 26)), zebra)
			y += 48.0
	for r: int in CROSS_ROWS:
		var y := r * T
		var x := v0.x + 16.0
		while x < v1.x - 20.0:
			draw_rect(Rect2(Vector2(x, y + 14), Vector2(26, T - 28)), zebra)
			x += 48.0
	# Mojado (noir): reflejos de las luces en el asfalto / Wet (noir): light reflections on the asphalt
	if _road("wet"):
		for i in 30:
			var q := Vector2(h0.x + fposmod(i * 731.0, h1.x - h0.x), h0.y + 30.0 + fposmod(i * 197.0, hw - 60.0))
			if q.x > core0.x and q.x < core1.x:
				continue
			var a := 0.2 + 0.15 * sin(_t * 1.5 + i)
			draw_rect(Rect2(q, Vector2(4, 40)), Color("e0303a", a) if i % 4 == 0 else Color(1, 0.94, 0.8, a))


func _line(a: Vector2, b: Vector2, col: Color, w: float, glow: bool) -> void:
	if glow:
		draw_line(a, b, Color(col, 0.18), w * 3.0)
	draw_line(a, b, col, w)


## Charcos de luz bajo las farolas (ciudades de noche) / Pools of light under the lamps (night cities)
func _draw_lamp_light(r0: int, r1: int, c0: int, c1: int) -> void:
	var lamp := Color({"synthwave": "5ff2ff", "steampunk": "ffb04a", "dieselpunk": "ffd27a", "noir": "ffe8b0"}[style])
	var soft := DreamBackground.soft_texture()
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if CityLayout.MAP[r][c] == "l":
				var p := (Vector2(c, r) + Vector2(0.5, 0.75)) * T
				draw_texture_rect(soft, Rect2(p - Vector2(200, 90), Vector2(400, 180)), false, Color(lamp, 0.28))
				draw_texture_rect(soft, Rect2(p - Vector2(90, 40), Vector2(180, 80)), false, Color(lamp, 0.25))


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
			var at := (Vector2(c, r) + base) * T
			if sprite == "tree":
				# Árboles algo movidos, de tamaños distintos y unos girados: que no parezcan una fila
				# Trees a bit offset, of different sizes and some flipped: so they don't look like a row
				var h := _hash(c, r)
				at += Vector2(float(h % 41) - 20.0, float((h / 41) % 21) - 10.0)
				p.size = 0.85 + float(h % 7) * 0.06
				p.flip = h % 2 == 0
			p.position = Bedroom.to_world(at)
			p.sway = sprite == "tree"
			out.append(p)
	for car: Array in parked:
		var p := CityProp.new()
		p.sprite = _tile("car%d" % car[2])
		var row: int = ROAD_H.position.y + (0 if car[1] == 0 else ROAD_H.size.y - 1)
		p.position = Bedroom.to_world(Vector2(float(car[0]) * T, (row + (0.62 if car[1] == 0 else 0.78)) * T))
		p.flip = car[1] == 1
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
				if not CityLayout.MAP[r][c] in [".", ":", ","] or is_road(c, r):
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
