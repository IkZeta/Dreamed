class_name Act3Room
extends Bedroom
## Acto 3 (sueños 11 a 13): el pasillo del colegio. Es infinito hacia los lados, como la
## biblioteca de Vampire Survivors: la cámara sigue a Kroker y el pasillo se dibuja a trozos de
## 1920 de ancho que se repiten (tres paredes distintas que se van turnando: taquillas y clase,
## baños y fuente, ventanales y vitrina). Los agujeros del suelo, los obstáculos (cartel de suelo
## mojado y cubo de fregar) y las puertas que se rompen también se repiten en cada trozo.
## Act 3 (dreams 11 to 13): the school hallway. It's endless to the sides, like the library in
## Vampire Survivors: the camera follows Kroker and the hallway is drawn in 1920-wide pieces
## that repeat (three different walls taking turns: lockers and classroom, toilets and fountain,
## big windows and trophy case). Floor holes, obstacles (wet-floor sign and mop bucket) and the
## doors that break open also repeat in every piece.

const PERIOD := 1920.0
## Mitad del ancho del pasillo (en el lienzo): de sobra para que nadie llegue al final
## Half the hallway's width (on the canvas): far more than anyone will ever walk
const HALF := 60000.0
const WALK := Rect2(-HALF, 330, HALF * 2.0, 690)
## Agujeros del suelo dentro de cada trozo (se abren más en cada sueño)
## Floor holes inside each piece (more open in each dream)
const PIECE_HOLES: Array[Rect2] = [
	Rect2(300, 640, 170, 72),
	Rect2(1320, 840, 190, 74),
	Rect2(880, 930, 140, 60),
]
## Puertas de cada pared (por ellas se puede tirar a los enemigos cuando se rompen)
## Doors on each wall (enemies can be shoved through them once they break)
const PIECE_DOORS := [
	[Rect2(760, 60, 140, 240)],
	[Rect2(620, 60, 140, 240), Rect2(820, 60, 140, 240)],
	[Rect2(1180, 60, 140, 240)],
]
## Obstáculos de cada trozo: [sprite, base de la figura, rectángulo que bloquea]
## Obstacles in each piece: [sprite, figure's base, blocking rectangle]
const PIECE_PROPS := [
	["hall_sign", Vector2(1120, 520), Rect2(1094, 494, 52, 32)],
	["hall_bucket", Vector2(560, 880), Rect2(530, 850, 60, 36)],
]

## Destrozos del Ovni: agujeros nuevos en el suelo y quemaduras en la pared (en el lienzo)
## UFO damage: new holes in the floor and scorch marks on the wall (on the canvas)
const MAX_CRATERS := 10
var craters: Array[Rect2] = []
var _crater_t: Array[float] = []   # segundos que le quedan a cada agujero / seconds left on each hole
const CRATER_LIFE := 25.0
var scorches: Array[Vector2] = []
## Timbre del recreo: 0 cerradas → 1 abiertas de par en par / School bell: 0 closed → 1 wide open
var bell_open := 0.0
var _piece := 999999          # trozo en el que está la cámara / piece the camera is in
var _holes: Array[Rect2] = []
var _doors: Array[Rect2] = []
var _props: Array[Rect2] = []


func walkable() -> Rect2:
	return WALK


func follows_camera() -> bool:
	return true


## Trozo (índice) de una x del lienzo / Piece index for a canvas x
static func piece_of(x: float) -> int:
	return floori(x / PERIOD)


## x del centro de la cámara en el lienzo / Camera centre x on the canvas
func _cam_x() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return 960.0
	return (cam.global_position.x - OFFSET.x) / S


func _process(delta: float) -> void:
	# Los agujeros del Ovni se cierran solos al rato / The UFO's holes close up after a while
	var closed := false
	for i in range(_crater_t.size() - 1, -1, -1):
		_crater_t[i] -= delta
		if _crater_t[i] <= 0.0:
			_crater_t.remove_at(i)
			craters.remove_at(i)
			closed = true
	_refresh_lists(closed)
	super._process(delta)


