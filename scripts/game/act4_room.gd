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

var style := "synthwave"
var final := false
var rubble: Array[Rect2] = []
var _rubble_t: Array[float] = []
var _static: Array[Rect2] = []          # edificios, árboles, setos, agua... / buildings, trees, hedges, water...
var _grid := {}                         # cubo (Vector2i) → índices de _static / bucket → indices of _static
var _holes: Array[Rect2] = []
var _open := 0
var _near_cache := {}
var _near_frame := -1
const BUCKET := 480.0


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
				"W": _static.append(Rect2(p, Vector2(T, T)))
				"l": _static.append(Rect2(p + Vector2(48, 70), Vector2(24, 24)))
				"b": _static.append(Rect2(p + Vector2(10, 50), Vector2(100, 40)))
	for b: Array in CityLayout.BUILDINGS:
		_static.append(Rect2(Vector2(b[0], b[1]) * T, Vector2(b[2], b[3]) * T))
	for i in _static.size():
		var r: Rect2 = _static[i]
		for by in range(floori(r.position.y / BUCKET), floori(r.end.y / BUCKET) + 1):
			for bx in range(floori(r.position.x / BUCKET), floori(r.end.x / BUCKET) + 1):
				var k := Vector2i(bx, by)
				if not _grid.has(k):
					_grid[k] = []
				_grid[k].append(i)


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


func _draw() -> void:
	# Canto de la ciudad flotando en el sueño / Edge of the city floating in the dream
	var map := Rect2(Vector2.ZERO, MAP_SIZE)
	draw_rect(Rect2(map.position + Vector2(0, MAP_SIZE.y), Vector2(MAP_SIZE.x, 60)), Color("1b1846"))
	draw_rect(Rect2(map.position + Vector2(0, MAP_SIZE.y), Vector2(MAP_SIZE.x, 6)), Color("6a63b8"))
	# Solo lo que se ve / Only what's visible
	var view := _view_canvas().grow(T)
	var c0 := clampi(floori(view.position.x / T), 0, CityLayout.COLS - 1)
	var c1 := clampi(floori(view.end.x / T), 0, CityLayout.COLS - 1)
	var r0 := clampi(floori(view.position.y / T), 0, CityLayout.ROWS - 1)
	var r1 := clampi(floori(view.end.y / T), 0, CityLayout.ROWS - 1)
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
			var p := Vector2(c, r) * T
			Sprites.draw(self, _tile(kind), Color.WHITE, p)
			if ch == "W":
				_draw_water_rim(c, r, p)
	_draw_fountain()
	_draw_holes()
	draw_set_transform(Vector2.ZERO)


func _view_canvas() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var half := Vector2(960, 540) / cam.zoom.x * 0.5
	return Rect2((cam.global_position - half - OFFSET) / S, half * 2.0 / S)