## Recalcula agujeros, puertas y obstáculos de los trozos cercanos cuando la cámara cambia de trozo
## Rebuilds holes, doors and obstacles of the nearby pieces when the camera moves to another piece
func _refresh_lists(force := false) -> void:
	var k := piece_of(_cam_x())
	if k == _piece and not force:
		return
	_piece = k
	_holes.clear()
	_doors.clear()
	_props.clear()
	var holes_each := clampi(weird, 0, PIECE_HOLES.size())
	for i in range(k - 2, k + 3):
		var off := Vector2(i * PERIOD, 0)
		for h in holes_each:
			_holes.append(Rect2(PIECE_HOLES[h].position + off, PIECE_HOLES[h].size))
		if weird >= 2:
			for d: Rect2 in PIECE_DOORS[posmod(i, 3)]:
				_doors.append(Rect2(d.position + off, d.size))
		var pr: Array = PIECE_PROPS[posmod(i, 2)]
		var r: Rect2 = pr[2]
		_props.append(Rect2(r.position + off, r.size))
	var lo := (k - 2) * PERIOD
	var hi := (k + 3) * PERIOD
	for c in craters:
		if c.end.x > lo and c.position.x < hi:
			_holes.append(c)


## Puntos del suelo delante de cada puerta entre dos x del lienzo (por ahí salen los alumnos al sonar el timbre)
## Floor points in front of each door between two canvas x (pupils pour out there when the bell rings)
func door_points(x0: float, x1: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(piece_of(x0), piece_of(x1) + 1):
		for d: Rect2 in PIECE_DOORS[posmod(i, 3)]:
			var x := d.get_center().x + i * PERIOD
			if x >= x0 and x <= x1:
				out.append(Vector2(x, WALL_BOTTOM + 46))
	return out


## El Ovni rompe el suelo: abre un agujero nuevo (los más viejos se cierran)
## The UFO breaks the floor: opens a new hole (the oldest ones close up)
func add_crater(center: Vector2, sz := Vector2(150, 64)) -> void:
	var r := Rect2(center - sz / 2.0, sz)
	var walk := Rect2(WALK.position + Vector2(0, 40), WALK.size - Vector2(0, 80))
	r.position.y = clampf(r.position.y, walk.position.y, walk.end.y - sz.y)
	craters.append(r)
	_crater_t.append(CRATER_LIFE)
	if craters.size() > MAX_CRATERS:
		craters.remove_at(0)
		_crater_t.remove_at(0)
	_refresh_lists(true)


## El Ovni quema la pared / The UFO scorches the wall
func add_scorch(x: float) -> void:
	scorches.append(Vector2(x, randf_range(90, 250)))
	if scorches.size() > 30:
		scorches.remove_at(0)


func hole_count() -> int:
	return _holes.size()


func wall_hole_count() -> int:
	return _doors.size()


func holes_list() -> Array[Rect2]:
	if _piece == 999999:
		_refresh_lists(true)
	return _holes


func wall_holes_list() -> Array[Rect2]:
	if _piece == 999999:
		_refresh_lists(true)
	return _doors


func obstacles_list() -> Array[Rect2]:
	if _piece == 999999:
		_refresh_lists(true)
	return _props.duplicate()   # copia: blockers() le añade los agujeros / a copy: blockers() appends the holes


func crack_zones() -> Array[Rect2]:
	var wall := Rect2(20, 30, 1880, 250)
	return [wall, wall, wall, wall, Rect2(60, 340, 1800, 680)]


func _draw() -> void:
	var k := piece_of(_cam_x())
	var pieces := range(k - 1, k + 2)
	for i: int in pieces:
		var off := Vector2(i * PERIOD, 0)
		_draw_piece("hall_floor", off)
		_draw_piece("hall_wall_%d" % posmod(i, 3), off)
	_draw_scorches(k)
	if bell_open > 0.0:
		_draw_open_doors(k)
	_draw_wall_holes()
	_draw_holes()
	_draw_wall_hole_floor()
	for i: int in pieces:
		var pr: Array = PIECE_PROPS[posmod(i, 2)]
		var base: Vector2 = pr[1]
		draw_colored_polygon(_ellipse(base + Vector2(i * PERIOD, 0), Vector2(30, 9)), Color(0, 0, 0, 0.3))
		Sprites.draw(self, pr[0], Color.WHITE, base + Vector2(i * PERIOD, 0))
	# Lo que se repite en cada trozo: grietas, estrellas y cosas que flotan
	# What repeats in each piece: cracks, stars and floating things
	for i: int in pieces:
		draw_set_transform(Vector2(i * PERIOD, 0))
		_draw_corruption()
		_draw_dream_stars()
	draw_set_transform(Vector2.ZERO)
	_draw_edges(k)


## Puertas abiertas con el timbre: hueco oscuro con luz de clase y la puerta girada
## Doors open with the bell: a dark gap with classroom light and the door swung open
func _draw_open_doors(k: int) -> void:
	for i in range(k - 1, k + 2):
		for d: Rect2 in PIECE_DOORS[posmod(i, 3)]:
			var r := Rect2(d.position + Vector2(i * PERIOD, 0), d.size)
			if _doors.has(r):
				continue   # ya está rota / already broken
			var w := r.size.x * bell_open
			draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Color("2a2238"))
			draw_rect(Rect2(r.position + Vector2(6, 10), Vector2(maxf(0.0, w - 12), r.size.y - 10)), Color("f6d993", 0.35))
			# Hoja de la puerta abierta hacia el pasillo / Door leaf swung out into the hallway
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(w, 0), r.position + Vector2(w + 26 * bell_open, -10), r.position + Vector2(w + 26 * bell_open, r.size.y + 14), r.position + Vector2(w, r.size.y)]), Color("8a5a3e"))


## Quemaduras del Ovni en la pared: mancha negra, taquillas abolladas y chispas
## UFO scorch marks on the wall: black blotch, dented lockers and sparks
func _draw_scorches(k: int) -> void:
	var lo := (k - 2) * PERIOD
	var hi := (k + 2) * PERIOD
	for i in scorches.size():
		var c := scorches[i]
		if c.x < lo or c.x > hi:
			continue
		draw_colored_polygon(_ellipse(c, Vector2(70, 46)), Color(0.1, 0.07, 0.05, 0.55))
		draw_colored_polygon(_ellipse(c, Vector2(40, 26)), Color(0.05, 0.03, 0.02, 0.8))
		for kk in 5:
			var a := TAU * kk / 5.0 + i
			draw_line(c, c + Vector2(cos(a) * 60.0, sin(a) * 36.0), Color(0.05, 0.03, 0.02, 0.6), 4.0)
		if fmod(_t * 3.0 + i, 2.0) < 0.15:
			draw_circle(c + Vector2(randf_range(-20, 20), randf_range(-10, 10)), 4.0, Color("ffd27a"))


## Dibuja un trozo un pelín más ancho para que no se vean costuras entre trozos
## Draws a piece a tiny bit wider so no seams show between pieces
func _draw_piece(sprite: String, off: Vector2) -> void:
	var r: Rect2 = SpriteRects.RECTS[sprite]
	r.position += off
	draw_texture_rect(Sprites.tex(sprite), r.grow_individual(4, 0, 4, 0), false)