func _is_water(c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= CityLayout.COLS or r >= CityLayout.ROWS:
		return false
	return CityLayout.MAP[r][c] == "W"


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


## La fuente de la plaza: chorros de agua que suben y caen / The plaza fountain: jets rising and falling
func _draw_fountain() -> void:
	var c := Vector2(22, 14) * T
	draw_colored_polygon(_ellipse(c + Vector2(0, 10), Vector2(80, 34)), Color("c8c4d8"))
	draw_colored_polygon(_ellipse(c + Vector2(0, 6), Vector2(62, 24)), Color("8fd8ff"))
	draw_rect(Rect2(c + Vector2(-12, -70), Vector2(24, 76)), Color("c8c4d8"))
	for i in 10:
		var ph := fposmod(_t * 0.9 + i * 0.1, 1.0)
		var a := TAU * i / 10.0
		var p := c + Vector2(0, -80) + Vector2(cos(a) * 70.0 * ph, sin(a) * 26.0 * ph - sin(ph * PI) * 50.0 + ph * 60.0)
		draw_circle(p, 6.0 * (1.0 - ph * 0.5), Color(0.8, 0.95, 1.0, 0.8 * (1.0 - ph)))


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
	return out


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


## Un edificio: tejado arriba y fachada abajo, dentro de su huella; se transparenta si Kroker pasa por detrás
## A building: roof on top and facade below, inside its footprint; it turns see-through if Kroker walks behind
class CityBuilding extends Node2D:
	var room: Act4Room
	var run: Node
	var style := ""
	var rect := Rect2()        # huella en el lienzo / footprint on the canvas
	var kind := "house"
	var seed := 0

	func _ready() -> void:
		scale = Vector2(Bedroom.S, Bedroom.S)

	func _process(_delta: float) -> void:
		if run == null or not is_instance_valid(run.player):
			return
		# Kroker detrás del edificio (tapado por el tejado): se ve a través / Kroker behind the building (hidden by the roof): see-through
		var p: Vector2 = (run.player.global_position - Bedroom.OFFSET) / Bedroom.S
		var top := rect.position.y - T * 0.5
		var behind := p.x > rect.position.x - 20.0 and p.x < rect.end.x + 20.0 and p.y > top and p.y < rect.end.y + 4.0
		modulate.a = move_toward(modulate.a, 0.45 if behind else 1.0, _delta * 4.0)
		if kind == "tower":
			queue_redraw()

	func _draw() -> void:
		var w := rect.size.x
		var d := rect.size.y
		var fh := TOWER_FACADE_H if kind == "tower" else FACADE_H
		var roof_top := -d - T * 0.5
		var roof_h := d + T * 0.5 - fh
		# Color del tejado un poco distinto en cada edificio / Roof colour slightly different on each building
		var tint := Color.WHITE.lerp(Color.from_hsv(fposmod(seed * 0.17, 1.0), 0.25, 1.0), 0.35)
		var roof := "city_%s_roof" % style
		var y := roof_top
		while y < -fh:
			var x := 0.0
			var hh := minf(T, -fh - y)
			while x < w:
				var ww := minf(T, w - x)
				_draw_part(roof, Rect2(x, y, ww, hh), tint)
				x += T
			y += T
		# Borde del tejado: luz delante, sombra arriba / Roof edge: light at the front, shadow at the top
		draw_rect(Rect2(0, roof_top, w, 6), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, -fh - 10, w, 10), Color(1, 1, 1, 0.25))
		draw_rect(Rect2(0, roof_top, 6, roof_h), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(w - 6, roof_top, 6, roof_h), Color(0, 0, 0, 0.25))
		_roof_details(roof_top, roof_h, w)
		# Fachada en tramos que casan / Facade in sections that tile
		var fac := "city_%s_%s" % [style, "facade_tall" if kind == "tower" else ("shopfront" if kind == "shop" else "facade")]
		var x2 := 0.0
		while x2 < w:
			_draw_part(fac, Rect2(x2, -fh, minf(250.0, w - x2), fh), Color.WHITE)
			x2 += 250.0
		draw_rect(Rect2(0, -6, w, 6), Color(0, 0, 0, 0.3))
		# Puerta en el centro / Door in the middle
		Sprites.draw(self, "city_%s_door" % style, Color.WHITE, Vector2(w / 2.0 - 62.5, -202.0))
		if kind == "tower":
			_tower_sign(w, fh)

	## Dibuja un trozo del sprite (para no estirarlo al final del edificio) / Draws part of the sprite (so it isn't stretched at the building's end)
	func _draw_part(sprite: String, dst: Rect2, mod: Color) -> void:
		var tex := Sprites.tex(sprite)
		var r: Rect2 = SpriteRects.RECTS[sprite]
		var src := Rect2(0, 0, tex.get_width() * dst.size.x / r.size.x, tex.get_height() * dst.size.y / r.size.y)
		draw_texture_rect_region(tex, dst, src, mod)

	func _roof_details(top: float, h: float, w: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 31 + 7
		var n := int(w / 200.0) + 1
		for i in n:
			var x := rng.randf_range(30.0, maxf(40.0, w - 90.0))
			var y := top + rng.randf_range(30.0, maxf(40.0, h - 70.0))
			match rng.randi() % 3:
				0:   # aire acondicionado / AC unit
					draw_rect(Rect2(x, y, 60, 40), Color("8a8fa8"))
					draw_rect(Rect2(x + 6, y + 6, 48, 6), Color("5a5f7a"))
					draw_circle(Vector2(x + 30, y + 26), 10.0, Color("4a4f6a"))
				1:   # chimenea / chimney
					draw_rect(Rect2(x, y, 30, 46), Color("7a5a5a"))
					draw_rect(Rect2(x - 4, y, 38, 8), Color("5a4040"))
				2:   # claraboya / skylight
					draw_rect(Rect2(x, y, 70, 44), Color("3a5a8a"))
					draw_rect(Rect2(x + 6, y + 6, 26, 32), Color("8fd8ff"))
					draw_rect(Rect2(x + 38, y + 6, 26, 32), Color("8fd8ff"))

	## Cartel luminoso de la torre de los sueños / The dream tower's lit sign
	func _tower_sign(w: float, fh: float) -> void:
		var c := Vector2(w / 2.0, -fh - 70.0)
		draw_rect(Rect2(c - Vector2(150, 34), Vector2(300, 68)), Color("1e1f2e"))
		draw_rect(Rect2(c - Vector2(144, 28), Vector2(288, 56)), Color("2a2c48"))
		var t := Time.get_ticks_msec() / 1000.0
		for i in 5:
			DreamBackground.draw_star(self, c + Vector2(-100 + i * 50, sin(t * 2.0 + i) * 4.0), 12.0, Color(UITheme.GOLD, 0.7 + 0.3 * sin(t * 3.0 + i)))