## El pasillo flota en el cielo: canto del suelo y del techo a lo largo
## The hallway floats in the sky: floor and ceiling edges all along
func _draw_edges(k: int) -> void:
	var x0 := (k - 1) * PERIOD
	var w := PERIOD * 3.0
	draw_rect(Rect2(x0, FLOOR_BOTTOM, w, 34), Color("5a5446"))
	draw_rect(Rect2(x0, FLOOR_BOTTOM, w, 4), Color("a49c86"))
	draw_rect(Rect2(x0, -8, w, 8), Color("8a7e66"))
	# Sombra junto a la pared / Shadow along the wall
	draw_polygon(PackedVector2Array([Vector2(x0, WALL_BOTTOM), Vector2(x0 + w, WALL_BOTTOM), Vector2(x0 + w, WALL_BOTTOM + 50), Vector2(x0, WALL_BOTTOM + 50)]),
		PackedColorArray([Color(0.25, 0.2, 0.1, 0.3), Color(0.25, 0.2, 0.1, 0.3), Color(0.25, 0.2, 0.1, 0), Color(0.25, 0.2, 0.1, 0)]))


## Agujeros del suelo: terrazo roto por el borde y, dentro, el vacío del sueño
## Floor holes: broken terrazzo at the rim and, inside, the dream void
func _draw_holes() -> void:
	var list := holes_list()
	for i in hole_count():
		var h := list[i]
		var c := h.get_center()
		var rr := h.size / 2.0
		var seed := float(i) + floorf(h.position.x / PERIOD) * 3.0
		var rim := PackedVector2Array()
		var inner := PackedVector2Array()
		for kk in 28:
			var a := TAU * kk / 28.0
			var jag := 1.0 + 0.12 * sin(a * 5.0 + seed * 2.0) + 0.06 * sin(a * 11.0 + seed)
			rim.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * (jag + 0.12))
			inner.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * jag)
		draw_colored_polygon(rim, Color("8f8872"))
		draw_colored_polygon(inner, Color("07061a"))
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - rr * 0.8, rr * 1.6), false, Color("5b4bc4", 0.35))
		for kk in 7:
			var sp := c + Vector2(sin(kk * 2.3 + seed) * rr.x * 0.6, cos(kk * 1.7 + seed) * rr.y * 0.5)
			draw_circle(sp, 1.4, Color(UITheme.BONE, 0.4 + 0.4 * sin(_t * 2.0 + kk)))
		# Trozos de baldosa / Bits of tile
		for kk in 6:
			var a := TAU * kk / 6.0 + seed
			var p0 := c + Vector2(cos(a) * rr.x, sin(a) * rr.y)
			draw_rect(Rect2(p0 + Vector2(cos(a) * 8.0, sin(a) * 4.0) - Vector2(5, 3), Vector2(10, 6)), Color("bdb49a"))


## Puertas rotas: el marco sigue y dentro se ve el vacío / Broken doors: the frame stays and the void shows through
func _draw_wall_holes() -> void:
	var list := wall_holes_list()
	for i in wall_hole_count():
		var h := list[i]
		draw_rect(h, Color("07061a"))
		draw_texture_rect(DreamBackground.soft_texture(), h.grow(-10), false, Color("5b4bc4", 0.4))
		for kk in 9:
			var sp := h.position + Vector2(fposmod(kk * 37.0 + i * 13.0, h.size.x), fposmod(kk * 53.0 + i * 29.0, h.size.y))
			draw_circle(sp, 1.5, Color(UITheme.BONE, 0.4 + 0.4 * sin(_t * 2.0 + kk)))
		# Astillas de la puerta colgando de las bisagras / Door splinters hanging from the hinges
		draw_colored_polygon(PackedVector2Array([h.position, h.position + Vector2(26, 0), h.position + Vector2(10, 90), h.position + Vector2(0, 120)]), Color("8a5a3e"))
		draw_colored_polygon(PackedVector2Array([Vector2(h.position.x, h.end.y - 70), Vector2(h.position.x + 18, h.end.y - 40), Vector2(h.position.x, h.end.y)]), Color("6a4430"))


func _draw_wall_hole_floor() -> void:
	var list := wall_holes_list()
	for i in wall_hole_count():
		var h := list[i]
		var c := Vector2(h.get_center().x, WALL_BOTTOM + 22)
		draw_colored_polygon(_ellipse(c, Vector2(h.size.x * 0.55, 20)), Color("07061a", 0.6))
